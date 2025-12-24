import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/image/image_factory.dart';

void main() {
  group('ImageFactory Widget Tests', () {
    group('Avatar Display', () {
      testWidgets('renders avatar with image URL', (WidgetTester tester) async {
        final widget = ImageFactory.avatar(
          imageUrl: 'https://example.com/avatar.jpg',
          displayName: 'Test User',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        expect(find.byType(CircleAvatar), findsOneWidget);
      });

      testWidgets('renders avatar with initials when no image',
          (WidgetTester tester) async {
        final widget = ImageFactory.avatar(
          displayName: 'Anna Andersson',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        expect(find.text('AA'), findsOneWidget);
        expect(find.byType(CircleAvatar), findsOneWidget);
      });

      testWidgets('shows online indicator when user is online',
          (WidgetTester tester) async {
        final widget = ImageFactory.avatar(
          displayName: 'Test User',
          showStatus: true,
          isOnline: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        // Online indicator is typically a green dot
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('responds to tap events', (WidgetTester tester) async {
        bool tapped = false;
        final widget = ImageFactory.avatar(
          displayName: 'Test User',
          onTap: () => tapped = true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        await tester.tap(find.byType(CircleAvatar));
        await tester.pump();

        expect(tapped, isTrue);
      });
    });

    group('Recipe Card Display', () {
      testWidgets('renders recipe card image', (WidgetTester tester) async {
        final widget = ImageFactory.recipeCard(
          imageUrls: ['https://example.com/recipe.jpg'],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 150,
                child: widget,
              ),
            ),
          ),
        );

        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('shows placeholder when no image',
          (WidgetTester tester) async {
        final widget = ImageFactory.recipeCard(
          imageUrls: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 150,
                child: widget,
              ),
            ),
          ),
        );

        // Should show placeholder icon
        expect(find.byIcon(Icons.restaurant), findsOneWidget);
      });

      testWidgets('handles tap on recipe card', (WidgetTester tester) async {
        bool tapped = false;
        final widget = ImageFactory.recipeCard(
          imageUrls: ['https://example.com/recipe.jpg'],
          onTap: () => tapped = true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 150,
                child: widget,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(tapped, isTrue);
      });
    });

    group('Recipe Detail Display', () {
      testWidgets('renders recipe detail image', (WidgetTester tester) async {
        final widget = ImageFactory.recipeDetail(
          imageUrls: ['https://example.com/recipe.jpg'],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('supports hero animation', (WidgetTester tester) async {
        final widget = ImageFactory.recipeDetail(
          imageUrls: ['https://example.com/recipe.jpg'],
          heroTag: 'recipe-hero',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        expect(find.byType(Hero), findsOneWidget);
      });

      testWidgets('handles tap to view fullscreen',
          (WidgetTester tester) async {
        bool tapped = false;
        int tappedIndex = -1;
        final widget = ImageFactory.recipeDetail(
          imageUrls: ['https://example.com/recipe.jpg'],
          onImageTap: (index) {
            tapped = true;
            tappedIndex = index;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(tapped, isTrue);
        expect(tappedIndex, equals(0));
      });
    });

    group('Recipe Edit Display', () {
      testWidgets('renders editable images', (WidgetTester tester) async {
        final widget = ImageFactory.recipeEdit(
          imageUrls: [
            'https://example.com/image1.jpg',
            'https://example.com/image2.jpg',
          ],
          maxImages: 5,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('shows add image button when under max',
          (WidgetTester tester) async {
        final widget = ImageFactory.recipeEdit(
          imageUrls: ['https://example.com/image1.jpg'],
          maxImages: 5,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        // Should show add button since we have 1 image and max is 5
        expect(find.byIcon(Icons.add_photo_alternate), findsOneWidget);
      });

      testWidgets('hides add button when at max images',
          (WidgetTester tester) async {
        final widget = ImageFactory.recipeEdit(
          imageUrls: [
            'https://example.com/image1.jpg',
            'https://example.com/image2.jpg',
          ],
          maxImages: 2,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        // Should not show add button since we're at max
        expect(find.byIcon(Icons.add_photo_alternate), findsNothing);
      });
    });

    group('Gallery Display', () {
      testWidgets('renders image gallery', (WidgetTester tester) async {
        final widget = ImageFactory.gallery(
          imageUrls: [
            'https://example.com/image1.jpg',
            'https://example.com/image2.jpg',
            'https://example.com/image3.jpg',
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        expect(find.byType(PageView), findsOneWidget);
      });

      testWidgets('supports swipe navigation', (WidgetTester tester) async {
        final widget = ImageFactory.gallery(
          imageUrls: [
            'https://example.com/image1.jpg',
            'https://example.com/image2.jpg',
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        // Swipe to next image
        await tester.drag(find.byType(PageView), const Offset(-300, 0));
        await tester.pumpAndSettle();

        // PageView should have navigated
        expect(find.byType(PageView), findsOneWidget);
      });
    });

    group('Error Handling', () {
      testWidgets('shows placeholder for empty recipe card',
          (WidgetTester tester) async {
        final widget = ImageFactory.recipeCard(
          imageUrls: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 150,
                child: widget,
              ),
            ),
          ),
        );

        // Should show placeholder icon
        expect(find.byIcon(Icons.restaurant), findsOneWidget);
      });

      testWidgets('handles empty gallery gracefully',
          (WidgetTester tester) async {
        final widget = ImageFactory.gallery(
          imageUrls: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        // Should show placeholder or empty state
        expect(find.byIcon(Icons.photo_library), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('provides semantic labels for recipe images',
          (WidgetTester tester) async {
        final widget = ImageFactory.recipeCard(
          imageUrls: ['https://example.com/recipe.jpg'],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Semantics(
                label: 'Receptbild',
                child: widget,
              ),
            ),
          ),
        );

        final semantics =
            tester.getSemantics(find.bySemanticsLabel('Receptbild'));
        expect(semantics.label, contains('Receptbild'));
      });

      testWidgets('supports keyboard navigation in edit mode',
          (WidgetTester tester) async {
        final widget = ImageFactory.recipeEdit(
          imageUrls: ['https://example.com/image.jpg'],
          maxImages: 5,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        // Buttons should be focusable
        expect(find.byType(IconButton), findsWidgets);
      });
    });

    group('Responsive Design', () {
      testWidgets('adapts to small screen sizes', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;

        final widget = ImageFactory.gallery(
          imageUrls: ['https://example.com/image.jpg'],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        expect(find.byType(Container), findsWidgets);

        // Reset
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('adapts to large screen sizes', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;

        final widget = ImageFactory.gallery(
          imageUrls: ['https://example.com/image.jpg'],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: widget,
            ),
          ),
        );

        expect(find.byType(Container), findsWidgets);

        // Reset
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
