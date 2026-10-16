import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/tagging/rule_condition_card.dart';

void main() {
  // Behavior: the type and operator dropdowns share one row, and every
  // type label must fit it on a phone-width screen.
  for (final type in ConditionType.values) {
    testWidgets('lays out ${type.name} on a 320 dp screen without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('sv'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: RuleConditionCard(
              condition: RuleCondition(
                type: type,
                operator: ConditionOperator.contains,
                value: 'x',
              ),
              canDelete: true,
              onTypeChanged: (_) {},
              onOperatorChanged: (_) {},
              onValueChanged: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  }
}
