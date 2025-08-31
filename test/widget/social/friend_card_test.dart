import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/views/social/friends_list/friend_card.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import '../../infrastructure/factories/user_profile_factory.dart';

void main() {
  group('FriendCard', () {
    late UserProfile testFriend;
    late UserProfile friendWithLongName;
    late UserProfile friendWithSpecialChars;
    
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      testFriend = UserProfileFactory.build(
        uid: 'friend_123',
        displayName: 'Anna Andersson',
        email: 'anna@example.com',
      );
      
      friendWithLongName = UserProfileFactory.build(
        uid: 'friend_456',
        displayName: 'Maria Elisabet Alexandra Johansson-Svensson',
        email: 'maria@example.com',
      );
      
      friendWithSpecialChars = UserProfileFactory.build(
        uid: 'friend_789',
        displayName: 'Björn Åström',
        email: 'bjorn@example.com',
      );
    });

    group('Rendering', () {
      testWidgets('should render friend card with basic information', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FriendCard.build(
                  context,
                  testFriend,
                ),
              ),
            ),
          ),
        );

        // Verify card structure
        expect(find.byType(Card), findsOneWidget);
        expect(find.byType(ListTile), findsOneWidget);
        
        // Verify friend name is displayed
        expect(find.text('Anna Andersson'), findsOneWidget);
        
        // Verify avatar icon
        expect(find.byIcon(Icons.person), findsOneWidget);
      });

      testWidgets('should render avatar with correct styling', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FriendCard.build(
                  context,
                testFriend,
                ),
              ),
            ),
          ),
        );

        // Find the avatar container
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(ListTile),
            matching: find.byType(Container),
          ).first,
        );
        
        // Verify avatar dimensions
        expect(container.constraints?.maxWidth, equals(56));
        expect(container.constraints?.maxHeight, equals(56));
        
        // Verify avatar decoration
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.primaryBlue));
        expect(decoration.shape, equals(BoxShape.circle));
        
        // Verify icon styling
        final icon = tester.widget<Icon>(find.byIcon(Icons.person));
        expect(icon.color, equals(AppColors.cardWhite));
        expect(icon.size, equals(32));
      });

      testWidgets('should apply correct card margins', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FriendCard.build(
                  context,
                testFriend,
                ),
              ),
            ),
          ),
        );

        final card = tester.widget<Card>(find.byType(Card));
        expect(
          card.margin,
          equals(const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingL,
            vertical: AppDimensions.spacingXs,
          )),
        );
      });

      testWidgets('should apply correct text styling', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FriendCard.build(
                  context,
                testFriend,
                ),
              ),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('Anna Andersson'));
        expect(text.style, equals(AppTextStyles.titleMedium));
      });

      testWidgets('should handle long display names', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300, // Constrain width to test overflow
                child: Builder(
                  builder: (context) => FriendCard.build(
                    context,
                  friendWithLongName,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(
          find.text('Maria Elisabet Alexandra Johansson-Svensson'),
          findsOneWidget,
        );
      });

      testWidgets('should handle special Swedish characters', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FriendCard.build(
                  context,
                friendWithSpecialChars,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Björn Åström'), findsOneWidget);
      });
    });

    group('Navigation', () {
      testWidgets('should navigate to friend profile on tap', (tester) async {
        final navigatorObserver = NavigatorObserver();
        String? pushedRoute;
        UserProfile? passedArgument;

        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [navigatorObserver],
            home: Scaffold(
              body: Builder(
                builder: (context) => FriendCard.build(
                  context,
                  testFriend,
                ),
              ),
            ),
            onGenerateRoute: (settings) {
              pushedRoute = settings.name;
              passedArgument = settings.arguments as UserProfile?;
              return MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('Friend Profile')),
              );
            },
          ),
        );

        // Tap on the list tile
        await tester.tap(find.byType(ListTile));
        await tester.pumpAndSettle();

        // Verify navigation
        expect(pushedRoute, equals('/friend-profile'));
        expect(passedArgument, equals(testFriend));
        expect(passedArgument?.uid, equals('friend_123'));
        expect(passedArgument?.displayName, equals('Anna Andersson'));
      });

      testWidgets('should pass correct friend data as navigation argument', (tester) async {
        UserProfile? receivedProfile;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FriendCard.build(
                  context,
                  friendWithSpecialChars,
                ),
              ),
            ),
            onGenerateRoute: (settings) {
              if (settings.name == '/friend-profile') {
                receivedProfile = settings.arguments as UserProfile?;
                return MaterialPageRoute(
                  builder: (_) => const Scaffold(body: Text('Profile')),
                );
              }
              return null;
            },
          ),
        );

        await tester.tap(find.byType(ListTile));
        await tester.pumpAndSettle();

        expect(receivedProfile, isNotNull);
        expect(receivedProfile?.uid, equals('friend_789'));
        expect(receivedProfile?.displayName, equals('Björn Åström'));
        expect(receivedProfile?.email, equals('bjorn@example.com'));
      });
    });

    group('Visual Consistency', () {
      testWidgets('should maintain consistent layout with different screen sizes', (tester) async {
        // Test on small screen
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FriendCard.build(
                  context,
                testFriend,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Card), findsOneWidget);
        expect(find.byType(ListTile), findsOneWidget);

        // Test on large screen
        tester.view.physicalSize = const Size(768, 1024);
        tester.view.devicePixelRatio = 1.0;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FriendCard.build(
                  context,
                testFriend,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Card), findsOneWidget);
        expect(find.byType(ListTile), findsOneWidget);
        
        // Reset to default
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('should render correctly in dark theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Builder(
                builder: (context) => FriendCard.build(
                  context,
                testFriend,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Card), findsOneWidget);
        expect(find.text('Anna Andersson'), findsOneWidget);
        
        // Avatar should still use defined colors
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(ListTile),
            matching: find.byType(Container),
          ).first,
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.primaryBlue));
      });

      testWidgets('should render correctly in light theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => FriendCard.build(
                  context,
                testFriend,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Card), findsOneWidget);
        expect(find.text('Anna Andersson'), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle empty display name', (tester) async {
        final emptyNameFriend = UserProfileFactory.build(
          uid: 'empty_name',
          displayName: '',
          email: 'empty@example.com',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FriendCard.build(
                  context,
                emptyNameFriend,
                ),
              ),
            ),
          ),
        );

        // Empty text widget should still be rendered
        expect(find.text(''), findsOneWidget);
        expect(find.byType(ListTile), findsOneWidget);
      });

      testWidgets('should handle special characters in display name', (tester) async {
        final specialFriend = UserProfileFactory.build(
          uid: 'special',
          displayName: '🎉 Test User 🎉',
          email: 'special@example.com',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FriendCard.build(
                  context,
                specialFriend,
                ),
              ),
            ),
          ),
        );

        expect(find.text('🎉 Test User 🎉'), findsOneWidget);
      });

      testWidgets('should handle very long display names gracefully', (tester) async {
        final veryLongName = UserProfileFactory.build(
          uid: 'long',
          displayName: 'A' * 100, // 100 character name
          email: 'long@example.com',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200, // Constrain width
                child: Builder(
                  builder: (context) => FriendCard.build(
                    context,
                  veryLongName,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('A' * 100), findsOneWidget);
        expect(find.byType(ListTile), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('should have tappable area for navigation', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FriendCard.build(
                  context,
                  testFriend,
                ),
              ),
            ),
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('Profile')),
            ),
          ),
        );

        // Verify the entire ListTile is tappable
        final listTile = tester.widget<ListTile>(find.byType(ListTile));
        expect(listTile.onTap, isNotNull);
      });

      testWidgets('should have sufficient contrast for text', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Builder(
                builder: (context) => FriendCard.build(
                  context,
                testFriend,
                ),
              ),
            ),
          ),
        );

        // Text should use AppTextStyles.titleMedium which has good contrast
        final text = tester.widget<Text>(find.text('Anna Andersson'));
        expect(text.style, equals(AppTextStyles.titleMedium));
      });

      testWidgets('should maintain minimum touch target size', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FriendCard.build(
                  context,
                testFriend,
                ),
              ),
            ),
          ),
        );

        final listTileBox = tester.renderObject<RenderBox>(
          find.byType(ListTile),
        );
        
        // Material Design recommends minimum 48x48 for touch targets
        expect(listTileBox.size.height, greaterThanOrEqualTo(48));
      });
    });

    group('Swedish Localization', () {
      testWidgets('should display Swedish names correctly', (tester) async {
        final swedishFriend = UserProfileFactory.build(
          uid: 'swedish',
          displayName: 'Åsa Öberg',
          email: 'asa@example.se',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FriendCard.build(
                  context,
                swedishFriend,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Åsa Öberg'), findsOneWidget);
      });

      testWidgets('should handle Swedish compound names', (tester) async {
        final compoundNameFriend = UserProfileFactory.build(
          uid: 'compound',
          displayName: 'Karl-Johan Nilsson',
          email: 'kj@example.se',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FriendCard.build(
                  context,
                compoundNameFriend,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Karl-Johan Nilsson'), findsOneWidget);
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}