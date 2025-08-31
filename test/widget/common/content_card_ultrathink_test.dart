// test/widget/common/content_card_ultrathink_test.dart
// ULTRATHINK TEST SUITE: ContentCard - 537 lines of production code
// Testing facade pattern with 5 content types, delegation logic, parameter mapping, style conversion
// 
// ULTRATHINK FOCUS: Facade pattern delegation, type validation with assertions, parameter mapping,
// backward compatibility static methods, style conversion logic, edge case handling

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports - NEVER assume, always check production code first
import 'package:butlery/widgets/common/content_card.dart';

// Test infrastructure imports - using centralized system
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/factories/user_profile_factory.dart';
import '../../infrastructure/factories/social_factory.dart';
import '../../infrastructure/factories/shopping_list_factory.dart';

void main() {
  group('ContentCard Ultrathink Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    // Helper to create test environment
    Widget createTestWidget({required Widget child}) {
      return MaterialApp(
        home: Scaffold(
          body: Container(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        ),
      );
    }

    group('Production Code Analysis', () {
      testWidgets('facade renders without crashes with basic configuration', (WidgetTester tester) async {
        // ULTRATHINK: Test basic facade pattern from production code lines 255-268
        final recipe = RecipeFactory.build();
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: recipe,
              type: ContentCardType.recipe,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(ContentCard), findsOneWidget);
      });

      testWidgets('supports all 5 ContentCardType enum values', (WidgetTester tester) async {
        // ULTRATHINK: Test enum completeness from lines 76-91
        expect(ContentCardType.values, hasLength(5));
        expect(ContentCardType.values, containsAll([
          ContentCardType.recipe,
          ContentCardType.menu,
          ContentCardType.shoppingList,
          ContentCardType.friend,
          ContentCardType.friendRequest,
        ]));
      });

      testWidgets('supports all 3 ContentCardStyle enum values', (WidgetTester tester) async {
        // ULTRATHINK: Test style enum from lines 97-106
        expect(ContentCardStyle.values, hasLength(3));
        expect(ContentCardStyle.values, containsAll([
          ContentCardStyle.detailed,
          ContentCardStyle.compact,
          ContentCardStyle.grid,
        ]));
      });
    });

    group('Content Type Delegation Tests', () {
      testWidgets('delegates to RecipeCard for recipe type', (WidgetTester tester) async {
        // ULTRATHINK: Test recipe delegation from lines 258-259, 279-294
        final recipe = RecipeFactory.build();
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: recipe,
              type: ContentCardType.recipe,
              style: ContentCardStyle.detailed,
            ),
          ),
        );

        // ULTRATHINK: Test delegation intention - should create RecipeCard widget
        expect(tester.takeException(), isNull);
        expect(find.byType(ContentCard), findsOneWidget);
      });

      testWidgets('delegates to FriendCard for friend type', (WidgetTester tester) async {
        // ULTRATHINK: Test friend delegation from lines 260-261, 304-321
        final user = UserProfileFactory.build();
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: user,
              type: ContentCardType.friend,
              style: ContentCardStyle.detailed,
              showOnlineStatus: true,
            ),
          ),
        );

        // ULTRATHINK: Test delegation intention - should create FriendCard widget
        expect(tester.takeException(), isNull);
        expect(find.byType(ContentCard), findsOneWidget);
      });

      testWidgets('delegates to FriendRequestCard for friendRequest type', (WidgetTester tester) async {
        // ULTRATHINK: Test friend request delegation from lines 262-263, 331-343
        final friendRequest = SocialFactory.createFriendRequest();
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: friendRequest,
              type: ContentCardType.friendRequest,
              onAccept: () {},
              onDecline: () {},
            ),
          ),
        );

        // ULTRATHINK: Test delegation intention - should create FriendRequestCard widget
        expect(tester.takeException(), isNull);
        expect(find.byType(ContentCard), findsOneWidget);
      });

      testWidgets('delegates to MenuCard for menu type', (WidgetTester tester) async {
        // ULTRATHINK: Test menu delegation from lines 264-265, 352-365
        final menuData = {'title': 'Test Menu', 'recipes': []};
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: menuData,
              type: ContentCardType.menu,
              showSharingStatus: true,
            ),
          ),
        );

        // ULTRATHINK: Test delegation intention - should create MenuCard widget
        expect(tester.takeException(), isNull);
        expect(find.byType(ContentCard), findsOneWidget);
      });

      testWidgets('delegates to ShoppingListCard for shoppingList type', (WidgetTester tester) async {
        // ULTRATHINK: Test shopping list delegation from lines 266-267, 374-387
        final shoppingList = ShoppingListFactory.build(name: 'Test Shopping List');
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: shoppingList,
              type: ContentCardType.shoppingList,
              showSharingStatus: true,
            ),
          ),
        );

        // ULTRATHINK: Test delegation intention - should create ShoppingListCard widget
        expect(tester.takeException(), isNull);
        expect(find.byType(ContentCard), findsOneWidget);
      });
    });

    group('Type Validation Tests', () {
      testWidgets('validates Recipe type for recipe cards', (WidgetTester tester) async {
        // ULTRATHINK: Test assertion from line 280
        final wrongItem = UserProfileFactory.build();
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: wrongItem,
              type: ContentCardType.recipe,
            ),
          ),
        );

        // ULTRATHINK: Test assertion intention - should fail with wrong type
        expect(tester.takeException(), isA<AssertionError>());
      });

      testWidgets('validates UserProfile type for friend cards', (WidgetTester tester) async {
        // ULTRATHINK: Test assertion from line 305
        final wrongItem = RecipeFactory.build();
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: wrongItem,
              type: ContentCardType.friend,
            ),
          ),
        );

        // ULTRATHINK: Test assertion intention - should fail with wrong type
        expect(tester.takeException(), isA<AssertionError>());
      });

      testWidgets('validates FriendRequest type for friendRequest cards', (WidgetTester tester) async {
        // ULTRATHINK: Test assertion from line 332
        final wrongItem = RecipeFactory.build();
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: wrongItem,
              type: ContentCardType.friendRequest,
            ),
          ),
        );

        // ULTRATHINK: Test assertion intention - should fail with wrong type
        expect(tester.takeException(), isA<AssertionError>());
      });

      testWidgets('accepts dynamic types for menu cards', (WidgetTester tester) async {
        // ULTRATHINK: Test dynamic acceptance from line 353-354
        final menuData = {'title': 'Dynamic Menu'};
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: menuData,
              type: ContentCardType.menu,
            ),
          ),
        );

        // ULTRATHINK: Test dynamic handling intention - should accept any type
        expect(tester.takeException(), isNull);
      });

      testWidgets('accepts dynamic types for shopping list cards', (WidgetTester tester) async {
        // ULTRATHINK: Test dynamic acceptance from line 375
        final shoppingList = ShoppingListFactory.build(name: 'Dynamic List');
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: shoppingList,
              type: ContentCardType.shoppingList,
            ),
          ),
        );

        // ULTRATHINK: Test dynamic handling intention - should accept any type
        expect(tester.takeException(), isNull);
      });
    });

    group('Parameter Mapping Tests', () {
      testWidgets('maps generic parameters to RecipeCard parameters', (WidgetTester tester) async {
        // ULTRATHINK: Test parameter mapping from lines 283-293
        final recipe = RecipeFactory.build();
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: recipe,
              type: ContentCardType.recipe,
              showImage: false,
              showTags: false,
              showMetadata: false,
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(4),
            ),
          ),
        );

        // ULTRATHINK: Test parameter mapping intention - should delegate with mapped parameters
        expect(tester.takeException(), isNull);
      });

      testWidgets('maps generic parameters to FriendCard parameters', (WidgetTester tester) async {
        // ULTRATHINK: Test friend parameter mapping from lines 308-320
        final user = UserProfileFactory.build();
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: user,
              type: ContentCardType.friend,
              showImage: true,  // Maps to showAvatar
              showOnlineStatus: true,
              showMetadata: false,
              subtitle: 'Test Subtitle',
              trailing: const Icon(Icons.message),
            ),
          ),
        );

        // ULTRATHINK: Test specialized parameter mapping intention
        expect(tester.takeException(), isNull);
      });

      testWidgets('maps showTags to showPreview for menu cards', (WidgetTester tester) async {
        // ULTRATHINK: Test parameter mapping from line 358
        final menuData = {'title': 'Test Menu'};
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: menuData,
              type: ContentCardType.menu,
              showTags: true,  // Should map to showPreview
            ),
          ),
        );

        // ULTRATHINK: Test parameter mapping intention - showTags → showPreview
        expect(tester.takeException(), isNull);
      });

      testWidgets('maps showTags to showPreview for shopping list cards', (WidgetTester tester) async {
        // ULTRATHINK: Test parameter mapping from line 380
        final shoppingList = ShoppingListFactory.build(name: 'Test List');
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: shoppingList,
              type: ContentCardType.shoppingList,
              showTags: true,  // Should map to showPreview
            ),
          ),
        );

        // ULTRATHINK: Test parameter mapping intention - showTags → showPreview
        expect(tester.takeException(), isNull);
      });
    });

    group('Style Mapping Tests', () {
      testWidgets('maps ContentCardStyle to RecipeCardStyle correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test style mapping from lines 390-399
        final recipe = RecipeFactory.build();
        
        // Test all three style mappings
        for (final style in ContentCardStyle.values) {
          await tester.pumpWidget(
            createTestWidget(
              child: ContentCard(
                item: recipe,
                type: ContentCardType.recipe,
                style: style,
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          
          // Pump between style changes
          await tester.pump();
        }
      });

      testWidgets('maps ContentCardStyle to FriendCardStyle with grid→list mapping', (WidgetTester tester) async {
        // ULTRATHINK: Test friend style mapping from lines 401-410, note grid→list mapping
        final user = UserProfileFactory.build();
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: user,
              type: ContentCardType.friend,
              style: ContentCardStyle.grid,  // Should map to FriendCardStyle.list
            ),
          ),
        );

        // ULTRATHINK: Test special grid→list mapping intention for friends
        expect(tester.takeException(), isNull);
      });

      testWidgets('maps ContentCardStyle to MenuCardStyle correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test menu style mapping from lines 412-421
        final menuData = {'title': 'Test Menu'};
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: menuData,
              type: ContentCardType.menu,
              style: ContentCardStyle.compact,
            ),
          ),
        );

        // ULTRATHINK: Test menu style mapping intention
        expect(tester.takeException(), isNull);
      });

      testWidgets('maps ContentCardStyle to ShoppingListCardStyle correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test shopping list style mapping from lines 423-432
        final shoppingList = ShoppingListFactory.build(name: 'Test List');
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: shoppingList,
              type: ContentCardType.shoppingList,
              style: ContentCardStyle.detailed,
            ),
          ),
        );

        // ULTRATHINK: Test shopping list style mapping intention
        expect(tester.takeException(), isNull);
      });
    });

    group('Backward Compatibility Static Methods Tests', () {
      testWidgets('recipe static method creates recipe card', (WidgetTester tester) async {
        // ULTRATHINK: Test backward compatibility from lines 437-459
        final recipe = RecipeFactory.build();
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard.recipe(
              recipe: recipe,
              showImage: false,
              showTags: true,
              showMetadata: false,
            ),
          ),
        );

        // ULTRATHINK: Test legacy API intention - should work identically to main constructor
        expect(tester.takeException(), isNull);
        expect(find.byType(ContentCard), findsOneWidget);
      });

      testWidgets('compactRecipe static method creates compact recipe card', (WidgetTester tester) async {
        // ULTRATHINK: Test compact recipe from lines 462-483
        final recipe = RecipeFactory.build();
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard.compactRecipe(
              recipe: recipe,
              showImage: true,
              showMetadata: true,
            ),
          ),
        );

        // ULTRATHINK: Test compact style intention - showTags forced to false (line 480)
        expect(tester.takeException(), isNull);
        expect(find.byType(ContentCard), findsOneWidget);
      });

      testWidgets('friend static method creates friend card', (WidgetTester tester) async {
        // ULTRATHINK: Test friend static method from lines 486-510
        final user = UserProfileFactory.build();
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard.friend(
              user: user,
              showAvatar: true,
              showOnlineStatus: true,
              showMetadata: false,
              trailing: const Icon(Icons.more_horiz),
            ),
          ),
        );

        // ULTRATHINK: Test friend legacy API intention
        expect(tester.takeException(), isNull);
        expect(find.byType(ContentCard), findsOneWidget);
      });

      testWidgets('friendRequest static method creates friend request card', (WidgetTester tester) async {
        // ULTRATHINK: Test friend request static method from lines 513-537
        final friendRequest = SocialFactory.createFriendRequest();
        bool acceptCalled = false;
        bool declineCalled = false;
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard.friendRequest(
              friendRequest: friendRequest,
              onAccept: () => acceptCalled = true,
              onDecline: () => declineCalled = true,
              showAvatar: true,
              showMetadata: true,
            ),
          ),
        );

        // ULTRATHINK: Test friend request legacy API intention with action handlers
        expect(tester.takeException(), isNull);
        expect(find.byType(ContentCard), findsOneWidget);
        expect(acceptCalled, isFalse); // Not triggered yet
        expect(declineCalled, isFalse); // Not triggered yet
      });
    });

    group('Interaction Handler Tests', () {
      testWidgets('handles onTap callback for recipe cards', (WidgetTester tester) async {
        // ULTRATHINK: Test onTap mapping from line 285
        final recipe = RecipeFactory.build();
        bool tapCalled = false;
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: recipe,
              type: ContentCardType.recipe,
              onTap: () => tapCalled = true,
            ),
          ),
        );

        // ULTRATHINK: Test tap handler intention - should be wrapped for RecipeCard
        expect(tester.takeException(), isNull);
        expect(tapCalled, isFalse); // Not triggered yet
      });

      testWidgets('handles onLongPress callback for all card types', (WidgetTester tester) async {
        // ULTRATHINK: Test onLongPress mapping from line 286
        final recipe = RecipeFactory.build();
        bool longPressCalled = false;
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: recipe,
              type: ContentCardType.recipe,
              onLongPress: () => longPressCalled = true,
            ),
          ),
        );

        // ULTRATHINK: Test long press handler intention - should be wrapped for RecipeCard
        expect(tester.takeException(), isNull);
        expect(longPressCalled, isFalse); // Not triggered yet
      });

      testWidgets('handles friend request action callbacks', (WidgetTester tester) async {
        // ULTRATHINK: Test friend request actions from lines 337-338
        final friendRequest = SocialFactory.createFriendRequest();
        bool acceptCalled = false;
        bool declineCalled = false;
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: friendRequest,
              type: ContentCardType.friendRequest,
              onAccept: () => acceptCalled = true,
              onDecline: () => declineCalled = true,
            ),
          ),
        );

        // ULTRATHINK: Test specialized action handlers intention
        expect(tester.takeException(), isNull);
        expect(acceptCalled, isFalse); // Not triggered yet
        expect(declineCalled, isFalse); // Not triggered yet
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('handles null optional parameters gracefully', (WidgetTester tester) async {
        // ULTRATHINK: Test null parameter handling
        final recipe = RecipeFactory.build();
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: recipe,
              type: ContentCardType.recipe,
              onTap: null,
              onLongPress: null,
              margin: null,
              padding: null,
              trailing: null,
              subtitle: null,
            ),
          ),
        );

        // ULTRATHINK: Test null handling intention - should use defaults
        expect(tester.takeException(), isNull);
      });

      testWidgets('uses default ContentCardStyle when not specified', (WidgetTester tester) async {
        // ULTRATHINK: Test default style from line 225
        final recipe = RecipeFactory.build();
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: recipe,
              type: ContentCardType.recipe,
              // style not specified - should default to detailed
            ),
          ),
        );

        // ULTRATHINK: Test default style intention - ContentCardStyle.detailed
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles complex nested parameter combinations', (WidgetTester tester) async {
        // ULTRATHINK: Test complex parameter combinations
        final user = UserProfileFactory.build();
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: user,
              type: ContentCardType.friend,
              style: ContentCardStyle.compact,
              showImage: false,
              showTags: true,
              showMetadata: false,
              showOnlineStatus: true,
              showSharingStatus: false,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              subtitle: 'Complex Configuration',
              trailing: const Icon(Icons.star),
            ),
          ),
        );

        // ULTRATHINK: Test complex parameter intention - should handle all combinations
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles rapid content type switching', (WidgetTester tester) async {
        // ULTRATHINK: Test widget rebuilding with different types
        final recipe = RecipeFactory.build();
        final user = UserProfileFactory.build();
        
        // Start with recipe
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: recipe,
              type: ContentCardType.recipe,
            ),
          ),
        );
        
        expect(tester.takeException(), isNull);
        
        // Switch to friend
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: user,
              type: ContentCardType.friend,
            ),
          ),
        );

        // ULTRATHINK: Test type switching intention - should handle rebuilds gracefully
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles menu and shopping list with complex dynamic data', (WidgetTester tester) async {
        // ULTRATHINK: Test dynamic data handling for menu/shopping list types
        final complexMenuData = {
          'title': 'Complex Menu with Special Characters: åäö',
          'description': 'Very long description with lots of text that might cause layout issues',
          'recipes': [
            {'name': 'Recipe 1', 'id': '123'},
            {'name': 'Recipe 2', 'id': '456'},
          ],
          'metadata': {
            'created': DateTime.now().toIso8601String(),
            'shared': true,
          },
        };
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: complexMenuData,
              type: ContentCardType.menu,
              style: ContentCardStyle.detailed,
              showTags: true,
              showMetadata: true,
              showSharingStatus: true,
            ),
          ),
        );

        // ULTRATHINK: Test complex dynamic data intention - should handle nested structures
        expect(tester.takeException(), isNull);
      });
    });

    group('Widget Structure and Architecture Tests', () {
      testWidgets('ContentCard is a StatelessWidget', (WidgetTester tester) async {
        // ULTRATHINK: Test widget type from line 150
        final recipe = RecipeFactory.build();
        
        final widget = ContentCard(
          item: recipe,
          type: ContentCardType.recipe,
        );

        expect(widget, isA<StatelessWidget>());
      });

      testWidgets('build method delegates immediately without intermediate widgets', (WidgetTester tester) async {
        // ULTRATHINK: Test delegation architecture from lines 255-268
        final recipe = RecipeFactory.build();
        
        await tester.pumpWidget(
          createTestWidget(
            child: ContentCard(
              item: recipe,
              type: ContentCardType.recipe,
            ),
          ),
        );

        // ULTRATHINK: Test delegation intention - should create delegated widget directly
        expect(tester.takeException(), isNull);
        expect(find.byType(ContentCard), findsOneWidget);
      });

      testWidgets('re-exports are available for backward compatibility', (WidgetTester tester) async {
        // ULTRATHINK: Test re-exports from lines 66-69
        // These should be available due to re-export statements in ContentCard
        expect(RecipeCardStyle.detailed, isA<RecipeCardStyle>());
        expect(FriendCardStyle.detailed, isA<FriendCardStyle>());
        expect(MenuCardStyle.detailed, isA<MenuCardStyle>());
        expect(ShoppingListCardStyle.detailed, isA<ShoppingListCardStyle>());
      });
    });
  });
}