import 'package:epikodi_tv/accounts/accounts_flow.dart';
import 'package:epikodi_tv/accounts/accounts_screen.dart';
import 'package:epikodi_tv/accounts/create_account_screen.dart';
import 'package:epikodi_tv/accounts/pin_dialog.dart';
import 'package:epikodi_tv/api/api.dart';
import 'package:epikodi_tv/library/library_screen.dart';
import 'package:epikodi_tv/remote/remote_keys.dart';
import 'package:epikodi_tv/widgets/profile_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// Mêmes clés et mêmes types que la fixture (les valeurs peuvent différer).
void expectShapeOf(Map<String, dynamic> sent, String fixture,
    {Set<String> without = const {}}) {
  final expected =
      Map<String, dynamic>.of(readFixture(fixture) as Map<String, dynamic>)
        ..removeWhere((k, _) => without.contains(k));
  expect(sent.keys.toSet(), expected.keys.toSet(),
      reason: 'clés envoyées vs $fixture');
  for (final k in expected.keys) {
    expect(sent[k].runtimeType, expected[k].runtimeType,
        reason: '$k vs $fixture');
  }
}

void main() {
  group('AccountsScreen (vue seule)', () {
    Future<List<String>> pumpScreen(
        WidgetTester tester, Map<String, dynamic> data) async {
      final calls = <String>[];
      await pumpTv(
        tester,
        AccountsScreen(
          data: data,
          onBackToPairing: () => calls.add('pairing'),
          onProfile: (p) => calls.add('profile:${p['id']}'),
          onCreate: () => calls.add('create'),
          onGuest: () => calls.add('guest'),
        ),
      );
      await tester.pump();
      return calls;
    }

    testWidgets('affiche les comptes, « Créer » et « Invité »', (tester) async {
      await pumpScreen(tester, accountsData());
      expect(find.text(fr.whoIsWatching), findsOneWidget);
      expect(find.text('Marc'), findsOneWidget);
      expect(find.text('Léa'), findsOneWidget);
      expect(find.text(fr.createCard), findsOneWidget);
      expect(find.text(fr.guestCard), findsOneWidget);
    });

    testWidgets('cadenas seulement sur les comptes avec PIN', (tester) async {
      await pumpScreen(tester, accountsData());
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(semanticsLabel(fr.accountLockedSemantics('Marc')), findsOneWidget);
      expect(semanticsLabel(fr.accountSemantics('Léa')), findsOneWidget);
    });

    testWidgets('aucun compte : texte d\'aide, Créer et Invité seulement',
        (tester) async {
      await pumpScreen(tester, accountsData(empty: true));
      expect(find.text(fr.noAccountYet), findsOneWidget);
      expect(find.text(fr.createOrGuest), findsOneWidget);
      expect(find.text(fr.whoIsWatching), findsNothing);
      expect(find.text(fr.createCard), findsOneWidget);
      expect(find.text(fr.guestCard), findsOneWidget);
    });

    testWidgets('respecte can_create et guest.available du serveur',
        (tester) async {
      final data = accountsData()
        ..['can_create'] = false
        ..['guest'] = {'available': false, 'is_restricted': true};
      await pumpScreen(tester, data);
      expect(find.text(fr.createCard), findsNothing);
      expect(find.text(fr.guestCard), findsNothing);
    });

    testWidgets('chaque carte prévient le parent', (tester) async {
      final calls = await pumpScreen(tester, accountsData());
      await tester.tap(find.text('Léa'));
      await tester.tap(find.text('Marc'));
      await tester.tap(find.text(fr.createCard));
      await tester.tap(find.text(fr.guestCard));
      await tester.tap(find.text(fr.pairingButton));
      expect(calls, ['profile:2', 'profile:1', 'create', 'guest', 'pairing']);
    });

    testWidgets('le premier compte a le focus et Entrée le choisit',
        (tester) async {
      final calls = await pumpScreen(tester, accountsData());
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(calls, ['profile:1']);
    });

    testWidgets('beaucoup de comptes ou petite fenêtre : pas de débordement',
        (tester) async {
      final data = accountsData();
      data['profiles'] = [
        for (var i = 1; i <= 12; i++)
          {
            'id': i,
            'name': 'Compte au nom très long $i',
            'requires_pin': i.isEven
          },
      ];
      await pumpScreen(tester, data);
      expect(tester.takeException(), isNull);

      await pumpTv(
        tester,
        AccountsScreen(
          data: data,
          onBackToPairing: () {},
          onProfile: (_) {},
          onCreate: () {},
          onGuest: () {},
        ),
        size: const Size(960, 540),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('le bouton de langue passe en anglais', (tester) async {
      await pumpScreen(tester, accountsData());
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();
      expect(find.text(en.whoIsWatching), findsOneWidget);
    });
  });

  group('PinDialog (choix d\'un compte)', () {
    Future<List<String>> openPin(
      WidgetTester tester, {
      String? Function(String pin)? check,
    }) async {
      final submitted = <String>[];
      await pumpTv(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => PinDialog(
                profileName: 'Marc',
                onSubmit: (pin) async {
                  submitted.add(pin);
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
      return submitted;
    }

    testWidgets('envoie le PIN dès le 4e chiffre et se ferme s\'il est bon',
        (tester) async {
      final submitted = await openPin(tester);
      expect(find.text('pour Marc'), findsOneWidget);
      await tapPin(tester, '123');
      expect(submitted, isEmpty);
      await tapPin(tester, '4');
      await tester.pumpAndSettle();
      expect(submitted, ['1234']);
      expect(find.byType(PinDialog), findsNothing);
    });

    testWidgets('PIN refusé : message affiché, saisie effacée, popup ouverte',
        (tester) async {
      final submitted =
          await openPin(tester, check: (_) => 'Code PIN incorrect.');
      await tapPin(tester, '9999');
      await tester.pumpAndSettle();
      expect(find.text('Code PIN incorrect.'), findsOneWidget);
      expect(find.byType(PinDialog), findsOneWidget);
      expect(semanticsLabel('0 chiffres saisis sur 4'), findsOneWidget);

      // Un nouveau chiffre efface le message.
      await tapPin(tester, '1');
      await tester.pumpAndSettle();
      expect(find.text('Code PIN incorrect.'), findsNothing);
      expect(submitted, ['9999']);
    });

    testWidgets('effacer retire le dernier chiffre', (tester) async {
      final submitted = await openPin(tester);
      await tapPin(tester, '12');
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();
      expect(semanticsLabel('1 chiffres saisis sur 4'), findsOneWidget);
      await tapPin(tester, '345');
      await tester.pumpAndSettle();
      expect(submitted, ['1345']);
    });

    testWidgets('clavier physique : chiffres et Retour arrière',
        (tester) async {
      final submitted = await openPin(tester);
      for (final k in [LogicalKeyboardKey.digit5, LogicalKeyboardKey.digit6]) {
        await tester.sendKeyEvent(k);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      for (final k in [
        LogicalKeyboardKey.digit7,
        LogicalKeyboardKey.digit8,
        LogicalKeyboardKey.digit9
      ]) {
        await tester.sendKeyEvent(k);
      }
      await tester.pumpAndSettle();
      expect(submitted, ['5789']);
    });

    testWidgets('« Annuler » ferme sans rien envoyer', (tester) async {
      final submitted = await openPin(tester);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(PinDialog), findsNothing);
      expect(submitted, isEmpty);
    });
  });

  group('AccountsFlow (avec le faux serveur)', () {
    late FixtureBackend backend;
    late List<String> backToPairing;

    setUp(() {
      backend = FixtureBackend();
      backToPairing = [];
    });

    Future<void> pumpFlow(WidgetTester tester, {bool empty = false}) async {
      await pumpTv(
        tester,
        AccountsFlow(
          api: Api(fixtureClient(backend).http),
          data: accountsData(empty: empty),
          onBackToPairing: () => backToPairing.add('x'),
        ),
      );
      await tester.pump();
    }

    testWidgets('compte restreint : choisi sans PIN, ouvre la médiathèque',
        (tester) async {
      await pumpFlow(tester);
      await tester.tap(find.text('Léa'));
      await settle(tester);

      final sent = backend.last('POST', '/api/session/profile')!.json;
      expect(sent, {'type': 'account', 'profile_id': 2});
      expectShapeOf(sent, 'session/select_request.json', without: {'pin'});
      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('compte avec PIN : popup, mauvais PIN refusé, bon PIN accepté',
        (tester) async {
      backend.fail('POST', '/api/session/profile',
          status: 403,
          code: 'pin_invalid',
          message: 'Code PIN incorrect.',
          details: {'attempts_left': 2});
      await pumpFlow(tester);
      await tester.tap(find.text('Marc'));
      await tester.pumpAndSettle();
      expect(find.byType(PinDialog), findsOneWidget);

      await tapPin(tester, '0000');
      await settle(tester);
      expect(find.text('Code PIN incorrect.'), findsOneWidget);
      expect(find.byType(LibraryScreen), findsNothing);

      backend.reset('POST', '/api/session/profile');
      await tapPin(tester, '1234');
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));

      final sent = backend.last('POST', '/api/session/profile')!.json;
      expect(sent, {'type': 'account', 'profile_id': 1, 'pin': '1234'});
      expectShapeOf(sent, 'session/select_request.json');
      expect(find.byType(PinDialog), findsNothing);
      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('PIN annulé : reste sur « Qui regarde ? »', (tester) async {
      await pumpFlow(tester);
      await tester.tap(find.text('Marc'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(backend.calls('POST', '/api/session/profile'), isEmpty);
      expect(find.text(fr.whoIsWatching), findsOneWidget);
    });

    testWidgets('Invité : envoie {"type": "guest"} seulement', (tester) async {
      await pumpFlow(tester);
      await tester.tap(find.text(fr.guestCard));
      await settle(tester);
      expect(backend.last('POST', '/api/session/profile')!.json,
          {'type': 'guest'});
      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('erreur serveur : message en bas, pas de médiathèque',
        (tester) async {
      backend.fail('POST', '/api/session/profile',
          status: 404,
          code: 'profile_not_found',
          message: 'Ce profil n\'existe pas.');
      await pumpFlow(tester);
      await tester.tap(find.text('Léa'));
      await settle(tester);
      expect(find.text('Ce profil n\'existe pas.'), findsOneWidget);
      expect(find.byType(LibraryScreen), findsNothing);
    });

    testWidgets(
        '« Changer de profil » depuis la médiathèque revient aux comptes',
        (tester) async {
      await pumpFlow(tester);
      await tester.tap(find.text('Léa'));
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byType(ProfileMenuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.switchProfile));
      await tester.pumpAndSettle();
      expect(find.text(fr.whoIsWatching), findsOneWidget);
      // Plus de profil actif : un invité ou un enfant ne reste pas « connecté »
      // pendant qu'on crée un compte.
      expect(backend.last('DELETE', '/api/session/profile'), isNotNull);
    });

    testWidgets(
        'invité revenu aux comptes avec Retour : il peut créer un compte',
        (tester) async {
      await pumpFlow(tester);
      await tester.tap(find.text(fr.guestCard));
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LibraryScreen), findsOneWidget);
      // Le serveur refuse tant que l'invité est actif.
      var guestActive = true;
      backend.on('DELETE', '/api/session/profile', (_) {
        guestActive = false;
        return (204, null);
      });
      backend.on(
          'POST',
          '/api/profiles',
          (_) => guestActive
              ? (
                  403,
                  FixtureBackend.errorBody('guest_forbidden',
                      message: 'Impossible pour un invité.')
                )
              : (
                  201,
                  {
                    ...readFixture('profiles/create_response.json'),
                    'profile': {
                      ...readFixture(
                          'profiles/create_response.json')['profile'],
                      'id': 3,
                      'name': 'Zoé',
                    },
                  }
                ));

      await tester.binding.handlePopRoute(); // touche Retour
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.text(fr.whoIsWatching), findsOneWidget);
      expect(guestActive, isFalse, reason: 'invité oublié en revenant');

      await tester.tap(find.text(fr.createCard));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Zoé');
      await tester.tap(find.text(fr.createAccountButton));
      await tester.pumpAndSettle();
      await tapPin(tester, '4321');
      await tester.pumpAndSettle();
      await tapPin(tester, '4321');
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Impossible pour un invité.'), findsNothing);
      expect(find.byType(LibraryScreen), findsOneWidget, reason: 'compte créé');
    });

    testWidgets(
        '« Changer de profil » sur la télécommande : la TV revient à '
        '« Qui regarde ? », profil oublié', (tester) async {
      await pumpFlow(tester);
      await tester.tap(find.text('Léa'));
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LibraryScreen), findsOneWidget);
      // Une fiche ouverte par-dessus la médiathèque.
      showDialog<void>(
          context: tester.element(find.byType(LibraryScreen)),
          builder: (_) => const AlertDialog(content: Text('fiche')));
      await tester.pumpAndSettle();

      RemoteKeyHandler(GlobalKey<NavigatorState>())
          .handle({'shortcut': 'switch_profile'});
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.text(fr.whoIsWatching), findsOneWidget);
      expect(find.text('fiche'), findsNothing);
      expect(find.byType(LibraryScreen), findsNothing);
      expect(backend.last('DELETE', '/api/session/profile'), isNotNull,
          reason: 'profil actif oublié');

      // Déjà sur « Qui regarde ? » : rien ne bouge.
      RemoteKeyHandler(GlobalKey<NavigatorState>())
          .handle({'shortcut': 'switch_profile'});
      await tester.pumpAndSettle();
      expect(find.text(fr.whoIsWatching), findsOneWidget);
    });

    testWidgets('« Appairage » prévient le parent', (tester) async {
      await pumpFlow(tester);
      await tester.tap(find.text(fr.pairingButton));
      expect(backToPairing, hasLength(1));
    });

    testWidgets('création : POST /api/profiles, le compte apparaît et s\'ouvre',
        (tester) async {
      await pumpFlow(tester, empty: true);
      await tester.tap(find.text(fr.createCard));
      await tester.pumpAndSettle();
      expect(find.byType(CreateAccountScreen), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  Zoé  ');
      await tester.tap(find.text(fr.createAccountButton));
      await tester.pumpAndSettle();
      // Compte sans restriction : code PIN choisi puis confirmé.
      await tapPin(tester, '4321');
      await tester.pumpAndSettle();
      await tapPin(tester, '4321');
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));

      final sent = backend.last('POST', '/api/profiles')!.json;
      expect(sent['name'], 'Zoé', reason: 'espaces retirés');
      expect(sent['language'], 'fr');
      expect(sent['age'], 18);
      expect(sent['is_restricted'], isFalse);
      expect(sent['pin'], '4321');
      expectShapeOf(sent, 'profiles/create_request.json');
      expect(find.byType(LibraryScreen), findsOneWidget);

      // Retour aux comptes : le compte créé (réponse du serveur) est listé.
      await tester.tap(find.byType(ProfileMenuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.switchProfile));
      await tester.pumpAndSettle();
      expect(find.text(fr.whoIsWatching), findsOneWidget);
      expect(find.text('Marc'), findsOneWidget);
    });
  });

  group('Modifier : supprimer des comptes', () {
    late FixtureBackend backend;
    setUp(() => backend = FixtureBackend());

    Future<void> pumpFlow(WidgetTester tester) async {
      await pumpTv(
        tester,
        AccountsFlow(
          api: Api(fixtureClient(backend).http),
          data: accountsData(),
          onBackToPairing: () {},
        ),
      );
      await tester.pump();
    }

    Finder edit() => find.byKey(const ValueKey('accounts-edit'));
    Finder account(int id) => find.byKey(ValueKey('account-$id'));

    Future<void> startDelete(WidgetTester tester, int id) async {
      await tester.tap(edit());
      await tester.pumpAndSettle();
      await tester.tap(account(id));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-delete-account')));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'bouton « Modifier » en haut à gauche : corbeilles, comptes seuls',
        (tester) async {
      await pumpFlow(tester);
      expect(edit(), findsOneWidget);
      // Petite icône juste à gauche des comptes, sur leur ligne.
      final icon = tester.getRect(edit());
      final first = tester.getRect(account(1));
      expect(icon.right, lessThan(first.left), reason: 'à gauche des comptes');
      expect(first.left - icon.right, lessThan(80),
          reason: 'collée aux comptes');
      expect(
          (icon.center.dy - first.center.dy).abs(), lessThan(first.height / 2),
          reason: 'sur la même ligne');
      expect(icon.width, lessThan(first.width / 2), reason: 'petite');
      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
      expect(find.text(fr.editAccounts), findsNothing, reason: 'icône seule');

      await tester.tap(edit());
      await tester.pumpAndSettle();
      expect(find.text(fr.manageAccounts), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-badge')), findsNWidgets(2));
      expect(find.text(fr.createCard), findsNothing);
      expect(find.text(fr.guestCard), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // « Terminé » : retour à « Qui regarde ? ».
      await tester.tap(edit());
      await tester.pumpAndSettle();
      expect(find.text(fr.whoIsWatching), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-badge')), findsNothing);
    });

    testWidgets('confirmation puis DELETE, sans PIN, compte retiré',
        (tester) async {
      await pumpFlow(tester);
      await startDelete(tester, 1); // Marc, pourtant protégé par un PIN
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.text(fr.pinTitle), findsNothing, reason: 'pas de PIN');
      final sent = backend.last('DELETE', '/api/profiles/1')!;
      expect(sent.body, isNull);
      expect(account(1), findsNothing, reason: 'retiré de la liste');
      expect(account(2), findsOneWidget);

      await tester.tap(account(2)); // Léa
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-delete-account')));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(account(2), findsNothing);
      expect(find.text(fr.noAccountYet), findsOneWidget,
          reason: 'plus de compte : retour à l\'écran normal');
    });

    testWidgets('« Annuler » : rien n\'est supprimé', (tester) async {
      await pumpFlow(tester);
      await tester.tap(edit());
      await tester.pumpAndSettle();
      await tester.tap(account(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.cancel));
      await tester.pumpAndSettle();
      expect(backend.calls('DELETE', '/api/profiles/{id}'), isEmpty);
      expect(account(1), findsOneWidget);
    });

    testWidgets('erreur du serveur : popup qui disparaît toute seule',
        (tester) async {
      backend.fail('DELETE', '/api/profiles/{id}',
          status: 404,
          code: 'profile_not_found',
          message: 'Compte introuvable.');
      await pumpFlow(tester);
      await startDelete(tester, 1);
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('error-toast')), findsOneWidget);
      expect(find.text('Compte introuvable.'), findsOneWidget);
      expect(account(1), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('error-toast')), findsNothing);
    });
  });

  group('CreateAccountScreen', () {
    late FixtureBackend backend;
    setUp(() => backend = FixtureBackend());

    Future<void> pumpCreate(WidgetTester tester) async {
      await pumpTv(
          tester, CreateAccountScreen(api: Api(fixtureClient(backend).http)));
      await tester.pump();
    }

    testWidgets('nom vide : message, aucune requête', (tester) async {
      await pumpCreate(tester);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text(fr.createAccountButton));
      await tester.pump();
      expect(find.text(fr.enterName), findsOneWidget);
      expect(backend.calls('POST', '/api/profiles'), isEmpty);
    });

    testWidgets('âge borné entre 3 et 99, profil enfant, avatar choisi',
        (tester) async {
      await pumpCreate(tester);
      expect(find.text(fr.ageYears(18)), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(find.text(fr.ageYears(19)), findsOneWidget);
      for (var i = 0; i < 30; i++) {
        await tester.tap(find.byIcon(Icons.remove_rounded));
      }
      await tester.pump();
      expect(find.text(fr.ageYears(3)), findsOneWidget);

      await tester.tap(find.text(fr.no)); // profil enfant : non -> oui
      await tester.pump();
      expect(find.text(fr.yes), findsOneWidget);
      expect(find.text(fr.blocksRatingAndAbove(10)), findsOneWidget);

      await tester.tap(semanticsLabel(fr.avatarIcon(3)));
      await tester.enterText(find.byType(TextField), 'Tom');
      await tester.tap(find.text(fr.createAccountButton));
      await settle(tester);

      final sent = backend.last('POST', '/api/profiles')!.json;
      expect(sent['age'], 3);
      expect(sent['is_restricted'], isTrue);
      expect(sent['icon'], 'avatar_03');
    });

    testWidgets('erreur serveur (nom pris) : message affiché, on peut corriger',
        (tester) async {
      backend.fail('POST', '/api/profiles',
          status: 409, code: 'profile_name_taken', message: 'Nom déjà pris.');
      await pumpCreate(tester);
      await tester.enterText(find.byType(TextField), 'Marc');
      await tester.tap(find.text(fr.createAccountButton));
      await tester.pumpAndSettle();
      await tapPin(tester, '1234');
      await tester.pumpAndSettle();
      await tapPin(tester, '1234');
      await settle(tester);
      expect(find.text('Nom déjà pris.'), findsOneWidget);
      expect(find.text(fr.createAccountButton), findsOneWidget,
          reason: 'plus en « création… »');
    });

    testWidgets('compte sans restriction : PIN demandé deux fois',
        (tester) async {
      await pumpCreate(tester);
      await tester.enterText(find.byType(TextField), 'Marc');
      await tester.tap(find.text(fr.createAccountButton));
      await tester.pumpAndSettle();
      expect(find.text(fr.newPinTitle), findsOneWidget);
      await tapPin(tester, '1234');
      await tester.pumpAndSettle();
      expect(find.text(fr.confirmPinTitle), findsOneWidget);

      // Codes différents : on recommence, avec un message.
      await tapPin(tester, '9999');
      await tester.pumpAndSettle();
      expect(find.text(fr.newPinTitle), findsOneWidget);
      expect(find.text(fr.pinMismatch), findsOneWidget);
      expect(backend.calls('POST', '/api/profiles'), isEmpty);

      await tapPin(tester, '2468');
      await tester.pumpAndSettle();
      await tapPin(tester, '2468');
      await settle(tester);
      expect(backend.last('POST', '/api/profiles')!.json['pin'], '2468');
    });

    testWidgets('PIN annulé : aucun compte créé', (tester) async {
      await pumpCreate(tester);
      await tester.enterText(find.byType(TextField), 'Marc');
      await tester.tap(find.text(fr.createAccountButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.cancel));
      await tester.pumpAndSettle();
      expect(backend.calls('POST', '/api/profiles'), isEmpty);
      expect(find.byType(CreateAccountScreen), findsOneWidget);
      expect(find.text(fr.createAccountButton), findsOneWidget);
    });

    testWidgets('fenêtre minimale : pas de débordement', (tester) async {
      await pumpTv(
          tester, CreateAccountScreen(api: Api(fixtureClient(backend).http)),
          size: const Size(960, 540));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
