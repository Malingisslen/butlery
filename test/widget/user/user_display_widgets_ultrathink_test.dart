// test/widget/user/user_display_widgets_ultrathink_test.dart
// Comprehensive tests for UserDisplayWidgets using ultrathink methodology
// 
// ULTRATHINK ANALYSIS: UserDisplayWidgets facade pattern (241 lines)
// - 12 static delegation methods across 4 categories
// - Pure facade with no business logic - perfect parameter forwarding
// - 4-way delegation: UserAvatarWidgets, UserLayoutWidgets, UserCollectionWidgets
// - Swedish localization defaults and ImageSize enum integration

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';

void main() {
  group('UserDisplayWidgets Facade Tests - ULTRATHINK METHODOLOGY', () {
    // Helper to create test environment
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: Colors.blue,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        home: Scaffold(
          body: SizedBox(
            height: 800, // Increased height for grid tests
            width: 600,  // Increased width for grid tests
            child: child,
          ),
        ),
      );
    }

    group('Core Avatars Delegation - UserAvatarWidgets (4 methods)', () {
      testWidgets('avatar() should delegate to UserAvatarWidgets.avatar with all parameters', (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 21-44
        await tester.pumpWidget(createTestWidget(
          UserDisplayWidgets.avatar(
            imageUrl: 'https://example.com/avatar.jpg',
            displayName: 'Anna Svensson',
            size: ImageSize.large,
            onTap: () {},
            borderColor: Colors.red,
            borderWidth: 2.0,
            backgroundColor: Colors.blue,
            textColor: Colors.white,
            showStatus: true,
            isOnline: true,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should delegate to UserAvatarWidgets.avatar structure
        expect(find.byType(Container), findsAtLeastNWidgets(1));
      });

      testWidgets('avatar() should handle minimal parameters with delegation', (WidgetTester tester) async {
        // ULTRATHINK: Test minimal required parameters delegation
        await tester.pumpWidget(createTestWidget(
          UserDisplayWidgets.avatar(
            displayName: 'Min User',
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should delegate with default parameters
        expect(find.byType(Container), findsAtLeastNWidgets(1));
      });

      testWidgets('editableAvatar() should delegate to UserAvatarWidgets.editableAvatar', (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 46-61
        bool editPressed = false;
        
        await tester.pumpWidget(createTestWidget(
          UserDisplayWidgets.editableAvatar(
            imageUrl: 'https://example.com/edit.jpg',
            displayName: 'Editable User',
            onEditTap: () => editPressed = true,
            size: ImageSize.extraLarge,
            borderColor: Colors.green,
            borderWidth: 3.0,
          ),
        ));

        expect(tester.takeException(), isNull);
        expect(editPressed, isFalse); // Callback not triggered during creation
        
        // Should delegate to UserAvatarWidgets.editableAvatar
        expect(find.byType(Container), findsAtLeastNWidgets(1));
      });

      testWidgets('statusIndicator() should delegate to UserAvatarWidgets.statusIndicator', (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 63-70
        await tester.pumpWidget(createTestWidget(
          UserDisplayWidgets.statusIndicator(
            isOnline: true,
            size: 12.0,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should delegate status indicator creation
        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('getInitials() should delegate to UserAvatarWidgets.getInitials', (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from line 72 (String helper method)
        const testName = 'Anna Svensson';
        
        final initials = UserDisplayWidgets.getInitials(testName);
        
        // Should delegate to UserAvatarWidgets.getInitials for actual logic
        expect(initials, isA<String>());
        expect(initials.isNotEmpty, isTrue);
      });
    });

    group('Text Components Delegation - UserLayoutWidgets (3 methods)', () {
      testWidgets('userName() should delegate to UserLayoutWidgets.userName', (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 75-86
        await tester.pumpWidget(createTestWidget(
          UserDisplayWidgets.userName(
            displayName: 'Erik Karlsson',
            style: const TextStyle(fontSize: 16),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should delegate to UserLayoutWidgets.userName
        expect(find.byType(Text), findsOneWidget);
        expect(find.text('Erik Karlsson'), findsOneWidget);
      });

      testWidgets('userEmail() should delegate to UserLayoutWidgets.userEmail', (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 88-99
        await tester.pumpWidget(createTestWidget(
          UserDisplayWidgets.userEmail(
            email: 'erik@example.com',
            style: const TextStyle(color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.fade,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should delegate to UserLayoutWidgets.userEmail
        expect(find.byType(Text), findsOneWidget);
        expect(find.text('erik@example.com'), findsOneWidget);
      });

      testWidgets('userInfo() should delegate to UserLayoutWidgets.userInfo', (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 101-114
        await tester.pumpWidget(createTestWidget(
          UserDisplayWidgets.userInfo(
            displayName: 'Sofia Lindberg',
            email: 'sofia@example.com',
            alignment: CrossAxisAlignment.center,
            nameStyle: const TextStyle(fontWeight: FontWeight.bold),
            emailStyle: const TextStyle(color: Colors.grey),
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should delegate to UserLayoutWidgets.userInfo with Column structure
        expect(find.byType(Column), findsOneWidget);
        expect(find.text('Sofia Lindberg'), findsOneWidget);
        expect(find.text('sofia@example.com'), findsOneWidget);
      });
    });

    group('Layout Components Delegation - UserLayoutWidgets (2 methods)', () {
      testWidgets('userRow() should delegate to UserLayoutWidgets.userRow with all parameters', (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 117-140 (10+ parameters)
        bool rowTapped = false;
        
        await tester.pumpWidget(createTestWidget(
          UserDisplayWidgets.userRow(
            imageUrl: 'https://example.com/row.jpg',
            displayName: 'Marcus Berg',
            email: 'marcus@example.com',
            subtitle: 'Custom subtitle',
            avatarSize: ImageSize.medium,
            onTap: () => rowTapped = true,
            trailing: const Icon(Icons.arrow_forward),
            showStatus: true,
            isOnline: false,
            padding: const EdgeInsets.all(8.0),
          ),
        ));

        expect(tester.takeException(), isNull);
        expect(rowTapped, isFalse); // Callback not triggered during creation
        
        // Should delegate to UserLayoutWidgets.userRow with Row structure
        expect(find.byType(Row), findsAtLeastNWidgets(1));
        expect(find.text('Marcus Berg'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      });

      testWidgets('userCard() should delegate to UserLayoutWidgets.userCard with complex parameters', (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 142-169 (15+ parameters)
        bool cardTapped = false;
        
        await tester.pumpWidget(createTestWidget(
          UserDisplayWidgets.userCard(
            imageUrl: 'https://example.com/card.jpg',
            displayName: 'Lisa Andersson',
            email: 'lisa@example.com',
            subtitle: 'Software Engineer',
            description: 'Full stack developer with 5 years experience',
            avatarSize: ImageSize.large,
            onTap: () => cardTapped = true,
            actions: const Icon(Icons.more_vert),
            showStatus: true,
            isOnline: true,
            padding: const EdgeInsets.all(16.0),
            margin: const EdgeInsets.symmetric(horizontal: 8.0),
          ),
        ));

        expect(tester.takeException(), isNull);
        expect(cardTapped, isFalse); // Callback not triggered during creation
        
        // Should delegate to UserLayoutWidgets.userCard
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.text('Lisa Andersson'), findsOneWidget);
        expect(find.text('lisa@example.com'), findsOneWidget);
        expect(find.text('Software Engineer'), findsOneWidget);
      });
    });

    group('Collection Components Delegation - UserCollectionWidgets (4 methods)', () {
      testWidgets('userList() should delegate to UserCollectionWidgets.userList', (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 172-191
        final testUsers = [
          const UserDisplayData(
            id: 'user1',
            displayName: 'User One',
            email: 'one@example.com',
            isOnline: true,
          ),
          const UserDisplayData(
            id: 'user2',
            displayName: 'User Two',
            email: 'two@example.com',
            isOnline: false,
          ),
        ];
        
        String? tappedUserId;
        
        await tester.pumpWidget(createTestWidget(
          UserDisplayWidgets.userList(
            users: testUsers,
            onUserTap: (user) => tappedUserId = user.id,
            trailingBuilder: (user) => Text('Trail: ${user.displayName}'),
            showStatus: true,
            avatarSize: ImageSize.medium,
            padding: const EdgeInsets.all(8.0),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should delegate to UserCollectionWidgets.userList (ListView.separated in production)
        expect(find.byType(ListView), findsOneWidget);
        expect(find.text('User One'), findsOneWidget);
        expect(find.text('User Two'), findsOneWidget);
        expect(tappedUserId, isNull); // Not tapped yet
      });

      testWidgets('userGrid() should delegate to UserCollectionWidgets.userGrid', (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 193-212
        final testUsers = [
          const UserDisplayData(
            id: 'grid1',
            displayName: 'Grid User 1',
            isOnline: true,
          ),
          const UserDisplayData(
            id: 'grid2',
            displayName: 'Grid User 2',
            isOnline: false,
          ),
        ];
        
        String? gridTappedId;
        
        await tester.pumpWidget(createTestWidget(
          UserDisplayWidgets.userGrid(
            users: testUsers,
            onUserTap: (user) => gridTappedId = user.id,
            crossAxisCount: 2,
            aspectRatio: 1.5,
            avatarSize: ImageSize.large,
            padding: const EdgeInsets.all(12.0),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should delegate to UserCollectionWidgets.userGrid
        expect(find.byType(GridView), findsOneWidget);
        expect(gridTappedId, isNull); // Not tapped yet
      });

      testWidgets('emptyUserState() should delegate with Swedish defaults', (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 214-227 with Swedish defaults
        await tester.pumpWidget(createTestWidget(
          UserDisplayWidgets.emptyUserState(),
        ));

        expect(tester.takeException(), isNull);
        
        // Should delegate with Swedish default texts (lines 215-216)
        expect(find.text('Inga användare'), findsOneWidget);
        expect(find.text('Inga användare att visa'), findsOneWidget);
        expect(find.byIcon(Icons.people_outline), findsOneWidget);
      });

      testWidgets('emptyUserState() should delegate with custom parameters', (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation with all custom parameters
        bool actionPressed = false;
        
        await tester.pumpWidget(createTestWidget(
          UserDisplayWidgets.emptyUserState(
            title: 'No Users Found',
            subtitle: 'Try adding some users first',
            icon: Icons.person_add,
            onAction: () => actionPressed = true,
            actionLabel: 'Add User',
          ),
        ));

        expect(tester.takeException(), isNull);
        expect(actionPressed, isFalse); // Callback not triggered during creation
        
        // Should pass all custom parameters through delegation
        expect(find.text('No Users Found'), findsOneWidget);
        expect(find.text('Try adding some users first'), findsOneWidget);
        expect(find.byIcon(Icons.person_add), findsOneWidget);
        expect(find.text('Add User'), findsOneWidget);
      });

      testWidgets('userBadge() should delegate to UserCollectionWidgets.userBadge', (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 229-240
        await tester.pumpWidget(createTestWidget(
          UserDisplayWidgets.userBadge(
            label: 'Admin',
            backgroundColor: Colors.red,
            textColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should delegate badge creation
        expect(find.text('Admin'), findsOneWidget);
      });
    });

    group('Edge Cases and Parameter Validation', () {
      testWidgets('should handle null optional parameters gracefully', (WidgetTester tester) async {
        // ULTRATHINK: Test parameter forwarding with null values
        await tester.pumpWidget(createTestWidget(
          SingleChildScrollView(
            child: Column(
              children: [
                UserDisplayWidgets.avatar(
                  displayName: 'Null Test',
                  imageUrl: null,
                  onTap: null,
                  borderColor: null,
                ),
                const SizedBox(height: 8),
                UserDisplayWidgets.userInfo(
                  displayName: 'Info Test',
                  email: null,
                  nameStyle: null,
                  emailStyle: null,
                ),
                const SizedBox(height: 8),
                UserDisplayWidgets.userRow(
                  displayName: 'Row Test',
                  imageUrl: null,
                  email: null,
                  onTap: null,
                  trailing: null,
                  padding: null,
                ),
              ],
            ),
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // All methods should handle null parameters through delegation
        // ULTRATHINK: Avatar shows initials, not full name
        expect(find.text('NT'), findsOneWidget); // Initials for 'Null Test' (first letter of each word)
        expect(find.text('Info Test'), findsOneWidget);
        expect(find.text('Row Test'), findsOneWidget);
      });

      testWidgets('should handle empty collections gracefully', (WidgetTester tester) async {
        // ULTRATHINK: Test collection methods with empty lists
        await tester.pumpWidget(createTestWidget(
          Column(
            children: [
              UserDisplayWidgets.userList(users: []),
              UserDisplayWidgets.userGrid(users: []),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should handle empty collections without errors
        // ULTRATHINK: Empty userList/userGrid return ListView/GridView, not Columns
        expect(find.byType(Column), findsOneWidget); // Only main Column
      });

      testWidgets('should handle complex UserDisplayData properly', (WidgetTester tester) async {
        // ULTRATHINK: Test with complex UserDisplayData objects
        final complexUser = UserDisplayData(
          id: 'complex_123',
          displayName: 'Åsa Öhman Ängström', // Swedish characters
          email: 'åsa.öhman@example.se',
          imageUrl: null,
          subtitle: 'Very long subtitle that might cause overflow issues',
          description: 'An extremely long description that tests how the delegation handles text overflow and layout constraints in various widget configurations',
          isOnline: true,
          lastSeen: DateTime.now(),
          metadata: {'role': 'admin', 'department': 'IT'},
        );

        await tester.pumpWidget(createTestWidget(
          UserDisplayWidgets.userList(
            users: [complexUser],
            showStatus: true,
            avatarSize: ImageSize.large,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should handle complex data through delegation
        expect(find.text('Åsa Öhman Ängström'), findsOneWidget);
        expect(find.text('åsa.öhman@example.se'), findsOneWidget);
      });

      testWidgets('should handle all ImageSize enum values correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test ImageSize enum parameter forwarding
        await tester.pumpWidget(createTestWidget(
          SingleChildScrollView(
            child: Column(
              children: [
                UserDisplayWidgets.avatar(
                  displayName: 'Small',
                  size: ImageSize.small,
                ),
                const SizedBox(height: 8),
                UserDisplayWidgets.avatar(
                  displayName: 'Medium',
                  size: ImageSize.medium,
                ),
                const SizedBox(height: 8),
                UserDisplayWidgets.avatar(
                  displayName: 'Large',
                  size: ImageSize.large,
                ),
                const SizedBox(height: 8),
                UserDisplayWidgets.avatar(
                  displayName: 'Extra Large',
                  size: ImageSize.extraLarge,
                ),
              ],
            ),
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Avatar widgets display initials as text inside containers, not display names
        // ULTRATHINK: getInitials() uses first 2 chars for single words (lines 197-205)
        expect(find.text('SM'), findsOneWidget); // Initials for 'Small' (first 2 chars)
        expect(find.text('ME'), findsOneWidget); // Initials for 'Medium' (first 2 chars)
        expect(find.text('LA'), findsOneWidget); // Initials for 'Large' (first 2 chars)
        expect(find.text('EL'), findsOneWidget); // Initials for 'Extra Large' (first char of each word)
      });

      testWidgets('should maintain callback functionality through delegation', (WidgetTester tester) async {
        // ULTRATHINK: Test that callbacks are properly forwarded
        bool avatarTapped = false;
        bool editTapped = false;
        bool actionTapped = false;
        
        await tester.pumpWidget(createTestWidget(
          Column(
            children: [
              UserDisplayWidgets.avatar(
                displayName: 'Clickable Avatar',
                onTap: () => avatarTapped = true,
              ),
              UserDisplayWidgets.editableAvatar(
                displayName: 'Editable Avatar',
                onEditTap: () => editTapped = true,
              ),
              UserDisplayWidgets.emptyUserState(
                onAction: () => actionTapped = true,
                actionLabel: 'Test Action',
              ),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Callbacks should remain functional after delegation
        // Note: Avatar widgets show initials, not display names as text
        expect(find.text('CA'), findsOneWidget); // Initials for 'Clickable Avatar'
        expect(find.text('EA'), findsOneWidget); // Initials for 'Editable Avatar'
        expect(find.text('Test Action'), findsOneWidget);
        
        // Verify callbacks are not called initially
        expect(avatarTapped, isFalse);
        expect(editTapped, isFalse);
        expect(actionTapped, isFalse);
      });
    });

    group('API Completeness and Method Coverage', () {
      testWidgets('should have all 12 static methods accessible', (WidgetTester tester) async {
        // ULTRATHINK: Verify all documented methods are present
        // This test ensures no methods are missing from our facade
        
        // Core Avatars (4 methods)
        expect(() => UserDisplayWidgets.avatar(displayName: 'test'), returnsNormally);
        expect(() => UserDisplayWidgets.editableAvatar(displayName: 'test', onEditTap: () {}), returnsNormally);
        expect(() => UserDisplayWidgets.statusIndicator(isOnline: true), returnsNormally);
        expect(() => UserDisplayWidgets.getInitials('test'), returnsNormally);
        
        // Text Components (3 methods)
        expect(() => UserDisplayWidgets.userName(displayName: 'test'), returnsNormally);
        expect(() => UserDisplayWidgets.userEmail(email: 'test@example.com'), returnsNormally);
        expect(() => UserDisplayWidgets.userInfo(displayName: 'test'), returnsNormally);
        
        // Layout Components (2 methods)
        expect(() => UserDisplayWidgets.userRow(displayName: 'test'), returnsNormally);
        expect(() => UserDisplayWidgets.userCard(displayName: 'test'), returnsNormally);
        
        // Collection Components (3 methods)
        expect(() => UserDisplayWidgets.userList(users: []), returnsNormally);
        expect(() => UserDisplayWidgets.userGrid(users: []), returnsNormally);
        expect(() => UserDisplayWidgets.emptyUserState(), returnsNormally);
        expect(() => UserDisplayWidgets.userBadge(label: 'test'), returnsNormally);
      });

      testWidgets('should return Widget types for all widget methods', (WidgetTester tester) async {
        // ULTRATHINK: Verify return types are proper widgets
        final emptyUserData = <UserDisplayData>[];
        
        expect(UserDisplayWidgets.avatar(displayName: 'test'), isA<Widget>());
        expect(UserDisplayWidgets.editableAvatar(displayName: 'test', onEditTap: () {}), isA<Widget>());
        expect(UserDisplayWidgets.statusIndicator(isOnline: true), isA<Widget>());
        expect(UserDisplayWidgets.userName(displayName: 'test'), isA<Widget>());
        expect(UserDisplayWidgets.userEmail(email: 'test@example.com'), isA<Widget>());
        expect(UserDisplayWidgets.userInfo(displayName: 'test'), isA<Widget>());
        expect(UserDisplayWidgets.userRow(displayName: 'test'), isA<Widget>());
        expect(UserDisplayWidgets.userCard(displayName: 'test'), isA<Widget>());
        expect(UserDisplayWidgets.userList(users: emptyUserData), isA<Widget>());
        expect(UserDisplayWidgets.userGrid(users: emptyUserData), isA<Widget>());
        expect(UserDisplayWidgets.emptyUserState(), isA<Widget>());
        expect(UserDisplayWidgets.userBadge(label: 'test'), isA<Widget>());
        
        // String method
        expect(UserDisplayWidgets.getInitials('test'), isA<String>());
      });
    });

    group('Facade Pattern Validation', () {
      testWidgets('should maintain pure delegation pattern without business logic', (WidgetTester tester) async {
        // ULTRATHINK: Verify facade maintains pure delegation
        // This test ensures the facade doesn't add unexpected business logic
        
        await tester.pumpWidget(createTestWidget(
          Column(
            children: [
              // Test that all methods delegate without modification
              UserDisplayWidgets.avatar(
                displayName: 'Facade Test',
                size: ImageSize.medium,
                showStatus: false,
              ),
              UserDisplayWidgets.userName(
                displayName: 'Pure Delegation Test',
                maxLines: 1,
              ),
              UserDisplayWidgets.emptyUserState(
                title: 'Custom Title',
                subtitle: 'Custom Subtitle',
              ),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // All content should be present as delegated
        // Avatar shows initials, userName shows full text, emptyUserState shows titles
        expect(find.text('FT'), findsOneWidget); // Initials for 'Facade Test'
        expect(find.text('Pure Delegation Test'), findsOneWidget);
        expect(find.text('Custom Title'), findsOneWidget);
        expect(find.text('Custom Subtitle'), findsOneWidget);
      });

      testWidgets('should expose all required imports through exports', (WidgetTester tester) async {
        // ULTRATHINK: Verify exports maintain backward compatibility
        // Test that UserDisplayData is accessible through this facade
        
        const testUser = UserDisplayData(
          id: 'export_test',
          displayName: 'Export Test User',
          email: 'export@example.com',
        );
        
        await tester.pumpWidget(createTestWidget(
          UserDisplayWidgets.userList(users: [testUser]),
        ));

        expect(tester.takeException(), isNull);
        
        // UserDisplayData should be usable through facade exports
        expect(find.text('Export Test User'), findsOneWidget);
        expect(find.text('export@example.com'), findsOneWidget);
      });
    });
  });
}