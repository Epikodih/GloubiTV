// Fiche d'un média (popup) : infos, Lecture, favoris et « À regarder ».
import 'package:design_system/design_system.dart';
import 'package:epikodi_tv/api/api.dart';
import 'package:epikodi_tv/library/library_screen.dart';
import 'package:epikodi_tv/library/media_details.dart';
import 'package:epikodi_tv/remote/remote_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

Map<String, dynamic> get marc => Map<String, dynamic>.of(
    readFixture('session/select_response.json')['profile']);

Map<String, dynamic> get detailFixture => Map<String, dynamic>.of(
    readFixture('media/get_response.json') as Map<String, dynamic>);

void main() {
  late FixtureBackend backend;
  setUp(() => backend = FixtureBackend());

  Finder dialog() => find.byKey(const ValueKey('media-details'));
  Finder inDialog(Finder f) => find.descendant(of: dialog(), matching: f);
  Finder action(String name) => find.byKey(ValueKey('details-$name'));

  String? focusedLabel() => FocusManager.instance.primaryFocus?.context
      ?.findAncestorWidgetOfExactType<FocusableCard>()
      ?.semanticLabel;

  String? actionLabel(WidgetTester tester, String name) => tester
      .widget<FocusableCard>(find.descendant(
          of: action(name), matching: find.byType(FocusableCard)))
      .semanticLabel;

  Future<void> pumpLibrary(WidgetTester tester,
      {Map<String, dynamic>? profile,
      Size size = const Size(1920, 1080)}) async {
    await pumpTv(
      tester,
      LibraryScreen(
        api: Api(fixtureClient(backend).http),
        profile: profile ?? marc,
        onChangeProfile: () {},
        onBackToPairing: () {},
      ),
      size: size,
    );
    await settle(tester);
  }

  /// Ouvre la fiche de Sintel (id 2), comme la fixture get_response.
  Future<void> openSintel(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('media-2')));
    await settle(tester);
    await tester.pumpAndSettle();
  }

  group('Api', () {
    late Api api;
    setUp(() => api = Api(fixtureClient(backend).http));

    test('fetchMediaDetail : GET /api/media/{id}', () async {
      final d = await api.fetchMediaDetail(2);
      expect(backend.last('GET', '/api/media/2'), isNotNull);
      expect(d['overview'], isA<String>());
      expect(d['in_favorites'], isFalse);
      expect(d['in_watchlist'], isTrue);
    });

    test('la fiche a tous les champs d\'un élément de la liste', () {
      final item = (readFixture('media/list.json')['items'] as List).first
          as Map<String, dynamic>;
      expect(detailFixture.keys, containsAll(item.keys));
      expect(detailFixture.keys,
          containsAll(['overview', 'in_favorites', 'in_watchlist']));
    });

    test('setInList : PUT pour ajouter, DELETE pour retirer', () async {
      await api.setInList(2, 'favorite', true);
      expect(backend.last('PUT', '/api/media/2/favorite'), isNotNull);
      await api.setInList(2, 'watchlist', false);
      expect(backend.last('DELETE', '/api/media/2/watchlist'), isNotNull);
      expect(backend.routeFor('PUT', '/api/media/2/favorite')!.errorCodes,
          contains('guest_forbidden'));
    });
  });

  test('durée : minutes, puis heures et minutes', () {
    expect(formatDuration(fr, 596), '10 min');
    expect(formatDuration(fr, 6000), '1 h 40 min');
    expect(formatDuration(en, 3600), '1 h 0 min');
  });

  group('popup', () {
    testWidgets('OK sur une affiche : fiche avec les infos du média',
        (tester) async {
      await pumpLibrary(tester);
      expect(dialog(), findsNothing);
      await openSintel(tester);

      expect(dialog(), findsOneWidget);
      expect(backend.last('GET', '/api/media/2'), isNotNull);
      expect(inDialog(find.text('Sintel')), findsOneWidget);
      expect(inDialog(find.text('2010')), findsOneWidget);
      expect(inDialog(find.text(fr.kindMovie)), findsOneWidget);
      expect(inDialog(find.text('15 min')), findsOneWidget, reason: '888 s');
      expect(inDialog(find.text(fr.ageRating(10))), findsOneWidget);
      expect(inDialog(find.text('Animation')), findsOneWidget);
      expect(inDialog(find.text('Fantastique')), findsOneWidget);
      expect(inDialog(find.text(detailFixture['overview'] as String)),
          findsOneWidget);

      // Lecture a le focus ; les listes reflètent la fiche du serveur.
      expect(focusedLabel(), fr.play);
      expect(actionLabel(tester, 'favorite'), fr.addFavorite);
      expect(actionLabel(tester, 'watchlist'), fr.inWatchlist);
    });

    testWidgets('télécommande : OK ouvre la fiche, Retour la ferme',
        (tester) async {
      await pumpLibrary(tester);
      final r = RemoteKeyHandler(GlobalKey<NavigatorState>());
      r.press('ok'); // première affiche : Big Buck Bunny
      await settle(tester);
      await tester.pumpAndSettle();
      expect(dialog(), findsOneWidget);
      expect(backend.last('GET', '/api/media/1'), isNotNull);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(dialog(), findsNothing);
      expect(focusedLabel(), 'Big Buck Bunny', reason: 'focus rendu');
    });

    testWidgets('Favoris : PUT puis DELETE, le bouton suit', (tester) async {
      await pumpLibrary(tester);
      await openSintel(tester);
      await tester.tap(action('favorite'));
      await settle(tester);
      expect(backend.last('PUT', '/api/media/2/favorite'), isNotNull);
      expect(actionLabel(tester, 'favorite'), fr.inFavorites);

      await tester.tap(action('favorite'));
      await settle(tester);
      expect(backend.last('DELETE', '/api/media/2/favorite'), isNotNull);
      expect(actionLabel(tester, 'favorite'), fr.addFavorite);
    });

    testWidgets('icônes : « + » pour À regarder, cœur pour les favoris',
        (tester) async {
      backend.on('GET', '/api/media/{id}',
          (_) => (200, {...detailFixture, 'in_watchlist': false}));
      await pumpLibrary(tester);
      await openSintel(tester);
      Finder icon(String name, IconData i) =>
          find.descendant(of: action(name), matching: find.byIcon(i));
      expect(icon('watchlist', Icons.add_rounded), findsOneWidget);
      expect(icon('favorite', Icons.favorite_border_rounded), findsOneWidget);

      await tester.tap(action('watchlist'));
      await settle(tester);
      await tester.tap(action('favorite'));
      await settle(tester);
      expect(icon('watchlist', Icons.check_rounded), findsOneWidget);
      expect(icon('favorite', Icons.favorite_rounded), findsOneWidget);
    });

    testWidgets('« À regarder » : retirer envoie DELETE', (tester) async {
      await pumpLibrary(tester);
      await openSintel(tester);
      await tester.tap(action('watchlist'));
      await settle(tester);
      expect(backend.last('DELETE', '/api/media/2/watchlist'), isNotNull);
      expect(actionLabel(tester, 'watchlist'), fr.addWatchlist);
    });

    testWidgets('erreur du serveur : bouton remis comme avant, message',
        (tester) async {
      backend.fail('PUT', '/api/media/{id}/favorite',
          status: 403, code: 'guest_forbidden', message: 'Pas de favoris.');
      await pumpLibrary(tester);
      await openSintel(tester);
      await tester.tap(action('favorite'));
      await settle(tester);
      expect(actionLabel(tester, 'favorite'), fr.addFavorite);
      expect(inDialog(find.text('Pas de favoris.')), findsOneWidget);
    });

    testWidgets('Lecture : pas encore branchée, message', (tester) async {
      await pumpLibrary(tester);
      await openSintel(tester);
      await tester.tap(action('play'));
      await tester.pump();
      expect(inDialog(find.text(fr.playSoon)), findsOneWidget);
    });

    testWidgets('fichier disparu : avertissement, Lecture désactivée',
        (tester) async {
      backend.on('GET', '/api/media/{id}',
          (_) => (200, {...detailFixture, 'id': 5, 'status': 'missing'}));
      await pumpLibrary(tester);
      await tester.tap(find.byKey(const ValueKey('media-5')));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(inDialog(find.text(fr.fileMissing)), findsOneWidget);
      await tester.tap(action('play'));
      await tester.pump();
      expect(inDialog(find.text(fr.playSoon)), findsNothing);
    });

    testWidgets('sans résumé ni classification', (tester) async {
      backend.on(
          'GET',
          '/api/media/{id}',
          (_) =>
              (200, {...detailFixture, 'overview': null, 'age_rating': null}));
      await pumpLibrary(tester);
      await openSintel(tester);
      expect(inDialog(find.text(fr.noOverview)), findsOneWidget);
      expect(inDialog(find.text(fr.notRated)), findsOneWidget);
    });

    testWidgets('fiche introuvable : message, Lecture reste possible',
        (tester) async {
      backend.fail('GET', '/api/media/{id}',
          status: 404, code: 'media_not_found', message: 'Introuvable.');
      await pumpLibrary(tester);
      await openSintel(tester);
      expect(inDialog(find.text('Introuvable.')), findsOneWidget);
      expect(inDialog(find.text('Sintel')), findsOneWidget,
          reason: 'infos de la liste');
    });

    testWidgets('invité : « + » et cœur gardés par la TV pour la session',
        (tester) async {
      final guest = {'kind': 'guest', 'id': null, 'name': null};
      await pumpLibrary(tester, profile: guest);
      await openSintel(tester);
      expect(action('watchlist'), findsOneWidget);
      expect(action('favorite'), findsOneWidget);

      await tester.tap(action('favorite'));
      await settle(tester);
      expect(actionLabel(tester, 'favorite'), fr.inFavorites);
      expect(backend.calls('PUT', '/api/media/{id}/favorite'), isEmpty,
          reason: 'rien envoyé au serveur');

      await tester.tap(action('close'));
      await settle(tester);
      await tester.pumpAndSettle();

      // Page Favoris : le média, sans requête au serveur.
      final before = backend.calls('GET', '/api/media').length;
      await tester.tap(find.byKey(const ValueKey('nav-favorites')));
      await settle(tester);
      expect(backend.calls('GET', '/api/media').length, before);
      expect(find.byKey(const ValueKey('media-2')), findsOneWidget);

      // La fiche se souvient du favori (même si le serveur dit non).
      await openSintel(tester);
      expect(actionLabel(tester, 'favorite'), fr.inFavorites);
      expect(actionLabel(tester, 'watchlist'), fr.addWatchlist,
          reason: 'fixture dit in_watchlist, mais invité : liste de la TV');
    });

    testWidgets('invité : nouvelle session (autre profil) = listes vides',
        (tester) async {
      final guest = {'kind': 'guest', 'id': null, 'name': null};
      await pumpLibrary(tester, profile: guest);
      await openSintel(tester);
      await tester.tap(action('watchlist'));
      await settle(tester);
      await tester.tap(action('close'));
      await tester.pumpAndSettle();

      await pumpTv(tester, const SizedBox()); // on quitte la médiathèque
      await pumpLibrary(tester, profile: guest);
      await tester.tap(find.byKey(const ValueKey('nav-watchlist')));
      await settle(tester);
      expect(find.text(fr.emptyWatchlist), findsOneWidget);
    });

    testWidgets('hauteur de la fiche = celle de l\'affiche (carrée en musique)',
        (tester) async {
      Future<(Size, Size)> sizes(int id) async {
        await tester.tap(find.byKey(ValueKey('media-$id')));
        await settle(tester);
        await tester.pumpAndSettle();
        final poster =
            tester.getSize(find.byKey(const ValueKey('details-poster')));
        final card = tester.getSize(dialog());
        await tester.tap(action('close'));
        await tester.pumpAndSettle();
        return (poster, card);
      }

      backend.on('GET', '/api/media/{id}', (r) {
        final id = int.parse(r.path.split('/').last);
        final item = (readFixture('media/list.json')['items'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((m) => m['id'] == id);
        return (
          200,
          {
            ...item,
            'overview': 'Résumé.',
            'in_favorites': false,
            'in_watchlist': false
          }
        );
      });
      await pumpLibrary(tester);
      final (moviePoster, movieCard) = await sizes(1);
      await tester.tap(find.byKey(const ValueKey('nav-music')));
      await settle(tester);
      final (musicPoster, musicCard) = await sizes(7);

      expect(moviePoster.height / moviePoster.width, closeTo(1.5, 0.01));
      expect(musicPoster.height, closeTo(musicPoster.width, 0.01),
          reason: 'pochette carrée');
      // Aucun vide sous l'affiche : la fiche = affiche + marges intérieures.
      const chrome = 2 * 32.0 + 4; // padding + bordure
      expect(movieCard.height, closeTo(moviePoster.height + chrome, 1));
      expect(musicCard.height, closeTo(musicPoster.height + chrome, 1));
      expect(musicCard.height, lessThan(movieCard.height));
    });

    testWidgets('Lecture, « + » et cœur : même hauteur, sur une ligne',
        (tester) async {
      await pumpLibrary(tester);
      await openSintel(tester);
      final play = tester.getRect(action('play'));
      final plus = tester.getRect(action('watchlist'));
      final heart = tester.getRect(action('favorite'));
      expect(plus.height, closeTo(play.height, 0.5));
      expect(heart.height, closeTo(play.height, 0.5));
      expect(plus.width, closeTo(plus.height, 0.5), reason: 'rond');
      expect(plus.center.dy, closeTo(play.center.dy, 0.5));
      expect(heart.center.dy, closeTo(play.center.dy, 0.5));
    });

    testWidgets('petite fenêtre : boutons toujours visibles dans la fiche',
        (tester) async {
      backend.on(
          'GET',
          '/api/media/{id}',
          (_) => (
                200,
                {
                  ...detailFixture,
                  'overview': 'Très long résumé. ' * 60,
                }
              ));
      await pumpLibrary(tester, size: const Size(960, 540));
      await tester.tap(find.byKey(const ValueKey('media-1')));
      await settle(tester);
      await tester.pumpAndSettle();
      final card = tester.getRect(dialog());
      for (final a in ['play', 'watchlist', 'favorite']) {
        final r = tester.getRect(action(a));
        expect(card.contains(r.topLeft) && card.contains(r.bottomRight), isTrue,
            reason: a);
        expect(r.bottom, lessThanOrEqualTo(540));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('retiré des favoris depuis Favoris : la liste se recharge',
        (tester) async {
      await pumpLibrary(tester);
      await tester.tap(find.byKey(const ValueKey('nav-favorites')));
      await settle(tester);
      final before = backend.calls('GET', '/api/media').length;

      await openSintel(tester);
      await tester.tap(action('favorite'));
      await settle(tester);
      await tester.tap(action('close'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(dialog(), findsNothing);
      expect(backend.calls('GET', '/api/media').length, before + 1);
      expect(backend.last('GET', '/api/media')!.query, {'list': 'favorites'});
    });

    testWidgets('fermer sans rien changer : pas de rechargement',
        (tester) async {
      await pumpLibrary(tester);
      final before = backend.calls('GET', '/api/media').length;
      await openSintel(tester);
      await tester.tap(action('close'));
      await tester.pumpAndSettle();
      expect(dialog(), findsNothing);
      expect(backend.calls('GET', '/api/media').length, before);
    });

    testWidgets('fenêtre minimale : pas de débordement', (tester) async {
      await pumpLibrary(tester, size: const Size(960, 540));
      await tester.tap(find.byKey(const ValueKey('media-1')));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(dialog(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
