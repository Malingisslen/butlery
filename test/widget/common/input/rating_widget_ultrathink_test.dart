// test/widget/common/input/rating_widget_ultrathink_test.dart
// ULTRATHINK TEST SUITE: RatingWidget (input) - 132 lines of production code
// Testing StatelessWidget with 3 constructor variants and star rating logic
// 
// ULTRATHINK FOCUS: Constructor behavior, star logic, interactive vs readonly modes, theme integration

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports - NEVER assume, always check production code first
import 'package:butlery/widgets/common/input/rating_widget.dart';
import 'package:butlery/theme/app_colors.dart';

// Test infrastructure imports - using centralized system
import '../../../infrastructure/helpers/base_widget_test.dart';

void main() {
  group('RatingWidget Ultrathink Tests', () {
    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
    });
    
    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    // Helper to create test environment
    Widget createTestWidget({required Widget child}) {
      return BaseWidgetTest.createTestApp(
        locale: const Locale('en', 'US'), // Use English to avoid localization warnings
        child: Scaffold(
          body: Container(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        ),
      );
    }

    group('Main Constructor Tests', () {
      testWidgets('creates widget with required rating parameter only', (WidgetTester tester) async {
        // ULTRATHINK: Test production code main constructor from lines 53-61
        await tester.pumpWidget(
          createTestWidget(
            child: const RatingWidget(
              rating: 3.0,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should create Row with 5 star icons (lines 99-102)
        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(Icon), findsNWidgets(5));
        
        // Verify default values applied (lines 56-60)
        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        expect(icons.first.size, equals(16)); // Default size
      });

      testWidgets('applies all custom parameters correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code parameter forwarding
        const customSize = 32.0;
        const customStarColor = Colors.red;
        const customEmptyColor = Colors.grey;

        await tester.pumpWidget(
          createTestWidget(
            child: const RatingWidget(
              rating: 2.5,
              size: customSize,
              starColor: customStarColor,
              emptyStarColor: customEmptyColor,
              isInteractive: false, // Focus on parameter application, not interaction
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: All parameters should be applied
        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(Icon), findsNWidgets(5));
        expect(find.byType(GestureDetector), findsNothing); // Non-interactive mode
        
        // Verify custom size applied (line 118)
        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        expect(icons.first.size, equals(customSize));
      });

      testWidgets('enforces rating validation with assert', (WidgetTester tester) async {
        // ULTRATHINK: Test production code assert validation from line 61
        expect(
          () => RatingWidget(rating: -1.0),
          throwsA(isA<AssertionError>()),
        );
        
        expect(
          () => RatingWidget(rating: 6.0),
          throwsA(isA<AssertionError>()),
        );
        
        // Valid ratings should not throw
        expect(() => RatingWidget(rating: 0.0), returnsNormally);
        expect(() => RatingWidget(rating: 2.5), returnsNormally);
        expect(() => RatingWidget(rating: 5.0), returnsNormally);
      });

      testWidgets('handles isInteractive false by default', (WidgetTester tester) async {
        // ULTRATHINK: Test production code default isInteractive behavior
        await tester.pumpWidget(
          createTestWidget(
            child: const RatingWidget(
              rating: 4.0,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should not wrap stars with GestureDetector when not interactive
        expect(find.byType(GestureDetector), findsNothing);
        expect(find.byType(Icon), findsNWidgets(5));
      });

      testWidgets('applies default theme colors correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code default colors from lines 57-58
        await tester.pumpWidget(
          createTestWidget(
            child: const RatingWidget(
              rating: 2.5,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should use AppColors.warning for filled stars, AppColors.outline for empty
        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        expect(icons.length, equals(5));
        
        // Stars 1-2 should be full (AppColors.warning), star 3 should be half (AppColors.warning)
        expect(icons[0].color, equals(AppColors.warning)); // Star 1: full
        expect(icons[1].color, equals(AppColors.warning)); // Star 2: full  
        expect(icons[2].color, equals(AppColors.warning)); // Star 3: half
        expect(icons[3].color, equals(AppColors.outline)); // Star 4: empty
        expect(icons[4].color, equals(AppColors.outline)); // Star 5: empty
      });
    });

    group('Readonly Factory Constructor Tests', () {
      testWidgets('creates readonly widget with preset values', (WidgetTester tester) async {
        // ULTRATHINK: Test production code .readonly factory from lines 64-77
        await tester.pumpWidget(
          createTestWidget(
            child: RatingWidget.readonly(
              rating: 3.5,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should create non-interactive widget with defaults
        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(Icon), findsNWidgets(5));
        expect(find.byType(GestureDetector), findsNothing); // Not interactive
        
        // Verify default readonly size (line 66)
        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        expect(icons.first.size, equals(16));
      });

      testWidgets('applies custom parameters in readonly mode', (WidgetTester tester) async {
        // ULTRATHINK: Test production code .readonly factory parameter forwarding
        const customSize = 20.0;
        const customStarColor = Colors.blue;
        const customEmptyColor = Colors.green;

        await tester.pumpWidget(
          createTestWidget(
            child: RatingWidget.readonly(
              rating: 1.5,
              size: customSize,
              starColor: customStarColor,
              emptyStarColor: customEmptyColor,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Custom parameters should be applied
        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        expect(icons.first.size, equals(customSize));
        expect(icons[0].color, equals(customStarColor)); // Star 1: full
        expect(icons[1].color, equals(customStarColor)); // Star 2: half
        expect(icons[2].color, equals(customEmptyColor)); // Star 3: empty
      });

      testWidgets('readonly factory enforces non-interactive behavior', (WidgetTester tester) async {
        // ULTRATHINK: Test production code .readonly factory sets isInteractive: false
        await tester.pumpWidget(
          createTestWidget(
            child: RatingWidget.readonly(
              rating: 4.0,
              size: 24,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should never be interactive regardless of other parameters
        expect(find.byType(GestureDetector), findsNothing);
        expect(find.byType(Icon), findsNWidgets(5));
      });
    });

    group('Interactive Factory Constructor Tests', () {
      testWidgets('creates interactive widget with required callback', (WidgetTester tester) async {
        // ULTRATHINK: Test production code .interactive factory from lines 80-95
        bool callbackCalled = false;
        double receivedRating = 0.0;

        await tester.pumpWidget(
          createTestWidget(
            child: RatingWidget.interactive(
              rating: 2.0,
              onRatingChanged: (rating) {
                callbackCalled = true;
                receivedRating = rating;
              },
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should create interactive widget with GestureDetectors
        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(Icon), findsNWidgets(5));
        expect(find.byType(GestureDetector), findsNWidgets(5)); // All stars interactive
        
        // Verify default interactive size (line 83)
        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        expect(icons.first.size, equals(24));
        
        // Test callback execution (line 128)
        await tester.tap(find.byType(GestureDetector).at(2)); // Tap star 3
        expect(callbackCalled, isTrue);
        expect(receivedRating, equals(3.0)); // starNumber.toDouble()
      });

      testWidgets('applies custom parameters in interactive mode', (WidgetTester tester) async {
        // ULTRATHINK: Test production code .interactive factory parameter forwarding
        const customSize = 28.0;
        const customStarColor = Colors.purple;
        const customEmptyColor = Colors.orange;

        await tester.pumpWidget(
          createTestWidget(
            child: RatingWidget.interactive(
              rating: 3.0,
              size: customSize,
              starColor: customStarColor,
              emptyStarColor: customEmptyColor,
              onRatingChanged: (rating) {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Custom parameters should be applied
        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        expect(icons.first.size, equals(customSize));
        expect(icons[0].color, equals(customStarColor)); // Full star
        expect(icons[3].color, equals(customEmptyColor)); // Empty star
      });

      testWidgets('executes callback with correct star values', (WidgetTester tester) async {
        // ULTRATHINK: Test production code callback execution with starNumber.toDouble()
        final receivedRatings = <double>[];

        await tester.pumpWidget(
          createTestWidget(
            child: RatingWidget.interactive(
              rating: 0.0,
              onRatingChanged: (rating) => receivedRatings.add(rating),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Tap each star and verify correct rating values
        for (int i = 0; i < 5; i++) {
          await tester.tap(find.byType(GestureDetector).at(i));
          expect(receivedRatings[i], equals((i + 1).toDouble()));
        }
        
        expect(receivedRatings, equals([1.0, 2.0, 3.0, 4.0, 5.0]));
      });
    });

    group('Star Logic and Display Tests', () {
      testWidgets('displays full stars correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code star logic - full stars when rating >= starNumber
        await tester.pumpWidget(
          createTestWidget(
            child: const RatingWidget(
              rating: 3.0,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Stars 1-3 should be full (Icons.star), 4-5 should be empty (Icons.star_border)
        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        expect(icons[0].icon, equals(Icons.star)); // Star 1
        expect(icons[1].icon, equals(Icons.star)); // Star 2  
        expect(icons[2].icon, equals(Icons.star)); // Star 3
        expect(icons[3].icon, equals(Icons.star_border)); // Star 4
        expect(icons[4].icon, equals(Icons.star_border)); // Star 5
      });

      testWidgets('displays half stars correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code half star logic from lines 107-112
        await tester.pumpWidget(
          createTestWidget(
            child: const RatingWidget(
              rating: 2.5,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Stars 1-2 full, star 3 half, stars 4-5 empty
        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        expect(icons[0].icon, equals(Icons.star)); // Star 1: full
        expect(icons[1].icon, equals(Icons.star)); // Star 2: full
        expect(icons[2].icon, equals(Icons.star_half)); // Star 3: half
        expect(icons[3].icon, equals(Icons.star_border)); // Star 4: empty
        expect(icons[4].icon, equals(Icons.star_border)); // Star 5: empty
      });

      testWidgets('displays all empty stars for rating 0.0', (WidgetTester tester) async {
        // ULTRATHINK: Test production code edge case - all empty stars
        await tester.pumpWidget(
          createTestWidget(
            child: const RatingWidget(
              rating: 0.0,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: All 5 stars should be empty (Icons.star_border)
        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        for (final icon in icons) {
          expect(icon.icon, equals(Icons.star_border));
          expect(icon.color, equals(AppColors.outline));
        }
      });

      testWidgets('displays all full stars for rating 5.0', (WidgetTester tester) async {
        // ULTRATHINK: Test production code edge case - all full stars
        await tester.pumpWidget(
          createTestWidget(
            child: const RatingWidget(
              rating: 5.0,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: All 5 stars should be full (Icons.star)
        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        for (final icon in icons) {
          expect(icon.icon, equals(Icons.star));
          expect(icon.color, equals(AppColors.warning));
        }
      });

      testWidgets('handles complex rating values correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code with various rating values
        await tester.pumpWidget(
          createTestWidget(
            child: const RatingWidget(
              rating: 4.3,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Rating 4.3 should show 4 full stars, 1 empty star
        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        expect(icons[0].icon, equals(Icons.star)); // Star 1: full (4.3 >= 1)
        expect(icons[1].icon, equals(Icons.star)); // Star 2: full (4.3 >= 2)
        expect(icons[2].icon, equals(Icons.star)); // Star 3: full (4.3 >= 3)  
        expect(icons[3].icon, equals(Icons.star)); // Star 4: full (4.3 >= 4)
        expect(icons[4].icon, equals(Icons.star_border)); // Star 5: empty (4.3 < 5)
      });

      testWidgets('handles half star edge cases correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code half star boundary conditions
        await tester.pumpWidget(
          createTestWidget(
            child: const RatingWidget(
              rating: 0.5,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Rating 0.5 should show 1 half star, 4 empty stars
        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        expect(icons[0].icon, equals(Icons.star_half)); // Star 1: half (0.5 >= 0.5 && 0.5 < 1)
        expect(icons[1].icon, equals(Icons.star_border)); // Star 2: empty
        expect(icons[2].icon, equals(Icons.star_border)); // Star 3: empty
        expect(icons[3].icon, equals(Icons.star_border)); // Star 4: empty
        expect(icons[4].icon, equals(Icons.star_border)); // Star 5: empty
      });
    });

    group('Interactive Behavior Tests', () {
      testWidgets('wraps stars with GestureDetector when interactive', (WidgetTester tester) async {
        // ULTRATHINK: Test production code interactive mode from lines 122-130
        await tester.pumpWidget(
          createTestWidget(
            child: RatingWidget(
              rating: 1.0,
              isInteractive: true,
              onRatingChanged: (rating) {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should wrap each star with GestureDetector
        expect(find.byType(GestureDetector), findsNWidgets(5));
        expect(find.byType(Icon), findsNWidgets(5));
        
        // Each GestureDetector should contain an Icon
        final gestures = tester.widgetList<GestureDetector>(find.byType(GestureDetector)).toList();
        for (final gesture in gestures) {
          expect(gesture.child, isA<Icon>());
        }
      });

      testWidgets('does not wrap stars when not interactive', (WidgetTester tester) async {
        // ULTRATHINK: Test production code non-interactive mode from line 123
        await tester.pumpWidget(
          createTestWidget(
            child: const RatingWidget(
              rating: 3.0,
              isInteractive: false,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should not create GestureDetectors
        expect(find.byType(GestureDetector), findsNothing);
        expect(find.byType(Icon), findsNWidgets(5));
      });

      testWidgets('handles null onRatingChanged callback gracefully', (WidgetTester tester) async {
        // ULTRATHINK: Test production code null callback handling from line 122
        await tester.pumpWidget(
          createTestWidget(
            child: const RatingWidget(
              rating: 2.0,
              isInteractive: true,
              onRatingChanged: null,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should not wrap with GestureDetector when callback is null
        expect(find.byType(GestureDetector), findsNothing);
        expect(find.byType(Icon), findsNWidgets(5));
      });

      testWidgets('executes callback on star tap with correct rating', (WidgetTester tester) async {
        // ULTRATHINK: Test production code tap handling from line 128
        double? tappedRating;

        await tester.pumpWidget(
          createTestWidget(
            child: RatingWidget.interactive(
              rating: 1.0,
              onRatingChanged: (rating) => tappedRating = rating,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Tap star 4 should return rating 4.0
        await tester.tap(find.byType(GestureDetector).at(3)); // Index 3 = Star 4
        expect(tappedRating, equals(4.0));
        
        // ULTRATHINK: Tap star 1 should return rating 1.0
        await tester.tap(find.byType(GestureDetector).at(0)); // Index 0 = Star 1  
        expect(tappedRating, equals(1.0));
      });
    });

    group('Theme Integration and Styling Tests', () {
      testWidgets('applies default AppColors correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code default theme colors
        await tester.pumpWidget(
          createTestWidget(
            child: const RatingWidget(
              rating: 1.5,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should use AppColors.warning for filled/half, AppColors.outline for empty
        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        expect(icons[0].color, equals(AppColors.warning)); // Star 1: full
        expect(icons[1].color, equals(AppColors.warning)); // Star 2: half
        expect(icons[2].color, equals(AppColors.outline)); // Star 3: empty
        expect(icons[3].color, equals(AppColors.outline)); // Star 4: empty
        expect(icons[4].color, equals(AppColors.outline)); // Star 5: empty
      });

      testWidgets('applies custom colors correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code custom color application
        const customStarColor = Colors.red;
        const customEmptyColor = Colors.blue;

        await tester.pumpWidget(
          createTestWidget(
            child: const RatingWidget(
              rating: 2.5,
              starColor: customStarColor,
              emptyStarColor: customEmptyColor,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Custom colors should be applied based on star state
        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        expect(icons[0].color, equals(customStarColor)); // Star 1: full
        expect(icons[1].color, equals(customStarColor)); // Star 2: full
        expect(icons[2].color, equals(customStarColor)); // Star 3: half
        expect(icons[3].color, equals(customEmptyColor)); // Star 4: empty
        expect(icons[4].color, equals(customEmptyColor)); // Star 5: empty
      });

      testWidgets('applies custom size correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code size application from line 118
        const customSize = 40.0;

        await tester.pumpWidget(
          createTestWidget(
            child: const RatingWidget(
              rating: 3.0,
              size: customSize,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: All stars should use custom size
        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        for (final icon in icons) {
          expect(icon.size, equals(customSize));
        }
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('handles edge rating values correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code with boundary values
        for (final rating in [0.1, 0.4, 0.6, 0.9, 4.4, 4.6, 4.9]) {
          await tester.pumpWidget(
            createTestWidget(
              child: RatingWidget(
                rating: rating,
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.byType(Icon), findsNWidgets(5));
        }
      });

      testWidgets('handles very small and large sizes', (WidgetTester tester) async {
        // ULTRATHINK: Test production code with extreme size values
        await tester.pumpWidget(
          createTestWidget(
            child: const RatingWidget(
              rating: 3.0,
              size: 1.0, // Very small
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(Icon), findsNWidgets(5));
        
        await tester.pumpWidget(
          createTestWidget(
            child: const RatingWidget(
              rating: 3.0,
              size: 100.0, // Very large
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(Icon), findsNWidgets(5));
      });

      testWidgets('handles multiple callback executions correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code callback with multiple taps
        final receivedRatings = <double>[];

        await tester.pumpWidget(
          createTestWidget(
            child: RatingWidget.interactive(
              rating: 2.0,
              onRatingChanged: (rating) => receivedRatings.add(rating),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should handle multiple callback executions
        await tester.tap(find.byType(GestureDetector).at(0)); // Star 1
        await tester.tap(find.byType(GestureDetector).at(2)); // Star 3
        await tester.tap(find.byType(GestureDetector).at(4)); // Star 5
        
        expect(receivedRatings, equals([1.0, 3.0, 5.0]));
      });
    });

    group('Widget Structure and Consistency Tests', () {
      testWidgets('maintains correct widget hierarchy', (WidgetTester tester) async {
        // ULTRATHINK: Test production code widget structure from lines 99-102
        await tester.pumpWidget(
          createTestWidget(
            child: const RatingWidget(
              rating: 2.5,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should have Row > 5 Icons hierarchy
        expect(find.byType(RatingWidget), findsOneWidget);
        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(Icon), findsNWidgets(5));
        
        // Verify Row properties (line 100)
        final row = tester.widget<Row>(find.byType(Row));
        expect(row.mainAxisSize, equals(MainAxisSize.min));
        expect(row.children.length, equals(5));
      });

      testWidgets('all factory constructors create consistent widgets', (WidgetTester tester) async {
        // ULTRATHINK: Test production code factory constructor consistency
        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                const RatingWidget(rating: 3.0),
                RatingWidget.readonly(rating: 3.0),
                RatingWidget.interactive(
                  rating: 3.0,
                  onRatingChanged: (rating) {},
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: All constructors should create RatingWidget instances
        expect(find.byType(RatingWidget), findsNWidgets(3));
        expect(find.byType(Row), findsNWidgets(3));
        expect(find.byType(Icon), findsNWidgets(15)); // 5 stars × 3 widgets
      });

      testWidgets('constructor parameters maintain independence', (WidgetTester tester) async {
        // ULTRATHINK: Test production code constructor parameter isolation
        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                const RatingWidget(
                  rating: 1.0,
                  size: 16,
                  starColor: Colors.red,
                ),
                RatingWidget.readonly(
                  rating: 5.0,
                  size: 24,
                  starColor: Colors.blue,
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Different widgets should maintain independent styling
        expect(find.byType(RatingWidget), findsNWidgets(2));
        
        // Verify different sizes applied independently
        final allIcons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        final firstWidgetIcons = allIcons.take(5).toList();
        final secondWidgetIcons = allIcons.skip(5).take(5).toList();
        
        expect(firstWidgetIcons.first.size, equals(16));
        expect(secondWidgetIcons.first.size, equals(24));
        
        // Verify different colors applied independently  
        expect(firstWidgetIcons.first.color, equals(Colors.red));
        expect(secondWidgetIcons.first.color, equals(Colors.blue));
      });
    });
  });
}