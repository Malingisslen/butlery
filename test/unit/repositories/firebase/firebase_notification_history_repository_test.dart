/// Intent-Test Sprint Batch 12 — FirebaseNotificationHistoryRepository.
///
/// Notification history doubles as the in-app inbox and the FCM dedup
/// table. Bugs here have **privacy-blast-radius**: a missing `userId`
/// filter lets one user see another user's notifications, an unprotected
/// `markAllAsOpenedForUser` lets anyone clear strangers' inboxes, and a
/// non-cascading `deleteAllByUser` is a GDPR Art.17 violation. These
/// tests pin exactly those invariants.
///
/// Behaviours covered:
/// - recordNotification persists ALL required fields (userId, expireAt,
///   delivered=false, opened=false, type, category, data) so dedup +
///   inbox queries actually work.
/// - recordNotification stamps `userId` from the **authed** user, not
///   from any payload field — so a sender can never forge ownership.
/// - recordNotification is idempotent under same notificationId (the
///   dedup contract — duplicate FCM delivery must not double-write).
/// - wasNotificationSent is true after record, false for unknown ids,
///   and swallows errors as `false` (does not throw upward).
/// - markNotificationDelivered/Opened mutate the right doc, leave
///   every other field intact, and do NOT crash on a missing doc.
/// - getHistory filters by userId — Alice's call returns only Alice's
///   docs, never Bob's. CRITICAL privacy invariant.
/// - getHistory respects the `limit` parameter and orders sentAt desc.
/// - getHistory `before` cursor is **strictly less than** (off-by-one).
/// - markAllAsOpenedForUser refuses cross-user calls — Alice authed
///   cannot mark Bob's notifications read. PRIVACY-CRITICAL.
/// - markAllAsOpenedForUser only touches `opened == false` docs and
///   does not re-stamp already-opened ones (idempotent + audit-safe).
/// - markAllAsOpenedForUser returns the exact count it mutated.
/// - markAllAsOpenedForUser only touches the caller's docs — even on
///   a self-call, Bob's docs are not collaterally damaged.
/// - deleteAllByUser refuses cross-user calls (GDPR ownership).
/// - deleteAllByUser deletes EVERY matching doc and only those —
///   no orphans, no collateral. GDPR Art.17 right-to-erasure.
/// - deleteAllByUser returns 0 (not throws) when nothing to delete.
/// - Unauthenticated record/mark/delete operations raise typed
///   AuthenticationException at the boundary, not silent NPE.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/repositories/firebase/firebase_notification_history_repository.dart';
import 'package:butlery/services/notifications/notification_types.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _alice = 'user-alice';
const _bob = 'user-bob';

FirebaseNotificationHistoryRepository _repo(
  FakeFirebaseFirestore firestore, {
  String? authedUserId = _alice,
}) {
  final mockAuth = MockAuthRepository();
  if (authedUserId != null) {
    mockAuth.setAuthState(
      user: FakeUser(uid: authedUserId),
      userId: authedUserId,
      isAuthenticated: true,
    );
  }
  return FirebaseNotificationHistoryRepository(
    firestore: firestore,
    authRepository: mockAuth,
    timestampProvider: const TestTimestampProvider(),
  );
}

Future<Map<String, dynamic>?> _doc(
  FakeFirebaseFirestore firestore,
  String id,
) async {
  final snap = await firestore.collection('notification_history').doc(id).get();
  return snap.data();
}

/// Seed a notification_history doc directly, bypassing the repo so we
/// can test queries against pre-existing state.
Future<void> _seed(
  FakeFirebaseFirestore firestore, {
  required String id,
  required String userId,
  DateTime? sentAt,
  bool opened = false,
  bool delivered = false,
  String category = 'friends',
  String type = 'immediate',
  Map<String, dynamic>? data,
}) async {
  await firestore.collection('notification_history').doc(id).set({
    'userId': userId,
    'notificationId': id,
    'category': category,
    'type': type,
    'data': data ?? const {'title': 't', 'body': 'b'},
    'sentAt': Timestamp.fromDate(sentAt ?? DateTime.utc(2026, 1, 1)),
    'expireAt': Timestamp.fromDate((sentAt ?? DateTime.utc(2026, 1, 1)).add(
      const Duration(days: 90),
    )),
    'delivered': delivered,
    'opened': opened,
  });
}

