import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/content_cards/menu_card.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/recipe_unified.dart';

void main() {
  group('MenuCard Tests', () {
    // Test data setup
    late Recipe testRecipe1;
    late Recipe testRecipe2;
    late Recipe testRecipe3;
    late Recipe testRecipe4;
    late Map<String, List<Recipe>> testMenuMap;
    late SharedMenu testSharedMenu;

    setUp(() {
      // Create test recipes
      testRecipe1 = Recipe(
        type: RecipeType.personal,
        core: RecipeCore(
          id: 'recipe1',
          title: 'Köttbullar med potatismos',
          description: 'Klassiska svenska köttbullar',
          mealType: 'middag',
          ingredients: const ['köttfärs', 'potatis', 'smör'],
          instructions: const ['Forma köttbullar', 'Koka potatis', 'Mosa med smör'],
        ),
      );

      testRecipe2 = Recipe(
        type: RecipeType.personal,
        core: RecipeCore(
          id: 'recipe2',
          title: 'Pannkakor',
          description: 'Tunna pannkakor med sylt',
          mealType: 'frukost',
          ingredients: const ['mjöl', 'mjölk', 'ägg'],
          instructions: const ['Blanda smet', 'Stek tunna pannkakor'],
        ),
      );

      testRecipe3 = Recipe(
        type: RecipeType.personal,
        core: RecipeCore(
          id: 'recipe3',
          title: 'Laxsallad',
          description: 'Fräsch sallad med lax',
          mealType: 'lunch',
          ingredients: const ['lax', 'sallad', 'citron'],
          instructions: const ['Grilla lax', 'Blanda sallad'],
        ),
      );

      testRecipe4 = Recipe(
        type: RecipeType.personal,
        core: RecipeCore(
          id: 'recipe4',
          title: 'Chokladmousse',
          description: 'Len chokladmousse',
          mealType: 'efterrätt',
          ingredients: const ['choklad', 'grädde', 'ägg'],
          instructions: const ['Smält choklad', 'Vispa grädde', 'Blanda försiktigt'],
        ),
      );

      // Create test menu map
      testMenuMap = {
        'Måndag': [testRecipe1, testRecipe2],
        'Tisdag': [testRecipe3],
        'Onsdag': [testRecipe4],
      };

      // Create test shared menu
      testSharedMenu = SharedMenu(
        id: 'shared-menu-1',
        menuTitle: 'Veckans meny',
        sharedByUserId: 'user1',
        sharedByDisplayName: 'Anna Andersson',
        sharedToUserIds: const ['user2', 'user3'],
        sharedAt: DateTime.now().subtract(const Duration(days: 2)),
        menuSnapshot: testMenuMap,
      );
    });

    group('Basic Rendering', () {
      testWidgets('renders menu card with title', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: testSharedMenu,
                onTap: () {},
              ),
            ),
          ),
        );

        // Verify menu title is displayed
        expect(find.text('Veckans meny'), findsOneWidget);
        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
      });

      testWidgets('renders menu card with recipe count metadata', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: testSharedMenu,
                onTap: () {},
              ),
            ),
          ),
        );

        // Verify recipe count is displayed with time
        expect(find.textContaining('4 recept'), findsOneWidget);
        expect(find.textContaining('dagar sedan'), findsOneWidget);
      });

      testWidgets('renders menu preview with recipes', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: testSharedMenu,
                onTap: () {},
              ),
            ),
          ),
        );

        // Verify recipe preview section
        expect(find.text('Recept i menyn:'), findsOneWidget);
        expect(find.text('Köttbullar med potatismos'), findsOneWidget);
        expect(find.text('Pannkakor'), findsOneWidget);
        expect(find.text('Laxsallad'), findsOneWidget);
        // With only 4 recipes and showing 3, should show +1 more
        expect(find.textContaining('fler recept'), findsOneWidget);
      });

      testWidgets('hides preview when showPreview is false', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: testSharedMenu,
                onTap: () {},
                showPreview: false,
              ),
            ),
          ),
        );

        // Verify preview is hidden
        expect(find.text('Recept i menyn:'), findsNothing);
        expect(find.text('Köttbullar med potatismos'), findsNothing);
      });

      testWidgets('hides metadata when showMetadata is false', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: testSharedMenu,
                onTap: () {},
                showMetadata: false,
              ),
            ),
          ),
        );

        // Verify metadata is hidden
        expect(find.text('4 recept • 2 dagar sedan'), findsNothing);
      });

      testWidgets('shows sharing status when enabled', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: testSharedMenu,
                onTap: () {},
                showSharingStatus: true,
              ),
            ),
          ),
        );

        // Verify sharing status is shown
        expect(find.text('Delad med 2 personer'), findsOneWidget);
        expect(find.byIcon(Icons.people), findsOneWidget);
      });

      testWidgets('renders empty menu correctly', (WidgetTester tester) async {
        final emptyMenu = SharedMenu(
          id: 'empty-menu',
          menuTitle: 'Tom meny',
          sharedByUserId: 'user1',
          sharedByDisplayName: 'Test User',
          sharedToUserIds: const [],
          sharedAt: DateTime.now(),
          menuSnapshot: const {},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: emptyMenu,
                onTap: () {},
              ),
            ),
          ),
        );

        // Verify empty state
        expect(find.text('Tom meny'), findsOneWidget);
        expect(find.text('Inga recept i menyn'), findsOneWidget);
      });
    });

    group('Menu Card Styles', () {
      testWidgets('renders detailed style correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: testSharedMenu,
                onTap: () {},
                style: MenuCardStyle.detailed,
              ),
            ),
          ),
        );

        // Detailed style should show all information
        expect(find.text('Veckans meny'), findsOneWidget);
        expect(find.text('4 recept • 2 dagar sedan'), findsOneWidget);
        expect(find.text('Recept i menyn:'), findsOneWidget);
      });

      testWidgets('renders compact style correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: testSharedMenu,
                onTap: () {},
                style: MenuCardStyle.compact,
                showSharingStatus: true,
              ),
            ),
          ),
        );

        // Compact style should show limited information
        expect(find.text('Veckans meny'), findsOneWidget);
        expect(find.text('4 recept • 2 dagar sedan'), findsOneWidget);
        // Preview should not be shown in compact mode
        expect(find.text('Recept i menyn:'), findsNothing);
      });

      testWidgets('renders grid style correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: testSharedMenu,
                onTap: () {},
                style: MenuCardStyle.grid,
              ),
            ),
          ),
        );

        // Grid style optimized for grid layout
        expect(find.text('Veckans meny'), findsOneWidget);
        expect(find.text('4 recept • 2 dagar sedan'), findsOneWidget);
        // Preview not shown in grid mode
        expect(find.text('Recept i menyn:'), findsNothing);
      });
    });

    group('User Interactions', () {
      testWidgets('handles tap callback', (WidgetTester tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: testSharedMenu,
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        );

        // Tap the card
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });

      testWidgets('handles long press callback', (WidgetTester tester) async {
        bool longPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: testSharedMenu,
                onTap: () {},
                onLongPress: () {
                  longPressed = true;
                },
              ),
            ),
          ),
        );

        // Long press the card
        await tester.longPress(find.byType(InkWell));
        await tester.pumpAndSettle();

        expect(longPressed, isTrue);
      });
    });

    group('Different Menu Types', () {
      testWidgets('handles Map<String, List<Recipe>> menu type', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: testMenuMap,
                onTap: () {},
              ),
            ),
          ),
        );

        // Should show generated menu title
        expect(find.text('Generated Menu'), findsOneWidget);
        expect(find.text('4 recept'), findsOneWidget);
      });

      testWidgets('handles SharedMenu type', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: testSharedMenu,
                onTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('Veckans meny'), findsOneWidget);
      });
    });

    group('Custom Styling', () {
      testWidgets('applies custom margin', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: testSharedMenu,
                onTap: () {},
                margin: const EdgeInsets.all(20),
              ),
            ),
          ),
        );

        // Find the container with margin
        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        expect(container.margin, const EdgeInsets.all(20));
      });

      testWidgets('applies custom padding', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: testSharedMenu,
                onTap: () {},
                padding: const EdgeInsets.all(30),
              ),
            ),
          ),
        );

        // Find the container with padding
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(InkWell),
            matching: find.byType(Container),
          ).first,
        );
        expect(container.padding, const EdgeInsets.all(30));
      });
    });

    group('Edge Cases', () {
      testWidgets('handles menu with many recipes', (WidgetTester tester) async {
        final largeMenu = SharedMenu(
          id: 'large-menu',
          menuTitle: 'Stor meny',
          sharedByUserId: 'user1',
          sharedByDisplayName: 'Test User',
          sharedToUserIds: const [],
          sharedAt: DateTime.now(),
          menuSnapshot: {
            'Day1': [testRecipe1, testRecipe2],
            'Day2': [testRecipe3, testRecipe4],
            'Day3': [testRecipe1, testRecipe2],
            'Day4': [testRecipe3, testRecipe4],
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: largeMenu,
                onTap: () {},
              ),
            ),
          ),
        );

        // Should show only first 3 recipes of 8 total
        expect(find.textContaining('fler recept'), findsOneWidget);
      });

      testWidgets('handles menu with no sharing', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: testSharedMenu,
                onTap: () {},
                showSharingStatus: true,
              ),
            ),
          ),
        );

        // SharedMenu is always considered shared
        expect(find.text('Delad med 2 personer'), findsOneWidget);
      });

      testWidgets('handles null callbacks gracefully', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: testSharedMenu,
              ),
            ),
          ),
        );

        // Should render without callbacks
        expect(find.text('Veckans meny'), findsOneWidget);

        // Tapping should not cause errors
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();
      });

      testWidgets('handles menu with special characters', (WidgetTester tester) async {
        final specialMenu = SharedMenu(
          id: 'special-menu',
          menuTitle: 'Årets bästa räksmörgås & öl',
          sharedByUserId: 'user1',
          sharedByDisplayName: 'Örjan Åkesson',
          sharedToUserIds: const [],
          sharedAt: DateTime.now(),
          menuSnapshot: const {},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: specialMenu,
                onTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('Årets bästa räksmörgås & öl'), findsOneWidget);
      });
    });

    group('Swedish Localization', () {
      testWidgets('displays all Swedish text correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: testSharedMenu,
                onTap: () {},
                showSharingStatus: true,
              ),
            ),
          ),
        );

        // Check Swedish text
        expect(find.textContaining('4 recept'), findsOneWidget);
        expect(find.text('Recept i menyn:'), findsOneWidget);
        expect(find.textContaining('fler recept'), findsOneWidget);
        expect(find.text('Delad med 2 personer'), findsOneWidget);
      });

      testWidgets('displays Swedish empty state', (WidgetTester tester) async {
        final emptyMenu = SharedMenu(
          id: 'empty',
          menuTitle: 'Tom',
          sharedByUserId: 'user1',
          sharedByDisplayName: 'Test',
          sharedToUserIds: const [],
          sharedAt: DateTime.now(),
          menuSnapshot: const {},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuCard(
                menu: emptyMenu,
                onTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('Inga recept i menyn'), findsOneWidget);
      });
    });
  });
}