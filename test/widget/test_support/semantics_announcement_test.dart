// The instrument BUT-1953's sweep measures with, measured itself: each
// helper must fail on the shape it exists to catch.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_support/semantics_announcement.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('a label restating its visible text is caught', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        Semantics(
          label: 'Öppna Pasta',
          button: true,
          child: GestureDetector(onTap: () {}, child: const Text('Pasta')),
        ),
      ),
    );
    final node = find.bySemanticsLabel(RegExp('Öppna'));

    expect(announcedLines(tester, node), ['Öppna Pasta', 'Pasta']);
    expect(
      () => expectNothingAnnouncedTwice(tester, node),
      throwsA(isA<TestFailure>()),
    );
    handle.dispose();
  });

  testWidgets('an action label beside the visible noun passes', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        Semantics(
          label: 'Öppna',
          button: true,
          child: GestureDetector(onTap: () {}, child: const Text('Pasta')),
        ),
      ),
    );
    final node = find.bySemanticsLabel(RegExp('Öppna'));

    expectNothingAnnouncedTwice(tester, node);
    expectActivatable(tester, node);
    handle.dispose();
  });

  testWidgets('excludeSemantics without onTap is caught as not activatable', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        Semantics(
          label: 'Pasta',
          button: true,
          excludeSemantics: true,
          child: GestureDetector(onTap: () {}, child: const Text('Pasta')),
        ),
      ),
    );
    final node = find.bySemanticsLabel('Pasta');

    expect(
      () => expectActivatable(tester, node),
      throwsA(isA<TestFailure>()),
    );
    handle.dispose();
  });
}
