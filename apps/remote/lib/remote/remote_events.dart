import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Champ texte qui a le focus sur la TV : le téléphone ouvre son clavier.
/// Événement `{"type": "text_input", "active": true, ...}` du serveur.
class TextInputRequest {
  const TextInputRequest({
    required this.id,
    required this.label,
    required this.value,
    this.obscure = false,
    this.number = false,
    this.pin = false,
    this.maxLength,
  });

  /// `null` si l'événement n'annonce pas de champ (`active: false`).
  static TextInputRequest? fromEvent(Map<String, dynamic> json) {
    if (json['type'] != 'text_input' || json['active'] != true) return null;
    return TextInputRequest(
      id: (json['id'] as num?)?.toInt() ?? 0,
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
      obscure: json['obscure'] == true,
      number: json['keyboard'] == 'number',
      pin: json['keyboard'] == 'pin',
      maxLength: (json['max_length'] as num?)?.toInt(),
    );
  }

  /// Identifie le champ de la TV (change quand le focus passe à un autre).
  final int id;
  final String label;
  final String value;
  final bool obscure;
  final bool number;

  /// Code PIN demandé par la TV (`keyboard: "pin"`) : pavé numérique à la
  /// place des flèches, pas de clavier.
  final bool pin;
  final int? maxLength;
}

/// Flux d'événements du serveur vers le téléphone.
abstract class RemoteEventsSource {
  void start();
  void close();
}

/// WebSocket du cœur (`GET /api/ws`, avec le jeton du téléphone). Se
/// reconnecte tout seul si la connexion tombe.
///
/// Les messages `{"type": ..., "data": {...}}` sont aplatis pour l'écran :
/// `{"type": "text_input", "active": true, ...}`. Un jeton révoqué (la TV a
/// désappairé ce téléphone) donne `{"type": "unauthorized"}`, et on arrête.
class WsRemoteEvents implements RemoteEventsSource {
  WsRemoteEvents({
    required this.baseUrl,
    required this.token,
    required this.onEvent,
    this.retryDelay = const Duration(seconds: 3),
  });

  final String baseUrl;
  final String? token;
  final void Function(Map<String, dynamic> event) onEvent;
  final Duration retryDelay;

  WebSocket? _socket;
  bool _closed = false;

  @override
  void start() => _run();

  @override
  void close() {
    _closed = true;
    _socket?.close();
  }

  /// Adresse du WebSocket : `ws://hôte:port/api/ws`.
  static Uri wsUri(String baseUrl) {
    final base = Uri.parse(baseUrl.replaceFirst(RegExp(r'/+$'), ''));
    return base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws', path: '/api/ws');
  }

  /// Message du serveur -> événement pour l'écran (`null` : ignoré).
  static Map<String, dynamic>? decode(Object? message) {
    if (message is! String) return null;
    final Object? json;
    try {
      json = jsonDecode(message);
    } on FormatException {
      return null;
    }
    if (json is! Map<String, dynamic>) return null;
    final type = json['type'];
    final data = json['data'];
    if (type == 'error' && data is Map && data['code'] == 'unauthorized') {
      return const {'type': 'unauthorized'};
    }
    if (type is! String) return null;
    return {'type': type, if (data is Map<String, dynamic>) ...data};
  }

  Future<void> _run() async {
    while (!_closed) {
      try {
        final socket = await WebSocket.connect(
          wsUri(baseUrl).toString(),
          headers: {
            if (token != null) HttpHeaders.authorizationHeader: 'Bearer $token',
          },
        );
        if (_closed) {
          await socket.close();
          return;
        }
        _socket = socket;
        await for (final message in socket) {
          if (_closed) return;
          final event = decode(message);
          if (event == null) continue;
          onEvent(event);
          if (event['type'] == 'unauthorized') {
            _closed = true;
            await socket.close();
            return;
          }
        }
      } on WebSocketException catch (e) {
        // Jeton refusé dès l'ouverture (401) : désappairé.
        if (e.message.contains('401')) {
          onEvent(const {'type': 'unauthorized'});
          return;
        }
      } catch (_) {
        // serveur arrêté, réseau coupé : on réessaie
      }
      _socket = null;
      if (!_closed) await Future<void>.delayed(retryDelay);
    }
  }
}
