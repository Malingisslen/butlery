// test/widget/messaging/message_status_icon_ultrathink_test.dart
// ULTRATHINK TEST SUITE: MessageStatusIcon
// 134-line message status widget with animated icons for all delivery states

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports
import 'package:butlery/widgets/messaging/message_status_icon.dart';
import 'package:butlery/models/messaging/message_type.dart';
import 'package:butlery/theme/app_colors.dart';

void main() {
  group('MessageStatusIcon Ultrathink Tests', () {
    // Helper to create properly configured test environment
    Widget createTestWidget({
      required Widget child,
      Size size = const Size(414, 896), // iPhone 11 Pro Max
    }) {
      return MaterialApp(
        theme: ThemeData(
          primaryColor: AppColors.primaryBlue,
          scaffoldBackgroundColor: Colors.white,
        ),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: Center(child: child),
          ),
        ),
      );
    }

    group('Rendering Tests', () {
      testWidgets('renders sending status with clock icon',
          (WidgetTester tester) async {
        // ULTRATHINK: Test sending status from lines 80-97
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.sending,
            ),
          ),
        );

        // Should show clock icon
        expect(find.byIcon(Icons.access_time), findsOneWidget);
        
        // Should have default size
        final sizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(MessageStatusIcon),
            matching: find.byType(SizedBox),
          ).first,
        );
        expect(sizedBox.width, equals(12));
        expect(sizedBox.height, equals(12));
      });

      testWidgets('renders sent status with single check',
          (WidgetTester tester) async {
        // ULTRATHINK: Test sent status from lines 99-104
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.sent,
            ),
          ),
        );

        // Should show single check icon
        expect(find.byIcon(Icons.check), findsOneWidget);
        
        // Should have medium color
        final icon = tester.widget<Icon>(find.byIcon(Icons.check));
        expect(icon.color, equals(AppColors.textMedium));
      });

      testWidgets('renders delivered status with double check',
          (WidgetTester tester) async {
        // ULTRATHINK: Test delivered status from lines 106-111
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.delivered,
            ),
          ),
        );

        // Should show double check icon
        expect(find.byIcon(Icons.done_all), findsOneWidget);
        
        // Should have medium color
        final icon = tester.widget<Icon>(find.byIcon(Icons.done_all));
        expect(icon.color, equals(AppColors.textMedium));
      });

      testWidgets('renders read status with colored double check',
          (WidgetTester tester) async {
        // ULTRATHINK: Test read status from lines 113-118
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.read,
            ),
          ),
        );

        // Should show double check icon
        expect(find.byIcon(Icons.done_all), findsOneWidget);
        
        // Should have primary blue color
        final icon = tester.widget<Icon>(find.byIcon(Icons.done_all));
        expect(icon.color, equals(AppColors.primaryBlue));
      });

      testWidgets('renders failed status with error icon',
          (WidgetTester tester) async {
        // ULTRATHINK: Test failed status from lines 120-125
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.failed,
            ),
          ),
        );

        // Should show error icon
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        
        // Should have error color
        final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
        expect(icon.color, equals(AppColors.error));
      });
    });

    group('Animation Tests', () {
      testWidgets('animates sending status when showAnimation is true',
          (WidgetTester tester) async {
        // ULTRATHINK: Test animation from lines 41-53, 81-92
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.sending,
              showAnimation: true,
            ),
          ),
        );

        // Should have AnimatedBuilder for rotation
        expect(find.descendant(
          of: find.byType(MessageStatusIcon),
          matching: find.byType(AnimatedBuilder),
        ), findsOneWidget);
        
        // Should have Transform.rotate
        expect(find.descendant(
          of: find.byType(MessageStatusIcon),
          matching: find.byType(Transform),
        ), findsOneWidget);
        
        // Animation should be running
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byIcon(Icons.access_time), findsOneWidget);
        
        // Pump again to verify continuous animation
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byIcon(Icons.access_time), findsOneWidget);
      });

      testWidgets('does not animate sending when showAnimation is false',
          (WidgetTester tester) async {
        // ULTRATHINK: Test no animation from lines 93-97
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.sending,
              showAnimation: false,
            ),
          ),
        );

        // Should not have AnimatedBuilder
        expect(find.descendant(
          of: find.byType(MessageStatusIcon),
          matching: find.byType(AnimatedBuilder),
        ), findsNothing);
        
        // Should have static icon
        expect(find.byIcon(Icons.access_time), findsOneWidget);
        
        // Should not have Transform
        expect(find.descendant(
          of: find.byType(MessageStatusIcon),
          matching: find.byType(Transform),
        ), findsNothing);
      });

      testWidgets('starts animation when status changes to sending',
          (WidgetTester tester) async {
        // ULTRATHINK: Test animation start from lines 60-63
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.sent,
              showAnimation: true,
            ),
          ),
        );

        // Initially no animation
        expect(find.descendant(
          of: find.byType(MessageStatusIcon),
          matching: find.byType(AnimatedBuilder),
        ), findsNothing);

        // Change to sending status
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.sending,
              showAnimation: true,
            ),
          ),
        );

        // Should now have animation
        expect(find.descendant(
          of: find.byType(MessageStatusIcon),
          matching: find.byType(AnimatedBuilder),
        ), findsOneWidget);
        
        // Animation should be running
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byIcon(Icons.access_time), findsOneWidget);
      });

      testWidgets('stops animation when status changes from sending',
          (WidgetTester tester) async {
        // ULTRATHINK: Test animation stop from lines 64-66
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.sending,
              showAnimation: true,
            ),
          ),
        );

        // Initially has animation
        expect(find.descendant(
          of: find.byType(MessageStatusIcon),
          matching: find.byType(AnimatedBuilder),
        ), findsOneWidget);

        // Change to sent status
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.sent,
              showAnimation: true,
            ),
          ),
        );

        // Should no longer have animation
        expect(find.descendant(
          of: find.byType(MessageStatusIcon),
          matching: find.byType(AnimatedBuilder),
        ), findsNothing);
        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets('handles rotation animation correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test rotation calculation from line 85
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.sending,
              showAnimation: true,
            ),
          ),
        );

        // Find the Transform widget
        final transform = tester.widget<Transform>(
          find.descendant(
            of: find.byType(MessageStatusIcon),
            matching: find.byType(Transform),
          ).first,
        );
        
        // Should have rotation transform
        expect(transform, isNotNull);
        
        // Pump to different animation points
        await tester.pump(const Duration(milliseconds: 250)); // 1/4 rotation
        await tester.pump(const Duration(milliseconds: 250)); // 1/2 rotation
        await tester.pump(const Duration(milliseconds: 250)); // 3/4 rotation
        await tester.pump(const Duration(milliseconds: 250)); // Full rotation
        
        // Should still be animating
        expect(find.descendant(
          of: find.byType(MessageStatusIcon),
          matching: find.byType(AnimatedBuilder),
        ), findsOneWidget);
      });
    });

    group('Customization Tests', () {
      testWidgets('respects custom color parameter',
          (WidgetTester tester) async {
        // ULTRATHINK: Test custom color from line 17, 89
        const customColor = Colors.green;
        
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.sent,
              color: customColor,
            ),
          ),
        );

        // Should use custom color
        final icon = tester.widget<Icon>(find.byIcon(Icons.check));
        expect(icon.color, equals(customColor));
      });

      testWidgets('respects custom size parameter',
          (WidgetTester tester) async {
        // ULTRATHINK: Test custom size from line 18
        const customSize = 24.0;
        
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.delivered,
              size: customSize,
            ),
          ),
        );

        // Should use custom size
        final sizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(MessageStatusIcon),
            matching: find.byType(SizedBox),
          ).first,
        );
        expect(sizedBox.width, equals(customSize));
        expect(sizedBox.height, equals(customSize));
        
        final icon = tester.widget<Icon>(find.byIcon(Icons.done_all));
        expect(icon.size, equals(customSize));
      });

      testWidgets('uses default values when not specified',
          (WidgetTester tester) async {
        // ULTRATHINK: Test defaults from lines 24-26
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.sent,
            ),
          ),
        );

        // Should use default size (12)
        final sizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(MessageStatusIcon),
            matching: find.byType(SizedBox),
          ).first,
        );
        expect(sizedBox.width, equals(12));
        
        // Should use default color (textMedium)
        final icon = tester.widget<Icon>(find.byIcon(Icons.check));
        expect(icon.color, equals(AppColors.textMedium));
      });
    });

    group('State Management Tests', () {
      testWidgets('properly handles widget updates',
          (WidgetTester tester) async {
        // ULTRATHINK: Test didUpdateWidget from lines 57-67
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.sending,
              showAnimation: true,
            ),
          ),
        );

        // Initially animating
        expect(find.descendant(
          of: find.byType(MessageStatusIcon),
          matching: find.byType(AnimatedBuilder),
        ), findsOneWidget);

        // Change to different status
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.sent,
              showAnimation: true,
            ),
          ),
        );

        // Should update icon
        expect(find.byIcon(Icons.check), findsOneWidget);
        expect(find.byIcon(Icons.access_time), findsNothing);

        // Change back to sending
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.sending,
              showAnimation: true,
            ),
          ),
        );

        // Should restart animation
        expect(find.descendant(
          of: find.byType(MessageStatusIcon),
          matching: find.byType(AnimatedBuilder),
        ), findsOneWidget);
      });

      testWidgets('transitions between all status types correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test all status transitions
        final statuses = [
          MessageStatus.sending,
          MessageStatus.sent,
          MessageStatus.delivered,
          MessageStatus.read,
          MessageStatus.failed,
        ];

        final expectedIcons = [
          Icons.access_time,
          Icons.check,
          Icons.done_all,
          Icons.done_all,
          Icons.error_outline,
        ];

        for (int i = 0; i < statuses.length; i++) {
          await tester.pumpWidget(
            createTestWidget(
              child: MessageStatusIcon(
                status: statuses[i],
                showAnimation: false, // Disable animation for simpler testing
              ),
            ),
          );

          // Verify correct icon is shown
          expect(find.byIcon(expectedIcons[i]), findsOneWidget,
              reason: 'Failed for status: ${statuses[i]}');
          
          // Clear previous icons
          for (int j = 0; j < expectedIcons.length; j++) {
            if (j != i && expectedIcons[j] != expectedIcons[i]) {
              expect(find.byIcon(expectedIcons[j]), findsNothing,
                  reason: 'Unexpected icon for status: ${statuses[i]}');
            }
          }
        }
      });
    });

    group('Lifecycle Tests', () {
      testWidgets('properly disposes animation controller',
          (WidgetTester tester) async {
        // ULTRATHINK: Test dispose from lines 130-133
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.sending,
              showAnimation: true,
            ),
          ),
        );

        // Animation should be running
        expect(find.descendant(
          of: find.byType(MessageStatusIcon),
          matching: find.byType(AnimatedBuilder),
        ), findsOneWidget);

        // Replace widget to trigger dispose
        await tester.pumpWidget(
          createTestWidget(
            child: const SizedBox(),
          ),
        );

        // Should dispose without errors
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles rapid status changes without leaking',
          (WidgetTester tester) async {
        // ULTRATHINK: Test rapid status changes
        final statuses = [
          MessageStatus.sending,
          MessageStatus.sent,
          MessageStatus.delivered,
          MessageStatus.read,
          MessageStatus.failed,
        ];

        // Rapidly change status
        for (int i = 0; i < 10; i++) {
          await tester.pumpWidget(
            createTestWidget(
              child: MessageStatusIcon(
                status: statuses[i % statuses.length],
                showAnimation: true,
              ),
            ),
          );
          
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Should not crash or leak
        expect(tester.takeException(), isNull);
      });
    });

    group('Visual Tests', () {
      testWidgets('maintains correct icon colors for each status',
          (WidgetTester tester) async {
        // ULTRATHINK: Test colors from lines 89, 96, 103, 110, 117, 124
        final testCases = [
          (MessageStatus.sending, AppColors.textMedium, Icons.access_time),
          (MessageStatus.sent, AppColors.textMedium, Icons.check),
          (MessageStatus.delivered, AppColors.textMedium, Icons.done_all),
          (MessageStatus.read, AppColors.primaryBlue, Icons.done_all),
          (MessageStatus.failed, AppColors.error, Icons.error_outline),
        ];

        for (final testCase in testCases) {
          await tester.pumpWidget(
            createTestWidget(
              child: MessageStatusIcon(
                status: testCase.$1,
                showAnimation: false,
              ),
            ),
          );

          final icon = tester.widget<Icon>(find.byIcon(testCase.$3));
          expect(icon.color, equals(testCase.$2),
              reason: 'Wrong color for status: ${testCase.$1}');
        }
      });

      testWidgets('icon sizes scale properly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test size scaling
        final sizes = [8.0, 12.0, 16.0, 24.0, 32.0];

        for (final size in sizes) {
          await tester.pumpWidget(
            createTestWidget(
              child: MessageStatusIcon(
                status: MessageStatus.delivered,
                size: size,
              ),
            ),
          );

          final sizedBox = tester.widget<SizedBox>(
            find.descendant(
              of: find.byType(MessageStatusIcon),
              matching: find.byType(SizedBox),
            ).first,
          );
          expect(sizedBox.width, equals(size));
          expect(sizedBox.height, equals(size));
          
          final icon = tester.widget<Icon>(find.byIcon(Icons.done_all));
          expect(icon.size, equals(size));
        }
      });
    });

    group('Edge Cases Tests', () {
      testWidgets('handles zero size gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Edge case for zero size
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.sent,
              size: 0,
            ),
          ),
        );

        // Should still render without errors
        expect(find.byType(MessageStatusIcon), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles very large size values',
          (WidgetTester tester) async {
        // ULTRATHINK: Edge case for large size
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.read,
              size: 100,
            ),
          ),
        );

        // Should render with large size
        final sizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(MessageStatusIcon),
            matching: find.byType(SizedBox),
          ).first,
        );
        expect(sizedBox.width, equals(100));
        expect(sizedBox.height, equals(100));
      });

      testWidgets('handles transparent color',
          (WidgetTester tester) async {
        // ULTRATHINK: Edge case for transparent color
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageStatusIcon(
              status: MessageStatus.delivered,
              color: Colors.transparent,
            ),
          ),
        );

        // Should use transparent color
        final icon = tester.widget<Icon>(find.byIcon(Icons.done_all));
        expect(icon.color, equals(Colors.transparent));
      });
    });
  });
}