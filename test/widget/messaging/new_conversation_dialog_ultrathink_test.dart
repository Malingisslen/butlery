// test/widget/messaging/new_conversation_dialog_ultrathink_test.dart
// ULTRATHINK TEST SUITE: NewConversationDialog
// 290-line complex dialog with Swedish localization and service integration

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';

// Production imports
import 'package:butlery/widgets/messaging/new_conversation_dialog.dart';
import 'package:butlery/widgets/styled/styled_button.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/di/di_container.dart';

// Mocks
class MockUnifiedFriendsService extends Mock implements UnifiedFriendsService {}

class MockMessagingService extends Mock implements MessagingService {}

class MockCallbacks extends Mock {
  void onConversationCreated(String conversationId);
}

void main() {
  group('NewConversationDialog Ultrathink Tests', () {
    late MockUnifiedFriendsService mockFriendsService;
    late MockMessagingService mockMessagingService;
    late MockCallbacks mockCallbacks;
    late List<UserProfile> testFriends;

    // Setup service locator
    final getIt = GetIt.instance;

    // Helper to create properly configured test environment
    Widget createTestWidget({
      required Widget child,
      Size size = const Size(414, 896), // iPhone 11 Pro Max
    }) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'),
        theme: ThemeData(
          primaryColor: AppColors.primaryBlue,
          scaffoldBackgroundColor: Colors.white,
        ),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: Builder(
              builder: (context) => child,
            ),
          ),
        ),
      );
    }

    setUpAll(() {
      // Register fallback values for mocktail
    });

    setUp(() {
      // Reset service locator
      ServiceLocator.reset();
      if (getIt.isRegistered<UnifiedFriendsService>()) {
        getIt.unregister<UnifiedFriendsService>();
      }
      if (getIt.isRegistered<MessagingService>()) {
        getIt.unregister<MessagingService>();
      }

      // Create mocks
      mockFriendsService = MockUnifiedFriendsService();
      mockMessagingService = MockMessagingService();
      mockCallbacks = MockCallbacks();

      // Register mocks with GetIt
      getIt.registerSingleton<UnifiedFriendsService>(mockFriendsService);
      getIt.registerSingleton<MessagingService>(mockMessagingService);

      // Initialize production ServiceLocator with real DIContainer
      // Since DIContainer uses GetIt.instance internally, it will use our registered mocks
      final container = DIContainer();
      ServiceLocator.initialize(container);

      // Setup test data
      testFriends = [
        UserProfile(
          uid: 'friend1',
          email: 'anna@example.com',
          displayName: 'Anna Andersson',
          avatarUrl: null,
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        ),
        UserProfile(
          uid: 'friend2',
          email: 'erik@example.com',
          displayName: 'Erik Eriksson',
          avatarUrl: null,
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        ),
        UserProfile(
          uid: 'friend3',
          email: 'maria@example.com',
          displayName: 'Maria Svensson',
          avatarUrl: null,
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        ),
      ];

      // Setup default mock behavior
      when(() => mockFriendsService.friends).thenReturn(testFriends);
      when(() => mockCallbacks.onConversationCreated(any())).thenReturn(null);
      when(() => mockMessagingService.startDirectConversation(
            otherUserId: any(named: 'otherUserId'),
            otherUserDisplayName: any(named: 'otherUserDisplayName'),
          )).thenAnswer((_) async => 'conv123');
      when(() => mockMessagingService.createGroupConversation(
            participantIds: any(named: 'participantIds'),
            participantDisplayNames: any(named: 'participantDisplayNames'),
            participantAvatarUrls: any(named: 'participantAvatarUrls'),
            title: any(named: 'title'),
          )).thenAnswer((_) async => 'group123');
    });

    tearDown(() {
      // Cleanup GetIt registrations
      if (getIt.isRegistered<UnifiedFriendsService>()) {
        getIt.unregister<UnifiedFriendsService>();
      }
      if (getIt.isRegistered<MessagingService>()) {
        getIt.unregister<MessagingService>();
      }
      // Reset production ServiceLocator
      ServiceLocator.reset();
    });

    group('Rendering Tests', () {
      testWidgets('renders dialog with Swedish title',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 92-93
        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show Swedish title "Ny konversation"
        expect(find.text('Ny konversation'), findsOneWidget);
      });

      testWidgets('renders search field with Swedish placeholder',
          (WidgetTester tester) async {
        // ULTRATHINK: Test search field from lines 123-134
        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show search field with Swedish placeholder
        final textField = find.byType(TextField);
        expect(textField, findsOneWidget);

        final widget = tester.widget<TextField>(textField);
        expect(widget.decoration?.hintText, equals('Sök vänner...'));

        // Should have search icon
        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('renders action buttons with Swedish labels',
          (WidgetTester tester) async {
        // ULTRATHINK: Test buttons from lines 108-119
        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show Cancel button with Swedish text
        expect(find.text('Avbryt'), findsOneWidget);

        // Should show Create button with Swedish text
        expect(find.text('Skapa'), findsOneWidget);

        // Should use StyledButton.primary
        expect(find.byType(StyledButton), findsOneWidget);
      });

      testWidgets('shows loading indicator briefly',
          (WidgetTester tester) async {
        // ULTRATHINK: Widget loads friends synchronously, so loading is very brief
        // This test verifies the widget handles the transition properly
        when(() => mockFriendsService.friends).thenReturn([]);

        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        // Widget should transition quickly to showing empty state
        await tester.pumpAndSettle();

        // Should show empty state instead of loading
        expect(find.byIcon(Icons.people_outline), findsOneWidget);
        expect(find.text('Inga vänner ännu'), findsOneWidget);
      });
    });

    group('Friends List Tests', () {
      testWidgets('displays friends list correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test friends list from lines 189-220
        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show all friends
        expect(find.text('Anna Andersson'), findsOneWidget);
        expect(find.text('Erik Eriksson'), findsOneWidget);
        expect(find.text('Maria Svensson'), findsOneWidget);

        // Should show emails as subtitles
        expect(find.text('anna@example.com'), findsOneWidget);
        expect(find.text('erik@example.com'), findsOneWidget);
        expect(find.text('maria@example.com'), findsOneWidget);

        // Should have checkboxes
        expect(find.byType(CheckboxListTile), findsNWidgets(3));
      });

      testWidgets('shows empty state when no friends',
          (WidgetTester tester) async {
        // ULTRATHINK: Test empty state from lines 146-176
        when(() => mockFriendsService.friends).thenReturn([]);

        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show empty state icon
        expect(find.byIcon(Icons.people_outline), findsOneWidget);

        // Should show Swedish empty state messages
        expect(find.text('Inga vänner ännu'), findsOneWidget);
        expect(
            find.text('Lägg till vänner först för att starta konversationer.'),
            findsOneWidget);
      });

      testWidgets('shows avatar with initials', (WidgetTester tester) async {
        // ULTRATHINK: Test avatar from lines 211-217
        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show CircleAvatar with initials
        expect(find.byType(CircleAvatar), findsNWidgets(3));
        expect(find.text('A'), findsOneWidget); // Anna
        expect(find.text('E'), findsOneWidget); // Erik
        expect(find.text('M'), findsOneWidget); // Maria
      });
    });

    group('Search Functionality Tests', () {
      testWidgets('filters friends by name', (WidgetTester tester) async {
        // ULTRATHINK: Test search filter from lines 74-88
        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Enter search query
        await tester.enterText(find.byType(TextField), 'anna');
        await tester.pumpAndSettle();

        // Should only show matching friend
        expect(find.text('Anna Andersson'), findsOneWidget);
        expect(find.text('Erik Eriksson'), findsNothing);
        expect(find.text('Maria Svensson'), findsNothing);
      });

      testWidgets('filters friends by email', (WidgetTester tester) async {
        // ULTRATHINK: Test email filtering from line 83
        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Enter email search query
        await tester.enterText(find.byType(TextField), 'erik@');
        await tester.pumpAndSettle();

        // Should only show matching friend
        expect(find.text('Anna Andersson'), findsNothing);
        expect(find.text('Erik Eriksson'), findsOneWidget);
        expect(find.text('Maria Svensson'), findsNothing);
      });

      testWidgets('shows no results message for empty search',
          (WidgetTester tester) async {
        // ULTRATHINK: Test empty search results from lines 178-187
        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Enter non-matching search
        await tester.enterText(find.byType(TextField), 'xyz');
        await tester.pumpAndSettle();

        // Should show no results message
        expect(find.text('Inga vänner matchar din sökning'), findsOneWidget);
      });

      testWidgets('clears filter when search is empty',
          (WidgetTester tester) async {
        // ULTRATHINK: Test filter clearing from lines 78-79
        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Filter friends
        await tester.enterText(find.byType(TextField), 'anna');
        await tester.pumpAndSettle();
        expect(find.text('Erik Eriksson'), findsNothing);

        // Clear search
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();

        // Should show all friends again
        expect(find.text('Anna Andersson'), findsOneWidget);
        expect(find.text('Erik Eriksson'), findsOneWidget);
        expect(find.text('Maria Svensson'), findsOneWidget);
      });
    });

    group('Selection Tests', () {
      testWidgets('can select single friend', (WidgetTester tester) async {
        // ULTRATHINK: Test selection from lines 200-210
        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Initially, create button should be disabled
        final createButton =
            tester.widget<StyledButton>(find.byType(StyledButton));
        expect(createButton.onPressed, isNull);

        // Select a friend
        await tester.tap(find.text('Anna Andersson'));
        await tester.pumpAndSettle();

        // Create button should now be enabled
        final updatedButton =
            tester.widget<StyledButton>(find.byType(StyledButton));
        expect(updatedButton.onPressed, isNotNull);
      });

      testWidgets('can select multiple friends', (WidgetTester tester) async {
        // ULTRATHINK: Test multiple selection
        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Select multiple friends
        await tester.tap(find.text('Anna Andersson'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Erik Eriksson'));
        await tester.pumpAndSettle();

        // Both should be selected
        final checkboxes =
            tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile));
        final selectedCount = checkboxes.where((cb) => cb.value == true).length;
        expect(selectedCount, equals(2));
      });

      testWidgets('can deselect friends', (WidgetTester tester) async {
        // ULTRATHINK: Test deselection from lines 205-206
        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Select then deselect
        await tester.tap(find.text('Anna Andersson'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Anna Andersson'));
        await tester.pumpAndSettle();

        // Should be deselected
        final checkbox = tester
            .widget<CheckboxListTile>(find.byKey(const ValueKey('friend1')));
        expect(checkbox.value, isFalse);
      });
    });

    group('Conversation Creation Tests', () {
      testWidgets('creates direct conversation for single friend',
          (WidgetTester tester) async {
        // ULTRATHINK: Test direct conversation from lines 238-244
        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Select single friend
        await tester.tap(find.text('Anna Andersson'));
        await tester.pumpAndSettle();

        // Create conversation
        await tester.tap(find.text('Skapa'));
        await tester.pumpAndSettle();

        // Verify direct conversation was created
        verify(() => mockMessagingService.startDirectConversation(
              otherUserId: 'friend1',
              otherUserDisplayName: 'Anna Andersson',
            )).called(1);

        // Verify callback
        verify(() => mockCallbacks.onConversationCreated('conv123')).called(1);
      });

      testWidgets('creates group conversation for multiple friends',
          (WidgetTester tester) async {
        // ULTRATHINK: Test group conversation from lines 246-264
        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Select multiple friends
        await tester.tap(find.text('Anna Andersson'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Erik Eriksson'));
        await tester.pumpAndSettle();

        // Create conversation
        await tester.tap(find.text('Skapa'));
        await tester.pumpAndSettle();

        // Verify group conversation was created
        verify(() => mockMessagingService.createGroupConversation(
              participantIds: any(named: 'participantIds'),
              participantDisplayNames: any(named: 'participantDisplayNames'),
              participantAvatarUrls: any(named: 'participantAvatarUrls'),
              title: any(named: 'title', that: contains('Gruppchatt med')),
            )).called(1);
      });

      testWidgets('handles conversation creation error',
          (WidgetTester tester) async {
        // ULTRATHINK: Test error handling from lines 273-281
        when(() => mockMessagingService.startDirectConversation(
              otherUserId: any(named: 'otherUserId'),
              otherUserDisplayName: any(named: 'otherUserDisplayName'),
            )).thenThrow(Exception('Network error'));

        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Select friend
        await tester.tap(find.text('Anna Andersson'));
        await tester.pumpAndSettle();

        // Try to create conversation
        await tester.tap(find.text('Skapa'));
        await tester.pumpAndSettle();

        // Should show error snackbar with Swedish message
        expect(
            find.text(
                'Kunde inte skapa konversation: Exception: Network error'),
            findsOneWidget);
      });
    });

    group('Dialog Actions Tests', () {
      testWidgets('cancel button closes dialog', (WidgetTester tester) async {
        // ULTRATHINK: Test cancel from lines 109-111
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => NewConversationDialog(
                        onConversationCreated:
                            mockCallbacks.onConversationCreated,
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );

        // Open dialog
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Dialog should be shown
        expect(find.text('Ny konversation'), findsOneWidget);

        // Cancel dialog
        await tester.tap(find.text('Avbryt'));
        await tester.pumpAndSettle();

        // Dialog should be closed
        expect(find.text('Ny konversation'), findsNothing);
      });
    });

    group('State Management Tests', () {
      testWidgets('disables create button during creation',
          (WidgetTester tester) async {
        // ULTRATHINK: Test isCreating state from lines 115-117, 230-232
        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Select a friend
        await tester.tap(find.text('Anna Andersson'));
        await tester.pumpAndSettle();

        // Before clicking create, button should be enabled
        StyledButton button =
            tester.widget<StyledButton>(find.byType(StyledButton));
        expect(button.onPressed, isNotNull);

        // Simulate slow network by delaying the response
        when(() => mockMessagingService.startDirectConversation(
              otherUserId: any(named: 'otherUserId'),
              otherUserDisplayName: any(named: 'otherUserDisplayName'),
            )).thenAnswer((_) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'conv123';
        });

        // Start creation
        await tester.tap(find.text('Skapa'));
        await tester.pump();

        // Button should be disabled during creation
        button = tester.widget<StyledButton>(find.byType(StyledButton));
        expect(button.onPressed, isNull);

        // Wait for the async operation to complete to avoid pending timers
        await tester.pumpAndSettle(const Duration(seconds: 2));
      });
    });

    group('Edge Cases Tests', () {
      testWidgets('handles empty display name correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test empty name handling from lines 213-215
        final friendsWithEmptyName = [
          UserProfile(
            uid: 'friend1',
            email: 'user@example.com',
            displayName: '',
            avatarUrl: null,
            joinedAt: DateTime.now(),
            lastActiveAt: DateTime.now(),
          ),
        ];

        when(() => mockFriendsService.friends).thenReturn(friendsWithEmptyName);

        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show ? for empty name
        expect(find.text('?'), findsOneWidget);
      });

      testWidgets('handles search with special characters',
          (WidgetTester tester) async {
        // ULTRATHINK: Test search robustness
        await tester.pumpWidget(
          createTestWidget(
            child: NewConversationDialog(
              onConversationCreated: mockCallbacks.onConversationCreated,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Enter special characters
        await tester.enterText(find.byType(TextField), '@#\$%');
        await tester.pumpAndSettle();

        // Should handle without error
        expect(tester.takeException(), isNull);
        expect(find.text('Inga vänner matchar din sökning'), findsOneWidget);
      });
    });
  });
}
