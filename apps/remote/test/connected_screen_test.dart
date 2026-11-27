// Télécommande une fois appairée : vérification du token, croix
// directionnelle, menu du profil (comme sur la TV), changement de compte.
import 'package:epikodi_remote/remote/pin_pad.dart';
import 'package:epikodi_remote/remote/tv_commands.dart';
import 'package:epikodi_remote/storage/remote_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

Map<String, dynamic> sessionWith(Object? profile) {
  final json = Map<String, dynamic>.of(
      readFixture('session/current.json') as Map<String, dynamic>);
  json['profile'] = profile;
  return json;
}

const guest = {
  'kind': 'guest',
  'id': null,
  'name': 'Invité',
  'icon': null,
  'language': 'fr',
  'age': 0,
  'is_restricted': true,
};

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('profile-menu')));
  await settle(tester);
}

Future<void> openSwitchSheet(WidgetTester tester) async {
  await openMenu(tester);
  await tester.tap(find.byKey(const ValueKey('menu-switchProfile')));
  await settle(tester);
}

void main() {
  group('lancement', () {
    testWidgets('sans TV appairée : connexion au serveur puis appairage',
        (tester) async {
      final world = TestWorld();
      await pumpRemote(tester, world);
      expect(find.text(fr.welcomeTitle), findsOneWidget);
      expect(world.backend.requests.map((r) => r.path), ['/api/health']);
      await unmount(tester);
    });

    testWidgets('TV appairée : session lue avec le token gardé',
        (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);

      final req = world.backend.last('GET', '/api/session')!;
      // (démarré déjà appairé : cas d'un retour dans l'app, pas d'un lancement)
      expect(req.headers['Authorization'],
          'Bearer mc_9fK2xQ7LrT3vB8nW5yZ1aD6hJ4sE0pUc');
      expect(world.baseUrls.single, 'http://192.168.1.42:7878');

      expect(find.byKey(const ValueKey('key-ok')), findsOneWidget);
      expect(button(fr.profileMenuSemantics('Léa')), findsOneWidget,
          reason: 'profil actif sur le bouton');
      expect(find.byKey(const ValueKey('key-ok')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Gloubi arrive, puis fait coucou une fois connecté',
        (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world, reducedMotion: false);

      // La session est déjà là, mais on laisse Gloubi finir son arrivée.
      expect(gloubiShowing('arrival.webp'), findsOneWidget);
      expect(find.text(fr.checking), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1400));
      await settle(tester);
      expect(find.byKey(const ValueKey('key-ok')), findsOneWidget);
      expect(gloubiShowing('wave.webp'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1700));
      expect(gloubiShowing('idle.webp'), findsWidgets);
      await unmount(tester);
    });

    testWidgets("relancer l'app : toujours un nouvel appairage",
        (tester) async {
      // Appairé lors d'un lancement précédent : on ne s'en sert pas.
      final world = TestWorld(saved: savedPairing(), connected: false);
      await pumpRemote(tester, world);
      expect(world.store.saved, isNull, reason: 'ancien token effacé');
      expect(world.backend.calls('GET', '/api/session'), isEmpty);
      expect(find.text(fr.welcomeTitle), findsOneWidget);
      await unmount(tester);
    });

    testWidgets("relancer l'app : l'adresse du serveur est gardée",
        (tester) async {
      final world = TestWorld(
          saved: savedPairing(), server: '10.0.0.7:9000', connected: false);
      await pumpRemote(tester, world);
      expect(world.store.server, '10.0.0.7:9000');
      expect(find.text(fr.serverLabel('10.0.0.7:9000')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('token sans expiration : gardé', (tester) async {
      final world = TestWorld(
        saved: const SavedPairing(
          host: '192.168.1.42',
          port: 7878,
          token: 'mc_9fK2xQ7LrT3vB8nW5yZ1aD6hJ4sE0pUc',
          expiresAt: null,
          deviceName: 'Pixel 7',
        ),
      );
      await pumpRemote(tester, world);
      expect(find.byKey(const ValueKey('key-ok')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets(
        'TV désappairée (« Appairage » sur la TV) : la touche suivante '
        'ramène à la connexion', (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);
      expect(find.byKey(const ValueKey('key-ok')), findsOneWidget);

      // Le serveur refuse le jeton à la prochaine touche.
      world.commands.rejectToken();
      await settle(tester);
      expect(world.store.saved, isNull, reason: 'TV oubliée');
      expect(find.text(fr.welcomeTitle), findsOneWidget);
      expect(find.text(fr.sessionExpired), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('TV désappairée : le serveur prévient tout de suite (WebSocket)',
        (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);
      world.events.emit({'type': 'unauthorized'});
      await settle(tester);
      expect(world.store.saved, isNull);
      expect(find.text(fr.sessionExpired), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('token refusé (unauthorized) : retour à l\'appairage',
        (tester) async {
      final world = TestWorld(saved: savedPairing());
      world.backend
          .fail('GET', '/api/session', status: 401, code: 'unauthorized');
      await pumpRemote(tester, world);

      expect(world.store.saved, isNull);
      expect(find.text(fr.welcomeTitle), findsOneWidget);
      expect(find.text(fr.sessionExpired), findsOneWidget);
      expect(gloubiShowing('worried.png'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('TV injoignable : Gloubi inquiet en boucle, puis réessayer',
        (tester) async {
      final world = TestWorld(saved: savedPairing())..offline = true;
      await pumpRemote(tester, world, reducedMotion: false);
      await tester.pump(const Duration(milliseconds: 1400));
      await settle(tester);

      expect(find.text(fr.tvUnreachableTitle), findsOneWidget);
      expect(gloubiShowing('worried.webp'), findsOneWidget);
      expect(world.store.saved, isNotNull, reason: 'la TV n\'est pas oubliée');

      await tester.pump(const Duration(seconds: 5));
      expect(gloubiShowing('worried.webp'), findsOneWidget);

      world.offline = false;
      await tester.tap(button(fr.retry));
      await settle(tester);
      expect(find.byKey(const ValueKey('key-ok')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('télécommande', () {
    testWidgets('flèches, OK, Retour, Accueil : envoyés à la TV',
        (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);

      for (final k in ['up', 'right', 'down', 'left', 'ok', 'back', 'home']) {
        await tester.tap(find.byKey(ValueKey('key-$k')));
        await tester.pump();
      }
      expect(world.commands.sent, [
        TvKey.up,
        TvKey.right,
        TvKey.down,
        TvKey.left,
        TvKey.ok,
        TvKey.back,
        TvKey.home,
      ]);
      await unmount(tester);
    });

    testWidgets('glisser le doigt sur le pavé : flèche', (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);
      final ok = find.byKey(const ValueKey('key-ok'));
      await tester.fling(ok, const Offset(150, 0), 1500);
      await tester.fling(ok, const Offset(0, -150), 1500);
      await settle(tester);
      expect(world.commands.sent, [TvKey.right, TvKey.up]);
      await unmount(tester);
    });

    testWidgets("pas d'adresse IP affichée sur la télécommande",
        (tester) async {
      await pumpRemote(tester, TestWorld(saved: savedPairing()));
      expect(find.textContaining('192.168.1.42'), findsNothing);
      await unmount(tester);
    });

    testWidgets('chaque touche a un libellé pour le lecteur d\'écran',
        (tester) async {
      await pumpRemote(tester, TestWorld(saved: savedPairing()));
      for (final label in [
        fr.keyUp,
        fr.keyDown,
        fr.keyLeft,
        fr.keyRight,
        fr.keyOk,
        fr.keyBack,
        fr.keyHome,
      ]) {
        expect(button(label), findsOneWidget, reason: label);
      }
      await unmount(tester);
    });

    testWidgets('petit écran : rien ne déborde', (tester) async {
      await pumpRemote(tester, TestWorld(saved: savedPairing()),
          size: const Size(320, 568));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('key-ok')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('menu du profil', () {
    testWidgets('mêmes entrées que sur la TV', (tester) async {
      await pumpRemote(tester, TestWorld(saved: savedPairing()));
      await openMenu(tester);

      expect(find.text(fr.profile), findsOneWidget);
      expect(find.text(fr.switchProfile), findsOneWidget);
      expect(find.text(fr.pairingMenu), findsOneWidget);
      expect(find.text(fr.infoMenu), findsOneWidget);
      expect(find.text('Léa'), findsOneWidget, reason: 'en-tête du menu');
      await unmount(tester);
    });

    testWidgets('profil (avatar + flèche) et langue côte à côte, au centre',
        (tester) async {
      for (final width in [412.0, 320.0]) {
        await pumpRemote(tester, TestWorld(saved: savedPairing()),
            size: Size(width, 800));
        final button =
            tester.getRect(find.byKey(const ValueKey('profile-menu')));
        final lang =
            tester.getRect(find.byKey(const ValueKey('language-toggle')));
        expect(find.text('Léa'), findsNothing, reason: 'pas de nom affiché');
        expect(((button.left + lang.right) / 2 - width / 2).abs(),
            lessThan(1), reason: 'centrés');

        // Le menu tient dans l'écran et affiche le nom en entier.
        await openMenu(tester);
        expect(find.text('Léa'), findsOneWidget);
        for (final item in ['menu-profile', 'menu-info']) {
          final r = tester.getRect(find.byKey(ValueKey(item)));
          expect(r.left, greaterThanOrEqualTo(0), reason: '$item à gauche');
          expect(r.right, lessThanOrEqualTo(width), reason: '$item à droite');
        }
        expect(tester.takeException(), isNull);
        await unmount(tester);
      }
    });

    testWidgets('« Profil » : raccourci envoyé à la TV', (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);
      await openMenu(tester);

      await tester.tap(find.byKey(const ValueKey('menu-profile')));
      await settle(tester);
      expect(world.commands.sent, [TvShortcut.profile]);
      expect(find.text(fr.switchProfile), findsNothing, reason: 'menu fermé');
      await unmount(tester);
    });

    testWidgets('aucun profil : « Choisir un profil », sans « Profil »',
        (tester) async {
      final world = TestWorld(saved: savedPairing());
      world.backend.on('GET', '/api/session', (_) => (200, sessionWith(null)));
      await pumpRemote(tester, world);
      expect(button(fr.profileMenuSemantics(fr.noProfile)), findsOneWidget);

      await openMenu(tester);
      expect(find.byKey(const ValueKey('menu-profile')), findsNothing);
      expect(find.text(fr.switchProfile), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('profil invité', (tester) async {
      final world = TestWorld(saved: savedPairing());
      world.backend.on('GET', '/api/session', (_) => (200, sessionWith(guest)));
      await pumpRemote(tester, world);
      expect(button(fr.profileMenuSemantics(fr.guestProfile)), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('« Appairage » : confirmation, puis la TV est oubliée',
        (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);

      await openMenu(tester);
      await tester.tap(find.byKey(const ValueKey('menu-pairing')));
      await settle(tester);
      expect(find.text(fr.pairingConfirmTitle), findsOneWidget);

      // Annuler : rien ne change.
      await tester.tap(find.text(fr.cancel));
      await settle(tester);
      expect(world.store.saved, isNotNull);

      await openMenu(tester);
      await tester.tap(find.byKey(const ValueKey('menu-pairing')));
      await settle(tester);
      expect(world.commands.unpairs, 0, reason: 'annulé : rien envoyé');
      await tester.tap(find.byKey(const ValueKey('confirm-pairing')));
      await settle(tester);
      expect(world.commands.unpairs, 1, reason: 'la TV revient à l\'appairage');
      expect(world.store.saved, isNull);
      expect(find.text(fr.welcomeTitle), findsOneWidget);
      await unmount(tester);
    });
  });

  group('infos', () {
    Future<void> openInfo(WidgetTester tester) async {
      await openMenu(tester);
      await tester.tap(find.byKey(const ValueKey('menu-info')));
      await settle(tester);
    }

    testWidgets("affiche l'adresse du serveur, le téléphone, le profil",
        (tester) async {
      await pumpRemote(tester, TestWorld(saved: savedPairing()));
      await openInfo(tester);

      expect(find.text(fr.infoTitle), findsOneWidget);
      final field = tester
          .widget<TextField>(find.byKey(const ValueKey('address-field')));
      expect(field.controller!.text, '192.168.1.42');
      expect(find.text('Pixel 7'), findsOneWidget);
      expect(find.text('Léa'), findsWidgets);

      // Retour : la télécommande, sans rien changer.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await settle(tester);
      expect(find.byKey(const ValueKey('key-ok')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets("changer d'adresse : confirmation, quitte la TV, reconnecte",
        (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);
      await openInfo(tester);

      await tester.enterText(
          find.byKey(const ValueKey('address-field')), '10.0.2.2');
      await tester.tap(button(fr.save));
      await settle(tester);
      expect(find.text(fr.changeServerConfirmTitle), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('confirm-server')));
      await settle(tester);
      expect(world.commands.unpairs, 1, reason: 'quitte la TV actuelle');
      expect(world.store.server, '10.0.2.2:7878');
      expect(world.store.saved, isNull, reason: 'nouvel appairage');
      expect(world.baseUrls.last, 'http://10.0.2.2:7878');
      expect(find.text(fr.welcomeTitle), findsOneWidget);
      expect(find.text(fr.serverLabel('10.0.2.2')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('adresse invalide : message', (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);
      await openInfo(tester);
      await tester.enterText(
          find.byKey(const ValueKey('address-field')), 'pas une adresse');
      await tester.tap(button(fr.save));
      await settle(tester);
      expect(find.text(fr.addressInvalid), findsOneWidget);
      expect(world.store.saved, isNotNull);
      await unmount(tester);
    });
  });

  group('changer de profil', () {
    testWidgets('la TV affiche « Qui regarde ? » : pas de menu sur le téléphone',
        (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);
      await openMenu(tester);
      await tester.tap(find.byKey(const ValueKey('menu-switchProfile')));
      await settle(tester);

      expect(world.commands.sent, [TvShortcut.switchProfile]);
      expect(find.byType(BottomSheet), findsNothing,
          reason: 'le compte se choisit sur la TV');
      expect(world.backend.calls('POST', '/api/session/profile'), isEmpty);
      expect(find.byKey(const ValueKey('key-up')), findsOneWidget,
          reason: 'les flèches pour choisir sur la TV');
      await unmount(tester);
    });

    testWidgets('profil choisi sur la TV : le téléphone suit (profile.changed)',
        (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);

      world.events.emit({'type': 'profile.changed', 'profile': null});
      await settle(tester);
      world.events.emit({
        'type': 'profile.changed',
        'profile': {
          'kind': 'account',
          'id': 2,
          'name': 'Léa',
          'icon': 'avatar_07',
          'language': 'fr',
          'age': 10,
          'is_restricted': true,
        },
      });
      await settle(tester);
      expect(button(fr.profileMenuSemantics('Léa')), findsOneWidget);
      await unmount(tester);
    });
  });

  testWidgets('en anglais', (tester) async {
    final world = TestWorld(saved: savedPairing());
    await pumpRemote(tester, world, locale: const Locale('en'));
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    await openMenu(tester);
    expect(find.text('Switch profile'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Retour / Accueil : tout le bouton est cliquable, pas que le texte',
      (tester) async {
    final world = TestWorld(saved: savedPairing());
    await pumpRemote(tester, world);
    final back = tester.getRect(find.byKey(const ValueKey('key-back')));
    final home = tester.getRect(find.byKey(const ValueKey('key-home')));
    expect(back.height, greaterThanOrEqualTo(60), reason: 'grande cible');
    expect(back.width, greaterThan(100));

    // Près des bords, loin de l'icône et du texte.
    await tester.tapAt(back.topLeft + const Offset(12, 8));
    await tester.tapAt(back.bottomRight - const Offset(6, 6));
    await tester.tapAt(home.centerRight - const Offset(10, 0));
    await tester.pump();
    expect(world.commands.sent, [TvKey.back, TvKey.back, TvKey.home]);
    await unmount(tester);
  });

  testWidgets(
      'erreur (« La TV ne connaît plus ce téléphone ») : popup qui disparaît '
      'toute seule', (tester) async {
    final world = TestWorld(saved: savedPairing());
    await pumpRemote(tester, world);
    world.events.emit({'type': 'unauthorized'});
    await settle(tester);
    final toast = find.byKey(const ValueKey('error-toast'));
    expect(toast, findsOneWidget);
    expect(find.descendant(of: toast, matching: find.text(fr.sessionExpired)),
        findsOneWidget);
    // En haut de l'écran, par-dessus la page.
    expect(tester.getTopLeft(toast).dy, lessThan(120));

    await tester.pump(const Duration(seconds: 3));
    expect(toast, findsOneWidget, reason: 'encore là');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(toast, findsNothing, reason: 'partie toute seule');
    await unmount(tester);
  });

  group('code PIN demandé sur la TV', () {
    Map<String, dynamic> pin({int id = 7, String label = 'Marc'}) => {
          'type': 'text_input',
          'active': true,
          'id': id,
          'label': label,
          'value': '',
          'obscure': true,
          'keyboard': 'pin',
          'max_length': 4,
        };

    testWidgets('le pavé numérique remplace les flèches, Retour/Accueil restent',
        (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);
      expect(find.byKey(const ValueKey('key-up')), findsOneWidget);

      world.events.emit(pin());
      await settle(tester);
      expect(find.byType(PinPad), findsOneWidget);
      expect(find.text('Marc'), findsWidgets);
      expect(find.byKey(const ValueKey('key-up')), findsNothing,
          reason: 'plus de flèches');
      expect(find.byKey(const ValueKey('key-ok')), findsNothing);
      expect(find.byKey(const ValueKey('key-back')), findsOneWidget);
      expect(find.byKey(const ValueKey('key-home')), findsOneWidget);
      expect(find.byKey(const ValueKey('tv-text-field')), findsNothing,
          reason: 'pas de clavier texte');

      // Retour marche toujours (ferme la popup PIN sur la TV).
      await tester.tap(find.byKey(const ValueKey('key-back')));
      await settle(tester);
      expect(world.commands.sent, [TvKey.back]);
      await unmount(tester);
    });

    testWidgets('chaque chiffre envoie la saisie, le dernier valide',
        (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);
      world.events.emit(pin());
      await settle(tester);

      for (final d in ['1', '2']) {
        await tester.tap(find.byKey(ValueKey('pin-$d')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('pin-erase')));
      await tester.pump();
      for (final d in ['3', '4', '5']) {
        await tester.tap(find.byKey(ValueKey('pin-$d')));
        await tester.pump();
      }
      expect(world.commands.texts, [
        ('1', false),
        ('12', false),
        ('1', false),
        ('13', false),
        ('134', false),
        ('1345', true),
      ]);
      // Le code n'est jamais affiché en clair.
      expect(find.text('1345'), findsNothing);
      await unmount(tester);
    });

    testWidgets('code faux (nouvelle demande) : saisie effacée, message',
        (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);
      world.events.emit(pin(id: 7));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('pin-9')));
      await tester.pump();

      world.events.emit(pin(id: 8, label: 'Code PIN incorrect.'));
      await settle(tester);
      expect(find.text('Code PIN incorrect.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pin-1')));
      await tester.pump();
      expect(world.commands.texts.last, ('1', false),
          reason: 'repart de zéro');
      await unmount(tester);
    });

    testWidgets('popup PIN fermée sur la TV : les flèches reviennent',
        (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);
      world.events.emit(pin());
      await settle(tester);
      world.events.emit({'type': 'text_input', 'active': false});
      await settle(tester);
      expect(find.byType(PinPad), findsNothing);
      expect(find.byKey(const ValueKey('key-up')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('petit écran : pas de débordement', (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world, size: const Size(320, 568));
      world.events.emit(pin());
      await settle(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('clavier pour la TV', () {
    Map<String, dynamic> field({int id = 1, String value = ''}) => {
          'type': 'text_input',
          'active': true,
          'id': id,
          'label': 'Nom',
          'value': value,
          'obscure': false,
          'keyboard': 'text',
          'max_length': 20,
        };

    testWidgets("champ texte sur la TV : le clavier s'ouvre", (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);
      expect(world.events.started, isTrue);

      world.events.emit(field(value: 'Lé'));
      await settle(tester);
      expect(find.text('Nom'), findsOneWidget);
      final input = tester
          .widget<TextField>(find.byKey(const ValueKey('tv-text-field')));
      expect(input.controller!.text, 'Lé', reason: 'texte déjà sur la TV');
      expect(input.maxLength, 20);
      await unmount(tester);
    });

    testWidgets('chaque lettre part sur la TV, Valider ferme le clavier',
        (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);
      world.events.emit(field());
      await settle(tester);

      await tester.enterText(
          find.byKey(const ValueKey('tv-text-field')), 'Léa');
      await tester.tap(button(fr.keyboardDone));
      await settle(tester);
      expect(world.commands.texts, [('Léa', false), ('Léa', true)]);
      expect(find.byKey(const ValueKey('tv-text-field')), findsNothing);
      await unmount(tester);
    });

    testWidgets('la TV quitte le champ : le clavier se ferme', (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);
      world.events.emit(field());
      await settle(tester);
      expect(find.byKey(const ValueKey('tv-text-field')), findsOneWidget);

      world.events.emit({'type': 'text_input', 'active': false});
      await settle(tester);
      expect(find.byKey(const ValueKey('tv-text-field')), findsNothing);
      expect(find.byKey(const ValueKey('key-ok')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('autre champ sur la TV : le clavier repart de son texte',
        (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);
      world.events.emit(field(id: 1, value: 'abc'));
      await settle(tester);
      world.events.emit(field(id: 2, value: 'xyz'));
      await settle(tester);
      final input = tester
          .widget<TextField>(find.byKey(const ValueKey('tv-text-field')));
      expect(input.controller!.text, 'xyz');
      await unmount(tester);
    });

    testWidgets('fermé à la main, puis OK sur la TV : il se rouvre',
        (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);
      world.events.emit(field());
      await settle(tester);
      await tester.tap(find.byTooltip(fr.keyboardClose));
      await settle(tester);
      expect(find.byKey(const ValueKey('tv-text-field')), findsNothing);
      expect(world.commands.texts, isEmpty, reason: 'rien envoyé');

      world.events.emit(field()); // la TV renvoie le champ (OK)
      await settle(tester);
      expect(find.byKey(const ValueKey('tv-text-field')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('langue', () {
    testWidgets('FR / EN : la TV et le téléphone changent de langue',
        (tester) async {
      final world = TestWorld(saved: savedPairing());
      await pumpRemote(tester, world);
      expect(find.text('FR'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('language-toggle')));
      await settle(tester);
      expect(world.commands.languages, ['en']);
      expect(find.text('EN'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget, reason: 'téléphone en anglais');

      await tester.tap(find.byKey(const ValueKey('language-toggle')));
      await settle(tester);
      expect(world.commands.languages, ['en', 'fr']);
      expect(find.text(fr.keyBack), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('petit écran : le bouton de langue ne fait rien déborder',
        (tester) async {
      await pumpRemote(tester, TestWorld(saved: savedPairing()),
          size: const Size(320, 568));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('language-toggle')), findsOneWidget);
      await unmount(tester);
    });
  });
}
