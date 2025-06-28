// test/views/inkopslista_view_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/views/inkopslista_view.dart';
import 'package:butlery/viewmodels/shopping_list_viewmodel.dart';
import 'package:butlery/services/friends_service.dart';
import 'package:butlery/services/share_service.dart';
import 'package:butlery/models/shopping_list.dart';
import 'package:butlery/models/shopping_item.dart';
import 'package:butlery/models/friend.dart';
import 'package:butlery/theme/app_theme.dart';

// Import generated mocks
import '../helpers/test_helpers.mocks.dart';

void main() {
  late MockShoppingListViewModel mockViewModel;
  late MockFriendsService mockFriendsService;
  late MockShareService mockShareService;
  final sl = GetIt.instance;

  setUpAll(() {
    // Reset GetIt before tests
    sl.reset();
  });

  setUp(() {
    mockViewModel = MockShoppingListViewModel();
    mockFriendsService = MockFriendsService();
    mockShareService = MockShareService();

    // Register mocks
    sl.registerFactory<ShoppingListViewModel>(() => mockViewModel);
    sl.registerLazySingleton<FriendsService>(() => mockFriendsService);
    sl.registerLazySingleton<ShareService>(() => mockShareService);

    // Default stubs
    when(mockViewModel.isLoading).thenReturn(false);
    when(mockViewModel.hasLists).thenReturn(true);
    when(mockViewModel.hasItems).thenReturn(true);
    when(mockViewModel.needsSync).thenReturn(false);
    when(mockViewModel.isSyncing).thenReturn(false);
    when(mockViewModel.lists).thenReturn([]);
    when(mockViewModel.activeList).thenReturn(null);
    when(mockViewModel.shoppingItems).thenReturn([]);
    when(mockViewModel.unboughtItems).thenReturn([]);
    when(mockViewModel.boughtItems).thenReturn([]);
    when(mockViewModel.formattedItems).thenReturn([]);
    when(mockViewModel.totalCount).thenReturn(0);
    when(mockViewModel.checkedCount).thenReturn(0);
    when(mockViewModel.uncheckedCount).thenReturn(0);
    when(mockViewModel.activeListId).thenReturn(null);

    when(mockFriendsService.friends).thenReturn([]);
    when(mockFriendsService.loadFriends()).thenAnswer((_) async {});

    when(mockShareService.shareShoppingList(any)).thenAnswer((_) async {});
  });

  tearDown(() {
    sl.reset();
  });

  Widget createTestWidget() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: const InkopslistaView(),
      routes: {
        '/veckomeny': (context) => const Scaffold(body: Text('Veckomeny')),
        '/friends': (context) => const Scaffold(body: Text('Friends')),
      },
    );
  }

  group('InkopslistaView - Basic UI', () {
    testWidgets('shows loading state when isLoading is true', (tester) async {
      // Arrange
      when(mockViewModel.isLoading).thenReturn(true);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Laddar inköpslistor...'), findsOneWidget);
    });

    testWidgets('shows empty state when no lists', (tester) async {
      // Arrange
      when(mockViewModel.hasLists).thenReturn(false);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.text('Inga inköpslistor'), findsOneWidget);
      expect(find.text('Skapa veckomeny'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
    });

    testWidgets('shows header and FAB when has lists', (tester) async {
      // Arrange
      final testList = ShoppingList(
        id: 'test-list',
        name: 'Test Lista',
        items: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ownerId: 'test-owner-id',
      );

      when(mockViewModel.hasLists).thenReturn(true);
      when(mockViewModel.activeList).thenReturn(testList);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.text('Test Lista'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Lägg till artikel'), findsOneWidget);
    });

    testWidgets('shows empty list message when no items', (tester) async {
      // Arrange
      when(mockViewModel.hasItems).thenReturn(false);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.text('Listan är tom'), findsOneWidget);
      expect(find.text('Gå till veckomeny'), findsOneWidget);
    });
  });

  group('InkopslistaView - Shopping Items', () {
    testWidgets('displays shopping items correctly', (tester) async {
      // Arrange
      final items = [
        ShoppingItem(name: 'Mjölk', amount: 1, unit: 'l', bought: false),
        ShoppingItem(name: 'Bröd', amount: 2, unit: 'st', bought: true),
      ];

      when(mockViewModel.hasItems).thenReturn(true);
      when(mockViewModel.shoppingItems).thenReturn(items);
      when(mockViewModel.unboughtItems).thenReturn([items[0]]);
      when(mockViewModel.boughtItems).thenReturn([items[1]]);
      when(mockViewModel.formattedItems).thenReturn(['1 l Mjölk', '2 st Bröd']);
      when(mockViewModel.getOriginalIndex(items[0])).thenReturn(0);
      when(mockViewModel.getOriginalIndex(items[1])).thenReturn(1);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.text('1 l Mjölk'), findsOneWidget);
      expect(find.text('2 st Bröd'), findsOneWidget);
      expect(find.text('Inköpt'), findsOneWidget); // Separator
    });

    testWidgets('can toggle item bought status', (tester) async {
      // Arrange
      final item = ShoppingItem(
        name: 'Mjölk',
        amount: 1,
        unit: 'l',
        bought: false,
      );

      when(mockViewModel.hasItems).thenReturn(true);
      when(mockViewModel.shoppingItems).thenReturn([item]);
      when(mockViewModel.unboughtItems).thenReturn([item]);
      when(mockViewModel.boughtItems).thenReturn([]);
      when(mockViewModel.formattedItems).thenReturn(['1 l Mjölk']);
      when(mockViewModel.getOriginalIndex(item)).thenReturn(0);
      when(mockViewModel.toggleItem(0)).thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      // Assert
      verify(mockViewModel.toggleItem(0)).called(1);
    });

    testWidgets('can remove item with swipe', (tester) async {
      // Arrange
      final item = ShoppingItem(name: 'Mjölk', amount: 1, bought: false);

      when(mockViewModel.hasItems).thenReturn(true);
      when(mockViewModel.shoppingItems).thenReturn([item]);
      when(mockViewModel.unboughtItems).thenReturn([item]);
      when(mockViewModel.boughtItems).thenReturn([]);
      when(mockViewModel.formattedItems).thenReturn(['1 l Mjölk']);
      when(mockViewModel.getOriginalIndex(item)).thenReturn(0);
      when(mockViewModel.removeItem(0)).thenAnswer((_) async => true);

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.drag(find.text('1 l Mjölk'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Confirm delete
      await tester.tap(find.text('Ta bort'));
      await tester.pumpAndSettle();

      // Assert
      verify(mockViewModel.removeItem(0)).called(1);
    });
  });

  group('InkopslistaView - Actions', () {
    testWidgets('shows sync indicator when needs sync', (tester) async {
      // Arrange
      when(mockViewModel.needsSync).thenReturn(true);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byIcon(Icons.sync_problem), findsOneWidget);
    });

    testWidgets('shows sync progress when syncing', (tester) async {
      // Arrange
      when(mockViewModel.isSyncing).thenReturn(true);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
    });

    testWidgets('can trigger force sync', (tester) async {
      // Arrange
      when(mockViewModel.forceSync()).thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(createTestWidget());

      // Open menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap sync
      await tester.tap(find.text('Synka nu'));
      await tester.pumpAndSettle();

      // Assert
      verify(mockViewModel.forceSync()).called(1);
    });

    testWidgets('can share with friends', (tester) async {
      // Arrange
      final friend = TestFriend(
        id: 'friend-1',
        name: 'Test Friend',
        email: 'friend@example.com',
      );

      when(mockFriendsService.friends).thenReturn([friend]);

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.byIcon(Icons.group));
      await tester.pumpAndSettle();

      // Assert
      verify(mockFriendsService.loadFriends()).called(1);
    });

    testWidgets('shows message when no friends', (tester) async {
      // Arrange
      when(mockFriendsService.friends).thenReturn([]);

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.byIcon(Icons.group));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Du har inga vänner att dela med'), findsOneWidget);
      expect(find.text('Lägg till vänner'), findsOneWidget);
    });

    testWidgets('can clear checked items', (tester) async {
      // Arrange
      when(mockViewModel.checkedCount).thenReturn(3);
      when(mockViewModel.clearCheckedItems()).thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(createTestWidget());

      // Open menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap clear
      await tester.tap(find.text('Rensa köpta (3)'));
      await tester.pumpAndSettle();

      // Confirm
      await tester.tap(find.text('Rensa'));
      await tester.pumpAndSettle();

      // Assert
      verify(mockViewModel.clearCheckedItems()).called(1);
    });
  });

  group('InkopslistaView - Navigation', () {
    testWidgets('can navigate to weekly menu', (tester) async {
      // Arrange
      when(mockViewModel.hasItems).thenReturn(false);

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.text('Gå till veckomeny'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Veckomeny'), findsOneWidget);
    });

    testWidgets('prevents back navigation with dialog', (tester) async {
      // Act
      await tester.pumpWidget(createTestWidget());

      // Simulate back button
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Avsluta Butlery?'), findsOneWidget);
    });

    testWidgets('can add item via FAB', (tester) async {
      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Assert - Dialog should open
      expect(find.byType(Dialog), findsOneWidget);
    });
  });

  group('InkopslistaView - Pull to Refresh', () {
    testWidgets('can pull to refresh', (tester) async {
      // Arrange
      final item = ShoppingItem(name: 'Test', amount: 1);

      when(mockViewModel.hasItems).thenReturn(true);
      when(mockViewModel.shoppingItems).thenReturn([item]);
      when(mockViewModel.unboughtItems).thenReturn([item]);
      when(mockViewModel.boughtItems).thenReturn([]);
      when(mockViewModel.formattedItems).thenReturn(['1 Test']);
      when(mockViewModel.getOriginalIndex(item)).thenReturn(0);
      when(mockViewModel.refresh()).thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(createTestWidget());

      // Pull to refresh
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      // Assert
      verify(mockViewModel.refresh()).called(1);
    });
  });
}
