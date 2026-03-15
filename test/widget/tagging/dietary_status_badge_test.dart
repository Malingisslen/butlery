import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/widgets/tagging/dietary_status_badge.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('DietaryStatusBadge', () {
    group('TriState rendering', () {
      testWidgets('FREE renders eco_outlined icon', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const DietaryStatusBadge(
              diet: 'vegetarisk',
              status: TriState.free,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.eco_outlined), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber), findsNothing);
        expect(find.byIcon(Icons.help_outline), findsNothing);
      });

      testWidgets('CONTAINS renders warning_amber icon', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const DietaryStatusBadge(
              diet: 'vegetarisk',
              status: TriState.contains,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.warning_amber), findsOneWidget);
        expect(find.byIcon(Icons.eco_outlined), findsNothing);
        expect(find.byIcon(Icons.help_outline), findsNothing);
      });

      testWidgets('UNKNOWN renders help_outline icon and "?" label',
          (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const DietaryStatusBadge(
              diet: 'vegetarisk',
              status: TriState.unknown,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.help_outline), findsOneWidget);
        expect(find.textContaining('?'), findsOneWidget);
      });
    });

    group('Compact mode', () {
      testWidgets('compact mode uses 14px icon', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const DietaryStatusBadge(
              diet: 'vegansk',
              status: TriState.free,
              compact: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final icon = tester.widget<Icon>(find.byIcon(Icons.eco_outlined));
        expect(icon.size, 14.0);
      });

      testWidgets('standard mode uses 18px icon', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const DietaryStatusBadge(
              diet: 'vegansk',
              status: TriState.free,
              compact: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final icon = tester.widget<Icon>(find.byIcon(Icons.eco_outlined));
        expect(icon.size, 18.0);
      });
    });

    group('Label display', () {
      testWidgets('showLabel: false hides text', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const DietaryStatusBadge(
              diet: 'vegetarisk',
              status: TriState.free,
              showLabel: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.eco_outlined), findsOneWidget);
        final textInBadge = find.descendant(
          of: find.byType(DietaryStatusBadge),
          matching: find.byType(Text),
        );
        expect(textInBadge, findsNothing);
      });

      testWidgets('custom label overrides computed label', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const DietaryStatusBadge(
              diet: 'vegetarisk',
              status: TriState.free,
              label: 'Custom Label',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Custom Label'), findsOneWidget);
      });

      testWidgets('CONTAINS shows "Inte {diet}" label', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const DietaryStatusBadge(
              diet: 'vegetarisk',
              status: TriState.contains,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Swedish l10n uses "Ej {name}" for CONTAINS
        expect(find.textContaining('Ej'), findsOneWidget);
      });
    });

    group('Semantics', () {
      testWidgets('has semantics label with diet name', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const DietaryStatusBadge(
              diet: 'vegetarisk',
              status: TriState.free,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final semanticsFinder = find.descendant(
          of: find.byType(DietaryStatusBadge),
          matching: find.byType(Semantics),
        );
        final semantics = tester.widget<Semantics>(semanticsFinder.first);
        expect(semantics.properties.label, contains('vegetarisk'));
      });
    });

    group('Fallback', () {
      testWidgets('unknown diet key falls back to raw key', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const DietaryStatusBadge(
              diet: 'custom-diet-xyz',
              status: TriState.free,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Falls back to the raw key since DietaryConfig won't have it
        expect(find.text('custom-diet-xyz'), findsOneWidget);
      });
    });
  });
}
