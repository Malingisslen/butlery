// test/widget/styled/styled_container_test.dart
// Comprehensive tests for StyledContainer widget using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/styled/styled_container.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/theme_constants.dart';

void main() {
  group('StyledContainer Widget Tests', () {
    // Helper to wrap widget with MaterialApp for proper theming
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          brightness: Brightness.light,
        ),
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    group('Default Constructor', () {
      testWidgets('should render with child content', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledContainer(
            child: Text('Container Content'),
          ),
        ));

        expect(find.byType(StyledContainer), findsOneWidget);
        expect(find.byType(Container), findsOneWidget);
        expect(find.text('Container Content'), findsOneWidget);
      });

      testWidgets('should apply custom padding', (WidgetTester tester) async {
        const customPadding = EdgeInsets.all(24);
        
        await tester.pumpWidget(createTestWidget(
          const StyledContainer(
            padding: customPadding,
            child: Text('Padded'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(customPadding));
      });

      testWidgets('should apply custom margin', (WidgetTester tester) async {
        const customMargin = EdgeInsets.all(16);
        
        await tester.pumpWidget(createTestWidget(
          const StyledContainer(
            margin: customMargin,
            child: Text('Margin'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.margin, equals(customMargin));
      });

      testWidgets('should apply custom background color', (WidgetTester tester) async {
        const customColor = Colors.blue;
        
        await tester.pumpWidget(createTestWidget(
          const StyledContainer(
            backgroundColor: customColor,
            child: Text('Colored'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(customColor));
      });

      testWidgets('should apply default background color based on theme', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledContainer(
            child: Text('Default'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        // In light theme, should use AppColors.cardWhite
        expect(decoration.color, equals(AppColors.cardWhite));
      });

      testWidgets('should apply border radius', (WidgetTester tester) async {
        const customRadius = 16.0;
        
        await tester.pumpWidget(createTestWidget(
          const StyledContainer(
            borderRadius: customRadius,
            child: Text('Rounded'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, equals(BorderRadius.circular(customRadius)));
      });

      testWidgets('should apply border when borderColor and borderWidth provided', (WidgetTester tester) async {
        const borderColor = Colors.red;
        const borderWidth = 2.0;
        
        await tester.pumpWidget(createTestWidget(
          const StyledContainer(
            borderColor: borderColor,
            borderWidth: borderWidth,
            child: Text('Bordered'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.border, isNotNull);
        final border = decoration.border as Border;
        expect(border.top.color, equals(borderColor));
        expect(border.top.width, equals(borderWidth));
      });

      testWidgets('should not apply border if only borderColor provided', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledContainer(
            borderColor: Colors.red,
            child: Text('No Border'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.border, isNull);
      });

      testWidgets('should apply box shadow', (WidgetTester tester) async {
        const shadows = [
          BoxShadow(
            color: Colors.grey,
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
        ];
        
        await tester.pumpWidget(createTestWidget(
          const StyledContainer(
            boxShadow: shadows,
            child: Text('Shadow'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.boxShadow, equals(shadows));
      });

      testWidgets('should apply custom dimensions', (WidgetTester tester) async {
        const customWidth = 200.0;
        const customHeight = 100.0;
        
        await tester.pumpWidget(createTestWidget(
          const StyledContainer(
            width: customWidth,
            height: customHeight,
            child: Text('Sized'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.maxWidth, equals(customWidth));
        expect(container.constraints?.maxHeight, equals(customHeight));
      });

      testWidgets('should be tappable when onTap provided', (WidgetTester tester) async {
        var tapped = false;
        
        await tester.pumpWidget(createTestWidget(
          StyledContainer(
            onTap: () => tapped = true,
            child: const Text('Tappable'),
          ),
        ));

        expect(find.byType(GestureDetector), findsOneWidget);
        
        await tester.tap(find.byType(GestureDetector));
        expect(tapped, isTrue);
      });

      testWidgets('should not be tappable when onTap is null', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledContainer(
            child: Text('Not Tappable'),
          ),
        ));

        expect(find.byType(GestureDetector), findsNothing);
      });
    });

    group('Card Constructor', () {
      testWidgets('should render with card styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledContainer.card(
            child: Text('Card'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, equals(BorderRadius.circular(AppDimensions.borderRadius8)));
        expect(decoration.boxShadow, equals(ThemeConstants.elevationLow));
        expect(decoration.border, isNull); // No border for card
      });

      testWidgets('should accept custom padding', (WidgetTester tester) async {
        const customPadding = EdgeInsets.all(20);
        
        await tester.pumpWidget(createTestWidget(
          const StyledContainer.card(
            padding: customPadding,
            child: Text('Card'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(customPadding));
      });

      testWidgets('should be tappable when onTap provided', (WidgetTester tester) async {
        var tapped = false;
        
        await tester.pumpWidget(createTestWidget(
          StyledContainer.card(
            onTap: () => tapped = true,
            child: const Text('Tappable Card'),
          ),
        ));

        await tester.tap(find.byType(GestureDetector));
        expect(tapped, isTrue);
      });
    });

    group('Section Constructor', () {
      testWidgets('should render with section padding', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledContainer.section(
            child: Text('Section'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(AppDimensions.sectionPadding));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, equals(BorderRadius.circular(AppDimensions.borderRadius8)));
        expect(decoration.boxShadow, isNull); // No shadow for section
      });
    });

    group('ListItem Constructor', () {
      testWidgets('should render with list item styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledContainer.listItem(
            child: Text('List Item'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(AppDimensions.listItemPadding));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, equals(BorderRadius.circular(AppDimensions.borderRadius4)));
      });

      testWidgets('should be tappable when onTap provided', (WidgetTester tester) async {
        var tapped = false;
        
        await tester.pumpWidget(createTestWidget(
          StyledContainer.listItem(
            onTap: () => tapped = true,
            child: const Text('Tappable Item'),
          ),
        ));

        await tester.tap(find.byType(GestureDetector));
        expect(tapped, isTrue);
      });
    });

    group('Dialog Constructor', () {
      testWidgets('should render with dialog styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledContainer.dialog(
            child: Text('Dialog'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, equals(BorderRadius.circular(AppDimensions.borderRadius12)));
      });

      testWidgets('should not be tappable even if attempting to add onTap', (WidgetTester tester) async {
        // Dialog constructor doesn't accept onTap
        await tester.pumpWidget(createTestWidget(
          const StyledContainer.dialog(
            child: Text('Dialog'),
          ),
        ));

        expect(find.byType(GestureDetector), findsNothing);
      });
    });

    group('InputField Constructor', () {
      testWidgets('should render with input field styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledContainer.inputField(
            child: Text('Input'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, equals(BorderRadius.circular(AppDimensions.borderRadius8)));
        // Border should be null when borderColor not provided
        expect(decoration.border, isNull);
      });

      testWidgets('should show border when borderColor provided', (WidgetTester tester) async {
        const borderColor = Colors.blue;
        
        await tester.pumpWidget(createTestWidget(
          const StyledContainer.inputField(
            borderColor: borderColor,
            child: Text('Input'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.border, isNotNull);
        final border = decoration.border as Border;
        expect(border.top.color, equals(borderColor));
        expect(border.top.width, equals(AppDimensions.borderWidthStandard));
      });

      testWidgets('should not be tappable', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledContainer.inputField(
            child: Text('Input'),
          ),
        ));

        expect(find.byType(GestureDetector), findsNothing);
      });
    });

    group('Dark Theme Support', () {
      testWidgets('should use dark background in dark theme', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: const Scaffold(
            body: StyledContainer(
              child: Text('Dark'),
            ),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.surfaceDark));
      });
    });
  });

  group('StyledContainers Utility Class Tests', () {
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    group('Error Container', () {
      testWidgets('should render with error colors', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledContainers.error(
            child: const Text('Error occurred'),
          ),
        ));

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(StyledContainer),
            matching: find.byType(Container),
          ),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.errorContainer));
      });

      testWidgets('should be tappable when onRetry provided', (WidgetTester tester) async {
        var retryClicked = false;
        
        await tester.pumpWidget(createTestWidget(
          StyledContainers.error(
            child: const Text('Error'),
            onRetry: () => retryClicked = true,
          ),
        ));

        await tester.tap(find.byType(GestureDetector));
        expect(retryClicked, isTrue);
      });

      testWidgets('should have correct padding', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledContainers.error(
            child: const Text('Error'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(const EdgeInsets.all(AppDimensions.spacingMd)));
      });
    });

    group('Success Container', () {
      testWidgets('should render with success colors', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledContainers.success(
            child: const Text('Success!'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.successContainer));
      });

      testWidgets('should not be tappable', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledContainers.success(
            child: const Text('Success'),
          ),
        ));

        expect(find.byType(GestureDetector), findsNothing);
      });
    });

    group('Warning Container', () {
      testWidgets('should render with warning colors', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledContainers.warning(
            child: const Text('Warning!'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.warningContainer));
      });
    });

    group('Info Container', () {
      testWidgets('should render with info colors', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledContainers.info(
            child: const Text('Information'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.infoContainer));
      });

      testWidgets('should have rounded corners', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledContainers.info(
            child: const Text('Info'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, equals(BorderRadius.circular(AppDimensions.borderRadius8)));
      });
    });

    group('Utility Container Common Properties', () {
      testWidgets('all utility containers should have consistent padding', (WidgetTester tester) async {
        // Test all utility containers have same padding
        const expectedPadding = EdgeInsets.all(AppDimensions.spacingMd);
        
        // Error container
        await tester.pumpWidget(createTestWidget(
          StyledContainers.error(child: const Text('E')),
        ));
        var container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(expectedPadding));
        
        // Success container
        await tester.pumpWidget(createTestWidget(
          StyledContainers.success(child: const Text('S')),
        ));
        container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(expectedPadding));
        
        // Warning container
        await tester.pumpWidget(createTestWidget(
          StyledContainers.warning(child: const Text('W')),
        ));
        container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(expectedPadding));
        
        // Info container
        await tester.pumpWidget(createTestWidget(
          StyledContainers.info(child: const Text('I')),
        ));
        container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(expectedPadding));
      });
    });
  });
}