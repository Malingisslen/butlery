/// BUT-1162: surface-level test proving [ConflictBanner] is actually wired into
/// the shared-menu collaborative surface ([MenuPreviewView]) — not just that the
/// banner widget works in isolation (that contract lives in
/// test/widget/realtime/conflict_banner_test.dart).
///
/// This pins the acceptance criterion "widget test for at least one of the three
/// surfaces asserting the banner appears after pumping a ConflictEvent through
/// the stream", and additionally proves the mount passes the right filterDocId
/// (a conflict for another menu must NOT surface here).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_menu_viewmodel.dart';
import 'package:butlery/views/social/menu_preview_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockRealtimeSyncService extends Mock implements RealtimeSyncService {}

class _MockCoordinator extends Mock
    implements SharedContentCoordinatorViewModel {}

class _MockMenuViewModel extends Mock implements SharedMenuViewModel {}

class _FakeResource extends Fake implements RealtimeResource {}

class _FakeSharedMenu extends Fake implements SharedMenu {}

ConflictEvent _event({required String docId}) => ConflictEvent(
  collectionPath: 'menus',
  docId: docId,
  localValue: _FakeResource(),
  remoteValue: _FakeResource(),
  chosenStrategy: ConflictResolutionStrategy.localWon,
  occurredAt: DateTime(2026, 5, 28),
);

void main() {
  late _MockRealtimeSyncService realtime;
  late _MockCoordinator coordinator;
  late _MockMenuViewModel menuViewModel;
  late StreamController<ConflictEvent> conflicts;
  late SharedMenu menu;

  setUpAll(() {
    registerFallbackValue(_FakeSharedMenu());
  });

  setUp(() async {
    await GetIt.instance.reset();

    conflicts = StreamController<ConflictEvent>.broadcast();
    realtime = _MockRealtimeSyncService();
    when(() => realtime.conflictStream).thenAnswer((_) => conflicts.stream);
    GetIt.instance.registerSingleton<RealtimeSyncService>(realtime);
    // ConflictBanner resolves the service via the production ServiceLocator,
    // which shares GetIt.instance with the registration above.
    prod.ServiceLocator.initialize(DIContainer());

    menu = SharedMenu(
      id: 'menu-1',
      sharedByUserId: 'u1',
      sharedByDisplayName: 'Anna',
      menuTitle: 'Veckomeny',
      menuSnapshot: const {}, // empty -> renders the empty-state, no recipes
    );

    menuViewModel = _MockMenuViewModel();
    when(() => menuViewModel.isMenuImported(any())).thenReturn(false);
    when(() => menuViewModel.isItemOperating(any())).thenReturn(false);
    coordinator = _MockCoordinator();
    when(() => coordinator.menuViewModel).thenReturn(menuViewModel);
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await conflicts.close();
    await GetIt.instance.reset();
  });

  testWidgets(
    'ConflictBanner is wired into MenuPreviewView and surfaces only for this '
    'menu doc',
    (tester) async {
      late String bannerMessage;

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false, // MenuPreviewView provides its own Scaffold
          child:
              ChangeNotifierProvider<SharedContentCoordinatorViewModel>.value(
                value: coordinator,
                child: Builder(
                  builder: (context) {
                    bannerMessage = context.l10n.conflictBannerMessage;
                    return MenuPreviewView(sharedMenu: menu);
                  },
                ),
              ),
        ),
      );
      await tester.pump();

      expect(
        find.text(bannerMessage),
        findsNothing,
        reason: 'no banner before any conflict event',
      );

      // A conflict for a DIFFERENT menu must be filtered out by filterDocId.
      conflicts.add(_event(docId: 'some-other-menu'));
      await tester.pumpAndSettle();
      expect(
        find.text(bannerMessage),
        findsNothing,
        reason: 'filterDocId must ignore conflicts for other menus',
      );

      // A conflict for THIS menu must surface the banner on the real surface.
      conflicts.add(_event(docId: menu.id));
      await tester.pumpAndSettle();
      expect(
        find.text(bannerMessage),
        findsOneWidget,
        reason: 'a conflict on this menu doc must surface the wired banner',
      );
    },
  );
}
