/// Opening a shared menu from the shared-with-me list: a collaborative menu the
/// user has joined opens live; anything else opens the preview, whose join
/// step is how an invitation is accepted. Both the card body and "Visa" open.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_menu_viewmodel.dart';
import 'package:butlery/views/social/menu_preview_view.dart';
import 'package:butlery/views/social/shared_with_me/shared_menu_card.dart';

import '../../../../infrastructure/helpers/widget_test_app.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

class _MockCoordinator extends Mock
    implements SharedContentCoordinatorViewModel {}

class _MockMenuViewModel extends Mock implements SharedMenuViewModel {}

class _MockRealtimeSyncService extends Mock implements RealtimeSyncService {}

class _FakeUserService extends Fake implements UserService {}

class _FakeSharedMenu extends Fake implements SharedMenu {}

void main() {
  late _MockCoordinator coordinator;
  late _MockMenuViewModel menus;
  late List<RouteSettings> namedPushes;

  SharedMenu shared({required bool collaborative}) => SharedMenu(
    id: 'share-1',
    sharedByUserId: 'u-anna',
    sharedByDisplayName: 'Anna',
    menuTitle: 'Snabb vardag',
    menuSnapshot: const {},
    allowCollaboration: collaborative,
    realtimeMenuId: 'live-42',
  );

  setUpAll(() => registerFallbackValue(_FakeSharedMenu()));

  setUp(() async {
    await GetIt.instance.reset();
    final realtime = _MockRealtimeSyncService();
    when(
      () => realtime.conflictStream,
    ).thenAnswer((_) => const Stream.empty());
    GetIt.instance.registerSingleton<RealtimeSyncService>(realtime);
    // MenuPreviewView builds a MenuDishCreditViewModel that resolves both.
    GetIt.instance.registerSingleton<UserService>(_FakeUserService());
    GetIt.instance.registerSingleton<PermissionService>(
      FakePermissionService()..setPermissionState(currentUserId: 'viewer'),
    );
    prod.ServiceLocator.initialize(DIContainer());

    menus = _MockMenuViewModel();
    when(() => menus.isMenuViewed(any())).thenReturn(false);
    when(() => menus.isItemOperating(any())).thenReturn(false);
    when(() => menus.hasError).thenReturn(false);
    when(() => menus.markAsViewed(any())).thenAnswer((_) async => true);
    coordinator = _MockCoordinator();
    when(() => coordinator.menuViewModel).thenReturn(menus);
    namedPushes = [];
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<void> pumpCard(
    WidgetTester tester,
    SharedMenu menu, {
    required bool joined,
  }) async {
    when(() => menus.isMenuImported(any())).thenReturn(joined);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScrollView: true,
        onGenerateRoute: (settings) {
          namedPushes.add(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('live stub')),
          );
        },
        child: Builder(
          builder: (context) =>
              SharedMenuCard.build(context, coordinator, menu),
        ),
      ),
    );
  }

  final triggers = <String, Finder Function()>{
    'the card': () => find.text('Snabb vardag'),
    'Visa': () => find.text('Visa'),
  };

  for (final entry in triggers.entries) {
    group('opening from ${entry.key}', () {
      testWidgets('a joined collaborative menu opens live on its realtime id', (
        tester,
      ) async {
        await pumpCard(tester, shared(collaborative: true), joined: true);

        await tester.tap(entry.value());
        await tester.pumpAndSettle();

        expect(namedPushes.map((s) => s.name), [Routes.realtimeMenu]);
        expect(namedPushes.single.arguments, {'menuId': 'live-42'});
        expect(find.byType(MenuPreviewView), findsNothing);
        verify(() => menus.markAsViewed(any())).called(1);
      });

      testWidgets('a collaborative menu not yet joined opens the preview', (
        tester,
      ) async {
        await pumpCard(tester, shared(collaborative: true), joined: false);

        await tester.tap(entry.value());
        await tester.pumpAndSettle();

        expect(namedPushes, isEmpty);
        expect(find.byType(MenuPreviewView), findsOneWidget);
      });

      testWidgets('a non-collaborative menu opens the preview even when '
          'already imported', (tester) async {
        await pumpCard(tester, shared(collaborative: false), joined: true);

        await tester.tap(entry.value());
        await tester.pumpAndSettle();

        expect(namedPushes, isEmpty);
        expect(find.byType(MenuPreviewView), findsOneWidget);
      });
    });
  }
}
