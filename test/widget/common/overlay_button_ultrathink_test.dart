// test/widget/common/overlay_button_ultrathink_test.dart
// ULTRATHINK TEST SUITE: OverlayButton (buttons) - 47 lines of production code
// Testing StatelessWidget with 2 constructor variants and theme integration
//
// ULTRATHINK FOCUS: Constructor behavior, DecoratedBox styling, IconButton delegation

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports - NEVER assume, always check production code first
import 'package:butlery/widgets/common/buttons/overlay_button.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

// Test infrastructure imports - using centralized system
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  group('OverlayButton Ultrathink Tests', () {
    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
    });

    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    // Helper to create test environment
    Widget createTestWidget({required Widget child}) {
      return BaseWidgetTest.createTestApp(
        locale: const Locale(
            'en', 'US'), // Use English to avoid localization warnings
        child: Scaffold(
          body: Container(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        ),
      );
    }

    group('Main Constructor Tests', () {
      testWidgets('creates widget with required child parameter only',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code main constructor from lines 17-23
        const testChild = Icon(Icons.edit);

        await tester.pumpWidget(
          createTestWidget(
            child: const OverlayButton(
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should create DecoratedBox with IconButton (lines 35-46)
        expect(find.byType(DecoratedBox), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);
        expect(find.byIcon(Icons.edit), findsOneWidget);

        // Verify default styling applied (lines 37-38)
        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(
            decoration.color,
            equals(
                AppColors.backgroundBeige.withValues(alpha: 0.8))); // Line 37
        expect(
            decoration.borderRadius,
            equals(
                BorderRadius.circular(AppDimensions.borderRadiusM))); // Line 38
      });

      testWidgets('applies custom onPressed callback',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code onPressed parameter forwarding
        const testChild = Icon(Icons.delete);
        bool callbackCalled = false;

        await tester.pumpWidget(
          createTestWidget(
            child: OverlayButton(
              onPressed: () => callbackCalled = true,
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Callback should be forwarded to IconButton (line 41)
        await tester.tap(find.byType(IconButton));
        expect(callbackCalled, isTrue);
      });

      testWidgets('applies custom backgroundColor parameter',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code backgroundColor parameter from line 37
        const testChild = Icon(Icons.photo);
        const customBackgroundColor = Colors.red;

        await tester.pumpWidget(
          createTestWidget(
            child: const OverlayButton(
              backgroundColor: customBackgroundColor,
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Custom backgroundColor should override default
        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.color, equals(customBackgroundColor));
      });

      testWidgets('applies tooltip parameter to IconButton',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code tooltip parameter from line 42
        const testChild = Icon(Icons.info);
        const customTooltip = 'Information button';

        await tester.pumpWidget(
          createTestWidget(
            child: const OverlayButton(
              tooltip: customTooltip,
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Tooltip should be applied to IconButton
        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, equals(customTooltip));
      });

      testWidgets('handles null onPressed gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code null onPressed handling
        const testChild = Icon(Icons.disabled_by_default);

        await tester.pumpWidget(
          createTestWidget(
            child: const OverlayButton(
              onPressed: null,
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: IconButton should handle null onPressed (disabled state)
        expect(find.byType(IconButton), findsOneWidget);
        expect(find.byIcon(Icons.disabled_by_default), findsOneWidget);

        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.onPressed, isNull);
      });

      testWidgets('applies all parameters together',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with all parameters set
        const testChild = Icon(Icons.settings);
        const customBackgroundColor = Colors.blue;
        const customTooltip = 'Settings overlay';
        bool callbackCalled = false;

        await tester.pumpWidget(
          createTestWidget(
            child: OverlayButton(
              backgroundColor: customBackgroundColor,
              tooltip: customTooltip,
              onPressed: () => callbackCalled = true,
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: All parameters should be applied correctly
        expect(find.byType(DecoratedBox), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);

        // Verify styling
        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.color, equals(customBackgroundColor));

        // Verify tooltip
        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, equals(customTooltip));

        // Verify callback
        await tester.tap(find.byType(IconButton));
        expect(callbackCalled, isTrue);
      });
    });

    group('Remove Constructor Tests', () {
      testWidgets('creates remove button with preset styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code .remove constructor from lines 26-31
        bool callbackCalled = false;

        await tester.pumpWidget(
          createTestWidget(
            child: OverlayButton.remove(
              onPressed: () => callbackCalled = true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should create DecoratedBox with preset remove styling
        expect(find.byType(DecoratedBox), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);
        expect(find.byIcon(Icons.clear), findsOneWidget); // Line 30

        // Verify preset child icon styling (line 30)
        final clearIcon = tester.widget<Icon>(find.byIcon(Icons.clear));
        expect(clearIcon.color, equals(AppColors.neutralLight));

        // Verify backgroundColor is null (uses default from line 37)
        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(
            decoration.color,
            equals(AppColors.backgroundBeige
                .withValues(alpha: 0.8))); // Default applied

        // Verify callback works
        await tester.tap(find.byType(IconButton));
        expect(callbackCalled, isTrue);
      });

      testWidgets('applies custom tooltip to remove button',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code .remove constructor tooltip parameter
        const customTooltip = 'Remove this item';

        await tester.pumpWidget(
          createTestWidget(
            child: OverlayButton.remove(
              onPressed: () {},
              tooltip: customTooltip,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Tooltip should be applied to remove button
        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, equals(customTooltip));
        expect(find.byIcon(Icons.clear), findsOneWidget);
      });

      testWidgets('remove button requires onPressed callback',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code .remove constructor required parameter
        bool callbackCalled = false;

        await tester.pumpWidget(
          createTestWidget(
            child: OverlayButton.remove(
              onPressed: () => callbackCalled = true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: onPressed is required for .remove constructor
        expect(find.byType(IconButton), findsOneWidget);

        await tester.tap(find.byType(IconButton));
        expect(callbackCalled, isTrue);
      });
    });

    group('Theme Integration Tests', () {
      testWidgets('applies default AppColors.backgroundBeige with alpha',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code default theme colors from line 37
        const testChild = Icon(Icons.palette);

        await tester.pumpWidget(
          createTestWidget(
            child: const OverlayButton(
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should use default AppColors.backgroundBeige.withValues(alpha: 0.8)
        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.color,
            equals(AppColors.backgroundBeige.withValues(alpha: 0.8)));
      });

      testWidgets('applies AppDimensions.borderRadiusM for border radius',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code border radius from line 38
        const testChild = Icon(Icons.border_style);

        await tester.pumpWidget(
          createTestWidget(
            child: const OverlayButton(
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should use AppDimensions.borderRadiusM
        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadiusM)));
      });

      testWidgets('remove button uses AppColors.neutralLight for icon',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code remove button icon color from line 30
        await tester.pumpWidget(
          createTestWidget(
            child: OverlayButton.remove(
              onPressed: () {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Remove button should use AppColors.neutralLight
        final clearIcon = tester.widget<Icon>(find.byIcon(Icons.clear));
        expect(clearIcon.color, equals(AppColors.neutralLight));
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('handles complex child widgets', (WidgetTester tester) async {
        // ULTRATHINK: Test production code with complex child content
        const complexChild = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: 16),
            Text('5'),
          ],
        );

        await tester.pumpWidget(
          createTestWidget(
            child: const OverlayButton(
              child: complexChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should handle complex child content
        expect(find.byType(DecoratedBox), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);
        expect(find.byIcon(Icons.star), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
      });

      testWidgets('handles custom backgroundColor with full opacity',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with full opacity color
        const testChild = Icon(Icons.opacity);
        const fullOpacityColor = Colors.green;

        await tester.pumpWidget(
          createTestWidget(
            child: const OverlayButton(
              backgroundColor: fullOpacityColor,
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should handle full opacity colors
        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.color, equals(fullOpacityColor));
      });

      testWidgets('handles transparent backgroundColor',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with transparent color
        const testChild = Icon(Icons.visibility_off);
        const transparentColor = Colors.transparent;

        await tester.pumpWidget(
          createTestWidget(
            child: const OverlayButton(
              backgroundColor: transparentColor,
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should handle transparent background
        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.color, equals(transparentColor));
      });

      testWidgets('handles very long tooltip text',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with long tooltip
        const testChild = Icon(Icons.help);
        const longTooltip =
            'This is a very long tooltip that might cause issues in some UI contexts but should be handled gracefully by the overlay button component';

        await tester.pumpWidget(
          createTestWidget(
            child: const OverlayButton(
              tooltip: longTooltip,
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should handle long tooltip text
        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, equals(longTooltip));
      });

      testWidgets('handles empty string tooltip', (WidgetTester tester) async {
        // ULTRATHINK: Test production code with empty tooltip
        const testChild = Icon(Icons.help_outline);
        const emptyTooltip = '';

        await tester.pumpWidget(
          createTestWidget(
            child: const OverlayButton(
              tooltip: emptyTooltip,
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should handle empty tooltip string
        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, equals(emptyTooltip));
      });
    });

    group('Widget Structure Validation', () {
      testWidgets('maintains correct widget hierarchy',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code widget structure from lines 35-46
        const testChild = Icon(Icons.layers);

        await tester.pumpWidget(
          createTestWidget(
            child: const OverlayButton(
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should have DecoratedBox > IconButton > Icon hierarchy
        expect(find.byType(DecoratedBox), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);
        expect(
            find.byType(Icon),
            findsAtLeastNWidgets(
                1)); // Could be multiple icons in test environment

        // Verify IconButton is child of DecoratedBox
        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        expect(decoratedBox.child, isA<IconButton>());

        // Verify Icon is child of IconButton
        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.icon, equals(testChild));
      });

      testWidgets('both constructors create same widget structure',
          (WidgetTester tester) async {
        // ULTRATHINK: Test that both constructors create consistent structure
        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                const OverlayButton(
                  child: Icon(Icons.edit),
                ),
                OverlayButton.remove(
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Both should create same widget structure
        expect(find.byType(DecoratedBox), findsNWidgets(2));
        expect(find.byType(IconButton), findsNWidgets(2));

        // Both should have proper decoration
        final decoratedBoxes =
            tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
        for (final decoratedBox in decoratedBoxes) {
          final decoration = decoratedBox.decoration as BoxDecoration;
          expect(decoration.borderRadius,
              equals(BorderRadius.circular(AppDimensions.borderRadiusM)));
          expect(decoration.color, isNotNull);
        }
      });

      testWidgets('constructor consistency verification',
          (WidgetTester tester) async {
        // ULTRATHINK: Verify constructors maintain OverlayButton type
        const mainButton = OverlayButton(child: Icon(Icons.menu));
        final removeButton = OverlayButton.remove(onPressed: () {});

        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                mainButton,
                removeButton,
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Both should be OverlayButton widgets
        expect(find.byType(OverlayButton), findsNWidgets(2));
        expect(mainButton, isA<OverlayButton>());
        expect(removeButton, isA<OverlayButton>());
      });
    });
  });
}
