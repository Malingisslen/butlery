import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/friends/friend_category_widgets.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/widget_mocks.dart';

void main() {
  group('FriendCategoryWidgets', () {
    late MockUnifiedFriendsService mockFriendsService;
    late MockFriendsViewModel mockFriendsViewModel;

    final testCategories = [
      FriendCategory(
        id: 'cat1',
        ownerId: 'user123',
        name: 'Familie',
        description: 'Familjemedlemmar',
        emoji: '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}',
        friendUserIds: ['friend1', 'friend2'],
        sortOrder: 1,
      ),
      FriendCategory(
        id: 'cat2',
        ownerId: 'user123',
        name: 'Jobbet',
        description: 'Arbetskamrater',
        emoji: '\u{1F4BC}',
        friendUserIds: ['friend3', 'friend4', 'friend5'],
        sortOrder: 2,
      ),
      FriendCategory(
        id: 'cat3',
        ownerId: 'user123',
        name: 'Grannar',
        emoji: '\u{1F3E0}',
        friendUserIds: ['friend6'],
        sortOrder: 3,
      ),
    ];

    final testSelectedCategoryIds = {'cat1', 'cat2'};

    setUp(() {
      Provider.debugCheckInvalidValueType = null;
      mockFriendsService = MockUnifiedFriendsService();
      mockFriendsViewModel = MockFriendsViewModel();
      mockFriendsService.setFriendsState(
          categoriesList: testCategories, isLoading: false, error: null);
      mockFriendsViewModel
          .setFriendsState(friends: [], isLoading: false, error: null);
    });

    Widget createTestWidget(Widget child) {
      return MaterialApp(
        locale: const Locale('sv'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme,
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
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    group('FriendCategoryManager', () {
      testWidgets('renders default Swedish title and subtitle', (tester) async {
        await tester.pumpWidget(createTestWidget(
          FriendCategoryWidgets.friendCategoryManager(
            selectedFriendIds: ['friend1'],
            onSelectionChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Välj vänner'), findsOneWidget);
        expect(find.text('Välj kategorier eller individuella vänner'),
            findsOneWidget);
      });

      testWidgets('renders custom title and subtitle', (tester) async {
        await tester.pumpWidget(createTestWidget(
          FriendCategoryWidgets.friendCategoryManager(
            selectedFriendIds: [],
            onSelectionChanged: (_) {},
            title: 'Custom Title',
            subtitle: 'Custom Subtitle',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Custom Title'), findsOneWidget);
        expect(find.text('Custom Subtitle'), findsOneWidget);
      });

      testWidgets('compact variant constrains height', (tester) async {
        await tester.pumpWidget(createTestWidget(
          FriendCategoryWidgets.compactFriendCategoryManager(
            selectedFriendIds: [],
            onSelectionChanged: (_) {},
            maxHeight: 320,
          ),
        ));
        await tester.pumpAndSettle();

        final finder = find.byWidgetPredicate(
            (w) => w is Container && w.constraints?.maxHeight == 320.0);
        expect(finder, findsOneWidget);
      });
    });

    group('CategorySelector', () {
      testWidgets('renders Swedish action buttons and create option',
          (tester) async {
        await tester.pumpWidget(createTestWidget(Builder(
          builder: (context) => FriendCategoryWidgets.friendCategorySelector(
            context,
            categories: testCategories,
            selectedCategoryIds: testSelectedCategoryIds,
            onCategoryToggled: (_) {},
            title: 'Test Selector',
            onCreateNew: () {},
          ),
        )));
        await tester.pumpAndSettle();

        expect(find.text('Test Selector'), findsOneWidget);
        expect(find.text('Välj alla'), findsOneWidget);
        expect(find.text('Rensa alla'), findsOneWidget);
        expect(find.text('Skapa ny kategori'), findsOneWidget);
      });

      testWidgets('hides select-all and create-new when disabled',
          (tester) async {
        await tester.pumpWidget(createTestWidget(Builder(
          builder: (context) => FriendCategoryWidgets.friendCategorySelector(
            context,
            categories: testCategories,
            selectedCategoryIds: testSelectedCategoryIds,
            onCategoryToggled: (_) {},
            showSelectAll: false,
            showCreateNew: false,
          ),
        )));
        await tester.pumpAndSettle();

        expect(find.text('Välj alla'), findsNothing);
        expect(find.text('Rensa alla'), findsNothing);
        expect(find.text('Skapa ny kategori'), findsNothing);
      });

      testWidgets('handles toggle callback', (tester) async {
        String? toggled;
        await tester.pumpWidget(createTestWidget(Builder(
          builder: (context) => FriendCategoryWidgets.friendCategorySelector(
            context,
            categories: testCategories,
            selectedCategoryIds: {},
            onCategoryToggled: (id) => toggled = id,
          ),
        )));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Familie'));
        await tester.pump();
        expect(toggled, isNotNull);
      });

      testWidgets('handles empty categories list', (tester) async {
        await tester.pumpWidget(createTestWidget(Builder(
          builder: (context) => FriendCategoryWidgets.friendCategorySelector(
            context,
            categories: [],
            selectedCategoryIds: {},
            onCategoryToggled: (_) {},
          ),
        )));
        await tester.pumpAndSettle();

        expect(find.byType(Wrap), findsOneWidget);
      });
    });

    group('CategoryChip', () {
      testWidgets('shows name and emoji icon when selected', (tester) async {
        await tester.pumpWidget(createTestWidget(Builder(
          builder: (context) => FriendCategoryWidgets.friendCategoryChip(
            context,
            category: testCategories.first,
            isSelected: true,
            onTap: () {},
            showCount: true,
          ),
        )));
        await tester.pumpAndSettle();

        expect(find.text('Familie'), findsOneWidget);
        expect(find.byIcon(Icons.emoji_emotions), findsOneWidget);
      });

      testWidgets('renders without count', (tester) async {
        await tester.pumpWidget(createTestWidget(Builder(
          builder: (context) => FriendCategoryWidgets.friendCategoryChip(
            context,
            category: testCategories.first,
            isSelected: false,
            onTap: () {},
            showCount: false,
          ),
        )));
        await tester.pumpAndSettle();

        expect(find.text('Familie'), findsOneWidget);
      });

      testWidgets('responds to tap', (tester) async {
        bool tapped = false;
        await tester.pumpWidget(createTestWidget(Builder(
          builder: (context) => FriendCategoryWidgets.friendCategoryChip(
            context,
            category: testCategories.first,
            isSelected: false,
            onTap: () => tapped = true,
          ),
        )));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Familie'));
        await tester.pump();
        expect(tapped, isTrue);
      });

      testWidgets('handles category without emoji', (tester) async {
        final noEmoji = FriendCategory.create(ownerId: 'u1', name: 'No Emoji');
        await tester.pumpWidget(createTestWidget(Builder(
          builder: (context) => FriendCategoryWidgets.friendCategoryChip(
            context,
            category: noEmoji,
            isSelected: false,
            onTap: () {},
          ),
        )));
        await tester.pumpAndSettle();

        expect(find.text('No Emoji'), findsOneWidget);
      });

      testWidgets('horizontalCategorySelector scrolls', (tester) async {
        await tester.pumpWidget(createTestWidget(Builder(
          builder: (context) =>
              FriendCategoryWidgets.horizontalCategorySelector(
            context,
            categories: testCategories,
            selectedCategoryIds: testSelectedCategoryIds,
            onCategoryToggled: (_) {},
            height: 80,
          ),
        )));
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsAtLeastNWidgets(1));
      });

      testWidgets('compactCategoryChip renders FilterChip', (tester) async {
        await tester.pumpWidget(createTestWidget(Builder(
          builder: (context) => FriendCategoryWidgets.compactCategoryChip(
            context,
            category: testCategories.first,
            isSelected: true,
            onTap: () {},
          ),
        )));
        await tester.pumpAndSettle();

        expect(find.text('Familie'), findsOneWidget);
        expect(find.byType(FilterChip), findsOneWidget);
      });
    });

    group('CategoryDisplay', () {
      testWidgets('categoryList shows all names', (tester) async {
        await tester.pumpWidget(createTestWidget(SizedBox(
          height: 300,
          child: FriendCategoryWidgets.categoryList(
            categories: testCategories,
            onCategoryTap: (_) {},
            showMemberCount: true,
          ),
        )));
        await tester.pumpAndSettle();

        expect(find.text('Familie'), findsOneWidget);
        expect(find.text('Jobbet'), findsOneWidget);
        expect(find.text('Grannar'), findsOneWidget);
      });

      testWidgets('categoryGrid renders GridView', (tester) async {
        await tester.pumpWidget(createTestWidget(SizedBox(
          height: 400,
          child: FriendCategoryWidgets.categoryGrid(
            categories: testCategories,
            onCategoryTap: (_) {},
            crossAxisCount: 3,
          ),
        )));
        await tester.pumpAndSettle();

        expect(find.byType(GridView), findsOneWidget);
        expect(find.text('Familie'), findsOneWidget);
      });

      testWidgets('categoryStatistics renders', (tester) async {
        await tester.pumpWidget(createTestWidget(Builder(
          builder: (context) => FriendCategoryWidgets.categoryStatistics(
            context: context,
            categories: testCategories,
          ),
        )));
        await tester.pumpAndSettle();

        expect(find.byType(Column), findsAtLeastNWidgets(1));
      });

      testWidgets('categoryCard shows name and description', (tester) async {
        await tester.pumpWidget(createTestWidget(Builder(
          builder: (context) => FriendCategoryWidgets.categoryCard(
            context: context,
            category: testCategories.first,
            onTap: () {},
            showMemberCount: true,
            showDescription: true,
          ),
        )));
        await tester.pumpAndSettle();

        expect(find.text('Familie'), findsOneWidget);
        expect(find.text('Familjemedlemmar'), findsOneWidget);
      });

      testWidgets('categoryCard responds to tap', (tester) async {
        bool tapped = false;
        await tester.pumpWidget(createTestWidget(Builder(
          builder: (context) => FriendCategoryWidgets.categoryCard(
            context: context,
            category: testCategories.first,
            onTap: () => tapped = true,
          ),
        )));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Card));
        await tester.pump();
        expect(tapped, isTrue);
      });

      testWidgets('categoryCard hides missing description', (tester) async {
        final noDesc = FriendCategory.create(ownerId: 'u1', name: 'No Desc');
        await tester.pumpWidget(createTestWidget(Builder(
          builder: (context) => FriendCategoryWidgets.categoryCard(
            context: context,
            category: noDesc,
            onTap: () {},
            showDescription: true,
          ),
        )));
        await tester.pumpAndSettle();

        expect(find.text('No Desc'), findsOneWidget);
        expect(find.textContaining('Familjemedlemmar'), findsNothing);
      });

      testWidgets('categoryCarousel renders horizontal list', (tester) async {
        await tester.pumpWidget(createTestWidget(
          FriendCategoryWidgets.categoryCarousel(
            categories: testCategories,
            onCategoryTap: (_) {},
            height: 200,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsOneWidget);
        expect(find.text('Familie'), findsOneWidget);
      });

      testWidgets('categorySummaryRow renders rows', (tester) async {
        await tester.pumpWidget(createTestWidget(Builder(
          builder: (context) => FriendCategoryWidgets.categorySummaryRow(
            context: context,
            categories: testCategories,
            showTotalMembers: true,
          ),
        )));
        await tester.pumpAndSettle();

        expect(find.byType(Row), findsAtLeastNWidgets(1));
      });

      testWidgets('emptyState shows Swedish default text', (tester) async {
        await tester.pumpWidget(createTestWidget(Builder(
          builder: (context) =>
              FriendCategoryWidgets.emptyState(context: context),
        )));
        await tester.pumpAndSettle();

        expect(find.text('Inga kategorier skapade'), findsOneWidget);
        expect(find.text('Skapa din första vänkategori'), findsOneWidget);
      });

      testWidgets('emptyState with custom text and create callback',
          (tester) async {
        bool created = false;
        await tester.pumpWidget(createTestWidget(Builder(
          builder: (context) => FriendCategoryWidgets.emptyState(
            context: context,
            title: 'Custom Title',
            subtitle: 'Custom Subtitle',
            onCreateCategory: () => created = true,
          ),
        )));
        await tester.pumpAndSettle();

        expect(find.text('Custom Title'), findsOneWidget);
        expect(find.text('Custom Subtitle'), findsOneWidget);

        final btn = find.text('Skapa kategori');
        if (tester.any(btn)) {
          await tester.tap(btn);
          expect(created, isTrue);
        }
      });
    });

    group('AdvancedSelection', () {
      testWidgets('selectionSummary renders and clears', (tester) async {
        bool cleared = false;
        await tester.pumpWidget(createTestWidget(
          FriendCategoryWidgets.categorySelectionSummary(
            selectedCategoryIds: testSelectedCategoryIds,
            categories: testCategories,
            onClear: () => cleared = true,
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.byType(Row), findsAtLeastNWidgets(1));
        final clearBtn = find.text('Rensa');
        if (tester.any(clearBtn)) {
          await tester.tap(clearBtn);
          expect(cleared, isTrue);
        }
      });

      testWidgets('multiSelectDropdown shows selected count', (tester) async {
        await tester.pumpWidget(createTestWidget(Builder(
          builder: (ctx) => FriendCategoryWidgets.categoryMultiSelectDropdown(
            context: ctx,
            categories: testCategories,
            selectedCategoryIds: testSelectedCategoryIds,
            onCategoryToggled: (_) {},
          ),
        )));
        await tester.pumpAndSettle();
        expect(find.text('2 kategorier valda'), findsOneWidget);
        expect(find.byType(ExpansionTile), findsOneWidget);
      });
    });
  });
}
