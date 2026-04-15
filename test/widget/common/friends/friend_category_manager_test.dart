// test/widget/common/friends/friend_category_manager_test.dart
// Widget tests for FriendCategoryManager — rewritten to match current production widget

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/widgets/common/friends/friend_category_manager.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/widget_mocks.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/factories/social_factory.dart';
import '../../../infrastructure/factories/user_profile_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('FriendCategoryManager Tests', () {
    late MockUnifiedFriendsService mockFriendsService;
    late MockFriendsViewModel mockFriendsViewModel;

    late List<FriendCategory> testCategories;
    late List<UserProfile> testFriends;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await BaseUnitTest.setupUnit();
      // UnifiedFriendsService is not a ChangeNotifier in production,
      // but our mock extends Mock with ChangeNotifier. Suppress the
      // Provider debug check so Provider.value works with the mock.
      Provider.debugCheckInvalidValueType = null;
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      mockFriendsService = MockUnifiedFriendsService();
      mockFriendsViewModel = MockFriendsViewModel();

      // Stub refresh() — called in initState via postFrameCallback
      when(() => mockFriendsService.refresh()).thenAnswer((_) async {});

      testCategories = [
        SocialFactory.createFriendCategory(
          id: 'family',
          name: 'Familjen',
          emoji: '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}',
          memberIds: ['user1', 'user2'],
        ),
        SocialFactory.createFriendCategory(
          id: 'work',
          name: 'Jobbet',
          emoji: '\u{1F4BC}',
          memberIds: ['user3', 'user4'],
        ),
        SocialFactory.createFriendCategory(
          id: 'friends',
          name: 'Kompisar',
          emoji: '\u{1F389}',
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

    Widget createTestWidget({
      List<String> selectedFriendIds = const [],
      Function(List<String>)? onSelectionChanged,
      bool allowMultipleCategories = true,
      String? title,
      String? subtitle,
    }) {
      return createLocalizedTestApp(
        wrapInScaffold: false,
        child: Scaffold(
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
              height: 600,
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

    group('Loading States', () {
      testWidgets('shows loading indicator when services are loading',
          (WidgetTester tester) async {
        mockFriendsService.setFriendsState(isLoading: true);
        mockFriendsViewModel.setFriendsState(isLoading: true);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows loading when only categories service loading',
          (WidgetTester tester) async {
        mockFriendsService.setFriendsState(isLoading: true);
        mockFriendsViewModel.setFriendsState(
            isLoading: false, friends: testFriends);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows loading when only friends VM loading',
          (WidgetTester tester) async {
        mockFriendsService.setFriendsState(
            isLoading: false, categoriesList: testCategories);
        mockFriendsViewModel.setFriendsState(isLoading: true);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Error States', () {
      testWidgets('shows error message when categories service has error',
          (WidgetTester tester) async {
        mockFriendsService.setFriendsState(
          isLoading: false,
          error: 'Test error message',
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.text('Test error message'), findsOneWidget);
      });
    });

    group('Empty States', () {
      testWidgets('shows empty state when no categories or friends',
          (WidgetTester tester) async {
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byIcon(Icons.people_outline), findsOneWidget);
      });

      testWidgets('shows categories section only when friends are empty',
          (WidgetTester tester) async {
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.text('Familjen'), findsOneWidget);
        expect(find.byType(FilterChip), findsNWidgets(3));
      });

      testWidgets('shows friends section only when categories are empty',
          (WidgetTester tester) async {
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.text('Anna Svensson'), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNWidgets(5));
      });
    });

    group('Category Display', () {
      testWidgets('displays category chips with emoji and member count',
          (WidgetTester tester) async {
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.text('Familjen'), findsOneWidget);
        expect(find.text('Jobbet'), findsOneWidget);
        expect(find.text('Kompisar'), findsOneWidget);
        expect(find.byType(FilterChip), findsNWidgets(3));
        // Member counts: family=2, work=2, friends=1
        expect(find.text('2'), findsNWidgets(2));
        expect(find.text('1'), findsOneWidget);
      });

      testWidgets('shows category section header icon',
          (WidgetTester tester) async {
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byIcon(Icons.category_outlined), findsOneWidget);
      });
    });

    group('Individual Friends Display', () {
      testWidgets('displays friends list with checkboxes',
          (WidgetTester tester) async {
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Anna Svensson'), findsOneWidget);
        expect(find.text('Erik Johansson'), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNWidgets(5));
      });

      testWidgets('shows friends section header icon',
          (WidgetTester tester) async {
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byIcon(Icons.people_outline), findsOneWidget);
      });
    });

    group('Category Selection', () {
      testWidgets('selects category and fires callback with member IDs',
          (WidgetTester tester) async {
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        List<String> capturedSelection = [];

        await tester.pumpWidget(createTestWidget(
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));
        await tester.pump();

        await tester.tap(find.widgetWithText(FilterChip, 'Familjen'));
        await tester.pumpAndSettle();

        expect(capturedSelection, containsAll(['user1', 'user2']));
      });

      testWidgets('deselects category on second tap',
          (WidgetTester tester) async {
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        List<String> capturedSelection = [];

        await tester.pumpWidget(createTestWidget(
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));
        await tester.pump();

        await tester.tap(find.widgetWithText(FilterChip, 'Familjen'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilterChip, 'Familjen'));
        await tester.pumpAndSettle();

        expect(capturedSelection, isEmpty);
      });

      testWidgets('allows multiple category selection when enabled',
          (WidgetTester tester) async {
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        List<String> capturedSelection = [];

        await tester.pumpWidget(createTestWidget(
          allowMultipleCategories: true,
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));
        await tester.pump();

        await tester.tap(find.widgetWithText(FilterChip, 'Familjen'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilterChip, 'Jobbet'));
        await tester.pump();

        expect(capturedSelection,
            containsAll(['user1', 'user2', 'user3', 'user4']));
      });

      testWidgets('replaces selection when multiple categories disabled',
          (WidgetTester tester) async {
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        List<String> capturedSelection = [];

        await tester.pumpWidget(createTestWidget(
          allowMultipleCategories: false,
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));
        await tester.pump();

        await tester.tap(find.widgetWithText(FilterChip, 'Familjen'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilterChip, 'Jobbet'));
        await tester.pump();

        expect(capturedSelection, containsAll(['user3', 'user4']));
        expect(capturedSelection, isNot(contains('user1')));
      });
    });

    group('Individual Friend Selection', () {
      testWidgets('selects friend via checkbox', (WidgetTester tester) async {
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        List<String> capturedSelection = [];

        await tester.pumpWidget(createTestWidget(
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pump();

        expect(capturedSelection, contains('user1'));
        expect(capturedSelection.length, equals(1));
      });

      testWidgets('deselects friend on second tap',
          (WidgetTester tester) async {
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        List<String> capturedSelection = [];

        await tester.pumpWidget(createTestWidget(
          selectedFriendIds: ['user1'],
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pump();

        expect(capturedSelection, isEmpty);
      });

      testWidgets('allows multiple friend selection',
          (WidgetTester tester) async {
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        List<String> capturedSelection = [];

        await tester.pumpWidget(createTestWidget(
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pump();
        await tester.tap(find.byType(CheckboxListTile).at(1));
        await tester.pump();

        expect(capturedSelection, containsAll(['user1', 'user2']));
        expect(capturedSelection.length, equals(2));
      });
    });

    group('Selection Summary', () {
      testWidgets('shows summary when friends are pre-selected',
          (WidgetTester tester) async {
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        await tester.pumpWidget(createTestWidget(
          selectedFriendIds: ['user1', 'user2'],
        ));
        await tester.pump();

        expect(find.byIcon(Icons.group), findsOneWidget);
        expect(find.byIcon(Icons.clear), findsOneWidget);
      });

      testWidgets('hides summary when no friends selected',
          (WidgetTester tester) async {
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byIcon(Icons.group), findsNothing);
      });

      testWidgets('clear button resets all selections',
          (WidgetTester tester) async {
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        List<String> capturedSelection = ['user1', 'user2'];

        await tester.pumpWidget(createTestWidget(
          selectedFriendIds: ['user1', 'user2'],
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));
        await tester.pump();

        // Tap the clear button (TextButton.icon with Icons.clear)
        await tester.tap(find.byIcon(Icons.clear));
        await tester.pump();

        expect(capturedSelection, isEmpty);
      });
    });

    group('Mixed Selection', () {
      testWidgets('combines category and individual selections',
          (WidgetTester tester) async {
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        List<String> capturedSelection = [];

        await tester.pumpWidget(createTestWidget(
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));
        await tester.pumpAndSettle();

        // Select category
        await tester.tap(find.widgetWithText(FilterChip, 'Familjen'));
        await tester.pumpAndSettle();

        // Select individual friend not in category
        await tester
            .tap(find.widgetWithText(CheckboxListTile, 'Sofia Lindberg'));
        await tester.pump();

        expect(capturedSelection, containsAll(['user1', 'user2', 'user5']));
      });
    });

    group('Visual State', () {
      testWidgets('FilterChip reflects selected state',
          (WidgetTester tester) async {
        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: testCategories,
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        await tester.tap(find.widgetWithText(FilterChip, 'Familjen'));
        await tester.pumpAndSettle();

        final chip = tester.widget<FilterChip>(
          find.widgetWithText(FilterChip, 'Familjen'),
        );
        expect(chip.selected, isTrue);
      });

      testWidgets('CheckboxListTile reflects pre-selected state',
          (WidgetTester tester) async {
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
          isLoading: false,
          friends: testFriends,
        );

        await tester.pumpWidget(createTestWidget(
          selectedFriendIds: ['user1'],
        ));
        await tester.pumpAndSettle();

        final checkbox = tester.widget<CheckboxListTile>(
          find.widgetWithText(CheckboxListTile, 'Anna Svensson'),
        );
        expect(checkbox.value, isTrue);
      });
    });

    group('Edge Cases', () {
      testWidgets('handles empty category name', (WidgetTester tester) async {
        final emptyNameCategory = SocialFactory.createFriendCategory(
          id: 'empty',
          name: '',
          memberIds: ['user1'],
        );

        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: [emptyNameCategory],
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byType(FilterChip), findsOneWidget);
      });

      testWidgets('handles category with no friends',
          (WidgetTester tester) async {
        final emptyCategory = SocialFactory.createFriendCategory(
          id: 'empty_cat',
          name: 'Tom kategori',
          memberIds: [],
        );

        mockFriendsService.setFriendsState(
          isLoading: false,
          categoriesList: [emptyCategory],
        );
        mockFriendsViewModel.setFriendsState(isLoading: false, friends: []);

        List<String> capturedSelection = [];

        await tester.pumpWidget(createTestWidget(
          onSelectionChanged: (selection) => capturedSelection = selection,
        ));
        await tester.pump();

        await tester.tap(find.text('Tom kategori'));
        await tester.pump();

        expect(capturedSelection, isEmpty);
      });

      testWidgets('renders with custom title', (WidgetTester tester) async {
        mockFriendsService
            .setFriendsState(isLoading: false, categoriesList: []);
        mockFriendsViewModel.setFriendsState(
            isLoading: false, friends: testFriends);

        await tester.pumpWidget(createTestWidget(
          title: 'Custom Title',
        ));
        await tester.pump();

        expect(find.text('Custom Title'), findsOneWidget);
      });
    });
  });
}
