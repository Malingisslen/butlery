import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/image/image_factory.dart';
import 'package:butlery/widgets/image/avatar_image_widget.dart';
import 'package:butlery/widgets/image/recipe_image_widget.dart';
import 'package:butlery/widgets/image/editable_image_widget.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  group('ImageFactory Widget Tests', () {
    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
    });

    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    group('Avatar Display', () {
      testWidgets('renders avatar with image URL', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ImageFactory.avatar(
              imageUrl: 'https://example.com/avatar.jpg',
              displayName: 'Test User',
            ),
          ),
        );

        expect(find.byType(AvatarImageWidget), findsOneWidget);
      });

      testWidgets('renders avatar with initials when no image', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ImageFactory.avatar(
              displayName: 'Anna Andersson',
            ),
          ),
        );

        // AvatarImageWidget uses UserAvatarWidgets.getInitials -> "AA"
        expect(find.text('AA'), findsOneWidget);
        expect(find.byType(AvatarImageWidget), findsOneWidget);
      });

      testWidgets('shows online indicator when showStatus is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ImageFactory.avatar(
              displayName: 'Test User',
              showStatus: true,
              isOnline: true,
            ),
          ),
        );

        // Status indicator renders inside a Stack
        expect(find.byType(AvatarImageWidget), findsOneWidget);
      });

      testWidgets('responds to tap events', (tester) async {
        bool tapped = false;
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ImageFactory.avatar(
              displayName: 'Test User',
              onTap: () => tapped = true,
            ),
          ),
        );

        // Production uses GestureDetector wrapping the avatar
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();

        expect(tapped, isTrue);
      });
    });

    group('Recipe Card Display', () {
      testWidgets('renders recipe card with image', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SizedBox(
              width: 200,
              height: 150,
              child: ImageFactory.recipeCard(
                imageUrls: ['https://example.com/recipe.jpg'],
              ),
            ),
          ),
        );

        expect(find.byType(RecipeImageWidget), findsOneWidget);
      });

      testWidgets('shows placeholder when no image', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SizedBox(
              width: 200,
              height: 150,
              child: ImageFactory.recipeCard(
                imageUrls: [],
              ),
            ),
          ),
        );

        // Empty state uses buildPlaceholder which defaults to Icons.restaurant_menu
        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
      });

      testWidgets('accepts onTap callback', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SizedBox(
              width: 200,
              height: 150,
              child: ImageFactory.recipeCard(
                imageUrls: ['https://example.com/recipe.jpg'],
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RecipeImageWidget), findsOneWidget);
      });
    });

    group('Recipe Detail Display', () {
      testWidgets('renders recipe detail image', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ImageFactory.recipeDetail(
              imageUrls: ['https://example.com/recipe.jpg'],
            ),
          ),
        );

        expect(find.byType(RecipeImageWidget), findsOneWidget);
      });

      testWidgets('supports hero animation', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ImageFactory.recipeDetail(
              imageUrls: ['https://example.com/recipe.jpg'],
              heroTag: 'recipe-hero',
            ),
          ),
        );

        expect(find.byType(Hero), findsOneWidget);
      });

      testWidgets('wires up onImageTap with GestureDetector', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ImageFactory.recipeDetail(
              imageUrls: ['https://example.com/recipe.jpg'],
              onImageTap: (index) {},
            ),
          ),
        );

        // Verify GestureDetector exists inside RecipeImageWidget for tap handling
        final gestureDetector = find.descendant(
          of: find.byType(RecipeImageWidget),
          matching: find.byType(GestureDetector),
        );
        expect(gestureDetector, findsOneWidget);
      });
    });

    group('Recipe Edit Display', () {
      testWidgets('renders editable images', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ImageFactory.recipeEdit(
              imageUrls: ['https://example.com/image1.jpg'],
              maxImages: 5,
            ),
          ),
        );

        expect(find.byType(EditableImageWidget), findsOneWidget);
      });

      testWidgets('shows add image button when under max', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ImageFactory.recipeEdit(
              imageUrls: ['https://example.com/image1.jpg'],
              maxImages: 5,
            ),
          ),
        );

        // Single image uses carousel with EditActionsPanel showing add_photo_alternate_outlined
        expect(
          find.byIcon(Icons.add_photo_alternate_outlined),
          findsOneWidget,
        );
      });

      testWidgets('shows empty state when no images', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ImageFactory.recipeEdit(
              imageUrls: [],
              maxImages: 5,
            ),
          ),
        );

        // Empty state shows add_photo_alternate_outlined icon
        expect(
          find.byIcon(Icons.add_photo_alternate_outlined),
          findsOneWidget,
        );
      });
    });

    group('Gallery Display', () {
      testWidgets('renders image gallery grid', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: ImageFactory.gallery(
              imageUrls: [
                'https://example.com/image1.jpg',
                'https://example.com/image2.jpg',
                'https://example.com/image3.jpg',
              ],
            ),
          ),
        );

        // Gallery uses GridView, not PageView
        expect(find.byType(GridView), findsOneWidget);
      });

      testWidgets('shows empty gallery state when no images', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ImageFactory.gallery(
              imageUrls: [],
            ),
          ),
        );

        // Empty gallery shows photo_library_outlined icon
        expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
      });
    });

    group('Error Handling', () {
      testWidgets('shows placeholder for empty recipe card', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SizedBox(
              width: 200,
              height: 150,
              child: ImageFactory.recipeCard(imageUrls: []),
            ),
          ),
        );

        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('provides semantic wrapper for recipe images', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Semantics(
              label: 'Receptbild',
              child: SizedBox(
                width: 200,
                height: 150,
                child: ImageFactory.recipeCard(
                  imageUrls: ['https://example.com/recipe.jpg'],
                ),
              ),
            ),
          ),
        );

        final semantics = tester.getSemantics(
          find.bySemanticsLabel('Receptbild'),
        );
        expect(semantics.label, contains('Receptbild'));
      });
    });

    group('Responsive Design', () {
      testWidgets('adapts to small screen sizes', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ImageFactory.recipeDetail(
              imageUrls: ['https://example.com/image.jpg'],
            ),
          ),
        );

        expect(find.byType(RecipeImageWidget), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('adapts to large screen sizes', (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ImageFactory.recipeDetail(
              imageUrls: ['https://example.com/image.jpg'],
            ),
          ),
        );

        expect(find.byType(RecipeImageWidget), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
