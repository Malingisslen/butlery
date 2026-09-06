// test/widget/social/friend_requests_selection_lock_test.dart
//
// The two decisions that live in the VIEW rather than in the action handler:
// which ids leave the selection, and whether the batch controls can be
// pressed again while one is running. The handler only reports
// what landed; `FriendRequestsView` decides both, so both are pinned here
// against the real view over a real ViewModel and a mocked service.

library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/views/social/friend_requests/friend_requests_view.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  late MockUnifiedFriendsService mockFriendsService;
  late MockFriendsManagementOperations mockManagement;

  const currentUserId = 'test-user-123';
  final requestIds = ['req-1', 'req-2'];

  FriendRequest incoming(String id) => FriendRequest(
    id: id,
    fromUserId: 'sender-$id',
    toUserId: currentUserId,
    status: FriendRequestStatus.pending,
    sentAt: DateTime(2026, 9, 1),
  );

  FriendRequest outgoing(String id) => FriendRequest(
    id: id,
    fromUserId: currentUserId,
    toUserId: 'recipient-$id',
    status: FriendRequestStatus.pending,
    sentAt: DateTime(2026, 9, 1),
  );

  final sentIds = ['sent-1', 'sent-2'];

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
    production.ServiceLocator.initialize(DIContainer());
    Provider.debugCheckInvalidValueType = null;
  });

  setUp(() async {
    await TestServiceLocator.initialize();

    mockFriendsService = MockFactory.createUnifiedFriendsService();
    mockManagement = MockFriendsManagementOperations();

    final permissionService = FakePermissionService()
      ..setPermissionState(
        currentUserId: currentUserId,
        isAuthenticated: true,
      );
    final mockUserService = MockUserService()
      ..setUserState(
        currentUser: null,
        users: {},
        isLoading: false,
        error: null,
      );

    mockFriendsService.setFriendsState(
      friends: [],
      incomingRequests: requestIds.map(incoming).toList(),
      outgoingRequests: sentIds.map(outgoing).toList(),
      categoriesList: [],
      isLoading: false,
      error: null,
      isInitialized: true,
      management: mockManagement,
    );
    mockManagement.setManagementState(
      friends: [],
      incomingRequests: requestIds.map(incoming).toList(),
      outgoingRequests: sentIds.map(outgoing).toList(),
      shouldSucceed: true,
      failingRequestIds: {},
      throwingRequestIds: {},
    );

    TestServiceLocator.registerMock<UnifiedFriendsService>(mockFriendsService);
    TestServiceLocator.registerMock<UserService>(mockUserService);
    final offlineService = MockOfflineService();
    when(() => offlineService.isOnline).thenReturn(true);
    when(() => offlineService.addListener(any())).thenReturn(null);
    when(() => offlineService.removeListener(any())).thenReturn(null);
    TestServiceLocator.registerMock<OfflineService>(offlineService);
    TestServiceLocator.registerMock<FriendsViewModel>(
      FriendsViewModel(
        authRepository: FakeAuthRepository(),
        maturityHelper: FakeMaturedAccountHelper(),
        friendsService: mockFriendsService,
        userService: mockUserService,
        analyticsService: MockAnalyticsService(),
        permissionService: permissionService,
      ),
    );
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
    // After the cleanups: a failing expect throws.
    expect(
      mockManagement.hasOutstandingRequestGate,
      isFalse,
      reason: 'a paused request gate was never released',
    );
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv', 'SE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const FriendRequestsView(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Selects both pending requests. The cards render a display name resolved
  /// from a profile this suite does not stub, so the checkbox is the stable
  /// handle rather than any text.
  Future<void> selectBoth(WidgetTester tester) async {
    expect(find.byType(Checkbox), findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byType(Checkbox).at(i));
      await tester.pump();
    }
  }

  /// Bounded instead of `pumpAndSettle`: the FAB's progress indicator spins
  /// for as long as a batch is paused, so settling would never return.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<AppLocalizations> confirmAcceptAll(WidgetTester tester) async {
    final l10n = AppLocalizations.of(
      tester.element(find.byType(FriendRequestsView)),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.checklist),
      ),
    );
    await settle(tester);
    await tester.tap(find.text(l10n.socialAcceptCount(2)).last);
    await settle(tester);
    await tester.tap(find.text(l10n.socialAcceptAll));
    return l10n;
  }

  VoidCallback? fabPress(WidgetTester tester) => tester
      .widget<FloatingActionButton>(find.byType(FloatingActionButton))
      .onPressed;

  /// The app-bar menu is the second way into a batch, and it locks separately
  /// from the FAB — a lock on one of them is not a lock.
  bool menuEnabled(WidgetTester tester) => tester
      .widget<PopupMenuButton<String>>(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>),
        ),
      )
      .enabled;

  testWidgets('a partial batch leaves the ids that failed selected', (
    tester,
  ) async {
    mockManagement.setManagementState(failingRequestIds: {'req-2'});

    await pumpView(tester);
    await selectBoth(tester);
    final l10n = await confirmAcceptAll(tester);
    await settle(tester);

    // The FAB counts the selection, so it is the observable. A count of 1
    // does not say WHICH id survived; that the survivor is the failed one is
    // pinned by `an id that vanished while the batch ran stops being counted`,
    // where keeping the landed id instead would leave the FAB on screen.
    expect(find.text(l10n.socialAcceptCount(1)), findsOneWidget);
    expect(find.text(l10n.socialAcceptCount(2)), findsNothing);
  });

  testWidgets('a batch that fully lands empties the selection', (tester) async {
    await pumpView(tester);
    await selectBoth(tester);
    await confirmAcceptAll(tester);
    await settle(tester);

    // Nothing left to act on, so the batch controls are gone entirely.
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.checklist),
      ),
      findsNothing,
    );
  });

  testWidgets('the batch controls are locked while a batch runs and usable '
      'again afterwards', (tester) async {
    mockManagement
      ..setManagementState(failingRequestIds: {'req-2'})
      ..pauseRequests();

    await pumpView(tester);
    await selectBoth(tester);
    await confirmAcceptAll(tester);
    await tester.pump();

    expect(fabPress(tester), isNull, reason: 'locked while the batch runs');
    expect(menuEnabled(tester), isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    mockManagement.releaseRequests();
    await settle(tester);

    // req-2 failed, so a control is still on screen — and pressable again.
    expect(fabPress(tester), isNotNull, reason: 'unlocked once it finishes');
    expect(menuEnabled(tester), isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a batch where every id throws still unlocks the controls', (
    tester,
  ) async {
    mockManagement
      ..setManagementState(throwingRequestIds: {'req-1', 'req-2'})
      ..pauseRequests();

    await pumpView(tester);
    await selectBoth(tester);
    final l10n = await confirmAcceptAll(tester);
    await tester.pump();

    expect(fabPress(tester), isNull);

    mockManagement.releaseRequests();
    await settle(tester);

    // Nothing landed and both requests are still open, so the reconcile
    // keeps them and the whole selection stays — and the controls work.
    // The throws are swallowed per id inside the ViewModel, so they never
    // reach `_runLocked`: this does not exercise its `finally`, and a probe
    // that moves the unlock out of it stays green. Nothing pins that clause.
    expect(fabPress(tester), isNotNull);
    expect(menuEnabled(tester), isTrue);
    expect(find.text(l10n.socialAcceptCount(2)), findsOneWidget);
  });

  testWidgets('the controls do not lock while the confirmation is still '
      'asking', (tester) async {
    mockManagement.pauseRequests();

    await pumpView(tester);
    await selectBoth(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(FriendRequestsView)),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.checklist),
      ),
    );
    await settle(tester);
    await tester.tap(find.text(l10n.socialAcceptCount(2)).last);
    await settle(tester);

    // The dialog is open and nothing has been written, so a spinner here
    // would claim work that has not started — and would have to be taken back
    // if the user cancels.
    expect(mockManagement.acceptCalls, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text(l10n.socialAcceptAll));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    mockManagement.releaseRequests();
    await settle(tester);
  });

  testWidgets('an id that vanished while the batch ran stops being counted', (
    tester,
  ) async {
    // req-2 fails AND disappears from the service mid-batch, which is what a
    // request cancelled from another device looks like. Keeping it selected
    // would leave the controls counting a request that is no longer a card.
    //
    // `landed` is NON-EMPTY here: the vanished id has to survive removeAll and
    // then be caught by retainWhere. The empty side of that boundary is
    // `a batch where EVERY id vanished still stops counting them`.
    mockManagement
      ..setManagementState(failingRequestIds: {'req-2'})
      ..pauseRequests();

    await pumpView(tester);
    await selectBoth(tester);
    await confirmAcceptAll(tester);
    await tester.pump();

    mockFriendsService.setFriendsState(
      incomingRequests: [incoming('req-1')],
      isInitialized: true,
      management: mockManagement,
    );
    mockManagement.releaseRequests();
    await settle(tester);

    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('a batch where EVERY id vanished still stops counting them', (
    tester,
  ) async {
    // The worst case, and the one the reconcile was built for: both requests
    // were cancelled from another device, so nothing lands, and the tab's
    // empty state hides the "Rensa" button.
    //
    // `landed` is EMPTY here, so retainWhere does all the work alone. The
    // non-empty side of that boundary is
    // `an id that vanished while the batch ran stops being counted`.
    mockManagement
      ..setManagementState(shouldSucceed: false)
      ..pauseRequests();

    await pumpView(tester);
    await selectBoth(tester);
    await confirmAcceptAll(tester);
    await tester.pump();

    mockFriendsService.setFriendsState(
      incomingRequests: [],
      isInitialized: true,
      management: mockManagement,
    );
    mockManagement.releaseRequests();
    await settle(tester);

    expect(find.byType(FloatingActionButton), findsNothing);
  });

  group('the sent tab', () {
    /// The three handlers are copies, and only the sent one reads
    /// `_selectedSent`. Driving the incoming tab alone lets a handler that
    /// clears the wrong set survive the whole repo.
    Future<AppLocalizations> openSentTabAndSelectBoth(
      WidgetTester tester,
    ) async {
      await pumpView(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(FriendRequestsView)),
      );

      await tester.tap(find.text(l10n.socialSent));
      await settle(tester);
      await selectBoth(tester);
      return l10n;
    }

    /// The IconButton itself, for reading `.onPressed`. `byTooltip` matches
    /// the Tooltip wrapper instead, so it is only used for tapping.
    Finder cancelButton() => find.descendant(
      of: find.byType(AppBar),
      matching: find.widgetWithIcon(IconButton, Icons.cancel),
    );

    Finder cancelTooltip(AppLocalizations l10n, int count) => find.descendant(
      of: find.byType(AppBar),
      matching: find.byTooltip(l10n.socialCancelCount(count)),
    );

    testWidgets('a partial cancel keeps the failed SENT id selected', (
      tester,
    ) async {
      mockManagement.setManagementState(failingRequestIds: {'sent-2'});

      final l10n = await openSentTabAndSelectBoth(tester);
      await tester.tap(cancelTooltip(l10n, 2));
      await settle(tester);
      await tester.tap(find.text(l10n.socialCancelAll));
      await settle(tester);

      // The count going 2 -> 1 is also what kills a handler that drops the
      // landed ids from `_selectedIncoming` instead: the sent selection would
      // still read 2. (Switching tabs clears both sets, so the incoming set
      // cannot be inspected afterwards to say the same thing.)
      expect(cancelTooltip(l10n, 1), findsOneWidget);
    });

    testWidgets('the cancel control locks while its batch runs', (
      tester,
    ) async {
      mockManagement
        ..setManagementState(failingRequestIds: {'sent-2'})
        ..pauseRequests();

      final l10n = await openSentTabAndSelectBoth(tester);
      await tester.tap(cancelTooltip(l10n, 2));
      await settle(tester);
      await tester.tap(find.text(l10n.socialCancelAll));
      await tester.pump();

      expect(
        tester.widget<IconButton>(cancelButton()).onPressed,
        isNull,
        reason: 'locked while the batch runs',
      );

      mockManagement.releaseRequests();
      await settle(tester);

      expect(
        tester.widget<IconButton>(cancelButton()).onPressed,
        isNotNull,
      );
    });
  });
}
