// test/widget/image/image_config_ultrathink_test.dart
// ULTRATHINK TEST SUITE: ImageConfig - 360 lines of production code
// Testing 9 factory constructors, 3 enums (ImageType, ImageDisplayMode, ImageSize), and 4 utility methods
//
// ULTRATHINK FOCUS: Configuration validation, factory constructor patterns, dimension calculations, border radius logic

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports - NEVER assume, always check production code first
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/theme/app_dimensions.dart';

// Test infrastructure imports - using centralized system
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  group('ImageConfig Ultrathink Tests', () {
    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
    });

    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    group('Enum Definitions Tests', () {
      testWidgets('ImageType enum contains all required values',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code enum from lines 7-17
        expect(ImageType.avatar, isNotNull);
        expect(ImageType.recipeCard, isNotNull);
        expect(ImageType.recipeDetail, isNotNull);
        expect(ImageType.recipeEdit, isNotNull);
        expect(ImageType.gallery, isNotNull);
        expect(ImageType.picker, isNotNull);
        expect(ImageType.hero, isNotNull);
        expect(ImageType.thumbnail, isNotNull);
        expect(ImageType.cached, isNotNull);

        // ULTRATHINK: Verify enum has exactly 9 values as per production code
        expect(ImageType.values.length, equals(9));
      });

      testWidgets('ImageDisplayMode enum contains all required values',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code enum from lines 19-28
        expect(ImageDisplayMode.readonly, isNotNull);
        expect(ImageDisplayMode.editable, isNotNull);
        expect(ImageDisplayMode.expandable, isNotNull);
        expect(ImageDisplayMode.carousel, isNotNull);
        expect(ImageDisplayMode.grid, isNotNull);
        expect(ImageDisplayMode.picker, isNotNull);

        // ULTRATHINK: Verify enum has exactly 6 values as per production code
        expect(ImageDisplayMode.values.length, equals(6));
      });

      testWidgets('ImageSize enum contains all required values',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code enum from lines 29-39
        expect(ImageSize.small, isNotNull);
        expect(ImageSize.medium, isNotNull);
        expect(ImageSize.large, isNotNull);
        expect(ImageSize.extraLarge, isNotNull);
        expect(ImageSize.card, isNotNull);
        expect(ImageSize.hero, isNotNull);
        expect(ImageSize.thumbnail, isNotNull);
        expect(ImageSize.custom, isNotNull);

        // ULTRATHINK: Verify enum has exactly 8 values as per production code
        expect(ImageSize.values.length, equals(8));
      });
    });

    group('Factory Constructor Tests', () {
      testWidgets('ImageConfig.avatar creates correct configuration',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code factory from lines 86-111
        final config = ImageConfig.avatar();

        expect(config.type, equals(ImageType.avatar));
        expect(config.mode, equals(ImageDisplayMode.readonly));
        expect(config.size, equals(ImageSize.medium)); // Default size
        expect(config.showPlaceholder, isTrue);
        expect(config.showLoadingIndicator, isTrue);
        expect(config.showMultipleIndicator, isFalse); // Avatar-specific
        expect(config.showEditControls, isFalse); // Avatar-specific
        expect(
            config.showStatusIndicator, isFalse); // Default showStatus = false
        expect(config.showNavigationDots, isFalse); // Avatar-specific
        expect(config.showImageCounter, isFalse); // Avatar-specific
        expect(config.enableHapticFeedback, isFalse); // Avatar-specific
        expect(config.maxImages, equals(1)); // Avatar-specific

        // ULTRATHINK: Border radius uses AppDimensions.borderRadius100 (line 106)
        expect(config.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius100)));
      });

      testWidgets('ImageConfig.avatar with custom parameters',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code factory with custom parameters
        final config = ImageConfig.avatar(
          size: ImageSize.large,
          showStatus: true,
          borderColor: Colors.red,
          borderWidth: 2.0,
          backgroundColor: Colors.blue,
        );

        expect(config.size, equals(ImageSize.large));
        expect(config.showStatusIndicator, isTrue); // Custom showStatus
        expect(config.borderColor, equals(Colors.red));
        expect(config.borderWidth, equals(2.0));
        expect(config.backgroundColor, equals(Colors.blue));
      });

      testWidgets('ImageConfig.recipeCard creates correct configuration',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code factory from lines 113-138
        final config = ImageConfig.recipeCard();

        expect(config.type, equals(ImageType.recipeCard));
        expect(config.mode, equals(ImageDisplayMode.readonly));
        expect(config.size,
            equals(ImageSize.card)); // Default size for recipe cards
        expect(config.showPlaceholder, isTrue);
        expect(config.showLoadingIndicator, isTrue);
        expect(
            config.showMultipleIndicator, isTrue); // Default for recipe cards
        expect(config.showEditControls, isFalse); // Default for recipe cards
        expect(config.showStatusIndicator,
            isFalse); // Recipe cards don't show status
        expect(
            config.showNavigationDots, isFalse); // Recipe cards don't need dots
        expect(config.showImageCounter,
            isFalse); // Recipe cards don't need counter
        expect(config.enableHapticFeedback, isTrue);
        expect(config.maxImages, equals(5));

        // ULTRATHINK: Border radius uses AppDimensions.borderRadius12 (line 127)
        expect(config.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius12)));
      });

      testWidgets('ImageConfig.recipeDetail creates correct configuration',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code factory from lines 140-162
        final config = ImageConfig.recipeDetail();

        expect(config.type, equals(ImageType.recipeDetail));
        expect(config.mode, equals(ImageDisplayMode.carousel));
        expect(config.size,
            equals(ImageSize.large)); // Default size for detail view
        expect(config.showPlaceholder, isTrue);
        expect(config.showLoadingIndicator, isTrue);
        expect(config.showMultipleIndicator,
            isFalse); // Detail view uses dots/counter instead
        expect(config.showEditControls, isFalse); // Detail view is readonly
        expect(config.showStatusIndicator, isFalse);
        expect(config.showNavigationDots, isTrue); // Default for detail view
        expect(config.showImageCounter, isTrue); // Default for detail view
        expect(config.enableHapticFeedback, isTrue);
        expect(config.maxImages, equals(5));

        // ULTRATHINK: Border radius uses AppDimensions.borderRadius16 (line 150)
        expect(config.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius16)));
      });

      testWidgets('ImageConfig.recipeEdit creates correct configuration',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code factory from lines 164-185
        final config = ImageConfig.recipeEdit();

        expect(config.type, equals(ImageType.recipeEdit));
        expect(config.mode, equals(ImageDisplayMode.editable));
        expect(
            config.size, equals(ImageSize.large)); // Default size for edit mode
        expect(config.showPlaceholder, isTrue);
        expect(config.showLoadingIndicator, isTrue);
        expect(config.showMultipleIndicator, isFalse);
        expect(config.showEditControls, isTrue); // Default for edit mode
        expect(config.showStatusIndicator, isFalse);
        expect(config.showNavigationDots, isTrue); // Default for edit mode
        expect(config.showImageCounter, isTrue);
        expect(config.enableHapticFeedback, isTrue);
        expect(config.maxImages, equals(5)); // Default max images

        // ULTRATHINK: Border radius uses AppDimensions.borderRadius16 (line 174)
        expect(config.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius16)));
      });

      testWidgets('ImageConfig.gallery creates correct configuration',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code factory from lines 187-206
        final config = ImageConfig.gallery();

        expect(config.type, equals(ImageType.gallery));
        expect(config.mode, equals(ImageDisplayMode.grid));
        expect(config.size, equals(ImageSize.thumbnail)); // Default for gallery
        expect(config.showPlaceholder, isTrue);
        expect(config.showLoadingIndicator, isTrue);
        expect(config.showMultipleIndicator,
            isFalse); // Gallery doesn't need indicators
        expect(config.showEditControls, isFalse); // Default for gallery
        expect(config.showStatusIndicator, isFalse);
        expect(config.showNavigationDots, isFalse); // Gallery doesn't need dots
        expect(
            config.showImageCounter, isFalse); // Gallery doesn't need counter
        expect(config.enableHapticFeedback, isTrue);
        expect(config.maxImages, equals(50)); // Gallery allows many images

        // ULTRATHINK: Border radius uses AppDimensions.borderRadius8 (line 195)
        expect(config.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius8)));
      });

      testWidgets('ImageConfig.picker creates correct configuration',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code factory from lines 208-227
        final config = ImageConfig.picker();

        expect(config.type, equals(ImageType.picker));
        expect(config.mode, equals(ImageDisplayMode.picker));
        expect(config.size, equals(ImageSize.medium)); // Default for picker
        expect(config.showPlaceholder, isTrue);
        expect(config.showLoadingIndicator, isTrue);
        expect(config.showMultipleIndicator, isFalse);
        expect(config.showEditControls, isTrue); // Picker needs edit controls
        expect(config.showStatusIndicator, isFalse);
        expect(config.showNavigationDots, isFalse); // Picker doesn't need dots
        expect(config.showImageCounter, isFalse); // Picker doesn't need counter
        expect(config.enableHapticFeedback, isTrue);
        expect(config.maxImages, equals(5)); // Default max images

        // ULTRATHINK: Border radius uses AppDimensions.borderRadius12 (line 216)
        expect(config.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius12)));
      });

      testWidgets('ImageConfig.hero creates correct configuration',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code factory from lines 229-253
        final config = ImageConfig.hero();

        expect(config.type, equals(ImageType.hero));
        expect(config.mode, equals(ImageDisplayMode.expandable));
        expect(config.size, equals(ImageSize.hero));
        expect(config.showPlaceholder, isTrue);
        expect(config.showLoadingIndicator, isTrue);
        expect(config.showMultipleIndicator, isFalse);
        expect(config.showEditControls, isFalse); // Hero is readonly
        expect(config.showStatusIndicator, isFalse);
        expect(config.showNavigationDots, isFalse); // Hero doesn't need dots
        expect(config.showImageCounter, isFalse); // Hero doesn't need counter
        expect(config.enableHapticFeedback, isTrue);
        expect(config.maxImages, equals(1)); // Hero shows single image
      });

      testWidgets('ImageConfig.thumbnail creates correct configuration',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code factory from lines 255-274
        final config = ImageConfig.thumbnail();

        expect(config.type, equals(ImageType.thumbnail));
        expect(config.mode, equals(ImageDisplayMode.readonly));
        expect(config.size, equals(ImageSize.thumbnail));
        expect(config.showPlaceholder, isTrue);
        expect(config.showLoadingIndicator, isTrue);
        expect(config.showMultipleIndicator, isFalse);
        expect(config.showEditControls, isFalse); // Thumbnail is readonly
        expect(config.showStatusIndicator, isFalse);
        expect(
            config.showNavigationDots, isFalse); // Thumbnail doesn't need dots
        expect(
            config.showImageCounter, isFalse); // Thumbnail doesn't need counter
        expect(config.enableHapticFeedback,
            isFalse); // Thumbnail doesn't need haptic
        expect(config.maxImages, equals(1)); // Thumbnail shows single image

        // ULTRATHINK: Border radius uses AppDimensions.borderRadius8 (line 263)
        expect(config.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius8)));
      });

      testWidgets('ImageConfig.cached creates correct configuration',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code factory from lines 276-299
        final config = ImageConfig.cached();

        expect(config.type, equals(ImageType.cached));
        expect(config.mode, equals(ImageDisplayMode.readonly));
        expect(config.size, equals(ImageSize.medium)); // Default size
        expect(config.showPlaceholder, isTrue);
        expect(config.showLoadingIndicator, isTrue);
        expect(config.showMultipleIndicator, isFalse);
        expect(config.showEditControls, isFalse); // Cached is readonly
        expect(config.showStatusIndicator, isFalse);
        expect(config.showNavigationDots, isFalse); // Cached doesn't need dots
        expect(config.showImageCounter, isFalse); // Cached doesn't need counter
        expect(
            config.enableHapticFeedback, isFalse); // Cached doesn't need haptic
        expect(config.maxImages, equals(1)); // Cached shows single image
      });
    });

    group('Dimension Calculation Tests', () {
      testWidgets('getDimensions returns correct sizes',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code getDimensions method from lines 302-322

        // Small size (line 305)
        var config = ImageConfig.cached(size: ImageSize.small);
        expect(config.getDimensions(), equals(const Size(40, 40)));

        // Medium size (line 307)
        config = ImageConfig.cached(size: ImageSize.medium);
        expect(config.getDimensions(), equals(const Size(80, 80)));

        // Large size (line 310) - responsive sizing
        config = ImageConfig.cached(size: ImageSize.large);
        expect(
            config.getDimensions(), equals(const Size(double.infinity, 280)));

        // Extra large size (line 312)
        config = ImageConfig.cached(size: ImageSize.extraLarge);
        expect(config.getDimensions(), equals(const Size(160, 160)));

        // Card size (line 314)
        config = ImageConfig.cached(size: ImageSize.card);
        expect(config.getDimensions(), equals(const Size(200, 140)));

        // Hero size (line 316)
        config = ImageConfig.cached(size: ImageSize.hero);
        expect(
            config.getDimensions(), equals(const Size(double.infinity, 300)));

        // Thumbnail size (line 318)
        config = ImageConfig.cached(size: ImageSize.thumbnail);
        expect(config.getDimensions(), equals(const Size(60, 60)));

        // Custom size (line 320)
        config = ImageConfig.cached(
          size: ImageSize.custom,
          customWidth: 150,
          customHeight: 100,
        );
        expect(config.getDimensions(), equals(const Size(150, 100)));

        // Custom size with defaults (customWidth/Height ?? 80)
        config = ImageConfig.cached(size: ImageSize.custom);
        expect(config.getDimensions(), equals(const Size(80, 80)));
      });

      testWidgets('getAspectRatio returns correct ratios',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code getAspectRatio method from lines 325-331

        // Square size should return 1.0
        var config = ImageConfig.cached(size: ImageSize.medium);
        expect(config.getAspectRatio(), equals(1.0)); // 80/80 = 1.0

        // Rectangle size
        config = ImageConfig.cached(size: ImageSize.card);
        expect(config.getAspectRatio(), equals(200.0 / 140.0));

        // Infinite width should return 16/9 (line 328)
        config = ImageConfig.cached(size: ImageSize.large);
        expect(config.getAspectRatio(), equals(16.0 / 9.0));

        // Hero size (infinite width)
        config = ImageConfig.cached(size: ImageSize.hero);
        expect(config.getAspectRatio(), equals(16.0 / 9.0));
      });

      testWidgets('isSquare returns correct boolean',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code isSquare getter from lines 334-337

        // Square sizes
        var config = ImageConfig.cached(size: ImageSize.small);
        expect(config.isSquare, isTrue); // 40x40

        config = ImageConfig.cached(size: ImageSize.medium);
        expect(config.isSquare, isTrue); // 80x80

        config = ImageConfig.cached(size: ImageSize.extraLarge);
        expect(config.isSquare, isTrue); // 160x160

        config = ImageConfig.cached(size: ImageSize.thumbnail);
        expect(config.isSquare, isTrue); // 60x60

        // Non-square sizes
        config = ImageConfig.cached(size: ImageSize.card);
        expect(config.isSquare, isFalse); // 200x140

        config = ImageConfig.cached(size: ImageSize.large);
        expect(config.isSquare, isFalse); // infinity x 280

        config = ImageConfig.cached(size: ImageSize.hero);
        expect(config.isSquare, isFalse); // infinity x 300
      });
    });

    group('Border Radius Logic Tests', () {
      testWidgets('effectiveBorderRadius returns custom radius when specified',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code effectiveBorderRadius getter from lines 340-360
        final customRadius = BorderRadius.circular(25.0);
        final config = ImageConfig.cached(borderRadius: customRadius);

        // When borderRadius is specified, it should return the custom value (line 341)
        expect(config.effectiveBorderRadius, equals(customRadius));
      });

      testWidgets('effectiveBorderRadius returns type-specific defaults',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code type-specific border radius logic

        // Avatar type (line 345)
        var config = ImageConfig.avatar();
        expect(config.effectiveBorderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius100)));

        // Recipe card type (line 347)
        config = ImageConfig.recipeCard();
        expect(config.effectiveBorderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius12)));

        // Recipe detail type (line 349)
        config = ImageConfig.recipeDetail();
        expect(config.effectiveBorderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius16)));

        // Recipe edit type (line 349)
        config = ImageConfig.recipeEdit();
        expect(config.effectiveBorderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius16)));

        // Gallery type (line 352)
        config = ImageConfig.gallery();
        expect(config.effectiveBorderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius8)));

        // Thumbnail type (line 352)
        config = ImageConfig.thumbnail();
        expect(config.effectiveBorderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius8)));

        // Picker type (line 355)
        config = ImageConfig.picker();
        expect(config.effectiveBorderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius12)));

        // Hero type (line 358)
        config = ImageConfig.hero();
        expect(config.effectiveBorderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius0)));

        // Cached type (line 358)
        config = ImageConfig.cached();
        expect(config.effectiveBorderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadius0)));
      });
    });

    group('Edge Cases and Integration Tests', () {
      testWidgets('handles null custom dimensions gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code null handling in custom size
        final config = ImageConfig.cached(
          size: ImageSize.custom,
          customWidth: null,
          customHeight: null,
        );

        // Should fallback to 80x80 when custom dimensions are null
        expect(config.getDimensions(), equals(const Size(80, 80)));
      });

      testWidgets('factory constructors with all parameters',
          (WidgetTester tester) async {
        // ULTRATHINK: Test factory constructors with full parameter sets
        final recipeEditConfig = ImageConfig.recipeEdit(
          size: ImageSize.extraLarge,
          showEditControls: false,
          showNavigationDots: false,
          maxImages: 10,
        );

        expect(recipeEditConfig.size, equals(ImageSize.extraLarge));
        expect(recipeEditConfig.showEditControls, isFalse);
        expect(recipeEditConfig.showNavigationDots, isFalse);
        expect(recipeEditConfig.maxImages, equals(10));

        final heroConfig = ImageConfig.hero(
          heroTag: 'recipe_hero',
          customWidth: 300,
          customHeight: 200,
          borderRadius: BorderRadius.circular(20),
        );

        expect(heroConfig.heroTag, equals('recipe_hero'));
        expect(heroConfig.customWidth, equals(300));
        expect(heroConfig.customHeight, equals(200));
        expect(heroConfig.borderRadius, equals(BorderRadius.circular(20)));
      });

      testWidgets('complex configuration combinations',
          (WidgetTester tester) async {
        // ULTRATHINK: Test complex real-world configuration scenarios

        // Avatar with status and custom styling
        final avatarConfig = ImageConfig.avatar(
          size: ImageSize.large,
          showStatus: true,
          borderColor: Colors.green,
          borderWidth: 3.0,
        );

        expect(avatarConfig.showStatusIndicator, isTrue);
        expect(avatarConfig.borderColor, equals(Colors.green));
        expect(avatarConfig.borderWidth, equals(3.0));
        expect(avatarConfig.getDimensions(),
            equals(const Size(double.infinity, 280)));
        expect(avatarConfig.getAspectRatio(), equals(16.0 / 9.0));
        expect(avatarConfig.isSquare, isFalse);

        // Gallery with custom edit controls
        final galleryConfig = ImageConfig.gallery(
          size: ImageSize.card,
          showEditControls: true,
        );

        expect(galleryConfig.showEditControls, isTrue);
        expect(galleryConfig.getDimensions(), equals(const Size(200, 140)));
        expect(galleryConfig.isSquare, isFalse);

        // Picker with custom max images
        final pickerConfig = ImageConfig.picker(
          size: ImageSize.small,
          maxImages: 15,
        );

        expect(pickerConfig.maxImages, equals(15));
        expect(pickerConfig.getDimensions(), equals(const Size(40, 40)));
        expect(pickerConfig.isSquare, isTrue);
      });
    });
  });
}
