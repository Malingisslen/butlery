// test/widget/image/image_gallery_widget_ultrathink_test.dart
// ULTRATHINK TEST SUITE: ImageGalleryWidget - 490 lines of production code
// Testing complex stateful widget with selection mode, grid layout, haptic feedback, and dual widget classes
//
// ULTRATHINK FOCUS: State management, selection mode transitions, interaction patterns, dual widget testing

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports - NEVER assume, always check production code
import 'package:butlery/widgets/image/image_gallery_widget.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/theme/app_colors.dart';

// Test infrastructure imports
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  group('ImageGalleryWidget Ultrathink Tests', () {
    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
    });

    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    // Helper to create test environment
    Widget createTestWidget({
      required Widget child,
    }) {
      return BaseWidgetTest.createTestApp(
        locale: const Locale(
            'en', 'US'), // Use English to avoid localization warnings
        child: Scaffold(
          body: child,
        ),
      );
    }

    group('Basic Widget Structure Tests', () {
      testWidgets('renders with basic configuration and images',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code basic rendering from lines 80-116
        const testImages = ['image1.jpg', 'image2.jpg', 'image3.jpg'];
        final config = ImageConfig.gallery();

        await tester.pumpWidget(
          createTestWidget(
            child: ImageGalleryWidget(
              imageUrls: testImages,
              config: config,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(ImageGalleryWidget), findsOneWidget);
        expect(find.byType(GridView), findsOneWidget);
      });

      testWidgets('factory constructor creates correct config',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code factory constructor from lines 38-69
        const testImages = ['image1.jpg', 'image2.jpg'];

        await tester.pumpWidget(
          createTestWidget(
            child: ImageGalleryWidget.gallery(
              imageUrls: testImages,
              size: ImageSize.thumbnail,
              showEditControls: false,
              crossAxisCount: 2,
              crossAxisSpacing: 10.0,
              mainAxisSpacing: 12.0,
              childAspectRatio: 1.5,
              onImageTap: (index) {},
              onImageLongPress: (imagePath) {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(ImageGalleryWidget), findsOneWidget);

        // Verify grid configuration is applied correctly
        final gridView = tester.widget<GridView>(find.byType(GridView));
        final delegate =
            gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, equals(2));
        expect(delegate.crossAxisSpacing, equals(10.0));
        expect(delegate.mainAxisSpacing, equals(12.0));
        expect(delegate.childAspectRatio, equals(1.5));
      });

      testWidgets('handles empty image list with empty state',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code empty state from lines 85-87, 119-159
        final config = ImageConfig.gallery();

        await tester.pumpWidget(
          createTestWidget(
            child: ImageGalleryWidget(
              imageUrls: const [], // Empty list
              config: config,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // Should show empty gallery state
        expect(find.text('No images yet'), findsOneWidget);
        expect(find.text('Images will appear here'), findsOneWidget);
        expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
        expect(find.byType(GridView), findsNothing); // No grid when empty
      });

      testWidgets('shows add button when enabled', (WidgetTester tester) async {
        // ULTRATHINK: Test production code add button from lines 106-108, 200-240
        const testImages = ['image1.jpg'];
        final config = ImageConfig.gallery();
        bool addButtonTapped = false;

        await tester.pumpWidget(
          createTestWidget(
            child: ImageGalleryWidget(
              imageUrls: testImages,
              config: config,
              showAddButton: true,
              onAddImage: () => addButtonTapped = true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // Should show add button as last item in grid
        expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
        expect(find.text('Add'), findsOneWidget);

        // Test add button interaction
        await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
        await tester.pump();

        expect(addButtonTapped, isTrue);
      });
    });

    group('Image Interaction Tests', () {
      testWidgets('handles normal image tap correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code normal tap handling from lines 322-332
        const testImages = ['image1.jpg', 'image2.jpg', 'image3.jpg'];
        final config = ImageConfig.gallery();
        int? tappedIndex;

        await tester.pumpWidget(
          createTestWidget(
            child: ImageGalleryWidget(
              imageUrls: testImages,
              config: config,
              onImageTap: (index) => tappedIndex = index,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // Tap on second image (index 1)
        await tester.tap(find.byType(GestureDetector).at(1));
        await tester.pump();

        expect(tappedIndex, equals(1));
      });

      testWidgets('handles image long press to enter selection mode',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code long press selection mode from lines 335-355
        const testImages = ['image1.jpg', 'image2.jpg', 'image3.jpg'];
        final config = ImageConfig.gallery();

        await tester.pumpWidget(
          createTestWidget(
            child: ImageGalleryWidget(
              imageUrls: testImages,
              config: config,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // Initially not in selection mode
        expect(find.text('selected'), findsNothing);
        expect(find.text('Cancel'), findsNothing);

        // Long press on first image to enter selection mode
        await tester.longPress(find.byType(GestureDetector).first);
        await tester.pump();

        // Should enter selection mode with first image selected
        expect(find.text('1 selected'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });

      testWidgets('handles image long press with custom callback',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code custom long press from lines 340-342
        const testImages = ['image1.jpg', 'image2.jpg'];
        final config = ImageConfig.gallery();
        String? longPressedImage;

        await tester.pumpWidget(
          createTestWidget(
            child: ImageGalleryWidget(
              imageUrls: testImages,
              config: config,
              onImageLongPress: (imagePath) => longPressedImage = imagePath,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // Long press should call custom callback instead of entering selection mode
        await tester.longPress(find.byType(GestureDetector).first);
        await tester.pump();

        expect(longPressedImage, equals('image1.jpg'));
        // Should NOT enter selection mode when custom callback is provided
        expect(find.text('selected'), findsNothing);
      });
    });

    group('Selection Mode Tests', () {
      testWidgets('selection mode UI displays correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code selection header from lines 161-198
        const testImages = ['image1.jpg', 'image2.jpg', 'image3.jpg'];
        final config = ImageConfig.gallery();

        await tester.pumpWidget(
          createTestWidget(
            child: ImageGalleryWidget(
              imageUrls: testImages,
              config: config,
            ),
          ),
        );

        // Enter selection mode by long pressing
        await tester.longPress(find.byType(GestureDetector).first);
        await tester.pump();

        // Verify selection header UI
        expect(find.text('1 selected'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);

        // Verify selection indicators appear on images
        expect(find.byIcon(Icons.check), findsOneWidget); // Selected image
        expect(find.byIcon(Icons.circle_outlined),
            findsNWidgets(2)); // Unselected images
      });

      testWidgets('can select and deselect images in selection mode',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code selection toggle from lines 366-379
        // PHASE 1 INVESTIGATION: Debug GestureDetector structure changes
        const testImages = ['image1.jpg', 'image2.jpg', 'image3.jpg'];
        final config = ImageConfig.gallery();

        await tester.pumpWidget(
          createTestWidget(
            child: ImageGalleryWidget(
              imageUrls: testImages,
              config: config,
              // ULTRATHINK: Explicitly set onImageLongPress to null so selection mode works
              onImageLongPress: null,
            ),
          ),
        );

        // ULTRATHINK: Before entering selection mode, verify initial state
        expect(find.text('selected'), findsNothing);
        expect(find.text('Cancel'), findsNothing);
        expect(find.byIcon(Icons.check_circle), findsNothing);

        // PHASE 1 DEBUG: Count GestureDetectors BEFORE selection mode
        final initialGestureDetectors = find.byType(GestureDetector);
        print(
            'ULTRATHINK DEBUG: GestureDetectors BEFORE selection mode: ${initialGestureDetectors.evaluate().length}');
        expect(initialGestureDetectors,
            findsNWidgets(3)); // Should be 3 for 3 images

        // Enter selection mode via long press on first image
        await tester.longPress(initialGestureDetectors.at(0));
        await tester.pump();

        // ULTRATHINK: Verify selection mode is entered correctly
        expect(find.text('1 selected'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);

        // PHASE 1 DEBUG: Count GestureDetectors AFTER selection mode
        final selectionModeGestureDetectors = find.byType(GestureDetector);
        print(
            'ULTRATHINK DEBUG: GestureDetectors AFTER selection mode: ${selectionModeGestureDetectors.evaluate().length}');

        // PHASE 1 DEBUG: Check if Cancel button adds GestureDetector
        final cancelButtons = find.text('Cancel');
        print(
            'ULTRATHINK DEBUG: Cancel buttons found: ${cancelButtons.evaluate().length}');

        // PHASE 3 SOLUTION: TextButton adds GestureDetector at index 0, shifting image indices by +1
        // Before selection: at(0)=img1, at(1)=img2, at(2)=img3
        // After selection:  at(0)=Cancel, at(1)=img1, at(2)=img2, at(3)=img3
        await tester.tap(
            selectionModeGestureDetectors.at(2)); // Now index 2 = second image
        await tester.pump();

        // Should now have 2 selected
        expect(find.text('2 selected'), findsOneWidget);
        expect(find.byIcon(Icons.check), findsNWidgets(2));

        // Deselect first image by tapping it again (now at index 1)
        await tester.tap(
            selectionModeGestureDetectors.at(1)); // Now index 1 = first image
        await tester.pump();

        // Should now have 1 selected again
        expect(find.text('1 selected'), findsOneWidget);
        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets('exits selection mode when cancel is tapped',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code exit selection mode from lines 357-363
        const testImages = ['image1.jpg', 'image2.jpg'];
        final config = ImageConfig.gallery();

        await tester.pumpWidget(
          createTestWidget(
            child: ImageGalleryWidget(
              imageUrls: testImages,
              config: config,
            ),
          ),
        );

        // Enter selection mode
        await tester.longPress(find.byType(GestureDetector).first);
        await tester.pump();

        expect(find.text('1 selected'), findsOneWidget);

        // Tap cancel button
        await tester.tap(find.text('Cancel'));
        await tester.pump();

        // Should exit selection mode
        expect(find.text('selected'), findsNothing);
        expect(find.text('Cancel'), findsNothing);
        expect(find.byIcon(Icons.check), findsNothing);
        expect(find.byIcon(Icons.circle_outlined), findsNothing);
      });

      testWidgets(
          'exits selection mode automatically when all images deselected',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code auto-exit from lines 375-377
        const testImages = ['image1.jpg'];
        final config = ImageConfig.gallery();

        await tester.pumpWidget(
          createTestWidget(
            child: ImageGalleryWidget(
              imageUrls: testImages,
              config: config,
            ),
          ),
        );

        // Enter selection mode with one image
        await tester.longPress(find.byType(GestureDetector).first);
        await tester.pump();

        expect(find.text('1 selected'), findsOneWidget);

        // Deselect the only selected image
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();

        // Should automatically exit selection mode
        expect(find.text('selected'), findsNothing);
        expect(find.text('Cancel'), findsNothing);
      });

      testWidgets('selection mode changes image tap behavior',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code tap behavior change from lines 327-331
        // PHASE 1 INVESTIGATION: Apply same debugging to second failing test
        const testImages = ['image1.jpg', 'image2.jpg'];
        final config = ImageConfig.gallery();
        int? normalTapIndex;

        await tester.pumpWidget(
          createTestWidget(
            child: ImageGalleryWidget(
              imageUrls: testImages,
              config: config,
              onImageTap: (index) => normalTapIndex = index,
              // ULTRATHINK: Explicitly set onImageLongPress to null so selection mode works
              onImageLongPress: null,
            ),
          ),
        );

        // PHASE 1 DEBUG: Count GestureDetectors BEFORE selection mode
        final initialGestureDetectors = find.byType(GestureDetector);
        print(
            'ULTRATHINK DEBUG (Test 2): GestureDetectors BEFORE selection mode: ${initialGestureDetectors.evaluate().length}');
        expect(initialGestureDetectors,
            findsNWidgets(2)); // Should be 2 for 2 images

        // Normal tap should call onImageTap callback
        await tester.tap(initialGestureDetectors.at(0));
        await tester.pump();
        expect(normalTapIndex, equals(0));

        // Enter selection mode via long press
        await tester.longPress(initialGestureDetectors.at(0));
        await tester.pump();

        // Verify selection mode is active
        expect(find.text('1 selected'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        // PHASE 1 DEBUG: Count GestureDetectors AFTER selection mode
        final selectionModeGestureDetectors = find.byType(GestureDetector);
        print(
            'ULTRATHINK DEBUG (Test 2): GestureDetectors AFTER selection mode: ${selectionModeGestureDetectors.evaluate().length}');

        // Reset callback tracking
        normalTapIndex = null;

        // PHASE 3 SOLUTION: TextButton adds GestureDetector at index 0, shifting image indices by +1
        // Before selection: at(0)=img1, at(1)=img2
        // After selection:  at(0)=Cancel, at(1)=img1, at(2)=img2
        // In selection mode, tap should toggle selection, not call onImageTap
        await tester.tap(
            selectionModeGestureDetectors.at(2)); // Now index 2 = second image
        await tester.pump();

        expect(normalTapIndex, isNull); // Callback should not be called
        expect(
            find.text('2 selected'), findsOneWidget); // Selection should change
      });
    });

    group('Visual State Tests', () {
      testWidgets('selected images show visual indicators correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code visual selection from lines 245-316
        const testImages = ['image1.jpg', 'image2.jpg'];
        final config = ImageConfig.gallery();

        await tester.pumpWidget(
          createTestWidget(
            child: ImageGalleryWidget(
              imageUrls: testImages,
              config: config,
            ),
          ),
        );

        // Enter selection mode
        await tester.longPress(find.byType(GestureDetector).first);
        await tester.pump();

        // First image should have selection indicators
        expect(find.byIcon(Icons.check), findsOneWidget);
        expect(find.byIcon(Icons.circle_outlined), findsOneWidget);

        // Verify selection overlay and border colors are applied
        final decoratedBoxes =
            tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
        bool hasSelectedBorder = false;

        for (final decoratedBox in decoratedBoxes) {
          final decoration = decoratedBox.decoration as BoxDecoration;
          if (decoration.border != null) {
            final border = decoration.border as Border;
            if (border.top.color == AppColors.primaryBlue &&
                border.top.width == 2) {
              hasSelectedBorder = true;
              break;
            }
          }
        }

        expect(hasSelectedBorder, isTrue);
      });

      testWidgets('grid layout parameters are applied correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code grid configuration from lines 98-103
        // Fix RenderFlex overflow by using smaller constraint-friendly parameters
        const testImages = ['image1.jpg', 'image2.jpg'];
        final config = ImageConfig.gallery();

        await tester.pumpWidget(
          BaseWidgetTest.createTestApp(
            locale: const Locale('en', 'US'),
            child: SizedBox(
              height: 800, // Provide explicit height to prevent overflow
              width: 400,
              child: ImageGalleryWidget(
                imageUrls: testImages,
                config: config,
                crossAxisCount: 2,
                crossAxisSpacing: 8.0, // Smaller spacing
                mainAxisSpacing: 8.0, // Smaller spacing
                childAspectRatio: 1.0, // Square aspect ratio
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // Verify grid configuration
        final gridView = tester.widget<GridView>(find.byType(GridView));
        final delegate =
            gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

        expect(delegate.crossAxisCount, equals(2));
        expect(delegate.crossAxisSpacing, equals(8.0));
        expect(delegate.mainAxisSpacing, equals(8.0));
        expect(delegate.childAspectRatio, equals(1.0));
      });
    });

    group('Edge Cases and Error Handling Tests', () {
      testWidgets('handles empty images with add button enabled',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code empty state with add button from lines 85-87
        final config = ImageConfig.gallery();

        await tester.pumpWidget(
          createTestWidget(
            child: ImageGalleryWidget(
              imageUrls: const [], // Empty but add button enabled
              config: config,
              showAddButton: true,
              onAddImage: () {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // Should show grid with only add button (not empty state)
        expect(find.byType(GridView), findsOneWidget);
        expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
        expect(find.text('No images yet'),
            findsNothing); // Empty state should not show
      });

      testWidgets('handles null callbacks gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code null callback handling
        const testImages = ['image1.jpg'];
        final config = ImageConfig.gallery();

        await tester.pumpWidget(
          createTestWidget(
            child: ImageGalleryWidget(
              imageUrls: testImages,
              config: config,
              // All callbacks null
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // Should handle tap without error
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();
        expect(tester.takeException(), isNull);

        // Should handle long press without error (enters selection mode)
        await tester.longPress(find.byType(GestureDetector).first);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('1 selected'), findsOneWidget);
      });

      testWidgets('handles haptic feedback configuration correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code haptic feedback from lines 323-325, 336-338
        const testImages = ['image1.jpg'];
        final config = ImageConfig.gallery();

        // Test with haptic feedback enabled
        await tester.pumpWidget(
          createTestWidget(
            child: ImageGalleryWidget(
              imageUrls: testImages,
              config: config,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // Interactions should work without error (can't directly test haptic feedback in tests)
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.longPress(find.byType(GestureDetector).first);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles single image correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code single image edge case
        const testImages = ['single_image.jpg'];
        final config = ImageConfig.gallery();

        await tester.pumpWidget(
          createTestWidget(
            child: ImageGalleryWidget(
              imageUrls: testImages,
              config: config,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(GridView), findsOneWidget);
        expect(find.byType(GestureDetector), findsOneWidget);

        // Should handle selection mode with single image
        await tester.longPress(find.byType(GestureDetector).first);
        await tester.pump();

        expect(find.text('1 selected'), findsOneWidget);

        // Deselecting should exit selection mode automatically
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();

        expect(find.text('selected'), findsNothing);
      });
    });

    group('StaggeredImageGalleryWidget Tests', () {
      testWidgets('renders basic staggered gallery correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code StaggeredImageGalleryWidget from lines 382-490
        const testImages = ['image1.jpg', 'image2.jpg', 'image3.jpg'];
        final config = ImageConfig.gallery();

        await tester.pumpWidget(
          createTestWidget(
            child: StaggeredImageGalleryWidget(
              imageUrls: testImages,
              config: config,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(StaggeredImageGalleryWidget), findsOneWidget);
        expect(find.byType(GridView), findsOneWidget);
      });

      testWidgets('staggered gallery handles empty state',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code staggered empty state from lines 407-438
        final config = ImageConfig.gallery();

        await tester.pumpWidget(
          createTestWidget(
            child: StaggeredImageGalleryWidget(
              imageUrls: const [],
              config: config,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // Should show different empty state message
        expect(find.text('No images to display'), findsOneWidget);
        expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
        expect(find.byType(GridView), findsNothing);
      });

      testWidgets('staggered gallery handles interactions',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code staggered interactions from lines 453-465
        const testImages = ['image1.jpg', 'image2.jpg'];
        final config = ImageConfig.gallery();
        int? tappedIndex;
        String? longPressedImage;

        await tester.pumpWidget(
          createTestWidget(
            child: StaggeredImageGalleryWidget(
              imageUrls: testImages,
              config: config,
              onImageTap: (index) => tappedIndex = index,
              onImageLongPress: (imagePath) => longPressedImage = imagePath,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // Test tap interaction
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();
        expect(tappedIndex, equals(0));

        // Test long press interaction
        await tester.longPress(find.byType(GestureDetector).at(1));
        await tester.pump();
        expect(longPressedImage, equals('image2.jpg'));
      });

      testWidgets('staggered gallery applies custom grid parameters',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code staggered grid configuration from lines 443-448
        const testImages = ['image1.jpg', 'image2.jpg'];
        final config = ImageConfig.gallery();

        await tester.pumpWidget(
          createTestWidget(
            child: StaggeredImageGalleryWidget(
              imageUrls: testImages,
              config: config,
              crossAxisCount: 1,
              crossAxisSpacing: 5.0,
              mainAxisSpacing: 7.0,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        final gridView = tester.widget<GridView>(find.byType(GridView));
        final delegate =
            gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

        expect(delegate.crossAxisCount, equals(1));
        expect(delegate.crossAxisSpacing, equals(5.0));
        expect(delegate.mainAxisSpacing, equals(7.0));
        expect(
            delegate.childAspectRatio, equals(1.0)); // From _getAspectRatio()
      });
    });
  });
}
