import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:epikodi_client/epikodi_client.dart';
import 'package:flutter/material.dart';

import 'media_kit_engine.dart';
import 'playback_engine.dart';
import 'playback_state.dart';
import 'player_screen.dart';
import 'subtitle_style.dart';

/// Lecture pilotée par le cœur (voir docs/adr/0002-lecture-pilotee-par-le-coeur.md).
///
/// La TV ne choisit jamais seule ce qu'elle lit :
/// 1. la médiathèque ou la télécommande demandent `POST /api/player/play` ;
/// 2. le cœur envoie l'événement WebSocket `player.command` ; `load` ouvre
///    le lecteur sur `now_playing.uri` à partir de `start_s`, les autres
///    actions pilotent le lecteur ouvert ;
/// 3. la TV publie l'état réel avec `POST /api/player/state` ([PlayerReporter]).

/// Canal entre l'app TV et le cœur pour la lecture.
abstract class PlayerLink {
  /// Événements temps réel du cœur : `{"type": ..., "data": ...}`.
  Stream<Map<String, dynamic>> get events;

  /// Publie l'état réel du lecteur (`POST /api/player/state`).
  Future<void> report(Map<String, dynamic> state);

  void close();
}

/// [PlayerLink] réel : WebSocket `GET /api/ws` (la TV est locale, sans
/// jeton) et route HTTP locale. Se reconnecte tout seul si le cœur redémarre.
class ServerPlayerLink implements PlayerLink {
  ServerPlayerLink({
    required this.baseUrl,
    this.retryDelay = const Duration(seconds: 2),
  }) : _client = EpikodiClient(baseUrl: baseUrl);

  final String baseUrl;

  /// Pause avant de se reconnecter quand la connexion tombe.
  final Duration retryDelay;

  final EpikodiClient _client;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  WebSocket? _socket;
  bool _started = false;
  bool _closed = false;

  @override
  Stream<Map<String, dynamic>> get events {
    if (!_started) {
      _started = true;
      _run();
    }
    return _events.stream;
  }

  Uri get _wsUri {
    final base = Uri.parse(baseUrl);
    return base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws', path: '/api/ws');
  }

  Future<void> _run() async {
    while (!_closed) {
      try {
        final socket = await WebSocket.connect(_wsUri.toString());
        if (_closed) {
          await socket.close();
          return;
        }
        _socket = socket;
        await for (final message in socket) {
          if (message is! String) continue;
          final json = _decode(message);
          if (json is Map<String, dynamic>) _events.add(json);
        }
      } catch (_) {
        // cœur arrêté ou réseau coupé : on réessaie ci-dessous
      }
      _socket = null;
      if (!_closed) await Future<void>.delayed(retryDelay);
    }
  }

  /// Un message illisible est ignoré (sans couper la connexion).
  static Object? _decode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> report(Map<String, dynamic> state) async {
    try {
      await _client.http.post('/api/player/state', body: state);
    } on ApiException {
      // Cœur injoignable : l'état suivant le remettra à jour.
    }
  }

  @override
  void close() {
    _closed = true;
    _socket?.close();
    _events.close();
    _client.close();
  }
}

/// Statut du lecteur tel que le cœur l'attend (`PlayerStatus`).
String playerStatusOf(PlaybackState s) {
  if (s.error != null) return 'error';
  if (s.completed) return 'ended';
  if (s.playing) return 'playing';
  if (s.duration == Duration.zero) return 'loading';
  return 'paused';
}

