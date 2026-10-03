/// BUT-2194: a cooking-mode ingredient row is at least 48 dp tall, and a long
/// press anywhere in it opens the substitutions, not only on its text. The
/// a11y matrix measures the row's size; this measures where a press lands.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/cooking/substitution_bottom_sheet.dart';

import 'state_harness.dart';
import 'state_runner.dart';

void main() {
  final row = StateFixture.load().rows.firstWhere(
    (r) => r.view == 'matlagningsläge' && r.state == 'DEFAULT',
  );

  testWidgets('a long press on the empty bottom of a short row opens the '
      'substitutions', (tester) async {
    final run = await pumpState(tester, row, Brightness.light);

    final detector = find
        .ancestor(
          of: find.text('400 g svamp').first,
          matching: find.byType(GestureDetector),
        )
        .first;
    final box = tester.getRect(detector);
    final text = tester.getRect(find.text('400 g svamp').first);
    // Premise: the press lands below the text, in the space the 48 dp
    // minimum adds.
    expect(box.height, greaterThanOrEqualTo(48));
    expect(box.bottom - 2, greaterThan(text.bottom));

    await tester.longPressAt(Offset(box.center.dx, box.bottom - 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SubstitutionBottomSheet), findsOneWidget);
    await finishState(tester, run);
  });
}
