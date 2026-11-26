// Popup d'erreur qui disparaît toute seule (partagée par les apps).
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<BuildContext> pump(WidgetTester tester, {bool reduce = false}) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Builder(builder: (c) {
          ctx = c;
          return const Scaffold(body: Text('écran'));
        }),
      ),
    ));
    return ctx;
  }

  Finder toast() => find.byKey(const ValueKey('error-toast'));

  testWidgets('apparaît puis disparaît toute seule', (tester) async {
    final ctx = await pump(tester);
    showErrorToast(ctx, 'La TV ne connaît plus ce téléphone.');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('La TV ne connaît plus ce téléphone.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(toast(), findsOneWidget, reason: 'encore là à 3 s');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(toast(), findsNothing, reason: 'partie après 4 s');
  });

  testWidgets('un appui la ferme tout de suite', (tester) async {
    final ctx = await pump(tester);
    showErrorToast(ctx, 'Code incorrect.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Code incorrect.'));
    await tester.pumpAndSettle();
    expect(toast(), findsNothing);
  });

  testWidgets('une nouvelle erreur remplace la précédente', (tester) async {
    final ctx = await pump(tester);
    showErrorToast(ctx, 'Première');
    await tester.pumpAndSettle();
    showErrorToast(ctx, 'Seconde');
    await tester.pumpAndSettle();
    expect(find.text('Première'), findsNothing);
    expect(find.text('Seconde'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(toast(), findsNothing);
  });

  testWidgets('ErrorToastTrigger : une fois par erreur, de nouveau après null',
      (tester) async {
    final ctx = await pump(tester, reduce: true);
    final trigger = ErrorToastTrigger();
    trigger.update(ctx, 'Oups');
    await tester.pump();
    await tester.pump();
    expect(find.text('Oups'), findsOneWidget);
    hideErrorToast();
    await tester.pump();
    expect(toast(), findsNothing);

    trigger.update(ctx, 'Oups'); // même erreur, pas de nouvelle popup
    await tester.pump();
    await tester.pump();
    expect(toast(), findsNothing);

    trigger.update(ctx, null); // nouvelle tentative
    trigger.update(ctx, 'Oups');
    await tester.pump();
    await tester.pump();
    expect(find.text('Oups'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('démontée avant la fin : pas de minuterie qui traîne',
      (tester) async {
    final ctx = await pump(tester);
    showErrorToast(ctx, 'Oups');
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  });
}