/// Rapport `POST /api/player/state` (voir fixtures/player/state_request.json).
///
/// Les identifiants de piste du moteur (`1`, `2` pour mpv) sont ceux que le
/// cœur renvoie dans `audio_track` / `subtitle_track`.
Map<String, dynamic> playerReportOf(PlaybackState s, {String? status}) {
  Map<String, dynamic>? track(MediaTrack t) {
    final id = int.tryParse(t.id);
    if (id == null) return null;
    return {
      'id': id,
      'lang': t.language,
      'title': t.title,
      'codec': null,
      'audio_description': t.isAudioDescription,
    };
  }

  int? selected(MediaTrack? t) => t == null ? null : int.tryParse(t.id);

  return {
    'status': status ?? playerStatusOf(s),
    'position_s': s.position.inMilliseconds / 1000,
    'duration_s':
        s.duration > Duration.zero ? s.duration.inMilliseconds / 1000 : null,
    'audio_tracks': s.audioTracks.map(track).whereType<Object>().toList(),
    'subtitle_tracks': s.subtitleTracks.map(track).whereType<Object>().toList(),
    'audio_track': selected(s.audioTrack),
    'subtitle_track': selected(s.subtitleTrack),
  };
}

/// Publie l'état d'un moteur au cœur :
/// - à chaque changement de statut ou de piste (une seule fois chacun : un
///   `ended` n'est jamais envoyé deux fois, le cœur sauterait un média) ;
/// - toutes les [interval] pendant la lecture, pour la position.
class PlayerReporter {
  PlayerReporter(
    this.engine,
    this.send, {
    this.interval = const Duration(seconds: 5),
  });

  final PlaybackEngine engine;
  final Future<void> Function(Map<String, dynamic> state) send;
  final Duration interval;

  Timer? _timer;
  String? _lastKey;
  bool _attached = false;

