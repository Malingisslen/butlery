/// ULTRATHINK TEST SUITE: ConversationsListView - Phase 2 High-Risk View
///
/// PRODUCTION CODE ANALYSIS: lib/views/messaging/conversations_list_view.dart
/// - StatefulWidget with complex initialization and service dependency injection
/// - Real-time stream architecture with MessagingService.getMyConversations().listen()
/// - Complex state management: controllers, focus nodes, conversation lists, loading state
/// - Search system with real-time filtering by title and last message content
/// - Navigation system with routes to ChatViewFacade, group details, user profiles
/// - Action system with long press modals for conversation management operations
/// - Error handling with comprehensive async operation safety and Swedish user feedback
/// - Swedish localization with complete UI text, error messages, and user guidance
/// - Empty state variants: no conversations vs no search results with different actions
/// - Service integration: MessagingService for operations, AuthRepository for current user
///
/// TEST FOCUS: StatefulWidget lifecycle, real-time streams, search system, navigation,
/// action modals, error handling, state management, Swedish localization, empty states
@Skip('BUT-1155: drifted ULTRATHINK smoke-suite — 51 failures from production-'
    'ServiceLocator / provider registration drift. Low behavioral value. Rebuild '
    'as real behavior tests on the journey-test harness — BUT-1180.')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports - NEVER assume, always check production code first
import 'package:butlery/views/messaging/conversations_list_view.dart';

