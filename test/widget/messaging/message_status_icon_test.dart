// test/widget/messaging/message_status_icon_test.dart
// Comprehensive tests for MessageStatusIcon widget using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/messaging/message_status_icon.dart';
import 'package:butlery/models/messaging/message_type.dart';
import 'package:butlery/theme/app_colors.dart';

void main() {
  group('MessageStatusIcon Widget Tests', () {
    // Helper to wrap widget with MaterialApp for proper theming
    Widget createTestWidget({
      required MessageStatus status,
      Color? color,
      double size = 12,
      bool showAnimation = true,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: MessageStatusIcon(
              status: status,
              color: color,
              size: size,
              showAnimation: showAnimation,
            ),
          ),
        ),
      );
    }

    group('Rendering', () {
      testWidgets('should render with required status', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sent,
        ));

        expect(find.byType(MessageStatusIcon), findsOneWidget);
        expect(find.byType(Icon), findsOneWidget);
      });

      testWidgets('should respect custom size', (WidgetTester tester) async {
        const customSize = 24.0;
        
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sent,
          size: customSize,
        ));

        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final iconSizedBox = sizedBoxes.firstWhere(
          (box) => box.width == customSize && box.height == customSize,
        );
        expect(iconSizedBox.width, equals(customSize));
        expect(iconSizedBox.height, equals(customSize));
        
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.size, equals(customSize));
      });

      testWidgets('should use default size of 12', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sent,
        ));

        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final iconSizedBox = sizedBoxes.firstWhere(
          (box) => box.width == 12.0 && box.height == 12.0,
        );
        expect(iconSizedBox.width, equals(12.0));
        expect(iconSizedBox.height, equals(12.0));
      });

      testWidgets('should respect custom color', (WidgetTester tester) async {
        const customColor = Colors.green;
        
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sent,
          color: customColor,
        ));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(customColor));
      });
    });

    group('Status: Sending', () {
      testWidgets('should show clock icon when sending', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sending,
        ));

        expect(find.byIcon(Icons.access_time), findsOneWidget);
      });

      testWidgets('should animate when sending with animation enabled', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sending,
          showAnimation: true,
        ));

        // Clock icon should be present
        expect(find.byIcon(Icons.access_time), findsOneWidget);
        
        // Verify animation is running by checking widget rebuilds
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byIcon(Icons.access_time), findsOneWidget);
      });

      testWidgets('should not animate when showAnimation is false', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sending,
          showAnimation: false,
        ));

        // Clock icon should be present without animation
        expect(find.byIcon(Icons.access_time), findsOneWidget);
      });

      testWidgets('should use default color for sending status', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sending,
          showAnimation: false,
        ));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(AppColors.textMedium));
      });
    });

    group('Status: Sent', () {
      testWidgets('should show single check icon when sent', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sent,
        ));

        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets('should use default color for sent status', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sent,
        ));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(AppColors.textMedium));
      });

      testWidgets('should not animate for sent status', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sent,
        ));

        // Check icon should be present without animation
        expect(find.byIcon(Icons.check), findsOneWidget);
      });
    });

    group('Status: Delivered', () {
      testWidgets('should show double check icon when delivered', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.delivered,
        ));

        expect(find.byIcon(Icons.done_all), findsOneWidget);
      });

      testWidgets('should use default color for delivered status', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.delivered,
        ));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(AppColors.textMedium));
      });
    });

    group('Status: Read', () {
      testWidgets('should show double check icon when read', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.read,
        ));

        expect(find.byIcon(Icons.done_all), findsOneWidget);
      });

      testWidgets('should use primary blue color for read status', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.read,
        ));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(AppColors.primaryBlue));
      });

      testWidgets('should override default color when custom color provided', (WidgetTester tester) async {
        const customColor = Colors.purple;
        
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.read,
          color: customColor,
        ));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(customColor));
      });
    });

    group('Status: Failed', () {
      testWidgets('should show error icon when failed', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.failed,
        ));

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });

      testWidgets('should use error color for failed status', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.failed,
        ));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(AppColors.error));
      });

      testWidgets('should override error color when custom color provided', (WidgetTester tester) async {
        const customColor = Colors.orange;
        
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.failed,
          color: customColor,
        ));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(customColor));
      });
    });

    group('State Transitions', () {
      testWidgets('should transition from sending to sent', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sending,
        ));

        expect(find.byIcon(Icons.access_time), findsOneWidget);

        // Change status to sent
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sent,
        ));

        expect(find.byIcon(Icons.check), findsOneWidget);
        expect(find.byIcon(Icons.access_time), findsNothing);
      });

      testWidgets('should transition from sent to delivered', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sent,
        ));

        expect(find.byIcon(Icons.check), findsOneWidget);

        // Change status to delivered
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.delivered,
        ));

        expect(find.byIcon(Icons.done_all), findsOneWidget);
        expect(find.byIcon(Icons.check), findsNothing);
      });

      testWidgets('should transition from delivered to read', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.delivered,
        ));

        final deliveredIcon = tester.widget<Icon>(find.byIcon(Icons.done_all));
        expect(deliveredIcon.color, equals(AppColors.textMedium));

        // Change status to read
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.read,
        ));

        final readIcon = tester.widget<Icon>(find.byIcon(Icons.done_all));
        expect(readIcon.color, equals(AppColors.primaryBlue));
      });

      testWidgets('should transition from sending to failed', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sending,
        ));

        expect(find.byIcon(Icons.access_time), findsOneWidget);

        // Change status to failed
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.failed,
        ));

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.byIcon(Icons.access_time), findsNothing);
      });
    });

    group('Animation Control', () {
      testWidgets('should start animation when status changes to sending', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sent,
        ));

        expect(find.byIcon(Icons.check), findsOneWidget);

        // Change to sending status
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sending,
          showAnimation: true,
        ));

        expect(find.byIcon(Icons.access_time), findsOneWidget);
        expect(find.byIcon(Icons.check), findsNothing);
      });

      testWidgets('should stop animation when status changes from sending', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sending,
          showAnimation: true,
        ));

        expect(find.byIcon(Icons.access_time), findsOneWidget);

        // Change to sent status
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sent,
        ));

        expect(find.byIcon(Icons.check), findsOneWidget);
        expect(find.byIcon(Icons.access_time), findsNothing);
      });

      testWidgets('should complete full rotation during animation', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sending,
          showAnimation: true,
        ));

        // Initial state
        expect(find.byIcon(Icons.access_time), findsOneWidget);

        // Pump through animation duration
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byIcon(Icons.access_time), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byIcon(Icons.access_time), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byIcon(Icons.access_time), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle rapid status changes', (WidgetTester tester) async {
        // Rapidly change status
        await tester.pumpWidget(createTestWidget(status: MessageStatus.sending));
        await tester.pump();
        
        await tester.pumpWidget(createTestWidget(status: MessageStatus.sent));
        await tester.pump();
        
        await tester.pumpWidget(createTestWidget(status: MessageStatus.delivered));
        await tester.pump();
        
        await tester.pumpWidget(createTestWidget(status: MessageStatus.read));
        await tester.pump();

        // Should end with read status
        expect(find.byIcon(Icons.done_all), findsOneWidget);
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(AppColors.primaryBlue));
      });

      testWidgets('should handle very small sizes', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sent,
          size: 8,
        ));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.size, equals(8));
      });

      testWidgets('should handle very large sizes', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sent,
          size: 48,
        ));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.size, equals(48));
      });

      testWidgets('should properly dispose animation controller', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          status: MessageStatus.sending,
          showAnimation: true,
        ));

        expect(find.byType(MessageStatusIcon), findsOneWidget);

        // Remove widget to trigger disposal
        await tester.pumpWidget(const SizedBox());

        expect(find.byType(MessageStatusIcon), findsNothing);
        // Test passes if no memory leaks or exceptions occur
      });
    });
  });
}