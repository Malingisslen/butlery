import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/widgets/recipe/recipe_detail_comments.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/models/social/social_comment.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

// Comprehensive widget test for RecipeDetailComments following ultrathink methodology
void main() {
  setUp(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('RecipeDetailComments Tests', () {
    // Test data
    late MockSocialRecipeViewModel mockSocialViewModel;
    late MockUserService mockUserService;
    late MockFirebaseAuthRepository mockAuthRepository;

    final testUser = UserProfile(
      uid: 'user123',
      displayName: 'Anna Andersson',
      email: 'anna@test.se',
      avatarUrl: 'https://example.com/avatar.jpg',
      isSearchable: true,
      joinedAt: DateTime.now().subtract(const Duration(days: 30)),
      lastActiveAt: DateTime.now().subtract(const Duration(hours: 1)),
    );

    final testComment = SocialComment(
      id: 'comment123',
      recipeId: 'recipe123',
      authorId: 'user123',
      text: 'Fantastiskt recept! Barnen älskade det.',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      likeCount: 3,
    );

    final testReply = SocialComment(
      id: 'reply123',
      recipeId: 'recipe123',
      authorId: 'user456',
      text: 'Håller med! Vilken krydda använde du?',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      parentCommentId: 'comment123',
      likeCount: 1,
    );

    setUp(() {
      mockSocialViewModel = MockSocialRecipeViewModel();
      mockUserService = MockUserService();
      mockAuthRepository = MockFirebaseAuthRepository();

      // Default mock setup
      when(() => mockSocialViewModel.hasComments).thenReturn(false);
      when(() => mockSocialViewModel.comments).thenReturn([]);
      when(() => mockSocialViewModel.friends).thenReturn([]);
      when(() => mockSocialViewModel.currentUser).thenReturn(null);
      when(() => mockSocialViewModel.isLoadingComments).thenReturn(false);
      when(() => mockSocialViewModel.commentsError).thenReturn(null);
      when(() => mockSocialViewModel.topLevelComments).thenReturn([]);
      when(() => mockSocialViewModel.newCommentText).thenReturn('');
      when(() => mockSocialViewModel.isPostingComment).thenReturn(false);
      when(() => mockSocialViewModel.isReplying).thenReturn(false);
      when(() => mockSocialViewModel.refreshComments(any())).thenAnswer((_) async {});
      when(() => mockSocialViewModel.updateNewCommentText(any())).thenReturn(null);
      when(() => mockSocialViewModel.postComment(any())).thenAnswer((_) async {});
      when(() => mockSocialViewModel.toggleCommentLike(any())).thenAnswer((_) async {});
      when(() => mockSocialViewModel.setReplyTo(any())).thenReturn(null);
      when(() => mockSocialViewModel.cancelReply()).thenReturn(null);
      when(() => mockSocialViewModel.hasLikedComment(any())).thenReturn(false);
      when(() => mockSocialViewModel.getAuthorDisplayName(any())).thenReturn('Test User');
      when(() => mockSocialViewModel.getAuthorAvatarUrl(any())).thenReturn(null);
      when(() => mockSocialViewModel.getReplies(any())).thenReturn([]);

      // Mock services
      when(() => mockUserService.currentUserProfile).thenReturn(null);
      when(() => mockUserService.isLoading).thenReturn(false);
      when(() => mockUserService.error).thenReturn(null);
      when(() => mockUserService.createOrUpdateProfile(
        displayName: any(named: 'displayName'),
        isSearchable: any(named: 'isSearchable'),
        allowEmailSearch: any(named: 'allowEmailSearch'),
      )).thenAnswer((_) async => testUser);

      when(() => mockAuthRepository.currentUser).thenReturn(null);
    });

    group('Basic Rendering', () {
      testWidgets('renders with required properties', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        expect(find.byType(RecipeDetailComments), findsOneWidget);
        expect(find.text('Kommentarer'), findsOneWidget);
        expect(find.byIcon(Icons.comment_outlined), findsOneWidget);
      });

      testWidgets('shows comment count when has comments', (WidgetTester tester) async {
        when(() => mockSocialViewModel.hasComments).thenReturn(true);
        when(() => mockSocialViewModel.comments).thenReturn([testComment]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        expect(find.textContaining('Kommentarer (1)'), findsOneWidget);
      });

      testWidgets('shows expand/collapse icon when has friends', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.expand_more), findsOneWidget);
      });

      testWidgets('hides expand icon when no friends', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.expand_more), findsNothing);
        expect(find.byIcon(Icons.expand_less), findsNothing);
      });
    });

    group('Expand/Collapse Functionality', () {
      testWidgets('expands when header is tapped', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Initially collapsed
        expect(find.byIcon(Icons.expand_more), findsOneWidget);
        expect(find.byType(Divider), findsNothing);

        // Tap to expand
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        // Should be expanded
        expect(find.byIcon(Icons.expand_less), findsOneWidget);
        expect(find.byType(Divider), findsOneWidget);
      });

      testWidgets('calls refreshComments when expanding for first time', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(false);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Tap to expand
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        // Should call refreshComments
        verify(() => mockSocialViewModel.refreshComments('recipe123')).called(1);
      });

      testWidgets('collapses when expanded and tapped again', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();
        expect(find.byIcon(Icons.expand_less), findsOneWidget);

        // Collapse
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();
        expect(find.byIcon(Icons.expand_more), findsOneWidget);
        expect(find.byType(Divider), findsNothing);
      });
    });

    group('Loading States', () {
      testWidgets('shows loading indicator when comments are loading', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.isLoadingComments).thenReturn(true);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show loading
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Laddar kommentarer...'), findsOneWidget);
      });

      testWidgets('shows error state when comments error occurs', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.commentsError).thenReturn('Kunde inte ladda kommentarer');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show error
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Kunde inte ladda kommentarer'), findsOneWidget);
      });
    });

    group('Empty State', () {
      testWidgets('shows empty state when no comments', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(false);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show empty state
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
        expect(find.text('Inga kommentarer än'), findsOneWidget);
        expect(find.text('Bli först att kommentera detta recept!'), findsOneWidget);
      });
    });

    group('Comment Display', () {
      testWidgets('displays comments when available', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(true);
        when(() => mockSocialViewModel.topLevelComments).thenReturn([testComment]);
        when(() => mockSocialViewModel.getAuthorDisplayName('user123')).thenReturn('Anna Andersson');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show comments
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.text('Anna Andersson'), findsOneWidget);
        expect(find.text('Fantastiskt recept! Barnen älskade det.'), findsOneWidget);
        expect(find.text('2h'), findsOneWidget); // Time formatting
      });

      testWidgets('displays replies with proper indentation', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(true);
        when(() => mockSocialViewModel.topLevelComments).thenReturn([testComment]);
        when(() => mockSocialViewModel.getReplies('comment123')).thenReturn([testReply]);
        when(() => mockSocialViewModel.getAuthorDisplayName('user123')).thenReturn('Anna Andersson');
        when(() => mockSocialViewModel.getAuthorDisplayName('user456')).thenReturn('Erik Svensson');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show comments
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.text('Anna Andersson'), findsOneWidget);
        expect(find.text('Erik Svensson'), findsOneWidget);
        expect(find.text('Håller med! Vilken krydda använde du?'), findsOneWidget);
      });

      testWidgets('shows like count when comment has likes', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(true);
        when(() => mockSocialViewModel.topLevelComments).thenReturn([testComment]);
        when(() => mockSocialViewModel.getAuthorDisplayName('user123')).thenReturn('Anna Andersson');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show comments
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.text('3'), findsOneWidget); // Like count
        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      });

      testWidgets('shows filled heart when user liked comment', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(true);
        when(() => mockSocialViewModel.topLevelComments).thenReturn([testComment]);
        when(() => mockSocialViewModel.getAuthorDisplayName('user123')).thenReturn('Anna Andersson');
        when(() => mockSocialViewModel.hasLikedComment('comment123')).thenReturn(true);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show comments
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.byIcon(Icons.favorite), findsOneWidget);
      });
    });

    group('Comment Interactions', () {
      testWidgets('handles comment like tap', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(true);
        when(() => mockSocialViewModel.topLevelComments).thenReturn([testComment]);
        when(() => mockSocialViewModel.getAuthorDisplayName('user123')).thenReturn('Anna Andersson');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show comments
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        // Tap like button
        await tester.tap(find.byIcon(Icons.favorite_border));
        
        verify(() => mockSocialViewModel.toggleCommentLike('comment123')).called(1);
      });

      testWidgets('handles reply button tap', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(true);
        when(() => mockSocialViewModel.topLevelComments).thenReturn([testComment]);
        when(() => mockSocialViewModel.getAuthorDisplayName('user123')).thenReturn('Anna Andersson');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show comments
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        // Tap reply button
        await tester.tap(find.text('Svara'));
        
        verify(() => mockSocialViewModel.setReplyTo('comment123')).called(1);
      });
    });

    group('Comment Form', () {
      testWidgets('shows comment form when user is logged in', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.currentUser).thenReturn(testUser);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show comment form
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Skriv en kommentar...'), findsOneWidget);
        expect(find.byIcon(Icons.send), findsOneWidget);
      });

      testWidgets('shows reply hint when replying', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.currentUser).thenReturn(testUser);
        when(() => mockSocialViewModel.isReplying).thenReturn(true);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show comment form
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.text('Svarar på kommentar'), findsOneWidget);
        expect(find.text('Skriv ditt svar...'), findsOneWidget);
        expect(find.byIcon(Icons.reply), findsOneWidget);
      });

      testWidgets('handles cancel reply', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.currentUser).thenReturn(testUser);
        when(() => mockSocialViewModel.isReplying).thenReturn(true);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show comment form
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        // Tap cancel button
        await tester.tap(find.byIcon(Icons.close));
        
        verify(() => mockSocialViewModel.cancelReply()).called(1);
      });

      testWidgets('handles text input changes', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.currentUser).thenReturn(testUser);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show comment form
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        // Type in text field
        await tester.enterText(find.byType(TextField), 'Bra recept!');
        
        verify(() => mockSocialViewModel.updateNewCommentText('Bra recept!')).called(1);
      });

      testWidgets('enables send button when text is not empty', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.currentUser).thenReturn(testUser);
        when(() => mockSocialViewModel.newCommentText).thenReturn('Test comment');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show comment form
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        final sendButton = tester.widget<IconButton>(find.byIcon(Icons.send).last);
        expect(sendButton.onPressed, isNotNull);
      });

      testWidgets('shows loading indicator when posting comment', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.currentUser).thenReturn(testUser);
        when(() => mockSocialViewModel.isPostingComment).thenReturn(true);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show comment form
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
      });
    });

    group('Profile Creation Flow', () {
      testWidgets('shows login prompt when user is not logged in', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.currentUser).thenReturn(null);

        await tester.pumpWidget(
          MaterialApp(
            routes: {
              '/profile/edit': (context) => const Scaffold(body: Text('Profile Edit')),
            },
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show login prompt
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
        expect(find.text('Skapa profil för att kommentera'), findsOneWidget);
        expect(find.text('Skapa profil'), findsOneWidget);
      });
    });

    group('Time Formatting', () {
      testWidgets('shows "nu" for recent comments', (WidgetTester tester) async {
        final recentComment = SocialComment(
          id: 'comment123',
          recipeId: 'recipe123',
          authorId: 'user123',
          text: 'Just posted!',
          createdAt: DateTime.now().subtract(const Duration(seconds: 30)),
        );

        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(true);
        when(() => mockSocialViewModel.topLevelComments).thenReturn([recentComment]);
        when(() => mockSocialViewModel.getAuthorDisplayName('user123')).thenReturn('Anna');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show comments
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.text('nu'), findsOneWidget);
      });

      testWidgets('shows minutes for recent comments', (WidgetTester tester) async {
        final minutesAgoComment = SocialComment(
          id: 'comment123',
          recipeId: 'recipe123',
          authorId: 'user123',
          text: 'Posted 15 minutes ago',
          createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        );

        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.hasComments).thenReturn(true);
        when(() => mockSocialViewModel.topLevelComments).thenReturn([minutesAgoComment]);
        when(() => mockSocialViewModel.getAuthorDisplayName('user123')).thenReturn('Anna');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show comments
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.text('15m'), findsOneWidget);
      });
    });

    group('Swedish Localization', () {
      testWidgets('displays Swedish text throughout interface', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.currentUser).thenReturn(testUser);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Expand to show Swedish text
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();

        expect(find.text('Kommentarer'), findsOneWidget);
        expect(find.text('Inga kommentarer än'), findsOneWidget);
        expect(find.text('Bli först att kommentera detta recept!'), findsOneWidget);
        expect(find.text('Skriv en kommentar...'), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('handles onCommentPosted callback', (WidgetTester tester) async {
        bool callbackCalled = false;
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);
        when(() => mockSocialViewModel.currentUser).thenReturn(testUser);
        when(() => mockSocialViewModel.newCommentText).thenReturn('Test comment');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
                onCommentPosted: () {
                  callbackCalled = true;
                },
              ),
            ),
          ),
        );

        // Expand and post comment
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        expect(callbackCalled, isTrue);
      });

      testWidgets('handles widget disposal safely', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Remove widget to trigger disposal
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(),
            ),
          ),
        );

        // Should not throw any errors
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles mount state properly in callbacks', (WidgetTester tester) async {
        when(() => mockSocialViewModel.friends).thenReturn([testUser]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeDetailComments(
                socialViewModel: mockSocialViewModel,
                recipeId: 'recipe123',
              ),
            ),
          ),
        );

        // Tap expand - should not throw error if widget is mounted
        await tester.tap(find.byType(InkWell).first);
        expect(tester.takeException(), isNull);
      });
    });
  });
}

// Mock classes
class MockSocialRecipeViewModel extends Mock implements SocialRecipeViewModel {}
class MockUserService extends Mock implements UserService {}
class MockFirebaseAuthRepository extends Mock implements FirebaseAuthRepository {}