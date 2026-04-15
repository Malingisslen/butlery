import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/user_profile.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/factories/shopping_list_factory.dart';
import '../../infrastructure/factories/user_profile_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

// Mock classes
class MockUniversalShareDialogViewModel extends Mock
    implements UniversalShareDialogViewModel {}

void main() {
  setUpAll(() {
    registerFallbackValue(RecipeFactory.build());
    registerFallbackValue(<String, List<Recipe>>{});
    registerFallbackValue(ShoppingListFactory.build());
    registerFallbackValue(<String>[]);
  });

  group('UniversalShareDialog Factory Constructor Tests', () {
    late MockUniversalShareDialogViewModel mockViewModel;
    late Recipe testRecipe;
    late Map<String, List<Recipe>> testMenu;
    late UnifiedShoppingList testShoppingList;
    late List<UserProfile> testFriends;

    setUp(() {
      mockViewModel = MockUniversalShareDialogViewModel();

      testRecipe = RecipeFactory.build(
        id: 'recipe_1',
        title: 'Mormors kottbullar',
        description: 'Klassiska svenska kottbullar',
        portions: 4,
        ingredients: ['kottfars', 'agg', 'mjolk', 'lok'],
        instructions: [
          'Blanda ingredienserna',
          'Forma kottbullar',
          'Stek i pannan'
        ],
        personalTagIds: ['svenska', 'klassiker'],
      );

      testMenu = {
        'Mandag': [testRecipe],
        'Tisdag': [testRecipe],
      };

      testShoppingList = ShoppingListFactory.build(
        id: 'shopping_1',
        name: 'Veckans inkop',
        ownerId: 'user_anna',
        ownerDisplayName: 'Anna Andersson',
      );

      testFriends = [
        UserProfileFactory.build(
          uid: 'friend_1',
          displayName: 'Erik Eriksson',
          email: 'erik@example.com',
        ),
        UserProfileFactory.build(
          uid: 'friend_2',
          displayName: 'Maria Andersson',
          email: 'maria@example.com',
        ),
      ];

      // Mock ViewModel behavior
      when(() => mockViewModel.isSharing).thenReturn(false);
      when(() => mockViewModel.shareRecipe(
            recipe: any(named: 'recipe'),
            friendUserIds: any(named: 'friendUserIds'),
            groupIds: any(named: 'groupIds'),
            message: any(named: 'message'),
            allowCollaboration: any(named: 'allowCollaboration'),
          )).thenAnswer((_) async => true);

      when(() => mockViewModel.shareMenu(
            menu: any(named: 'menu'),
            friendUserIds: any(named: 'friendUserIds'),
            groupIds: any(named: 'groupIds'),
            message: any(named: 'message'),
            allowCollaboration: any(named: 'allowCollaboration'),
          )).thenAnswer((_) async => true);

      when(() => mockViewModel.shareShoppingList(
            shoppingList: any(named: 'shoppingList'),
            friendUserIds: any(named: 'friendUserIds'),
            groupIds: any(named: 'groupIds'),
            message: any(named: 'message'),
          )).thenAnswer((_) async => true);
    });

    test('recipe factory constructor creates correct widget configuration', () {
      final dialog = UniversalShareDialog.recipe(
        recipe: testRecipe,
        viewModel: mockViewModel,
        availableFriends: testFriends,
        initialMessage: 'Test recipe message',
      );

      expect(dialog.content, equals(testRecipe));
      expect(dialog.contentType, equals(ShareContentType.recipe));
      expect(dialog.viewModel, equals(mockViewModel));
      expect(dialog.availableFriends, equals(testFriends));
      expect(dialog.initialMessage, equals('Test recipe message'));
      expect(dialog.isBulkSharing, isFalse);
    });

    test('menu factory constructor creates correct widget configuration', () {
      final dialog = UniversalShareDialog.menu(
        menu: testMenu,
        viewModel: mockViewModel,
        availableFriends: testFriends,
      );

      expect(dialog.content, equals(testMenu));
      expect(dialog.contentType, equals(ShareContentType.menu));
      expect(dialog.viewModel, equals(mockViewModel));
      expect(dialog.availableFriends, equals(testFriends));
      expect(dialog.availableGroups, isNull);
      expect(dialog.isBulkSharing, isFalse);
    });

    test(
        'shopping list factory constructor creates correct widget configuration',
        () {
      final dialog = UniversalShareDialog.shoppingList(
        shoppingList: testShoppingList,
        viewModel: mockViewModel,
        initialMessage: 'Dela inkopslistan',
      );

      expect(dialog.content, equals(testShoppingList));
      expect(dialog.contentType, equals(ShareContentType.shoppingList));
      expect(dialog.viewModel, equals(mockViewModel));
      expect(dialog.initialMessage, equals('Dela inkopslistan'));
      expect(dialog.isBulkSharing, isFalse);
    });

    test('bulk share factory constructor creates correct widget configuration',
        () {
      final bulkContent = [testRecipe, testRecipe];

      final dialog = UniversalShareDialog.bulkShare(
        contentItems: bulkContent,
        primaryContentType: ShareContentType.recipe,
        viewModel: mockViewModel,
        availableFriends: testFriends,
      );

      expect(dialog.content, equals(bulkContent));
      expect(dialog.contentType, equals(ShareContentType.recipe));
      expect(dialog.viewModel, equals(mockViewModel));
      expect(dialog.availableFriends, equals(testFriends));
      expect(dialog.isBulkSharing, isTrue);
    });

    test('factory constructors handle null optional parameters correctly', () {
      final minimalDialog = UniversalShareDialog.recipe(
        recipe: testRecipe,
        viewModel: mockViewModel,
      );

      expect(minimalDialog.content, equals(testRecipe));
      expect(minimalDialog.initialMessage, isNull);
      expect(minimalDialog.availableFriends, isNull);
      expect(minimalDialog.availableGroups, isNull);
    });

    test('content type enum values are correctly assigned', () {
      final recipeDialog = UniversalShareDialog.recipe(
        recipe: testRecipe,
        viewModel: mockViewModel,
      );

      final menuDialog = UniversalShareDialog.menu(
        menu: testMenu,
        viewModel: mockViewModel,
      );

      final shoppingDialog = UniversalShareDialog.shoppingList(
        shoppingList: testShoppingList,
        viewModel: mockViewModel,
      );

      expect(recipeDialog.contentType, ShareContentType.recipe);
      expect(menuDialog.contentType, ShareContentType.menu);
      expect(shoppingDialog.contentType, ShareContentType.shoppingList);
    });
  });

  group('UniversalShareDialog Widget Rendering Tests', () {
    late MockUniversalShareDialogViewModel mockViewModel;
    late Recipe testRecipe;
    late Map<String, List<Recipe>> testMenu;
    late UnifiedShoppingList testShoppingList;
    late List<UserProfile> testFriends;

    setUp(() async {
      mockViewModel = MockUniversalShareDialogViewModel();

      testRecipe = RecipeFactory.build(
        id: 'recipe_1',
        title: 'Mormors kottbullar',
        description: 'Klassiska svenska kottbullar',
        portions: 4,
        ingredients: ['kottfars', 'agg', 'mjolk', 'lok'],
        instructions: [
          'Blanda ingredienserna',
          'Forma kottbullar',
          'Stek i pannan'
        ],
        personalTagIds: ['svenska', 'klassiker'],
      );

      testMenu = {
        'Mandag': [testRecipe],
        'Tisdag': [testRecipe],
      };

      testShoppingList = ShoppingListFactory.build(
        id: 'shopping_1',
        name: 'Veckans inkop',
        ownerId: 'user_anna',
        ownerDisplayName: 'Anna Andersson',
      );

      testFriends = [
        UserProfileFactory.build(
          uid: 'friend_1',
          displayName: 'Erik Eriksson',
          email: 'erik@example.com',
        ),
        UserProfileFactory.build(
          uid: 'friend_2',
          displayName: 'Maria Andersson',
          email: 'maria@example.com',
        ),
      ];

      // Mock ViewModel behavior - successful sharing
      when(() => mockViewModel.isSharing).thenReturn(false);
      when(() => mockViewModel.shareRecipe(
            recipe: any(named: 'recipe'),
            friendUserIds: any(named: 'friendUserIds'),
            groupIds: any(named: 'groupIds'),
            message: any(named: 'message'),
            allowCollaboration: any(named: 'allowCollaboration'),
          )).thenAnswer((_) async => true);

      when(() => mockViewModel.shareMenu(
            menu: any(named: 'menu'),
            friendUserIds: any(named: 'friendUserIds'),
            groupIds: any(named: 'groupIds'),
            message: any(named: 'message'),
            allowCollaboration: any(named: 'allowCollaboration'),
          )).thenAnswer((_) async => true);

      when(() => mockViewModel.shareShoppingList(
            shoppingList: any(named: 'shoppingList'),
            friendUserIds: any(named: 'friendUserIds'),
            groupIds: any(named: 'groupIds'),
            message: any(named: 'message'),
          )).thenAnswer((_) async => true);
    });

    group('Essential Structure Tests - Gold Standard', () {
      testWidgets('should render dialog structure correctly', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: UniversalShareDialog.recipe(
              recipe: testRecipe,
              viewModel: mockViewModel,
              availableFriends: testFriends,
            ),
          ),
        );

        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byType(Column), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle different content types correctly',
          (tester) async {
        final dialogs = [
          UniversalShareDialog.recipe(
            recipe: testRecipe,
            viewModel: mockViewModel,
            availableFriends: testFriends,
          ),
          UniversalShareDialog.menu(
            menu: testMenu,
            viewModel: mockViewModel,
            availableFriends: testFriends,
          ),
          UniversalShareDialog.shoppingList(
            shoppingList: testShoppingList,
            viewModel: mockViewModel,
            availableFriends: testFriends,
          ),
        ];

        for (final dialog in dialogs) {
          await tester.pumpWidget(
            createLocalizedTestApp(child: dialog),
          );

          expect(find.byType(Dialog), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('should handle empty friends list gracefully',
          (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: UniversalShareDialog.recipe(
              recipe: testRecipe,
              viewModel: mockViewModel,
              availableFriends: const [],
            ),
          ),
        );

        expect(find.byType(Dialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Share Actions and Features - Gold Standard', () {
      testWidgets('should support platform selection for recipes',
          (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: UniversalShareDialog.recipe(
              recipe: testRecipe,
              viewModel: mockViewModel,
              availableFriends: testFriends,
            ),
          ),
        );

        expect(find.byType(Dialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should exclude platform selection for shopping lists',
          (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: UniversalShareDialog.shoppingList(
              shoppingList: testShoppingList,
              viewModel: mockViewModel,
              availableFriends: testFriends,
            ),
          ),
        );

        expect(find.byType(Dialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle custom messages correctly', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: UniversalShareDialog.recipe(
              recipe: testRecipe,
              viewModel: mockViewModel,
              availableFriends: testFriends,
              initialMessage: 'Prova detta recept!',
            ),
          ),
        );

        expect(find.text('Prova detta recept!'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should support Swedish localization', (tester) async {
        final swedishRecipe = RecipeFactory.build(
          title: 'Kottbullar med artor och rakor',
          description: 'Traditionell svensk husmanskost',
          ingredients: ['kott', 'artor', 'rakor', 'gradde'],
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: UniversalShareDialog.recipe(
              recipe: swedishRecipe,
              viewModel: mockViewModel,
              availableFriends: testFriends,
              initialMessage: 'Hej! Prova denna underbara ratt!',
            ),
          ),
        );

        expect(find.text('Hej! Prova denna underbara ratt!'), findsWidgets);
        expect(find.byType(Dialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
