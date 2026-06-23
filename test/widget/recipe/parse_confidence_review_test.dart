// BUT-925: widget tests for ParseConfidenceReview and the colour accent bar.
//
// Acceptance gate: each row renders a coloured left bar (not a pill label)
// at the correct colour token, the original line is reachable only when
// non-whitespace differences exist, and screen-reader semantics include the
// confidence word in the row label.
//
// BUT-1244: updated to assert via l10n keys and ButleryColors tokens.
// BUT-1244-redesign: updated for the new left-bar design (no pill labels,
// whitespace-only suppression, subtitle counts non-high rows).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/recipe/parse_confidence_review.dart';

// Test fixture helpers

ParsedIngredient _ingredient({
  required String name,
  required ParseConfidence confidence,
  String? originalLine,
  String? quantity,
  String? unit,
}) {
  return ParsedIngredient(
    name: name,
    originalLine: originalLine ?? name,
    confidence: confidence,
    quantity: quantity,
    unit: unit,
  );
}

/// Wraps [child] with full theme + Swedish l10n so context.l10n and
/// context.butleryColors both resolve to their light-mode values.
Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// Finds the accent-bar Container for a given [ParseConfidence] using the
/// ValueKey set in _IngredientConfidenceRow.build.
Finder _barContainer(ParseConfidence confidence) =>
    find.byKey(ValueKey('confidence-bar-${confidence.name}'));

/// Reads the solid [color] from the Container found by [finder].
Color _barColor(WidgetTester tester, Finder finder) {
  final container = tester.widget<Container>(finder);
  return container.color!;
}

