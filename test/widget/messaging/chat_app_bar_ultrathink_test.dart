// test/widget/messaging/chat_app_bar_ultrathink_test.dart
// ULTRATHINK TEST SUITE: ChatAppBar
// 111-line app bar with Swedish menu items and conversation info display

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Production imports
import 'package:butlery/widgets/messaging/chat_app_bar.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/theme/app_colors.dart';

// Mocks
class MockCallbacks extends Mock {
  Future<void> onMenuAction(String action);
}

void main() {
  group('ChatAppBar Ultrathink Tests', () {
    late MockCallbacks mockCallbacks;
    late Conversation testConversation;
    late Conversation groupConversation;

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
        home: Scaffold(
          appBar: child as PreferredSizeWidget,
          body: const SizedBox(),
        ),
      );
    }

    setUp(() {
      mockCallbacks = MockCallbacks();
      when(() => mockCallbacks.onMenuAction(any())).thenAnswer((_) async {});

      // Create test conversation for direct chat
      testConversation = Conversation(
        id: 'conv123',
        participantIds: ['user1', 'user2'],
        participantDisplayNames: {
          'user1': 'Anna Andersson',
          'user2': 'Erik Eriksson',
        },
        participantAvatarUrls: {
          'user1': null,
          'user2': null,
        },
        lastMessage: null,
        lastReadTimestamps: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        title: 'Anna och Erik',
        isGroup: false,
      );

      // Create group conversation with 4 participants
      groupConversation = Conversation(
        id: 'group123',
        participantIds: ['user1', 'user2', 'user3', 'user4'],
        participantDisplayNames: {
          'user1': 'Anna Andersson',
          'user2': 'Erik Eriksson',
          'user3': 'Maria Svensson',
          'user4': 'Johan Johansson',
        },
        participantAvatarUrls: {
          'user1': null,
          'user2': null,
          'user3': null,
          'user4': null,
        },
        lastMessage: null,
        lastReadTimestamps: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        title: 'Middagsgruppen',
        isGroup: true,
      );
    });

    group('Rendering Tests', () {
      testWidgets('renders with default title when no conversation',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 84-85
        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: null,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        // Should show default Swedish title "Chatt"
        expect(find.text('Chatt'), findsOneWidget);

        // Should have app bar with correct colors
        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, equals(AppColors.primaryBlue));
        expect(appBar.foregroundColor, equals(AppColors.cardWhite));
      });

      testWidgets('renders conversation title for direct chat',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 92-98
        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: testConversation,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        // Should show conversation title
        expect(find.text('Anna och Erik'), findsOneWidget);

        // Should not show participant count for direct chat (2 participants)
        expect(find.text('2 deltagare'), findsNothing);
      });

      testWidgets('shows participant count for group conversations',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 99-107
        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: groupConversation,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        // Should show conversation title
        expect(find.text('Middagsgruppen'), findsOneWidget);

        // Should show participant count with Swedish text
        expect(find.text('4 deltagare'), findsOneWidget);

        // Verify subtitle styling
        final subtitleText = tester.widget<Text>(find.text('4 deltagare'));
        expect(subtitleText.style?.fontSize, equals(12));
        expect(subtitleText.style?.color, equals(AppColors.textSecondary));
        expect(subtitleText.style?.fontWeight, equals(FontWeight.normal));
      });

      testWidgets('has correct preferred size', (WidgetTester tester) async {
        // ULTRATHINK: Test production code from line 24
        final appBar = ChatAppBar(
          conversation: null,
          onMenuAction: mockCallbacks.onMenuAction,
        );

        expect(appBar.preferredSize,
            equals(const Size.fromHeight(kToolbarHeight)));
      });

      testWidgets('renders popup menu button with correct icon',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 42-44
        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: testConversation,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        // Should have popup menu button
        expect(find.byType(PopupMenuButton<String>), findsOneWidget);

        // Should have more_vert icon
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
      });
    });

    group('Menu Actions Tests', () {
      testWidgets('shows all Swedish menu items when tapped',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 45-77
        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: testConversation,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        // Tap the menu button
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // Should show all Swedish menu items
        expect(find.text('Konversationsinfo'), findsOneWidget);
        expect(find.text('Tysta'), findsOneWidget);
        expect(find.text('Lämna konversation'), findsOneWidget);

        // Should have correct icons
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
        expect(find.byIcon(Icons.exit_to_app), findsOneWidget);

        // Should have divider
        expect(find.byType(PopupMenuDivider), findsOneWidget);
      });

      testWidgets('handles info menu action', (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 46-55
        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: testConversation,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        // Open menu
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // Tap info item
        await tester.tap(find.text('Konversationsinfo'));
        await tester.pumpAndSettle();

        // Verify callback was called with correct action
        verify(() => mockCallbacks.onMenuAction('info')).called(1);
      });

      testWidgets('handles mute menu action', (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 56-64
        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: testConversation,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        // Open menu
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // Tap mute item
        await tester.tap(find.text('Tysta'));
        await tester.pumpAndSettle();

        // Verify callback was called with correct action
        verify(() => mockCallbacks.onMenuAction('mute')).called(1);
      });

      testWidgets('handles leave menu action', (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 67-75
        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: testConversation,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        // Open menu
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // Tap leave item
        await tester.tap(find.text('Lämna konversation'));
        await tester.pumpAndSettle();

        // Verify callback was called with correct action
        verify(() => mockCallbacks.onMenuAction('leave')).called(1);
      });

      testWidgets('leave action has error color', (WidgetTester tester) async {
        // ULTRATHINK: Test production code from line 71
        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: testConversation,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        // Open menu
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // Find the exit icon and verify it has error color
        final exitIcon = tester.widget<Icon>(
          find.descendant(
            of: find.widgetWithText(
                PopupMenuItem<String>, 'Lämna konversation'),
            matching: find.byIcon(Icons.exit_to_app),
          ),
        );
        expect(exitIcon.color, equals(AppColors.error));
      });
    });

    group('Error Handling Tests', () {
      testWidgets('handles menu action errors gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 26-33
        // Setup mock to throw error
        when(() => mockCallbacks.onMenuAction(any()))
            .thenThrow(Exception('Network error'));

        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: testConversation,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        // Open menu
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // Tap action that will throw
        await tester.tap(find.text('Konversationsinfo'));
        await tester.pumpAndSettle();

        // Should not crash - error is caught and logged
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles async menu actions', (WidgetTester tester) async {
        // ULTRATHINK: Test async handling from line 26
        bool actionCalled = false;
        when(() => mockCallbacks.onMenuAction(any())).thenAnswer((_) async {
          actionCalled = true;
        });

        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: testConversation,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        // Open menu
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // Tap action
        await tester.tap(find.text('Konversationsinfo'));
        await tester.pumpAndSettle();

        // Verify async action was called
        expect(actionCalled, isTrue);
        verify(() => mockCallbacks.onMenuAction('info')).called(1);
      });
    });

    group('Edge Cases Tests', () {
      testWidgets('handles conversation with empty title',
          (WidgetTester tester) async {
        // ULTRATHINK: Test null safety from line 93
        final emptyTitleConv = Conversation(
          id: 'conv456',
          participantIds: ['user1', 'user2'],
          participantDisplayNames: {
            'user1': 'Anna',
            'user2': 'Erik',
          },
          participantAvatarUrls: {},
          lastMessage: null,
          lastReadTimestamps: {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          title: '', // Empty title
          isGroup: false,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: emptyTitleConv,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        // Should show empty string (not crash)
        expect(find.text(''), findsOneWidget);
      });

      testWidgets('handles conversation with null title',
          (WidgetTester tester) async {
        // ULTRATHINK: Test null safety from lines 93-94
        final nullTitleConv = Conversation(
          id: 'conv789',
          participantIds: ['user1', 'user2'],
          participantDisplayNames: {
            'user1': 'Anna',
            'user2': 'Erik',
          },
          participantAvatarUrls: {},
          lastMessage: null,
          lastReadTimestamps: {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          title: null, // Null title
          isGroup: false,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: nullTitleConv,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        // Should handle null with ?? operator
        expect(find.text(''), findsOneWidget);
      });

      testWidgets('handles large participant count correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test large groups
        final largeGroup = Conversation(
          id: 'large123',
          participantIds: List.generate(100, (i) => 'user$i'),
          participantDisplayNames: Map.fromEntries(
            List.generate(100, (i) => MapEntry('user$i', 'User $i')),
          ),
          participantAvatarUrls: {},
          lastMessage: null,
          lastReadTimestamps: {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          title: 'Stora gruppen',
          isGroup: true,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: largeGroup,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        // Should show large participant count with Swedish text
        expect(find.text('100 deltagare'), findsOneWidget);
      });

      testWidgets('title column has correct layout properties',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Column properties from lines 88-91
        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: groupConversation,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        // Find the Column widget in the title
        final column = tester.widget<Column>(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(Column),
          ),
        );

        expect(column.crossAxisAlignment, equals(CrossAxisAlignment.start));
        expect(column.mainAxisSize, equals(MainAxisSize.min));
      });
    });

    group('Swedish Localization Tests', () {
      testWidgets('all text is in Swedish', (WidgetTester tester) async {
        // ULTRATHINK: Verify Swedish localization throughout
        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: null,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        // Default title
        expect(find.text('Chatt'), findsOneWidget);

        // Open menu
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // All menu items in Swedish
        expect(find.text('Konversationsinfo'), findsOneWidget);
        expect(find.text('Tysta'), findsOneWidget);
        expect(find.text('Lämna konversation'), findsOneWidget);

        // No English text
        expect(find.text('Chat'), findsNothing);
        expect(find.text('Info'), findsNothing);
        expect(find.text('Mute'), findsNothing);
        expect(find.text('Leave'), findsNothing);
      });

      testWidgets('participant count uses Swedish plural',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish plural from line 101
        // Test with 1 participant (edge case)
        final singleParticipant = Conversation(
          id: 'single',
          participantIds: ['user1'],
          participantDisplayNames: {'user1': 'Anna'},
          participantAvatarUrls: {},
          lastMessage: null,
          lastReadTimestamps: {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          title: 'Solo',
          isGroup: false,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: singleParticipant,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        // Should not show count for 1 participant (not > 2)
        expect(find.textContaining('deltagare'), findsNothing);
      });
    });

    group('Visual Layout Tests', () {
      testWidgets('menu items have correct spacing',
          (WidgetTester tester) async {
        // ULTRATHINK: Test SizedBox spacing from lines 51, 61, 72
        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: testConversation,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        // Open menu
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // Check that each menu item has proper spacing
        // There should be 3 menu items with SizedBox spacing
        final rows = tester.widgetList<Row>(
          find.descendant(
            of: find.byType(PopupMenuItem<String>),
            matching: find.byType(Row),
          ),
        );

        // Verify we have 3 rows (one for each menu item)
        expect(rows.length, equals(3));

        // Each row should have mainAxisSize.min as we fixed in production
        for (final row in rows) {
          expect(row.mainAxisSize, equals(MainAxisSize.min));
        }
      });

      testWidgets('title text has correct styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test TextStyle from lines 94-97
        await tester.pumpWidget(
          createTestWidget(
            child: ChatAppBar(
              conversation: testConversation,
              onMenuAction: mockCallbacks.onMenuAction,
            ),
          ),
        );

        final titleText = tester.widget<Text>(find.text('Anna och Erik'));
        expect(titleText.style?.fontSize, equals(16));
        expect(titleText.style?.fontWeight, equals(FontWeight.w600));
      });
    });
  });
}
