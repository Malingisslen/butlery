import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/app/session_activity_detector.dart';

void main() {
  testWidgets('reports a tap on the screen below and still lets it through', (
    tester,
  ) async {
    var activity = 0;
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SessionActivityDetector(
          onActivity: () => activity++,
          child: Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => pressed++,
                child: const Text('Tryck'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tryck'));

    expect(pressed, 1);
    expect(activity, greaterThanOrEqualTo(1));
  });

  testWidgets('adds no tappable node to the semantics tree', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: SessionActivityDetector(
          onActivity: () {},
          child: const Scaffold(body: Text('Innehåll')),
        ),
      ),
    );

    // A screen-sized node with a tap action takes every web click that lands
    // where no control has a node of its own.
    expect(
      tester.semantics.simulatedAccessibilityTraversal().where(
        (node) => node.getSemanticsData().hasAction(SemanticsAction.tap),
      ),
      isEmpty,
    );
    handle.dispose();
  });
}
