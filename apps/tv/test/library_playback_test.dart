// Lire un média depuis la médiathèque (#23), avec un faux moteur :
// OK sur une affiche ouvre la fiche, « Lecture » y ouvre le lecteur.
import 'package:design_system/design_system.dart';
import 'package:epikodi_tv/api/api.dart';
import 'package:epikodi_tv/library/library_screen.dart';
import 'package:epikodi_tv/player/player_screen.dart';
import 'package:epikodi_tv/player/subtitle_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_engine.dart';
import 'support/harness.dart';

Map<String, dynamic> get detailFixture => Map<String, dynamic>.of(
    readFixture('media/get_response.json') as Map<String, dynamic>);

void main() {
  late FixtureBackend backend;
  late List<FakeEngine> engines;

  setUp(() {
    backend = FixtureBackend();
    engines = [];
  });

  Finder dialog() => find.byKey(const ValueKey('media-details'));
  Finder playButton() => find.byKey(const ValueKey('details-play'));

  String? focusedLabel() => FocusManager.instance.primaryFocus?.context
      ?.findAncestorWidgetOfExactType<FocusableCard>()
      ?.semanticLabel;

  Future<void> pumpLibrary(WidgetTester tester) async {
    await pumpTv(
      tester,
      LibraryScreen(
        api: Api(fixtureClient(backend).http),
        profile: Map<String, dynamic>.of(
            readFixture('session/select_response.json')['profile']),
        onChangeProfile: () {},
        onBackToPairing: () {},
        engineFactory: () {
          final e = FakeEngine();
          engines.add(e);
          return e;
        },
      ),
      size: const Size(1920, 1080),
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
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('« Lecture » sur un film ouvre le lecteur sur son flux',
      (tester) async {
    await pumpLibrary(tester);
    await openDetails(tester, 2);
    await tester.tap(playButton());
    await transition(tester);

    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(engines.single.opened?.uri, '$testBaseUrl/api/media/2/stream');
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

  testWidgets('un média indisponible est signalé et ne se lit pas',
      (tester) async {
    backend.on('GET', '/api/media/{id}',
        (_) => (200, {...detailFixture, 'id': 5, 'status': 'missing'}));
    await pumpLibrary(tester);
    expect(semanticsLabel('Elephants Dream, ${fr.unavailable}'),
        findsOneWidget);

    await openDetails(tester, 5);
    await tester.tap(playButton());
    await transition(tester);
    expect(find.byType(PlayerScreen), findsNothing);
    expect(engines, isEmpty);
    await unmount(tester);
  });

  testWidgets('une série ne lance pas la lecture (pas encore branchée)',
      (tester) async {
    backend.on(
        'GET',
        '/api/media/{id}',
        (_) => (
              200,
              {...detailFixture, 'id': 6, 'kind': 'series', 'title': 'Série Démo'}
            ));
    await pumpLibrary(tester);
    await openDetails(tester, 6);
    await tester.tap(playButton());
    await transition(tester);
    expect(find.byType(PlayerScreen), findsNothing);
    expect(
        find.descendant(of: dialog(), matching: find.text(fr.playSoon)),
        findsOneWidget);
    await unmount(tester);
  });

  testWidgets("le style des sous-titres est gardé d'une lecture à l'autre",
      (tester) async {
    await pumpLibrary(tester);
    await openDetails(tester, 2);
    await tester.tap(playButton());
    await transition(tester);
    final player = tester.widget<PlayerScreen>(find.byType(PlayerScreen));
    player.onSubtitleStyleChanged!(
        const SubtitleStyle(size: SubtitleSize.extraLarge));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await transition(tester);
    await tester.tap(playButton());
    await transition(tester);
    expect(tester.widget<PlayerScreen>(find.byType(PlayerScreen)).subtitleStyle,
        const SubtitleStyle(size: SubtitleSize.extraLarge));
    await unmount(tester);
  });
}
