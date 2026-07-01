// test/widget/common/cooking_mode_offline_banner_test.dart
//
// Intent (BUT-1360): prove the cooking-mode offline banner appears while the
// cook is offline and is invisible when online — without breaking the
// landscape split-view (ingredients left, instructions right).
//
// Cooking offline is the marquee scenario, so the banner must never be missed
// offline yet cost zero layout when online. We mirror the exact placement used
// by `cooking_mode_view._CookingModeContent.build` (offlineIndicator as the top
// strip of the Column above the split Row), following the same
// structure-mirror approach as `cooking_mode_touch_target_test` — pumping the
// full view drags in wakelock/SystemChrome/VM plumbing that would make this
// contract flaky.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/layout/status_indicators.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/di/di_container.dart';
import 'package:get_it/get_it.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

/// Lightweight OfflineService double that drives the OfflineIndicator's
/// ServiceLocator lookup + listener. Mirrors the stub in
/// `status_indicators_simplified_test.dart`.
class _MockOfflineService extends ChangeNotifier implements OfflineService {
  bool _online = true;

  @override
  bool get isOnline => _online;

  void setOnline(bool value) {
    _online = value;
    notifyListeners();
  }

  @override
  bool get isInitialized => true;
  @override
  String? get currentUserId => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mirrors the cooking-mode content layout: offline strip pinned above the
/// landscape split Row. Keeps the two panels present so the test also proves
/// the banner doesn't displace the split view.
Widget _cookingModeLayout() {
  return Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          LayoutComponents.offlineIndicator(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(flex: 35, child: Center(child: Text('ingredients'))),
                Expanded(flex: 65, child: Center(child: Text('instructions'))),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('Cooking-mode offline banner', () {
    late _MockOfflineService mockOffline;

    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      production.ServiceLocator.initialize(DIContainer());
      mockOffline = _MockOfflineService();
      final getIt = GetIt.instance;
      if (getIt.isRegistered<OfflineService>()) {
        getIt.unregister<OfflineService>();
      }
      getIt.registerSingleton<OfflineService>(mockOffline);
    });

    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    testWidgets('shows the offline strip while offline, split view intact', (
      tester,
    ) async {
      mockOffline.setOnline(false);

      await tester.pumpWidget(
        createLocalizedTestApp(child: _cookingModeLayout()),
      );
      await tester.pump();

      // Banner is present...
      expect(find.byType(OfflineIndicator), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      // ...and the split view is untouched.
      expect(find.text('ingredients'), findsOneWidget);
      expect(find.text('instructions'), findsOneWidget);
    });

    testWidgets('hides the offline strip when online (no layout cost)', (
      tester,
    ) async {
      mockOffline.setOnline(true);

      await tester.pumpWidget(
        createLocalizedTestApp(child: _cookingModeLayout()),
      );
      await tester.pumpAndSettle();

      // OfflineIndicator is mounted but renders SizedBox.shrink — no banner.
      expect(find.byIcon(Icons.wifi_off), findsNothing);
      expect(find.text('ingredients'), findsOneWidget);
      expect(find.text('instructions'), findsOneWidget);
    });

    testWidgets('reacts to going offline mid-cook', (tester) async {
      mockOffline.setOnline(true);

      await tester.pumpWidget(
        createLocalizedTestApp(child: _cookingModeLayout()),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.wifi_off), findsNothing);

      mockOffline.setOnline(false);
      await tester.pump();

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });
  });
}
