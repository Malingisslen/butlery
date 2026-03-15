import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/widgets/tagging/allergen_status_badge.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('AllergenStatusBadge', () {
    group('TriState rendering', () {
      testWidgets('should show check_circle_outline icon for FREE status',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const AllergenStatusBadge(
              allergen: 'gluten',
              status: TriState.free,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber), findsNothing);
        expect(find.byIcon(Icons.help_outline), findsNothing);
      });

      testWidgets('should show warning_amber icon for CONTAINS status',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const AllergenStatusBadge(
              allergen: 'gluten',
              status: TriState.contains,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.warning_amber), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsNothing);
        expect(find.byIcon(Icons.help_outline), findsNothing);
      });

      testWidgets('should show help_outline icon for UNKNOWN status',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const AllergenStatusBadge(
              allergen: 'gluten',
              status: TriState.unknown,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.help_outline), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsNothing);
        expect(find.byIcon(Icons.warning_amber), findsNothing);
      });
    });

    group('Compact mode', () {
      testWidgets('should render 14px icon in compact mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const AllergenStatusBadge(
              allergen: 'gluten',
              status: TriState.free,
              compact: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final icon =
            tester.widget<Icon>(find.byIcon(Icons.check_circle_outline));
        expect(icon.size, 14.0);
      });

      testWidgets('should render 18px icon in standard mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const AllergenStatusBadge(
              allergen: 'gluten',
              status: TriState.free,
              compact: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final icon =
            tester.widget<Icon>(find.byIcon(Icons.check_circle_outline));
        expect(icon.size, 18.0);
      });
    });

    group('Label display', () {
      testWidgets('should hide text when showLabel is false',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const AllergenStatusBadge(
              allergen: 'gluten',
              status: TriState.free,
              showLabel: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The icon should still render
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        // No Text widget inside the badge row — find text descendants of the badge
        final badgeFinder = find.byType(AllergenStatusBadge);
        final textInBadge = find.descendant(
          of: badgeFinder,
          matching: find.byType(Text),
        );
        expect(textInBadge, findsNothing);
      });

      testWidgets('should show text when showLabel is true (default)',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const AllergenStatusBadge(
              allergen: 'gluten',
              status: TriState.free,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Text descendant should exist inside the badge
        final badgeFinder = find.byType(AllergenStatusBadge);
        final textInBadge = find.descendant(
          of: badgeFinder,
          matching: find.byType(Text),
        );
        expect(textInBadge, findsOneWidget);
      });

      testWidgets('should use custom label when provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const AllergenStatusBadge(
              allergen: 'gluten',
              status: TriState.free,
              label: 'Custom Label',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Custom Label'), findsOneWidget);
      });

      testWidgets(
          'should use default allergen label from config when no custom label',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const AllergenStatusBadge(
              allergen: 'gluten',
              status: TriState.free,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // AllergenConfig for 'gluten' has freeTag: 'glutenfri'
        expect(find.text('glutenfri'), findsOneWidget);
      });
    });

    group('Coverage display', () {
      testWidgets(
          'should append coverage text for UNKNOWN status with coveragePercent',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const AllergenStatusBadge(
              allergen: 'gluten',
              status: TriState.unknown,
              coveragePercent: 75,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Label format: "gluten okänd (75% täckning)"
        expect(find.textContaining('75% täckning'), findsOneWidget);
      });

      testWidgets(
          'should not show coverage text for FREE status even with coveragePercent',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const AllergenStatusBadge(
              allergen: 'gluten',
              status: TriState.free,
              coveragePercent: 75,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Coverage only appended for UNKNOWN status
        expect(find.textContaining('täckning'), findsNothing);
      });

      testWidgets(
          'should not show coverage text for CONTAINS status even with coveragePercent',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const AllergenStatusBadge(
              allergen: 'gluten',
              status: TriState.contains,
              coveragePercent: 90,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('täckning'), findsNothing);
      });
    });

    group('Semantics', () {
      testWidgets(
          'should have Semantics label containing allergen name for FREE',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const AllergenStatusBadge(
              allergen: 'gluten',
              status: TriState.free,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the Semantics widget that is a direct descendant of the badge
        final semanticsFinder = find.descendant(
          of: find.byType(AllergenStatusBadge),
          matching: find.byType(Semantics),
        );
        final semantics = tester.widget<Semantics>(semanticsFinder.first);
        // Semantic label: "Fri från gluten"
        expect(semantics.properties.label, contains('gluten'));
        expect(semantics.properties.label, contains('Fri'));
      });

      testWidgets(
          'should have Semantics label containing allergen name for CONTAINS',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const AllergenStatusBadge(
              allergen: 'mjölk',
              status: TriState.contains,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final semanticsFinder = find.descendant(
          of: find.byType(AllergenStatusBadge),
          matching: find.byType(Semantics),
        );
        final semantics = tester.widget<Semantics>(semanticsFinder.first);
        // Semantic label: "Innehåller mjölk"
        expect(semantics.properties.label, contains('mjölk'));
        expect(semantics.properties.label, contains('Innehåller'));
      });

      testWidgets(
          'should have Semantics label containing allergen name for UNKNOWN',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const AllergenStatusBadge(
              allergen: 'nötter',
              status: TriState.unknown,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final semanticsFinder = find.descendant(
          of: find.byType(AllergenStatusBadge),
          matching: find.byType(Semantics),
        );
        final semantics = tester.widget<Semantics>(semanticsFinder.first);
        // Semantic label: "nötter status okänd"
        expect(semantics.properties.label, contains('nötter'));
        expect(semantics.properties.label, contains('okänd'));
      });
    });
  });
}
