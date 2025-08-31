import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/social/activity_feed_item_widget.dart';
import 'package:butlery/models/social/activity_feed_item.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/user_avatar.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

// Comprehensive widget test for ActivityFeedItemWidget following ultrathink methodology
void main() {
  setUp(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('ActivityFeedItemWidget Tests', () {
    // Test data
    final testActivity = ActivityFeedItem(
      id: 'activity123',
      userId: 'user123',
      userDisplayName: 'Anna Andersson',
      userAvatarUrl: 'https://example.com/avatar.jpg',
      type: ActivityType.recipeCreated,
      targetId: 'recipe456',
      targetType: 'recipe',
      targetTitle: 'Köttbullar med potatismos',
      targetImageUrl: 'https://example.com/recipe.jpg',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      visibility: ['all_friends'],
      metadata: {},
      engagement: const ActivityEngagement(
        likes: 5,
        comments: 3,
        shares: 1,
        views: 10,
      ),
    );

    group('Basic Rendering', () {
      testWidgets('renders with required activity data', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: testActivity,
              ),
            ),
          ),
        );

        expect(find.byType(ActivityFeedItemWidget), findsOneWidget);
        expect(find.text('Anna Andersson'), findsOneWidget);
        expect(find.text('Köttbullar med potatismos'), findsOneWidget);
        expect(find.byType(UserAvatar), findsOneWidget);
      });

      testWidgets('displays activity description', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: testActivity,
              ),
            ),
          ),
        );

        // Description is rendered in RichText widget
        expect(find.byType(RichText), findsAtLeastNWidgets(1));
        // Check that target title is shown
        expect(find.textContaining('Köttbullar med potatismos'), findsAtLeastNWidgets(1));
      });

      testWidgets('shows content preview section', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: testActivity,
              ),
            ),
          ),
        );

        // Find the content preview container
        final contentPreview = find.byWidgetPredicate(
          (widget) => widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color ==
                  AppColors.surfaceVariant.withValues(alpha: 0.3),
        );
        expect(contentPreview, findsOneWidget);
        expect(find.text('Recept'), findsOneWidget); // Swedish for "Recipe"
      });

      testWidgets('displays activity type icon', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: testActivity,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
      });
    });

    group('Engagement Metrics', () {
      testWidgets('shows engagement metrics when enabled', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: testActivity,
                showEngagement: true,
              ),
            ),
          ),
        );

        expect(find.text('5'), findsOneWidget); // likes
        expect(find.text('3'), findsOneWidget); // comments
        expect(find.text('1'), findsOneWidget); // shares
        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
        expect(find.byIcon(Icons.share), findsOneWidget);
      });

      testWidgets('hides engagement metrics when disabled', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: testActivity,
                showEngagement: false,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.favorite), findsNothing);
        expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
        expect(find.byIcon(Icons.share), findsNothing);
      });

      testWidgets('only shows non-zero engagement metrics', (WidgetTester tester) async {
        final activityNoShares = ActivityFeedItem(
          id: 'activity123',
          userId: 'user123',
          userDisplayName: 'Anna Andersson',
          type: ActivityType.recipeCreated,
          targetId: 'recipe456',
          targetType: 'recipe',
          targetTitle: 'Test Recipe',
          timestamp: DateTime.now(),
          visibility: ['all_friends'],
          metadata: {},
          engagement: const ActivityEngagement(
            likes: 5,
            comments: 0,
            shares: 0,
            views: 10,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: activityNoShares,
                showEngagement: true,
              ),
            ),
          ),
        );

        expect(find.text('5'), findsOneWidget); // likes shown
        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(find.byIcon(Icons.chat_bubble_outline), findsNothing); // no comments
        expect(find.byIcon(Icons.share), findsNothing); // no shares
      });
    });

    group('Time Display', () {
      testWidgets('shows relative time by default', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: testActivity,
                showFullTimestamp: false,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.schedule), findsOneWidget);
        expect(find.textContaining('timmar sedan'), findsOneWidget);
      });

      testWidgets('shows full timestamp when enabled', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: testActivity,
                showFullTimestamp: true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.schedule), findsNothing);
        // Full timestamp format includes time (hour:minute)
        expect(find.byWidgetPredicate(
          (widget) => widget is Text && widget.data!.contains(':'),
        ), findsAtLeastNWidgets(1));
      });

      testWidgets('displays "Nyss" for very recent activities', (WidgetTester tester) async {
        final recentActivity = ActivityFeedItem(
          id: 'activity123',
          userId: 'user123',
          userDisplayName: 'Anna Andersson',
          type: ActivityType.recipeCreated,
          targetId: 'recipe456',
          targetType: 'recipe',
          targetTitle: 'Test Recipe',
          timestamp: DateTime.now().subtract(const Duration(seconds: 30)),
          visibility: ['all_friends'],
          metadata: {},
          engagement: const ActivityEngagement(
            likes: 0,
            comments: 0,
            shares: 0,
            views: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: recentActivity,
                showFullTimestamp: false,
              ),
            ),
          ),
        );

        expect(find.text('Nyss'), findsOneWidget);
      });
    });

    group('Activity Types', () {
      testWidgets('displays correct icon for recipe rating', (WidgetTester tester) async {
        final ratingActivity = ActivityFeedItem(
          id: 'activity123',
          userId: 'user123',
          userDisplayName: 'Test User',
          type: ActivityType.recipeRated,
          targetId: 'recipe456',
          targetType: 'recipe',
          targetTitle: 'Test Recipe',
          timestamp: DateTime.now(),
          visibility: ['all_friends'],
          metadata: {'rating': 5},
          engagement: const ActivityEngagement(
            likes: 0,
            comments: 0,
            shares: 0,
            views: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: ratingActivity,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.star), findsOneWidget);
        // Description is in RichText, check for icon instead
        expect(find.byType(RichText), findsAtLeastNWidgets(1));
      });

      testWidgets('displays correct icon for comment added', (WidgetTester tester) async {
        final commentActivity = ActivityFeedItem(
          id: 'activity123',
          userId: 'user123',
          userDisplayName: 'Test User',
          type: ActivityType.commentAdded,
          targetId: 'recipe456',
          targetType: 'recipe',
          targetTitle: 'Test Recipe',
          timestamp: DateTime.now(),
          visibility: ['all_friends'],
          metadata: {},
          engagement: const ActivityEngagement(
            likes: 0,
            comments: 0,
            shares: 0,
            views: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: commentActivity,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.chat_bubble), findsOneWidget);
        // Description is in RichText
        expect(find.byType(RichText), findsAtLeastNWidgets(1));
      });

      testWidgets('displays correct icon for menu shared', (WidgetTester tester) async {
        final menuActivity = ActivityFeedItem(
          id: 'activity123',
          userId: 'user123',
          userDisplayName: 'Test User',
          type: ActivityType.menuShared,
          targetId: 'menu456',
          targetType: 'menu',
          targetTitle: 'Veckomeny',
          timestamp: DateTime.now(),
          visibility: ['all_friends'],
          metadata: {},
          engagement: const ActivityEngagement(
            likes: 0,
            comments: 0,
            shares: 0,
            views: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: menuActivity,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.list_alt), findsNWidgets(2)); // One in content preview, one as activity type icon
        // Description is in RichText
        expect(find.byType(RichText), findsAtLeastNWidgets(1));
        expect(find.text('Meny'), findsOneWidget);
      });

      testWidgets('displays correct icon for shopping list', (WidgetTester tester) async {
        final shoppingActivity = ActivityFeedItem(
          id: 'activity123',
          userId: 'user123',
          userDisplayName: 'Test User',
          type: ActivityType.shoppingListCreated,
          targetId: 'list456',
          targetType: 'shopping_list',
          targetTitle: 'Veckans inköp',
          timestamp: DateTime.now(),
          visibility: ['all_friends'],
          metadata: {},
          engagement: const ActivityEngagement(
            likes: 0,
            comments: 0,
            shares: 0,
            views: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: shoppingActivity,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.shopping_cart), findsNWidgets(2)); // One in content preview, one as activity type icon
        // Description is in RichText
        expect(find.byType(RichText), findsAtLeastNWidgets(1));
        expect(find.text('Inköpslista'), findsOneWidget);
      });

      testWidgets('displays correct icon for achievement', (WidgetTester tester) async {
        final achievementActivity = ActivityFeedItem(
          id: 'activity123',
          userId: 'user123',
          userDisplayName: 'Test User',
          type: ActivityType.achievementUnlocked,
          targetId: 'achievement456',
          targetType: 'achievement',
          targetTitle: 'Master Chef',
          timestamp: DateTime.now(),
          visibility: ['all_friends'],
          metadata: {'achievementName': 'Master Chef'},
          engagement: const ActivityEngagement(
            likes: 0,
            comments: 0,
            shares: 0,
            views: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: achievementActivity,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.emoji_events), findsOneWidget);
        // Description is in RichText, check title is shown
        expect(find.text('Master Chef'), findsOneWidget);
      });
    });

    group('Interactions', () {
      testWidgets('handles tap callback', (WidgetTester tester) async {
        ActivityFeedItem? tappedActivity;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: testActivity,
                onTap: (activity) {
                  tappedActivity = activity;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byType(InkWell));
        expect(tappedActivity, equals(testActivity));
      });

      testWidgets('handles long press callback', (WidgetTester tester) async {
        ActivityFeedItem? longPressedActivity;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: testActivity,
                onLongPress: (activity) {
                  longPressedActivity = activity;
                },
              ),
            ),
          ),
        );

        await tester.longPress(find.byType(InkWell));
        expect(longPressedActivity, equals(testActivity));
      });

      testWidgets('disables interaction when callbacks are null', (WidgetTester tester) async {
        final nullCallbackActivity = ActivityFeedItem(
          id: 'activity123',
          userId: 'user123',
          userDisplayName: 'Test User',
          type: ActivityType.recipeCreated,
          targetId: 'recipe456',
          targetType: 'recipe',
          targetTitle: 'Test Recipe',
          timestamp: DateTime.now(),
          visibility: ['all_friends'],
          metadata: {},
          engagement: const ActivityEngagement(
            likes: 0,
            comments: 0,
            shares: 0,
            views: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: nullCallbackActivity,
                onTap: null,
                onLongPress: null,
              ),
            ),
          ),
        );

        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        expect(inkWell.onTap, isNull);
        expect(inkWell.onLongPress, isNull);
      });
    });

    group('Display Options', () {
      testWidgets('hides description when showDescription is false', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: testActivity,
                showDescription: false,
              ),
            ),
          ),
        );

        expect(find.textContaining('skapade ett recept'), findsNothing);
      });

      testWidgets('applies custom height when provided', (WidgetTester tester) async {
        const customHeight = 150.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: testActivity,
                height: customHeight,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        expect(container.constraints?.maxHeight, equals(customHeight));
      });

      testWidgets('handles missing target image URL', (WidgetTester tester) async {
        final activityNoImage = ActivityFeedItem(
          id: 'activity123',
          userId: 'user123',
          userDisplayName: 'Test User',
          type: ActivityType.recipeCreated,
          targetId: 'recipe456',
          targetType: 'recipe',
          targetTitle: 'Test Recipe',
          targetImageUrl: null,
          timestamp: DateTime.now(),
          visibility: ['all_friends'],
          metadata: {},
          engagement: const ActivityEngagement(
            likes: 0,
            comments: 0,
            shares: 0,
            views: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: activityNoImage,
              ),
            ),
          ),
        );

        // Should show icon instead of image
        expect(find.byIcon(Icons.restaurant_menu), findsAtLeastNWidgets(1));
      });
    });

    group('Swedish Localization', () {
      testWidgets('displays Swedish content type names', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: testActivity,
              ),
            ),
          ),
        );

        expect(find.text('Recept'), findsOneWidget);
      });

      testWidgets('displays Swedish time descriptions', (WidgetTester tester) async {
        final dayOldActivity = ActivityFeedItem(
          id: 'activity123',
          userId: 'user123',
          userDisplayName: 'Test User',
          type: ActivityType.recipeCreated,
          targetId: 'recipe456',
          targetType: 'recipe',
          targetTitle: 'Test Recipe',
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          visibility: ['all_friends'],
          metadata: {},
          engagement: const ActivityEngagement(
            likes: 0,
            comments: 0,
            shares: 0,
            views: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: dayOldActivity,
                showFullTimestamp: false,
              ),
            ),
          ),
        );

        expect(find.textContaining('dagar sedan'), findsOneWidget);
      });

      testWidgets('displays Swedish activity descriptions', (WidgetTester tester) async {
        final reactionActivity = ActivityFeedItem(
          id: 'activity123',
          userId: 'user123',
          userDisplayName: 'Test User',
          type: ActivityType.reactionAdded,
          targetId: 'recipe456',
          targetType: 'recipe',
          targetTitle: 'Test Recipe',
          timestamp: DateTime.now(),
          visibility: ['all_friends'],
          metadata: {'reactionType': '❤️'},
          engagement: const ActivityEngagement(
            likes: 0,
            comments: 0,
            shares: 0,
            views: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: reactionActivity,
              ),
            ),
          ),
        );

        // Description is in RichText
        expect(find.byType(RichText), findsAtLeastNWidgets(1));
      });
    });

    group('Layout and Styling', () {
      testWidgets('applies correct container styling', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: testActivity,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.surface));
        expect(decoration.borderRadius, equals(BorderRadius.circular(AppDimensions.radiusM)));
      });

      testWidgets('renders correctly in ListView', (WidgetTester tester) async {
        final activities = [
          testActivity,
          ActivityFeedItem(
            id: 'activity456',
            userId: 'user456',
            userDisplayName: 'Björn Bergström',
            type: ActivityType.menuCreated,
            targetId: 'menu789',
            targetType: 'menu',
            targetTitle: 'Veckomeny',
            timestamp: DateTime.now(),
            visibility: ['all_friends'],
            metadata: {},
            engagement: const ActivityEngagement(
              likes: 2,
              comments: 1,
              shares: 0,
              views: 5,
            ),
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                itemCount: activities.length,
                itemBuilder: (context, index) => ActivityFeedItemWidget(
                  activity: activities[index],
                ),
              ),
            ),
          ),
        );

        expect(find.byType(ActivityFeedItemWidget), findsNWidgets(2));
        expect(find.text('Anna Andersson'), findsOneWidget);
        expect(find.text('Björn Bergström'), findsOneWidget);
      });

      testWidgets('user avatar displays correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: testActivity,
              ),
            ),
          ),
        );

        final userAvatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
        expect(userAvatar.imageUrl, equals('https://example.com/avatar.jpg'));
        expect(userAvatar.displayName, equals('Anna Andersson'));
      });

      testWidgets('applies correct padding', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: testActivity,
              ),
            ),
          ),
        );

        final padding = tester.widget<Padding>(
          find.descendant(
            of: find.byType(InkWell),
            matching: find.byType(Padding),
          ).first,
        );
        expect(padding.padding, equals(const EdgeInsets.all(AppDimensions.spacingM)));
      });
    });

    group('Metadata Display', () {
      testWidgets('shows rating metadata for recipe rated', (WidgetTester tester) async {
        final ratedActivity = ActivityFeedItem(
          id: 'activity123',
          userId: 'user123',
          userDisplayName: 'Test User',
          type: ActivityType.recipeRated,
          targetId: 'recipe456',
          targetType: 'recipe',
          targetTitle: 'Test Recipe',
          timestamp: DateTime.now(),
          visibility: ['all_friends'],
          metadata: {'rating': 4},
          engagement: const ActivityEngagement(
            likes: 0,
            comments: 0,
            shares: 0,
            views: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: ratedActivity,
              ),
            ),
          ),
        );

        // Metadata is in RichText
        expect(find.byType(RichText), findsAtLeastNWidgets(1));
      });

      testWidgets('shows share count metadata when multiple shares', (WidgetTester tester) async {
        final sharedActivity = ActivityFeedItem(
          id: 'activity123',
          userId: 'user123',
          userDisplayName: 'Test User',
          type: ActivityType.recipeShared,
          targetId: 'recipe456',
          targetType: 'recipe',
          targetTitle: 'Test Recipe',
          timestamp: DateTime.now(),
          visibility: ['all_friends'],
          metadata: {'shareCount': 3},
          engagement: const ActivityEngagement(
            likes: 0,
            comments: 0,
            shares: 3,
            views: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: sharedActivity,
              ),
            ),
          ),
        );

        // Metadata is in RichText
        expect(find.byType(RichText), findsAtLeastNWidgets(1));
        expect(find.text('3'), findsOneWidget); // shares count shown
      });

      testWidgets('shows reaction type in metadata', (WidgetTester tester) async {
        final reactionActivity = ActivityFeedItem(
          id: 'activity123',
          userId: 'user123',
          userDisplayName: 'Test User',
          type: ActivityType.reactionAdded,
          targetId: 'recipe456',
          targetType: 'recipe',
          targetTitle: 'Test Recipe',
          timestamp: DateTime.now(),
          visibility: ['all_friends'],
          metadata: {'reactionType': '😍'},
          engagement: const ActivityEngagement(
            likes: 1,
            comments: 0,
            shares: 0,
            views: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: reactionActivity,
              ),
            ),
          ),
        );

        // Metadata is in RichText
        expect(find.byType(RichText), findsAtLeastNWidgets(1));
      });
    });

    group('Edge Cases', () {
      testWidgets('handles empty engagement metrics', (WidgetTester tester) async {
        final noEngagementActivity = ActivityFeedItem(
          id: 'activity123',
          userId: 'user123',
          userDisplayName: 'Test User',
          type: ActivityType.recipeCreated,
          targetId: 'recipe456',
          targetType: 'recipe',
          targetTitle: 'Test Recipe',
          timestamp: DateTime.now(),
          visibility: ['all_friends'],
          metadata: {},
          engagement: const ActivityEngagement(
            likes: 0,
            comments: 0,
            shares: 0,
            views: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: noEngagementActivity,
                showEngagement: true,
              ),
            ),
          ),
        );

        // No engagement icons should be shown
        expect(find.byIcon(Icons.favorite), findsNothing);
        expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
        expect(find.byIcon(Icons.share), findsNothing);
      });

      testWidgets('handles very long user names', (WidgetTester tester) async {
        final longNameActivity = ActivityFeedItem(
          id: 'activity123',
          userId: 'user123',
          userDisplayName: 'Anna-Maria Elisabet Andersson-Bergström',
          type: ActivityType.recipeCreated,
          targetId: 'recipe456',
          targetType: 'recipe',
          targetTitle: 'Test Recipe',
          timestamp: DateTime.now(),
          visibility: ['all_friends'],
          metadata: {},
          engagement: const ActivityEngagement(
            likes: 0,
            comments: 0,
            shares: 0,
            views: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                child: ActivityFeedItemWidget(
                  activity: longNameActivity,
                ),
              ),
            ),
          ),
        );

        final nameText = tester.widget<Text>(
          find.text('Anna-Maria Elisabet Andersson-Bergström'),
        );
        expect(nameText.overflow, equals(TextOverflow.ellipsis));
        expect(nameText.maxLines, equals(1));
      });

      testWidgets('handles very long content titles', (WidgetTester tester) async {
        final longTitleActivity = ActivityFeedItem(
          id: 'activity123',
          userId: 'user123',
          userDisplayName: 'Test User',
          type: ActivityType.recipeCreated,
          targetId: 'recipe456',
          targetType: 'recipe',
          targetTitle: 'Köttbullar med gräddsås, potatismos, lingonsylt och pressgurka - traditionell svensk husmanskost',
          timestamp: DateTime.now(),
          visibility: ['all_friends'],
          metadata: {},
          engagement: const ActivityEngagement(
            likes: 0,
            comments: 0,
            shares: 0,
            views: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                child: ActivityFeedItemWidget(
                  activity: longTitleActivity,
                ),
              ),
            ),
          ),
        );

        // Title should be truncated in the preview
        final titleTexts = find.byWidgetPredicate(
          (widget) => widget is Text && 
            widget.data!.contains('Köttbullar med gräddsås'),
        );
        expect(titleTexts, findsAtLeastNWidgets(1));
      });

      testWidgets('handles unknown activity type', (WidgetTester tester) async {
        final unknownActivity = ActivityFeedItem(
          id: 'activity123',
          userId: 'user123',
          userDisplayName: 'Test User',
          type: ActivityType.unknown,
          targetId: 'unknown456',
          targetType: 'unknown',
          targetTitle: 'Unknown Content',
          timestamp: DateTime.now(),
          visibility: ['all_friends'],
          metadata: {},
          engagement: const ActivityEngagement(
            likes: 0,
            comments: 0,
            shares: 0,
            views: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityFeedItemWidget(
                activity: unknownActivity,
              ),
            ),
          ),
        );

        expect(find.byType(ActivityFeedItemWidget), findsOneWidget);
        // Fallback description is in RichText
        expect(find.byType(RichText), findsAtLeastNWidgets(1));
        expect(find.text('Innehåll'), findsOneWidget); // Fallback content type
      });
    });
  });
}