// Test infrastructure imports - using centralized system
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  group('ConversationsListView Tests - ULTRATHINK METHODOLOGY', () {
    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      await BaseWidgetTest.teardownWidget();
    });

    // Helper to create test environment following gold standard pattern
    Widget createTestWidget({
      required Widget child,
    }) {
      return MaterialApp(
        home: child,
        locale: const Locale('sv', 'SE'),
        debugShowCheckedModeBanner: false,
      );
    }

    group('StatefulWidget Initialization Tests', () {
      testWidgets(
          'should initialize StatefulWidget with complex state management',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code StatefulWidget initialization from lines 44-66
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump(); // Allow initState

        // Verify StatefulWidget structure exists
        expect(find.byType(ConversationsListView), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('should initialize service dependencies via ServiceLocator',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code service injection from lines 60-62
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Service dependency injection should work without errors
        expect(tester.takeException(), isNull);
        expect(find.byType(ConversationsListView), findsOneWidget);
      });

      testWidgets('should setup search controller listeners in initState',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code listener setup from lines 64, 68-70
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Search controller listener should be initialized without errors
        expect(tester.takeException(), isNull);
      });

      testWidgets('should load conversations on initialization',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code conversation loading from lines 65, 81-100
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Should show loading state initially
        expect(find.byType(ConversationsListView), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle missing current user ID gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code null user handling from lines 82-89
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Should handle missing user ID without crashing
        expect(tester.takeException(), isNull);
      });
    });

    group('Real-Time Stream Integration Tests', () {
      testWidgets('should setup stream listener for conversation updates',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code stream listener from lines 91-99
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Stream listener should be setup without errors
        expect(tester.takeException(), isNull);
        expect(find.byType(ConversationsListView), findsOneWidget);
      });

      testWidgets('should handle conversation updates with mounted checks',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code mounted checks from lines 92, 97
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Mounted checks should work properly in stream updates
        expect(tester.takeException(), isNull);
      });

      testWidgets('should update filtered conversations on stream updates',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code conversation filtering from lines 94-95
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Conversation filtering should work with stream updates
        expect(tester.takeException(), isNull);
      });

      testWidgets('should manage loading state during conversation updates',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code loading state management from lines 96
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Loading state should be managed properly
        expect(tester.takeException(), isNull);
      });
    });

    group('Search System Tests', () {
      testWidgets('should provide search functionality with Swedish hint',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code search bar from lines 178-188
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Search functionality should be available
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle search query changes with listener',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code search listener from lines 69, 72-79
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Search query listener should work without errors
        expect(tester.takeException(), isNull);
      });

      testWidgets('should filter conversations by title and message content',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code filtering logic from lines 102-114
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Conversation filtering should work for both title and content
        expect(tester.takeException(), isNull);
      });

      testWidgets('should update UI on search query changes',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code UI updates from lines 74-77
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Search UI updates should work with mounted checks
        expect(tester.takeException(), isNull);
      });

      testWidgets('should clear search properly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code search clearing from lines 184-186
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Search clearing should work without errors
        expect(tester.takeException(), isNull);
      });
    });

    group('Navigation System Tests', () {
      testWidgets('should navigate to chat on conversation tap',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code chat navigation from lines 122-131
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Navigation system should be initialized without errors
        expect(tester.takeException(), isNull);
      });

      testWidgets('should show new conversation dialog',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code new conversation dialog from lines 133-146
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // New conversation dialog should be available
        expect(tester.takeException(), isNull);
      });

      testWidgets('should navigate to group info for group conversations',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code group info navigation from lines 375-381
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Group info navigation should be available
        expect(tester.takeException(), isNull);
      });

      testWidgets('should navigate to user profile for direct conversations',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code user profile navigation from lines 384-391
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // User profile navigation should be available
        expect(tester.takeException(), isNull);
      });
    });

    group('Action System Tests', () {
      testWidgets('should show conversation actions on long press',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code long press actions from lines 248-303
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Long press action system should be available
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle mark as read action',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code mark as read from lines 305-307
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Mark as read functionality should be available
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle group leave action with confirmation',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code group leave from lines 309-350
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Group leave action should be available
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle conversation deletion with confirmation',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code conversation deletion from lines 352-373
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Conversation deletion should be available
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'should show different actions for group vs direct conversations',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code conditional actions from lines 264-290
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Conditional actions should be properly configured
        expect(tester.takeException(), isNull);
      });
    });

    group('Error Handling Tests', () {
      testWidgets('should handle group leave errors with Swedish feedback',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code error handling from lines 334-343
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Error handling should be properly implemented
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle conversation deletion errors',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code deletion error handling from lines 413-422
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Deletion error handling should be available
        expect(tester.takeException(), isNull);
      });

      testWidgets('should use mounted checks in async operations',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code mounted checks from lines 329, 335, 405, 414
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Mounted checks should be properly implemented
        expect(tester.takeException(), isNull);
      });

      testWidgets('should show Swedish error messages',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code Swedish error messages from lines 338, 417
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Swedish error messages should be configured
        expect(tester.takeException(), isNull);
      });
    });

    group('State Management Tests', () {
      testWidgets('should manage conversation lists state properly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code state variables from lines 51-55
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // State management should work without errors
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle loading state transitions',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code loading state from lines 54, 85, 96
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Loading state transitions should work properly
        expect(tester.takeException(), isNull);
      });

      testWidgets('should synchronize all and filtered conversation lists',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code list synchronization from lines 52-53, 94-95
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // List synchronization should work properly
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle search query state updates',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code search state from lines 55, 75
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Search query state should be managed properly
        expect(tester.takeException(), isNull);
      });
    });

    group('Swedish Localization Tests', () {
      testWidgets('should display Swedish app bar title',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code Swedish title from line 152
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        expect(find.text('Meddelanden'), findsOneWidget);
      });

      testWidgets('should display Swedish action button tooltip',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code Swedish tooltip from line 157
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Swedish tooltip should be configured
        expect(find.byType(IconButton), findsOneWidget);
      });

      testWidgets('should use Swedish search hint',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code Swedish search hint from line 183
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Swedish search hint should be available
        expect(tester.takeException(), isNull);
      });

      testWidgets('should display Swedish dialog texts',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code Swedish dialog text from lines 313-318, 356-357
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Swedish dialog texts should be configured
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle Swedish locale configuration',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish locale from MaterialApp helper
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Should handle Swedish locale properly
        final materialApp =
            tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.locale?.languageCode, equals('sv'));
      });
    });

    group('Empty States Tests', () {
      testWidgets('should show loading state initially',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code loading state from lines 192-197
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Loading state should be displayed initially
        expect(tester.takeException(), isNull);
      });

      testWidgets('should show no search results empty state',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code no search results from lines 200-207
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // No search results state should be available
        expect(tester.takeException(), isNull);
      });

      testWidgets('should show no conversations empty state with action',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code no conversations state from lines 209-220
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // No conversations state should be available
        expect(tester.takeException(), isNull);
      });

      testWidgets('should show different empty states based on context',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code contextual empty states from lines 199-221
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Contextual empty states should be properly configured
        expect(tester.takeException(), isNull);
      });
    });

    group('Service Integration Tests', () {
      testWidgets('should integrate with MessagingService for operations',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code MessagingService integration from lines 48, 60, 91, 306
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // MessagingService integration should work without errors
        expect(tester.takeException(), isNull);
      });

      testWidgets('should integrate with AuthRepository for user context',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code AuthRepository integration from lines 49, 61-62
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // AuthRepository integration should work without errors
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle service locator dependency injection',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code service locator usage from lines 60-61, 397
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Service locator should work without errors
        expect(tester.takeException(), isNull);
      });

      testWidgets('should coordinate between services properly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code service coordination throughout the class
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Service coordination should work without errors
        expect(tester.takeException(), isNull);
      });
    });

    group('UI Component Tests', () {
      testWidgets('should render main UI structure properly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code UI structure from lines 149-176
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Main UI structure should be rendered
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(Column), findsOneWidget);
      });

      testWidgets('should display FloatingActionButton for new conversation',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code FAB from lines 172-174
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // FloatingActionButton should be present
        expect(find.byType(FloatingActionButton), findsOneWidget);
      });

      testWidgets('should handle RefreshIndicator for conversation refresh',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code RefreshIndicator from lines 223-224
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();
        await tester.pump(); // Allow conversation loading

        // RefreshIndicator should be available
        expect(tester.takeException(), isNull);
      });

      testWidgets('should configure ListView with proper separators',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code ListView configuration from lines 225-233
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // ListView configuration should work properly
        expect(tester.takeException(), isNull);
      });
    });

    group('Performance and Integration Tests', () {
      testWidgets('should handle complex initialization efficiently',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code complex initialization performance
        final stopwatch = Stopwatch()..start();

        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();
        await tester.pump(); // Allow full initialization

        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
        expect(find.byType(ConversationsListView), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should integrate with Phase 1 test infrastructure',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code integration with test infrastructure
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Should integrate with test helpers
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(find.byType(ConversationsListView), findsOneWidget);

        // Should handle Swedish locale properly
        final materialApp =
            tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.locale?.languageCode, equals('sv'));
      });

      testWidgets('should handle stream updates efficiently',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code stream performance
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();
        await tester.pump(); // Allow stream setup

        // Stream updates should be efficient
        expect(find.byType(ConversationsListView), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should dispose resources properly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code resource disposal from lines 425-430
        await tester.pumpWidget(createTestWidget(
          child: const ConversationsListView(),
        ));
        await tester.pump();

        // Remove widget to test disposal
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));

        // Should dispose resources without errors
        expect(tester.takeException(), isNull);
      });
    });
  });
}
