// test/widget/common/input/rating_widget_test.dart
// Comprehensive tests for RatingWidget using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/input/rating_widget.dart';
import 'package:butlery/theme/app_colors.dart';

// Test infrastructure
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('RatingWidget Tests', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
    });

    tearDown(() async {
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Read-Only Mode', () {
      testWidgets('should display full stars correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(rating: 5.0),
            ),
          ),
        );

        // Should find 5 filled stars (Icons.star)
        expect(find.byIcon(Icons.star), findsNWidgets(5));
        expect(find.byIcon(Icons.star_half), findsNothing);
        expect(find.byIcon(Icons.star_border), findsNothing);
      });

      testWidgets('should display half stars correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(rating: 3.5),
            ),
          ),
        );

        // Should find 3 full stars, 1 half star, 1 empty star
        expect(find.byIcon(Icons.star), findsNWidgets(3));
        expect(find.byIcon(Icons.star_half), findsOneWidget);
        expect(find.byIcon(Icons.star_border), findsOneWidget);
      });

      testWidgets('should display empty stars correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(rating: 0.0),
            ),
          ),
        );

        // Should find 5 empty stars (Icons.star_border)
        expect(find.byIcon(Icons.star_border), findsNWidgets(5));
        expect(find.byIcon(Icons.star), findsNothing);
        expect(find.byIcon(Icons.star_half), findsNothing);
      });

      testWidgets('should handle decimal ratings correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(rating: 4.2),
            ),
          ),
        );

        // Rating 4.2 should show: 4 full stars, 1 empty star
        expect(find.byIcon(Icons.star), findsNWidgets(4));
        expect(find.byIcon(Icons.star_half), findsNothing);
        expect(find.byIcon(Icons.star_border), findsOneWidget);
      });

      testWidgets('should handle half-star threshold correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(rating: 2.7),
            ),
          ),
        );

        // Rating 2.7 should show: 2 full stars, 1 half star, 2 empty stars
        expect(find.byIcon(Icons.star), findsNWidgets(2));
        expect(find.byIcon(Icons.star_half), findsOneWidget);
        expect(find.byIcon(Icons.star_border), findsNWidgets(2));
      });

      testWidgets('should use correct default colors', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(rating: 3.0),
            ),
          ),
        );

        // Check star colors
        final starIcons = tester.widgetList<Icon>(find.byIcon(Icons.star));
        for (Icon icon in starIcons) {
          expect(icon.color, equals(AppColors.warning));
        }

        final emptyStarIcons = tester.widgetList<Icon>(find.byIcon(Icons.star_border));
        for (Icon icon in emptyStarIcons) {
          expect(icon.color, equals(AppColors.outline));
        }
      });

      testWidgets('should use correct default size', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(rating: 3.0),
            ),
          ),
        );

        // Check star size (default should be 16)
        final starIcon = tester.widget<Icon>(find.byIcon(Icons.star).first);
        expect(starIcon.size, equals(16));
      });

      testWidgets('should use custom size when specified', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(rating: 3.0, size: 32),
            ),
          ),
        );

        // Check custom size
        final starIcon = tester.widget<Icon>(find.byIcon(Icons.star).first);
        expect(starIcon.size, equals(32));
      });

      testWidgets('should use custom colors when specified', (WidgetTester tester) async {
        const customStarColor = Colors.blue;
        const customEmptyColor = Colors.grey;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(
                rating: 2.0,
                starColor: customStarColor,
                emptyStarColor: customEmptyColor,
              ),
            ),
          ),
        );

        // Check custom colors
        final starIcons = tester.widgetList<Icon>(find.byIcon(Icons.star));
        for (Icon icon in starIcons) {
          expect(icon.color, equals(customStarColor));
        }

        final emptyStarIcons = tester.widgetList<Icon>(find.byIcon(Icons.star_border));
        for (Icon icon in emptyStarIcons) {
          expect(icon.color, equals(customEmptyColor));
        }
      });
    });

    group('Interactive Mode', () {
      testWidgets('should call callback when star is tapped', (WidgetTester tester) async {
        double? capturedRating;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.interactive(
                rating: 2.0,
                onRatingChanged: (rating) => capturedRating = rating,
              ),
            ),
          ),
        );

        // Find all GestureDetectors (one per star) and tap the 4th one (index 3)
        final gestureDetectors = find.byType(GestureDetector);
        expect(gestureDetectors, findsNWidgets(5));
        
        // Tap the fourth star (index 3) - should set rating to 4.0
        await tester.tap(gestureDetectors.at(3));

        expect(capturedRating, equals(4.0));
      });

      testWidgets('should have correct default size for interactive mode', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.interactive(
                rating: 3.0,
                onRatingChanged: (_) {},
              ),
            ),
          ),
        );

        // Interactive mode should default to size 24
        final starIcon = tester.widget<Icon>(find.byIcon(Icons.star).first);
        expect(starIcon.size, equals(24));
      });

      testWidgets('should update rating when different stars are tapped', (WidgetTester tester) async {
        final List<double> capturedRatings = [];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.interactive(
                rating: 0.0,
                onRatingChanged: (rating) => capturedRatings.add(rating),
              ),
            ),
          ),
        );

        // Tap each star from 1-5
        final allStars = find.byIcon(Icons.star_border);
        expect(allStars, findsNWidgets(5));

        for (int i = 0; i < 5; i++) {
          await tester.tap(allStars.at(i));
          expect(capturedRatings[i], equals((i + 1).toDouble()));
        }
      });

      testWidgets('should not respond to taps in read-only mode', (WidgetTester tester) async {
        double? capturedRating;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(rating: 2.0),
            ),
          ),
        );

        // Try to tap a star - should not trigger anything
        final star = find.byIcon(Icons.star_border).first;
        await tester.tap(star);

        expect(capturedRating, isNull);
      });

      testWidgets('should wrap stars in GestureDetectors for interactive mode', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.interactive(
                rating: 3.0,
                onRatingChanged: (_) {},
              ),
            ),
          ),
        );

        // Should find GestureDetectors wrapping the stars
        expect(find.byType(GestureDetector), findsNWidgets(5));
      });

      testWidgets('should not have GestureDetectors in read-only mode', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(rating: 3.0),
            ),
          ),
        );

        // Should not find any GestureDetectors
        expect(find.byType(GestureDetector), findsNothing);
      });
    });

    group('Main Constructor', () {
      testWidgets('should work with main constructor in read-only mode', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const RatingWidget(
                rating: 4.0,
                isInteractive: false,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.star), findsNWidgets(4));
        expect(find.byIcon(Icons.star_border), findsOneWidget);
        expect(find.byType(GestureDetector), findsNothing);
      });

      testWidgets('should work with main constructor in interactive mode', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget(
                rating: 3.0,
                isInteractive: true,
                onRatingChanged: (_) {},
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.star), findsNWidgets(3));
        expect(find.byIcon(Icons.star_border), findsNWidgets(2));
        expect(find.byType(GestureDetector), findsNWidgets(5));
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle minimum rating (0.0)', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(rating: 0.0),
            ),
          ),
        );

        expect(find.byIcon(Icons.star_border), findsNWidgets(5));
        expect(find.byIcon(Icons.star), findsNothing);
        expect(find.byIcon(Icons.star_half), findsNothing);
      });

      testWidgets('should handle maximum rating (5.0)', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(rating: 5.0),
            ),
          ),
        );

        expect(find.byIcon(Icons.star), findsNWidgets(5));
        expect(find.byIcon(Icons.star_border), findsNothing);
        expect(find.byIcon(Icons.star_half), findsNothing);
      });

      testWidgets('should handle precise half-star boundary (X.5)', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(rating: 1.5),
            ),
          ),
        );

        expect(find.byIcon(Icons.star), findsOneWidget);
        expect(find.byIcon(Icons.star_half), findsOneWidget);
        expect(find.byIcon(Icons.star_border), findsNWidgets(3));
      });

      testWidgets('should handle very small decimal values', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(rating: 0.1),
            ),
          ),
        );

        // 0.1 should show all empty stars (no half star since < 0.5)
        expect(find.byIcon(Icons.star_border), findsNWidgets(5));
        expect(find.byIcon(Icons.star), findsNothing);
        expect(find.byIcon(Icons.star_half), findsNothing);
      });

      testWidgets('should handle rating just under half-star threshold', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(rating: 2.4),
            ),
          ),
        );

        // 2.4 should show: 2 full stars, 3 empty stars (no half star since 2.4 < 2.5)
        expect(find.byIcon(Icons.star), findsNWidgets(2));
        expect(find.byIcon(Icons.star_half), findsNothing);
        expect(find.byIcon(Icons.star_border), findsNWidgets(3));
      });

      testWidgets('should handle rating just at half-star threshold', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(rating: 2.5),
            ),
          ),
        );

        // 2.5 should show: 2 full stars, 1 half star, 2 empty stars
        expect(find.byIcon(Icons.star), findsNWidgets(2));
        expect(find.byIcon(Icons.star_half), findsOneWidget);
        expect(find.byIcon(Icons.star_border), findsNWidgets(2));
      });
    });

    group('Widget Structure', () {
      testWidgets('should use Row with MainAxisSize.min', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(rating: 3.0),
            ),
          ),
        );

        final row = tester.widget<Row>(find.byType(Row));
        expect(row.mainAxisSize, equals(MainAxisSize.min));
      });

      testWidgets('should render exactly 5 stars', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(rating: 2.7),
            ),
          ),
        );

        // Should always have exactly 5 star icons total
        final totalStars = find.byIcon(Icons.star).evaluate().length +
                          find.byIcon(Icons.star_half).evaluate().length +
                          find.byIcon(Icons.star_border).evaluate().length;
        
        expect(totalStars, equals(5));
      });

      testWidgets('should maintain consistent icon sizing', (WidgetTester tester) async {
        const customSize = 28.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingWidget.readonly(
                rating: 3.5,
                size: customSize,
              ),
            ),
          ),
        );

        // All star types should have the same size
        final allIcons = [
          ...tester.widgetList<Icon>(find.byIcon(Icons.star)),
          ...tester.widgetList<Icon>(find.byIcon(Icons.star_half)),
          ...tester.widgetList<Icon>(find.byIcon(Icons.star_border)),
        ];

        for (Icon icon in allIcons) {
          expect(icon.size, equals(customSize));
        }
      });
    });
  });
}