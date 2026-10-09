/// BUT-1499: a shared menu opens live on the weekly-menu screen. The prompt
/// and the "clear" action are gone (a new generation would overwrite
/// everyone's menu), the conflict banner is mounted on the menu's id, and the
/// swap controls follow the viewer's role.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/router/app_router.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/viewmodels/realtime_menu_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/views/veckomeny_view.dart';
import 'package:butlery/widgets/menu/menu_placement_footer.dart';
import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';
import 'package:butlery/widgets/realtime/conflict_banner.dart';

import '../../infrastructure/di/test_service_locator.dart';
import 'veckomeny_flow_harness.dart';

class _MockSync extends Mock implements RealtimeSyncService {}

class _MockMenuService extends Mock implements RealtimeMenuService {}

class _FakeLiveMenu extends Fake implements RealtimeMenu {}

class _FakeRealtimeVm extends ChangeNotifier
    with Fake
    implements RealtimeMenuViewModel {
  RealtimeMenu? menu;
  Map<String, List<Recipe>> snapshot = {};
  bool editable = true;

  @override
  RealtimeMenu? get currentMenu => menu;

  @override
  Map<String, List<Recipe>> get menuWithOptimisticChanges => snapshot;

  @override
  bool get canEdit => menu != null && editable;

  @override
  Future<void> startWatching(String menuId) async {}

  @override
  Future<void> stopWatching() async {}

  void deliver(Map<String, List<Recipe>> next, {bool canEdit = true}) {
    menu = _FakeLiveMenu();
    snapshot = next;
    editable = canEdit;
    notifyListeners();
  }
}

void main() {
  late VeckomenyFlowHarness h;
  late _FakeRealtimeVm realtime;
  late StreamController<ConflictEvent> conflicts;

  setUp(() async {
    h = VeckomenyFlowHarness();
    await h.setUp();
    realtime = _FakeRealtimeVm();
    conflicts = StreamController<ConflictEvent>.broadcast();
    final sync = _MockSync();
    when(() => sync.conflictStream).thenAnswer((_) => conflicts.stream);
    GetIt.instance.registerSingleton<RealtimeSyncService>(sync);
    GetIt.instance.registerSingleton<RealtimeMenuService>(_MockMenuService());
    TestServiceLocator.registerFactory<RealtimeMenuViewModel>(() => realtime);
  });

  tearDown(() async {
    await conflicts.close();
    await h.tearDown();
  });

  Future<void> openLive(WidgetTester tester) async {
    await h.pump(tester, home: const VeckomenyView(realtimeMenuId: 'm1'));
    realtime.deliver({
      'Middag': [flowDinner(1)],
    });
    await tester.pumpAndSettle();
  }

  bool tapEnabled(WidgetTester tester, IconData icon) {
    final inkWell = tester.widget<InkWell>(
      find
          .ancestor(of: find.byIcon(icon), matching: find.byType(InkWell))
          .first,
    );
    return inkWell.onTap != null;
  }

  testWidgets('shows the live menu without the prompt, and with the banner '
      'on the menu id', (tester) async {
    await openLive(tester);

    expect(find.text('Middag 1'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(
      find.byKey(const ValueKey('test-veckomeny-generate')),
      findsNothing,
    );
    expect(
      tester.widget<ConflictBanner>(find.byType(ConflictBanner)).filterDocId,
      'm1',
    );
  });

  testWidgets('a live menu shows no Lista/Kalender toggle', (tester) async {
    await openLive(tester);

    expect(find.text('Middag 1'), findsOneWidget);
    expect(find.byType(VeckomenyViewModeToggle), findsNothing);
  });

  testWidgets('a personal menu shows the Lista/Kalender toggle', (
    tester,
  ) async {
    await h.pump(tester, home: const VeckomenyView());
    await tester.pumpAndSettle();

    expect(find.byType(VeckomenyViewModeToggle), findsOneWidget);
  });

  testWidgets('offers no "clear" in the root bar menu', (tester) async {
    await openLive(tester);

    await tester.tap(find.byKey(const ValueKey('veckomeny-root-more')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('veckomeny-root-save')), findsOneWidget);
    expect(find.byKey(const ValueKey('veckomeny-root-clear')), findsNothing);
  });

  testWidgets('offers no "load saved menu" in the root bar menu', (
    tester,
  ) async {
    await openLive(tester);

    await tester.tap(find.byKey(const ValueKey('veckomeny-root-more')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('veckomeny-root-load')), findsNothing);
  });

  testWidgets('offers no calendar placement for the live menu', (
    tester,
  ) async {
    await openLive(tester);

    expect(find.byType(MenuPlacementChoiceFooter), findsNothing);
  });

  testWidgets('a stored Kalender preference still opens the live menu in '
      'Lista, shopping from the live menu', (tester) async {
    SharedPreferences.setMockInitialValues({'veckomeny_view_mode': 'kalender'});
    await openLive(tester);

    expect(find.text('Middag 1'), findsOneWidget);
    // The user's own week is empty: in Kalender the shopping button would
    // read it and hide, in Lista it reads the live menu and shows.
    expect(find.byIcon(ButleryIcons.shoppingCart), findsOneWidget);
  });

  testWidgets('a viewer can neither swap nor regenerate, an editor can', (
    tester,
  ) async {
    await openLive(tester);
    expect(tapEnabled(tester, ButleryIcons.swapHorizontal), isTrue);
    expect(tapEnabled(tester, ButleryIcons.refreshCw), isTrue);

    realtime.deliver({
      'Middag': [flowDinner(1)],
    }, canEdit: false);
    await tester.pumpAndSettle();

    expect(tapEnabled(tester, ButleryIcons.swapHorizontal), isFalse);
    expect(tapEnabled(tester, ButleryIcons.refreshCw), isFalse);
  });

  testWidgets('a personal menu still has the prompt and no banner', (
    tester,
  ) async {
    await h.pump(tester, home: const VeckomenyView());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsWidgets);
    expect(find.byType(ConflictBanner), findsNothing);
  });

  test('the router reads the menu id from the route arguments', () {
    expect(AppRouter.liveMenuIdFrom({'menuId': 'm1'}), 'm1');
    expect(AppRouter.liveMenuIdFrom(<String, dynamic>{}), isNull);
    expect(AppRouter.liveMenuIdFrom({'menuId': 7}), isNull);
    expect(AppRouter.liveMenuIdFrom({'menuId': ''}), isNull);
    expect(AppRouter.liveMenuIdFrom(null), isNull);
    expect(AppRouter.liveMenuIdFrom('m1'), isNull);
  });
}
