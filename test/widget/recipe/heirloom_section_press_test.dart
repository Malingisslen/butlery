// BUT-2266: the scanned page of an heirloom recipe presses like a photo
// (R8-4 = C): it scales to 97 % while pressed and keeps no old press.

import 'package:butlery/models/recipe/heirloom_metadata.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/recipe/heirloom_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infrastructure/helpers/ink_fill.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('a pressed scan scales to 97 % and keeps no old press', (
    tester,
  ) async {
    final heirloom = HeirloomMetadata(
      sourceImageUrl: 'https://example.invalid/heirloom.jpg',
      addedAt: DateTime(2026, 1, 1),
      addedByUserId: 'user_1',
    );
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: SizedBox(
          height: 400,
          width: 300,
          child: HeirloomSection(heirloom: heirloom),
        ),
      ),
    );

    final section = find.byType(HeirloomSection);
    expect(
      find.descendant(of: section, matching: find.byType(PressUnchanged)),
      findsNothing,
    );
    double scale() => tester
        .widget<AnimatedScale>(
          find.descendant(of: section, matching: find.byType(AnimatedScale)),
        )
        .scale;

    expect(scale(), 1);
    final gesture = await holdPress(tester, find.byType(PressScale));
    expect(scale(), PressScale.pressedScale);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(scale(), 1);
  });
}
