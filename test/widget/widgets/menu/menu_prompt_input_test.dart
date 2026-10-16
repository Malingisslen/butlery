/// The week generator's prompt row: at 320 dp and 200 % text the button
/// goes under the field instead of squeezing it, and nothing overflows
/// (BUT-2192).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/menu/veckomeny_prompt_row.dart';
import 'package:butlery/widgets/common/input/styled_input.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('VeckomenyPromptRow - 320 dp and 200 % text', () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController(text: 'pasta'));
    tearDown(() => controller.dispose());

    testWidgets('the field and the button stay inside the row', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 2.0,
            maxScaleFactor: 2.0,
            child: VeckomenyPromptRow(
              controller: controller,
              isGenerating: false,
              hasMenu: false,
              compact: false,
              onClear: () {},
              onChanged: () {},
              onGenerate: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final field = find.byType(StyledInput);
      expect(field, findsOneWidget);
      expect(tester.getRect(field).right, lessThanOrEqualTo(320));
      final button = find.text('Generera meny');
      expect(button, findsOneWidget);
      // Under the field, not beside it.
      expect(
        tester.getRect(button).top,
        greaterThanOrEqualTo(tester.getRect(field).bottom),
      );
    });
  });
}
