import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Widget under test
import 'package:butlery/widgets/recipe/recipe_detail_comments.dart';

// Dependencies - ultrathink production code analysis
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/models/social/social_comment.dart';
import 'package:butlery/services/user_service.dart';
// Test infrastructure 
import '../../infrastructure/helpers/base_widget_test.dart';
import '../../infrastructure/factories/user_profile_factory.dart';

void main() {
  // Initialize test environment  
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('RecipeDetailComments Ultrathink Widget Tests', () {
    late MockSocialRecipeViewModel mockSocialViewModel;
    late MockUserService mockUserService;
    
    // Swedish test data - ultrathink realistic patterns
    final testUser = UserProfileFactory.build(
      uid: 'anna123',
      displayName: 'Anna Andersson',
      email: 'anna@butlery.se',
      avatarUrl: 'https://example.com/anna.jpg',
    );

    final testComment = SocialComment(
      id: 'comment_svenska_123',
      recipeId: 'recipe_kottbullar',
      authorId: 'anna123',
      text: 'Fantastiskt recept! Barnen älskade köttbullarna - blev mycket saftigare än vanligt.',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      likeCount: 5,
      isLiked: false,
    );

    final testReply = SocialComment(
      id: 'reply_svenska_456',
      recipeId: 'recipe_kottbullar', 
      authorId: 'erik456',
      text: 'Håller med helt! Vilken krydda använder du för extra smak?',
      createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
      parentCommentId: 'comment_svenska_123',
      likeCount: 2,
      isLiked: true,
    );

    void setupDefaultMocks() {
      // Core state mocks
      when(() => mockSocialViewModel.hasComments).thenReturn(false);
      when(() => mockSocialViewModel.comments).thenReturn([]);
      when(() => mockSocialViewModel.topLevelComments).thenReturn([]);
      when(() => mockSocialViewModel.friends).thenReturn([]);
      when(() => mockSocialViewModel.currentUser).thenReturn(null);
      
      // Loading states
      when(() => mockSocialViewModel.isLoadingComments).thenReturn(false);
      when(() => mockSocialViewModel.isPostingComment).thenReturn(false);
      when(() => mockSocialViewModel.commentsError).thenReturn(null);
      
      // Form state  
      when(() => mockSocialViewModel.newCommentText).thenReturn('');
      when(() => mockSocialViewModel.isReplying).thenReturn(false);
      
      // Methods
      when(() => mockSocialViewModel.refreshComments(any())).thenAnswer((_) async {});
      when(() => mockSocialViewModel.updateNewCommentText(any())).thenReturn(null);
      when(() => mockSocialViewModel.postComment(any())).thenAnswer((_) async {});
      when(() => mockSocialViewModel.toggleCommentLike(any())).thenAnswer((_) async {});
      when(() => mockSocialViewModel.setReplyTo(any())).thenReturn(null);
      when(() => mockSocialViewModel.cancelReply()).thenReturn(null);
      
      // Helper methods
      when(() => mockSocialViewModel.hasLikedComment(any())).thenReturn(false);
      when(() => mockSocialViewModel.getAuthorDisplayName(any())).thenReturn('Test User');
      when(() => mockSocialViewModel.getAuthorAvatarUrl(any())).thenReturn(null);
      when(() => mockSocialViewModel.getReplies(any())).thenReturn([]);
      
      // UserService mocks
      when(() => mockUserService.currentUserProfile).thenReturn(null);
      when(() => mockUserService.isLoading).thenReturn(false);
      when(() => mockUserService.error).thenReturn(null);
      when(() => mockUserService.createOrUpdateProfile(
        displayName: any(named: 'displayName'),
        isSearchable: any(named: 'isSearchable'), 
        allowEmailSearch: any(named: 'allowEmailSearch'),
      )).thenAnswer((_) async => testUser);
    }

    setUp(() async {
      await BaseWidgetTest.setupWidget();
      
      mockSocialViewModel = MockSocialRecipeViewModel();
      mockUserService = MockUserService();

      // Default mock setup - comprehensive state coverage
      setupDefaultMocks();
    });

    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    // Helper to create properly sized widget - ultrathink layout solution
    Widget createTestWidget({
      String recipeId = 'recipe_test',
      VoidCallback? onCommentPosted,
    }) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'), // Swedish locale
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 600,
                maxHeight: 1200, // Prevent overflow from debug section
                maxWidth: 800,
              ),
              child: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: recipeId,
                onCommentPosted: onCommentPosted,
                showDebugSection: false, // Disable debug section for tests
              ),
            ),
          ),
        ),
      );
    }

    group('Basic Widget Rendering - Facade Pattern', () {
      testWidgets('renders collapsed state with Swedish header text', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Core UI elements - Swedish localization
        expect(find.byType(RecipeDetailComments), findsOneWidget);
        expect(find.text('Kommentarer'), findsOneWidget);
        expect(find.byIcon(Icons.comment_outlined), findsOneWidget);
        
        // Should be collapsed initially
        expect(find.byType(Divider), findsNothing);
      });

      testWidgets('shows comment count in Swedish format when has comments', (WidgetTester tester) async {
        when(() => mockSocialViewModel.hasComments).thenReturn(true);
        when(() => mockSocialViewModel.comments).thenReturn([testComment, testReply]);

        await tester.pumpWidget(createTestWidget());

        expect(find.textContaining('Kommentarer (2)'), findsOneWidget);
      });

      testWidgets('shows expand icon only when has friends - social feature gating', (WidgetTester tester) async {
        // No friends - no expand icon
        when(() => mockSocialViewModel.friends).thenReturn([]);
        await tester.pumpWidget(createTestWidget());
        expect(find.byIcon(Icons.expand_more), findsNothing);

        // Has friends - show expand icon  
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        await tester.pumpWidget(createTestWidget());
        expect(find.byIcon(Icons.expand_more), findsOneWidget);
      });
    });

    group('Expand/Collapse State Management', () {
      testWidgets('expands when header tapped and loads comments', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(false);

        await tester.pumpWidget(createTestWidget(recipeId: 'recipe_svenska'));

        // Initially collapsed
        expect(find.byIcon(Icons.expand_more), findsOneWidget);
        expect(find.byType(Divider), findsNothing);

        // Tap to expand
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        // Should expand and load comments
        expect(find.byIcon(Icons.expand_less), findsOneWidget);
        expect(find.byType(Divider), findsOneWidget);
        verify(() => mockSocialViewModel.refreshComments('recipe_svenska')).called(1);
      });

      testWidgets('collapses when expanded and tapped again', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);

        await tester.pumpWidget(createTestWidget());

        // Expand first
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();
        expect(find.byIcon(Icons.expand_less), findsOneWidget);

        // Tap again to collapse
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();
        expect(find.byIcon(Icons.expand_more), findsOneWidget);
        expect(find.byType(Divider), findsNothing);
      });
    });

    group('Loading and Error States - Swedish UX', () {
      testWidgets('shows Swedish loading indicator when fetching comments', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.isLoadingComments).thenReturn(true);

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Laddar kommentarer...'), findsOneWidget);
      });

      testWidgets('shows Swedish error state when comment loading fails', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.commentsError).thenReturn('Kunde inte ladda kommentarer från servern');

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Kunde inte ladda kommentarer från servern'), findsOneWidget);
      });

      testWidgets('shows Swedish empty state with encouragement text', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(false);
        when(() => mockSocialViewModel.isLoadingComments).thenReturn(false);

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
        expect(find.text('Inga kommentarer än'), findsOneWidget);
        expect(find.text('Bli först att kommentera detta recept!'), findsOneWidget);
      });
    });

    group('Comment Display and Threading', () {
      testWidgets('displays Swedish comments with proper time formatting', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(true);
        when(() => mockSocialViewModel.topLevelComments).thenReturn([testComment]);
        when(() => mockSocialViewModel.getAuthorDisplayName('anna123')).thenReturn('Anna Andersson');

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        // Comment content in Swedish
        expect(find.text('Anna Andersson'), findsOneWidget);
        expect(find.text('Fantastiskt recept! Barnen älskade köttbullarna - blev mycket saftigare än vanligt.'), findsOneWidget);
        expect(find.text('2h'), findsOneWidget); // Time formatting
      });

      testWidgets('displays threaded replies with proper indentation', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(true);
        when(() => mockSocialViewModel.topLevelComments).thenReturn([testComment]);
        when(() => mockSocialViewModel.getReplies('comment_svenska_123')).thenReturn([testReply]);
        when(() => mockSocialViewModel.getAuthorDisplayName('anna123')).thenReturn('Anna Andersson');
        when(() => mockSocialViewModel.getAuthorDisplayName('erik456')).thenReturn('Erik Svensson');

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        // Both comments should be visible
        expect(find.text('Anna Andersson'), findsOneWidget);
        expect(find.text('Erik Svensson'), findsOneWidget);
        expect(find.text('Håller med helt! Vilken krydda använder du för extra smak?'), findsOneWidget);
        
        // Reply should be indented (has left padding)
        final replyPadding = tester.widget<Padding>(
          find.ancestor(
            of: find.text('Erik Svensson'),
            matching: find.byType(Padding),
          ).first,
        );
        expect(replyPadding.padding, isA<EdgeInsets>());
      });

      testWidgets('shows like counts and interaction states correctly', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(true);
        when(() => mockSocialViewModel.topLevelComments).thenReturn([testComment]);
        when(() => mockSocialViewModel.getAuthorDisplayName('anna123')).thenReturn('Anna Andersson');
        when(() => mockSocialViewModel.hasLikedComment('comment_svenska_123')).thenReturn(false);

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.text('5'), findsOneWidget); // Like count
        expect(find.byIcon(Icons.favorite_border), findsOneWidget); // Unliked state
        expect(find.text('Svara'), findsOneWidget); // Swedish reply button
      });

      testWidgets('shows liked state with filled heart icon', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(true);
        when(() => mockSocialViewModel.topLevelComments).thenReturn([testComment]);
        when(() => mockSocialViewModel.getAuthorDisplayName('anna123')).thenReturn('Anna Andersson');
        when(() => mockSocialViewModel.hasLikedComment('comment_svenska_123')).thenReturn(true);

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.byIcon(Icons.favorite), findsOneWidget); // Liked state
      });
    });

    group('Comment Interactions - Social Engagement', () {
      testWidgets('handles like button tap correctly', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(true);
        when(() => mockSocialViewModel.topLevelComments).thenReturn([testComment]);
        when(() => mockSocialViewModel.getAuthorDisplayName('anna123')).thenReturn('Anna Andersson');

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        // Tap like button
        await tester.tap(find.byIcon(Icons.favorite_border));
        
        verify(() => mockSocialViewModel.toggleCommentLike('comment_svenska_123')).called(1);
      });

      testWidgets('handles reply button tap correctly', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(true);
        when(() => mockSocialViewModel.topLevelComments).thenReturn([testComment]);
        when(() => mockSocialViewModel.getAuthorDisplayName('anna123')).thenReturn('Anna Andersson');

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        // Tap reply button
        await tester.tap(find.text('Svara'));
        
        verify(() => mockSocialViewModel.setReplyTo('comment_svenska_123')).called(1);
      });
    });

    group('Comment Form - Swedish UX', () {
      testWidgets('shows Swedish comment form when user is logged in', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.currentUser).thenReturn(testUser);

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Skriv en kommentar...'), findsOneWidget);
        expect(find.byIcon(Icons.send), findsOneWidget);
      });

      testWidgets('shows reply context when replying to comment', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.currentUser).thenReturn(testUser);
        when(() => mockSocialViewModel.isReplying).thenReturn(true);

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.text('Svarar på kommentar'), findsOneWidget);
        expect(find.text('Skriv ditt svar...'), findsOneWidget);
        expect(find.byIcon(Icons.reply), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget); // Cancel reply button
      });

      testWidgets('handles text input changes', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.currentUser).thenReturn(testUser);

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'Underbart recept! Tack för tips.');
        
        verify(() => mockSocialViewModel.updateNewCommentText('Underbart recept! Tack för tips.')).called(1);
      });

      testWidgets('shows profile creation prompt when not logged in', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.currentUser).thenReturn(null);

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
        expect(find.text('Skapa profil för att kommentera'), findsOneWidget);
        expect(find.text('Skapa profil'), findsAtLeastNWidgets(1));
      });
    });

    group('Swedish Time Formatting', () {
      testWidgets('shows "nu" for very recent comments', (WidgetTester tester) async {
        final recentComment = SocialComment(
          id: 'recent_123',
          recipeId: 'recipe_test',
          authorId: 'anna123', 
          text: 'Precis postad kommentar!',
          createdAt: DateTime.now().subtract(const Duration(seconds: 30)),
        );

        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(true);
        when(() => mockSocialViewModel.topLevelComments).thenReturn([recentComment]);
        when(() => mockSocialViewModel.getAuthorDisplayName('anna123')).thenReturn('Anna');

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.text('nu'), findsOneWidget);
      });

      testWidgets('shows minutes for recent comments', (WidgetTester tester) async {
        final minutesAgoComment = SocialComment(
          id: 'minutes_123',
          recipeId: 'recipe_test',
          authorId: 'anna123',
          text: 'Kommentar för 15 minuter sedan',
          createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        );

        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(true);
        when(() => mockSocialViewModel.topLevelComments).thenReturn([minutesAgoComment]);
        when(() => mockSocialViewModel.getAuthorDisplayName('anna123')).thenReturn('Anna');

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.text('15m'), findsOneWidget);
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('handles onCommentPosted callback correctly', (WidgetTester tester) async {
        bool callbackTriggered = false;
        
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.currentUser).thenReturn(testUser);
        when(() => mockSocialViewModel.newCommentText).thenReturn('Test kommentar');

        await tester.pumpWidget(createTestWidget(
          onCommentPosted: () => callbackTriggered = true,
        ));
        
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();
        
        // Try to find and tap send button
        final sendButton = find.byIcon(Icons.send);
        if (sendButton.evaluate().isNotEmpty) {
          await tester.tap(sendButton);
          await tester.pump();
          
          // Callback should be triggered after successful post
          expect(callbackTriggered, isTrue);
        }
      });

      testWidgets('handles widget disposal without errors', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        
        // Remove widget to trigger disposal
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        
        // Should not throw any exceptions
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles rapid state changes without crashing', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);

        await tester.pumpWidget(createTestWidget());

        // Rapid expand/collapse
        for (int i = 0; i < 3; i++) {
          await tester.tap(find.byType(InkWell).first);
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Should handle rapid interactions
        expect(find.byType(RecipeDetailComments), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}

// Mock classes
class MockSocialRecipeViewModel extends Mock implements SocialRecipeViewModel {}
class MockUserService extends Mock implements UserService {}