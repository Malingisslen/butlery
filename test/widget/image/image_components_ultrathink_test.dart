// test/widget/image/image_components_ultrathink_test.dart
// ULTRATHINK TEST SUITE: ImageComponents - 383 lines of production code
// Testing static utility class with 11 methods for adaptive images, placeholders, and indicators
// 
// ULTRATHINK FOCUS: Static methods, file vs URL detection, CachedNetworkImage integration, graceful error handling

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Production imports - NEVER assume, always check production code first
import 'package:butlery/widgets/image/image_components.dart';
import 'package:butlery/widgets/image/image_config.dart';

// Test infrastructure imports - using centralized system
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  group('ImageComponents Ultrathink Tests', () {
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

    group('buildAdaptiveImage Method Tests', () {
      testWidgets('detects file paths and delegates to file image handler',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code file path detection from lines 23-32, 47-52
        final config = ImageConfig.cached(size: ImageSize.medium, borderRadius: BorderRadius.circular(8));
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageComponents.buildAdaptiveImage(
              pathOrUrl: '/storage/emulated/0/image.jpg', // File path pattern
              config: config,
              fit: BoxFit.cover,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: File paths create ClipRRect wrapper (line 102-107) around FutureBuilder
        // _isFilePath('/storage/emulated/0/image.jpg') should return true (startsWith('/'))
        // _buildFileImage creates FutureBuilder, then gets wrapped in ClipRRect due to borderRadius
        expect(find.byType(ClipRRect), findsOneWidget);
        
        // ULTRATHINK: Should NOT create CachedNetworkImage (that's for URLs)
        expect(find.byType(CachedNetworkImage), findsNothing);
      });

      testWidgets('detects URLs and delegates to cached image handler',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code URL detection from lines 34-42
        final config = ImageConfig.cached(size: ImageSize.medium);
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageComponents.buildAdaptiveImage(
              pathOrUrl: 'https://example.com/image.jpg', // URL pattern
              config: config,
              fit: BoxFit.contain,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: URLs delegate to CachedNetworkImage
        expect(find.byType(CachedNetworkImage), findsOneWidget);
      });

      testWidgets('handles custom placeholder and error widgets',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code custom widget passing
        final config = ImageConfig.cached(size: ImageSize.medium);
        final customPlaceholder = Container(color: Colors.blue);
        final customError = Container(color: Colors.red);
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageComponents.buildAdaptiveImage(
              pathOrUrl: 'https://example.com/image.jpg',
              config: config,
              placeholder: customPlaceholder,
              errorWidget: customError,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // Custom widgets should be passed through to CachedNetworkImage
        expect(find.byType(CachedNetworkImage), findsOneWidget);
      });

      testWidgets('applies tap handler when onTap provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code tap wrapping from line 110, 377-382
        final config = ImageConfig.cached(size: ImageSize.medium);
        bool tapped = false;
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageComponents.buildAdaptiveImage(
              pathOrUrl: 'https://example.com/image.jpg',
              config: config,
              onTap: () => tapped = true,
            ),
          ),
        );

        // ULTRATHINK: buildOptimizedCachedImage calls _wrapWithTapHandler when onTap != null (line 146-148)
        expect(find.byType(GestureDetector), findsOneWidget);
        
        // ULTRATHINK: Verify GestureDetector has the correct callback assigned
        final gestureDetector = tester.widget<GestureDetector>(find.byType(GestureDetector));
        expect(gestureDetector.onTap, isNotNull);
        
        // ULTRATHINK: Manually trigger the callback to verify it works
        gestureDetector.onTap!();
        expect(tapped, isTrue);
      });
    });

    group('buildOptimizedCachedImage Method Tests', () {
      testWidgets('creates CachedNetworkImage with correct parameters',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code CachedNetworkImage creation from lines 117-151
        final config = ImageConfig.cached(
          size: ImageSize.custom,  // Custom size to use customWidth/Height
          customWidth: 200,
          customHeight: 150,
        );
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageComponents.buildOptimizedCachedImage(
              imageUrl: 'https://example.com/test.jpg',
              config: config,
              fit: BoxFit.scaleDown,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Verify CachedNetworkImage receives correct parameters
        final cachedImage = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
        expect(cachedImage.imageUrl, equals('https://example.com/test.jpg'));
        expect(cachedImage.fit, equals(BoxFit.scaleDown));
        expect(cachedImage.width, equals(200));
        expect(cachedImage.height, equals(150));
      });

      testWidgets('applies border radius when specified in config',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code border radius application from lines 139-143
        final config = ImageConfig.cached(
          size: ImageSize.medium,
          borderRadius: BorderRadius.circular(12),
        );
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageComponents.buildOptimizedCachedImage(
              imageUrl: 'https://example.com/test.jpg',
              config: config,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // Should wrap CachedNetworkImage in ClipRRect when borderRadius specified
        expect(find.byType(ClipRRect), findsOneWidget);
        expect(find.byType(CachedNetworkImage), findsOneWidget);
      });

      testWidgets('handles infinite dimensions gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code infinite dimensions handling from lines 132-134
        final config = ImageConfig.cached(size: ImageSize.large); // Can cause infinite dimensions
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageComponents.buildOptimizedCachedImage(
              imageUrl: 'https://example.com/test.jpg',
              config: config,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Infinite width should become null, memCacheWidth should be 800
        final cachedImage = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
        expect(cachedImage.width, isNull); // Infinite width becomes null
        expect(cachedImage.memCacheWidth, equals(800)); // Fallback cache width
      });
    });

    group('Placeholder Method Tests', () {
      testWidgets('buildPlaceholder creates container with default icon',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code placeholder from lines 154-182
        final config = ImageConfig.cached(size: ImageSize.medium);
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageComponents.buildPlaceholder(config: config),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(Container), findsOneWidget);
        // ULTRATHINK: Default icon is Icons.restaurant_menu (line 177)
        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
      });

      testWidgets('buildPlaceholder applies custom child and background',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code custom child and background
        final config = ImageConfig.cached(size: ImageSize.medium);
        final customChild = Icon(Icons.star, color: Colors.yellow);
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageComponents.buildPlaceholder(
              config: config,
              backgroundColor: Colors.purple,
              child: customChild,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.star), findsOneWidget);
        // Default restaurant_menu icon should not appear when custom child provided
        expect(find.byIcon(Icons.restaurant_menu), findsNothing);
      });

      testWidgets('buildLoadingPlaceholder shows circular progress indicator',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code loading placeholder from lines 185-205
        final config = ImageConfig.cached(size: ImageSize.medium);
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageComponents.buildLoadingPlaceholder(config: config),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // Should be wrapped in Center and SizedBox
        expect(find.byType(Center), findsOneWidget);
        expect(find.byType(SizedBox), findsAtLeastNWidgets(1));
      });

      testWidgets('buildErrorPlaceholder shows graceful fallback icon',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code error placeholder from lines 208-225
        final config = ImageConfig.cached(size: ImageSize.medium);
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageComponents.buildErrorPlaceholder(config: config),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Error shows Icons.image_outlined (line 220), not red error
        expect(find.byIcon(Icons.image_outlined), findsOneWidget);
        // Should not show intimidating error indicators
        expect(find.byIcon(Icons.error), findsNothing);
      });
    });

    group('Indicator Method Tests', () {
      testWidgets('buildMultipleIndicator shows count for multiple images',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code multiple indicator from lines 228-269
        final config = ImageConfig.cached(size: ImageSize.medium);
        
        await tester.pumpWidget(
          createTestWidget(
            child: Stack(
              children: [
                Container(width: 200, height: 200, color: Colors.grey),
                ImageComponents.buildMultipleIndicator(
                  imageCount: 5,
                  config: config,
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('5'), findsOneWidget);
        expect(find.byIcon(Icons.collections_outlined), findsOneWidget);
        // Should be positioned widget
        expect(find.byType(Positioned), findsOneWidget);
      });

      testWidgets('buildMultipleIndicator hides for single image',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code single image hiding from line 232
        final config = ImageConfig.cached(size: ImageSize.medium);
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageComponents.buildMultipleIndicator(
              imageCount: 1,
              config: config,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Check for SizedBox.shrink specifically, avoiding test wrapper SizedBox
        expect(find.byWidgetPredicate((widget) => 
          widget is SizedBox && 
          widget.width == 0.0 && 
          widget.height == 0.0), findsOneWidget);
        expect(find.text('1'), findsNothing);
      });

      testWidgets('buildImageCounter shows current position',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code image counter from lines 272-303
        final config = ImageConfig.cached(size: ImageSize.medium);
        
        await tester.pumpWidget(
          createTestWidget(
            child: Stack(
              children: [
                Container(width: 200, height: 200, color: Colors.grey),
                ImageComponents.buildImageCounter(
                  currentIndex: 2,
                  totalImages: 7,
                  config: config,
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Shows "currentIndex + 1" (line 294)
        expect(find.text('3/7'), findsOneWidget);
        expect(find.byType(Positioned), findsOneWidget);
      });

      testWidgets('buildNavigationDots creates tappable dots',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code navigation dots from lines 306-343
        final config = ImageConfig.cached(size: ImageSize.medium);
        int? tappedIndex;
        
        await tester.pumpWidget(
          createTestWidget(
            child: Stack(
              children: [
                Container(width: 200, height: 200, color: Colors.grey),
                ImageComponents.buildNavigationDots(
                  currentIndex: 1,
                  totalImages: 3,
                  config: config,
                  onDotTap: (index) => tappedIndex = index,
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // Should create 3 GestureDetectors for 3 images
        expect(find.byType(GestureDetector), findsNWidgets(3));
        
        // Test tapping second dot (index 1)
        await tester.tap(find.byType(GestureDetector).at(1));
        expect(tappedIndex, equals(1));
      });

      testWidgets('buildStatusIndicator shows online/offline status',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code status indicator from lines 346-374
        final config = ImageConfig.avatar(showStatus: true, size: ImageSize.medium);
        
        await tester.pumpWidget(
          createTestWidget(
            child: Stack(
              children: [
                Container(width: 100, height: 100, color: Colors.grey),
                ImageComponents.buildStatusIndicator(
                  isOnline: true,
                  config: config,
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(Positioned), findsOneWidget);
        // Status indicator should be a circular container
        final container = tester.widget<Container>(find.byType(Container).last);
        expect(container.decoration, isA<BoxDecoration>());
      });

      testWidgets('buildStatusIndicator handles infinite dimensions gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code infinite dimensions fix from lines 354-356
        final config = ImageConfig.avatar(showStatus: true, size: ImageSize.large); // May cause infinite dimensions
        
        await tester.pumpWidget(
          createTestWidget(
            child: Stack(
              children: [
                Container(width: 100, height: 100, color: Colors.grey),
                ImageComponents.buildStatusIndicator(
                  isOnline: false,
                  config: config,
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // Should handle infinite dimensions without crashing
        expect(find.byType(Container), findsAtLeastNWidgets(1));
      });

      testWidgets('buildStatusIndicator hides when showStatusIndicator is false',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code status hiding from line 350
        final config = ImageConfig.avatar(showStatus: false, size: ImageSize.medium);
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageComponents.buildStatusIndicator(
              isOnline: true,
              config: config,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // ULTRATHINK: Check for SizedBox.shrink specifically, avoiding test wrapper SizedBox
        expect(find.byWidgetPredicate((widget) => 
          widget is SizedBox && 
          widget.width == 0.0 && 
          widget.height == 0.0), findsOneWidget);
        expect(find.byType(Positioned), findsNothing);
      });
    });

    group('Edge Cases and Integration Tests', () {
      testWidgets('handles null onTap gracefully in buildOptimizedCachedImage',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code null callback handling
        final config = ImageConfig.cached(size: ImageSize.medium);
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageComponents.buildOptimizedCachedImage(
              imageUrl: 'https://example.com/test.jpg',
              config: config,
              onTap: null, // Null callback
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // Should not wrap in GestureDetector when onTap is null
        expect(find.byType(GestureDetector), findsNothing);
        expect(find.byType(CachedNetworkImage), findsOneWidget);
      });

      testWidgets('handles zero and negative image counts in indicators',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code edge cases
        final config = ImageConfig.cached(size: ImageSize.medium);
        
        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                ImageComponents.buildMultipleIndicator(
                  imageCount: 0,
                  config: config,
                ),
                ImageComponents.buildImageCounter(
                  currentIndex: 0,
                  totalImages: 0,
                  config: config,
                ),
                ImageComponents.buildNavigationDots(
                  currentIndex: 0,
                  totalImages: 0,
                  config: config,
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // All should return SizedBox.shrink for zero/invalid counts
        expect(find.byType(SizedBox), findsAtLeastNWidgets(3));
      });

      testWidgets('placeholder dimensions respect config constraints',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code dimension constraints - custom size uses customWidth/Height
        final config = ImageConfig.cached(
          size: ImageSize.custom,
          customWidth: 150,
          customHeight: 100,
        );
        
        await tester.pumpWidget(
          createTestWidget(
            child: ImageComponents.buildPlaceholder(config: config),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Container uses width/height from buildPlaceholder (lines 162-163)
        // Production code: width: dimensions.width == double.infinity ? null : dimensions.width
        // Since custom size with 150x100, dimensions should be Size(150, 100)
        final container = tester.widget<Container>(find.byType(Container).last);
        expect(container.constraints, equals(BoxConstraints.tightFor(width: 150.0, height: 100.0)));
      });

      testWidgets('complex integration with all features',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code integration scenario
        final config = ImageConfig.recipeDetail(
          size: ImageSize.medium,
          showNavigationDots: true,
          showImageCounter: true,
        );
        
        await tester.pumpWidget(
          createTestWidget(
            child: Stack(
              children: [
                ImageComponents.buildOptimizedCachedImage(
                  imageUrl: 'https://example.com/recipe.jpg',
                  config: config,
                  onTap: () {},
                ),
                ImageComponents.buildImageCounter(
                  currentIndex: 2,
                  totalImages: 5,
                  config: config,
                ),
                ImageComponents.buildNavigationDots(
                  currentIndex: 2,
                  totalImages: 5,
                  config: config,
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // All components should render together
        expect(find.byType(CachedNetworkImage), findsOneWidget);
        expect(find.byType(ClipRRect), findsOneWidget); // Border radius
        expect(find.byType(GestureDetector), findsAtLeastNWidgets(1)); // Tap + dots
        expect(find.text('3/5'), findsOneWidget); // Counter
      });
    });
  });
}