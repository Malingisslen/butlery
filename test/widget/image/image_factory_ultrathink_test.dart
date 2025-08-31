// test/widget/image/image_factory_ultrathink_test.dart
// ULTRATHINK TEST SUITE: ImageFactory - 393 lines of production code
// Testing pure delegation factory with 15 static methods
// 
// ULTRATHINK FOCUS: Factory method delegation, parameter passing, widget creation patterns

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports - NEVER assume, always check production code first
import 'package:butlery/widgets/image/image_factory.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/image/avatar_image_widget.dart';
import 'package:butlery/widgets/image/recipe_image_widget.dart';
import 'package:butlery/widgets/image/editable_image_widget.dart';
import 'package:butlery/widgets/image/image_gallery_widget.dart';
import 'package:butlery/widgets/image/image_picker_widget.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';

// Test infrastructure imports - using centralized system
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  group('ImageFactory Ultrathink Tests', () {
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
        locale: const Locale('en', 'US'),
        child: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: child,
          ),
        ),
      );
    }

    group('Avatar Factory Method Tests', () {
      testWidgets('avatar factory creates AvatarImageWidget.readonly when onImageSelected is null',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 15-57
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.avatar(
              imageUrl: 'https://example.com/avatar.jpg',
              displayName: 'Test User',
              email: 'test@example.com',
              isOnline: true,
              size: ImageSize.medium, // ULTRATHINK FIX: Avoid infinite dimensions
              showStatus: true,
              borderColor: Colors.blue,
              borderWidth: 2.0,
              backgroundColor: Colors.grey,
              onTap: () {},
              // onImageSelected is null - should create readonly
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Production code returns AvatarImageWidget.readonly, NOT CircleAvatar
        expect(find.byType(AvatarImageWidget), findsOneWidget);
      });

      testWidgets('avatar factory creates AvatarImageWidget.editable when onImageSelected provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 29-42
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.avatar(
              imageUrl: 'https://example.com/avatar.jpg',
              displayName: 'Test User',
              size: ImageSize.medium, // ULTRATHINK FIX: Avoid infinite dimensions
              onImageSelected: (url) {}, // Provides callback - should create editable
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Production code returns AvatarImageWidget.editable
        expect(find.byType(AvatarImageWidget), findsOneWidget);
      });

      testWidgets('avatar factory passes all parameters correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code parameter passing from lines 30-56
        const testImageUrl = 'https://example.com/test.jpg';
        const testDisplayName = 'John Doe';
        const testEmail = 'john@example.com';
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.avatar(
              imageUrl: testImageUrl,
              displayName: testDisplayName,
              email: testEmail,
              isOnline: false,
              size: ImageSize.small,
              showStatus: false,
              borderColor: Colors.red,
              borderWidth: 3.0,
              backgroundColor: Colors.yellow,
              onTap: () {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Verify actual widget receives correct parameters
        final avatarWidget = tester.widget<AvatarImageWidget>(find.byType(AvatarImageWidget));
        expect(avatarWidget.imageUrl, equals(testImageUrl));
        expect(avatarWidget.displayName, equals(testDisplayName));
        expect(avatarWidget.email, equals(testEmail));
        expect(avatarWidget.isOnline, equals(false));
        expect(avatarWidget.config.size, equals(ImageSize.small));
        expect(avatarWidget.config.showStatusIndicator, equals(false));
        expect(avatarWidget.config.borderColor, equals(Colors.red));
        expect(avatarWidget.config.borderWidth, equals(3.0));
        expect(avatarWidget.config.backgroundColor, equals(Colors.yellow));
      });
    });

    group('Recipe Factory Method Tests', () {
      testWidgets('recipeCard factory creates RecipeImageWidget.card',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 61-83
        const testImages = ['https://example.com/recipe1.jpg', 'https://example.com/recipe2.jpg'];
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.recipeCard(
              imageUrls: testImages,
              size: ImageSize.card,
              showMultipleIndicator: true,
              customWidth: 200,
              customHeight: 150,
              borderRadius: BorderRadius.circular(12),
              onTap: () {},
              onImageTap: (index) {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Production code returns RecipeImageWidget.card
        expect(find.byType(RecipeImageWidget), findsOneWidget);
      });

      testWidgets('recipeDetail factory creates RecipeImageWidget.detail',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 86-106
        const testImages = ['https://example.com/detail1.jpg', 'https://example.com/detail2.jpg'];
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.recipeDetail(
              imageUrls: testImages,
              size: ImageSize.medium, // ULTRATHINK FIX: Avoid infinite dimensions from ImageSize.large
              showNavigationDots: true,
              showImageCounter: true,
              heroTag: 'recipe-detail-hero',
              onTap: () {},
              onImageTap: (index) {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Production code returns RecipeImageWidget.detail
        expect(find.byType(RecipeImageWidget), findsOneWidget);
      });

      testWidgets('recipeEdit factory creates EditableImageWidget.recipeEdit',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 109-135
        const testImages = ['https://example.com/edit1.jpg'];
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.recipeEdit(
              imageUrls: testImages,
              size: ImageSize.medium, // ULTRATHINK FIX: Avoid infinite dimensions from ImageSize.large
              showEditControls: true,
              showNavigationDots: false,
              maxImages: 3,
              onImagesChanged: (images) {},
              onPrimaryImageChanged: (index) {},
              onImageTap: (index) {},
              primaryIndex: 0,
              isLoading: false,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Production code returns EditableImageWidget.recipeEdit
        expect(find.byType(EditableImageWidget), findsOneWidget);
      });
    });

    group('Gallery Factory Method Tests', () {
      testWidgets('gallery factory creates ImageGalleryWidget.gallery',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 138-166
        const testImages = ['https://example.com/gallery1.jpg', 'https://example.com/gallery2.jpg'];
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.gallery(
              imageUrls: testImages,
              size: ImageSize.thumbnail,
              showEditControls: false,
              onImageTap: (index) {},
              onImageLongPress: (url) {},
              onAddImage: () {},
              showAddButton: true,
              crossAxisCount: 2,
              crossAxisSpacing: 4.0,
              mainAxisSpacing: 4.0,
              childAspectRatio: 1.2,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Production code returns ImageGalleryWidget.gallery
        expect(find.byType(ImageGalleryWidget), findsOneWidget);
      });

      testWidgets('staggeredGallery factory creates StaggeredImageGalleryWidget',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 288-308
        const testImages = ['https://example.com/stag1.jpg', 'https://example.com/stag2.jpg'];
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.staggeredGallery(
              imageUrls: testImages,
              size: ImageSize.thumbnail,
              onImageTap: (index) {},
              onImageLongPress: (url) {},
              crossAxisCount: 2,
              crossAxisSpacing: 6.0,
              mainAxisSpacing: 6.0,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Production code returns StaggeredImageGalleryWidget
        expect(find.byType(StaggeredImageGalleryWidget), findsOneWidget);
      });
    });

    group('Picker Factory Method Tests', () {
      testWidgets('picker factory creates ImagePickerWidget.picker',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 169-189
        const testSelectedImages = ['https://example.com/selected1.jpg'];
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.picker(
              selectedImages: testSelectedImages,
              size: ImageSize.medium,
              maxImages: 4,
              onImagesSelected: (images) {},
              onImageRemoved: (url) {},
              allowMultiple: true,
              showImagePreview: true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Production code returns ImagePickerWidget.picker
        expect(find.byType(ImagePickerWidget), findsOneWidget);
      });
    });

    group('SimpleImage Factory Method Tests', () {
      testWidgets('hero factory creates SimpleImageWidget.hero',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 192-214
        const testImageUrl = 'https://example.com/hero.jpg';
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.hero(
              imageUrl: testImageUrl,
              heroTag: 'test-hero-tag',
              customWidth: 250,
              customHeight: 200,
              borderRadius: BorderRadius.circular(16),
              onTap: () {},
              onLongPress: () {},
              fit: BoxFit.contain,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Production code returns SimpleImageWidget.hero
        expect(find.byType(SimpleImageWidget), findsOneWidget);
        // Should also have Hero wrapper
        expect(find.byType(Hero), findsOneWidget);
      });

      testWidgets('thumbnail factory creates SimpleImageWidget.thumbnail',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 217-235
        const testImageUrl = 'https://example.com/thumb.jpg';
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.thumbnail(
              imageUrl: testImageUrl,
              size: ImageSize.thumbnail,
              borderRadius: BorderRadius.circular(8),
              onTap: () {},
              onLongPress: () {},
              fit: BoxFit.cover,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Production code returns SimpleImageWidget.thumbnail
        expect(find.byType(SimpleImageWidget), findsOneWidget);
      });

      testWidgets('cached factory creates SimpleImageWidget.cached',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 238-260
        const testImageUrl = 'https://example.com/cached.jpg';
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.cached(
              imageUrl: testImageUrl,
              size: ImageSize.medium,
              customWidth: 180,
              customHeight: 120,
              borderRadius: BorderRadius.circular(10),
              onTap: () {},
              onLongPress: () {},
              fit: BoxFit.fitWidth,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Production code returns SimpleImageWidget.cached
        expect(find.byType(SimpleImageWidget), findsOneWidget);
      });
    });

    group('Specialized Widget Factory Method Tests', () {
      testWidgets('carousel factory creates ImageCarouselWidget',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 263-285
        const testImages = ['https://example.com/car1.jpg', 'https://example.com/car2.jpg'];
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.carousel(
              imageUrls: testImages,
              size: ImageSize.medium, // ULTRATHINK FIX: Avoid infinite dimensions from ImageSize.large
              showNavigationDots: true,
              showImageCounter: false,
              onImageTap: (index) {},
              onPageChanged: (index) {},
              initialIndex: 1,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Production code returns ImageCarouselWidget
        expect(find.byType(ImageCarouselWidget), findsOneWidget);
      });

      testWidgets('expandable factory creates ExpandableImageWidget',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 311-327
        const testImageUrl = 'https://example.com/expandable.jpg';
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.expandable(
              imageUrl: testImageUrl,
              size: ImageSize.medium, // ULTRATHINK FIX: Avoid infinite dimensions from ImageSize.large
              onTap: () {},
              onExpandedChanged: (expanded) {},
              initiallyExpanded: false,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Production code returns ExpandableImageWidget
        expect(find.byType(ExpandableImageWidget), findsOneWidget);
      });

      testWidgets('lazy factory creates LazyImageWidget',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 330-344
        const testImageUrl = 'https://example.com/lazy.jpg';
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.lazy(
              imageUrl: testImageUrl,
              size: ImageSize.medium,
              onTap: () {},
              autoLoad: true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Production code returns LazyImageWidget
        expect(find.byType(LazyImageWidget), findsOneWidget);
      });

      testWidgets('network factory creates NetworkImageWidget',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 347-373
        const testImageUrl = 'https://example.com/network.jpg';
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.network(
              imageUrl: testImageUrl,
              width: 200,
              height: 150,
              fit: BoxFit.scaleDown,
              borderRadius: BorderRadius.circular(5),
              onTap: () {},
              onLongPress: () {},
              enableHapticFeedback: true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Production code returns NetworkImageWidget
        expect(find.byType(NetworkImageWidget), findsOneWidget);
      });
    });

    group('Edge Cases and Error Handling Tests', () {
      testWidgets('handles empty image lists gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with empty image lists
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.gallery(
              imageUrls: const [], // Empty list
              onImageTap: (index) {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(ImageGalleryWidget), findsOneWidget);
      });

      testWidgets('handles null optional parameters gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with minimal parameters
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.avatar(
              // All optional parameters null/default
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(AvatarImageWidget), findsOneWidget);
      });

      testWidgets('handles very long image URLs gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code URL handling
        final longUrl = 'https://example.com/${'very-long-filename' * 20}.jpg';
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.thumbnail(
              imageUrl: longUrl,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(SimpleImageWidget), findsOneWidget);
      });

      testWidgets('handles single image in multi-image factories',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code single image handling
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.recipeCard(
              imageUrls: const ['https://example.com/single.jpg'], // Single image
              showMultipleIndicator: true, // Indicator shouldn't show for single image
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(RecipeImageWidget), findsOneWidget);
      });
    });

    group('Parameter Validation Tests', () {
      testWidgets('factory methods preserve all parameter values correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Comprehensive parameter passing verification
        const testImages = ['https://example.com/param1.jpg', 'https://example.com/param2.jpg'];
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageFactory.gallery(
              imageUrls: testImages,
              size: ImageSize.thumbnail,
              showEditControls: true,
              showAddButton: true,
              crossAxisCount: 4,
              crossAxisSpacing: 12.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 0.8,
              onImageTap: (index) {},
              onImageLongPress: (url) {},
              onAddImage: () {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Verify actual widget receives all parameters
        final galleryWidget = tester.widget<ImageGalleryWidget>(find.byType(ImageGalleryWidget));
        expect(galleryWidget.imageUrls, equals(testImages));
        expect(galleryWidget.config.size, equals(ImageSize.thumbnail));
        expect(galleryWidget.config.showEditControls, equals(true));
        expect(galleryWidget.showAddButton, equals(true));
        expect(galleryWidget.crossAxisCount, equals(4));
        expect(galleryWidget.crossAxisSpacing, equals(12.0));
        expect(galleryWidget.mainAxisSpacing, equals(8.0));
        expect(galleryWidget.childAspectRatio, equals(0.8));
      });
    });

    // ULTRATHINK NOTE: showImagePicker is async and requires BuildContext for modal display
    // This would require more complex testing setup and is primarily a delegation method
    // The actual picker functionality is tested in ImagePickerBottomSheet tests
  });
}