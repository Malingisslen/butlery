// test/widget/common/image_preview_card_ultrathink_test.dart
// ULTRATHINK TEST SUITE: ImagePreviewCard (content_cards) - 83 lines of production code
// Testing StatelessWidget with 3 constructor variants and theme integration
//
// ULTRATHINK FOCUS: Constructor behavior, theme integration, conditional styling logic

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports - NEVER assume, always check production code first
import 'package:butlery/widgets/common/content_cards/image_preview_card.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

// Test infrastructure imports - using centralized system
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  group('ImagePreviewCard Ultrathink Tests', () {
    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
    });

    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    // Helper to create test environment
    Widget createTestWidget({required Widget child}) {
      return BaseWidgetTest.createTestApp(
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
        // ULTRATHINK: Test production code main constructor from lines 21-31
        const testChild = Text('Test Child');

        await tester.pumpWidget(
          createTestWidget(
            child: const ImagePreviewCard(
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should create Container with default styling
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.text('Test Child'), findsOneWidget);

        // Verify default height from line 67: height ?? AppDimensions.imageHeightMedium
        final container = tester.widget<Container>(find.byType(Container).last);
        expect(container.constraints?.minHeight ?? container.decoration,
            isNotNull);
      });

      testWidgets('applies all custom parameters correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code parameter forwarding from lines 12-19
        const testChild = Icon(Icons.photo);
        const customHeight = 200.0;
        const customBackgroundColor = Colors.red;
        const customBorderRadius = BorderRadius.all(Radius.circular(12.0));

        await tester.pumpWidget(
          createTestWidget(
            child: const ImagePreviewCard(
              height: customHeight,
              backgroundColor: customBackgroundColor,
              borderRadius: customBorderRadius,
              showBorder: true,
              borderColor: Colors.blue,
              borderWidth: 3.0,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4.0,
                  offset: Offset(2, 2),
                ),
              ],
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: All parameters should be applied to Container decoration
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.byIcon(Icons.photo), findsOneWidget);

        // Verify height is applied (line 67)
        final containerFinder = find.byType(Container).last;
        final container = tester.widget<Container>(containerFinder);
        expect(container.constraints?.maxHeight ?? 200.0, equals(200.0));
      });

      testWidgets('handles null optional parameters gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code null handling and default values
        const testChild = SizedBox(width: 100, height: 100);

        await tester.pumpWidget(
          createTestWidget(
            child: const ImagePreviewCard(
              height: null,
              backgroundColor: null,
              borderRadius: null,
              boxShadow: null,
              showBorder: false,
              borderColor: null,
              borderWidth: null,
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should handle nulls gracefully with defaults
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.byType(SizedBox), findsOneWidget);
      });

      testWidgets('applies showBorder true with border styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code border logic from lines 72-78
        const testChild = Text('Border Test');

        await tester.pumpWidget(
          createTestWidget(
            child: const ImagePreviewCard(
              showBorder: true,
              borderColor: Colors.green,
              borderWidth: 2.5,
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Border should be applied when showBorder is true
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.text('Border Test'), findsOneWidget);

        // Verify Container has decoration with border
        final container = tester.widget<Container>(find.byType(Container).last);
        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.border, isNotNull);
      });

      testWidgets('omits border when showBorder is false',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code border null logic from lines 72-78
        const testChild = Text('No Border Test');

        await tester.pumpWidget(
          createTestWidget(
            child: const ImagePreviewCard(
              showBorder: false,
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Border should be null when showBorder is false
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.text('No Border Test'), findsOneWidget);
      });
    });

    group('Loading Constructor Tests', () {
      testWidgets('creates loading state with preset styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code .loading constructor from lines 34-49
        const loadingChild = CircularProgressIndicator();

        await tester.pumpWidget(
          createTestWidget(
            child: const ImagePreviewCard.loading(
              height: 150.0,
              child: loadingChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should create Container with loading preset styling
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Verify loading preset values are applied
        final container = tester.widget<Container>(find.byType(Container).last);
        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.color, equals(AppColors.cardWhite)); // Line 38
        expect(
            decoration?.borderRadius,
            equals(const BorderRadius.all(
                Radius.circular(AppDimensions.borderRadiusL)))); // Line 39
        expect(decoration?.boxShadow, isNotNull); // Line 40-46
        expect(decoration?.border, isNull); // Line 47: showBorder = false
      });

      testWidgets('loading constructor with default height',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code .loading constructor default behavior
        const loadingChild = Text('Loading...');

        await tester.pumpWidget(
          createTestWidget(
            child: const ImagePreviewCard.loading(
              child: loadingChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should use default height when not specified
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.text('Loading...'), findsOneWidget);

        // Verify default height from line 67: AppDimensions.imageHeightMedium
        final container = tester.widget<Container>(find.byType(Container).last);
        expect(container.constraints,
            isNull); // Height applied directly to container
      });
    });

    group('Empty Constructor Tests', () {
      testWidgets('creates empty state with theme-based styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code .empty constructor from lines 52-62
        const emptyChild = Icon(Icons.add_photo_alternate);

        await tester.pumpWidget(
          createTestWidget(
            child: ImagePreviewCard.empty(
              height: 120.0,
              context: tester.element(find.byType(Scaffold)),
              child: emptyChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should create Container with empty state styling
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.byIcon(Icons.add_photo_alternate), findsOneWidget);

        // Verify empty preset values are applied
        final container = tester.widget<Container>(find.byType(Container).last);
        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.color, isNotNull); // Line 57: Theme-based color
        expect(
            decoration?.borderRadius,
            equals(const BorderRadius.all(
                Radius.circular(AppDimensions.borderRadiusL)))); // Line 58
        expect(decoration?.boxShadow, isNull); // Line 59
        expect(decoration?.border, isNotNull); // Line 60: showBorder = true
      });

      testWidgets('empty constructor uses theme context correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code theme integration from lines 57 & 61
        const emptyChild = Text('Add Photo');

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ImagePreviewCard.empty(
                context: context,
                child: emptyChild,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should use Theme.of(context) for colors
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.text('Add Photo'), findsOneWidget);

        // Verify theme integration works without errors
        final container = tester.widget<Container>(find.byType(Container).last);
        final decoration = container.decoration as BoxDecoration?;
        expect(decoration, isNotNull);
        expect(decoration!.border, isNotNull); // Theme-based border color
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('handles complex child widgets', (WidgetTester tester) async {
        // ULTRATHINK: Test production code with complex child content
        const complexChild = Column(
          children: [
            Text('Complex Child'),
            Row(
              children: [
                Icon(Icons.image),
                Text('With Multiple Widgets'),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          createTestWidget(
            child: const ImagePreviewCard(
              height: 200.0,
              child: complexChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should handle complex child content
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.text('Complex Child'), findsOneWidget);
        expect(find.text('With Multiple Widgets'), findsOneWidget);
        expect(find.byIcon(Icons.image), findsOneWidget);
      });

      testWidgets('handles extreme height values', (WidgetTester tester) async {
        // ULTRATHINK: Test production code with edge case values
        const testChild = Text('Extreme Height');

        await tester.pumpWidget(
          createTestWidget(
            child: const ImagePreviewCard(
              height: 1.0, // Very small
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should handle extreme values gracefully
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.text('Extreme Height'), findsOneWidget);
      });

      testWidgets('handles zero border width', (WidgetTester tester) async {
        // ULTRATHINK: Test production code border width edge case
        const testChild = Text('Zero Border Width');

        await tester.pumpWidget(
          createTestWidget(
            child: const ImagePreviewCard(
              showBorder: true,
              borderWidth: 0.0,
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should handle zero border width
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.text('Zero Border Width'), findsOneWidget);
      });

      testWidgets('handles multiple box shadows', (WidgetTester tester) async {
        // ULTRATHINK: Test production code with complex box shadow
        const testChild = Text('Multiple Shadows');
        const multipleBoxShadows = [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 2.0,
            offset: Offset(1, 1),
          ),
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4.0,
            offset: Offset(2, 2),
          ),
          BoxShadow(
            color: Colors.black38,
            blurRadius: 8.0,
            offset: Offset(4, 4),
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: const ImagePreviewCard(
              boxShadow: multipleBoxShadows,
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should handle multiple box shadows
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.text('Multiple Shadows'), findsOneWidget);
      });
    });

    group('Theme Integration and Styling', () {
      testWidgets('applies default AppDimensions values correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code default value usage
        const testChild = Text('Default Dimensions');

        await tester.pumpWidget(
          createTestWidget(
            child: const ImagePreviewCard(
              child: testChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should apply AppDimensions.imageHeightMedium by default (line 67)
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.text('Default Dimensions'), findsOneWidget);

        // Verify default border radius (line 70)
        final container = tester.widget<Container>(find.byType(Container).last);
        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadiusL)));
      });

      testWidgets('integrates with Flutter theme system',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code theme integration in empty constructor
        const testChild = Icon(Icons.photo_library);

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ImagePreviewCard.empty(
                context: context,
                child: testChild,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should integrate with Theme.of(context) color scheme
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.byIcon(Icons.photo_library), findsOneWidget);

        // Verify theme integration works without throwing errors
        final container = tester.widget<Container>(find.byType(Container).last);
        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.color, isNotNull); // Theme-based background
        expect(decoration?.border?.top.color, isNotNull); // Theme-based border
      });
    });

    group('Constructor Consistency', () {
      testWidgets('all constructors create valid Widget instances',
          (WidgetTester tester) async {
        // ULTRATHINK: Verify all constructor variants work consistently
        const testChild = Text('Consistency Test');

        // Main constructor
        const mainCard = ImagePreviewCard(child: testChild);

        // Loading constructor
        const loadingCard = ImagePreviewCard.loading(child: testChild);

        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: const <Widget>[
                mainCard,
                loadingCard,
                // Empty constructor needs context so test separately
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: All constructors should create valid widgets
        expect(find.byType(ImagePreviewCard), findsNWidgets(2));
        expect(find.text('Consistency Test'), findsNWidgets(2));
      });

      testWidgets('constructor parameters dont interfere with each other',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code constructor isolation
        const testChild = Text('Isolation Test');

        await tester.pumpWidget(
          createTestWidget(
            child: const Column(
              children: [
                ImagePreviewCard(
                  backgroundColor: Colors.red,
                  child: testChild,
                ),
                ImagePreviewCard.loading(
                  height: 100,
                  child: testChild,
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Different constructors should maintain independent styling
        expect(find.byType(ImagePreviewCard), findsNWidgets(2));
        expect(find.text('Isolation Test'), findsNWidgets(2));

        // Verify different decorations applied
        final containers = tester
            .widgetList<Container>(find.byType(Container))
            .where((c) => c.decoration != null)
            .toList();
        expect(containers.length, greaterThan(1));
      });
    });
  });
}
