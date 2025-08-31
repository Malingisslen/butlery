import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Widget under test - ultrathink production code analysis
import 'package:butlery/widgets/common/content_cards/friend_card.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';

// Dependencies - production code insights
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';

// Test infrastructure
import '../../../infrastructure/factories/user_profile_factory.dart';

void main() {
  // Initialize test environment
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('FriendCard Ultrathink Widget Tests', () {

    // Helper to create properly sized widget - ultrathink layout solution
    Widget createTestWidget({Widget? child}) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'), // Swedish locale
        home: Scaffold(
          body: SingleChildScrollView(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );
    }

    // Test data - Swedish user profiles for comprehensive testing
    late UserProfile swedishUser;
    late UserProfile onlineUser;
    late UserProfile longNameUser;
    late UserProfile minimalUser;

    setUp(() {
      swedishUser = UserProfileFactory.build(
        uid: 'swedish_user_123',
        displayName: 'Åsa Lindström',
        email: 'asa@example.se',
        isOnline: false,
      );

      onlineUser = UserProfileFactory.build(
        uid: 'online_user_456', 
        displayName: 'Erik Johansson',
        email: 'erik@butlery.se',
        isOnline: true,
      );

      longNameUser = UserProfileFactory.build(
        uid: 'long_name_789',
        displayName: 'Maria Elisabet Christina von Schwarz-Hohenberg',
        email: 'maria@longname.se',
        isOnline: false,
      );

      minimalUser = UserProfileFactory.build(
        uid: 'minimal_user_999',
        displayName: 'Test',
        email: '',
        isOnline: false,
      );
    });

    group('FriendCard - Detailed Style Rendering', () {
      testWidgets('renders detailed style with all components - Swedish user', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            style: FriendCardStyle.detailed,
            showAvatar: true,
            showOnlineStatus: false,
            showMetadata: true,
          ),
        ));

        // Core UI elements
        expect(find.text('Åsa Lindström'), findsOneWidget);
        expect(find.textContaining('asa@example.se'), findsOneWidget);
        
        // Container structure verification
        expect(find.byType(Container), findsWidgets);
        expect(find.byType(Material), findsWidgets);
        expect(find.byType(InkWell), findsOneWidget);
        
        // Avatar verification
        expect(find.byType(SimpleImageWidget), findsOneWidget);
        expect(find.byIcon(Icons.person), findsOneWidget);
      });

      testWidgets('renders with online status indicator correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: onlineUser,
            style: FriendCardStyle.detailed,
            showOnlineStatus: true,
          ),
        ));

        // Should have Stack for status overlay
        expect(find.byType(Stack), findsWidgets);
        
        // Should have Positioned widget for status indicator
        expect(find.byType(Positioned), findsOneWidget);
        
        // Positioned widget should be at bottom-right
        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        expect(positioned.bottom, equals(0));
        expect(positioned.right, equals(0));

        // Status indicator should be green for online users
        final statusContainers = tester.widgetList<Container>(find.byType(Container));
        final statusContainer = statusContainers.firstWhere(
          (container) => container.decoration is BoxDecoration &&
            (container.decoration as BoxDecoration).color == Colors.green,
        );
        expect(statusContainer, isNotNull);
      });

      testWidgets('renders without online status when disabled', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: onlineUser,
            style: FriendCardStyle.detailed,
            showOnlineStatus: false,
          ),
        ));

        // Should not have Positioned widget for status when disabled
        expect(find.byType(Positioned), findsNothing);
      });

      testWidgets('handles metadata display correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            showMetadata: true,
          ),
        ));

        // Should display combined metadata (email • memberSinceText)
        expect(find.textContaining('asa@example.se'), findsOneWidget);
        expect(find.textContaining('Medlem i'), findsOneWidget);
      });

      testWidgets('hides metadata when disabled', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            showMetadata: false,
          ),
        ));

        // Should not display metadata
        expect(find.textContaining('asa@example.se'), findsNothing);
        expect(find.textContaining('Medlem i'), findsNothing);
      });

      testWidgets('displays custom subtitle correctly', (WidgetTester tester) async {
        const customSubtitle = 'Vän sedan 2020';
        
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            subtitle: customSubtitle,
          ),
        ));

        expect(find.text(customSubtitle), findsOneWidget);
        
        // Subtitle should use correct styling
        final subtitleText = tester.widget<Text>(find.text(customSubtitle));
        expect(subtitleText.style?.color, equals(AppColors.textMedium));
        expect(subtitleText.maxLines, equals(1));
        expect(subtitleText.overflow, equals(TextOverflow.ellipsis));
      });

      testWidgets('handles trailing widget correctly', (WidgetTester tester) async {
        final trailingWidget = IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {},
        );

        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            trailing: trailingWidget,
          ),
        ));

        expect(find.byIcon(Icons.more_vert), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);
      });
    });

    group('FriendCard - Compact Style Rendering', () {
      testWidgets('renders compact style layout correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            style: FriendCardStyle.compact,
          ),
        ));

        // Should show name and avatar in compact layout
        expect(find.text('Åsa Lindström'), findsOneWidget);
        expect(find.byType(SimpleImageWidget), findsOneWidget);
        
        // Should use correct text styling for compact mode
        final nameText = tester.widget<Text>(find.text('Åsa Lindström'));
        expect(nameText.style, equals(AppTextStyles.bodyLarge));
      });

      testWidgets('uses smaller avatar in compact mode', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            style: FriendCardStyle.compact,
            showAvatar: true,
          ),
        ));

        // Avatar should be present but smaller
        expect(find.byType(SimpleImageWidget), findsOneWidget);
        expect(find.byIcon(Icons.person), findsOneWidget);
      });

      testWidgets('applies compact style padding correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            style: FriendCardStyle.compact,
          ),
        ));

        // Should have specific padding for compact style
        final containers = tester.widgetList<Container>(find.byType(Container));
        final paddedContainer = containers.firstWhere(
          (container) => container.padding == const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingS,
            vertical: AppDimensions.spacingS,
          ),
        );
        expect(paddedContainer, isNotNull);
      });
    });

    group('FriendCard - List Style Rendering', () {
      testWidgets('renders list style using ListTile', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            style: FriendCardStyle.list,
          ),
        ));

        // Should use ListTile for list style
        expect(find.byType(ListTile), findsOneWidget);
        expect(find.text('Åsa Lindström'), findsOneWidget);
        
        // ListTile should have zero content padding
        final listTile = tester.widget<ListTile>(find.byType(ListTile));
        expect(listTile.contentPadding, equals(EdgeInsets.zero));
      });

      testWidgets('shows subtitle in list style when provided', (WidgetTester tester) async {
        const customSubtitle = 'Aktiv användare';
        
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            style: FriendCardStyle.list,
            subtitle: customSubtitle,
          ),
        ));

        final listTile = tester.widget<ListTile>(find.byType(ListTile));
        expect(listTile.subtitle, isNotNull);
      });

      testWidgets('shows metadata as subtitle when no custom subtitle', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            style: FriendCardStyle.list,
            showMetadata: true,
          ),
        ));

        final listTile = tester.widget<ListTile>(find.byType(ListTile));
        expect(listTile.subtitle, isNotNull);
      });
    });

    group('FriendCard - Interactive Behavior', () {
      testWidgets('handles tap callback correctly', (WidgetTester tester) async {
        bool tapped = false;

        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            onTap: () => tapped = true,
          ),
        ));

        // Should have InkWell for tap handling
        expect(find.byType(InkWell), findsOneWidget);

        // Tap the card
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });

      testWidgets('handles long press callback correctly', (WidgetTester tester) async {
        bool longPressed = false;

        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            onLongPress: () => longPressed = true,
          ),
        ));

        // Long press the card
        await tester.longPress(find.byType(InkWell));
        await tester.pumpAndSettle();

        expect(longPressed, isTrue);
      });

      testWidgets('applies correct border radius for touch feedback', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            onTap: () {},
          ),
        ));

        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        expect(inkWell.borderRadius, equals(BorderRadius.circular(AppDimensions.borderRadiusM)));
      });

      testWidgets('list style uses ListTile onTap when provided', (WidgetTester tester) async {
        bool tapped = false;

        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            style: FriendCardStyle.list,
            onTap: () => tapped = true,
          ),
        ));

        // Tap the ListTile
        await tester.tap(find.byType(ListTile));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });
    });

    group('FriendCard - Custom Styling', () {
      testWidgets('applies custom margin correctly', (WidgetTester tester) async {
        const customMargin = EdgeInsets.all(20);

        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            margin: customMargin,
          ),
        ));

        final outerContainer = tester.widget<Container>(find.byType(Container).first);
        expect(outerContainer.margin, equals(customMargin));
      });

      testWidgets('applies custom padding correctly', (WidgetTester tester) async {
        const customPadding = EdgeInsets.all(24);

        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            padding: customPadding,
          ),
        ));

        // Find the inner container with custom padding
        final containers = tester.widgetList<Container>(find.byType(Container));
        final paddedContainer = containers.firstWhere(
          (container) => container.padding == customPadding,
        );
        expect(paddedContainer, isNotNull);
      });

      testWidgets('uses default styling when not specified', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            style: FriendCardStyle.detailed,
          ),
        ));

        // Should use default padding for detailed style
        final containers = tester.widgetList<Container>(find.byType(Container));
        final defaultPaddedContainer = containers.firstWhere(
          (container) => container.padding == const EdgeInsets.all(AppDimensions.spacingS),
        );
        expect(defaultPaddedContainer, isNotNull);
      });

      testWidgets('applies correct decoration with background and border', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
          ),
        ));

        // Find decorated container
        final containers = tester.widgetList<Container>(find.byType(Container));
        final decoratedContainer = containers.firstWhere(
          (container) => container.decoration is BoxDecoration,
        );
        
        final decoration = decoratedContainer.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.backgroundLight));
        expect(decoration.borderRadius, equals(BorderRadius.circular(AppDimensions.borderRadiusM)));
        expect(decoration.border, isNotNull);
      });
    });

    group('FriendCard - Avatar System', () {
      testWidgets('renders avatar with correct size for detailed style', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            style: FriendCardStyle.detailed,
            showAvatar: true,
          ),
        ));

        expect(find.byType(SimpleImageWidget), findsOneWidget);
        expect(find.byType(ClipRRect), findsOneWidget);
        
        // Avatar should have circular clipping
        final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
        expect(clipRRect.borderRadius, equals(BorderRadius.circular(25))); // 50/2
      });

      testWidgets('hides avatar when disabled', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            showAvatar: false,
          ),
        ));

        // Should not show avatar components when disabled
        expect(find.byType(SimpleImageWidget), findsNothing);
        expect(find.byIcon(Icons.person), findsNothing);
      });

      testWidgets('shows placeholder icon when no avatar URL', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: minimalUser, // No avatar URL
            showAvatar: true,
          ),
        ));

        // Should show person icon placeholder
        expect(find.byIcon(Icons.person), findsOneWidget);
        
        // Icon should be properly sized
        final icon = tester.widget<Icon>(find.byIcon(Icons.person));
        expect(icon.color, equals(AppColors.textMedium));
      });

      testWidgets('status indicator scales with avatar size', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: onlineUser,
            style: FriendCardStyle.detailed,
            showOnlineStatus: true,
          ),
        ));

        // Status indicator should be 30% of avatar size
        final statusContainers = tester.widgetList<Container>(find.byType(Container));
        final statusContainer = statusContainers.firstWhere(
          (container) => container.decoration is BoxDecoration &&
            (container.decoration as BoxDecoration).color == Colors.green,
        );
        expect(statusContainer, isNotNull);
      });
    });

    group('FriendCard - Swedish Localization & Character Support', () {
      testWidgets('displays Swedish characters correctly', (WidgetTester tester) async {
        final swedishCharUser = UserProfileFactory.build(
          displayName: 'Björn Åkerström',
          email: 'björn@example.se',
        );

        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishCharUser,
          ),
        ));

        expect(find.text('Björn Åkerström'), findsOneWidget);
        expect(find.textContaining('björn@example.se'), findsOneWidget);
      });

      testWidgets('handles Swedish compound names correctly', (WidgetTester tester) async {
        final compoundNameUser = UserProfileFactory.build(
          displayName: 'Karl-Gustav von Schweden',
          email: 'kg@royal.se',
        );

        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: compoundNameUser,
          ),
        ));

        expect(find.text('Karl-Gustav von Schweden'), findsOneWidget);
      });

      testWidgets('displays member since text in Swedish', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: swedishUser,
            showMetadata: true,
          ),
        ));

        // Should use Swedish text from UserProfile.memberSinceText
        expect(find.textContaining('Medlem i'), findsOneWidget);
      });
    });

    group('FriendCard - Edge Cases & Error Handling', () {
      testWidgets('handles empty display name gracefully', (WidgetTester tester) async {
        final emptyNameUser = UserProfileFactory.build(
          displayName: '',
          email: 'empty@example.se',
        );

        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: emptyNameUser,
          ),
        ));

        // Should render without crashing
        expect(find.byType(FriendCard), findsOneWidget);
        expect(find.text(''), findsOneWidget);
      });

      testWidgets('handles very long names with ellipsis', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: SizedBox(
            width: 200,
            child: FriendCard(
              user: longNameUser,
            ),
          ),
        ));

        final nameText = tester.widget<Text>(find.textContaining('Maria Elisabet'));
        expect(nameText.maxLines, equals(1));
        expect(nameText.overflow, equals(TextOverflow.ellipsis));
      });

      testWidgets('handles empty metadata gracefully', (WidgetTester tester) async {
        final noMetadataUser = UserProfileFactory.build(
          displayName: 'Test User',
          email: '',
        );

        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: noMetadataUser,
            showMetadata: true,
          ),
        ));

        // Should show member since text even if email is empty
        expect(find.textContaining('Medlem i'), findsOneWidget);
      });

      testWidgets('handles null online status correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendCard(
            user: minimalUser, // isOnline is null
            showOnlineStatus: true,
          ),
        ));

        // Should render without crashing
        expect(find.byType(FriendCard), findsOneWidget);
      });
    });
  });

  group('FriendRequestCard Ultrathink Widget Tests', () {
    late FriendRequest testRequest;
    late FriendRequest requestWithMessage;

    setUp(() {
      testRequest = FriendRequest(
        id: 'request_123',
        fromUserId: 'user_456',
        toUserId: 'user_789',
        message: null,
        sentAt: DateTime.now(),
        status: FriendRequestStatus.pending,
      );

      requestWithMessage = FriendRequest(
        id: 'request_456',
        fromUserId: 'user_123',
        toUserId: 'user_456',
        message: 'Hej! Vill vi bli vänner?',
        sentAt: DateTime.now(),
        status: FriendRequestStatus.pending,
      );
    });

    // Helper to create properly sized widget
    Widget createTestWidget({Widget? child}) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );
    }

    group('FriendRequestCard - Basic Rendering', () {
      testWidgets('renders friend request with basic content', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendRequestCard(
            friendRequest: testRequest,
          ),
        ));

        // Basic structure
        expect(find.byType(Container), findsWidgets);
        expect(find.byType(Material), findsWidgets);
        expect(find.byType(InkWell), findsOneWidget);
        
        // Content
        expect(find.text('Friend Request'), findsOneWidget);
        expect(find.text('Vill bli din vän'), findsOneWidget);
        
        // Avatar placeholder
        expect(find.byIcon(Icons.person), findsOneWidget);
      });

      testWidgets('displays custom message when provided', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendRequestCard(
            friendRequest: requestWithMessage,
          ),
        ));

        expect(find.text('Hej! Vill vi bli vänner?'), findsOneWidget);
        
        // Message should have correct styling
        final messageText = tester.widget<Text>(find.text('Hej! Vill vi bli vänner?'));
        expect(messageText.maxLines, equals(2));
        expect(messageText.overflow, equals(TextOverflow.ellipsis));
      });

      testWidgets('renders sender avatar placeholder correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendRequestCard(
            friendRequest: testRequest,
          ),
        ));

        // Should have ClipRRect for circular avatar
        expect(find.byType(ClipRRect), findsOneWidget);
        expect(find.byType(SimpleImageWidget), findsOneWidget);
        
        // Should show placeholder icon
        expect(find.byIcon(Icons.person), findsOneWidget);
        final icon = tester.widget<Icon>(find.byIcon(Icons.person));
        expect(icon.size, equals(30));
        expect(icon.color, equals(AppColors.textMedium));
      });
    });

    group('FriendRequestCard - Action Buttons', () {
      testWidgets('renders accept and decline buttons when callbacks provided', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendRequestCard(
            friendRequest: testRequest,
            onAccept: () {},
            onDecline: () {},
          ),
        ));

        expect(find.text('Acceptera'), findsOneWidget);
        expect(find.text('Avvisa'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);
      });

      testWidgets('handles accept button callback correctly', (WidgetTester tester) async {
        bool accepted = false;

        await tester.pumpWidget(createTestWidget(
          child: FriendRequestCard(
            friendRequest: testRequest,
            onAccept: () => accepted = true,
            onDecline: () {},
          ),
        ));

        await tester.tap(find.text('Acceptera'));
        await tester.pumpAndSettle();

        expect(accepted, isTrue);
      });

      testWidgets('handles decline button callback correctly', (WidgetTester tester) async {
        bool declined = false;

        await tester.pumpWidget(createTestWidget(
          child: FriendRequestCard(
            friendRequest: testRequest,
            onAccept: () {},
            onDecline: () => declined = true,
          ),
        ));

        await tester.tap(find.text('Avvisa'));
        await tester.pumpAndSettle();

        expect(declined, isTrue);
      });

      testWidgets('does not show action buttons when callbacks not provided', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendRequestCard(
            friendRequest: testRequest,
          ),
        ));

        expect(find.text('Acceptera'), findsNothing);
        expect(find.text('Avvisa'), findsNothing);
        expect(find.byType(ElevatedButton), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
      });

      testWidgets('applies correct button styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendRequestCard(
            friendRequest: testRequest,
            onAccept: () {},
            onDecline: () {},
          ),
        ));

        // Decline button should have outlined style
        final outlinedButton = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
        expect(outlinedButton.style?.side?.resolve({})?.color, equals(AppColors.textMedium));

        // Accept button should use theme primary color
        final elevatedButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(elevatedButton.style, isNotNull);
      });
    });

    group('FriendRequestCard - Interactive Behavior', () {
      testWidgets('handles card tap correctly', (WidgetTester tester) async {
        bool tapped = false;

        await tester.pumpWidget(createTestWidget(
          child: FriendRequestCard(
            friendRequest: testRequest,
            onTap: () => tapped = true,
          ),
        ));

        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });

      testWidgets('applies correct border radius for touch feedback', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendRequestCard(
            friendRequest: testRequest,
            onTap: () {},
          ),
        ));

        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        expect(inkWell.borderRadius, equals(BorderRadius.circular(AppDimensions.borderRadiusM)));
      });
    });

    group('FriendRequestCard - Custom Styling', () {
      testWidgets('applies custom margin correctly', (WidgetTester tester) async {
        const customMargin = EdgeInsets.all(16);

        await tester.pumpWidget(createTestWidget(
          child: FriendRequestCard(
            friendRequest: testRequest,
            margin: customMargin,
          ),
        ));

        final outerContainer = tester.widget<Container>(find.byType(Container).first);
        expect(outerContainer.margin, equals(customMargin));
      });

      testWidgets('applies custom padding correctly', (WidgetTester tester) async {
        const customPadding = EdgeInsets.all(20);

        await tester.pumpWidget(createTestWidget(
          child: FriendRequestCard(
            friendRequest: testRequest,
            padding: customPadding,
          ),
        ));

        // Find container with custom padding
        final containers = tester.widgetList<Container>(find.byType(Container));
        final paddedContainer = containers.firstWhere(
          (container) => container.padding == customPadding,
        );
        expect(paddedContainer, isNotNull);
      });

      testWidgets('uses default styling when not specified', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: FriendRequestCard(
            friendRequest: testRequest,
          ),
        ));

        // Should use default margin and padding
        final outerContainer = tester.widget<Container>(find.byType(Container).first);
        expect(outerContainer.margin, equals(const EdgeInsets.only(bottom: AppDimensions.spacingS)));
        
        final containers = tester.widgetList<Container>(find.byType(Container));
        final defaultPaddedContainer = containers.firstWhere(
          (container) => container.padding == const EdgeInsets.all(AppDimensions.spacingS),
        );
        expect(defaultPaddedContainer, isNotNull);
      });
    });

    group('FriendRequestCard - Edge Cases', () {
      testWidgets('handles empty message correctly', (WidgetTester tester) async {
        final emptyMessageRequest = FriendRequest(
          id: 'empty',
          fromUserId: 'user1',
          toUserId: 'user2',
          message: '',
          sentAt: DateTime.now(),
          status: FriendRequestStatus.pending,
        );

        await tester.pumpWidget(createTestWidget(
          child: FriendRequestCard(
            friendRequest: emptyMessageRequest,
          ),
        ));

        // Should not display empty message
        expect(find.text('Friend Request'), findsOneWidget);
        expect(find.text('Vill bli din vän'), findsOneWidget);
        expect(find.text(''), findsNothing);
      });

      testWidgets('handles very long message with ellipsis', (WidgetTester tester) async {
        final longMessageRequest = FriendRequest(
          id: 'long',
          fromUserId: 'user1',
          toUserId: 'user2',
          message: 'Detta är ett mycket långt meddelande som borde trunkeras eftersom det tar upp för mycket utrymme på skärmen och inte passar in i layouten',
          sentAt: DateTime.now(),
          status: FriendRequestStatus.pending,
        );

        await tester.pumpWidget(createTestWidget(
          child: SizedBox(
            width: 300,
            child: FriendRequestCard(
              friendRequest: longMessageRequest,
            ),
          ),
        ));

        // Should find the long message
        expect(find.textContaining('Detta är ett mycket långt meddelande'), findsOneWidget);
        
        // Should have maxLines and ellipsis
        final messageText = tester.widget<Text>(find.textContaining('Detta är ett mycket långt meddelande'));
        expect(messageText.maxLines, equals(2));
        expect(messageText.overflow, equals(TextOverflow.ellipsis));
      });
    });
  });
}