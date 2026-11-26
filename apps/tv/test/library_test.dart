// Médiathèque : menu de gauche, listes (favoris, « À regarder »,
// catégories), icônes de type et recherche avec filtres.
import 'package:design_system/design_system.dart';
import 'package:epikodi_tv/api/api.dart';
import 'package:epikodi_tv/library/library_screen.dart';
import 'package:epikodi_tv/library/library_section.dart';
import 'package:epikodi_tv/library/library_sidebar.dart';
import 'package:epikodi_tv/library/media_card.dart';
import 'package:epikodi_tv/library/search_view.dart';
import 'package:epikodi_tv/remote/remote_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

Map<String, dynamic> get marc => Map<String, dynamic>.of(
    readFixture('session/select_response.json')['profile']);

List<Map<String, dynamic>> get fixtureItems => [
      for (final m in readFixture('media/list.json')['items'] as List)
        Map<String, dynamic>.of(m as Map<String, dynamic>),
    ];

FixtureReply page(List<Map<String, dynamic>> items) =>
    (200, {'items': items, 'total': items.length, 'limit': 50, 'offset': 0});

void main() {
  late FixtureBackend backend;
  setUp(() => backend = FixtureBackend());

  Future<void> pumpLibrary(WidgetTester tester,
      {Size size = const Size(1920, 1080)}) async {
    await pumpTv(
      tester,
      LibraryScreen(
        api: Api(fixtureClient(backend).http),
        profile: marc,
        onChangeProfile: () {},
        onBackToPairing: () {},
      ),
      size: size,
    );
    await settle(tester);
  }

  Finder nav(LibrarySection s) => find.byKey(ValueKey('nav-${s.name}'));

  Future<void> open(WidgetTester tester, LibrarySection s) async {
    await tester.tap(nav(s));
    await settle(tester);
  }

  /// Paramètres de la dernière requête GET /api/media.
  Map<String, String> lastQuery() => backend.last('GET', '/api/media')!.query;

  /// Texte du lecteur d'écran de la carte qui a le focus (ou null).
  String? focusedLabel() => FocusManager.instance.primaryFocus?.context
      ?.findAncestorWidgetOfExactType<FocusableCard>()
      ?.semanticLabel;

  group('Api.fetchMedia', () {
    late Api api;
    setUp(() => api = Api(fixtureClient(backend).http));

    test('sans filtre : aucun paramètre', () async {
      await api.fetchMedia();
      expect(lastQuery(), isEmpty);
    });

    test('filtres envoyés en paramètres (routes.json)', () async {
      await api.fetchMedia(
          kind: 'movie',
          list: 'favorites',
          query: '  sintel ',
          genre: 'Animation',
          maxAge: 12);
      expect(lastQuery(), {
        'kind': 'movie',
        'list': 'favorites',
        'q': 'sintel',
        'genre': 'Animation',
        'max_age': '12',
      });
      final declared =
          (backend.routeFor('GET', '/api/media')!.json['query'] as List)
              .cast<String>();
      expect(declared, containsAll(lastQuery().keys));
    });

    test('recherche vide : pas de paramètre q', () async {
      await api.fetchMedia(query: '   ');
      expect(lastQuery().containsKey('q'), isFalse);
    });

    test('chaque média de la fixture a une liste de genres', () {
      for (final m in fixtureItems) {
        expect(m['genres'], isA<List>(), reason: '${m['title']}');
      }
    });
  });

  group('menu de gauche', () {
    /// Libellé d'une entrée visible (menu déplié) ou caché (opacité 0).
    double labelOpacity(WidgetTester tester, LibrarySection s) => tester
        .widget<AnimatedOpacity>(find.ancestor(
            of: find.descendant(of: nav(s), matching: find.text(s.label(fr))),
            matching: find.byType(AnimatedOpacity)))
        .opacity;

    RemoteKeyHandler remoteFor() =>
        RemoteKeyHandler(GlobalKey<NavigatorState>());

    Future<void> press(
        WidgetTester tester, RemoteKeyHandler r, String key) async {
      r.press(key);
      await tester.pump();
      await settle(tester);
    }

    testWidgets('réduit aux icônes, focus sur la première affiche',
        (tester) async {
      await pumpLibrary(tester);
      final sections = LibrarySidebar.sections;
      expect(sections.take(3), [
        LibrarySection.home,
        LibrarySection.watchlist,
        LibrarySection.favorites,
      ]);
      expect(nav(LibrarySection.search), findsNothing,
          reason: 'la recherche est dans l\'en-tête');
      final ys = [for (final s in sections) tester.getTopLeft(nav(s)).dy];
      expect(ys, orderedEquals([...ys]..sort()));

      for (final s in sections) {
        expect(find.descendant(of: nav(s), matching: find.byIcon(s.icon)),
            findsOneWidget,
            reason: s.name);
        expect(labelOpacity(tester, s), 0, reason: s.name);
      }
      expect(tester.getSize(find.byType(LibrarySidebar)).width, lessThan(120));
      expect(focusedLabel(), 'Big Buck Bunny', reason: 'premier film');
      expect(lastQuery(), isEmpty, reason: 'accueil : tout le catalogue');
    });

    testWidgets('hauteur du menu = ses entrées, pas de vide en bas',
        (tester) async {
      await pumpLibrary(tester);
      final menu = tester.getRect(find.byType(LibrarySidebar));
      final last = tester.getRect(nav(LibrarySidebar.sections.last));
      // Les paramètres sont dans le menu du profil, pas dans celui-ci.
      expect(find.byKey(const ValueKey('nav-settings')), findsNothing);
      expect(menu.bottom - last.bottom, lessThan(40));
      expect(menu.bottom, lessThan(900), reason: 'ne va pas jusqu\'en bas');
    });

    testWidgets('entrer dans le menu : il se déplie sur l\'entrée affichée',
        (tester) async {
      await pumpLibrary(tester);
      final r = remoteFor();
      final cardX = tester.getTopLeft(find.byKey(const ValueKey('media-1'))).dx;

      await press(tester, r, 'left');
      expect(focusedLabel(), fr.navHome, reason: 'entrée affichée');
      expect(lastQuery(), isEmpty, reason: 'la liste ne change pas');
      expect(
          tester.getSize(find.byType(LibrarySidebar)).width, greaterThan(200));
      for (final s in LibrarySidebar.sections) {
        expect(labelOpacity(tester, s), 1, reason: s.name);
      }
      final shifted =
          tester.getTopLeft(find.byKey(const ValueKey('media-1'))).dx;
      expect(shifted, greaterThan(cardX), reason: 'la liste reste visible');
      expect(shifted,
          greaterThan(tester.getTopRight(find.byType(LibrarySidebar)).dx));

      await press(tester, r, 'right');
      expect(focusedLabel(), 'Big Buck Bunny');
      expect(tester.getSize(find.byType(LibrarySidebar)).width, lessThan(120));
    });

    testWidgets('passer sur une entrée l\'affiche, sans valider',
        (tester) async {
      await pumpLibrary(tester);
      final r = remoteFor();
      await press(tester, r, 'left'); // Accueil
      await press(tester, r, 'down');
      expect(focusedLabel(), fr.navWatchlist);
      expect(lastQuery(), {'list': 'watchlist'});
      await press(tester, r, 'down');
      expect(focusedLabel(), fr.navFavorites);
      expect(lastQuery(), {'list': 'favorites'});
      expect(find.byType(KindBadge), findsWidgets);

      await press(tester, r, 'right');
      expect(focusedLabel(), contains(', '), reason: 'une affiche (avec type)');
      // On revient sur Favoris, pas sur l'entrée la plus proche.
      await press(tester, r, 'left');
      expect(focusedLabel(), fr.navFavorites);
      expect(lastQuery(), {'list': 'favorites'});
    });

    testWidgets('Favoris : icône du type sur chaque affiche', (tester) async {
      await pumpLibrary(tester);
      await open(tester, LibrarySection.favorites);
      expect(lastQuery(), {'list': 'favorites'});
      for (final f in MediaFamily.values) {
        expect(find.byKey(ValueKey('kind-${f.name}')), findsWidgets,
            reason: f.name);
      }
      final bunny = tester.widget<FocusableCard>(find.descendant(
          of: find.byKey(const ValueKey('media-1')),
          matching: find.byType(FocusableCard)));
      expect(bunny.semanticLabel, 'Big Buck Bunny, ${fr.kindMovie}');
    });

    testWidgets('« À regarder » vide : message dédié', (tester) async {
      backend.on('GET', '/api/media',
          (r) => page(r.query['list'] == 'watchlist' ? [] : fixtureItems));
      await pumpLibrary(tester);
      await open(tester, LibrarySection.watchlist);
      expect(lastQuery(), {'list': 'watchlist'});
      expect(find.text(fr.emptyWatchlist), findsOneWidget);
    });

    testWidgets('catégorie : filtre kind, pas d\'icône de type',
        (tester) async {
      backend.on(
          'GET',
          '/api/media',
          (r) => page([
                for (final m in fixtureItems)
                  if (r.query['kind'] == null || m['kind'] == r.query['kind']) m
              ]));
      await pumpLibrary(tester);
      for (final (section, kind) in [
        (LibrarySection.movies, 'movie'),
        (LibrarySection.series, 'series'),
        (LibrarySection.music, 'artist'),
        (LibrarySection.podcasts, 'podcast'),
      ]) {
        await open(tester, section);
        expect(lastQuery(), {'kind': kind});
      }
      await open(tester, LibrarySection.movies);
      expect(find.text('Sintel'), findsOneWidget);
      expect(find.text('Série Démo'), findsNothing);
      expect(find.byType(KindBadge), findsNothing);
    });

    testWidgets('média manquant : affiché grisé', (tester) async {
      await pumpLibrary(tester);
      await open(tester, LibrarySection.movies);
      final opacity = tester.widget<Opacity>(find.descendant(
          of: find.byKey(const ValueKey('media-5')), // Elephants Dream
          matching: find.byType(Opacity)));
      expect(opacity.opacity, lessThan(1));
    });

    testWidgets('format : films en 2:3, musique et podcasts carrés',
        (tester) async {
      await pumpLibrary(tester);
      // La carte a son propre ClipRRect ; le dernier est celui de l'affiche.
      Size poster(int id) => tester.getSize(find
          .descendant(
              of: find.byKey(ValueKey('media-$id')),
              matching: find.byType(ClipRRect))
          .last);
      final movie = poster(1);
      expect(movie.height / movie.width, closeTo(1.5, 0.01));
      final music = poster(7);
      expect(music.height, closeTo(music.width, 0.01));
      final podcast = poster(8);
      expect(podcast.height, closeTo(podcast.width, 0.01));
      expect(music.height, lessThan(movie.height));
      expect(music.width, greaterThan(movie.width));
    });

    testWidgets('fenêtre minimale : pas de débordement', (tester) async {
      await pumpLibrary(tester, size: const Size(960, 540));
      expect(tester.takeException(), isNull);
      await open(tester, LibrarySection.favorites);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('search-field')));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('filter-panel')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('recherche', () {
    Finder field() => find.byKey(const ValueKey('search-field'));

    Future<void> openSearch(WidgetTester tester) async {
      await pumpLibrary(tester);
      await tester.tap(field());
      await settle(tester);
    }

    Future<void> waitSearch(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 450));
      await settle(tester);
    }

    Finder chip(String group, String text) =>
        find.byKey(ValueKey('filter-$group-$text'));

    Future<void> openFilters(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
    }

    Future<void> closeFilters(WidgetTester tester) async {
      await tester.tapAt(const Offset(5, 1070)); // en dehors du panneau
      await tester.pumpAndSettle();
    }

    testWidgets('focus dans la barre de l\'en-tête : recherche en dessous',
        (tester) async {
      await pumpLibrary(tester);
      expect(find.byType(SearchView), findsNothing);
      expect(tester.getBottomLeft(field()).dy,
          lessThan(tester.getTopLeft(find.byType(LibrarySidebar)).dy));
      // Le bouton des filtres (icône seule) est juste à droite de la barre.
      expect(find.text(fr.filters), findsNothing);
      expect(tester.getTopLeft(find.byIcon(Icons.tune_rounded)).dx,
          greaterThan(tester.getTopRight(field()).dx));

      final remote = RemoteKeyHandler(GlobalKey<NavigatorState>());
      for (var i = 0; i < 5 && focusedEditable() == null; i++) {
        remote.press('up');
        await settle(tester);
      }
      expect(focusedEditable(), isNotNull, reason: 'flèche haut -> barre');
      expect(find.byType(SearchView), findsOneWidget);

      // Une entrée du menu quitte la recherche et vide la barre.
      await tester.enterText(field(), 'sin');
      await open(tester, LibrarySection.favorites);
      expect(find.byType(SearchView), findsNothing);
      expect(find.widgetWithText(TextField, 'sin'), findsNothing);
    });

    testWidgets('texte tapé : recherche après une courte pause',
        (tester) async {
      await openSearch(tester);
      final before = backend.calls('GET', '/api/media').length;
      await tester.enterText(field(), 'sin');
      await tester.pump(const Duration(milliseconds: 100));
      expect(backend.calls('GET', '/api/media').length, before,
          reason: 'pas encore');
      await waitSearch(tester);
      expect(lastQuery(), {'q': 'sin'});
    });

    testWidgets('résultats : icône du type, sinon « Aucun résultat »',
        (tester) async {
      backend.on('GET', '/api/media', (r) {
        final q = r.query['q'];
        return page([
          for (final m in fixtureItems)
            if (q == null ||
                '${m['title']}'.toLowerCase().contains(q.toLowerCase()))
              m
        ]);
      });
      await openSearch(tester);
      await tester.enterText(field(), 'démo');
      await waitSearch(tester);
      expect(find.byKey(const ValueKey('kind-series')), findsOneWidget);
      expect(find.byKey(const ValueKey('kind-music')), findsOneWidget);
      expect(find.byKey(const ValueKey('kind-podcast')), findsOneWidget);

      await tester.enterText(field(), 'zzz');
      await waitSearch(tester);
      expect(find.text(fr.noResults), findsOneWidget);
    });

    testWidgets('menu déroulant des filtres : type, genre et âge',
        (tester) async {
      await pumpLibrary(tester);
      await openFilters(tester);
      final panel = find.byKey(const ValueKey('filter-panel'));
      expect(panel, findsOneWidget);
      // Sous la barre, aligné sur son bord gauche, jusqu'au bouton.
      expect(tester.getTopLeft(panel).dy,
          greaterThan(tester.getBottomLeft(field()).dy));
      expect(tester.getTopLeft(panel).dx,
          closeTo(tester.getTopLeft(field()).dx, 1));
      expect(tester.getTopRight(panel).dx,
          closeTo(tester.getTopRight(find.byIcon(Icons.tune_rounded)).dx, 40));
      // Genres proposés : ceux du catalogue, triés.
      for (final g in ['Action', 'Animation', 'Drame', 'Thriller']) {
        expect(chip(fr.filterGenre, g), findsOneWidget, reason: g);
      }

      await tester.ensureVisible(chip(fr.filterType, fr.kindSeries));
      await tester.tap(chip(fr.filterType, fr.kindSeries));
      await tester.pumpAndSettle();
      expect(find.byType(SearchView), findsOneWidget,
          reason: 'un filtre affiche les résultats');
      expect(lastQuery(), {'kind': 'series,season,episode'});

      await tester.ensureVisible(chip(fr.filterGenre, 'Animation'));
      await tester.tap(chip(fr.filterGenre, 'Animation'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(chip(fr.filterAge, fr.ageMax(12)));
      await tester.tap(chip(fr.filterAge, fr.ageMax(12)));
      await tester.pumpAndSettle();
      expect(lastQuery(), {
        'kind': 'series,season,episode',
        'genre': 'Animation',
        'max_age': '12',
      });

      await tester.ensureVisible(chip(fr.filterType, fr.filterAll));
      await tester.tap(chip(fr.filterType, fr.filterAll));
      await tester.pumpAndSettle();
      expect(lastQuery(), {'genre': 'Animation', 'max_age': '12'});

      // Fermé : la pastille du bouton compte les filtres actifs.
      await closeFilters(tester);
      expect(panel, findsNothing);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('filters-count')),
              matching: find.text('2')),
          findsOneWidget);

      // « Effacer les filtres » remet tout à zéro.
      await openFilters(tester);
      await tester.tap(find.byKey(const ValueKey('filters-clear')));
      await tester.pumpAndSettle();
      await closeFilters(tester);
      expect(lastQuery(), isEmpty);
      expect(find.byKey(const ValueKey('filters-count')), findsNothing);
    });

    testWidgets('filtres + texte tapé : combinés', (tester) async {
      await openSearch(tester);
      await tester.enterText(field(), 'sin');
      await waitSearch(tester);
      await openFilters(tester);
      await tester.ensureVisible(chip(fr.filterType, fr.kindMovie));
      await tester.tap(chip(fr.filterType, fr.kindMovie));
      await tester.pumpAndSettle();
      expect(lastQuery(), {'q': 'sin', 'kind': 'movie'});
    });

    testWidgets('clavier du téléphone : recherche, puis sortie du champ',
        (tester) async {
      await openSearch(tester);
      final remote = RemoteKeyHandler(GlobalKey<NavigatorState>());
      remote.typeText('tears', done: true);
      await tester.pump();
      await waitSearch(tester);
      expect(lastQuery(), {'q': 'tears'});
      expect(focusedEditable(), isNull, reason: 'sorti du champ');
      expect(focusedLabel(), isNotNull, reason: 'un élément a le focus');
    });
  });
}
