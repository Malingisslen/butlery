// test/widget/common/layout/status_indicators_ultrathink_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/widgets/common/layout/status_indicators.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/services/offline_service.dart';

// Mock implementation for testing
class MockOfflineServiceForTest extends Mock
    with ChangeNotifier
    implements OfflineService {
  bool _isOnline = true;

  @override
  bool get isOnline => _isOnline;

  void setOnlineStatus(bool online) {
    _isOnline = online;
    notifyListeners();
  }
}

void main() {
  group('StatusIndicators Tests - ULTRATHINK METHODOLOGY', () {
    late MockOfflineServiceForTest mockOfflineService;

    setUp(() {
      mockOfflineService = MockOfflineServiceForTest();
    });

    Widget createTestWidget(Widget child) {
      return Provider<OfflineService>.value(
        value: mockOfflineService,
        child: MaterialApp(
          home: Scaffold(
            body: child,
          ),
        ),
      );
    }

    group('StatusIndicators Facade Tests', () {
      testWidgets('offlineIndicator returns OfflineIndicator widget',
          (tester) async {
        final widget = StatusIndicators.offlineIndicator();

        await tester.pumpWidget(createTestWidget(widget));

        expect(find.byType(OfflineIndicator), findsOneWidget);
      });

      testWidgets('offlineIndicator with custom message and background color',
          (tester) async {
        const customMessage = 'Custom offline message';
        const customColor = Colors.red;

        final widget = StatusIndicators.offlineIndicator(
          message: customMessage,
          backgroundColor: customColor,
        );

        await tester.pumpWidget(createTestWidget(widget));

        expect(find.byType(OfflineIndicator), findsOneWidget);

        final offlineIndicator = tester.widget<OfflineIndicator>(
          find.byType(OfflineIndicator),
        );
        expect(offlineIndicator.message, customMessage);
        expect(offlineIndicator.backgroundColor, customColor);
      });

      testWidgets('offlineStatusIcon returns OfflineStatusIcon widget',
          (tester) async {
        final widget = StatusIndicators.offlineStatusIcon();

        await tester.pumpWidget(createTestWidget(widget));

        expect(find.byType(OfflineStatusIcon), findsOneWidget);
      });

      testWidgets('static methods create independent widget instances',
          (tester) async {
        final widget1 = StatusIndicators.offlineIndicator();
        final widget2 = StatusIndicators.offlineIndicator();
        final iconWidget1 = StatusIndicators.offlineStatusIcon();
        final iconWidget2 = StatusIndicators.offlineStatusIcon();

        expect(widget1, isNot(same(widget2)));
        expect(iconWidget1, isNot(same(iconWidget2)));
        expect(widget1, isA<OfflineIndicator>());
        expect(iconWidget1, isA<OfflineStatusIcon>());
      });

      testWidgets('facade methods work without parameters', (tester) async {
        final widget = StatusIndicators.offlineIndicator();
        final iconWidget = StatusIndicators.offlineStatusIcon();

        await tester.pumpWidget(createTestWidget(
          Column(children: [widget, iconWidget]),
        ));

        expect(find.byType(OfflineIndicator), findsOneWidget);
        expect(find.byType(OfflineStatusIcon), findsOneWidget);
      });
    });

    group('OfflineIndicator Online State Tests', () {
      testWidgets('shows nothing when online', (tester) async {
        mockOfflineService.setOnlineStatus(true);

        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(),
        ));

        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(Container), findsNothing);
        expect(find.byIcon(Icons.wifi_off), findsNothing);

        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.width, 0.0);
        expect(sizedBox.height, 0.0);
      });

      testWidgets('online state persists across rebuilds', (tester) async {
        mockOfflineService.setOnlineStatus(true);

        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(),
        ));

        expect(find.byType(SizedBox), findsOneWidget);

        // Rebuild and verify state persistence
        await tester.pumpAndSettle();
        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(Container), findsNothing);
      });

      testWidgets('handles service state changes from offline to online',
          (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(),
        ));

        expect(find.byType(Container), findsOneWidget);

        // Change to online
        mockOfflineService.setOnlineStatus(true);
        await tester.pumpAndSettle();

        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(Container), findsNothing);
      });
    });

    group('OfflineIndicator Offline State Tests', () {
      testWidgets('shows banner when offline with default styling',
          (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(),
        ));

        expect(find.byType(Container), findsOneWidget);
        expect(find.byIcon(Icons.wifi_off), findsOneWidget);
        expect(find.text('Offline-läge - Ändringar sparas lokalt'),
            findsOneWidget);

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.decoration, isA<BoxDecoration>());

        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, AppColors.warning);
      });

      testWidgets('shows custom message when provided', (tester) async {
        mockOfflineService.setOnlineStatus(false);
        const customMessage = 'Custom offline message';

        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(message: customMessage),
        ));

        expect(find.text(customMessage), findsOneWidget);
        expect(
            find.text('Offline-läge - Ändringar sparas lokalt'), findsNothing);
      });

      testWidgets('uses custom background color when provided', (tester) async {
        mockOfflineService.setOnlineStatus(false);
        const customColor = Colors.red;

        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(backgroundColor: customColor),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.color, customColor);
      });

      testWidgets('container has correct styling and dimensions',
          (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        // Container width is set via constructor, test the render box size
        final renderBox =
            tester.renderObject<RenderBox>(find.byType(Container));
        expect(renderBox.size.width,
            greaterThan(0)); // Should fill available width
        expect(
            container.padding,
            const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingL,
              vertical: AppDimensions.spacingS,
            ));
      });

      testWidgets('row has correct layout and alignment', (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(),
        ));

        final row = tester.widget<Row>(find.byType(Row));
        expect(row.mainAxisAlignment, MainAxisAlignment.center);
        expect(row.children, hasLength(3)); // Icon, SizedBox, Text
      });

      testWidgets('icon has correct properties', (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(),
        ));

        final icon = tester.widget<Icon>(find.byIcon(Icons.wifi_off));
        expect(icon.icon, Icons.wifi_off);
        expect(icon.color, AppColors.neutralLight);
        expect(icon.size, AppDimensions.iconSizeM);
      });

      testWidgets('text has correct styling', (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(),
        ));

        final text = tester
            .widget<Text>(find.text('Offline-läge - Ändringar sparas lokalt'));
        final textStyle = text.style!;
        expect(textStyle.color, AppColors.neutralLight);
        expect(textStyle.fontWeight, FontWeight.w500);
      });

      testWidgets('spacing between icon and text is correct', (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(),
        ));

        final sizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(Row),
            matching: find.byType(SizedBox),
          ),
        );
        expect(sizedBox.width, AppDimensions.spacingM);
      });
    });

    group('OfflineStatusIcon Online State Tests', () {
      testWidgets('shows nothing when online', (tester) async {
        mockOfflineService.setOnlineStatus(true);

        await tester.pumpWidget(createTestWidget(
          const OfflineStatusIcon(),
        ));

        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(Icon), findsNothing);

        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.width, 0.0);
        expect(sizedBox.height, 0.0);
      });

      testWidgets('online state persists across rebuilds', (tester) async {
        mockOfflineService.setOnlineStatus(true);

        await tester.pumpWidget(createTestWidget(
          const OfflineStatusIcon(),
        ));

        expect(find.byType(SizedBox), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off), findsNothing);
      });

      testWidgets('handles service state changes from offline to online',
          (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          const OfflineStatusIcon(),
        ));

        expect(find.byIcon(Icons.cloud_off), findsOneWidget);

        // Change to online
        mockOfflineService.setOnlineStatus(true);
        await tester.pumpAndSettle();

        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off), findsNothing);
      });
    });

    group('OfflineStatusIcon Offline State Tests', () {
      testWidgets('shows icon when offline with correct styling',
          (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          const OfflineStatusIcon(),
        ));

        expect(find.byIcon(Icons.cloud_off), findsOneWidget);

        final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
        expect(icon.icon, Icons.cloud_off);
        expect(icon.color, AppColors.warning);
        expect(icon.size, AppDimensions.iconSizeAction);
      });

      testWidgets('has correct padding for app bar positioning',
          (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          const OfflineStatusIcon(),
        ));

        final padding = tester.widget<Padding>(find.byType(Padding));
        expect(padding.padding,
            const EdgeInsets.only(right: AppDimensions.spacingS));
      });

      testWidgets('works in app bar context', (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          AppBar(
            title: const Text('Test'),
            actions: const [
              OfflineStatusIcon(),
            ],
          ),
        ));

        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
        expect(find.text('Test'), findsOneWidget);
      });
    });

    group('Consumer OfflineService Integration Tests', () {
      testWidgets('both widgets react to service state changes',
          (tester) async {
        mockOfflineService.setOnlineStatus(true);

        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              OfflineIndicator(),
              OfflineStatusIcon(),
            ],
          ),
        ));

        expect(find.byType(SizedBox), findsNWidgets(2));
        expect(find.byType(Container), findsNothing);
        expect(find.byIcon(Icons.cloud_off), findsNothing);

        // Change to offline
        mockOfflineService.setOnlineStatus(false);
        await tester.pumpAndSettle();

        expect(find.byType(Container), findsOneWidget);
        expect(find.byIcon(Icons.wifi_off), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
        expect(find.text('Offline-läge - Ändringar sparas lokalt'),
            findsOneWidget);
      });

      testWidgets('widgets update independently based on service state',
          (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          Row(
            children: const [
              OfflineIndicator(),
              OfflineStatusIcon(),
            ],
          ),
        ));

        expect(find.byType(Container), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);

        // Change to online
        mockOfflineService.setOnlineStatus(true);
        await tester.pumpAndSettle();

        expect(find.byType(SizedBox), findsNWidgets(2));
        expect(find.byType(Container), findsNothing);
        expect(find.byIcon(Icons.cloud_off), findsNothing);
      });

      testWidgets('multiple rapid state changes handled correctly',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(),
        ));

        // Rapid state changes
        for (int i = 0; i < 5; i++) {
          mockOfflineService.setOnlineStatus(i.isEven);
          await tester.pumpAndSettle();

          if (i.isEven) {
            expect(find.byType(SizedBox), findsOneWidget);
          } else {
            expect(find.byType(Container), findsOneWidget);
          }
        }
      });

      testWidgets('service context provided correctly to nested widgets',
          (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              Card(
                child: Column(
                  children: [
                    OfflineIndicator(),
                    Divider(),
                    OfflineStatusIcon(),
                  ],
                ),
              ),
            ],
          ),
        ));

        expect(find.byType(Container), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
        expect(find.text('Offline-läge - Ändringar sparas lokalt'),
            findsOneWidget);
      });
    });

    group('Theme Integration Tests', () {
      testWidgets('OfflineIndicator adapts to different themes',
          (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(
          Provider<OfflineService>.value(
            value: mockOfflineService,
            child: MaterialApp(
              theme: ThemeData(
                brightness: Brightness.dark,
                colorScheme: const ColorScheme.dark(),
              ),
              home: const Scaffold(
                body: OfflineIndicator(),
              ),
            ),
          ),
        );

        expect(find.byType(Container), findsOneWidget);
        expect(find.byIcon(Icons.wifi_off), findsOneWidget);

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(
            decoration.color, AppColors.warning); // Should remain warning color
      });

      testWidgets('custom colors override theme defaults', (tester) async {
        mockOfflineService.setOnlineStatus(false);
        const customColor = Colors.purple;

        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(backgroundColor: customColor),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.color, customColor);
      });

      testWidgets('AppColors constants used consistently', (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              OfflineIndicator(),
              OfflineStatusIcon(),
            ],
          ),
        ));

        // Check OfflineIndicator colors
        final indicatorIcon = tester.widget<Icon>(find.byIcon(Icons.wifi_off));
        expect(indicatorIcon.color, AppColors.neutralLight);

        final text = tester
            .widget<Text>(find.text('Offline-läge - Ändringar sparas lokalt'));
        expect(text.style!.color, AppColors.neutralLight);

        // Check OfflineStatusIcon color
        final statusIcon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
        expect(statusIcon.color, AppColors.warning);
      });

      testWidgets('AppDimensions constants used consistently', (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              OfflineIndicator(),
              OfflineStatusIcon(),
            ],
          ),
        ));

        // Check OfflineIndicator dimensions
        final indicatorIcon = tester.widget<Icon>(find.byIcon(Icons.wifi_off));
        expect(indicatorIcon.size, AppDimensions.iconSizeM);

        final container = tester.widget<Container>(find.byType(Container));
        expect(
            container.padding,
            const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingL,
              vertical: AppDimensions.spacingS,
            ));

        // Check OfflineStatusIcon dimensions
        final statusIcon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
        expect(statusIcon.size, AppDimensions.iconSizeAction);

        final padding = tester.widget<Padding>(find.byType(Padding));
        expect(padding.padding,
            const EdgeInsets.only(right: AppDimensions.spacingS));
      });
    });

    group('Swedish Localization Tests', () {
      testWidgets('uses Swedish offline message by default', (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(),
        ));

        expect(find.text('Offline-läge - Ändringar sparas lokalt'),
            findsOneWidget);

        final text = tester
            .widget<Text>(find.text('Offline-läge - Ändringar sparas lokalt'));
        expect(text.data, contains('Offline-läge'));
        expect(text.data, contains('Ändringar sparas lokalt'));
      });

      testWidgets('handles Swedish characters correctly in custom messages',
          (tester) async {
        mockOfflineService.setOnlineStatus(false);
        const swedishMessage = 'Anslutningen är förlorad - åäö ÅÄÖ';

        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(message: swedishMessage),
        ));

        expect(find.text(swedishMessage), findsOneWidget);

        final text = tester.widget<Text>(find.text(swedishMessage));
        expect(text.data, contains('åäö'));
        expect(text.data, contains('ÅÄÖ'));
        expect(text.data, contains('förlorad'));
      });

      testWidgets('text styling supports Swedish characters', (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(),
        ));

        final text = tester
            .widget<Text>(find.text('Offline-läge - Ändringar sparas lokalt'));
        final style = text.style!;
        expect(style.fontWeight, FontWeight.w500);
        expect(style.color, AppColors.neutralLight);

        // Verify text renders correctly
        final renderParagraph = tester
            .renderObject(find.text('Offline-läge - Ändringar sparas lokalt'));
        expect(renderParagraph.runtimeType.toString(),
            contains('RenderParagraph'));
      });
    });

    group('Edge Cases and Error Handling Tests', () {
      testWidgets('handles null OfflineService gracefully', (tester) async {
        // This should be caught by Flutter's Provider system
        expect(() async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: OfflineIndicator(),
              ),
            ),
          );
        }, throwsA(isA<ProviderNotFoundException>()));
      });

      testWidgets('handles extreme message lengths', (tester) async {
        mockOfflineService.setOnlineStatus(false);
        final longMessage = 'A' * 1000; // Very long message

        await tester.pumpWidget(createTestWidget(
          OfflineIndicator(message: longMessage),
        ));

        expect(find.text(longMessage), findsOneWidget);
        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('handles empty custom message', (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(message: ''),
        ));

        expect(find.text(''), findsOneWidget);
        expect(
            find.text('Offline-läge - Ändringar sparas lokalt'), findsNothing);
      });

      testWidgets('handles special characters in messages', (tester) async {
        mockOfflineService.setOnlineStatus(false);
        const specialMessage = '🌐 📶 ⚠️ Offline! @#\$%^&*()[]{}|;:,.<>?';

        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(message: specialMessage),
        ));

        expect(find.text(specialMessage), findsOneWidget);
      });

      testWidgets('multiple widgets with same service instance work correctly',
          (tester) async {
        mockOfflineService.setOnlineStatus(false);

        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              OfflineIndicator(),
              OfflineIndicator(message: 'Custom message'),
              OfflineStatusIcon(),
              OfflineStatusIcon(),
            ],
          ),
        ));

        expect(find.byType(OfflineIndicator), findsNWidgets(2));
        expect(find.byType(OfflineStatusIcon), findsNWidgets(2));
        expect(find.text('Offline-läge - Ändringar sparas lokalt'),
            findsOneWidget);
        expect(find.text('Custom message'), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off), findsNWidgets(2));
      });

      testWidgets('maintains performance with frequent state changes',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(),
        ));

        final stopwatch = Stopwatch()..start();

        // Simulate rapid state changes
        for (int i = 0; i < 100; i++) {
          mockOfflineService.setOnlineStatus(i.isOdd);
          await tester.pump(const Duration(milliseconds: 1));
        }

        stopwatch.stop();

        // Should complete relatively quickly (less than 5 seconds for 100 changes)
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));

        // Final state should be respected
        expect(find.byType(Container),
            findsOneWidget); // Should be offline (99 is odd)
      });
    });
  });
}
