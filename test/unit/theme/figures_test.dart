// Butlery Sans draws tabular figures unless asked otherwise, so running text
// and fields get proportional figures from the theme and only the roles whose
// numbers must line up opt back in.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/field_text_style.dart';

void main() {
  const proportional = FontFeature.proportionalFigures();
  const tabular = FontFeature.tabularFigures();

  group('text theme', () {
    final textTheme = AppTextStyles.createTextTheme();

    for (final entry in {
      'bodyLarge': textTheme.bodyLarge,
      'bodyMedium': textTheme.bodyMedium,
      'bodySmall': textTheme.bodySmall,
      'labelLarge': textTheme.labelLarge,
      'labelMedium': textTheme.labelMedium,
      'titleMedium': textTheme.titleMedium,
    }.entries) {
      test('${entry.key} carries proportional figures', () {
        expect(entry.value!.fontFeatures, [proportional]);
      });
    }

    test('the statistics and timer role keeps tabular figures', () {
      expect(AppTextStyles.statNumber.fontFeatures, [tabular]);
    });
  });

  for (final dark in [false, true]) {
    testWidgets('${dark ? 'dark' : 'light'}: a field types in proportional '
        'figures', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextField(
                controller: TextEditingController(text: '45'),
                style: fieldTextStyle(context, enabled: true),
              ),
            ),
          ),
        ),
      );
      final style = tester
          .widget<EditableText>(find.byType(EditableText))
          .style;
      expect(style.fontFeatures, contains(proportional));
      expect(style.fontFeatures, isNot(contains(tabular)));
    });
  }
}
