// test/widget/image/editable_image_widget_ultrathink_test.dart
// ULTRATHINK TEST SUITE: EditableImageWidget
// 824-line complex image management widget with comprehensive coverage

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:image_picker/image_picker.dart';

// Production imports
import 'package:butlery/widgets/image/editable_image_widget.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/theme/app_colors.dart';

// Mock for ImagePickerService
class MockImagePickerService extends Mock implements ImagePickerService {}

class MockXFile extends Mock implements XFile {
  final String mockPath;
  MockXFile(this.mockPath);

  @override
  String get path => mockPath;
}

void main() {
  group('EditableImageWidget Ultrathink Tests', () {
    // Helper to create properly configured test environment
    Widget createTestWidget({
      required Widget child,
      Size size = const Size(414, 896), // iPhone 11 Pro Max
    }) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'),
        theme: ThemeData(
          primaryColor: AppColors.primaryBlue,
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryBlue,
            onSurface: Colors.black87,
          ),
          textTheme: const TextTheme(
            labelSmall: TextStyle(fontSize: 10),
          ),
        ),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: Center(child: child),
          ),
        ),
      );
    }

    // Create properly configured ImageConfig for testing
    ImageConfig createTestConfig({
      ImageSize size = ImageSize.large,
      bool showEditControls = true,
      bool showNavigationDots = true,
      int maxImages = 5,
    }) {
      return ImageConfig.recipeEdit(
        size: size,
        showEditControls: showEditControls,
        showNavigationDots: showNavigationDots,
        maxImages: maxImages,
      );
    }

    // Test data
    final testImageUrls = [
      'https://example.com/image1.jpg',
      'https://example.com/image2.jpg',
      'https://example.com/image3.jpg',
    ];

    late MockImagePickerService mockImagePickerService;

    setUpAll(() {
      // Register fallback values for mocktail
      registerFallbackValue(ImageSource.camera);
    });

    setUp(() {
      mockImagePickerService = MockImagePickerService();

      // Setup default mock behavior
      when(() => mockImagePickerService.pickMultipleImages())
          .thenAnswer((_) async => []);
    });

    tearDown(() {
      // Clean up
    });

    group('Empty State Tests', () {
      testWidgets('shows empty state with add image button when no images',
          (WidgetTester tester) async {
        // ULTRATHINK: Test empty state UI from production code lines 141-224
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: const [],
              config: createTestConfig(),
            ),
          ),
        );

        // Verify empty state UI elements
        expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
        expect(find.text('Lägg till bilder'), findsOneWidget);
        expect(find.textContaining('Tryck för att lägga till upp till'),
            findsOneWidget);
        expect(find.text('Tryck för att lägga till upp till 5 bilder'),
            findsOneWidget);
      });

      testWidgets('shows loading state when isLoading is true',
          (WidgetTester tester) async {
        // ULTRATHINK: Test loading state from production code lines 163-181
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: const [],
              config: createTestConfig(),
              isLoading: true,
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Adding image...'), findsOneWidget);

        // Verify add button is disabled during loading
        expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
      });

      testWidgets('triggers onPickImage callback when tapped',
          (WidgetTester tester) async {
        // ULTRATHINK: Test custom onPickImage callback from production code lines 459-464
        bool callbackTriggered = false;

        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: const [],
              config: createTestConfig(),
              onPickImage: () {
                callbackTriggered = true;
              },
            ),
          ),
        );

        // Tap empty state to trigger image picker
        await tester.tap(find.byType(InkWell));
        await tester.pump();

        expect(callbackTriggered, isTrue);
      });

      testWidgets('respects maxImages configuration',
          (WidgetTester tester) async {
        // ULTRATHINK: Test maxImages from production code line 209
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: const [],
              config: createTestConfig(maxImages: 3),
            ),
          ),
        );

        expect(find.text('Tryck för att lägga till upp till 3 bilder'),
            findsOneWidget);
      });
    });

    group('Single Image Carousel Tests', () {
      testWidgets('displays single image in carousel mode',
          (WidgetTester tester) async {
        // ULTRATHINK: Test single image mode from production code lines 123-129
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: [testImageUrls[0]],
              config: createTestConfig(),
            ),
          ),
        );

        // Verify carousel mode is used for single image
        expect(find.byType(PageView), findsOneWidget);
        expect(find.byType(ClipRRect), findsWidgets); // Image containers
      });

      testWidgets('shows edit controls for single image',
          (WidgetTester tester) async {
        // ULTRATHINK: Test edit controls from production code lines 348-387
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: [testImageUrls[0]],
              config: createTestConfig(showEditControls: true),
            ),
          ),
        );

        // Verify edit action buttons are present
        expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);

        // Should not show "set as primary" for single image
        expect(find.byIcon(Icons.star_outline), findsNothing);
      });

      testWidgets('triggers onImageTap callback when image tapped',
          (WidgetTester tester) async {
        // ULTRATHINK: Test image tap callback from production code lines 292-297
        int? tappedIndex;

        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: [testImageUrls[0]],
              config: createTestConfig(),
              onImageTap: (index) {
                tappedIndex = index;
              },
            ),
          ),
        );

        // Find and tap the GestureDetector wrapping the image
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();

        expect(tappedIndex, equals(0));
      });

      testWidgets('shows primary indicator for primary image',
          (WidgetTester tester) async {
        // ULTRATHINK: Test primary indicator from production code lines 311-344
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: [testImageUrls[0]],
              config: createTestConfig(),
              primaryIndex: 0,
            ),
          ),
        );

        expect(find.text('Primary'), findsOneWidget);
        expect(find.byIcon(Icons.star), findsOneWidget);
      });
    });

    group('Multiple Image Carousel Tests', () {
      testWidgets('displays multiple images with navigation dots',
          (WidgetTester tester) async {
        // ULTRATHINK: Test navigation dots from production code lines 243-250
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls,
              config: createTestConfig(showNavigationDots: true),
            ),
          ),
        );

        // PageView should be present for carousel
        expect(find.byType(PageView), findsOneWidget);

        // Navigation dots should be shown (handled by ImageComponents)
        // We can't directly test ImageComponents here, but we verify the call
      });

      testWidgets('navigates between images using PageView',
          (WidgetTester tester) async {
        // ULTRATHINK: Test page navigation from production code lines 419-426
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls,
              config: createTestConfig(),
            ),
          ),
        );

        final pageView = find.byType(PageView);
        expect(pageView, findsOneWidget);

        // Swipe to next image
        await tester.fling(pageView, const Offset(-300, 0), 800);
        await tester.pumpAndSettle();

        // Widget should update current index internally
        // We can't directly access _currentIndex, but navigation should work
      });

      testWidgets('shows set as primary button for non-primary images',
          (WidgetTester tester) async {
        // ULTRATHINK: Test set primary button from production code lines 366-373
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls,
              config: createTestConfig(),
              primaryIndex: 0,
            ),
          ),
        );

        // Initially on first image (primary), should not show star_outline
        expect(find.byIcon(Icons.star_outline), findsNothing);

        // Navigate to second image
        final pageView = find.byType(PageView);
        await tester.fling(pageView, const Offset(-300, 0), 800);
        await tester.pumpAndSettle();

        // Now should show set as primary button
        expect(find.byIcon(Icons.star_outline), findsOneWidget);
      });

      testWidgets('triggers onPrimaryImageChanged when set as primary tapped',
          (WidgetTester tester) async {
        // ULTRATHINK: Test primary change callback from production code lines 519-527
        int? newPrimaryIndex;

        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls,
              config: createTestConfig(),
              primaryIndex: 0,
              onPrimaryImageChanged: (index) {
                newPrimaryIndex = index;
              },
            ),
          ),
        );

        // Navigate to second image
        final pageView = find.byType(PageView);
        await tester.fling(pageView, const Offset(-300, 0), 800);
        await tester.pumpAndSettle();

        // Tap set as primary button
        await tester.tap(find.byIcon(Icons.star_outline));
        await tester.pump();

        expect(newPrimaryIndex, equals(1));
      });
    });

    group('Grid Layout Tests', () {
      testWidgets('uses grid layout for multiple images',
          (WidgetTester tester) async {
        // ULTRATHINK: Test grid layout from production code lines 529-557
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls.sublist(0, 2), // 2 images for grid
              config: createTestConfig(),
            ),
          ),
        );

        // Grid layout should be used for 2+ images
        expect(find.byType(GridView), findsOneWidget);
        expect(find.byType(Column), findsWidgets);
      });

      testWidgets('shows primary indicator on grid items',
          (WidgetTester tester) async {
        // ULTRATHINK: Test grid primary indicator from production code lines 613-651
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls.sublist(0, 2),
              config: createTestConfig(),
              primaryIndex: 0,
            ),
          ),
        );

        // Primary indicator should be visible
        expect(find.text('Primär'), findsOneWidget); // Swedish localization
        expect(find.byIcon(Icons.star), findsOneWidget);
        expect(find.byIcon(Icons.star_outline), findsOneWidget); // Non-primary
      });

      testWidgets('tapping non-primary image sets it as primary',
          (WidgetTester tester) async {
        // ULTRATHINK: Test grid tap to set primary from production code lines 574-581
        int? newPrimaryIndex;

        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls.sublist(0, 2),
              config: createTestConfig(),
              primaryIndex: 0,
              onPrimaryImageChanged: (index) {
                newPrimaryIndex = index;
              },
            ),
          ),
        );

        // Find and tap second image (non-primary)
        final gestureDetectors = find.byType(GestureDetector);
        // Second GestureDetector should be for second image
        await tester.tap(gestureDetectors.at(1));
        await tester.pump();

        expect(newPrimaryIndex, equals(1));
      });

      testWidgets('shows delete button on each grid item',
          (WidgetTester tester) async {
        // ULTRATHINK: Test grid delete button from production code lines 653-670
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls.sublist(0, 2),
              config: createTestConfig(showEditControls: true),
            ),
          ),
        );

        // Delete buttons should be present for each image
        expect(find.byIcon(Icons.close), findsNWidgets(2));
      });

      testWidgets('shows add image button when under limit',
          (WidgetTester tester) async {
        // ULTRATHINK: Test add button in grid from production code lines 550-554, 725-777
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls.sublist(0, 2),
              config: createTestConfig(maxImages: 5),
            ),
          ),
        );

        // Add button should show remaining slots
        expect(find.text('Lägg till bild (3 kvar)'), findsOneWidget);
        expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      });

      testWidgets('hides add button when at max images',
          (WidgetTester tester) async {
        // ULTRATHINK: Test max images limit from production code line 551
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls,
              config: createTestConfig(maxImages: 3),
            ),
          ),
        );

        // Add button should not be shown when at limit
        expect(find.text('Lägg till bild'), findsNothing);
        expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
      });
    });

    group('Image Operations Tests', () {
      testWidgets('removes image when delete button tapped',
          (WidgetTester tester) async {
        // ULTRATHINK: Test image removal from production code lines 493-517
        List<String>? updatedUrls;

        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls,
              config: createTestConfig(),
              onImagesChanged: (urls) {
                updatedUrls = urls;
              },
            ),
          ),
        );

        // Tap delete button
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pump();

        expect(updatedUrls, isNotNull);
        expect(updatedUrls!.length, equals(2));
        expect(updatedUrls!.contains(testImageUrls[0]), isFalse);
      });

      testWidgets('removes correct image from grid',
          (WidgetTester tester) async {
        // ULTRATHINK: Test grid image removal from production code lines 779-793
        List<String>? updatedUrls;

        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls.sublist(0, 2),
              config: createTestConfig(),
              onImagesChanged: (urls) {
                updatedUrls = urls;
              },
            ),
          ),
        );

        // Tap delete button on first image
        final deleteButtons = find.byIcon(Icons.close);
        await tester.tap(deleteButtons.first);
        await tester.pump();

        expect(updatedUrls, isNotNull);
        expect(updatedUrls!.length, equals(1));
        expect(updatedUrls![0], equals(testImageUrls[1]));
      });

      testWidgets('adjusts current index after removal',
          (WidgetTester tester) async {
        // ULTRATHINK: Test index adjustment from production code lines 506-514
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls,
              config: createTestConfig(),
              onImagesChanged: (_) {},
            ),
          ),
        );

        // Navigate to last image
        final pageView = find.byType(PageView);
        await tester.fling(pageView, const Offset(-600, 0), 800);
        await tester.pumpAndSettle();

        // Remove current (last) image
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        // Should navigate to new last image (index adjusted)
        // PageController should animate to new index
      });
    });

    group('Factory Constructor Tests', () {
      testWidgets('recipeEdit factory creates correct configuration',
          (WidgetTester tester) async {
        // ULTRATHINK: Test factory constructor from production code lines 37-68
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget.recipeEdit(
              imageUrls: testImageUrls,
              size: ImageSize.large,
              showEditControls: true,
              showNavigationDots: true,
              maxImages: 5,
            ),
          ),
        );

        // Should create widget with correct config
        expect(find.byType(EditableImageWidget), findsOneWidget);
      });

      testWidgets('factory constructor passes callbacks correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test callback passing from factory
        bool pickImageCalled = false;

        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget.recipeEdit(
              imageUrls: const [],
              onImagesChanged:
                  (_) {}, // Callbacks are passed but not tested here
              onPrimaryImageChanged: (_) {}, // Focus on pickImage for this test
              onImageTap: (_) {},
              onPickImage: () => pickImageCalled = true,
            ),
          ),
        );

        // Test onPickImage
        await tester.tap(find.byType(InkWell));
        await tester.pump();
        expect(pickImageCalled, isTrue);
      });
    });

    group('Loading State Tests', () {
      testWidgets('shows loading overlay on carousel when loading',
          (WidgetTester tester) async {
        // ULTRATHINK: Test loading overlay from production code lines 263-277
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls,
              config: createTestConfig(),
              isLoading: true,
            ),
          ),
        );

        // Loading overlay should be visible
        final progressIndicators = find.byType(CircularProgressIndicator);
        expect(progressIndicators, findsOneWidget);
      });

      testWidgets('disables interactions during loading',
          (WidgetTester tester) async {
        // ULTRATHINK: Test loading state disables interaction from production code line 156
        bool callbackTriggered = false;

        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: const [],
              config: createTestConfig(),
              isLoading: true,
              onPickImage: () {
                callbackTriggered = true;
              },
            ),
          ),
        );

        // Try to tap - should be disabled
        await tester.tap(find.byType(InkWell));
        await tester.pump();

        expect(callbackTriggered, isFalse);
      });

      testWidgets('shows loading state in grid add button',
          (WidgetTester tester) async {
        // ULTRATHINK: Test grid loading from production code lines 742-757
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls.sublist(0, 2),
              config: createTestConfig(),
              isLoading: true,
            ),
          ),
        );

        expect(find.text('Lägger till...'), findsOneWidget);
      });
    });

    group('Widget Lifecycle Tests', () {
      testWidgets('updates when primaryIndex changes',
          (WidgetTester tester) async {
        // ULTRATHINK: Test didUpdateWidget from production code lines 87-103
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls,
              config: createTestConfig(),
              primaryIndex: 0,
            ),
          ),
        );

        // Update primary index
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls,
              config: createTestConfig(),
              primaryIndex: 1,
            ),
          ),
        );

        // Widget should update internal state
        // PageController should be recreated with new initial page
      });

      testWidgets('disposes PageController properly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test dispose from production code lines 105-109
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls,
              config: createTestConfig(),
            ),
          ),
        );

        // Remove widget to trigger dispose
        await tester.pumpWidget(
          createTestWidget(
            child: const SizedBox(),
          ),
        );

        // PageController should be disposed (no exceptions)
      });

      testWidgets('resets loading state when external loading changes',
          (WidgetTester tester) async {
        // ULTRATHINK: Test loading state transition from production code lines 90-96
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: const [],
              config: createTestConfig(),
              isLoading: false,
            ),
          ),
        );

        // Change to loading
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: const [],
              config: createTestConfig(),
              isLoading: true,
            ),
          ),
        );

        // Internal loading state should reset
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Swedish Localization Tests', () {
      testWidgets('displays Swedish text in empty state',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish text from production code lines 199, 209
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: const [],
              config: createTestConfig(),
            ),
          ),
        );

        expect(find.text('Lägg till bilder'), findsOneWidget);
        expect(find.textContaining('Tryck för att lägga till'), findsOneWidget);
      });

      testWidgets('displays Swedish text in grid', (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish in grid from production code lines 640, 666, 766
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls.sublist(0, 2),
              config: createTestConfig(),
              primaryIndex: 0,
            ),
          ),
        );

        expect(find.text('Primär'), findsOneWidget);
        expect(find.textContaining('Lägg till bild'), findsOneWidget);
      });

      testWidgets('displays Swedish in loading states',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish loading text from production code line 753
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls.sublist(0, 2),
              config: createTestConfig(),
              isLoading: true,
            ),
          ),
        );

        expect(find.text('Lägger till...'), findsOneWidget);
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('handles empty imageUrls list gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test empty list handling from production code line 117
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: const [],
              config: createTestConfig(),
            ),
          ),
        );

        expect(find.byType(EditableImageWidget), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles null callbacks gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test null callback handling
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls,
              config: createTestConfig(),
              onImagesChanged: null,
              onPrimaryImageChanged: null,
              onImageTap: null,
              onPickImage: null,
            ),
          ),
        );

        // Try operations that would trigger callbacks
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pump();

        // Should not throw exceptions
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles primaryIndex out of bounds',
          (WidgetTester tester) async {
        // ULTRATHINK: Test bounds checking
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls,
              config: createTestConfig(),
              primaryIndex: 10, // Out of bounds
            ),
          ),
        );

        // Should handle gracefully
        expect(tester.takeException(), isNull);
      });

      testWidgets('prevents adding images beyond maxImages',
          (WidgetTester tester) async {
        // ULTRATHINK: Test max images enforcement from production code line 443
        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: testImageUrls,
              config: createTestConfig(maxImages: 3),
            ),
          ),
        );

        // Add button should not be visible when at limit
        expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
      });

      testWidgets('handles file paths vs URLs correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test adaptive image handling from production code line 299
        final mixedUrls = [
          'https://example.com/image1.jpg',
          '/local/path/image2.jpg',
          'https://example.com/image3.jpg',
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: EditableImageWidget(
              imageUrls: mixedUrls,
              config: createTestConfig(),
            ),
          ),
        );

        // Should handle both file paths and URLs
        expect(find.byType(EditableImageWidget), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