void main() {
  const colors = ButleryColors.light;

  group('Accent bar — colour-per-ParseConfidence', () {
    testWidgets('high confidence → success green bar', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ParseConfidenceReview(
            ingredients: [
              _ingredient(name: 'smör', confidence: ParseConfidence.high),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bar = _barContainer(ParseConfidence.high);
      expect(bar, findsOneWidget);
      expect(_barColor(tester, bar), equals(colors.success));
    });

    testWidgets('medium confidence → warning amber bar', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ParseConfidenceReview(
            ingredients: [
              _ingredient(name: 'mjölk', confidence: ParseConfidence.medium),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bar = _barContainer(ParseConfidence.medium);
      expect(bar, findsOneWidget);
      expect(_barColor(tester, bar), equals(colors.warning));
    });

    testWidgets('low confidence → neutral grey bar', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ParseConfidenceReview(
            ingredients: [
              _ingredient(name: 'mystisk sak', confidence: ParseConfidence.low),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bar = _barContainer(ParseConfidence.low);
      expect(bar, findsOneWidget);
      expect(_barColor(tester, bar), equals(colors.neutral));
    });

    testWidgets('failed confidence → neutral grey bar (same as low)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ParseConfidenceReview(
            ingredients: [
              _ingredient(
                name: 'okänd sak',
                confidence: ParseConfidence.failed,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bar = _barContainer(ParseConfidence.failed);
      expect(bar, findsOneWidget);
      expect(_barColor(tester, bar), equals(colors.neutral));
    });
  });

  group('No visible HÖG/MEDEL/LÅG/OKÄND pill labels', () {
    testWidgets('pill text labels are NOT rendered in the UI', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ParseConfidenceReview(
            ingredients: [
              _ingredient(name: 'a', confidence: ParseConfidence.high),
              _ingredient(name: 'b', confidence: ParseConfidence.medium),
              _ingredient(name: 'c', confidence: ParseConfidence.low),
              _ingredient(name: 'd', confidence: ParseConfidence.failed),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Old pill text labels must not appear anywhere
      expect(find.text('HÖG'), findsNothing);
      expect(find.text('MEDEL'), findsNothing);
      expect(find.text('LÅG'), findsNothing);
      expect(find.text('OKÄND'), findsNothing);
      // English variants too (in case locale resolution differs in CI)
      expect(find.text('HIGH'), findsNothing);
      expect(find.text('MEDIUM'), findsNothing);
      expect(find.text('LOW'), findsNothing);
      expect(find.text('UNKNOWN'), findsNothing);
    });
  });

  group('confidenceColorFor() helper', () {
    test('returns correct token per confidence', () {
      expect(confidenceColorFor(ParseConfidence.high, colors), colors.success);
      expect(
        confidenceColorFor(ParseConfidence.medium, colors),
        colors.warning,
      );
      expect(confidenceColorFor(ParseConfidence.low, colors), colors.neutral);
      expect(
        confidenceColorFor(ParseConfidence.failed, colors),
        colors.neutral,
      );
    });
  });

  group('ParseConfidenceReview — subtitle counts non-high rows', () {
    testWidgets('medium + low each count toward the review total', (
      tester,
    ) async {
      final ingredients = [
        _ingredient(name: 'a', confidence: ParseConfidence.low),
        _ingredient(name: 'b', confidence: ParseConfidence.medium),
        _ingredient(name: 'c', confidence: ParseConfidence.high),
      ];

      await tester.pumpWidget(
        _wrap(ParseConfidenceReview(ingredients: ingredients)),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ParseConfidenceReview)),
      );
      // 2 non-high rows (a=low, b=medium) → subtitle shows count=2
      expect(
        find.textContaining(l10n.parseConfidenceReviewCountSubtitle(2)),
        findsOneWidget,
      );
    });

    testWidgets('subtitle not shown when all rows are high confidence', (
      tester,
    ) async {
      final ingredients = [
        _ingredient(name: 'a', confidence: ParseConfidence.high),
        _ingredient(name: 'b', confidence: ParseConfidence.high),
      ];

      await tester.pumpWidget(
        _wrap(ParseConfidenceReview(ingredients: ingredients)),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ParseConfidenceReview)),
      );
      // Assert against the count=1 string (not count=0): it can only be absent
      // because reviewCount==0 suppressed the whole subtitle, NOT because the
      // format string happens to differ — a stronger guard than findsNothing(0).
      expect(
        find.textContaining(l10n.parseConfidenceReviewCountSubtitle(1)),
        findsNothing,
      );
    });
  });

  group('ParseConfidenceReview — sort order', () {
    testWidgets('low-confidence items appear before high-confidence ones', (
      tester,
    ) async {
      final ingredients = [
        _ingredient(
          name: 'smör',
          confidence: ParseConfidence.high,
          quantity: '100',
          unit: 'g',
        ),
        _ingredient(name: 'mystisk sak', confidence: ParseConfidence.low),
        _ingredient(
          name: 'mjölk',
          confidence: ParseConfidence.medium,
          quantity: '3',
          unit: 'dl',
        ),
      ];

      await tester.pumpWidget(
        _wrap(ParseConfidenceReview(ingredients: ingredients)),
      );
      await tester.pumpAndSettle();

      final lowBar = _barContainer(ParseConfidence.low);
      final medBar = _barContainer(ParseConfidence.medium);
      final highBar = _barContainer(ParseConfidence.high);

      expect(
        tester.getTopLeft(lowBar).dy,
        lessThan(tester.getTopLeft(medBar).dy),
        reason: 'low-confidence row should render above medium',
      );
      expect(
        tester.getTopLeft(medBar).dy,
        lessThan(tester.getTopLeft(highBar).dy),
        reason: 'medium-confidence row should render above high',
      );
    });
  });

  group('ParseConfidenceReview — original line expand/collapse', () {
    testWidgets('tapping a row with a genuinely different original shows it', (
      tester,
    ) async {
      const originalText = '2dl vetemjöl siktat';
      final ingredients = [
        _ingredient(
          name: 'vetemjöl',
          confidence: ParseConfidence.medium,
          originalLine: originalText,
          quantity: '2',
          unit: 'dl',
        ),
      ];

      await tester.pumpWidget(
        _wrap(ParseConfidenceReview(ingredients: ingredients)),
      );

      expect(find.textContaining(originalText), findsNothing);

      await tester.tap(find.text('2 dl vetemjöl'));
      await tester.pumpAndSettle();

      expect(find.textContaining(originalText), findsOneWidget);
    });

    testWidgets(
      'whitespace-only difference does NOT show the chevron or original line',
      (tester) async {
        // "100g smör" vs "100 g smör" — differ only by a space → no expand arrow.
        final ingredients = [
          _ingredient(
            name: 'smör',
            confidence: ParseConfidence.high,
            originalLine: '100g smör',
            quantity: '100',
            unit: 'g',
          ),
        ];

        await tester.pumpWidget(
          _wrap(ParseConfidenceReview(ingredients: ingredients)),
        );
        await tester.pumpAndSettle();

        // No expand chevron rendered
        expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
        expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);

        // Tapping the row still does nothing
        await tester.tap(find.text('100 g smör'));
        await tester.pumpAndSettle();
        expect(find.textContaining('100g smör'), findsNothing);
      },
    );

    testWidgets('non-whitespace different original DOES show the chevron', (
      tester,
    ) async {
      final ingredients = [
        _ingredient(
          name: 'mjölk',
          confidence: ParseConfidence.medium,
          originalLine: '3dl helmjölk',
          quantity: '3',
          unit: 'dl',
        ),
      ];

      await tester.pumpWidget(
        _wrap(ParseConfidenceReview(ingredients: ingredients)),
      );
      await tester.pumpAndSettle();

      // Chevron is visible before expand
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });
  });

  group('Accessibility — semantics label includes confidence word', () {
    testWidgets('high-confidence row semantics include confidence word', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _wrap(
          ParseConfidenceReview(
            ingredients: [
              _ingredient(name: 'smör', confidence: ParseConfidence.high),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ParseConfidenceReview)),
      );
      final expectedLabel = l10n.a11yIngredientWithConfidence(
        'smör',
        l10n.a11yConfidenceHigh,
      );

      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(expectedLabel))),
        findsOneWidget,
        reason: 'Row semantics must include both name and confidence word',
      );

      handle.dispose();
    });

    testWidgets('low-confidence row semantics include confidence word', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _wrap(
          ParseConfidenceReview(
            ingredients: [
              _ingredient(name: 'mystisk sak', confidence: ParseConfidence.low),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ParseConfidenceReview)),
      );
      final expectedLabel = l10n.a11yIngredientWithConfidence(
        'mystisk sak',
        l10n.a11yConfidenceLow,
      );

      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(expectedLabel))),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('medium-confidence row semantics include confidence word', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _wrap(
          ParseConfidenceReview(
            ingredients: [
              _ingredient(name: 'mjölk', confidence: ParseConfidence.medium),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ParseConfidenceReview)),
      );
      final expectedLabel = l10n.a11yIngredientWithConfidence(
        'mjölk',
        l10n.a11yConfidenceMedium,
      );

      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(expectedLabel))),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('failed-confidence row semantics include confidence word', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _wrap(
          ParseConfidenceReview(
            ingredients: [
              _ingredient(
                name: 'okänd sak',
                confidence: ParseConfidence.failed,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ParseConfidenceReview)),
      );
      final expectedLabel = l10n.a11yIngredientWithConfidence(
        'okänd sak',
        l10n.a11yConfidenceFailed,
      );

      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(expectedLabel))),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
