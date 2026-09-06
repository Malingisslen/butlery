// test/widget/social/friend_requests_batch_actions_test.dart
//
// The batch friend-request flow end to end through the REAL action handler and
// the REAL ViewModel, over a mocked service.
//
// It exists because of the shape of the defect it closes: the three handlers
// used to show a modal spinner, wait a second, and report success without
// writing anything — nothing reached the service at all.
//
// All three verbs run the same cases: covering one verb leaves a re-pointed
// copy (cancel calling reject, say) green through the whole suite, which is
// the same class of defect as the stubs.

library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/views/social/friend_requests/friend_request_actions.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  late FriendsViewModel viewModel;
  late MockUnifiedFriendsService mockFriendsService;
  late MockUserService mockUserService;
  late MockFriendsManagementOperations mockManagement;
  late FriendRequestActions actions;
  final landedReports = <List<String>>[];

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

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    landedReports.clear();

    mockFriendsService = MockFactory.createUnifiedFriendsService();
    mockUserService = MockUserService();
    mockManagement = MockFriendsManagementOperations();

    final permissionService = FakePermissionService()
      ..setPermissionState(
        currentUserId: currentUserId,
        isAuthenticated: true,
      );

    TestServiceLocator.registerMock<UnifiedFriendsService>(mockFriendsService);
    TestServiceLocator.registerMock<UserService>(mockUserService);

    mockFriendsService.setFriendsState(
      friends: [],
      incomingRequests: requestIds.map(incoming).toList(),
      outgoingRequests: requestIds.map(outgoing).toList(),
      categoriesList: [],
      isLoading: false,
      error: null,
      isInitialized: true,
      management: mockManagement,
    );
    mockManagement.setManagementState(
      friends: [],
      incomingRequests: requestIds.map(incoming).toList(),
      outgoingRequests: requestIds.map(outgoing).toList(),
      shouldSucceed: true,
      failingRequestIds: {},
      throwingRequestIds: {},
    );
    mockUserService.setUserState(
      currentUser: null,
      users: {},
      isLoading: false,
      error: null,
    );

    viewModel = FriendsViewModel(
      authRepository: FakeAuthRepository(),
      maturityHelper: FakeMaturedAccountHelper(),
      friendsService: mockFriendsService,
      userService: mockUserService,
      analyticsService: MockAnalyticsService(),
      permissionService: permissionService,
    );
    actions = FriendRequestActions();
  });

  tearDown(() async {
    viewModel.dispose();
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<void> pumpHost(WidgetTester tester, _Verb verb) {
    return tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv', 'SE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => verb.run(
                actions,
                context,
                viewModel,
                requestIds,
                landedReports.add,
              ),
              child: const Text('kör'),
            ),
          ),
        ),
      ),
    );
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.text('kör')));

  Future<AppLocalizations> runAndConfirm(
    WidgetTester tester,
    _Verb verb,
  ) async {
    await pumpHost(tester, verb);
    final l10n = l10nOf(tester);

    await tester.tap(find.text('kör'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(verb.confirmLabel(l10n)));
    await tester.pumpAndSettle();

    return l10n;
  }

  for (final verb in _verbs) {
    group(verb.name, () {
      testWidgets('confirming the dialog writes every selected request', (
        tester,
      ) async {
        final l10n = await runAndConfirm(tester, verb);

        expect(verb.calls(mockManagement), requestIds);
        // The other two verbs must see nothing: a handler re-pointed at the
        // wrong ViewModel method reports the same count in the same words.
        for (final other in _verbs.where((v) => v.name != verb.name)) {
          expect(other.calls(mockManagement), isEmpty, reason: other.name);
        }
        expect(find.text(verb.all(l10n, 2)), findsOneWidget);
        expect(landedReports, [requestIds]);
      });

      testWidgets('declining the dialog writes nothing', (tester) async {
        await pumpHost(tester, verb);
        final l10n = l10nOf(tester);

        await tester.tap(find.text('kör'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.commonCancel));
        await tester.pumpAndSettle();

        expect(verb.calls(mockManagement), isEmpty);
        expect(landedReports, isEmpty);
      });

      testWidgets('a partial batch says how many landed, not that all did', (
        tester,
      ) async {
        mockManagement.setManagementState(failingRequestIds: {'req-2'});

        final l10n = await runAndConfirm(tester, verb);

        expect(find.text(verb.partial(l10n, 1, 2)), findsOneWidget);
        expect(find.text(verb.all(l10n, 2)), findsNothing);
        // Only the id that landed is reported back; what the view then does
        // with the rest is the view's decision, pinned in its own suite.
        expect(landedReports, [
          ['req-1'],
        ]);
      });

      testWidgets('a batch where nothing lands reports an error and still '
          'reports back', (tester) async {
        mockManagement.setManagementState(shouldSucceed: false);

        final l10n = await runAndConfirm(tester, verb);

        expect(find.text(verb.none(l10n)), findsOneWidget);
        // Both ids were attempted. An action that THREW would show this same
        // message from executeAction's catch, having written nothing.
        expect(verb.calls(mockManagement), requestIds);
        // An EMPTY report, not no report: the view reconciles its selection
        // from it either way.
        expect(landedReports, [<String>[]]);
      });

      testWidgets('an empty selection asks nothing and writes nothing', (
        tester,
      ) async {
        await pumpHost(tester, verb);
        final l10n = l10nOf(tester);

        await verb.run(
          actions,
          tester.element(find.text('kör')),
          viewModel,
          const [],
          landedReports.add,
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.socialNoRequestsSelected), findsOneWidget);
        expect(find.text(verb.confirmLabel(l10n)), findsNothing);
        expect(verb.calls(mockManagement), isEmpty);
        expect(landedReports, isEmpty);
      });

      testWidgets('no modal barrier survives the batch', (tester) async {
        await runAndConfirm(tester, verb);

        // The old stubs opened a barrierDismissible: false progress dialog and
        // never closed it, leaving the screen unusable behind it.
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });
  }

  testWidgets(
    'the FAB delegates to the caller instead of running the batch itself',
    (tester) async {
      var batchStarts = 0;

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
          home: DefaultTabController(
            length: 2,
            child: Builder(
              builder: (context) => Scaffold(
                body: const SizedBox.shrink(),
                floatingActionButton: actions.buildFloatingActionButton(
                  context,
                  DefaultTabController.of(context),
                  requestIds.toSet(),
                  () => batchStarts++,
                  batchRunning: false,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // The FAB used to run the batch itself AND hand this callback to the
      // batch as its own completion callback, so one press ran the flow twice
      // over.
      expect(batchStarts, 1);
      expect(mockManagement.acceptCalls, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}

/// One batch verb. Every case runs against all three, so a handler re-pointed
/// at the wrong ViewModel method cannot hide behind a suite that exercises only
/// one of them.
class _Verb {
  const _Verb({
    required this.name,
    required this.run,
    required this.confirmLabel,
    required this.all,
    required this.partial,
    required this.none,
    required this.calls,
  });

  final String name;
  final Future<void> Function(
    FriendRequestActions,
    BuildContext,
    FriendsViewModel,
    List<String>,
    void Function(List<String>),
  )
  run;
  final String Function(AppLocalizations) confirmLabel;
  final String Function(AppLocalizations, int) all;
  final String Function(AppLocalizations, int, int) partial;
  final String Function(AppLocalizations) none;
  final List<String> Function(MockFriendsManagementOperations) calls;
}

final _verbs = <_Verb>[
  _Verb(
    name: 'acceptMultipleRequests',
    run: (a, c, vm, ids, onSettled) =>
        a.acceptMultipleRequests(c, vm, ids, onSettled),
    confirmLabel: (l) => l.socialAcceptAll,
    all: (l, n) => l.socialRequestsAccepted(n),
    partial: (l, n, total) => l.socialRequestsAcceptedPartial(n, total),
    none: (l) => l.socialCouldNotAcceptAllRequests,
    calls: (m) => m.acceptCalls,
  ),
  _Verb(
    name: 'rejectMultipleRequests',
    run: (a, c, vm, ids, onSettled) =>
        a.rejectMultipleRequests(c, vm, ids, onSettled),
    confirmLabel: (l) => l.socialRejectAll,
    all: (l, n) => l.socialRequestsRejected(n),
    partial: (l, n, total) => l.socialRequestsRejectedPartial(n, total),
    none: (l) => l.socialCouldNotRejectAllRequests,
    calls: (m) => m.rejectCalls,
  ),
  _Verb(
    name: 'cancelMultipleSentRequests',
    run: (a, c, vm, ids, onSettled) =>
        a.cancelMultipleSentRequests(c, vm, ids, onSettled),
    confirmLabel: (l) => l.socialCancelAll,
    all: (l, n) => l.socialRequestsCancelled(n),
    partial: (l, n, total) => l.socialRequestsCancelledPartial(n, total),
    none: (l) => l.socialCouldNotCancelAllRequests,
    calls: (m) => m.cancelCalls,
  ),
];
