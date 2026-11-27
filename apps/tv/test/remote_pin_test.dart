// Code PIN tapé sur le téléphone : la TV annonce la saisie (pavé numérique
// à la place des flèches) et les chiffres reçus remplissent ses popups PIN.
import 'dart:async';

import 'package:epikodi_tv/accounts/pin_dialog.dart';
import 'package:epikodi_tv/player/server_player.dart';
import 'package:epikodi_tv/remote/remote_keys.dart';
import 'package:epikodi_tv/widgets/pin_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

class _Link implements PlayerLink {
  final _c = StreamController<Map<String, dynamic>>.broadcast();
  void emit(Map<String, dynamic> e) => _c.add(e);
  @override
  Stream<Map<String, dynamic>> get events => _c.stream;
  @override
  Future<void> report(Map<String, dynamic> state) async {}
  @override
  void close() => _c.close();
}

void main() {
  tearDown(() => remotePinEntry.value = null);

  RemoteKeyHandler handler() => RemoteKeyHandler(GlobalKey<NavigatorState>());

  test('annonce au téléphone : keyboard pin, masqué, 4 chiffres', () {
    final e = RemotePinEntry(label: 'Marc', onDigits: (_) {});
    expect(e.toJson(), {
      'active': true,
      'id': e.id,
      'label': 'Marc',
      'value': '',
      'obscure': true,
      'keyboard': 'pin',
      'max_length': 4,
    });
    expect(RemotePinEntry(label: 'x', onDigits: (_) {}).id, isNot(e.id),
        reason: 'nouvelle demande = nouvel identifiant');
  });

  test('texte du téléphone : va au PIN ouvert, pas au champ texte', () {
    final got = <String>[];
    showRemotePin(RemotePinEntry(label: 'Marc', onDigits: got.add));
    handler().handle({'text': '12', 'done': false});
    handler().handle({'text': '1a2 3', 'done': false});
    expect(got, ['12', '123'], reason: 'seulement les chiffres');

    hideRemotePin(remotePinEntry.value);
    expect(remotePinEntry.value, isNull);
  });

  group('popup du choix de compte (PinDialog)', () {
    Future<List<String>> open(WidgetTester tester,
        {String? Function(String pin)? check}) async {
      final tried = <String>[];
      await pumpTv(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => PinDialog(
                profileName: 'Marc',
                onSubmit: (pin) async {
                  tried.add(pin);
                  return check?.call(pin);
                },
              ),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      return tried;
    }

    testWidgets('chiffres du téléphone : code envoyé, popup fermée',
        (tester) async {
      final tried = await open(tester);
      final entry = remotePinEntry.value!;
      expect(entry.label, 'Marc');

      handler().handle({'text': '12'});
      await tester.pump();
      expect(find.byType(PinDialog), findsOneWidget);
      handler().handle({'text': '1234', 'done': true});
      await tester.pumpAndSettle();
      expect(tried, ['1234']);
      expect(find.byType(PinDialog), findsNothing);
      expect(remotePinEntry.value, isNull, reason: 'flèches de retour');
    });

    testWidgets('code faux : nouvelle demande au téléphone, avec l\'erreur',
        (tester) async {
      final tried = await open(tester,
          check: (pin) => pin == '1234' ? null : fr.pinWrong);
      final first = remotePinEntry.value!;
      handler().handle({'text': '0000'});
      await tester.pumpAndSettle();
      expect(find.byType(PinDialog), findsOneWidget);
      final second = remotePinEntry.value!;
      expect(second.id, isNot(first.id), reason: 'le téléphone efface');
      expect(second.label, fr.pinWrong);

      handler().handle({'text': '1234'});
      await tester.pumpAndSettle();
      expect(tried, ['0000', '1234']);
      expect(remotePinEntry.value, isNull);
    });
  });

  testWidgets('popup PIN générique (contrôle parental) : chiffres du téléphone',
      (tester) async {
    String? result;
    await pumpTv(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showPinDialog(context),
          child: const Text('ouvrir'),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(remotePinEntry.value!.label, fr.pinTitle);

    handler().handle({'text': '4321', 'done': true});
    await tester.pumpAndSettle();
    expect(result, '4321');
    expect(remotePinEntry.value, isNull);
  });

  testWidgets('RemoteKeyListener : annonce le PIN puis le retour aux flèches',
      (tester) async {
    final backend = FixtureBackend();
    final link = _Link();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      home: RemoteKeyListener(
        baseUrl: testBaseUrl,
        navigator: nav,
        createLink: () => link,
        createClient: () => fixtureClient(backend),
        child: const Scaffold(body: Text('accueil')),
      ),
    ));
    await tester.pump();

    final entry = RemotePinEntry(label: 'Marc', onDigits: (_) {});
    showRemotePin(entry);
    await tester.pump();
    final sent = backend.last('POST', '/api/tv/text-input')!.json;
    expect(sent['keyboard'], 'pin');
    expect(sent['id'], entry.id);
    expectSameShape(sent, readFixture('tv/text_input_request.json'));

    hideRemotePin(entry);
    await tester.pump();
    expect(backend.last('POST', '/api/tv/text-input')!.json, {'active': false},
        reason: 'aucun champ : les flèches reviennent');

    // Un message de la télécommande pendant le PIN arrive dans la popup.
    final got = <String>[];
    showRemotePin(RemotePinEntry(label: 'Marc', onDigits: got.add));
    link.emit({
      'type': 'remote.text',
      'data': {'text': '98', 'done': false}
    });
    await tester.pump();
    expect(got, ['98']);
    await tester.pumpWidget(const SizedBox());
  });
}

/// Mêmes clés que la fixture.
void expectSameShape(Map<String, dynamic> sent, Object? fixture) {
  expect(sent.keys.toSet(), (fixture as Map).keys.toSet());
}
