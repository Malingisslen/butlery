// test/widget/components/empty_states_test.dart
// Tests for EmptyStates widget — variants, custom content, layout.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/state/empty_states.dart';
import 'package:butlery/widgets/common/state/state_enums.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/theme/app_dimensions.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('EmptyStates.buildEmptyState', () {
    // ───── Custom content (variant: null) ─────

    testWidgets('displays custom title and subtitle', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => EmptyStates.buildEmptyState(
              ctx,
              variant: null,
              title: 'Custom Title',
              subtitle: 'Custom Subtitle',
            ),
          ),
        ),
      );

      expect(find.text('Custom Title'), findsOneWidget);
      expect(find.text('Custom Subtitle'), findsOneWidget);
    });

    testWidgets('displays custom icon when provided', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => EmptyStates.buildEmptyState(
              ctx,
              variant: null,
              title: 'Test',
              icon: Icons.favorite,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('hides icon when Icons.clear is passed', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => EmptyStates.buildEmptyState(
              ctx,
              variant: null,
              title: 'No Icon',
              icon: Icons.clear,
            ),
          ),
        ),
      );

      expect(find.byType(Icon), findsNothing);
      expect(find.text('No Icon'), findsOneWidget);
    });

    testWidgets('displays action button and triggers callback', (tester) async {
      bool actionCalled = false;

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => EmptyStates.buildEmptyState(
              ctx,
              variant: null,
              title: 'Test',
              actionLabel: 'Retry',
              onAction: () => actionCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(actionCalled, isTrue);
    });

    testWidgets('displays custom action widget', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => EmptyStates.buildEmptyState(
              ctx,
              variant: null,
              title: 'Test',
              customAction: const Text('Custom Action Widget'),
            ),
          ),
        ),
      );

      expect(find.text('Custom Action Widget'), findsOneWidget);
    });

    testWidgets('uses custom padding when provided', (tester) async {
      const customPadding = EdgeInsets.all(50.0);

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => EmptyStates.buildEmptyState(
              ctx,
              variant: null,
              title: 'Test',
              padding: customPadding,
            ),
          ),
        ),
      );

      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(padding.padding, equals(customPadding));
    });

    testWidgets('uses default padding when not provided', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => EmptyStates.buildEmptyState(
              ctx,
              variant: null,
              title: 'Test',
            ),
          ),
        ),
      );

      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(
        padding.padding,
        equals(const EdgeInsets.all(AppDimensions.spacingXl)),
      );
    });

    testWidgets('wraps content in SingleChildScrollView', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => EmptyStates.buildEmptyState(
              ctx,
              variant: null,
              title: 'Scrollable',
              subtitle: 'Long text for scrolling test',
            ),
          ),
        ),
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('centers content', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => EmptyStates.buildEmptyState(
              ctx,
              variant: null,
              title: 'Centered',
            ),
          ),
        ),
      );

      expect(find.byType(Center), findsWidgets);

      final titleText = tester.widget<Text>(find.text('Centered'));
      expect(titleText.textAlign, equals(TextAlign.center));
    });

    testWidgets('applies custom icon color and size', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => EmptyStates.buildEmptyState(
              ctx,
              variant: null,
              title: 'Test',
              icon: Icons.error,
              iconColor: Colors.red,
              iconSize: 100.0,
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.error));
      expect(icon.color, equals(Colors.red));
      expect(icon.size, equals(100.0));
    });

    testWidgets('hides subtitle when not provided', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => EmptyStates.buildEmptyState(
              ctx,
              variant: null,
              title: 'Title Only',
            ),
          ),
        ),
      );

      expect(find.text('Title Only'), findsOneWidget);
      // Only title text should be present (no subtitle)
      final texts = tester.widgetList<Text>(find.byType(Text));
      expect(texts.length, equals(1));
    });

    testWidgets('hides action when onAction is null', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => EmptyStates.buildEmptyState(
              ctx,
              variant: null,
              title: 'Test',
              actionLabel: 'Should not appear',
              onAction: null,
            ),
          ),
        ),
      );

      expect(find.text('Should not appear'), findsNothing);
    });

    // ───── Variant: noRecipes ─────

    testWidgets('noRecipes uses VegetableIllustration (broccoli)', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => EmptyStates.buildEmptyState(
              ctx,
              variant: EmptyStateVariant.noRecipes,
            ),
          ),
        ),
      );

      // Uses illustration instead of icon
      expect(find.byType(VegetableIllustration), findsOneWidget);
      // l10n sv: 'Inga resultat hittades.'
      expect(find.text('Inga resultat hittades.'), findsOneWidget);
    });

    // ───── Variant: noSearchResults ─────

    testWidgets('noSearchResults uses VegetableIllustration (mushroom)', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => EmptyStates.buildEmptyState(
              ctx,
              variant: EmptyStateVariant.noSearchResults,
            ),
          ),
        ),
      );

      expect(find.byType(VegetableIllustration), findsOneWidget);
      expect(find.text('Inga resultat hittades.'), findsOneWidget);
    });

    // ───── Variant: noRecipes with useIllustration=false ─────

    testWidgets('noRecipes falls back to icon when useIllustration=false', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => EmptyStates.buildEmptyState(
              ctx,
              variant: EmptyStateVariant.noRecipes,
              useIllustration: false,
            ),
          ),
        ),
      );

      expect(find.byType(VegetableIllustration), findsNothing);
      expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
    });
  });
}
