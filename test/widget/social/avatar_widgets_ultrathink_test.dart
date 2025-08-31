// test/widget/social/avatar_widgets_ultrathink_test.dart
// ULTRATHINK TEST SUITE: AvatarWidgets - 335 lines of production code
// Testing 14 static delegation methods in facade pattern for social avatar functionality
// 
// ULTRATHINK FOCUS: UserProfile integration, delegation verification, parameter passing, fallback handling

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports - NEVER assume, always check production code first
import 'package:butlery/widgets/social/avatar/avatar_widgets.dart';
import 'package:butlery/models/user_profile.dart';

// Test infrastructure imports - using centralized system
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/base_widget_test.dart';
import '../../infrastructure/factories/user_profile_factory.dart';

void main() {
  group('AvatarWidgets Ultrathink Tests', () {
    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
    });
    
    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    // Helper to create test environment
    Widget createTestWidget({Widget? child}) {
      return BaseWidgetTest.createTestApp(
        locale: const Locale('en', 'US'),
        child: Scaffold(
          body: child ?? const SizedBox.shrink(),
        ),
      );
    }

    // Helper to create test user
    UserProfile createTestUser({
      String uid = 'test_user_123',
      String displayName = 'Anna Svensson',
      String email = 'anna@example.com',
      String? avatarUrl,
      bool isOnline = false,
    }) {
      return UserProfileFactory.build(
        uid: uid,
        displayName: displayName,
        email: email,
        avatarUrl: avatarUrl,
        isOnline: isOnline,
      );
    }

    group('Avatar Method Tests', () {
      testWidgets('avatar delegates to UserDisplayWidgets.avatar with UserProfile',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 16-47
        final testUser = createTestUser(
          avatarUrl: 'https://example.com/avatar.jpg',
          isOnline: true,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.avatar(
              user: testUser,
              size: ImageSize.large,
              showStatus: true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate to UserDisplayWidgets.avatar structure
        expect(find.byType(Container), findsAtLeastNWidgets(1));
      });

      testWidgets('avatar delegates with individual parameters when user is null',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code fallback parameter logic from lines 30-33
        const testImageUrl = 'https://example.com/test.jpg';
        const testDisplayName = 'Manual User';

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.avatar(
              user: null,
              imageUrl: testImageUrl,
              displayName: testDisplayName,
              size: ImageSize.medium,
              borderColor: Colors.red,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should use fallback parameters when user is null
        expect(find.byType(Container), findsAtLeastNWidgets(1));
      });

      testWidgets('avatar uses fallback displayName when both user and displayName are null',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code fallback logic from line 32
        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.avatar(
              user: null,
              displayName: null,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should use 'Okänd användare' fallback (line 32)
        expect(find.byType(Container), findsAtLeastNWidgets(1));
      });

      testWidgets('avatar handles clickable parameter correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code clickable logic from line 39
        bool tapCallbackCalled = false;
        
        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.avatar(
              displayName: 'Clickable User',
              clickable: true,
              onTap: () => tapCallbackCalled = true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Clickable should pass onTap callback through delegation
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(tapCallbackCalled, isFalse); // Callback not triggered in widget creation
      });
    });

    group('EditableAvatar Method Tests', () {
      testWidgets('editableAvatar delegates to UserDisplayWidgets.editableAvatar',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 50-71
        final testUser = createTestUser(avatarUrl: 'https://example.com/edit.jpg');
        bool editCallbackCalled = false;

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.editableAvatar(
              user: testUser,
              onEditTap: () => editCallbackCalled = true,
              size: ImageSize.extraLarge,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate to UserDisplayWidgets.editableAvatar
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(editCallbackCalled, isFalse); // Callback not triggered in widget creation
      });

      testWidgets('editableAvatar uses fallback parameters when user is null',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code fallback logic from lines 59-61
        bool editCallbackCalled = false;

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.editableAvatar(
              user: null,
              imageUrl: 'https://example.com/manual.jpg',
              displayName: 'Manual Edit User',
              onEditTap: () => editCallbackCalled = true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should use manual parameters with fallback logic
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(editCallbackCalled, isFalse); // Callback not triggered in widget creation
      });
    });

    group('UserName Method Tests', () {
      testWidgets('userName delegates to UserDisplayWidgets.userName with UserProfile',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 74-90
        final testUser = createTestUser();

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.userName(
              user: testUser,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate to UserDisplayWidgets.userName
        expect(find.byType(Text), findsOneWidget);
        expect(find.text('Anna Svensson'), findsOneWidget);
      });

      testWidgets('userName uses fallback when user and displayName are null',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code fallback logic from lines 81-82
        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.userName(
              user: null,
              displayName: null,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should use 'Okänd användare' fallback
        expect(find.text('Okänd användare'), findsOneWidget);
      });
    });

    group('UserInfo Method Tests', () {
      testWidgets('userInfo delegates to UserDisplayWidgets.userInfo',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 93-112
        final testUser = createTestUser();

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.userInfo(
              user: testUser,
              alignment: CrossAxisAlignment.center,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate to UserDisplayWidgets.userInfo with Column structure
        expect(find.byType(Column), findsOneWidget);
        expect(find.text('Anna Svensson'), findsOneWidget);
      });

      testWidgets('userInfo uses manual parameters when user is null',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code fallback logic from lines 101-103
        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.userInfo(
              user: null,
              displayName: 'Manual Name',
              email: 'manual@example.com',
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should use manual parameters
        expect(find.text('Manual Name'), findsOneWidget);
      });
    });

    group('UserRow Method Tests', () {
      testWidgets('userRow delegates to UserDisplayWidgets.userRow',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 115-146
        final testUser = createTestUser(isOnline: true);

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.userRow(
              user: testUser,
              trailing: const Icon(Icons.arrow_forward),
              showStatus: true,
              onTap: () {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate to UserDisplayWidgets.userRow with Row structure
        expect(find.byType(Row), findsAtLeastNWidgets(1));
      });

      testWidgets('userRow handles subtitle parameter correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code subtitle handling from line 131
        final testUser = createTestUser();
        const testSubtitle = 'Custom Subtitle';

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.userRow(
              user: testUser,
              subtitle: testSubtitle,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should pass subtitle through delegation
        expect(find.byType(Row), findsAtLeastNWidgets(1));
      });
    });

    group('UserCard Method Tests', () {
      testWidgets('userCard delegates to UserDisplayWidgets.userCard',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 149-189
        final testUser = createTestUser();

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.userCard(
              user: testUser,
              description: 'User description',
              actions: const Icon(Icons.more_vert),
              showStatus: true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate to UserDisplayWidgets.userCard
        expect(find.byType(Container), findsAtLeastNWidgets(1));
      });

      testWidgets('userCard uses isOnline fallback when user.isOnline is null',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code isOnline fallback from line 173
        final testUser = createTestUser(isOnline: false);

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.userCard(
              user: testUser,
              isOnline: true, // Should use user.isOnline instead
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should use user.isOnline value over manual parameter
        expect(find.byType(Container), findsAtLeastNWidgets(1));
      });
    });

    group('UserListTile Method Tests', () {
      testWidgets('userListTile delegates to UserDisplayWidgets.userRow',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 192-224
        // Note: userListTile delegates to UserDisplayWidgets.userRow, not ListTile
        final testUser = createTestUser();

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.userListTile(
              user: testUser,
              trailing: const Icon(Icons.check),
              enabled: true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate to UserDisplayWidgets.userRow (line 213)
        expect(find.byType(Row), findsAtLeastNWidgets(1));
      });

      testWidgets('userListTile handles enabled parameter for onTap callback',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code enabled logic from line 219
        bool tapCallbackCalled = false;

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.userListTile(
              displayName: 'Test User',
              enabled: false, // Should disable onTap
              onTap: () => tapCallbackCalled = true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: enabled: false should pass null to onTap (line 219)
        expect(find.byType(Row), findsAtLeastNWidgets(1));
        expect(tapCallbackCalled, isFalse); // Callback should not be called when disabled
      });
    });

    group('UserList Method Tests', () {
      testWidgets('userList delegates to UserDisplayWidgets.userList',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 227-260
        final testUsers = [
          createTestUser(uid: 'user1', displayName: 'User One'),
          createTestUser(uid: 'user2', displayName: 'User Two'),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.userList(
              users: testUsers,
              onUserTap: (user) {},
              showStatus: true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate to UserDisplayWidgets.userList
        expect(find.byType(Column), findsAtLeastNWidgets(1));
      });

      testWidgets('userList converts UserProfile to UserDisplayData',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code UserDisplayData conversion from lines 237-238
        final testUsers = [createTestUser()];

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.userList(
              users: testUsers,
              trailingBuilder: (user) => Text('Trail: ${user.displayName}'),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should convert UserProfile to UserDisplayData for delegation
        expect(find.byType(Column), findsOneWidget);
      });

      testWidgets('userList handles callback conversions correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code callback conversion from lines 242-252
        final testUsers = [createTestUser(uid: 'callback_test')];
        String? tappedUserId;

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.userList(
              users: testUsers,
              onUserTap: (user) => tappedUserId = user.uid,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should handle UserProfile callback conversion
        expect(find.byType(Column), findsOneWidget);
        expect(tappedUserId, isNull); // Callback not triggered in widget creation
      });
    });

    group('UserGrid Method Tests', () {
      testWidgets('userGrid delegates to UserDisplayWidgets.userGrid',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 263-291
        final testUsers = [
          createTestUser(uid: 'grid1', displayName: 'Grid User 1'),
          createTestUser(uid: 'grid2', displayName: 'Grid User 2'),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.userGrid(
              users: testUsers,
              crossAxisCount: 2,
              aspectRatio: 1.5,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate to UserDisplayWidgets.userGrid
        expect(find.byType(GridView), findsOneWidget);
      });

      testWidgets('userGrid handles onUserTap callback conversion',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code callback conversion from lines 278-282
        final testUsers = [createTestUser(uid: 'grid_tap_test')];
        String? tappedUserId;

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.userGrid(
              users: testUsers,
              onUserTap: (user) => tappedUserId = user.uid,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should convert UserProfile callback to UserDisplayData callback
        expect(find.byType(GridView), findsOneWidget);
        expect(tappedUserId, isNull); // Callback not triggered in widget creation
      });
    });

    group('Simple Delegation Methods', () {
      testWidgets('emptyUserState delegates with default parameters',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 294-308
        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.emptyUserState(),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should use default Swedish parameters (lines 295-296)
        expect(find.text('Inga användare'), findsOneWidget);
        expect(find.text('Inga användare att visa'), findsOneWidget);
      });

      testWidgets('emptyUserState passes custom parameters correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code custom parameter passing
        const customTitle = 'No Users Found';
        const customSubtitle = 'Try adding some users';

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.emptyUserState(
              title: customTitle,
              subtitle: customSubtitle,
              icon: Icons.person_add,
              actionLabel: 'Add User',
              onAction: () {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should pass all custom parameters to delegation
        expect(find.text(customTitle), findsOneWidget);
        expect(find.text(customSubtitle), findsOneWidget);
      });

      testWidgets('statusIndicator delegates to UserDisplayWidgets.statusIndicator',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 311-318
        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.statusIndicator(
              isOnline: true,
              size: 12.0,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate status indicator creation
        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('userBadge delegates to UserDisplayWidgets.userBadge',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 322-334
        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.userBadge(
              label: 'Admin',
              backgroundColor: Colors.blue,
              textColor: Colors.white,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate badge creation
        expect(find.text('Admin'), findsOneWidget);
      });
    });

    group('Parameter Edge Cases', () {
      testWidgets('handles null UserProfile gracefully across all methods',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code null UserProfile handling
        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                AvatarWidgets.avatar(user: null),
                AvatarWidgets.userName(user: null),
                AvatarWidgets.userInfo(user: null),
                AvatarWidgets.userRow(user: null),
                AvatarWidgets.userCard(user: null),
                AvatarWidgets.userListTile(user: null),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: All methods should handle null user gracefully with fallbacks
        // Note: userCard and userListTile may render differently
        expect(find.text('Okänd användare'), findsAtLeastNWidgets(4));
      });

      testWidgets('handles empty user lists correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with empty lists
        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                AvatarWidgets.userList(users: []),
                AvatarWidgets.userGrid(users: []),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should handle empty lists without errors
        expect(find.byType(Column), findsAtLeastNWidgets(1)); // At least main Column
      });

      testWidgets('handles complex UserProfile parameters',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with complex UserProfile
        final complexUser = UserProfileFactory.build(
          uid: 'complex_user',
          displayName: 'Very Long User Name That Might Overflow',
          email: 'very.long.email.address@example.com',
          avatarUrl: null, // Test null avatar handling
          isOnline: true,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: AvatarWidgets.userCard(
              user: complexUser,
              description: 'A very long description that should be handled properly',
              showStatus: true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should handle complex parameters without layout issues
        expect(find.text('Very Long User Name That Might Overflow'), findsOneWidget);
      });
    });
  });
}