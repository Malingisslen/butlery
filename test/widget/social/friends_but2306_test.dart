// BUT-2306: a friend shown as "Online" whatever their state, an accept that
// said nothing for seconds, and incoming requests visible only under
// "Hitta vänner".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/views/more/more_view.dart';
import 'package:butlery/views/social/friends_list/friends_list_cards.dart';
import 'package:butlery/views/social/friends_list/search_result_card.dart';
import 'package:butlery/widgets/common/content_cards/friend_card.dart' as cards;
import 'package:butlery/widgets/common/sync/sync_queue_indicator.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';
import '../views/sync/fake_sync_queue_source.dart';

FriendRequest _incoming(String id) => FriendRequest(
  id: id,
  fromUserId: 'sender-$id',
  toUserId: 'me',
  status: FriendRequestStatus.pending,
  sentAt: DateTime(2026, 10, 1),
);

class _MockFriendsVm extends Mock implements FriendsViewModel {}

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  testWidgets('a friend without a bio gets no presence line, even when the '
      'stored profile says online', (tester) async {
    final friend = UserProfile(
      uid: 'friend',
      email: 'friend@example.com',
      displayName: 'Björn Ek',
      joinedAt: DateTime(2026),
      lastActiveAt: DateTime(2026),
      isOnline: true,
    );
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(builder: (context) => FriendCard.build(context, friend)),
      ),
    );

    expect(find.text('Björn Ek'), findsOneWidget);
    expect(find.text('Online'), findsNothing);
  });

  testWidgets('a friend with a bio still shows it', (tester) async {
    final friend = UserProfile(
      uid: 'friend',
      email: 'friend@example.com',
      displayName: 'Björn Ek',
      joinedAt: DateTime(2026),
      lastActiveAt: DateTime(2026),
      bio: 'Lagar gärna soppa',
    );
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(builder: (context) => FriendCard.build(context, friend)),
      ),
    );

    expect(find.text('Lagar gärna soppa'), findsOneWidget);
  });

  group('the search result button says it is working', () {
    final them = UserProfile(
      uid: 'sender-r1',
      email: 'them@example.com',
      displayName: 'Björn Ek',
      joinedAt: DateTime(2026),
      lastActiveAt: DateTime(2026),
    );

    Future<_MockFriendsVm> pump(
      WidgetTester tester,
      FriendshipStatus status, {
      bool sending = false,
      bool accepting = false,
    }) async {
      final vm = _MockFriendsVm();
      when(() => vm.isBlocked(any())).thenReturn(false);
      when(() => vm.getFriendshipStatus(them.uid)).thenReturn(status);
      when(() => vm.isSendingTo(them.uid)).thenReturn(sending);
      when(() => vm.incomingRequests).thenReturn([_incoming('r1')]);
      when(() => vm.isAccepting(any())).thenReturn(false);
      when(() => vm.isAccepting('r1')).thenReturn(accepting);
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => SearchResultCard.build(context, them, vm),
          ),
        ),
      );
      return vm;
    }

    testWidgets('while a request goes out', (tester) async {
      await pump(tester, FriendshipStatus.none, sending: true);
      expect(find.text('Skickar …'), findsOneWidget);
    });

    testWidgets('while their request is accepted', (tester) async {
      await pump(tester, FriendshipStatus.requestReceived, accepting: true);
      expect(find.text('Accepterar …'), findsOneWidget);
    });

    testWidgets('and not before', (tester) async {
      await pump(tester, FriendshipStatus.none);
      expect(find.text('Skickar …'), findsNothing);
      await pump(tester, FriendshipStatus.requestReceived);
      expect(find.text('Accepterar …'), findsNothing);
      expect(find.text('Acceptera'), findsOneWidget);
    });
  });

  group('accepting a request', () {
    Future<void> pumpCard(WidgetTester tester, {required bool accepting}) =>
        tester.pumpWidget(
          createLocalizedTestApp(
            child: cards.FriendRequestCard(
              friendRequest: _incoming('r1'),
              senderName: 'Björn Ek',
              isAccepting: accepting,
              onAccept: () {},
              onDecline: () {},
            ),
          ),
        );

    testWidgets('while it runs, the buttons say so and take no tap', (
      tester,
    ) async {
      await pumpCard(tester, accepting: true);

      expect(find.text('Accepterar …'), findsOneWidget);
      for (final button in tester.widgetList<ButtonStyleButton>(
        find.byWidgetPredicate((w) => w is ButtonStyleButton),
      )) {
        expect(button.onPressed, isNull);
      }
    });

    testWidgets('before it runs, both buttons take a tap', (tester) async {
      await pumpCard(tester, accepting: false);

      expect(find.text('Accepterar …'), findsNothing);
      final buttons = tester.widgetList<ButtonStyleButton>(
        find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(buttons, hasLength(2));
      expect(buttons.every((b) => b.onPressed != null), isTrue);
    });
  });

  group('Mer', () {
    late MockUnifiedFriendsService friends;

    setUp(() {
      SyncQueueSource.debugOverride = FakeSyncQueueSource();
      production.ServiceLocator.initialize(DIContainer());
      friends = MockUnifiedFriendsService();
      final getIt = GetIt.instance;
      if (getIt.isRegistered<UnifiedFriendsService>()) {
        getIt.unregister<UnifiedFriendsService>();
      }
      getIt.registerSingleton<UnifiedFriendsService>(friends);
    });

    tearDown(() {
      SyncQueueSource.debugOverride = null;
      final getIt = GetIt.instance;
      if (getIt.isRegistered<UnifiedFriendsService>()) {
        getIt.unregister<UnifiedFriendsService>();
      }
      production.ServiceLocator.reset();
    });

    Finder friendsRowCount() => find.descendant(
      of: find.byKey(MoreView.rowKey(Routes.friends)),
      matching: find.byType(SaffronCount),
    );

    testWidgets('Vänner & grupper counts the requests waiting', (
      tester,
    ) async {
      friends.setFriendsState(
        incomingRequests: [_incoming('a'), _incoming('b')],
      );
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const MoreView(avatar: SizedBox.square(dimension: 40)),
        ),
      );

      expect(friendsRowCount(), findsOneWidget);
      expect(
        find.descendant(of: friendsRowCount(), matching: find.text('2')),
        findsOneWidget,
      );
      final handle = tester.ensureSemantics();
      expect(
        tester
            .getSemantics(find.byKey(MoreView.rowKey(Routes.friends)))
            .getSemanticsData()
            .value,
        'Väntar på dig · 2',
      );
      handle.dispose();
    });

    testWidgets('and shows nothing when none waits', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const MoreView(avatar: SizedBox.square(dimension: 40)),
        ),
      );

      expect(find.byKey(MoreView.rowKey(Routes.friends)), findsOneWidget);
      expect(friendsRowCount(), findsNothing);
    });

    testWidgets('and follows requests that arrive and go while it is open', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const MoreView(avatar: SizedBox.square(dimension: 40)),
        ),
      );
      expect(friendsRowCount(), findsNothing);

      // A pump runs its frame before the stream's event lands, so the
      // rebuild that event asks for needs a second one.
      Future<void> deliver(FriendsServiceState state) async {
        friends.emitState(state);
        await tester.pump();
        await tester.pump();
      }

      friends.setFriendsState(incomingRequests: [_incoming('a')]);
      await deliver(const FriendsStateLoading());
      expect(
        find.descendant(of: friendsRowCount(), matching: find.text('1')),
        findsOneWidget,
      );

      // A stream error keeps what is shown.
      friends.emitStateError(Exception('offline'));
      await tester.pump();
      await tester.pump();
      expect(friendsRowCount(), findsOneWidget);

      friends.setFriendsState(incomingRequests: []);
      await deliver(const FriendsStateLoading());
      expect(friendsRowCount(), findsNothing);
    });
  });
}