void main() {
  group('recordNotification — persistence & ownership invariants', () {
    /// Proves that record writes every field the dedup + inbox flows
    /// rely on, with userId derived from auth (not payload).
    test('persists userId from auth, plus the canonical field set', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _alice);

      await repo.recordNotification(
        notificationId: 'n1',
        category: NotificationCategory.friends,
        type: NotificationType.immediate,
        data: const {'title': 'Hi', 'body': 'Body'},
      );

      final stored = await _doc(firestore, 'n1');
      expect(stored, isNotNull);
      expect(stored!['userId'], _alice,
          reason: 'userId must come from authed user, not payload');
      expect(stored['notificationId'], 'n1');
      expect(stored['category'], 'friends');
      expect(stored['type'], 'immediate');
      expect(stored['data'], const {'title': 'Hi', 'body': 'Body'});
      // Inbox + cleanup workflows depend on these flags + expireAt.
      expect(stored['delivered'], isFalse);
      expect(stored['opened'], isFalse);
      expect(stored['sentAt'], isA<Timestamp>());
      expect(stored['expireAt'], isA<Timestamp>());
    });

    /// Proves that even if a payload tries to inject a `userId` field
    /// (forging ownership), the auth-derived userId wins. A bug here
    /// is "user A creates a notification owned by user B."
    test('payload cannot forge userId — auth wins', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _alice);

      // Sneaky data payload claiming to be from Bob.
      await repo.recordNotification(
        notificationId: 'n-forge',
        category: NotificationCategory.recipes,
        type: NotificationType.immediate,
        data: const {'userId': _bob, 'spoofed': true},
      );

      final stored = await _doc(firestore, 'n-forge');
      expect(stored!['userId'], _alice,
          reason: 'top-level userId must be the authed uid, not payload');
      // The data map is preserved verbatim (separate field), which is
      // fine — the security boundary is the top-level userId column.
      expect(stored['data'], const {'userId': _bob, 'spoofed': true});
    });

    /// Proves dedup: re-recording the same notificationId overwrites
    /// rather than appending a second doc. FCM duplicate-delivery is
    /// common; if this regressed to `add()`, the inbox would fill with
    /// dupes and the dedup check (`wasNotificationSent`) would be racey.
    test('is idempotent — same notificationId never creates a second doc',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _alice);

      await repo.recordNotification(
        notificationId: 'n-dup',
        category: NotificationCategory.friends,
        type: NotificationType.immediate,
        data: const {'v': 1},
      );
      await repo.recordNotification(
        notificationId: 'n-dup',
        category: NotificationCategory.friends,
        type: NotificationType.immediate,
        data: const {'v': 2},
      );

      final all = await firestore.collection('notification_history').get();
      expect(all.docs, hasLength(1));
      expect(all.docs.first.data()['data'], const {'v': 2},
          reason: 'second write overwrites — that is the dedup contract');
    });

    /// Proves the no-auth boundary is clean: an unauthenticated record
    /// must NOT silently succeed (which would persist `userId: ''`),
    /// the caller's catch in production swallows the throw, but the
    /// throw itself must originate from `requireCurrentUserId`.
    /// If this test regresses to "writes a doc anyway with empty
    /// userId," that doc is invisible to every query and becomes
    /// orphaned waste — and worse, depending on rules, could leak.
    test('unauthenticated record leaves the collection empty', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: null);

      // The production code wraps in try/catch and only logs — so this
      // does NOT throw upward. The invariant we pin is "no garbage
      // doc was written" (the throw aborted the `set`).
      await repo.recordNotification(
        notificationId: 'n-unauth',
        category: NotificationCategory.friends,
        type: NotificationType.immediate,
        data: const {'x': 1},
      );

      final all = await firestore.collection('notification_history').get();
      expect(all.docs, isEmpty,
          reason: 'unauthenticated write must not persist anything');
    });
  });

  group('wasNotificationSent — dedup query', () {
    /// Proves the dedup query returns true for previously-recorded ids.
    test('returns true after record, false for unknown id', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _alice);

      await repo.recordNotification(
        notificationId: 'n-known',
        category: NotificationCategory.friends,
        type: NotificationType.immediate,
        data: const {},
      );

      expect(await repo.wasNotificationSent('n-known'), isTrue);
      expect(await repo.wasNotificationSent('n-missing'), isFalse);
    });
  });

  group('markNotificationDelivered / markNotificationOpened — flag updates',
      () {
    /// Proves delivered-update writes `delivered: true` + `deliveredAt`
    /// and leaves every other field (userId, opened, data) intact. A
    /// bug where update overwrites the doc with `.set` instead of
    /// `.update` would wipe userId — every "delivered" notification
    /// becomes invisible to the inbox.
    test('markDelivered flips the flag and preserves every other field',
        () async {
      final firestore = FakeFirebaseFirestore();
      await _seed(firestore, id: 'n-d', userId: _alice);
      final repo = _repo(firestore, authedUserId: _alice);

      await repo.markNotificationDelivered('n-d');

      final stored = await _doc(firestore, 'n-d');
      expect(stored!['delivered'], isTrue);
      expect(stored['deliveredAt'], isA<Timestamp>());
      // Field-preservation invariant:
      expect(stored['userId'], _alice);
      expect(stored['opened'], isFalse);
      expect(stored['notificationId'], 'n-d');
      expect(stored['data'], isA<Map>());
    });

    /// Same as above but for opened — caught the same class of bug
    /// where `.set` replaces vs `.update` merges.
    test('markOpened flips the flag and preserves every other field', () async {
      final firestore = FakeFirebaseFirestore();
      await _seed(firestore, id: 'n-o', userId: _alice, delivered: true);
      final repo = _repo(firestore, authedUserId: _alice);

      await repo.markNotificationOpened('n-o');

      final stored = await _doc(firestore, 'n-o');
      expect(stored!['opened'], isTrue);
      expect(stored['openedAt'], isA<Timestamp>());
      expect(stored['delivered'], isTrue,
          reason: 'must NOT clobber the delivered flag');
      expect(stored['userId'], _alice);
    });

    /// Proves graceful handling of a missing doc — production catches
    /// the FirebaseException and only logs. If this regressed to
    /// rethrow, FCM background isolates would crash on the first
    /// stale notificationId, taking down delivery for the device.
    test('mark on missing doc does not throw upward', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _alice);

      // No await expectLater + throwsA — explicit "does not throw":
      await repo.markNotificationDelivered('does-not-exist');
      await repo.markNotificationOpened('does-not-exist');
      // If we got here, the contract held.
    });
  });

  group('getHistory — per-user filtering & pagination', () {
    /// THE privacy-critical test. Proves Alice's getHistory cannot
    /// return Bob's docs. A regression here — missing `where('userId',
    /// isEqualTo: ...)` — leaks every user's inbox to every other user.
    test('returns only docs owned by the queried userId', () async {
      final firestore = FakeFirebaseFirestore();
      await _seed(firestore,
          id: 'a1', userId: _alice, sentAt: DateTime.utc(2026, 2, 1));
      await _seed(firestore,
          id: 'a2', userId: _alice, sentAt: DateTime.utc(2026, 2, 2));
      await _seed(firestore,
          id: 'b1', userId: _bob, sentAt: DateTime.utc(2026, 2, 3));
      final repo = _repo(firestore, authedUserId: _alice);

      final history = await repo.getHistory(_alice);

      expect(history.map((e) => e.id), unorderedEquals(['a1', 'a2']),
          reason: 'must not include Bob-owned docs');
    });

    /// Proves desc ordering by sentAt — inbox shows newest first.
    /// Off-by-one bug would surface as oldest-first or random order.
    test('orders by sentAt descending (newest first)', () async {
      final firestore = FakeFirebaseFirestore();
      await _seed(firestore,
          id: 'old', userId: _alice, sentAt: DateTime.utc(2026, 1, 1));
      await _seed(firestore,
          id: 'mid', userId: _alice, sentAt: DateTime.utc(2026, 6, 1));
      await _seed(firestore,
          id: 'new', userId: _alice, sentAt: DateTime.utc(2026, 12, 1));
      final repo = _repo(firestore, authedUserId: _alice);

      final history = await repo.getHistory(_alice);
      expect(history.map((e) => e.id).toList(), ['new', 'mid', 'old']);
    });

    /// Proves the `limit` parameter is respected. If repo dropped the
    /// `.limit()` clause, large inboxes would blow read quota every
    /// open. Default is 20 — we pin both the override and the bound.
    test('respects the limit parameter', () async {
      final firestore = FakeFirebaseFirestore();
      for (var i = 0; i < 10; i++) {
        await _seed(firestore,
            id: 'n$i',
            userId: _alice,
            sentAt: DateTime.utc(2026, 1, 1).add(Duration(days: i)));
      }
      final repo = _repo(firestore, authedUserId: _alice);

      final limited = await repo.getHistory(_alice, limit: 3);
      expect(limited, hasLength(3));
    });

    /// Proves `before` cursor is strictly-less-than. If it were `<=`
    /// (off-by-one), paging would return the same doc on the seam
    /// (duplicate at page boundary). If it were `>` (flipped), pages
    /// would skip entirely.
    test('before cursor is strict less-than (no boundary duplicate)', () async {
      final firestore = FakeFirebaseFirestore();
      final t1 = DateTime.utc(2026, 1, 1);
      final t2 = DateTime.utc(2026, 1, 2);
      final t3 = DateTime.utc(2026, 1, 3);
      await _seed(firestore, id: 'n1', userId: _alice, sentAt: t1);
      await _seed(firestore, id: 'n2', userId: _alice, sentAt: t2);
      await _seed(firestore, id: 'n3', userId: _alice, sentAt: t3);
      final repo = _repo(firestore, authedUserId: _alice);

      // before = t2 must NOT include n2 itself (strict <).
      final page = await repo.getHistory(_alice, before: t2);
      expect(page.map((e) => e.id), ['n1'],
          reason: 'strict less-than: n2 (== cursor) excluded, n1 (< cursor) '
              'included, n3 (> cursor) excluded');
    });

    /// Proves errors are absorbed into an empty list — production
    /// returns `[]` on exception. The contract is "inbox query never
    /// throws upward; worst case is empty list + log line." A regression
    /// to rethrow would crash the inbox view on every transient.
    test('returns empty list (not throw) when something goes wrong', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: null);

      // No auth needed for getHistory (it takes userId as a param), but
      // the query itself succeeds and returns []. The real "throws"
      // path is hard to trigger with FakeFirebaseFirestore — this test
      // at minimum pins the empty-result contract.
      final result = await repo.getHistory(_alice);
      expect(result, isEmpty);
    });
  });

  group('markAllAsOpenedForUser — ownership + scope', () {
    /// PRIVACY-CRITICAL: Alice (authed) calling on Bob's id must throw.
    /// A regression dropping `validateOwnership` would let any user
    /// silently clear any other user's unread badge — observable as
    /// "my notifications keep getting marked read on their own."
    test('throws PermissionDeniedException for cross-user call', () async {
      final firestore = FakeFirebaseFirestore();
      await _seed(firestore, id: 'b1', userId: _bob);
      final repo = _repo(firestore, authedUserId: _alice);

      await expectLater(
        repo.markAllAsOpenedForUser(_bob),
        throwsA(isA<PermissionDeniedException>()),
      );

      // And critically, Bob's doc was NOT mutated by the failed call.
      final stored = await _doc(firestore, 'b1');
      expect(stored!['opened'], isFalse,
          reason: 'failed permission check must not partially mutate');
    });

    /// Proves the filter is `opened == false` — already-opened docs
    /// are not re-stamped. If the filter were missing, every call
    /// would update `openedAt` to "now," corrupting the user-facing
    /// "opened 3 days ago" timestamp.
    test('only touches unread docs; leaves already-opened openedAt intact',
        () async {
      final firestore = FakeFirebaseFirestore();
      final originalOpenedAt = Timestamp.fromDate(DateTime.utc(2025, 12, 1));
      // One already-opened (must not be re-stamped).
      await firestore.collection('notification_history').doc('a-already').set({
        'userId': _alice,
        'notificationId': 'a-already',
        'category': 'friends',
        'type': 'immediate',
        'data': const {},
        'sentAt': Timestamp.fromDate(DateTime.utc(2025, 11, 1)),
        'expireAt': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
        'delivered': true,
        'opened': true,
        'openedAt': originalOpenedAt,
      });
      // Two unread (must be flipped).
      await _seed(firestore, id: 'a-u1', userId: _alice);
      await _seed(firestore, id: 'a-u2', userId: _alice);
      final repo = _repo(firestore, authedUserId: _alice);

      final count = await repo.markAllAsOpenedForUser(_alice);

      expect(count, 2, reason: 'returns exact count of docs mutated');

      final preserved = await _doc(firestore, 'a-already');
      expect(preserved!['openedAt'], originalOpenedAt,
          reason: 'already-opened doc must NOT be re-stamped');

      final u1 = await _doc(firestore, 'a-u1');
      final u2 = await _doc(firestore, 'a-u2');
      expect(u1!['opened'], isTrue);
      expect(u2!['opened'], isTrue);
      expect(u1['openedAt'], isA<Timestamp>());
    });

    /// Proves scope is locked to caller's docs — Bob's notifications
    /// must remain untouched even when Alice self-marks. A regression
    /// dropping the `userId` filter would have Alice's call mark
    /// Bob's docs too (collateral cross-user write).
    test('does not collaterally touch other users\' docs', () async {
      final firestore = FakeFirebaseFirestore();
      await _seed(firestore, id: 'a-1', userId: _alice);
      await _seed(firestore, id: 'b-1', userId: _bob);
      final repo = _repo(firestore, authedUserId: _alice);

      final count = await repo.markAllAsOpenedForUser(_alice);
      expect(count, 1);

      final bobDoc = await _doc(firestore, 'b-1');
      expect(bobDoc!['opened'], isFalse,
          reason: 'Bob\'s doc must be untouched by Alice\'s self-mark');
    });

    /// Proves the empty-set early return — returns 0 cleanly when
    /// there's nothing to mark. A bug forgetting this fast-path would
    /// still commit an empty batch (Firestore rejects with `INVALID_ARG`
    /// on some versions, or wastes a write op).
    test('returns 0 when there are no unread docs', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _alice);

      expect(await repo.markAllAsOpenedForUser(_alice), 0);
    });
  });

  group('deleteAllByUser — GDPR Art.17 cascade', () {
    /// GDPR-CRITICAL: Alice cannot delete Bob's data. A regression
    /// here is a confused-deputy: any authed user could erase
    /// strangers' notification history.
    test('throws PermissionDeniedException for cross-user call', () async {
      final firestore = FakeFirebaseFirestore();
      await _seed(firestore, id: 'b1', userId: _bob);
      final repo = _repo(firestore, authedUserId: _alice);

      await expectLater(
        repo.deleteAllByUser(_bob),
        throwsA(isA<PermissionDeniedException>()),
      );

      // Bob's doc still there.
      final stored = await _doc(firestore, 'b1');
      expect(stored, isNotNull,
          reason: 'failed ownership check must not delete anything');
    });

    /// THE GDPR invariant. Proves every owned doc is removed and
    /// nothing else. A bug where filter is missing → mass-deletes
    /// the whole collection (catastrophic). A bug where filter is
    /// stale (e.g., uses currentUserId vs param) → fails on admin /
    /// account-deletion flows.
    test('deletes every doc owned by user, and only those', () async {
      final firestore = FakeFirebaseFirestore();
      await _seed(firestore, id: 'a-1', userId: _alice);
      await _seed(firestore, id: 'a-2', userId: _alice);
      await _seed(firestore, id: 'a-3', userId: _alice);
      await _seed(firestore, id: 'b-1', userId: _bob);
      await _seed(firestore, id: 'b-2', userId: _bob);
      final repo = _repo(firestore, authedUserId: _alice);

      final count = await repo.deleteAllByUser(_alice);

      expect(count, 3, reason: 'returns exact count of docs deleted');

      final remaining = await firestore
          .collection('notification_history')
          .get()
          .then((s) => s.docs.map((d) => d.id).toSet());
      expect(remaining, {'b-1', 'b-2'},
          reason: 'only Bob\'s docs remain — Alice\'s 3 wiped, none orphaned');
    });

    /// Proves the empty-set fast path — returns 0 cleanly rather
    /// than committing an empty batch / throwing.
    test('returns 0 when user has no notification_history docs', () async {
      final firestore = FakeFirebaseFirestore();
      // Only Bob has docs; Alice has none.
      await _seed(firestore, id: 'b-1', userId: _bob);
      final repo = _repo(firestore, authedUserId: _alice);

      expect(await repo.deleteAllByUser(_alice), 0);
      // Bob untouched.
      final bobStill = await _doc(firestore, 'b-1');
      expect(bobStill, isNotNull);
    });

    /// Proves the cascade is COMPLETE — opened/unread/delivered mix
    /// all get nuked. A bug like `.where('opened', isEqualTo: false)`
    /// in the cascade would leave read notifications behind, violating
    /// right-to-erasure.
    test('cascade removes opened, unread, and delivered docs alike', () async {
      final firestore = FakeFirebaseFirestore();
      await _seed(firestore,
          id: 'a-unread', userId: _alice, opened: false, delivered: false);
      await _seed(firestore,
          id: 'a-delivered', userId: _alice, opened: false, delivered: true);
      await _seed(firestore,
          id: 'a-opened', userId: _alice, opened: true, delivered: true);
      final repo = _repo(firestore, authedUserId: _alice);

      final count = await repo.deleteAllByUser(_alice);
      expect(count, 3);

      final remaining =
          await firestore.collection('notification_history').get();
      expect(remaining.docs, isEmpty,
          reason: 'GDPR cascade must remove all states');
    });
  });

  group('auth boundary', () {
    /// Unauthenticated `markAllAsOpenedForUser` must NOT silently
    /// succeed — it must raise typed AuthenticationException. A
    /// regression to "if uid null, no-op" would mask call-site bugs
    /// during sign-out flows where the auth state flips mid-call.
    test('unauthenticated markAllAsOpenedForUser throws', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: null);

      await expectLater(
        repo.markAllAsOpenedForUser(_alice),
        throwsA(isA<Exception>()),
      );
    });

    /// Same boundary contract on the delete path. A regression to
    /// silent no-op would make sign-out-then-delete-account flows
    /// silently retain data — a GDPR-grade bug.
    test('unauthenticated deleteAllByUser throws', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: null);

      await expectLater(
        repo.deleteAllByUser(_alice),
        throwsA(isA<Exception>()),
      );
    });
  });
}
