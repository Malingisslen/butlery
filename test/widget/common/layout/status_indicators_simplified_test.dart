// test/widget/common/layout/status_indicators_simplified_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/widgets/common/layout/status_indicators.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/services/offline_service.dart';

// Simple mock that implements OfflineService behavior
class MockOfflineServiceForWidget extends Mock with ChangeNotifier implements OfflineService {
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
    late MockOfflineServiceForWidget mockOfflineService;

    setUp(() {
      mockOfflineService = MockOfflineServiceForWidget();
    });

    Widget createTestWidget(Widget child) {
      return ChangeNotifierProvider<OfflineService>.value(
        value: mockOfflineService,
        child: MaterialApp(
          home: Scaffold(
            body: child,
          ),
        ),
      );
    }

    group('StatusIndicators Facade Tests', () {
      testWidgets('offlineIndicator creates OfflineIndicator widget', (tester) async {
        final widget = StatusIndicators.offlineIndicator();
        
        await tester.pumpWidget(createTestWidget(widget));
        
        expect(find.byType(OfflineIndicator), findsOneWidget);
      });

      testWidgets('offlineStatusIcon creates OfflineStatusIcon widget', (tester) async {
        final widget = StatusIndicators.offlineStatusIcon();
        
        await tester.pumpWidget(createTestWidget(widget));
        
        expect(find.byType(OfflineStatusIcon), findsOneWidget);
      });

      testWidgets('facade methods create proper widget types', (tester) async {
        final indicator = StatusIndicators.offlineIndicator();
        final statusIcon = StatusIndicators.offlineStatusIcon();
        
        expect(indicator, isA<OfflineIndicator>());
        expect(statusIcon, isA<OfflineStatusIcon>());
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
        expect(find.text('Offline-läge - Ändringar sparas lokalt'), findsNothing);
      });

      testWidgets('switches from offline to online correctly', (tester) async {
        mockOfflineService.setOnlineStatus(false);
        
        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(),
        ));
        
        expect(find.text('Offline-läge - Ändringar sparas lokalt'), findsOneWidget);
        
        // Change to online
        mockOfflineService.setOnlineStatus(true);
        await tester.pumpAndSettle();
        
        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.text('Offline-läge - Ändringar sparas lokalt'), findsNothing);
      });
    });

    group('OfflineIndicator Offline State Tests', () {
      testWidgets('shows banner when offline with default message', (tester) async {
        mockOfflineService.setOnlineStatus(false);
        
        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(),
        ));
        
        expect(find.byType(Container), findsOneWidget);
        expect(find.byIcon(Icons.wifi_off), findsOneWidget);
        expect(find.text('Offline-läge - Ändringar sparas lokalt'), findsOneWidget);
      });

      testWidgets('shows custom message when provided', (tester) async {
        mockOfflineService.setOnlineStatus(false);
        const customMessage = 'Custom offline message';
        
        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(message: customMessage),
        ));
        
        expect(find.text(customMessage), findsOneWidget);
        expect(find.text('Offline-läge - Ändringar sparas lokalt'), findsNothing);
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

      testWidgets('has correct icon and text styling', (tester) async {
        mockOfflineService.setOnlineStatus(false);
        
        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(),
        ));
        
        final icon = tester.widget<Icon>(find.byIcon(Icons.wifi_off));
        expect(icon.color, AppColors.neutralLight);
        expect(icon.size, AppDimensions.iconSizeM);
        
        final text = tester.widget<Text>(find.text('Offline-läge - Ändringar sparas lokalt'));
        expect(text.style!.color, AppColors.neutralLight);
        expect(text.style!.fontWeight, FontWeight.w500);
      });
    });

    group('OfflineStatusIcon Tests', () {
      testWidgets('shows nothing when online', (tester) async {
        mockOfflineService.setOnlineStatus(true);
        
        await tester.pumpWidget(createTestWidget(
          const OfflineStatusIcon(),
        ));
        
        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off), findsNothing);
      });

      testWidgets('shows icon when offline', (tester) async {
        mockOfflineService.setOnlineStatus(false);
        
        await tester.pumpWidget(createTestWidget(
          const OfflineStatusIcon(),
        ));
        
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
        
        final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
        expect(icon.color, AppColors.warning);
        expect(icon.size, AppDimensions.iconSizeAction);
      });

      testWidgets('switches from offline to online correctly', (tester) async {
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

    group('Consumer Integration Tests', () {
      testWidgets('both widgets react to service state changes', (tester) async {
        mockOfflineService.setOnlineStatus(true);
        
        await tester.pumpWidget(createTestWidget(
          const Column(
            children: [
              OfflineIndicator(),
              OfflineStatusIcon(),
            ],
          ),
        ));
        
        expect(find.byType(SizedBox), findsNWidgets(2));
        expect(find.byIcon(Icons.wifi_off), findsNothing);
        expect(find.byIcon(Icons.cloud_off), findsNothing);
        
        // Change to offline
        mockOfflineService.setOnlineStatus(false);
        await tester.pumpAndSettle();
        
        expect(find.byType(Container), findsOneWidget);
        expect(find.byIcon(Icons.wifi_off), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
        expect(find.text('Offline-läge - Ändringar sparas lokalt'), findsOneWidget);
      });
    });

    group('Theme Integration Tests', () {
      testWidgets('uses correct AppColors constants', (tester) async {
        mockOfflineService.setOnlineStatus(false);
        
        await tester.pumpWidget(createTestWidget(
          const Column(
            children: [
              OfflineIndicator(),
              OfflineStatusIcon(),
            ],
          ),
        ));
        
        // Check OfflineIndicator colors
        final indicatorIcon = tester.widget<Icon>(find.byIcon(Icons.wifi_off));
        expect(indicatorIcon.color, AppColors.neutralLight);
        
        final text = tester.widget<Text>(find.text('Offline-läge - Ändringar sparas lokalt'));
        expect(text.style!.color, AppColors.neutralLight);
        
        // Check OfflineStatusIcon color
        final statusIcon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
        expect(statusIcon.color, AppColors.warning);
      });

      testWidgets('uses correct AppDimensions constants', (tester) async {
        mockOfflineService.setOnlineStatus(false);
        
        await tester.pumpWidget(createTestWidget(
          const Column(
            children: [
              OfflineIndicator(),
              OfflineStatusIcon(),
            ],
          ),
        ));
        
        // Check icon sizes
        final indicatorIcon = tester.widget<Icon>(find.byIcon(Icons.wifi_off));
        expect(indicatorIcon.size, AppDimensions.iconSizeM);
        
        final statusIcon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
        expect(statusIcon.size, AppDimensions.iconSizeAction);
        
        // Check container padding
        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingL,
          vertical: AppDimensions.spacingS,
        ));
      });
    });

    group('Swedish Localization Tests', () {
      testWidgets('uses correct Swedish default message', (tester) async {
        mockOfflineService.setOnlineStatus(false);
        
        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(),
        ));
        
        expect(find.text('Offline-läge - Ändringar sparas lokalt'), findsOneWidget);
        
        final text = tester.widget<Text>(find.text('Offline-läge - Ändringar sparas lokalt'));
        expect(text.data, contains('Offline-läge'));
        expect(text.data, contains('Ändringar'));
        expect(text.data, contains('sparas'));
        expect(text.data, contains('lokalt'));
      });

      testWidgets('handles Swedish characters in custom messages', (tester) async {
        mockOfflineService.setOnlineStatus(false);
        const swedishMessage = 'Anslutningen förlorad - åäö ÅÄÖ';
        
        await tester.pumpWidget(createTestWidget(
          const OfflineIndicator(message: swedishMessage),
        ));
        
        expect(find.text(swedishMessage), findsOneWidget);
        
        final text = tester.widget<Text>(find.text(swedishMessage));
        expect(text.data, contains('åäö'));
        expect(text.data, contains('ÅÄÖ'));
      });
    });
  });
}