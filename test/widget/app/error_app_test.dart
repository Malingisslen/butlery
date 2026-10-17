/// ErrorApp is what a user sees when bootstrap throws, with no localisations
/// or services loaded. It must render on its own, offer a restart, and keep
/// the technical message behind "Visa detaljer".
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/app/butlery_app.dart';

void main() {
  const technical = 'FirebaseException: [core/no-app] boom';

  testWidgets('renders without localisations and hides the technical text', (
    tester,
  ) async {
    await tester.pumpWidget(ErrorApp(technical, onRestart: () {}));

    expect(find.text(ErrorApp.title), findsOneWidget);
    expect(find.text(ErrorApp.explanation), findsOneWidget);
    expect(find.text(ErrorApp.detailsLabel), findsOneWidget);
    expect(find.text(technical), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Starta om" calls onRestart once', (tester) async {
    var restarts = 0;
    await tester.pumpWidget(ErrorApp(technical, onRestart: () => restarts++));

    await tester.tap(find.text(ErrorApp.restartLabel));
    await tester.pump();

    expect(restarts, 1);
  });

  testWidgets('"Visa detaljer" reveals the message', (tester) async {
    await tester.pumpWidget(ErrorApp(technical, onRestart: () {}));

    await tester.tap(find.text(ErrorApp.detailsLabel));
    await tester.pumpAndSettle();

    expect(find.text(technical), findsOneWidget);
  });
}