  void start() {
    _attached = true;
    engine.state.addListener(_onState);
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void _onState() {
    if (!_attached) return;
    final report = playerReportOf(engine.state.value);
    // La position change sans cesse : elle part avec le minuteur.
    final key = jsonEncode({...report}..remove('position_s'));
    if (key == _lastKey) return;
    _lastKey = key;
    send(report);
  }

  void _tick() {
    if (!_attached) return;
    final s = engine.state.value;
    if (playerStatusOf(s) == 'playing') send(playerReportOf(s));
  }

  /// Arrête de publier, sans rien envoyer (le cœur est déjà passé à autre
  /// chose : nouveau média ou arrêt qu'il a lui-même demandé).
  void detach() {
    if (!_attached) return;
    _attached = false;
    _timer?.cancel();
    engine.state.removeListener(_onState);
  }

  /// Le lecteur se ferme depuis la TV (Retour) : dernier état `stopped`,
  /// avec la position, pour que le cœur enregistre la reprise.
  void stop(PlaybackState last) {
    if (!_attached) return;
    detach();
    send(playerReportOf(last, status: 'stopped'));
  }
}

/// Ouvre et pilote le lecteur selon les commandes du cœur, quel que soit
/// l'écran affiché. Placé au-dessus du navigateur de l'app (dans
/// `MaterialApp.builder`), comme l'écoute de la télécommande.
class PlaybackHost extends StatefulWidget {
  const PlaybackHost({
    super.key,
    required this.navigator,
    required this.linkFactory,
    this.engineFactory = MediaKitEngine.new,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigator;

  /// Crée le canal vers le cœur ; il est fermé avec l'hôte.
  final PlayerLink Function() linkFactory;

  /// Crée un moteur neuf à chaque `load` (faux moteur dans les tests).
  final PlaybackEngine Function() engineFactory;

  final Widget child;

  @override
  State<PlaybackHost> createState() => _PlaybackHostState();
}

/// Lecteur ouvert : son moteur, sa page et ce qui publie son état.
class _Session {
  _Session(this.engine, this.route, this.reporter);

  final PlaybackEngine engine;
  final Route<void> route;
  final PlayerReporter reporter;
}

class _PlaybackHostState extends State<PlaybackHost> {
  late final PlayerLink _link = widget.linkFactory();
  StreamSubscription<Map<String, dynamic>>? _subscription;
  _Session? _session;

  // Apparence des sous-titres gardée d'une lecture à l'autre (session).
  SubtitleStyle _subtitleStyle = const SubtitleStyle();

  @override
  void initState() {
    super.initState();
    _subscription = _link.events.listen(_onEvent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _session?.reporter.detach();
    _link.close();
    super.dispose();
  }

  void _onEvent(Map<String, dynamic> event) {
    if (event['type'] != 'player.command') return;
    final command = event['data'];
    if (command is Map<String, dynamic>) _handle(command);
  }

  static Duration? _seconds(Object? value) => value is num
      ? Duration(microseconds: (value * Duration.microsecondsPerSecond).round())
      : null;

  Future<void> _handle(Map<String, dynamic> c) async {
    if (c['action'] == 'load') return _load(c);
    final engine = _session?.engine;
    if (engine == null) return; // rien d'ouvert : commande sans objet
    switch (c['action']) {
      case 'play':
        await engine.play();
      case 'pause':
        await engine.pause();
      case 'toggle':
        await engine.togglePlay();
      case 'stop':
        _close();
      case 'seek':
        final to = _seconds(c['position_s']);
        if (to != null) await engine.seek(to);
      case 'seek_relative':
        final delta = _seconds(c['delta_s']);
        if (delta != null) {
          await engine.seek(engine.state.value.position + delta);
        }
      case 'volume':
        final level = c['level'];
        if (level is int) {
          await engine.setVolume(level, muted: c['muted'] == true);
        }
      case 'audio_track':
        final track = _track(engine.state.value.audioTracks, c['id']);
        if (track != null) await engine.setAudioTrack(track);
      case 'subtitle_track':
        if (c['id'] == null) {
          await engine.setSubtitleTrack(null);
        } else {
          final track = _track(engine.state.value.subtitleTracks, c['id']);
          if (track != null) await engine.setSubtitleTrack(track);
        }
      case 'subtitle_delay':
        final ms = c['delay_ms'];
        if (ms is int) {
          await engine.setSubtitleDelay(Duration(milliseconds: ms));
        }
    }
  }

  static MediaTrack? _track(List<MediaTrack> tracks, Object? id) {
    for (final t in tracks) {
      if (t.id == '$id') return t;
    }
    return null;
  }

  /// `load` : ouvre le lecteur. Un lecteur déjà ouvert (média suivant, autre
  /// média lancé depuis la télécommande) est remplacé, pas empilé.
  void _load(Map<String, dynamic> c) {
    final nowPlaying = c['now_playing'];
    final nav = widget.navigator.currentState;
    if (nowPlaying is! Map<String, dynamic> || nav == null) return;
    final uri = nowPlaying['uri'];
    if (uri is! String || uri.isEmpty) return;

    final source = PlaybackSource(
      uri: uri,
      title: '${nowPlaying['title'] ?? ''}',
      start: _seconds(c['start_s']) ?? Duration.zero,
    );
    final engine = widget.engineFactory();
    final reporter = PlayerReporter(engine, _link.report);
    late final MaterialPageRoute<void> route;
    route = MaterialPageRoute<void>(
      builder: (_) => PlayerScreen(
        engine: engine,
        source: source,
        subtitleStyle: _subtitleStyle,
        onSubtitleStyleChanged: (s) => _subtitleStyle = s,
        onClosing: (last) {
          reporter.stop(last);
          if (_session?.route == route) _session = null;
        },
      ),
    );

    final previous = _session;
    previous?.reporter.detach(); // le cœur est déjà passé au nouveau média
    _session = _Session(engine, route, reporter);
    reporter.start();

    if (previous != null && previous.route.isActive) {
      // Ferme d'abord ce qui est ouvert au-dessus (panneau des pistes).
      nav.popUntil((r) => r == previous.route || r.isFirst);
      if (previous.route.isCurrent) {
        nav.pushReplacement(route);
        return;
      }
    }
    nav.push(route);
  }

  /// `stop` : ferme le lecteur (et ce qui est ouvert au-dessus).
  void _close() {
    final session = _session;
    final nav = widget.navigator.currentState;
    if (session == null || nav == null || !session.route.isActive) return;
    nav.popUntil((r) => r == session.route || r.isFirst);
    if (session.route.isCurrent) nav.pop();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
