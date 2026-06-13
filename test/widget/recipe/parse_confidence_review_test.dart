// BUT-925: widget tests for ParseConfidenceReview and ConfidencePill.
//
// Acceptance gate: the pill renders the correct color for each
// ParseConfidence value (high→green, medium→amber/gold, low→grey), and the
// original line is reachable per ingredient.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/theme/app_colors.dart';
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

Widget _wrap(Widget child) {
  return MaterialApp(
    // No custom theme extension → ButleryColorsAccess falls back to
    // ButleryColors.light, giving deterministic color values for assertions.
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

// Helper: find the Container that forms the confidence pill for a given
// ParseConfidence value, using the key we set in _ConfidencePill.build.
Finder _pillContainer(ParseConfidence confidence) =>
    find.byKey(ValueKey('confidence-pill-${confidence.name}'));

// Extract the BoxDecoration border color from a Container found by [finder].
Color _pillBorderColor(WidgetTester tester, Finder finder) {
  final container = tester.widget<Container>(finder);
  final decoration = container.decoration as BoxDecoration;
  return decoration.border!.top.color;
}

void main() {
  group('ConfidencePill — color-per-ParseConfidence', () {
    // Use ButleryColors.light values (the fallback when no theme extension)
    const colors = ButleryColors.light;

    testWidgets('high confidence → success green border', (tester) async {
      await tester.pumpWidget(
        _wrap(ConfidencePill(confidence: ParseConfidence.high)),
      );

      final pillFinder = _pillContainer(ParseConfidence.high);
      expect(pillFinder, findsOneWidget);

      final borderColor = _pillBorderColor(tester, pillFinder);
      expect(borderColor, equals(colors.success)); // #4A7C59 forestGreen
    });

    testWidgets('medium confidence → warning amber border', (tester) async {
      await tester.pumpWidget(
        _wrap(ConfidencePill(confidence: ParseConfidence.medium)),
      );

      final pillFinder = _pillContainer(ParseConfidence.medium);
      expect(pillFinder, findsOneWidget);

      final borderColor = _pillBorderColor(tester, pillFinder);
      expect(borderColor, equals(colors.warning)); // #D4A03C warm gold
    });

    testWidgets('low confidence → neutral grey border', (tester) async {
      await tester.pumpWidget(
        _wrap(ConfidencePill(confidence: ParseConfidence.low)),
      );

      final pillFinder = _pillContainer(ParseConfidence.low);
      expect(pillFinder, findsOneWidget);

      final borderColor = _pillBorderColor(tester, pillFinder);
      expect(borderColor, equals(AppColors.neutralMedium)); // #9CA3AF
    });

    testWidgets('pill label text matches confidence — HÖG/MEDIUM/LÅG',
        (tester) async {
      for (final entry in {
        ParseConfidence.high: 'HÖG',
        ParseConfidence.medium: 'MEDIUM',
        ParseConfidence.low: 'LÅG',
      }.entries) {
        await tester.pumpWidget(
          _wrap(ConfidencePill(confidence: entry.key)),
        );
        expect(find.text(entry.value), findsOneWidget,
            reason: '${entry.key.name} should show "${entry.value}"');
      }
    });

    test('confidenceColorFor() returns same colors as the pill build', () {
      const colors = ButleryColors.light;

      expect(
        ConfidencePill.confidenceColorFor(ParseConfidence.high, colors),
        equals(colors.success),
      );
      expect(
        ConfidencePill.confidenceColorFor(ParseConfidence.medium, colors),
        equals(colors.warning),
      );
      expect(
        ConfidencePill.confidenceColorFor(ParseConfidence.low, colors),
        equals(AppColors.neutralMedium),
      );
    });
  });

  group('ParseConfidenceReview — original line reachable', () {
    testWidgets('tapping an ingredient row expands to show original line',
        (tester) async {
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

      // Original line not visible before tap
      expect(find.textContaining(originalText), findsNothing);

      // Tap the row to expand
      await tester.tap(find.text('2 dl vetemjöl'));
      await tester.pumpAndSettle();

      // Original line now visible
      expect(find.textContaining(originalText), findsOneWidget);
    });

    testWidgets('low-confidence items appear before high-confidence ones',
        (tester) async {
      final ingredients = [
        _ingredient(
            name: 'smör',
            confidence: ParseConfidence.high,
            quantity: '100',
            unit: 'g'),
        _ingredient(name: 'mystisk sak', confidence: ParseConfidence.low),
        _ingredient(
            name: 'mjölk',
            confidence: ParseConfidence.medium,
            quantity: '3',
            unit: 'dl'),
      ];

      await tester.pumpWidget(
        _wrap(ParseConfidenceReview(ingredients: ingredients)),
      );
      await tester.pumpAndSettle();

      // Verify low-confidence pill appears in the tree
      expect(_pillContainer(ParseConfidence.low), findsOneWidget);
      expect(_pillContainer(ParseConfidence.medium), findsOneWidget);
      expect(_pillContainer(ParseConfidence.high), findsOneWidget);

      // Low must appear before medium which appears before high in render order
      final lowTop = tester.getTopLeft(_pillContainer(ParseConfidence.low)).dy;
      final medTop =
          tester.getTopLeft(_pillContainer(ParseConfidence.medium)).dy;
      final highTop =
          tester.getTopLeft(_pillContainer(ParseConfidence.high)).dy;

      expect(lowTop, lessThan(medTop),
          reason: 'low-confidence row should render above medium');
      expect(medTop, lessThan(highTop),
          reason: 'medium-confidence row should render above high');
    });

    testWidgets('renders all three confidence pills in a mixed list',
        (tester) async {
      final ingredients = [
        _ingredient(name: 'a', confidence: ParseConfidence.high),
        _ingredient(name: 'b', confidence: ParseConfidence.medium),
        _ingredient(name: 'c', confidence: ParseConfidence.low),
      ];

      await tester.pumpWidget(
        _wrap(ParseConfidenceReview(ingredients: ingredients)),
      );
      await tester.pumpAndSettle();

      expect(_pillContainer(ParseConfidence.high), findsOneWidget);
      expect(_pillContainer(ParseConfidence.medium), findsOneWidget);
      expect(_pillContainer(ParseConfidence.low), findsOneWidget);
    });

    testWidgets('warns about low-confidence count in header subtitle',
        (tester) async {
      final ingredients = [
        _ingredient(name: 'a', confidence: ParseConfidence.low),
        _ingredient(name: 'b', confidence: ParseConfidence.low),
        _ingredient(name: 'c', confidence: ParseConfidence.high),
      ];

      await tester.pumpWidget(
        _wrap(ParseConfidenceReview(ingredients: ingredients)),
      );
      await tester.pumpAndSettle();

      // Should show "2 rader med osäker tolkning"
      expect(
        find.textContaining('2 rader med osäker tolkning'),
        findsOneWidget,
      );
    });
  });
}
