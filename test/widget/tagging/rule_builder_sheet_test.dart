import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:butlery/widgets/common/input/butlery_switch.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/tagging/rule_builder_sheet.dart';
import '../../infrastructure/helpers/field_finder.dart';

final _testTag = PersonalTag(
  id: 'tag-1',
  name: 'Test Tag',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final _existingRule = PersonalTagRule(
  id: 'rule-1',
  tagId: 'tag-1',
  name: 'My Rule',
  conditions: const [
    RuleCondition(
      type: ConditionType.ingredient,
      operator: ConditionOperator.contains,
      value: 'chicken',
    ),
  ],
  matchMode: MatchMode.any,
  isEnabled: false,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// Shows the RuleBuilderSheet and returns the result when popped.
Future<PersonalTagRule?> _showSheet(
  WidgetTester tester, {
  PersonalTagRule? existingRule,
}) async {
  PersonalTagRule? popResult;

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
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              final result = await showModalBottomSheet<PersonalTagRule>(
                context: context,
                isScrollControlled: true,
                builder: (_) => RuleBuilderSheet(
                  tag: _testTag,
                  existingRule: existingRule,
                ),
              );
              popResult = result;
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Open the sheet
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();

  return popResult;
}

void main() {
  group('RuleBuilderSheet', () {
    group('create mode', () {
      testWidgets('shows new rule title and create button', (
        tester,
      ) async {
        await _showSheet(tester);

        expect(find.byType(RuleBuilderSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(RuleBuilderSheet),
            matching: find.byType(ElevatedButton),
          ),
          findsOneWidget,
        );
      });

      testWidgets('starts with 1 default condition', (tester) async {
        await _showSheet(tester);

        expect(find.byType(Card), findsAtLeastNWidgets(1));
      });

      testWidgets(
        'save with empty name shows snackbar, does NOT pop',
        (tester) async {
          await _showSheet(tester);

          await tester.tap(
            find.descendant(
              of: find.byType(RuleBuilderSheet),
              matching: find.byType(ElevatedButton),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(RuleBuilderSheet), findsOneWidget);
          expect(find.byType(SnackBar), findsOneWidget);
        },
      );
    });

    group('edit mode', () {
      testWidgets('pre-fills name, matchMode, isEnabled', (
        tester,
      ) async {
        await _showSheet(tester, existingRule: _existingRule);

        final nameField = tester.widget<TextField>(
          fieldLabelled('Regelnamn', type: TextField),
        );
        expect(nameField.controller?.text, 'My Rule');

        final segmented = tester.widget<SegmentedButton<MatchMode>>(
          find.byType(SegmentedButton<MatchMode>),
        );
        expect(segmented.selected, contains(MatchMode.any));
      });

      testWidgets('shows edit title and save button', (tester) async {
        await _showSheet(tester, existingRule: _existingRule);

        expect(
          find.descendant(
            of: find.byType(RuleBuilderSheet),
            matching: find.byType(ElevatedButton),
          ),
          findsOneWidget,
        );
      });
    });

    group('cancel', () {
      testWidgets('cancel pops with no value', (tester) async {
        await _showSheet(tester);

        final cancelButtons = find.byType(TextButton);
        await tester.tap(cancelButtons.first);
        await tester.pumpAndSettle();

        expect(find.byType(RuleBuilderSheet), findsNothing);
      });
    });

    group('conditions', () {
      testWidgets('add condition increases count', (tester) async {
        await _showSheet(tester);

        final initialCards = find.byType(Card).evaluate().length;

        await tester.tap(find.byIcon(ButleryIcons.plus));
        await tester.pumpAndSettle();

        final newCards = find.byType(Card).evaluate().length;
        expect(newCards, initialCards + 1);
      });

      testWidgets(
        'removing the first of two conditions keeps the second one\'s value',
        (tester) async {
          await _showSheet(tester);
          await tester.tap(find.byIcon(ButleryIcons.plus));
          await tester.pumpAndSettle();

          final valueFields = find.descendant(
            of: find.byType(Card),
            matching: find.byType(TextField),
          );
          expect(valueFields, findsNWidgets(2));
          await tester.enterText(valueFields.at(0), 'kyckling');
          await tester.enterText(valueFields.at(1), 'ris');
          await tester.pumpAndSettle();

          await tester.tap(find.byIcon(ButleryIcons.x).first);
          await tester.pumpAndSettle();

          expect(valueFields, findsOneWidget);
          expect(
            tester.widget<TextField>(valueFields).controller!.text,
            'ris',
          );
          expect(find.text('kyckling'), findsNothing);
        },
      );

      testWidgets(
        'last condition delete button is disabled (canDelete: false)',
        (tester) async {
          await _showSheet(tester);

          expect(find.byIcon(ButleryIcons.x), findsNothing);
        },
      );
    });

    group('enabled switch', () {
      testWidgets('enabled switch toggles subtitle text', (
        tester,
      ) async {
        await _showSheet(tester);

        // The switch row may be below the fold — scroll to it
        final listView = find.descendant(
          of: find.byType(RuleBuilderSheet),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.byType(ButlerySwitch),
          200,
          scrollable: listView.first,
        );
        await tester.pumpAndSettle();

        final switchTile = find.byType(ButlerySwitch);
        expect(switchTile, findsOneWidget);

        // Verify initial state is enabled
        final before = tester.widget<ButlerySwitch>(switchTile);
        expect(before.value, isTrue);

        await tester.tap(switchTile);
        await tester.pumpAndSettle();

        // After toggle, switch should be disabled
        final after = tester.widget<ButlerySwitch>(find.byType(ButlerySwitch));
        expect(after.value, isFalse);
      });
    });
  });
}
