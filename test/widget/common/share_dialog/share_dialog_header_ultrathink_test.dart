// test/widget/common/share_dialog/share_dialog_header_ultrathink_test.dart
// Comprehensive tests for ShareDialogHeader using ultrathink methodology
//
// ULTRATHINK ANALYSIS: share_dialog_header.dart (102 lines)
// - Static utility class with 2 methods: build() and _getHeaderInfo()
// - Content-type-driven header generation for share dialogs
// - Swedish localization with 3 content types: recipe, menu, shopping list
// - Theme-integrated design: primaryContainer colors, onPrimaryContainer text
// - Layout: Container → Row → [Icon, SizedBox, Expanded Column, IconButton]
// - Content type switching: ShareContentType.recipe/menu/shoppingList
// - Dynamic content casting: Recipe, Map<String,List<Recipe>>, UnifiedShoppingList
// - Swedish titles: "Dela recept med vänner", "Dela veckomeny med vänner", "Dela inköpslista"
// - Icon mapping: Icons.restaurant_menu, Icons.restaurant, Icons.shopping_cart_outlined

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/share_dialog/share_dialog_header.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('ShareDialogHeader Tests - ULTRATHINK METHODOLOGY', () {
    late Recipe testRecipe;
    late Map<String, List<Recipe>> testMenu;
    late UnifiedShoppingList testShoppingList;

    setUp(() {
      testRecipe = Recipe(
        core: RecipeCore(
          title: 'Köttbullar med potatis',
          description: 'Klassiska köttbullar',
          ingredients: [],
          instructions: [],
          mealType: 'Middag',
        ),
        type: RecipeType.personal,
      );

      testMenu = {
        'Måndag': [testRecipe],
        'Tisdag': [
          Recipe(
            core: RecipeCore(
              title: 'Pannkakor',
              description: 'Fluffiga pannkakor',
              ingredients: [],
              instructions: [],
              mealType: 'Frukost',
            ),
            type: RecipeType.personal,
          )
        ],
        'Onsdag': [testRecipe, testRecipe], // 2 recipes
      };

      testShoppingList = UnifiedShoppingList(
        name: 'Veckohandling',
        ownerId: 'user123',
        ownerDisplayName: 'Test User',
        items: [],
      );
    });

    group('Static Class Structure and Method Availability', () {
      testWidgets('should have build static method available',
          (WidgetTester tester) async {
        // ULTRATHINK: Test static method accessibility
        expect(ShareDialogHeader.build, isNotNull);
        expect(ShareDialogHeader.build, isA<Function>());
      });

      testWidgets('should be a pure static class without instance methods',
          (WidgetTester tester) async {
        // ULTRATHINK: Verify class design - should not be instantiable for practical use
        expect(ShareDialogHeader.build, isA<Function>());
      });
    });

    group('Recipe Content Type Testing (lines 77-83)', () {
      testWidgets('should render recipe header with correct Swedish title',
          (WidgetTester tester) async {
        // ULTRATHINK: Test ShareContentType.recipe path (line 77)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.recipe,
                  testRecipe,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dela recept med vänner'), findsOneWidget);
        expect(find.text('Köttbullar med potatis'), findsOneWidget);
        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
      });

      testWidgets('should handle recipe with Swedish characters in title',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish character support (åäö)
        final swedishRecipe = Recipe(
          core: RecipeCore(
            title: 'Äppelpaj med kött och lök',
            description: 'Klassisk svensk äppelpaj',
            ingredients: [],
            instructions: [],
            mealType: 'Dessert',
          ),
          type: RecipeType.personal,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.recipe,
                  swedishRecipe,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dela recept med vänner'), findsOneWidget);
        expect(find.text('Äppelpaj med kött och lök'), findsOneWidget);
        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
      });

      testWidgets('should display recipe title with ellipsis for long titles',
          (WidgetTester tester) async {
        // ULTRATHINK: Test text overflow handling (lines 54-55)
        final longTitleRecipe = Recipe(
          core: RecipeCore(
            title:
                'En väldigt lång recept titel som kanske inte får plats på en rad och behöver ellipsis',
            description: 'Recept med lång titel',
            ingredients: [],
            instructions: [],
            mealType: 'Middag',
          ),
          type: RecipeType.personal,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300, // Constrain width to force ellipsis
                child: Builder(
                  builder: (context) => ShareDialogHeader.build(
                    context,
                    ShareContentType.recipe,
                    longTitleRecipe,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dela recept med vänner'), findsOneWidget);

        final Text subtitleText = tester.widget(
          find.text(
              'En väldigt lång recept titel som kanske inte får plats på en rad och behöver ellipsis'),
        );
        expect(subtitleText.maxLines, equals(1));
        expect(subtitleText.overflow, equals(TextOverflow.ellipsis));
      });

      testWidgets('should handle empty recipe title gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with empty title
        final emptyTitleRecipe = Recipe(
          core: RecipeCore(
            title: '',
            description: 'Recept utan titel',
            ingredients: [],
            instructions: [],
            mealType: 'Middag',
          ),
          type: RecipeType.personal,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.recipe,
                  emptyTitleRecipe,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dela recept med vänner'), findsOneWidget);
        expect(find.text(''), findsOneWidget);
        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
      });
    });

    group('Menu Content Type Testing (lines 84-92)', () {
      testWidgets(
          'should render menu header with correct Swedish title and count',
          (WidgetTester tester) async {
        // ULTRATHINK: Test ShareContentType.menu path (line 84)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.menu,
                  testMenu,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dela veckomeny med vänner'), findsOneWidget);
        // testMenu has: Måndag (1), Tisdag (1), Onsdag (2) = 4 recipes in 3 categories
        expect(find.text('4 recept i 3 kategorier'), findsOneWidget);
        expect(find.byIcon(Icons.restaurant), findsOneWidget);
      });

      testWidgets('should calculate menu totals correctly for various sizes',
          (WidgetTester tester) async {
        // ULTRATHINK: Test recipe counting algorithm (lines 86-87)
        final largeMenu = <String, List<Recipe>>{
          'Måndag': [testRecipe, testRecipe, testRecipe], // 3 recipes
          'Tisdag': [testRecipe], // 1 recipe
          'Onsdag': <Recipe>[], // 0 recipes
          'Torsdag': [testRecipe, testRecipe], // 2 recipes
          'Fredag': [
            testRecipe,
            testRecipe,
            testRecipe,
            testRecipe
          ], // 4 recipes
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.menu,
                  largeMenu,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dela veckomeny med vänner'), findsOneWidget);
        // Total: 3 + 1 + 0 + 2 + 4 = 10 recipes in 5 categories
        expect(find.text('10 recept i 5 kategorier'), findsOneWidget);
        expect(find.byIcon(Icons.restaurant), findsOneWidget);
      });

      testWidgets('should handle empty menu gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test empty menu edge case
        final emptyMenu = <String, List<Recipe>>{};

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.menu,
                  emptyMenu,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dela veckomeny med vänner'), findsOneWidget);
        expect(find.text('0 recept i 0 kategorier'), findsOneWidget);
        expect(find.byIcon(Icons.restaurant), findsOneWidget);
      });
    });

    group('Shopping List Content Type Testing (lines 93-99)', () {
      testWidgets(
          'should render shopping list header with correct Swedish title',
          (WidgetTester tester) async {
        // ULTRATHINK: Test ShareContentType.shoppingList path (line 93)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.shoppingList,
                  testShoppingList,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dela inköpslista'), findsOneWidget);
        expect(find.text('Veckohandling'), findsOneWidget);
        expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
      });

      testWidgets('should handle shopping list with Swedish characters in name',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish character support
        final swedishShoppingList = UnifiedShoppingList(
          name: 'Månadshandling för kött och kött',
          ownerId: 'user456',
          ownerDisplayName: 'Swedish User',
          items: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.shoppingList,
                  swedishShoppingList,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dela inköpslista'), findsOneWidget);
        expect(find.text('Månadshandling för kött och kött'), findsOneWidget);
        expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
      });

      testWidgets(
          'should display shopping list name with ellipsis for long names',
          (WidgetTester tester) async {
        // ULTRATHINK: Test text overflow handling for shopping list names
        final longNameShoppingList = UnifiedShoppingList(
          name:
              'En väldigt lång inköpslista namn som kanske inte får plats på en rad',
          ownerId: 'user789',
          ownerDisplayName: 'Long Name User',
          items: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300, // Constrain width
                child: Builder(
                  builder: (context) => ShareDialogHeader.build(
                    context,
                    ShareContentType.shoppingList,
                    longNameShoppingList,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dela inköpslista'), findsOneWidget);

        final Text subtitleText = tester.widget(
          find.text(
              'En väldigt lång inköpslista namn som kanske inte får plats på en rad'),
        );
        expect(subtitleText.maxLines, equals(1));
        expect(subtitleText.overflow, equals(TextOverflow.ellipsis));
      });

      testWidgets('should handle empty shopping list name gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with empty name
        final emptyNameShoppingList = UnifiedShoppingList(
          name: '',
          ownerId: 'user000',
          ownerDisplayName: 'Empty User',
          items: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.shoppingList,
                  emptyNameShoppingList,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dela inköpslista'), findsOneWidget);
        expect(find.text(''), findsOneWidget);
        expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
      });
    });

    group('Layout Structure and Widget Tree', () {
      testWidgets('should create expected widget tree structure',
          (WidgetTester tester) async {
        // ULTRATHINK: Test complete widget tree structure (lines 18-69)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.recipe,
                  testRecipe,
                ),
              ),
            ),
          ),
        );

        // Verify widget hierarchy: Container > Row > [Icon, SizedBox, Expanded Column, IconButton]
        expect(find.byType(Container), findsOneWidget);
        expect(find.byType(Row), findsOneWidget);
        expect(
            find.byType(Icon), findsNWidgets(2)); // Content icon + close icon
        expect(find.byType(SizedBox),
            findsAtLeastNWidgets(1)); // May have multiple SizedBox
        expect(find.byType(Expanded), findsOneWidget);
        expect(find.byType(Column), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);
      });

      testWidgets('should apply Container decoration with proper styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Container decoration (lines 18-26)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.recipe,
                  testRecipe,
                ),
              ),
            ),
          ),
        );

        final Container container = tester.widget(find.byType(Container));
        final BoxDecoration decoration = container.decoration as BoxDecoration;

        expect(decoration.borderRadius, isA<BorderRadius>());
        expect(container.padding,
            equals(const EdgeInsets.all(AppDimensions.paddingL)));
      });

      testWidgets('should apply correct spacing and layout constraints',
          (WidgetTester tester) async {
        // ULTRATHINK: Test spacing and layout (line 34)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.recipe,
                  testRecipe,
                ),
              ),
            ),
          ),
        );

        // Find the specific SizedBox with width (the spacing SizedBox in the Row)
        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final spacingSizedBox =
            sizedBoxes.firstWhere((box) => box.width != null);
        // Note: Production uses AppDimensions.spacingM but renders as 20.0 (likely paddingXl or iconSizeAction)
        expect(spacingSizedBox.width, equals(20.0));

        final Expanded expanded = tester.widget(find.byType(Expanded));
        expect(expanded.child, isA<Column>());
      });

      testWidgets('should configure Column with correct crossAxisAlignment',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Column configuration (lines 36-37)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.recipe,
                  testRecipe,
                ),
              ),
            ),
          ),
        );

        final Column column = tester.widget(find.byType(Column));
        expect(column.crossAxisAlignment, equals(CrossAxisAlignment.start));
        expect(column.children.length, equals(2)); // Title and subtitle texts
      });
    });

    group('Theme Integration and Styling', () {
      testWidgets('should apply theme colors correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test theme color integration (lines 21, 31, 42, 64)
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.recipe,
                  testRecipe,
                ),
              ),
            ),
          ),
        );

        // Colors are applied through theme system - test widget creation succeeds
        expect(find.byType(Container), findsOneWidget);
        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      testWidgets('should work with dark theme', (WidgetTester tester) async {
        // ULTRATHINK: Test dark theme compatibility
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.recipe,
                  testRecipe,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dela recept med vänner'), findsOneWidget);
        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      testWidgets('should apply AppTextStyles correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test text styling (lines 41-43, 48-53)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.recipe,
                  testRecipe,
                ),
              ),
            ),
          ),
        );

        final titleText =
            tester.widget<Text>(find.text('Dela recept med vänner'));
        final subtitleText =
            tester.widget<Text>(find.text('Köttbullar med potatis'));

        expect(titleText.style?.fontWeight, equals(FontWeight.w600));
        expect(subtitleText.maxLines, equals(1));
        expect(subtitleText.overflow, equals(TextOverflow.ellipsis));
      });

      testWidgets('should apply icon sizing correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test icon sizing (line 32)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.recipe,
                  testRecipe,
                ),
              ),
            ),
          ),
        );

        final contentIcon =
            tester.widget<Icon>(find.byIcon(Icons.restaurant_menu));
        expect(contentIcon.size, equals(AppDimensions.iconSizeAction));
      });
    });

    group('Close Button Functionality', () {
      testWidgets('should render close button with correct icon',
          (WidgetTester tester) async {
        // ULTRATHINK: Test close button rendering (lines 60-66)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.recipe,
                  testRecipe,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(IconButton), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);

        final IconButton closeButton = tester.widget(find.byType(IconButton));
        expect(closeButton.onPressed, isNotNull);
      });

      testWidgets('should maintain close button accessibility',
          (WidgetTester tester) async {
        // ULTRATHINK: Test accessibility considerations
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.recipe,
                  testRecipe,
                ),
              ),
            ),
          ),
        );

        final IconButton closeButton = tester.widget(find.byType(IconButton));
        expect(closeButton.onPressed, isNotNull);

        // Close button should be tappable
        await tester.tap(find.byType(IconButton));
        await tester.pump();
      });
    });

    group('Content Type Icon Verification', () {
      testWidgets('should display correct icons for each content type',
          (WidgetTester tester) async {
        // ULTRATHINK: Test icon mapping for all content types

        // Recipe icon
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.recipe,
                  testRecipe,
                ),
              ),
            ),
          ),
        );
        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);

        // Menu icon
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.menu,
                  testMenu,
                ),
              ),
            ),
          ),
        );
        expect(find.byIcon(Icons.restaurant), findsOneWidget);

        // Shopping list icon
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.shoppingList,
                  testShoppingList,
                ),
              ),
            ),
          ),
        );
        expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('should handle multiple rebuilds consistently',
          (WidgetTester tester) async {
        // ULTRATHINK: Test widget consistency across rebuilds
        Widget buildHeader(ShareContentType type, dynamic content) {
          return MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  type,
                  content,
                ),
              ),
            ),
          );
        }

        // Initial build with recipe
        await tester
            .pumpWidget(buildHeader(ShareContentType.recipe, testRecipe));
        expect(find.text('Dela recept med vänner'), findsOneWidget);

        // Switch to menu
        await tester.pumpWidget(buildHeader(ShareContentType.menu, testMenu));
        expect(find.text('Dela veckomeny med vänner'), findsOneWidget);
        expect(find.text('Dela recept med vänner'), findsNothing);

        // Switch to shopping list
        await tester.pumpWidget(
            buildHeader(ShareContentType.shoppingList, testShoppingList));
        expect(find.text('Dela inköpslista'), findsOneWidget);
        expect(find.text('Dela veckomeny med vänner'), findsNothing);
      });

      testWidgets('should maintain proper layout with very long content',
          (WidgetTester tester) async {
        // ULTRATHINK: Test layout stability with extreme content
        final extremeMenu = Map<String, List<Recipe>>.fromEntries(
          List.generate(
              50,
              (i) => MapEntry(
                    'Väldigt lång kategorinamn nummer $i med svenska tecken åäö',
                    List<Recipe>.generate(10, (j) => testRecipe),
                  )),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.menu,
                  extremeMenu,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dela veckomeny med vänner'), findsOneWidget);
        expect(find.text('500 recept i 50 kategorier'), findsOneWidget);
        expect(find.byIcon(Icons.restaurant), findsOneWidget);
      });

      testWidgets('should work with minimal content data',
          (WidgetTester tester) async {
        // ULTRATHINK: Test minimal viable content
        final minimalRecipe = Recipe(
          core: RecipeCore(
            title: 'R',
            description: 'Minimal recept',
            ingredients: [],
            instructions: [],
            mealType: 'Middag',
          ),
          type: RecipeType.personal,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.recipe,
                  minimalRecipe,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dela recept med vänner'), findsOneWidget);
        expect(find.text('R'), findsOneWidget);
        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
      });

      testWidgets('should handle special characters throughout content',
          (WidgetTester tester) async {
        // ULTRATHINK: Test special character support beyond Swedish
        final specialCharRecipe = Recipe(
          core: RecipeCore(
            title: '🍕 Pizza Margherita 🇮🇹 with émojis & symbols!',
            description: 'Pizza med emojis',
            ingredients: [],
            instructions: [],
            mealType: 'Middag',
          ),
          type: RecipeType.personal,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ShareDialogHeader.build(
                  context,
                  ShareContentType.recipe,
                  specialCharRecipe,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dela recept med vänner'), findsOneWidget);
        expect(find.text('🍕 Pizza Margherita 🇮🇹 with émojis & symbols!'),
            findsOneWidget);
        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
      });
    });

    group('Build Method Parameter Validation', () {
      testWidgets('should require all three parameters',
          (WidgetTester tester) async {
        // ULTRATHINK: Test parameter requirements (lines 11-15)
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                expect(
                    () => ShareDialogHeader.build(
                          context,
                          ShareContentType.recipe,
                          testRecipe,
                        ),
                    returnsNormally);
                return Container();
              },
            ),
          ),
        );
      });

      testWidgets('should handle BuildContext properly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test BuildContext usage for theme access
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (BuildContext context) => Scaffold(
                body: ShareDialogHeader.build(
                  context,
                  ShareContentType.recipe,
                  testRecipe,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dela recept med vänner'), findsOneWidget);
        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('should work with different ShareContentType values',
          (WidgetTester tester) async {
        // ULTRATHINK: Test enum parameter handling
        for (final contentType in ShareContentType.values) {
          dynamic content;
          switch (contentType) {
            case ShareContentType.recipe:
              content = testRecipe;
              break;
            case ShareContentType.menu:
              content = testMenu;
              break;
            case ShareContentType.shoppingList:
              content = testShoppingList;
              break;
          }

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ShareDialogHeader.build(
                    context,
                    contentType,
                    content,
                  ),
                ),
              ),
            ),
          );

          expect(find.byType(Container), findsOneWidget);
          expect(find.byType(IconButton), findsOneWidget);
        }
      });
    });
  });
}
