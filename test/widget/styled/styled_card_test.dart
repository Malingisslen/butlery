// test/widget/styled/styled_card_test.dart
// Comprehensive tests for StyledCard widget using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/styled/styled_card.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';

void main() {
  group('StyledCard Widget Tests', () {
    // Helper to wrap widget with MaterialApp for proper theming
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          cardTheme: const CardThemeData(
            color: Colors.white,
            elevation: 2,
          ),
          colorScheme: const ColorScheme.light(
            outline: Colors.grey,
          ),
        ),
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    group('Default Constructor', () {
      testWidgets('should render with child content',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledCard(
            child: Text('Card Content'),
          ),
        ));

        expect(find.byType(StyledCard), findsOneWidget);
        expect(find.byType(Card), findsOneWidget);
        expect(find.text('Card Content'), findsOneWidget);
      });

      testWidgets('should apply custom padding', (WidgetTester tester) async {
        const customPadding = EdgeInsets.all(32);

        await tester.pumpWidget(createTestWidget(
          const StyledCard(
            padding: customPadding,
            child: Text('Padded'),
          ),
        ));

        // Find the Padding widget with our specific padding value
        final paddingFinder = find.byWidgetPredicate(
            (widget) => widget is Padding && widget.padding == customPadding);

        expect(paddingFinder, findsOneWidget);
        final padding = tester.widget<Padding>(paddingFinder);
        expect(padding.padding, equals(customPadding));
      });

      testWidgets('should apply custom margin', (WidgetTester tester) async {
        const customMargin = EdgeInsets.all(16);

        await tester.pumpWidget(createTestWidget(
          const StyledCard(
            margin: customMargin,
            child: Text('Margin'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.margin, equals(customMargin));
      });

      testWidgets('should apply custom background color',
          (WidgetTester tester) async {
        const customColor = Colors.blue;

        await tester.pumpWidget(createTestWidget(
          const StyledCard(
            backgroundColor: customColor,
            child: Text('Colored'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.color, equals(customColor));
      });

      testWidgets('should apply custom elevation', (WidgetTester tester) async {
        const customElevation = 8.0;

        await tester.pumpWidget(createTestWidget(
          const StyledCard(
            elevation: customElevation,
            child: Text('Elevated'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.elevation, equals(customElevation));
      });

      testWidgets('should show border when showBorder is true',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledCard(
            showBorder: true,
            child: Text('Bordered'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.side, isNot(equals(BorderSide.none)));
        expect(shape.side.width, equals(AppDimensions.borderWidthStandard));
      });

      testWidgets('should apply custom border color',
          (WidgetTester tester) async {
        const customBorderColor = Colors.red;

        await tester.pumpWidget(createTestWidget(
          const StyledCard(
            showBorder: true,
            borderColor: customBorderColor,
            child: Text('Custom Border'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.side.color, equals(customBorderColor));
      });

      testWidgets('should be tappable when onTap is provided',
          (WidgetTester tester) async {
        bool tapped = false;

        await tester.pumpWidget(createTestWidget(
          StyledCard(
            onTap: () => tapped = true,
            child: const Text('Tappable'),
          ),
        ));

        expect(find.byType(InkWell), findsOneWidget);

        await tester.tap(find.byType(InkWell));
        expect(tapped, isTrue);
      });

      testWidgets('should not be tappable when onTap is null',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledCard(
            child: Text('Not Tappable'),
          ),
        ));

        expect(find.byType(InkWell), findsNothing);
      });
    });

    group('Standard Constructor', () {
      testWidgets('should render with standard elevation',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledCard.standard(
            child: Text('Standard'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.elevation, equals(AppDimensions.elevationLow));
      });

      testWidgets('should have standard border radius',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledCard.standard(
            child: Text('Standard'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius8)));
      });

      testWidgets('should not show border', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledCard.standard(
            child: Text('Standard'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.side, equals(BorderSide.none));
      });
    });

    group('Elevated Constructor', () {
      testWidgets('should render with medium elevation',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledCard.elevated(
            child: Text('Elevated'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.elevation, equals(AppDimensions.elevationMedium));
      });

      testWidgets('should have larger border radius',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledCard.elevated(
            child: Text('Elevated'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius12)));
      });
    });

    group('Outlined Constructor', () {
      testWidgets('should render with zero elevation',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledCard.outlined(
            child: Text('Outlined'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.elevation, equals(0));
      });

      testWidgets('should show border', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledCard.outlined(
            child: Text('Outlined'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.side, isNot(equals(BorderSide.none)));
      });

      testWidgets('should accept custom border color',
          (WidgetTester tester) async {
        const customColor = Colors.purple;

        await tester.pumpWidget(createTestWidget(
          const StyledCard.outlined(
            borderColor: customColor,
            child: Text('Outlined'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.side.color, equals(customColor));
      });
    });

    group('Recipe Constructor', () {
      testWidgets('should render with recipe-specific styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledCard.recipe(
            child: Text('Recipe'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.elevation, equals(AppDimensions.elevationLow));

        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius12)));
      });
    });

    group('ListItem Constructor', () {
      testWidgets('should render with minimal elevation',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledCard.listItem(
            child: Text('List Item'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.elevation, equals(1));
      });

      testWidgets('should be tappable when onTap provided',
          (WidgetTester tester) async {
        bool tapped = false;

        await tester.pumpWidget(createTestWidget(
          StyledCard.listItem(
            onTap: () => tapped = true,
            child: const Text('Tappable Item'),
          ),
        ));

        await tester.tap(find.byType(InkWell));
        expect(tapped, isTrue);
      });
    });

    group('Dialog Constructor', () {
      testWidgets('should render with high elevation',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledCard.dialog(
            child: Text('Dialog'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.elevation, equals(AppDimensions.elevationHigh));
      });

      testWidgets('should have larger border radius',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledCard.dialog(
            child: Text('Dialog'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius16)));
      });

      testWidgets('should not be tappable', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledCard.dialog(
            child: Text('Dialog'),
          ),
        ));

        expect(find.byType(InkWell), findsNothing);
      });
    });

    group('Selection Constructor', () {
      testWidgets('should show elevated and bordered when selected',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledCard.selection(
            isSelected: true,
            child: Text('Selected'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.elevation, equals(AppDimensions.elevationMedium));

        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.side.color, equals(AppColors.forestGreen));
      });

      testWidgets('should show minimal elevation when not selected',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledCard.selection(
            isSelected: false,
            child: Text('Not Selected'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.elevation, equals(1));

        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.side, equals(BorderSide.none));
      });

      testWidgets('should be tappable when onTap provided',
          (WidgetTester tester) async {
        bool tapped = false;

        await tester.pumpWidget(createTestWidget(
          StyledCard.selection(
            isSelected: false,
            onTap: () => tapped = true,
            child: const Text('Tap to Select'),
          ),
        ));

        await tester.tap(find.byType(InkWell));
        expect(tapped, isTrue);
      });
    });
  });

  group('StyledCards Utility Class Tests', () {
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            outline: Colors.grey,
          ),
        ),
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    group('EmptyState Card', () {
      testWidgets('should render with outlined style',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledCards.emptyState(
            child: const Text('No data'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.elevation, equals(0));

        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.side, isNot(equals(BorderSide.none)));
      });

      testWidgets('should be tappable when onAction provided',
          (WidgetTester tester) async {
        bool actionCalled = false;

        await tester.pumpWidget(createTestWidget(
          StyledCards.emptyState(
            child: const Text('No data'),
            onAction: () => actionCalled = true,
          ),
        ));

        await tester.tap(find.byType(InkWell));
        expect(actionCalled, isTrue);
      });
    });

    group('Error Card', () {
      testWidgets('should render with error colors',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledCards.error(
            child: const Text('Error occurred'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.color, equals(AppColors.errorContainer));

        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.side.color, equals(AppColors.error));
      });

      testWidgets('should be tappable when onRetry provided',
          (WidgetTester tester) async {
        bool retryCalled = false;

        await tester.pumpWidget(createTestWidget(
          StyledCards.error(
            child: const Text('Error'),
            onRetry: () => retryCalled = true,
          ),
        ));

        await tester.tap(find.byType(InkWell));
        expect(retryCalled, isTrue);
      });
    });

    group('Info Card', () {
      testWidgets('should render with info colors',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledCards.info(
            child: const Text('Information'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.color, equals(AppColors.infoContainer));

        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.side.color, equals(AppColors.info));
      });
    });

    group('Success Card', () {
      testWidgets('should render with success colors',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledCards.success(
            child: const Text('Success!'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.color, equals(AppColors.successContainer));

        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.side.color, equals(AppColors.success));
      });
    });

    group('Warning Card', () {
      testWidgets('should render with warning colors',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledCards.warning(
            child: const Text('Warning!'),
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.color, equals(AppColors.warningContainer));

        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.side.color, equals(AppColors.warning));
      });
    });

    group('Loading Card', () {
      testWidgets('should render loading placeholder with default height',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledCards.loading(),
        ));

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(Card),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(container.constraints?.maxHeight, equals(100));
      });

      testWidgets('should accept custom dimensions',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledCards.loading(
            height: 200,
            width: 300,
          ),
        ));

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(Card),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(container.constraints?.maxHeight, equals(200));
        expect(container.constraints?.maxWidth, equals(300));
      });

      testWidgets('should show gradient animation',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledCards.loading(),
        ));

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(Card),
                matching: find.byType(Container),
              )
              .first,
        );

        final decoration = container.decoration as BoxDecoration;
        expect(decoration.gradient, isNotNull);
        expect(decoration.gradient, isA<LinearGradient>());
      });
    });

    group('Image Card', () {
      testWidgets('should render with image widget',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledCards.image(
            imageWidget: Container(
              height: 100,
              color: Colors.blue,
            ),
          ),
        ));

        expect(find.byType(ClipRRect), findsOneWidget);
        // Stack may exist both in the card and in parent widgets, so check for at least one
        expect(find.byType(Stack), findsWidgets);
      });

      testWidgets('should render overlay when provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledCards.image(
            imageWidget: Container(
              height: 100,
              color: Colors.blue,
            ),
            overlay: const Text('Overlay'),
          ),
        ));

        expect(find.text('Overlay'), findsOneWidget);

        // Check for dark overlay decoration
        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        expect(decoratedBox.decoration, isA<BoxDecoration>());
      });

      testWidgets('should be tappable when onTap provided',
          (WidgetTester tester) async {
        bool tapped = false;

        await tester.pumpWidget(createTestWidget(
          StyledCards.image(
            imageWidget: Container(
              height: 100,
              color: Colors.blue,
            ),
            onTap: () => tapped = true,
          ),
        ));

        await tester.tap(find.byType(InkWell));
        expect(tapped, isTrue);
      });
    });
  });
}
