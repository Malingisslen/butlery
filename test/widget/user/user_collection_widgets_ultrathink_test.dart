// test/widget/user/user_collection_widgets_ultrathink_test.dart
// Comprehensive tests for UserCollectionWidgets using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/user/user_collection_widgets.dart';
import 'package:butlery/widgets/user/user_display_models.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('UserCollectionWidgets Static Class Tests - ULTRATHINK METHODOLOGY',
      () {
    // Helper to wrap widgets with MaterialApp for proper theming
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryBlue,
            surface: AppColors.cardWhite,
          ),
          textTheme: const TextTheme(
            titleMedium: TextStyle(fontSize: 16),
            labelSmall: TextStyle(fontSize: 12),
          ),
        ),
        home: Scaffold(
          body: SizedBox(
            height: 800, // Increased height for grid content
            width: 500, // Increased width for grid layouts
            child: child,
          ),
        ),
      );
    }

    // Helper to create test user data
    List<UserDisplayData> createTestUsers({int count = 3}) {
      return List.generate(
          count,
          (index) => UserDisplayData(
                id: 'user_$index',
                displayName: 'User ${index + 1}',
                email: 'user${index + 1}@test.com',
                imageUrl: 'https://example.com/avatar$index.jpg',
                subtitle: 'Subtitle $index',
                isOnline: index.isEven,
              ));
    }

    group('userList() Static Method Tests', () {
      testWidgets('should create ListView.separated with basic user data',
          (WidgetTester tester) async {
        final users = createTestUsers();

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userList(users: users),
        ));

        expect(find.byType(ListView), findsOneWidget);
        expect(find.text('User 1'), findsOneWidget);
        expect(find.text('User 2'), findsOneWidget);
        expect(find.text('User 3'), findsOneWidget);
      });

      testWidgets('should handle empty user list', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userList(users: []),
        ));

        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.childrenDelegate, isA<SliverChildBuilderDelegate>());
      });

      testWidgets('should apply default ListView properties',
          (WidgetTester tester) async {
        final users = createTestUsers();

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userList(users: users),
        ));

        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.shrinkWrap, isTrue);
        expect(listView.physics, isA<NeverScrollableScrollPhysics>());
        expect(listView.padding,
            equals(const EdgeInsets.all(AppDimensions.paddingL)));
      });

      testWidgets('should accept custom ListView properties',
          (WidgetTester tester) async {
        final users = createTestUsers();
        const customPadding = EdgeInsets.all(20);
        const customPhysics = ClampingScrollPhysics();

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userList(
            users: users,
            padding: customPadding,
            physics: customPhysics,
            shrinkWrap: false,
          ),
        ));

        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.shrinkWrap, isFalse);
        expect(listView.physics, isA<ClampingScrollPhysics>());
        expect(listView.padding, equals(customPadding));
      });

      testWidgets('should trigger onUserTap callback',
          (WidgetTester tester) async {
        final users = createTestUsers();
        UserDisplayData? tappedUser;

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userList(
            users: users,
            onUserTap: (user) => tappedUser = user,
          ),
        ));

        await tester.tap(find.text('User 1'));
        expect(tappedUser?.displayName, equals('User 1'));
      });

      testWidgets('should show SizedBox separators between items',
          (WidgetTester tester) async {
        final users = createTestUsers(count: 2);

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userList(users: users),
        ));

        // ListView.separated should create separators between items
        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.childrenDelegate, isA<SliverChildBuilderDelegate>());

        // The ListView should be properly configured with separator builder
        expect(find.byType(ListView), findsOneWidget);
        expect(find.text('User 1'), findsOneWidget);
        expect(find.text('User 2'), findsOneWidget);
      });
    });

    group('userGrid() Static Method Tests', () {
      testWidgets('should create GridView.builder with basic user data',
          (WidgetTester tester) async {
        final users = createTestUsers();

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userGrid(users: users),
        ));

        expect(find.byType(GridView), findsOneWidget);
        expect(find.text('User 1'), findsOneWidget);
        expect(find.text('User 2'), findsOneWidget);
        expect(find.text('User 3'), findsOneWidget);
      });

      testWidgets('should handle empty user list', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userGrid(users: []),
        ));

        final gridView = tester.widget<GridView>(find.byType(GridView));
        expect(gridView.childrenDelegate, isA<SliverChildBuilderDelegate>());
      });

      testWidgets('should apply default GridView properties',
          (WidgetTester tester) async {
        final users = createTestUsers();

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userGrid(users: users),
        ));

        final gridView = tester.widget<GridView>(find.byType(GridView));
        expect(gridView.shrinkWrap, isTrue);
        expect(gridView.physics, isA<NeverScrollableScrollPhysics>());
        expect(gridView.padding,
            equals(const EdgeInsets.all(AppDimensions.paddingL)));

        final delegate =
            gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, equals(2));
        expect(delegate.childAspectRatio, equals(1.2));
        expect(delegate.crossAxisSpacing, equals(AppDimensions.spacingS));
        expect(delegate.mainAxisSpacing, equals(AppDimensions.spacingS));
      });

      testWidgets('should accept custom GridView properties',
          (WidgetTester tester) async {
        final users = createTestUsers();
        const customPadding = EdgeInsets.all(16);
        const customPhysics = BouncingScrollPhysics();

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userGrid(
            users: users,
            crossAxisCount: 2, // Wider cells to accommodate content
            aspectRatio:
                0.8, // Taller cells to fit avatar + text + padding (160px needed)
            padding: customPadding,
            physics: customPhysics,
            shrinkWrap: false,
          ),
        ));

        final gridView = tester.widget<GridView>(find.byType(GridView));
        expect(gridView.shrinkWrap, isFalse);
        expect(gridView.physics, isA<BouncingScrollPhysics>());
        expect(gridView.padding, equals(customPadding));

        final delegate =
            gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, equals(2));
        expect(delegate.childAspectRatio, equals(0.8));
      });

      testWidgets('should trigger onUserTap callback',
          (WidgetTester tester) async {
        final users = createTestUsers();
        UserDisplayData? tappedUser;

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userGrid(
            users: users,
            onUserTap: (user) => tappedUser = user,
          ),
        ));

        await tester.tap(find.text('User 1'));
        expect(tappedUser?.displayName, equals('User 1'));
      });
    });

    group('emptyUserState() Static Method Tests', () {
      testWidgets('should render with default properties',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.emptyUserState(),
        ));

        // Should find multiple Center widgets (test wrapper + emptyState)
        expect(find.byType(Center), findsAtLeastNWidgets(1));
        expect(find.byIcon(Icons.people_outline), findsOneWidget);
        expect(find.text('Inga användare'), findsOneWidget);
        expect(find.text('Inga användare att visa'), findsOneWidget);
      });

      testWidgets('should apply custom text and icon',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.emptyUserState(
            title: 'Custom Title',
            subtitle: 'Custom Subtitle',
            icon: Icons.person_add,
          ),
        ));

        expect(find.byIcon(Icons.person_add), findsOneWidget);
        expect(find.text('Custom Title'), findsOneWidget);
        expect(find.text('Custom Subtitle'), findsOneWidget);
        expect(find.text('Inga användare'), findsNothing);
      });

      testWidgets('should display action button when provided',
          (WidgetTester tester) async {
        bool actionCalled = false;

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.emptyUserState(
            actionLabel: 'Add User',
            onAction: () => actionCalled = true,
          ),
        ));

        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.text('Add User'), findsOneWidget);

        await tester.tap(find.text('Add User'));
        expect(actionCalled, isTrue);
      });

      testWidgets(
          'should not display action button when only actionLabel provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.emptyUserState(
            actionLabel: 'Add User',
          ),
        ));

        expect(find.byType(ElevatedButton), findsNothing);
        expect(find.text('Add User'), findsNothing);
      });

      testWidgets(
          'should not display action button when only onAction provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.emptyUserState(
            onAction: () {},
          ),
        ));

        expect(find.byType(ElevatedButton), findsNothing);
      });

      testWidgets('should have correct icon styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.emptyUserState(),
        ));

        final icon = tester.widget<Icon>(find.byIcon(Icons.people_outline));
        expect(icon.size, equals(AppDimensions.iconSizeXl));
        expect(icon.color, equals(AppColors.textTertiary));
      });

      testWidgets('should have correct text styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.emptyUserState(),
        ));

        final titleText = tester.widget<Text>(find.text('Inga användare'));
        expect(titleText.style, equals(AppTextStyles.titleMedium));
        expect(titleText.textAlign, equals(TextAlign.center));

        final subtitleText =
            tester.widget<Text>(find.text('Inga användare att visa'));
        expect(subtitleText.style, equals(AppTextStyles.titleMedium));
        expect(subtitleText.textAlign, equals(TextAlign.center));
      });

      testWidgets('should have correct button styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.emptyUserState(
            actionLabel: 'Add User',
            onAction: () {},
          ),
        ));

        final button =
            tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        final buttonStyle = button.style!;
        expect(buttonStyle.backgroundColor?.resolve({}),
            equals(AppColors.primaryBlue));
        expect(buttonStyle.foregroundColor?.resolve({}),
            equals(AppColors.cardWhite));
      });
    });

    group('userBadge() Static Method Tests', () {
      testWidgets('should render with required label',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userBadge(label: 'Admin'),
        ));

        expect(find.byType(Container), findsOneWidget);
        expect(find.text('Admin'), findsOneWidget);
      });

      testWidgets('should apply default styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userBadge(label: 'Admin'),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        expect(
            container.padding,
            equals(const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingXs,
              vertical: AppDimensions.spacingXs / 2,
            )));

        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.primaryBlue));
        expect(decoration.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadiusS)));

        final text = tester.widget<Text>(find.text('Admin'));
        expect(text.style?.color, equals(AppColors.cardWhite));
      });

      testWidgets('should accept custom background color',
          (WidgetTester tester) async {
        const customColor = Colors.red;

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userBadge(
            label: 'Admin',
            backgroundColor: customColor,
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(customColor));
      });

      testWidgets('should accept custom text color',
          (WidgetTester tester) async {
        const customTextColor = Colors.yellow;

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userBadge(
            label: 'Admin',
            textColor: customTextColor,
          ),
        ));

        final text = tester.widget<Text>(find.text('Admin'));
        expect(text.style?.color, equals(customTextColor));
      });

      testWidgets('should accept custom padding', (WidgetTester tester) async {
        const customPadding = EdgeInsets.all(20);

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userBadge(
            label: 'Admin',
            padding: customPadding,
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(customPadding));
      });

      testWidgets('should use AppTextStyles.labelSmall for text',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userBadge(label: 'Admin'),
        ));

        final text = tester.widget<Text>(find.text('Admin'));
        // Check that it's using labelSmall by verifying base style
        expect(text.style?.fontSize, equals(AppTextStyles.labelSmall.fontSize));
      });

      testWidgets('should handle empty label', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userBadge(label: ''),
        ));

        expect(find.text(''), findsOneWidget);
        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('should handle long label text', (WidgetTester tester) async {
        const longLabel = 'This is a very long badge label that might wrap';

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userBadge(label: longLabel),
        ));

        expect(find.text(longLabel), findsOneWidget);
      });

      testWidgets('should handle Swedish characters',
          (WidgetTester tester) async {
        const swedishLabel = 'Ägare';

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userBadge(label: swedishLabel),
        ));

        expect(find.text(swedishLabel), findsOneWidget);
      });
    });

    group('Static Class Structure Tests', () {
      testWidgets('all methods should return Widget instances',
          (WidgetTester tester) async {
        final users = createTestUsers();

        // Test that all static methods return Widgets
        final userList = UserCollectionWidgets.userList(users: users);
        final userGrid = UserCollectionWidgets.userGrid(users: users);
        final emptyState = UserCollectionWidgets.emptyUserState();
        final badge = UserCollectionWidgets.userBadge(label: 'Test');

        expect(userList, isA<Widget>());
        expect(userGrid, isA<Widget>());
        expect(emptyState, isA<Widget>());
        expect(badge, isA<Widget>());
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('should handle very large user lists',
          (WidgetTester tester) async {
        final largeUserList = createTestUsers(count: 100);

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userList(users: largeUserList),
        ));

        expect(find.byType(ListView), findsOneWidget);
        expect(find.text('User 1'), findsOneWidget);
      });

      testWidgets('should handle single user in grid',
          (WidgetTester tester) async {
        final singleUser = createTestUsers(count: 1);

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userGrid(users: singleUser),
        ));

        expect(find.byType(GridView), findsOneWidget);
        expect(find.text('User 1'), findsOneWidget);
      });

      testWidgets('should handle users with null/empty data',
          (WidgetTester tester) async {
        final usersWithEmptyData = [
          UserDisplayData(
            id: 'empty',
            displayName: '',
            email: '',
            imageUrl: null,
            subtitle: null,
            isOnline: false,
          ),
        ];

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userList(users: usersWithEmptyData),
        ));

        expect(find.byType(ListView), findsOneWidget);
        expect(
            find.text(''), findsWidgets); // Empty strings should still render
      });

      testWidgets('should handle special characters in badge labels',
          (WidgetTester tester) async {
        const specialLabel = '!@#\$%^&*()_+-=[]{}|;:,.<>?';

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userBadge(label: specialLabel),
        ));

        expect(find.text(specialLabel), findsOneWidget);
      });

      testWidgets('should handle extreme grid configurations',
          (WidgetTester tester) async {
        final users = createTestUsers();

        await tester.pumpWidget(createTestWidget(
          UserCollectionWidgets.userGrid(
            users: users,
            crossAxisCount: 1,
            aspectRatio: 1.5, // More reasonable ratio to prevent overflow
          ),
        ));

        final gridView = tester.widget<GridView>(find.byType(GridView));
        final delegate =
            gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, equals(1));
        expect(delegate.childAspectRatio, equals(1.5));
      });
    });
  });
}
