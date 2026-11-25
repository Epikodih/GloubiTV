// Lecture pilotée par le cœur : commandes player.command reçues par la TV
// et états publiés (POST /api/player/state), avec un faux moteur.
import 'package:epikodi_tv/player/playback_state.dart';
import 'package:epikodi_tv/player/player_screen.dart';
import 'package:epikodi_tv/player/server_player.dart';
import 'package:epikodi_tv/player/subtitle_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_engine.dart';
import 'support/fake_player_link.dart';
import 'support/harness.dart';

/// Commande `load` du contrat (fixtures/events/player_command_load.json).
Map<String, dynamic> get loadCommand => Map<String, dynamic>.of(
    readFixture('events/player_command_load.json')['data']);

Map<String, dynamic> load(String uri, String title, {num start = 0}) => {
      'action': 'load',
      'now_playing': {
        'media': null,
        'title': title,
        'uri': uri,
        'queue_item_id': null,
      },
      'start_s': start,
    };

void main() {
  late FakePlayerLink link;
  late List<FakeEngine> engines;

  setUp(() {
    link = FakePlayerLink();
    engines = [];
  });

  /// Moteur du dernier lecteur ouvert.
  FakeEngine engine() => engines.last;

  Future<void> pumpHost(WidgetTester tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await pumpTv(
      tester,
      const Scaffold(body: Text('Accueil')),
      navigatorKey: navigator,
      wrap: (child) => PlaybackHost(
        navigator: navigator,
        linkFactory: () => link,
        engineFactory: () {
          final e = FakeEngine();
          engines.add(e);
          return e;
        },
        child: child,
      ),
    );
    await settle(tester);
  }

  /// Envoie une commande, puis laisse le lecteur s'ouvrir : la commande est
  /// traitée après une image, la page apparaît à l'image suivante.
  Future<void> send(WidgetTester tester, Map<String, dynamic> command) async {
    link.command(command);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
  }

  group('load', () {
    testWidgets('ouvre le lecteur sur le fichier, à la position de reprise',
        (tester) async {
      await pumpHost(tester);
      await send(tester, loadCommand);

      expect(find.byType(PlayerScreen), findsOneWidget);
      final opened = engine().opened!;
      expect(opened.uri, '/home/demo/media-demo/Films/Sintel (2010).mkv');
      expect(opened.title, 'Sintel');
      expect(opened.start, const Duration(milliseconds: 312500));
      expect(opened.headers, isEmpty);
      await unmount(tester);
    });

    testWidgets('un second load remplace le lecteur sans publier « stopped »',
        (tester) async {
      await pumpHost(tester);
      await send(tester, load('/films/a.mkv', 'A'));
      final first = engine();
      await send(tester, load('/films/b.mkv', 'B'));

      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(first.disposed, isTrue);
      expect(engine().opened?.title, 'B');
      expect(link.statuses, isNot(contains('stopped')));
      await unmount(tester);
    });

    testWidgets('load sans uri : rien ne s\'ouvre', (tester) async {
      await pumpHost(tester);
      await send(tester, {
        'action': 'load',
        'now_playing': {'title': 'X', 'uri': ''},
        'start_s': 0,
      });
      expect(find.byType(PlayerScreen), findsNothing);
      expect(engines, isEmpty);
      await unmount(tester);
    });

    testWidgets("le style des sous-titres est gardé d'une lecture à l'autre",
        (tester) async {
      await pumpHost(tester);
      await send(tester, load('/films/a.mkv', 'A'));
      tester
              .widget<PlayerScreen>(find.byType(PlayerScreen))
              .onSubtitleStyleChanged!(
          const SubtitleStyle(size: SubtitleSize.extraLarge));
      await send(tester, load('/films/b.mkv', 'B'));
      expect(
          tester.widget<PlayerScreen>(find.byType(PlayerScreen)).subtitleStyle,
          const SubtitleStyle(size: SubtitleSize.extraLarge));
      await unmount(tester);
    });
  });

  group('commandes', () {
    testWidgets('lecture, pause, position, volume, décalage', (tester) async {
      await pumpHost(tester);
      await send(tester, load('/films/a.mkv', 'A'));
      engine().calls.clear();

      await send(tester, {'action': 'pause'});
      await send(tester, {'action': 'play'});
      await send(tester, {'action': 'toggle'});
      await send(tester, {'action': 'seek', 'position_s': 60});
      await send(tester, {'action': 'seek_relative', 'delta_s': -10.5});
      await send(tester, {'action': 'volume', 'level': 40, 'muted': true});
      await send(tester, {'action': 'subtitle_delay', 'delay_ms': -250});

      expect(engine().calls, [
        'pause',
        'play',
        'pause',
        'seek ${const Duration(seconds: 60)}',
        'seek ${const Duration(milliseconds: 49500)}',
        'volume 40 muet',
        'sub-delay -250',
      ]);
      await unmount(tester);
    });

    testWidgets('pistes audio et sous-titres choisies par identifiant',
        (tester) async {
      await pumpHost(tester);
      await send(tester, load('/films/a.mkv', 'A'));
      engine().emit((s) => s.copyWith(
            audioTracks: const [MediaTrack(id: '1'), MediaTrack(id: '2')],
            subtitleTracks: const [MediaTrack(id: '3')],
          ));
      engine().calls.clear();

      await send(tester, {'action': 'audio_track', 'id': 2});
      await send(tester, {'action': 'subtitle_track', 'id': 3});
      await send(tester, {'action': 'subtitle_track', 'id': null});
      await send(tester, {'action': 'audio_track', 'id': 9}); // inconnue

      expect(engine().calls, ['audio 2', 'subtitle 3', 'subtitle null']);
      await unmount(tester);
    });

    testWidgets('stop ferme le lecteur', (tester) async {
      await pumpHost(tester);
      await send(tester, load('/films/a.mkv', 'A'));
      await send(tester, {'action': 'stop'});
      expect(find.byType(PlayerScreen), findsNothing);
      expect(engine().disposed, isTrue);
      expect(find.text('Accueil'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('sans lecteur ouvert, les commandes sont ignorées',
        (tester) async {
      await pumpHost(tester);
      await send(tester, {'action': 'pause'});
      link.event({
        'type': 'player.state',
        'data': {'status': 'stopped'}
      });
      await tester.pump();
      expect(find.byType(PlayerScreen), findsNothing);
      expect(link.reports, isEmpty);
      await unmount(tester);
    });
  });

  group('état publié au cœur', () {
    testWidgets('changements de statut, chacun une seule fois', (tester) async {
      await pumpHost(tester);
      await send(tester, load('/films/a.mkv', 'A'));
      await send(tester, {'action': 'pause'});
      engine().emit((s) => s.copyWith(completed: true));
      engine().emit((s) => s.copyWith(position: const Duration(minutes: 10)));
      await tester.pump();

      expect(link.statuses, ['playing', 'paused', 'ended']);
      await unmount(tester);
    });

    testWidgets('position publiée toutes les 5 s pendant la lecture',
        (tester) async {
      await pumpHost(tester);
      await send(tester, load('/films/a.mkv', 'A'));
      link.reports.clear();
      engine().emit((s) => s.copyWith(position: const Duration(seconds: 42)));
      await tester.pump(const Duration(seconds: 5));

      expect(link.reports.single['status'], 'playing');
      expect(link.reports.single['position_s'], 42.0);

      await send(tester, {'action': 'pause'});
      link.reports.clear();
      await tester.pump(const Duration(seconds: 10));
      expect(link.reports, isEmpty, reason: 'en pause : rien à publier');
      await unmount(tester);
    });

    testWidgets(
        'Retour ferme le lecteur et publie « stopped » avec la position',
        (tester) async {
      await pumpHost(tester);
      await send(tester, load('/films/a.mkv', 'A'));
      engine().emit((s) => s.copyWith(position: const Duration(seconds: 90)));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(PlayerScreen), findsNothing);
      expect(engine().disposed, isTrue);
      expect(link.reports.last['status'], 'stopped');
      expect(link.reports.last['position_s'], 90.0);
      await unmount(tester);
    });

    testWidgets('le canal est fermé avec l\'app', (tester) async {
      await pumpHost(tester);
      await unmount(tester);
      expect(link.closed, isTrue);
    });
  });

  group('playerReportOf', () {
    test('même forme que fixtures/player/state_request.json', () {
      final fixture =
          readFixture('player/state_request.json') as Map<String, dynamic>;
      final report = playerReportOf(const PlaybackState(
        playing: true,
        position: Duration(milliseconds: 312500),
        duration: Duration(seconds: 888),
        audioTracks: [MediaTrack(id: '1', title: 'English', language: 'en')],
        subtitleTracks: [
          MediaTrack(id: '1', title: 'Français', language: 'fr')
        ],
        audioTrack: MediaTrack(id: '1'),
      ));
      expect(report.keys.toSet(), fixture.keys.toSet());
      expect(report['status'], 'playing');
      expect(report['position_s'], 312.5);
      expect(report['duration_s'], 888.0);
      expect(report['audio_track'], 1);
      expect(report['subtitle_track'], isNull);
      expect((report['audio_tracks'] as List).single,
          {...(fixture['audio_tracks'] as List).single, 'codec': null});
    });

    test('audiodescription signalée, pistes virtuelles ignorées', () {
      final report = playerReportOf(const PlaybackState(audioTracks: [
        MediaTrack(id: 'auto'),
        MediaTrack(
            id: '2', title: 'Audiodescription', isAudioDescription: true),
      ]));
      final tracks = report['audio_tracks'] as List;
      expect(tracks.single['id'], 2);
      expect(tracks.single['audio_description'], isTrue);
      expect(report['status'], 'loading');
      expect(report['duration_s'], isNull);
    });

    test('statuts : erreur, fin, lecture, pause, chargement', () {
      const loaded = PlaybackState(duration: Duration(seconds: 1));
      expect(playerStatusOf(loaded.copyWith(error: 'x')), 'error');
      expect(playerStatusOf(loaded.copyWith(completed: true)), 'ended');
      expect(playerStatusOf(loaded.copyWith(playing: true)), 'playing');
      expect(playerStatusOf(loaded), 'paused');
      expect(playerStatusOf(const PlaybackState()), 'loading');
    });
  });
}
