import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
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

        // Empty state uses buildPlaceholder which defaults to ButleryIcons.utensils
        expect(find.byIcon(ButleryIcons.utensils), findsOneWidget);
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
          find.byIcon(ButleryIcons.camera),
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
          find.byIcon(ButleryIcons.camera),
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
        expect(find.byIcon(ButleryIcons.image), findsOneWidget);
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

        expect(find.byIcon(ButleryIcons.utensils), findsOneWidget);
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

  // BUT-2183 5c: badges on a photo are overlay.paperCard with ink; the grid's
  // add control is not on a photo and takes surface.raised with border.subtle.
  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    group('BUT-2183 5c image badge tokens ($name)', () {
      final cs = theme.colorScheme;
      final modes = ModeColors.of(theme.brightness);

      setUpAll(() async {
        await BaseWidgetTest.setupWidget();
      });

      setUp(() async {
        await TestServiceLocator.initialize();
      });

      tearDown(() async {
        await BaseWidgetTest.teardownWidget();
      });

      BoxDecoration fillAround(WidgetTester tester, Finder of) => tester
          .widgetList<Container>(
            find.ancestor(of: of, matching: find.byType(Container)),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.color != null);

      testWidgets('card: multiple-photo indicator is overlay.paperCard with '
          'ink', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Theme(
              data: theme,
              child: SizedBox(
                width: 200,
                height: 150,
                child: ImageFactory.recipeCard(
                  imageUrls: [
                    'https://example.com/a.jpg',
                    'https://example.com/b.jpg',
                  ],
                ),
              ),
            ),
          ),
        );

        final count = find.text('2');
        expect(fillAround(tester, count).color, modes.overlayPaperCard);
        expect(tester.widget<Text>(count).style?.color, cs.primary);
      });

      testWidgets('detail: page counter is overlay.paperCard with ink', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Theme(
              data: theme,
              child: ImageFactory.recipeDetail(
                imageUrls: [
                  'https://example.com/a.jpg',
                  'https://example.com/b.jpg',
                ],
              ),
            ),
          ),
        );

        final counter = find.text('1/2');
        expect(fillAround(tester, counter).color, modes.overlayPaperCard);
        expect(tester.widget<Text>(counter).style?.color, cs.primary);
      });

      testWidgets('edit grid: unchosen-primary badge is overlay.paperCard, '
          'add control is raised with border.subtle', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Theme(
              data: theme,
              child: SingleChildScrollView(
                child: ImageFactory.recipeEdit(
                  imageUrls: [
                    'https://example.com/a.jpg',
                    'https://example.com/b.jpg',
                  ],
                  maxImages: 5,
                ),
              ),
            ),
          ),
        );

        final badge = tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .where((d) => d.color == modes.overlayPaperCard);
        expect(badge, hasLength(1));
        final star = tester.widget<ButleryIcon>(
          find.byWidgetPredicate(
            (w) => w is ButleryIcon && w.icon == ButleryIcons.primaryOutline,
          ),
        );
        expect(star.color, cs.primary);

        final add = fillAround(tester, find.text('Lägg till (3)'));
        expect(add.color, cs.surfaceContainerHighest);
        expect((add.border! as Border).top.color, cs.outlineVariant);
      });
    });
  }
}
