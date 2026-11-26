// Messages du WebSocket du cœur (GET /api/ws) vus par le téléphone.
import 'dart:convert';

import 'package:epikodi_remote/remote/remote_events.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  test('adresse : ws://hôte:port/api/ws', () {
    expect(WsRemoteEvents.wsUri('http://192.168.1.31:7878/').toString(),
        'ws://192.168.1.31:7878/api/ws');
    expect(WsRemoteEvents.wsUri('https://tv.test').scheme, 'wss');
  });

  test('champ texte de la TV : aplati, compris par TextInputRequest', () {
    final field = readFixture('tv/text_input_request.json')
        as Map<String, dynamic>;
    final event = WsRemoteEvents.decode(
        jsonEncode({'type': 'text_input', 'data': field}))!;
    expect(event['type'], 'text_input');
    final request = TextInputRequest.fromEvent(event)!;
    expect(request.label, field['label']);
    expect(request.maxLength, field['max_length']);
    expect(request.number, isFalse);
  });

  test('champ quitté : pas de clavier', () {
    final event = WsRemoteEvents.decode(jsonEncode({
      'type': 'text_input',
      'data': {'active': false}
    }))!;
    expect(TextInputRequest.fromEvent(event), isNull);
  });

  test('jeton révoqué : unauthorized', () {
    final event = WsRemoteEvents.decode(jsonEncode({
      'type': 'error',
      'data': {'code': 'unauthorized', 'message': 'Jeton invalide.'}
    }));
    expect(event, {'type': 'unauthorized'});
  });

  test('autres messages : gardés tels quels ou ignorés', () {
    expect(
        WsRemoteEvents.decode(jsonEncode({
          'type': 'player.state',
          'data': {'status': 'playing'}
        })),
        {'type': 'player.state', 'status': 'playing'});
    expect(WsRemoteEvents.decode('pas du json'), isNull);
    expect(WsRemoteEvents.decode(42), isNull);
  });
}
