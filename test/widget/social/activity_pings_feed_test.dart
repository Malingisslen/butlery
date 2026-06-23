// test/widget/social/activity_pings_feed_test.dart
//
// BUT-407-C: widget tests for the activity + pings feed.
//
// Strategy: inject fake `PingService`, `ActivityEventRepository`, and
// `UnifiedFriendsService` implementations so we control exactly what the
// widget sees. We verify the rendering contract (empty → SizedBox.shrink,
// top-5 cap, copy per type) and the ack-on-tap contract.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/models/social/ping.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/activity_event_repository.dart';
import 'package:butlery/services/social/ping_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/social/activity_pings_feed.dart';

class _FakePingService implements PingService {
  final StreamController<List<Ping>> controller =
      StreamController<List<Ping>>.broadcast();
  final List<_AckCall> ackCalls = [];

  @override
  Stream<List<Ping>> watchGroup(String groupId) => controller.stream;

  @override
  Future<void> acknowledge({
    required String groupId,
    required String pingId,
  }) async {
    ackCalls.add(_AckCall(groupId, pingId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AckCall {
  final String groupId;
  final String pingId;
  _AckCall(this.groupId, this.pingId);
}

class _FakeActivityRepo implements ActivityEventRepository {
  List<ActivityEvent> events;
  int fetchCount = 0;

  _FakeActivityRepo(this.events);

  @override
  Future<List<ActivityEvent>> fetchFriendActivity({
    required List<String> friendIds,
    int limit = 20,
    DateTime? before,
  }) async {
    fetchCount++;
    return events;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFriendsService implements UnifiedFriendsService {
  final String _myId;
  final List<FriendCategory> _cats;
  final List<UserProfile> _friends;

  _FakeFriendsService({
    required String myId,
    required List<FriendCategory> categories,
    required List<UserProfile> friends,
  }) : _myId = myId,
       _cats = categories,
       _friends = friends;

  @override
  String? get currentUserId => _myId;

  @override
  List<FriendCategory> get categoriesList => List.unmodifiable(_cats);

  @override
  List<UserProfile> get friends => List.unmodifiable(_friends);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserProfile _profile(String uid, {String? name}) => UserProfile(
  uid: uid,
  displayName: name ?? uid[0].toUpperCase() + uid.substring(1),
  email: '$uid@butlery.test',
  joinedAt: DateTime(2026, 1, 1),
  lastActiveAt: DateTime(2026, 4, 20),
);

Ping _ping({
  required String id,
  required String from,
  PingType type = PingType.nudge,
  String? message,
  bool acknowledged = false,
  DateTime? at,
}) => Ping(
  id: id,
  groupId: 'g1',
  fromUserId: from,
  type: type,
  message: message,
  createdAt: at ?? DateTime.now(),
  acknowledged: acknowledged,
);

ActivityEvent _activity({
  required String id,
  required String actor,
  required ActivityEventType type,
  String recipeId = 'r1',
  String recipeTitle = 'Kycklinggryta',
  Map<String, dynamic>? extra,
  DateTime? at,
}) => ActivityEvent(
  id: id,
  actorId: actor,
  actorDisplayName: actor[0].toUpperCase() + actor.substring(1),
  type: type,
  recipeId: recipeId,
  recipeTitle: recipeTitle,
  extraData: extra ?? const {},
  createdAt: at ?? DateTime.now(),
);

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('sv'),
    home: Scaffold(body: child),
  );
}

_FakeFriendsService _friendsWithGroup({
  required String me,
  required List<String> memberIds,
}) {
  return _FakeFriendsService(
    myId: me,
    categories: [
      FriendCategory(
        id: 'g1',
        name: 'Familjen',
        ownerId: me,
        friendUserIds: memberIds,
        createdAt: DateTime(2026, 1, 1),
      ),
    ],
    friends: memberIds.map((id) => _profile(id)).toList(),
  );
}

void main() {
  group('ActivityPingsFeed', () {
    testWidgets('empty state → SizedBox.shrink (no feed rendered)', (
      tester,
    ) async {
      final pings = _FakePingService();
      final repo = _FakeActivityRepo(const []);
      final friends = _friendsWithGroup(me: 'me', memberIds: ['erik']);

      await tester.pumpWidget(
        _wrap(
          ActivityPingsFeed(
            groupId: 'g1',
            pingService: pings,
            activityRepository: repo,
            friendsService: friends,
          ),
        ),
      );
      // Flush the stream's initial frame + the first activity fetch.
      pings.controller.add(const []);
      await tester.pump();
      await tester.pump();

      // With no pings and no activity, nothing renders.
      expect(find.textContaining('puttar'), findsNothing);
      expect(find.textContaining('min sedan'), findsNothing);
    });

    testWidgets('one un-acked nudge ping renders with message suffix', (
      tester,
    ) async {
      final pings = _FakePingService();
      final repo = _FakeActivityRepo(const []);
      final friends = _friendsWithGroup(me: 'me', memberIds: ['erik']);

      await tester.pumpWidget(
        _wrap(
          ActivityPingsFeed(
            groupId: 'g1',
            pingService: pings,
            activityRepository: repo,
            friendsService: friends,
          ),
        ),
      );

      pings.controller.add([
        _ping(
          id: 'p1',
          from: 'erik',
          type: PingType.nudge,
          message: 'börja laga?',
        ),
      ]);
      await tester.pump();
      await tester.pump();

      // Primary line in Swedish.
      expect(find.text('Erik puttar på dig'), findsOneWidget);
      // Message suffix rendered with the em-dash + quotes wrapper.
      expect(find.text('— "börja laga?"'), findsOneWidget);
    });

    testWidgets('acknowledged pings are filtered out', (tester) async {
      final pings = _FakePingService();
      final repo = _FakeActivityRepo(const []);
      final friends = _friendsWithGroup(me: 'me', memberIds: ['erik']);

      await tester.pumpWidget(
        _wrap(
          ActivityPingsFeed(
            groupId: 'g1',
            pingService: pings,
            activityRepository: repo,
            friendsService: friends,
          ),
        ),
      );

      pings.controller.add([
        _ping(id: 'p1', from: 'erik', acknowledged: true),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Erik puttar på dig'), findsNothing);
    });

    testWidgets('6 items → only top 5 shown (newest first)', (tester) async {
      final pings = _FakePingService();
      final now = DateTime.now();
      final repo = _FakeActivityRepo([
        _activity(
          id: 'a1',
          actor: 'erik',
          type: ActivityEventType.startedCooking,
          at: now.subtract(const Duration(minutes: 60)),
        ),
      ]);
      final friends = _friendsWithGroup(me: 'me', memberIds: ['erik']);

      await tester.pumpWidget(
        _wrap(
          ActivityPingsFeed(
            groupId: 'g1',
            pingService: pings,
            activityRepository: repo,
            friendsService: friends,
          ),
        ),
      );

      // 5 fresh pings — the 60-minute-old activity event must be dropped.
      pings.controller.add([
        for (int i = 0; i < 5; i++)
          _ping(
            id: 'p$i',
            from: 'erik',
            at: now.subtract(Duration(minutes: i)),
          ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Erik puttar på dig'), findsNWidgets(5));
      // The activity event for "started cooking" falls outside the top 5.
      expect(find.textContaining('började laga'), findsNothing);
    });

    testWidgets('tap on un-acked ping → pingService.acknowledge called', (
      tester,
    ) async {
      final pings = _FakePingService();
      final repo = _FakeActivityRepo(const []);
      final friends = _friendsWithGroup(me: 'me', memberIds: ['erik']);

      await tester.pumpWidget(
        _wrap(
          ActivityPingsFeed(
            groupId: 'g1',
            pingService: pings,
            activityRepository: repo,
            friendsService: friends,
          ),
        ),
      );

      pings.controller.add([_ping(id: 'p1', from: 'erik')]);
      await tester.pump();
      await tester.pump();

      // Tap the ping row — ack fires with the matching id.
      await tester.tap(find.byKey(const Key('ping-row-ack')));
      await tester.pump();

      expect(pings.ackCalls, hasLength(1));
      expect(pings.ackCalls.first.pingId, 'p1');
      expect(pings.ackCalls.first.groupId, 'g1');
    });

    testWidgets('addedIngredient activity renders Swedish copy', (
      tester,
    ) async {
      final pings = _FakePingService();
      final now = DateTime.now();
      final repo = _FakeActivityRepo([
        _activity(
          id: 'a1',
          actor: 'sara',
          type: ActivityEventType.addedIngredient,
          extra: const {'ingredient': 'smör'},
          at: now,
        ),
      ]);
      final friends = _friendsWithGroup(me: 'me', memberIds: ['sara']);

      await tester.pumpWidget(
        _wrap(
          ActivityPingsFeed(
            groupId: 'g1',
            pingService: pings,
            activityRepository: repo,
            friendsService: friends,
          ),
        ),
      );

      pings.controller.add(const []);
      // Let the initial activity fetch resolve.
      await tester.pump();
      await tester.pump();

      expect(find.text('Sara lade till smör'), findsOneWidget);
    });

    // BUT-764: regression guard for the BUT-629 lifecycle pause/resume.
    // Without this, a refactor that breaks the lifecycle wiring would
    // silently re-introduce the ~30 fetches/hr cost on backgrounded phones.
    testWidgets('pauses activity polling while app backgrounded', (
      tester,
    ) async {
      final pings = _FakePingService();
      final now = DateTime.now();
      final repo = _FakeActivityRepo([
        _activity(
          id: 'a1',
          actor: 'erik',
          type: ActivityEventType.startedCooking,
          at: now,
        ),
      ]);
      final friends = _friendsWithGroup(me: 'me', memberIds: ['erik']);

      await tester.pumpWidget(
        _wrap(
          ActivityPingsFeed(
            groupId: 'g1',
            pingService: pings,
            activityRepository: repo,
            friendsService: friends,
          ),
        ),
      );

      pings.controller.add(const []);
      // Init fetch has been scheduled — pump twice to flush the microtask.
      await tester.pump();
      await tester.pump();
      expect(repo.fetchCount, 1, reason: 'one fetch on init');

      // App goes background. The 2-min Timer.periodic should be cancelled.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      // Advance well past the 2-min refresh interval. With the timer
      // cancelled, no additional fetch should fire.
      await tester.pump(const Duration(minutes: 5));
      expect(repo.fetchCount, 1, reason: 'no fetch while backgrounded');

      // App returns to foreground. didChangeAppLifecycleState should fire
      // an immediate refresh + restart the periodic timer.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(
        repo.fetchCount,
        2,
        reason: 'one immediate fetch on resume (no stale data)',
      );

      // Advance one full refresh interval — the resumed periodic timer
      // should fire one more fetch.
      await tester.pump(const Duration(minutes: 2));
      expect(
        repo.fetchCount,
        greaterThanOrEqualTo(3),
        reason: 'periodic timer resumed after foreground',
      );

      // Tear down cleanly so the periodic timer doesn't leak into the
      // next test (and to avoid the "Timer is still pending" tester error).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
    });

    testWidgets('startedCooking activity renders Swedish copy', (tester) async {
      final pings = _FakePingService();
      final now = DateTime.now();
      final repo = _FakeActivityRepo([
        _activity(
          id: 'a1',
          actor: 'erik',
          type: ActivityEventType.startedCooking,
          recipeTitle: 'köttbullar',
          at: now,
        ),
      ]);
      final friends = _friendsWithGroup(me: 'me', memberIds: ['erik']);

      await tester.pumpWidget(
        _wrap(
          ActivityPingsFeed(
            groupId: 'g1',
            pingService: pings,
            activityRepository: repo,
            friendsService: friends,
          ),
        ),
      );

      pings.controller.add(const []);
      await tester.pump();
      await tester.pump();

      expect(find.text('Erik började laga köttbullar'), findsOneWidget);
    });
  });
}
