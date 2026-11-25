// Lire un média depuis la médiathèque (#23) : « Lecture » dans la fiche
// demande la lecture au cœur, qui ouvre le lecteur par player.command.
import 'package:design_system/design_system.dart';
import 'package:epikodi_tv/api/api.dart';
import 'package:epikodi_tv/library/library_screen.dart';
import 'package:epikodi_tv/player/player_screen.dart';
import 'package:epikodi_tv/player/server_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_engine.dart';
import 'support/fake_player_link.dart';
import 'support/harness.dart';

Map<String, dynamic> get detailFixture => Map<String, dynamic>.of(
    readFixture('media/get_response.json') as Map<String, dynamic>);

void main() {
  late FixtureBackend backend;
  late FakePlayerLink link;
  late List<FakeEngine> engines;

  setUp(() {
    backend = FixtureBackend();
    link = FakePlayerLink();
    engines = [];
    // Comme le vrai cœur : POST /api/player/play, puis `load` vers la TV.
    backend.on('POST', '/api/player/play', (r) {
      link.command(Map<String, dynamic>.of(
          readFixture('events/player_command_load.json')['data']));
      return (200, readFixture('player/state.json'));
    });
  });

  Finder dialog() => find.byKey(const ValueKey('media-details'));
  Finder playButton() => find.byKey(const ValueKey('details-play'));
  Finder inDialog(Finder f) => find.descendant(of: dialog(), matching: f);

  String? focusedLabel() => FocusManager.instance.primaryFocus?.context
      ?.findAncestorWidgetOfExactType<FocusableCard>()
      ?.semanticLabel;

  Future<void> pumpLibrary(WidgetTester tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await pumpTv(
      tester,
      LibraryScreen(
        api: Api(fixtureClient(backend).http),
        profile: Map<String, dynamic>.of(
            readFixture('session/select_response.json')['profile']),
        onChangeProfile: () {},
        onBackToPairing: () {},
      ),
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

  /// Ouvre la fiche du média [id] (la fixture de fiche est Sintel, id 2).
  Future<void> openDetails(WidgetTester tester, int id) async {
    await tester.tap(find.byKey(ValueKey('media-$id')));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(dialog(), findsOneWidget);
  }

  Future<void> transition(WidgetTester tester) async {
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('« Lecture » demande la lecture au cœur, qui ouvre le lecteur',
      (tester) async {
    await pumpLibrary(tester);
    await openDetails(tester, 2);
    await tester.tap(playButton());
    await transition(tester);

    expect(backend.last('POST', '/api/player/play')?.body,
        {'media_id': 2, 'resume': true});
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(engines.single.opened?.title, 'Sintel');
    await unmount(tester);
  });

  testWidgets('Retour revient sur la fiche, focus sur « Lecture »',
      (tester) async {
    await pumpLibrary(tester);
    await openDetails(tester, 2);
    // « Lecture » a le focus à l'ouverture de la fiche : Entrée lance.
    final before = FocusManager.instance.primaryFocus;
    expect(focusedLabel(), fr.play);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await transition(tester);
    expect(find.byType(PlayerScreen), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await transition(tester);
    expect(find.byType(PlayerScreen), findsNothing);
    expect(engines.single.disposed, isTrue);
    expect(dialog(), findsOneWidget);
    expect(FocusManager.instance.primaryFocus, before);
    await unmount(tester);
  });

  testWidgets('refus du cœur : message dans la fiche, pas de lecteur',
      (tester) async {
    backend.fail('POST', '/api/player/play',
        status: 409, code: 'nothing_to_play', message: 'Rien à lire.');
    await pumpLibrary(tester);
    await openDetails(tester, 2);
    await tester.tap(playButton());
    await transition(tester);

    expect(find.byType(PlayerScreen), findsNothing);
    expect(inDialog(find.text('Rien à lire.')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('un média indisponible est signalé et ne se lit pas',
      (tester) async {
    backend.on('GET', '/api/media/{id}',
        (_) => (200, {...detailFixture, 'id': 5, 'status': 'missing'}));
    await pumpLibrary(tester);
    expect(
        semanticsLabel('Elephants Dream, ${fr.unavailable}'), findsOneWidget);

    await openDetails(tester, 5);
    await tester.tap(playButton());
    await transition(tester);
    expect(backend.calls('POST', '/api/player/play'), isEmpty);
    expect(find.byType(PlayerScreen), findsNothing);
    await unmount(tester);
  });

  testWidgets('une série se lit aussi : le cœur choisit l\'épisode',
      (tester) async {
    backend.on(
        'GET',
        '/api/media/{id}',
        (_) => (
              200,
              {
                ...detailFixture,
                'id': 6,
                'kind': 'series',
                'title': 'Série Démo'
              }
            ));
    await pumpLibrary(tester);
    await openDetails(tester, 6);
    await tester.tap(playButton());
    await transition(tester);
    expect(backend.last('POST', '/api/player/play')?.body,
        {'media_id': 6, 'resume': true});
    await unmount(tester);
  });
}
