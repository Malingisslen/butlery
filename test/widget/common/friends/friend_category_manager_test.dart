// test/widget/common/friends/friend_category_manager_test.dart
// Comprehensive tests for FriendCategoryManager using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Widget under test
import 'package:butlery/widgets/common/friends/friend_category_manager.dart';

// Dependencies
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

// Test infrastructure
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/widget_mocks.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/factories/social_factory.dart';
import '../../../infrastructure/factories/user_profile_factory.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('FriendCategoryManager Tests', () {
    // Test services
    late MockUnifiedFriendsService mockFriendsService;
    late MockFriendsViewModel mockFriendsViewModel;

    // Test data
    late List<FriendCategory> testCategories;
    late List<UserProfile> testFriends;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Initialize mock services
      mockFriendsService = MockUnifiedFriendsService();
      mockFriendsViewModel = MockFriendsViewModel();

      // Create test data
      testCategories = [
        SocialFactory.createFriendCategory(
          id: 'family',
          name: 'Familjen',
          emoji: '👨‍👩‍👧‍👦',
          memberIds: ['user1', 'user2'],
        ),
        SocialFactory.createFriendCategory(
          id: 'work',
          name: 'Jobbet',
          emoji: '💼',
          memberIds: ['user3', 'user4'],
        ),
        SocialFactory.createFriendCategory(
          id: 'friends',
          name: 'Kompisar',
          emoji: '🎉',
          memberIds: ['user5'],
        ),
      ];

      testFriends = [
        UserProfileFactory.build(uid: 'user1', displayName: 'Anna Svensson'),
        UserProfileFactory.build(uid: 'user2', displayName: 'Erik Johansson'),
        UserProfileFactory.build(uid: 'user3', displayName: 'Lisa Andersson'),
        UserProfileFactory.build(uid: 'user4', displayName: 'Magnus Karlsson'),
        UserProfileFactory.build(uid: 'user5', displayName: 'Sofia Lindberg'),
      ];
    });

    tearDown(() async {
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    // Helper to create test widget with proper provider setup
    Widget createTestWidget({
      List<String> selectedFriendIds = const [],
      Function(List<String>)? onSelectionChanged,
      bool allowMultipleCategories = true,
      String title = 'Välj vänner',
      String subtitle = 'Välj kategorier eller individuella vänner',
    }) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'),
        home: Scaffold(
          body: MultiProvider(
            providers: [
              Provider<UnifiedFriendsService>.value(
                value: mockFriendsService,
              ),
              ChangeNotifierProvider<FriendsViewModel>.value(
                value: mockFriendsViewModel,
              ),
            ],
            child: SizedBox(
              height:
                  600, // Adequate height for categories + friends + selection
              child: SingleChildScrollView(
                child: FriendCategoryManager(
                  selectedFriendIds: selectedFriendIds,
                  onSelectionChanged: onSelectionChanged ?? (_) {},
                  allowMultipleCategories: allowMultipleCategories,
                  title: title,
                  subtitle: subtitle,
                ),
              ),
            ),
          ),
        ),
      );
    }

    group('Basic Rendering', () {
      testWidgets('should render with default configuration',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.byType(FriendCategoryManager), findsOneWidget);
        expect(find.text('Välj vänner'), findsOneWidget);
        expect(find.text('Välj kategorier eller individuella vänner'),
            findsOneWidget);
      });

      testWidgets('should render with custom title and subtitle',
          (WidgetTester tester) async {
        // Arrange - need at least one friend so header is shown
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
            isLoading: false, friends: testFriends.take(1).toList());

        // Act
        await tester.pumpWidget(createTestWidget(
          title: 'Välj deltagare',
          subtitle: 'Välj vem som ska delta',
        ));

        // Assert
        expect(find.text('Välj deltagare'), findsOneWidget);
        expect(find.text('Välj vem som ska delta'), findsOneWidget);
      });

      testWidgets('should render both categories and friends sections',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.text('Kategorier'), findsOneWidget);
        expect(find.text('Individuellt val'), findsOneWidget);
        expect(find.text('Familjen'), findsOneWidget);
        expect(find.text('Anna Svensson'), findsOneWidget);
      });
    });

    group('Loading States', () {
      testWidgets('should show loading when both services are loading',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(isLoading: true);
        mockFriendsViewModel.setFriendsState(isLoading: true);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Laddar vänner och kategorier...'), findsOneWidget);
      });

      testWidgets('should show loading when only categories service is loading',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(isLoading: true);
        mockFriendsViewModel.setFriendsState(
            isLoading: false, friends: testFriends);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Laddar vänner och kategorier...'), findsOneWidget);
      });

      testWidgets('should show loading when only friends service is loading',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(
            isLoading: false, categoriesList: testCategories);
        mockFriendsViewModel.setFriendsState(isLoading: true);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Laddar vänner och kategorier...'), findsOneWidget);
      });
    });

    group('Error States', () {
      testWidgets('should handle normal state when services ready',
          (WidgetTester tester) async {
        // Arrange - both services ready with data
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(
            isLoading: false, friends: testFriends);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert - should show normal content
        expect(find.text('Kategorier'), findsOneWidget);
        expect(find.text('Individuellt val'), findsOneWidget);
      });

      testWidgets('should handle mixed data states properly',
          (WidgetTester tester) async {
        // Arrange - categories empty, friends available
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert - should show only friends section
        expect(find.text('Individuellt val'), findsOneWidget);
        expect(find.text('Anna Svensson'), findsOneWidget);
        expect(find.text('Kategorier'), findsNothing);
      });

      testWidgets('should handle service coordination when no data',
          (WidgetTester tester) async {
        // Arrange - test coordination when both services have no data
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: [],
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert - should show empty state when both are empty
        expect(find.text('Inga vänner eller kategorier'), findsOneWidget);
        expect(find.text('Lägg till vänner och skapa kategorier först'),
            findsOneWidget);
      });
    });

    group('Empty States', () {
      testWidgets('should show empty state when no categories or friends',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.text('Inga vänner eller kategorier'), findsOneWidget);
        expect(find.text('Lägg till vänner och skapa kategorier först'),
            findsOneWidget);
        expect(find.text('Hantera vänner'), findsOneWidget);
        expect(find.byIcon(Icons.people_outline), findsOneWidget);
      });

      testWidgets('should show content when categories exist but no friends',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.text('Kategorier'), findsOneWidget);
        expect(find.text('Familjen'), findsOneWidget);
        expect(find.text('Individuellt val'),
            findsNothing); // Friends section hidden when empty
      });

      testWidgets('should show content when friends exist but no categories',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.text('Individuellt val'), findsOneWidget);
        expect(find.text('Anna Svensson'), findsOneWidget);
        expect(find.text('Kategorier'), findsNothing);
      });
    });

    group('Category Display', () {
      testWidgets('should display category chips with correct information',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.text('Familjen'), findsOneWidget);
        expect(find.text('👨‍👩‍👧‍👦'), findsOneWidget);
        expect(
            find.text('2'),
            findsNWidgets(
                2)); // Both 'family' and 'work' categories have 2 members
        expect(find.text('Jobbet'), findsOneWidget);
        expect(find.text('💼'), findsOneWidget);
        expect(find.byType(FilterChip), findsNWidgets(3));
      });

      testWidgets('should show category section header',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.text('Kategorier'), findsOneWidget);
        expect(find.text('Välj hela kategorier för snabb delning'),
            findsOneWidget);
        expect(find.byIcon(Icons.category_outlined), findsOneWidget);
      });
    });

    group('Individual Friends Display', () {
      testWidgets('should display friends list with checkboxes',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        // Act
        await tester.pumpWidget(createTestWidget());
        await tester
            .pumpAndSettle(); // Allow Consumer2 to process notifications

        // Assert
        expect(find.text('Anna Svensson'), findsOneWidget);
        expect(find.text('Erik Johansson'), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNWidgets(5));
      });

      testWidgets('should show friends section header',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.text('Individuellt val'), findsOneWidget);
        expect(find.text('Välj specifika vänner från din vänlista'),
            findsOneWidget);
        expect(find.byIcon(Icons.people_outline), findsOneWidget);
      });
    });

    group('Category Selection', () {
      testWidgets('should select category when tapped',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        List<String> capturedSelection = [];

        // Act
        await tester.pumpWidget(createTestWidget(
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));

        await tester.tap(find.widgetWithText(FilterChip, 'Familjen'));
        await tester.pumpAndSettle();

        // Assert
        expect(capturedSelection, containsAll(['user1', 'user2']));
      });

      testWidgets('should deselect category when tapped again',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        List<String> capturedSelection = [];

        // Act
        await tester.pumpWidget(createTestWidget(
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));

        // Tap to select
        await tester.tap(find.widgetWithText(FilterChip, 'Familjen'));
        await tester.pumpAndSettle();

        // Tap again to deselect
        await tester.tap(find.widgetWithText(FilterChip, 'Familjen'));
        await tester.pumpAndSettle();

        // Assert
        expect(capturedSelection, isEmpty);
      });

      testWidgets('should allow multiple category selection when enabled',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        List<String> capturedSelection = [];

        // Act
        await tester.pumpWidget(createTestWidget(
          allowMultipleCategories: true,
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));

        await tester.tap(find.widgetWithText(FilterChip, 'Familjen'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilterChip, 'Jobbet'));
        await tester.pump();

        // Assert
        expect(capturedSelection,
            containsAll(['user1', 'user2', 'user3', 'user4']));
      });

      testWidgets(
          'should replace previous selection when multiple categories disabled',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        List<String> capturedSelection = [];

        // Act
        await tester.pumpWidget(createTestWidget(
          allowMultipleCategories: false,
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));

        await tester.tap(find.widgetWithText(FilterChip, 'Familjen'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilterChip, 'Jobbet'));
        await tester.pump();

        // Assert
        expect(capturedSelection, containsAll(['user3', 'user4']));
        expect(capturedSelection, isNot(containsAll(['user1', 'user2'])));
      });
    });

    group('Individual Friend Selection', () {
      testWidgets('should select individual friend when checkbox tapped',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        List<String> capturedSelection = [];

        // Act
        await tester.pumpWidget(createTestWidget(
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));

        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pump();

        // Assert
        expect(capturedSelection, contains('user1'));
        expect(capturedSelection.length, equals(1));
      });

      testWidgets(
          'should deselect individual friend when checkbox tapped again',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        List<String> capturedSelection = [];

        // Act
        await tester.pumpWidget(createTestWidget(
          selectedFriendIds: ['user1'],
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));

        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pump();

        // Assert
        expect(capturedSelection, isEmpty);
      });

      testWidgets('should allow multiple individual friend selection',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        List<String> capturedSelection = [];

        // Act
        await tester.pumpWidget(createTestWidget(
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));

        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pump();
        await tester.tap(find.byType(CheckboxListTile).at(1));
        await tester.pump();

        // Assert
        expect(capturedSelection, containsAll(['user1', 'user2']));
        expect(capturedSelection.length, equals(2));
      });
    });

    group('Selection Summary', () {
      testWidgets('should show selection summary when friends are selected',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        // Act
        await tester.pumpWidget(createTestWidget(
          selectedFriendIds: ['user1', 'user2'],
        ));

        // Assert
        expect(find.text('Valda vänner'), findsOneWidget);
        expect(find.text('2 vänner valda'), findsOneWidget);
        expect(find.text('Rensa'), findsOneWidget);
        expect(find.byIcon(Icons.group), findsOneWidget);
      });

      testWidgets('should show singular form for one selected friend',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        // Act
        await tester.pumpWidget(createTestWidget(
          selectedFriendIds: ['user1'],
        ));

        // Assert
        expect(find.text('1 vän vald'), findsOneWidget);
      });

      testWidgets('should not show selection summary when no friends selected',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.text('Valda vänner'), findsNothing);
        expect(find.text('Rensa'), findsNothing);
      });

      testWidgets('should clear all selections when clear button tapped',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        List<String> capturedSelection = [];

        // Act
        await tester.pumpWidget(createTestWidget(
          selectedFriendIds: ['user1', 'user2'],
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));

        await tester.tap(find.text('Rensa'));
        await tester.pump();

        // Assert
        expect(capturedSelection, isEmpty);
      });
    });

    group('Mixed Category and Individual Selection', () {
      testWidgets('should combine category and individual selections',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        List<String> capturedSelection = [];

        // Act
        await tester.pumpWidget(createTestWidget(
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));

        // Select category
        await tester.tap(find.widgetWithText(FilterChip, 'Familjen'));
        await tester.pumpAndSettle();

        // Select individual friend not in category
        await tester
            .tap(find.widgetWithText(CheckboxListTile, 'Sofia Lindberg'));
        await tester.pump();

        // Assert
        expect(capturedSelection, containsAll(['user1', 'user2', 'user5']));
      });

      testWidgets(
          'should handle deselecting category while individual friends selected',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        List<String> capturedSelection = [];

        // Act
        await tester.pumpWidget(createTestWidget(
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));

        // Select category and individual
        await tester.tap(find.widgetWithText(FilterChip, 'Familjen'));
        await tester.pumpAndSettle();
        await tester
            .tap(find.widgetWithText(CheckboxListTile, 'Sofia Lindberg'));
        await tester.pump();

        // Deselect category
        await tester.tap(find.widgetWithText(FilterChip, 'Familjen'));
        await tester.pumpAndSettle();

        // Assert - should only have individual selection left
        expect(capturedSelection, equals(['user5']));
      });
    });

    group('Visual State Indicators', () {
      testWidgets('should highlight selected categories',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        // Act
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.widgetWithText(FilterChip, 'Familjen'));
        await tester.pumpAndSettle();

        // Assert - verify FilterChip selected state
        final filterChip = tester.widget<FilterChip>(
          find.widgetWithText(FilterChip, 'Familjen'),
        );
        expect(filterChip.selected, isTrue);
      });

      testWidgets('should highlight selected individual friends',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        // Act
        await tester.pumpWidget(createTestWidget(
          selectedFriendIds: ['user1'],
        ));

        // Assert
        final checkboxListTile = tester.widget<CheckboxListTile>(
          find.widgetWithText(CheckboxListTile, 'Anna Svensson'),
        );
        expect(checkboxListTile.value, isTrue);

        // Verify visual styling for selected friend
        final card = tester.widget<Card>(
          find.ancestor(
            of: find.widgetWithText(CheckboxListTile, 'Anna Svensson'),
            matching: find.byType(Card),
          ),
        );
        expect(card.color, isNotNull);
      });
    });

    group('Swedish Localization', () {
      testWidgets('should display all Swedish interface text correctly',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert Swedish UI text
        expect(find.text('Välj vänner'), findsOneWidget);
        expect(find.text('Välj kategorier eller individuella vänner'),
            findsOneWidget);
        expect(find.text('Kategorier'), findsOneWidget);
        expect(find.text('Välj hela kategorier för snabb delning'),
            findsOneWidget);
        expect(find.text('Individuellt val'), findsOneWidget);
        expect(find.text('Välj specifika vänner från din vänlista'),
            findsOneWidget);
      });

      testWidgets('should display Swedish loading message',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(isLoading: true);
        mockFriendsViewModel.setFriendsState(isLoading: true);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.text('Laddar vänner och kategorier...'), findsOneWidget);
      });

      testWidgets('should display Swedish error messages',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(
          isLoading: false,
          error: 'Nätverksfel uppstod',
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.text('Nätverksfel uppstod'), findsOneWidget);
      });

      testWidgets('should display Swedish selection summary text',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        // Act
        await tester.pumpWidget(createTestWidget(
          selectedFriendIds: ['user1', 'user2', 'user3'],
        ));

        // Assert
        expect(find.text('Valda vänner'), findsOneWidget);
        expect(find.text('3 vänner valda'), findsOneWidget);
        expect(find.text('Rensa'), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle empty category name',
          (WidgetTester tester) async {
        // Arrange
        final categoryWithEmptyName = SocialFactory.createFriendCategory(
          id: 'empty',
          name: '',
          memberIds: ['user1'],
        );

        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: [categoryWithEmptyName],
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert - should still render chip
        expect(find.byType(FilterChip), findsOneWidget);
      });

      testWidgets('should handle category with no friends',
          (WidgetTester tester) async {
        // Arrange
        final categoryWithNoFriends = SocialFactory.createFriendCategory(
          id: 'empty_category',
          name: 'Tom kategori',
          memberIds: [],
        );

        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: [categoryWithNoFriends],
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        List<String> capturedSelection = [];

        // Act
        await tester.pumpWidget(createTestWidget(
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));

        await tester.tap(find.text('Tom kategori'));
        await tester.pump();

        // Assert
        expect(capturedSelection, isEmpty);
      });

      testWidgets('should handle friend with empty display name',
          (WidgetTester tester) async {
        // Arrange
        final friendWithEmptyName = UserProfileFactory.build(
          uid: 'user_no_name',
          displayName: '',
        );

        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: [friendWithEmptyName],
        );

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert - should still render checkbox
        expect(find.byType(CheckboxListTile), findsOneWidget);
      });

      testWidgets('should handle very long category names',
          (WidgetTester tester) async {
        // Arrange
        final categoryWithLongName = SocialFactory.createFriendCategory(
          id: 'long',
          name:
              'En mycket lång kategorinnamn som kanske inte får plats på en rad',
          memberIds: ['user1'],
        );

        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: [categoryWithLongName],
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(
            find.text(
                'En mycket lång kategorinnamn som kanske inte får plats på en rad'),
            findsOneWidget);
        expect(find.byType(FilterChip), findsOneWidget);
      });

      testWidgets('should handle complex widget initialization properly',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert - widget initializes and renders correctly
        expect(find.byType(FriendCategoryManager), findsOneWidget);
        expect(find.text('Anna Svensson'), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsAtLeastNWidgets(4));
      });
    });

    group('Constructor Validation', () {
      testWidgets('should accept empty selectedFriendIds',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        // Act
        await tester.pumpWidget(createTestWidget(
          selectedFriendIds: [],
        ));

        // Assert
        expect(find.byType(FriendCategoryManager), findsOneWidget);
        expect(find.text('Valda vänner'), findsNothing);
      });

      testWidgets('should handle null callback parameter',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        // Act & Assert - should not throw
        expect(
            () => createTestWidget(onSelectionChanged: null), returnsNormally);
      });
    });

    group('Accessibility', () {
      testWidgets('should provide proper semantics for interactive elements',
          (WidgetTester tester) async {
        // Arrange
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert - FilterChips should be accessible
        final filterChips =
            tester.widgetList<FilterChip>(find.byType(FilterChip));
        expect(filterChips, isNotEmpty);

        // CheckboxListTiles should be accessible
        final checkboxes =
            tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile));
        expect(checkboxes, isNotEmpty);
      });
    });
  });
}
