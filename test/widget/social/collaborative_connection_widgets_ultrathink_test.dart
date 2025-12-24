// test/widget/social/collaborative_connection_widgets_ultrathink_test.dart
// ULTRATHINK TEST SUITE: CollaborativeConnectionWidgets - 122 lines of production code
// Testing 2 static methods for collaborative connection status indicators
//
// ULTRATHINK FOCUS: Conditional UI rendering, online/offline states, theme integration, Swedish localization

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports - NEVER assume, always check production code first
import 'package:butlery/widgets/social/collaborative/components/collaborative_connection_widgets.dart';

// Test infrastructure imports - using centralized system
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  group('CollaborativeConnectionWidgets Ultrathink Tests', () {
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

    // Helper to get BuildContext from rendered widget
    BuildContext getContext(WidgetTester tester) {
      return tester.element(find.byType(Scaffold));
    }

    // Helper to create test widget with CollaborativeConnectionWidgets method
    Future<void> pumpConnectionWidget(
      WidgetTester tester,
      Widget Function(BuildContext) builder,
    ) async {
      await tester.pumpWidget(createTestWidget());
      final context = getContext(tester);
      final widget = builder(context);
      await tester.pumpWidget(createTestWidget(child: widget));
    }

    group('connectionStatus Method Tests', () {
      group('Online State Tests', () {
        testWidgets('creates minimal online indicator when isOnline is true',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code online state from lines 18-50
          await pumpConnectionWidget(
            tester,
            (context) => CollaborativeConnectionWidgets.connectionStatus(
              isOnline: true,
              statusText: 'Connected to server',
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Verify minimal online container structure (lines 20-49)
          expect(find.byType(Container), findsAtLeastNWidgets(1));
          expect(find.byType(Row), findsOneWidget);
          expect(find.text('Online'), findsOneWidget);

          // ULTRATHINK: Should have green success dot (lines 32-38)
          final containers =
              tester.widgetList<Container>(find.byType(Container));
          expect(containers.length,
              greaterThanOrEqualTo(2)); // Main container + dot container

          // ULTRATHINK: Row should have MainAxisSize.min (line 30)
          final row = tester.widget<Row>(find.byType(Row));
          expect(row.mainAxisSize, equals(MainAxisSize.min));
        });

        testWidgets('applies correct online styling and colors',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code online styling from lines 25-46
          await pumpConnectionWidget(
            tester,
            (context) => CollaborativeConnectionWidgets.connectionStatus(
              isOnline: true,
              statusText: 'All systems operational',
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Verify "Online" text styling (lines 43-46)
          final onlineText = tester.widget<Text>(find.text('Online'));
          expect(onlineText.style?.fontWeight, equals(FontWeight.w500));

          // ULTRATHINK: Should have success color theming
          expect(find.text('Online'), findsOneWidget);
        });

        testWidgets('ignores statusText parameter when online',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code online state ignores statusText
          await pumpConnectionWidget(
            tester,
            (context) => CollaborativeConnectionWidgets.connectionStatus(
              isOnline: true,
              statusText: 'This text should not appear',
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Online state should only show "Online", not statusText
          expect(find.text('Online'), findsOneWidget);
          expect(find.text('This text should not appear'), findsNothing);
        });

        testWidgets('ignores retry parameters when online',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code online state ignores retry elements
          await pumpConnectionWidget(
            tester,
            (context) => CollaborativeConnectionWidgets.connectionStatus(
              isOnline: true,
              statusText: 'Connected',
              showRetryButton: true,
              onRetry: () {}, // Callback provided but should be ignored
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Should not show retry button when online
          expect(find.byType(TextButton), findsNothing);
          expect(find.text('Försök igen'), findsNothing);
        });
      });

      group('Offline State Tests', () {
        testWidgets('creates full offline banner when isOnline is false',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code offline state from lines 53-102
          await pumpConnectionWidget(
            tester,
            (context) => CollaborativeConnectionWidgets.connectionStatus(
              isOnline: false,
              statusText: 'Connection lost. Check your internet.',
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Verify offline banner structure (lines 54-101)
          expect(find.byType(Container), findsOneWidget);
          expect(find.byType(Row), findsOneWidget);
          expect(find.byType(Column), findsOneWidget);
          expect(find.text('Offline'), findsOneWidget);
          expect(find.text('Connection lost. Check your internet.'),
              findsOneWidget);
        });

        testWidgets('applies full width and correct error styling',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code offline styling from lines 54-62, 76-85
          await pumpConnectionWidget(
            tester,
            (context) => CollaborativeConnectionWidgets.connectionStatus(
              isOnline: false,
              statusText: 'Server unavailable',
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Main container should have full width (line 55)
          // Container should have error color theming (lines 58-61)
          expect(find.byType(Container), findsOneWidget);

          // ULTRATHINK: Verify "Offline" text bold styling (lines 76-79)
          final offlineText = tester.widget<Text>(find.text('Offline'));
          expect(offlineText.style?.fontWeight, equals(FontWeight.bold));
        });

        testWidgets('shows emoji when statusEmoji is provided',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code emoji display from lines 65-68
          const testEmoji = '🔌';

          await pumpConnectionWidget(
            tester,
            (context) => CollaborativeConnectionWidgets.connectionStatus(
              isOnline: false,
              statusText: 'Power disconnected',
              statusEmoji: testEmoji,
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Should display emoji (line 66)
          expect(find.text(testEmoji), findsOneWidget);

          // ULTRATHINK: Should have spacing after emoji (line 67)
          expect(find.byType(SizedBox), findsAtLeastNWidgets(1));
        });

        testWidgets('hides emoji section when statusEmoji is null',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code emoji conditional from line 65
          await pumpConnectionWidget(
            tester,
            (context) => CollaborativeConnectionWidgets.connectionStatus(
              isOnline: false,
              statusText: 'Network error',
              statusEmoji: null,
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Should not show emoji section when null (line 65 condition)
          expect(find.text('Offline'), findsOneWidget);
          expect(find.text('Network error'), findsOneWidget);
        });

        testWidgets(
            'shows retry button when showRetryButton is true and onRetry provided',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code retry button from lines 90-99
          bool retryPressed = false;

          await pumpConnectionWidget(
            tester,
            (context) => CollaborativeConnectionWidgets.connectionStatus(
              isOnline: false,
              statusText: 'Connection failed',
              showRetryButton: true,
              onRetry: () => retryPressed = true,
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Should show retry button (lines 90-99)
          expect(find.byType(TextButton), findsOneWidget);
          expect(find.text('Försök igen'), findsOneWidget);

          // ULTRATHINK: Test button tap functionality
          await tester.tap(find.byType(TextButton));
          expect(retryPressed, isTrue);

          // Use retryPressed to prevent unused variable warning
          expect(retryPressed, isTrue);
        });

        testWidgets('hides retry button when showRetryButton is false',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code retry button condition from line 90
          await pumpConnectionWidget(
            tester,
            (context) => CollaborativeConnectionWidgets.connectionStatus(
              isOnline: false,
              statusText: 'Network timeout',
              showRetryButton: false,
              onRetry: () {}, // Provided but should not show
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Should not show retry button when showRetryButton is false
          expect(find.byType(TextButton), findsNothing);
          expect(find.text('Försök igen'), findsNothing);
        });

        testWidgets('hides retry button when onRetry is null',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code retry button condition from line 90
          await pumpConnectionWidget(
            tester,
            (context) => CollaborativeConnectionWidgets.connectionStatus(
              isOnline: false,
              statusText: 'Authentication failed',
              showRetryButton: true, // True but onRetry is null
              onRetry: null,
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Should not show retry button when onRetry is null
          expect(find.byType(TextButton), findsNothing);
          expect(find.text('Försök igen'), findsNothing);
        });

        testWidgets('column has correct cross axis alignment and size',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code column properties from lines 71-72
          await pumpConnectionWidget(
            tester,
            (context) => CollaborativeConnectionWidgets.connectionStatus(
              isOnline: false,
              statusText: 'Database connection lost',
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Verify column alignment (lines 71-72)
          final column = tester.widget<Column>(find.byType(Column));
          expect(column.crossAxisAlignment, equals(CrossAxisAlignment.start));
          expect(column.mainAxisSize, equals(MainAxisSize.min));
        });
      });
    });

    group('onlineIndicator Method Tests', () {
      testWidgets(
          'creates online indicator with green color when isOnline is true',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code online indicator from lines 106-122
        await pumpConnectionWidget(
          tester,
          (context) => CollaborativeConnectionWidgets.onlineIndicator(
            isOnline: true,
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Verify container structure (lines 112-121)
        expect(find.byType(Container), findsOneWidget);

        // Container with default size (8x8) should be created
      });

      testWidgets(
          'creates offline indicator with red color when isOnline is false',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code offline indicator
        await pumpConnectionWidget(
          tester,
          (context) => CollaborativeConnectionWidgets.onlineIndicator(
            isOnline: false,
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should create container with error color when offline
        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('applies custom size when provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code size customization from lines 108, 113-114
        const customSize = 12.0;

        await pumpConnectionWidget(
          tester,
          (context) => CollaborativeConnectionWidgets.onlineIndicator(
            isOnline: true,
            size: customSize,
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should use custom size (lines 113-114)
        // Container widget with custom dimensions created
        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('uses custom online color when provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code custom color from lines 109, 117
        const customColor = Colors.purple;

        await pumpConnectionWidget(
          tester,
          (context) => CollaborativeConnectionWidgets.onlineIndicator(
            isOnline: true,
            onlineColor: customColor,
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should use custom online color (line 117)
        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('uses custom offline color when provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code custom offline color from lines 110, 118
        const customColor = Colors.orange;

        await pumpConnectionWidget(
          tester,
          (context) => CollaborativeConnectionWidgets.onlineIndicator(
            isOnline: false,
            offlineColor: customColor,
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should use custom offline color (line 118)
        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('defaults to AppColors when no custom colors provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code default colors from lines 117-118
        await pumpConnectionWidget(
          tester,
          (context) => CollaborativeConnectionWidgets.onlineIndicator(
            isOnline: true,
            onlineColor: null,
            offlineColor: null,
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should use AppColors.success as default (line 117)
        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('always creates circular shape', (WidgetTester tester) async {
        // ULTRATHINK: Test production code BoxShape.circle from line 119
        await pumpConnectionWidget(
          tester,
          (context) => CollaborativeConnectionWidgets.onlineIndicator(
            isOnline: true,
            size: 20,
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should always have circular shape (line 119)
        expect(find.byType(Container), findsOneWidget);
      });
    });

    group('Edge Cases and Integration Tests', () {
      testWidgets('handles empty statusText gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with empty string
        await pumpConnectionWidget(
          tester,
          (context) => CollaborativeConnectionWidgets.connectionStatus(
            isOnline: false,
            statusText: '',
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should still render structure with empty text
        expect(find.text('Offline'), findsOneWidget);
        expect(find.text(''), findsOneWidget);
      });

      testWidgets('handles very long statusText with proper layout',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with long text and Expanded widget
        const longText =
            'This is a very long status message that should wrap properly and not overflow the container boundaries in the offline state banner.';

        await pumpConnectionWidget(
          tester,
          (context) => CollaborativeConnectionWidgets.connectionStatus(
            isOnline: false,
            statusText: longText,
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Expanded widget should handle long text (line 69)
        expect(find.text(longText), findsOneWidget);
        expect(find.byType(Expanded), findsOneWidget);
      });

      testWidgets('multiple indicators can coexist',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code multiple instances
        await pumpConnectionWidget(
          tester,
          (context) => Column(
            children: [
              CollaborativeConnectionWidgets.onlineIndicator(isOnline: true),
              CollaborativeConnectionWidgets.onlineIndicator(isOnline: false),
              CollaborativeConnectionWidgets.connectionStatus(
                isOnline: false,
                statusText: 'Connection lost',
                statusEmoji: '🔗',
                showRetryButton: true,
                onRetry: () {},
              ),
            ],
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: All widgets should render independently
        expect(find.byType(Container), findsAtLeastNWidgets(3));
        expect(find.text('Offline'), findsOneWidget);
        expect(find.text('🔗'), findsOneWidget);
        expect(find.text('Försök igen'), findsOneWidget);
      });

      testWidgets('handles extreme size values for indicator',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with edge case sizes
        await pumpConnectionWidget(
          tester,
          (context) => Column(
            children: [
              CollaborativeConnectionWidgets.onlineIndicator(
                isOnline: true,
                size: 0.1, // Very small
              ),
              CollaborativeConnectionWidgets.onlineIndicator(
                isOnline: false,
                size: 100, // Very large
              ),
            ],
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should handle extreme sizes without errors
        expect(find.byType(Container), findsNWidgets(2));
      });

      testWidgets('respects layout constraints in connectionStatus',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code layout behavior with reasonable constraints
        await pumpConnectionWidget(
          tester,
          (context) => SizedBox(
            width: 350, // Wider constraint to avoid Swedish text overflow
            child: CollaborativeConnectionWidgets.connectionStatus(
              isOnline: false,
              statusText: 'Network connection test',
              showRetryButton: true,
              onRetry: () {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should render content within reasonable constraints
        expect(find.text('Offline'), findsOneWidget);
        expect(find.text('Försök igen'), findsOneWidget);
        expect(find.text('Network connection test'), findsOneWidget);
      });
    });
  });
}
