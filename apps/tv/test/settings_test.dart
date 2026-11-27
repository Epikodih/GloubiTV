// Paramètres : dossiers scannés par le media center (menu du profil).
import 'package:design_system/design_system.dart';
import 'package:epikodi_tv/api/api.dart';
import 'package:epikodi_tv/library/library_screen.dart';
import 'package:epikodi_tv/library/library_sidebar.dart';
import 'package:epikodi_tv/settings/sources_screen.dart';
import 'package:epikodi_tv/widgets/profile_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

Map<String, dynamic> get marc => Map<String, dynamic>.of(
    readFixture('session/select_response.json')['profile']);

void main() {
  late FixtureBackend backend;
  setUp(() => backend = FixtureBackend());

  Finder key(String k) => find.byKey(ValueKey(k));

  test('chemin -> URI du dossier', () {
    expect(sourceUri(r'D:\Films'), 'file:///D:/Films');
    expect(sourceUri('D:/Films/'), 'file:///D:/Films/');
    expect(sourceUri('/mnt/films'), 'file:///mnt/films');
    expect(sourceUri('  smb://nas/films '), 'smb://nas/films');
    expect(sourceUri(r'\\nas\films'), 'file://nas/films');
  });

  group('Api', () {
    late Api api;
    setUp(() => api = Api(fixtureClient(backend).http));

    test('fetchSources lit sources/list.json', () async {
      final list = await api.fetchSources();
      expect(list, hasLength(2));
      expect(list.first['uri'], 'file:///D:/Films');
    });

    test('addSource : forme de sources/create_request.json', () async {
      final created =
          await api.addSource('file:///D:/Musique', name: 'Musique');
      final sent = backend.last('POST', '/api/sources')!.json;
      expect(sent, readFixture('sources/create_request.json'));
      expect(created['id'], 3);

      await api.addSource('file:///D:/X');
      expect(backend.last('POST', '/api/sources')!.json.keys, ['uri'],
          reason: 'nom facultatif');
    });

    test('removeSource : DELETE /api/sources/{id}', () async {
      await api.removeSource(2);
      expect(backend.last('DELETE', '/api/sources/2'), isNotNull);
    });

    test('scanSources sans dossier : tout, sans corps', () async {
      final started = await api.scanSources();
      final sent = backend.last('POST', '/api/sources/scan')!;
      expect(sent.body, isNull, reason: 'pas de corps = tout rescanner');
      expect(started.single['uri'], 'file:///D:/Films',
          reason: 'lit scanning de sources/scan_response.json');
      await api.scanSources(uris: []);
      expect(backend.last('POST', '/api/sources/scan')!.body, isNull);
    });

    test('scanSources avec dossiers : forme de sources/scan_request.json',
        () async {
      await api.scanSources(uris: ['file:///D:/Films']);
      expect(backend.last('POST', '/api/sources/scan')!.json,
          readFixture('sources/scan_request.json'));
      expect(backend.routeFor('POST', '/api/sources/scan')!.status, 202);
    });
  });

  testWidgets('menu de gauche : pas de « Paramètres » (menu du profil seulement)',
      (tester) async {
    await pumpTv(
      tester,
      LibraryScreen(
        api: Api(fixtureClient(backend).http),
        profile: marc,
        onChangeProfile: () {},
        onBackToPairing: () {},
      ),
    );
    await settle(tester);
    expect(key('nav-settings'), findsNothing);
    expect(
        find.descendant(
            of: find.byType(LibrarySidebar),
            matching: find.byIcon(Icons.settings_rounded)),
        findsNothing);
  });

  group('menu du profil', () {
    Future<void> openMenu(
        WidgetTester tester, Map<String, dynamic> profile) async {
      await pumpTv(
        tester,
        LibraryScreen(
          api: Api(fixtureClient(backend).http),
          profile: profile,
          onChangeProfile: () {},
          onBackToPairing: () {},
        ),
      );
      await settle(tester);
      await tester.tap(find.byType(ProfileMenuButton));
      await tester.pumpAndSettle();
    }

    testWidgets('compte sans restriction : « Paramètres » sous « Profil »',
        (tester) async {
      await openMenu(tester, marc);
      expect(find.text(fr.settings), findsOneWidget);
      expect(tester.getTopLeft(find.text(fr.settings)).dy,
          greaterThan(tester.getTopLeft(find.text(fr.profile)).dy));
      expect(tester.getTopLeft(find.text(fr.settings)).dy,
          lessThan(tester.getTopLeft(find.text(fr.pairingButton)).dy));

      await tester.tap(find.text(fr.settings));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SourcesScreen), findsOneWidget);
    });

    testWidgets('invité : « Paramètres » disponible (choisir ses dossiers)',
        (tester) async {
      await openMenu(tester, {'kind': 'guest', 'id': null, 'name': null});
      expect(find.text(fr.settings), findsOneWidget,
          reason: 'sans compte, il faut pouvoir ajouter des dossiers');
      await tester.tap(find.text(fr.settings));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SourcesScreen), findsOneWidget);
    });

    testWidgets('compte restreint : pas de « Paramètres »', (tester) async {
      await openMenu(tester, {...marc, 'is_restricted': true});
      expect(find.text(fr.settings), findsNothing);
    });

    testWidgets('retour avec un dossier ajouté : la médiathèque se recharge',
        (tester) async {
      await openMenu(tester, marc);
      await tester.tap(find.text(fr.settings));
      await settle(tester);
      await tester.pumpAndSettle();
      final before = backend.calls('GET', '/api/media').length;

      await tester.enterText(key('source-path'), r'D:\Musique');
      await tester.tap(key('source-add'));
      await settle(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SourcesScreen), findsNothing);
      expect(backend.calls('GET', '/api/media').length, before + 1);
    });

    testWidgets('retour sans changement : pas de rechargement', (tester) async {
      await openMenu(tester, marc);
      await tester.tap(find.text(fr.settings));
      await settle(tester);
      await tester.pumpAndSettle();
      final before = backend.calls('GET', '/api/media').length;
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SourcesScreen), findsNothing);
      expect(backend.calls('GET', '/api/media').length, before);
    });
  });

  group('écran des dossiers', () {
    Future<void> pumpSources(WidgetTester tester,
        {FolderPicker? pick, Size size = const Size(1920, 1080)}) async {
      await pumpTv(
        tester,
        SourcesScreen(api: Api(fixtureClient(backend).http), pickFolder: pick),
        size: size,
      );
      await settle(tester);
    }

    String? message(WidgetTester tester) =>
        tester.widgetList<Text>(key('sources-message')).firstOrNull?.data;

    testWidgets('liste : nom, chemin, état, dernier scan, nombre de médias',
        (tester) async {
      await pumpSources(tester);
      expect(find.text('Films'), findsOneWidget);
      expect(find.text('file:///D:/Films'), findsOneWidget);
      expect(find.text('smb://nas/series'), findsOneWidget);
      expect(find.text(fr.sourceOnline), findsOneWidget);
      expect(find.text(fr.sourceOffline), findsOneWidget);
      expect(find.text(fr.neverScanned), findsOneWidget);
      expect(find.textContaining('Dernier scan'), findsOneWidget);
      expect(find.text(fr.sourceMediaCount(6)), findsOneWidget);
      // Un dossier local et un partage réseau n'ont pas la même icône.
      expect(find.byIcon(Icons.lan_rounded), findsOneWidget);
    });

    testWidgets('aucun dossier : message', (tester) async {
      backend.on('GET', '/api/sources', (_) => (200, {'sources': []}));
      await pumpSources(tester);
      expect(key('no-sources'), findsOneWidget);
    });

    testWidgets('ajouter un chemin tapé : POST, message, liste rechargée',
        (tester) async {
      await pumpSources(tester);
      await tester.enterText(key('source-path'), r'D:\Musique');
      await tester.tap(key('source-add'));
      await settle(tester);
      expect(backend.last('POST', '/api/sources')!.json,
          {'uri': 'file:///D:/Musique'});
      expect(message(tester), fr.sourceAdded('Musique'));
      expect(backend.calls('GET', '/api/sources'), hasLength(2));
      expect(find.widgetWithText(TextField, r'D:\Musique'), findsNothing,
          reason: 'champ vidé');
    });

    testWidgets('champ vide : message, aucune requête', (tester) async {
      await pumpSources(tester);
      await tester.tap(key('source-add'));
      await tester.pump();
      expect(message(tester), fr.enterFolder);
      expect(backend.calls('POST', '/api/sources'), isEmpty);
    });

    testWidgets('« Parcourir… » remplit le champ avec le dossier choisi',
        (tester) async {
      await pumpSources(tester, pick: () async => r'E:\Séries');
      await tester.tap(key('source-browse'));
      await settle(tester);
      expect(find.widgetWithText(TextField, r'E:\Séries'), findsOneWidget);
    });

    testWidgets('sélecteur indisponible : message', (tester) async {
      await pumpSources(tester, pick: () async => throw Exception('non'));
      await tester.tap(key('source-browse'));
      await settle(tester);
      expect(message(tester), fr.folderPickError);
    });

    testWidgets('erreur du serveur (dossier introuvable) : message',
        (tester) async {
      backend.fail('POST', '/api/sources',
          status: 422,
          code: 'validation_failed',
          message: 'Dossier introuvable.');
      await pumpSources(tester);
      await tester.enterText(key('source-path'), r'Z:\Rien');
      await tester.tap(key('source-add'));
      await settle(tester);
      expect(message(tester), 'Dossier introuvable.');
    });

    testWidgets('Rescanner un dossier : POST /api/sources/scan avec son URI',
        (tester) async {
      await pumpSources(tester);
      await tester.tap(
          find.descendant(of: key('source-1'), matching: key('source-scan')));
      await settle(tester);
      expect(backend.last('POST', '/api/sources/scan')!.json, {
        'uris': ['file:///D:/Films']
      });
      expect(message(tester), fr.scanStarted('Films'));
    });

    testWidgets('« Tout scanner » : POST /api/sources/scan sans corps',
        (tester) async {
      backend.on(
          'POST',
          '/api/sources/scan',
          (_) => (
                202,
                {
                  'scanning': [
                    {'id': 1, 'name': 'Films', 'uri': 'file:///D:/Films'},
                    {'id': 2, 'name': 'series', 'uri': 'smb://nas/series'},
                  ]
                }
              ));
      await pumpSources(tester);
      expect(find.text(fr.scanAll), findsOneWidget);
      await tester.tap(key('sources-scan-all'));
      await settle(tester);
      expect(backend.last('POST', '/api/sources/scan')!.body, isNull);
      expect(message(tester), fr.scanAllStarted(2));
      expect(backend.calls('GET', '/api/sources'), hasLength(2),
          reason: 'liste rechargée (dernier scan)');
    });

    testWidgets('« Tout scanner » refusé : message du serveur', (tester) async {
      backend.fail('POST', '/api/sources/scan',
          status: 403, code: 'settings_forbidden', message: 'Interdit.');
      await pumpSources(tester);
      await tester.tap(key('sources-scan-all'));
      await settle(tester);
      expect(message(tester), 'Interdit.');
    });

    testWidgets('Retirer : confirmation, « Annuler » ne fait rien',
        (tester) async {
      await pumpSources(tester);
      await tester.ensureVisible(
          find.descendant(of: key('source-2'), matching: key('source-remove')));
      await tester.pumpAndSettle();
      await tester.tap(
          find.descendant(of: key('source-2'), matching: key('source-remove')));
      await tester.pumpAndSettle();
      expect(find.text(fr.removeSourceConfirm('series')), findsOneWidget);
      // « Annuler » a le focus.
      expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<FocusableCard>()
              ?.semanticLabel,
          fr.cancel);
      await tester.tap(find.text(fr.cancel));
      await tester.pumpAndSettle();
      expect(backend.calls('DELETE', '/api/sources/{id}'), isEmpty);

      await tester.ensureVisible(
          find.descendant(of: key('source-2'), matching: key('source-remove')));
      await tester.pumpAndSettle();
      await tester.tap(
          find.descendant(of: key('source-2'), matching: key('source-remove')));
      await tester.pumpAndSettle();
      await tester.tap(key('confirm-remove'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(backend.last('DELETE', '/api/sources/2'), isNotNull);
      expect(message(tester), fr.sourceRemoved('series'));
      expect(backend.calls('GET', '/api/sources'), hasLength(2));
    });

    testWidgets('chargement impossible : message et « Réessayer »',
        (tester) async {
      var n = 0;
      backend.on('GET', '/api/sources', (_) {
        n++;
        return n == 1
            ? (
                403,
                FixtureBackend.errorBody('settings_forbidden',
                    message: 'Interdit.')
              )
            : (200, readFixture('sources/list.json'));
      });
      await pumpSources(tester);
      expect(find.text('Interdit.'), findsOneWidget);
      await tester.tap(find.text(fr.retry));
      await settle(tester);
      expect(find.text('Films'), findsOneWidget);
    });

    testWidgets('fenêtre minimale : pas de débordement', (tester) async {
      await pumpSources(tester, size: const Size(960, 540));
      expect(tester.takeException(), isNull);
    });
  });
}
