// Envoi des touches : POST /api/remote/input (contrat), désappairage
// DELETE /api/session, raccourcis sur les routes provisoires.
import 'package:epikodi_client/epikodi_client.dart';
import 'package:epikodi_remote/remote/tv_commands.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  late FixtureBackend backend;
  late EpikodiClient client;

  setUp(() {
    backend = FixtureBackend();
    backend.on('POST', '/api/remote/shortcut', (_) => (200, {'ok': true}));
    client =
        EpikodiClient(baseUrl: 'http://tv.test', httpClient: backend.client)
          ..token = 'mc_token';
  });

  test('touche : POST /api/remote/input, forme de remote/input_request.json',
      () async {
    await HttpTvCommands(client).key(TvKey.up);
    final sent = backend.last('POST', '/api/remote/input')!;
    expect(sent.json, readFixture('remote/input_request.json'));
    expect(sent.headers['Authorization'], 'Bearer mc_token');
    expect(backend.routeFor('POST', '/api/remote/input')!.status, 204);
  });

  test('toutes les touches font partie de celles du contrat', () async {
    const contract = {
      'up', 'down', 'left', 'right', 'ok', 'back', 'home', //
      'menu', 'info', 'play_pause',
    };
    for (final k in TvKey.values) {
      expect(contract, contains(k.name), reason: k.name);
    }
  });

  test('désappairage : DELETE /api/session', () async {
    await HttpTvCommands(client).unpair();
    expect(backend.last('DELETE', '/api/session'), isNotNull);
  });

  test('désappairage refusé : pas d\'erreur, le téléphone oublie quand même',
      () async {
    backend.fail('DELETE', '/api/session', status: 401, code: 'unauthorized');
    await expectLater(HttpTvCommands(client).unpair(), completes);
  });

  test('jeton refusé (TV désappairée) : onUnauthorized', () async {
    backend.fail('POST', '/api/remote/input',
        status: 401, code: 'unauthorized');
    var calls = 0;
    final commands = HttpTvCommands(client)..onUnauthorized = () => calls++;
    await commands.key(TvKey.ok);
    expect(calls, 1);
  });

  test('autre erreur : ignorée, pas de retour à la connexion', () async {
    backend.fail('POST', '/api/remote/input',
        status: 422, code: 'validation_failed');
    var calls = 0;
    final commands = HttpTvCommands(client)..onUnauthorized = () => calls++;
    await expectLater(commands.key(TvKey.ok), completes);
    expect(calls, 0);
  });

  test('raccourci : POST /api/remote/shortcut (route provisoire)', () async {
    await HttpTvCommands(client).shortcut(TvShortcut.profile);
    expect(backend.last('POST', '/api/remote/shortcut')!.json,
        {'shortcut': 'profile'});
    await HttpTvCommands(client).shortcut(TvShortcut.switchProfile);
    expect(backend.last('POST', '/api/remote/shortcut')!.json,
        {'shortcut': 'switch_profile'});
  });
}
