import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/layout/status_indicators.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/di/di_container.dart';
import 'package:get_it/get_it.dart';
// ignore: unused_import - mocktail removed, lightweight mock used instead
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/base_widget_test.dart';

/// Lightweight mock that extends ChangeNotifier so listeners work.
class _MockOfflineService extends ChangeNotifier implements OfflineService {
  bool _online = true;

  @override
  bool get isOnline => _online;

  void setOnline(bool value) {
    _online = value;
    notifyListeners();
  }

  // Stubs for remaining OfflineService API (unused in indicator widgets)
  @override
  bool get isInitialized => true;
  @override
  String? get currentUserId => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('StatusIndicators Tests', () {
    late _MockOfflineService mockOffline;

    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      // Bridge production ServiceLocator to the same GetIt instance
      production.ServiceLocator.initialize(DIContainer());
      mockOffline = _MockOfflineService();
      // Register into GetIt so production ServiceLocator.get<OfflineService>() works
      final getIt = GetIt.instance;
      if (getIt.isRegistered<OfflineService>()) {
        getIt.unregister<OfflineService>();
      }
      getIt.registerSingleton<OfflineService>(mockOffline);
    });

    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    group('StatusIndicators facade', () {
      testWidgets('offlineIndicator creates OfflineIndicator widget', (
        tester,
      ) async {
        final widget = StatusIndicators.offlineIndicator();
        await tester.pumpWidget(createLocalizedTestApp(child: widget));
        expect(find.byType(OfflineIndicator), findsOneWidget);
      });

      testWidgets('offlineStatusIcon creates OfflineStatusIcon widget', (
        tester,
      ) async {
        final widget = StatusIndicators.offlineStatusIcon();
        await tester.pumpWidget(createLocalizedTestApp(child: widget));
        expect(find.byType(OfflineStatusIcon), findsOneWidget);
      });

      testWidgets('facade methods return correct widget types', (tester) async {
        expect(StatusIndicators.offlineIndicator(), isA<OfflineIndicator>());
        expect(StatusIndicators.offlineStatusIcon(), isA<OfflineStatusIcon>());
      });
    });

    group('OfflineIndicator - online state', () {
      testWidgets('shows nothing when online', (tester) async {
        mockOffline.setOnline(true);

        await tester.pumpWidget(
          createLocalizedTestApp(child: const OfflineIndicator()),
        );
        await tester.pumpAndSettle();

        // AnimatedSwitcher renders SizedBox.shrink when online
        expect(find.byType(AnimatedSwitcher), findsOneWidget);
        expect(find.byIcon(Icons.wifi_off), findsNothing);
      });

      testWidgets('switches from offline to online', (tester) async {
        mockOffline.setOnline(false);

        await tester.pumpWidget(
          createLocalizedTestApp(child: const OfflineIndicator()),
        );
        await tester.pump();

        expect(find.byIcon(Icons.wifi_off), findsOneWidget);

        mockOffline.setOnline(true);
        // Pump past the "back online" confirmation timer (3s snackbarDuration)
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 3100));
        await tester.pumpAndSettle();

        // After going online the offline icon is gone
        expect(find.byIcon(Icons.wifi_off), findsNothing);
      });
    });

    group('OfflineIndicator - offline state', () {
      testWidgets('shows banner when offline', (tester) async {
        mockOffline.setOnline(false);

        await tester.pumpWidget(
          createLocalizedTestApp(child: const OfflineIndicator()),
        );
        await tester.pump();

        expect(find.byIcon(Icons.wifi_off), findsOneWidget);
        // l10n sv: 'Offline-lage - Andringar sparas lokalt'
        expect(
          find.text('Offline-l\u00e4ge - \u00c4ndringar sparas lokalt'),
          findsOneWidget,
        );
      });

      testWidgets('shows custom message when provided', (tester) async {
        mockOffline.setOnline(false);
        const msg = 'Anpassat meddelande';

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const OfflineIndicator(message: msg),
          ),
        );
        await tester.pump();

        expect(find.text(msg), findsOneWidget);
        expect(
          find.text('Offline-l\u00e4ge - \u00c4ndringar sparas lokalt'),
          findsNothing,
        );
      });

      testWidgets('uses custom background color', (tester) async {
        mockOffline.setOnline(false);
        const customColor = Colors.red;

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const OfflineIndicator(backgroundColor: customColor),
          ),
        );
        await tester.pump();

        // The offline banner is a Container with a ValueKey('offline')
        final container = tester.widget<Container>(
          find.byKey(const ValueKey('offline')),
        );
        expect(container.color, customColor);
      });

      testWidgets('icon has correct size', (tester) async {
        mockOffline.setOnline(false);

        await tester.pumpWidget(
          createLocalizedTestApp(child: const OfflineIndicator()),
        );
        await tester.pump();

        final icon = tester.widget<Icon>(find.byIcon(Icons.wifi_off));
        expect(icon.size, AppDimensions.iconSizeM);
      });
    });

    group('OfflineStatusIcon', () {
      testWidgets('shows nothing when online', (tester) async {
        mockOffline.setOnline(true);

        await tester.pumpWidget(
          createLocalizedTestApp(child: const OfflineStatusIcon()),
        );

        expect(find.byIcon(Icons.cloud_off), findsNothing);
      });

      testWidgets('shows cloud_off icon when offline', (tester) async {
        mockOffline.setOnline(false);

        await tester.pumpWidget(
          createLocalizedTestApp(child: const OfflineStatusIcon()),
        );

        expect(find.byIcon(Icons.cloud_off), findsOneWidget);

        final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
        expect(icon.size, AppDimensions.iconSizeAction);
      });

      testWidgets('switches from offline to online', (tester) async {
        mockOffline.setOnline(false);

        await tester.pumpWidget(
          createLocalizedTestApp(child: const OfflineStatusIcon()),
        );

        expect(find.byIcon(Icons.cloud_off), findsOneWidget);

        mockOffline.setOnline(true);
        await tester.pump();

        expect(find.byIcon(Icons.cloud_off), findsNothing);
      });
    });

    group('Both widgets together', () {
      testWidgets('react to service state changes', (tester) async {
        mockOffline.setOnline(true);

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const Column(
              children: [
                OfflineIndicator(),
                OfflineStatusIcon(),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.wifi_off), findsNothing);
        expect(find.byIcon(Icons.cloud_off), findsNothing);

        mockOffline.setOnline(false);
        await tester.pump();

        expect(find.byIcon(Icons.wifi_off), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      });
    });
  });
}
