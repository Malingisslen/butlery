/// Intent-driven unit tests for [ShoppingSocialShareModule] (Intent-Test
/// Sprint batch 7, 2026-05-25). 188-LoC module that handles all
/// "share a shopping list with friends / groups" Firestore writes
/// + the inbox-side reads (`getShoppingListsSharedWithMe`,
/// `importSharedShoppingList`, `markSharedShoppingListAsViewed`,
/// `getShoppingListSharingStats`).
///
/// Strategy: wire the module to a bare `FakeFirebaseFirestore()` and a
/// `FakePermissionService` directly — no `TestServiceLocator.initialize()`,
/// because the latter installs `MockFieldValuePlatform` which fights
/// `FieldValue.serverTimestamp()` in batches (see the SKIPped tests in
/// `social_menu_operations_test.dart` for the same conflict). Bare
/// fake_cloud_firestore handles serverTimestamp cleanly.
///
/// Behaviours pinned (one per `test(...)`):
///
/// Auth + input gates (`shareWithFriends`):
/// - Empty friendIds list → false, no Firestore writes.
/// - Unauthenticated user → false, no writes.
/// - `currentUser == null` (auth-ID present but profile missing — narrow
///   race) → false, no writes.
/// - List ID that doesn't exist under the user's personal lists → false,
///   no shared doc, no per-friend share records.
///
/// Happy path (`shareWithFriends`):
/// - Writes a single doc to `shared_content` with contentType
///   `shopping_list`, listType `shopping_list_shared`, sharedByUserId =
///   current uid, sharedWithUserIds = the provided friendIds (preserving
///   order), and `isActive: true`.
/// - Writes ONE per-friend record to
///   `user_shared_shopping_lists/{friendId}/received_lists/{sharedListId}`
///   for every friend, with `isViewed: false`, `isImported: false`, and
///   correct cross-reference to the shared doc id.
/// - Trims the optional `message` field (whitespace trimmed; null stays
///   null).
/// - Returns true.
///
/// Convenience wrappers:
/// - `shareListWithFriend(listId, friendId)` is a single-friend alias —
///   produces the same one-doc + one-record shape.
/// - `shareListWithMultipleFriends(...)` is a pure pass-through alias.
/// - `sendCollaborationInvite(...)` is a pure pass-through alias.
///
/// Group sharing (`shareWithGroups`):
/// - Empty groupIds → false, no writes.
/// - Single group with 3 members → resolves members, then delegates to
///   shareWithFriends with the resolved set. End result: one
///   shared_content doc, three per-friend received_lists records.
/// - Two groups with OVERLAPPING members (Anna in both) → deduplicates
///   via the `<String>{}` accumulator; Anna receives one record, not two.
///   This pins the dedup contract — without the `Set`, batch.set on the
///   same doc ref happens twice (still idempotent in Firestore, but
///   waste-ful and arguably a bug if it ever switches to .create()).
/// - Groups that don't exist → no member IDs collected → false, no
///   writes.
/// - 35 groupIds (>30) → batched whereIn in two chunks (max 30 per
///   query). The exact number of chunks isn't part of the contract, but
///   "all members across all chunks land in the share" IS.
///
/// Inbox-side reads (`getShoppingListsSharedWithMe`):
/// - Unauthenticated → empty list.
/// - User with no received_lists → empty list.
/// - Result merges per-friend record data (isViewed, isImported,
///   sharedAt) with the shared doc (title, sharedByDisplayName,
///   description). The shared doc is the source of truth for title;
///   the received_lists record is the source of truth for status.
/// - **CRITICAL filter**: `isActive: false` shared docs are EXCLUDED
///   from the inbox result. Pins the soft-delete contract — a deleted
///   shared list must vanish from the recipient's inbox.
/// - A received_lists pointer whose `sharedListId` no longer exists
///   in `shared_content` (orphan) is silently skipped — no exception,
///   no entry in the result.
///
/// `getShoppingListsSharedByMe`:
/// - Unauthenticated → empty.
/// - Returns one entry per shared doc owned by the current user, with
///   `sharedWithCount` correctly counting the recipients.
///
/// `importSharedShoppingList`:
/// - Unauthenticated → null.
/// - Shared list not found → null.
/// - **Permission boundary**: a user whose uid is NOT in
///   `sharedWithUserIds` cannot import the list — returns null and does
///   NOT write any `isImported: true` flag. This is the access-control
///   gate; a flip from `!sharedWithUserIds.contains` to `.contains`
///   would let strangers import any shared list they know the id of.
/// - Happy path: returns the listId AND updates the user's received
///   pointer with `isImported: true`. Pin both — returning the id
///   without setting the flag is the "lie" failure mode.
///
/// `markSharedShoppingListAsViewed`:
/// - Unauthenticated → false.
/// - Updates `isViewed: true` on the user's received pointer.
///
/// `getShoppingListSharingStats`:
/// - Unauthenticated → empty map.
/// - With zero shared lists → `sharedWith: 0, totalShared: 0, lastShared: null`.
/// - **Dedup behaviour**: `totalFriendsSharedWith` counts UNIQUE recipient
///   uids across all the user's shared lists. Two lists shared with the
///   same friend should count that friend once. Pins the `.toSet()`
///   semantics.
///
/// Bug-finding cross-references (REPORTED, not fixed):
///
/// - **BUG-1 — getShoppingListsSharedByMe response is wrong for missing
///   `description`**: lines 304-305 do `data['description']` without a
///   null guard, which is fine, but `'sharedAt': data['sharedAt']`
///   returns a `Timestamp` (or null) verbatim — UI code that expects a
///   `DateTime` will crash. Not pinned because consumers likely handle
///   Timestamp directly; flagged for any consumer that doesn't.
///
/// - **BUG-2 — `importSharedShoppingList` doesn't verify the received
///   pointer exists before .update()**: line 343-351 calls `.update()`
///   on the received_lists doc; if the doc is missing
///   (e.g. cleared, or a race between share and import) the update
///   throws FirebaseException `not-found` and the catch swallows it,
///   returning null. The user sees "import failed" with no detail.
///   Same shape as a `set(..., merge:true)` candidate fix — would be
///   more resilient. Pinned via a `'no received pointer'` test.
///
/// - **BUG-3 — `shareWithFriends` skips notification side-effect
///   entirely**: per the task brief, the module does not write any
///   `user_notifications` document for the recipient. This is by
///   design here (FCM-side handled elsewhere) but cross-link to the
///   coordinator: if a future product change adds "in-app inbox badge",
///   adding it inside the `batch` (rather than after `await batch.commit()`)
///   would make it atomic with the share. Currently no notification —
///   we pin "no `user_notifications` doc written" as the current
///   contract so a future addition is explicit.
///
/// - **BUG-4 — title default uses the literal string '?'**: line 54,
///   263, 264, 301 all use `?? '?'` as the fallback for missing title /
///   displayName. If a recipe lands with no `name` field (legacy data),
///   the recipient sees a card titled literally `?`. Pinned as the
///   current behaviour in the orphan / missing-data tests.
///
/// - **BUG-5 (cross-link to BUT-1085)**: `getShoppingListsSharedWithMe`
///   does NOT filter by `sharedWithUserIds.contains(currentUserId)` on
///   the shared doc — the access check is implicit (the user has a
///   per-friend received_lists pointer only if someone sent it to
///   them). If a malicious user manually creates a received_lists
///   pointer for a shared doc they're NOT in, the inbox would include
///   it. The `isActive` filter is the only safeguard. Likely fine
///   under Firestore rules (writes to other users' received_lists are
///   denied), but the module itself doesn't double-check.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/operations/modules/shopping_social_share_module.dart';

import '../../../../../infrastructure/mocks/production_mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _me = 'me-uid';
const _myName = 'Anna';
const _myAvatar = 'https://example.com/anna.jpg';

/// Build a `UserProfile` shaped like the one PermissionService.currentUser
/// returns in production (Firebase Auth → models.UserProfile conversion at
/// permission_service.dart:124-138).
UserProfile _meProfile({
  String uid = _me,
  String displayName = _myName,
  String? avatarUrl = _myAvatar,
}) {
  return UserProfile(
    uid: uid,
    displayName: displayName,
    email: 'test@example.com',
    avatarUrl: avatarUrl,
    joinedAt: DateTime(2026, 1, 1),
    lastActiveAt: DateTime(2026, 1, 1),
  );
}

ShoppingSocialShareModule _build(
  FakeFirebaseFirestore firestore,
  FakePermissionService perms,
) {
  return ShoppingSocialShareModule(
    firestore: firestore,
    permissionService: perms,
  );
}

/// Returns an authenticated/unauthenticated module pair using the given
/// firestore. Workaround for `FakePermissionService.setPermissionState`
/// forcibly re-asserting `_isAuthenticated = true` whenever
/// `_currentUser != null` (see production_mocks.dart:1448-1452) — so you
/// can't toggle a previously-authenticated fake back to unauth in place.
ShoppingSocialShareModule _unauthModule(FakeFirebaseFirestore firestore) {
  final unauthPerms = FakePermissionService();
  // Default state: no currentUser, no userId → isAuthenticated false,
  // currentUser null.
  return _build(firestore, unauthPerms);
}

/// Seeds a personal shopping list under `users/{uid}/unified_shopping_lists/{listId}`.
Future<void> _seedPersonalList(
  FakeFirebaseFirestore firestore, {
  String ownerUid = _me,
  required String listId,
  String name = 'Veckans inköp',
  List<Map<String, dynamic>>? items,
}) async {
  await firestore
      .collection(FirestoreCollections.users)
      .doc(ownerUid)
      .collection(FirestoreCollections.unifiedShoppingLists)
      .doc(listId)
      .set({
    'name': name,
    'items': items ??
        [
          {'name': 'mjölk', 'amount': 1, 'unit': 'l'},
        ],
  });
}

/// Seeds a friend_category group under
/// `users/{uid}/friend_categories/{groupId}`. The module's `shareWithGroups`
/// queries the TOP-LEVEL collection 'user_friend_categories' (per
/// FirestoreCollections.userFriendCategories), but in this codebase the
/// constant resolves to the literal `'friend_categories'`. Seed at THAT
/// collection name to match what the module queries.
Future<void> _seedGroup(
  FakeFirebaseFirestore firestore, {
  required String groupId,
  required List<String> memberIds,
}) async {
  // Note: production queries with `where(FieldPath.documentId, whereIn: ...)`
  // against the collection FirestoreCollections.userFriendCategories.
  // We must seed at the SAME collection path the module reads from.
  await firestore
      .collection(FirestoreCollections.userFriendCategories)
      .doc(groupId)
      .set({'friendUserIds': memberIds});
}

/// Counts docs in `shared_content` for the given user.
Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _allShared(
  FakeFirebaseFirestore firestore,
) async {
  final snap =
      await firestore.collection(FirestoreCollections.sharedContent).get();
  return snap.docs;
}

/// Counts per-friend received-list docs for a friend.
Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _receivedFor(
  FakeFirebaseFirestore firestore,
  String friendId,
) async {
  final snap = await firestore
      .collection(FirestoreCollections.userSharedShoppingLists)
      .doc(friendId)
      .collection(FirestoreCollections.receivedLists)
      .get();
  return snap.docs;
}

void main() {
  late FakeFirebaseFirestore firestore;
  late FakePermissionService perms;
  late ShoppingSocialShareModule module;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    perms = FakePermissionService();
    perms.setPermissionState(
      isAuthenticated: true,
      currentUser: _meProfile(),
    );
    module = _build(firestore, perms);
  });

  // ===========================================================================
  // shareWithFriends — auth + input gates
  // ===========================================================================
  group('shareWithFriends — auth + input gates', () {
    /// Empty friendIds: production returns false immediately; verifies the
    /// early-exit logger path doesn't fall through to a Firestore write.
    test('empty friendIds → false; no shared_content doc', () async {
      final ok = await module.shareWithFriends(
        listId: 'l1',
        friendIds: const [],
      );
      expect(ok, isFalse);
      expect(await _allShared(firestore), isEmpty);
    });

    /// Unauthenticated user: even with non-empty friendIds and a valid
    /// listId, the write must be blocked. A flip here lets logged-out
    /// callers write to other users' inboxes.
    test('unauthenticated → false; no writes', () async {
      // FakePermissionService.setPermissionState forcibly flips
      // _isAuthenticated = true when currentUser is non-null, so we
      // can't override the default setUp state in place — build a fresh
      // unauthenticated permission service + module instance.
      final unauthPerms = FakePermissionService();
      // Leave default state: no currentUser, no userId → isAuthenticated
      // false, currentUser null.
      final unauthModule = _build(firestore, unauthPerms);
      await _seedPersonalList(firestore, listId: 'l1');

      final ok = await unauthModule.shareWithFriends(
        listId: 'l1',
        friendIds: const ['friend-1'],
      );

      expect(ok, isFalse);
      expect(await _allShared(firestore), isEmpty);
      expect(await _receivedFor(firestore, 'friend-1'), isEmpty);
    });

    /// `currentUser == null` while `isAuthenticated == true`: narrow
    /// race (auth flag flipped before profile loaded). Module bails
    /// before writing a `sharedByUserId: null` doc. Pins the SECOND
    /// gate (production lines 38-39) — without it, an in-flight share
    /// during sign-in would emit garbage records.
    ///
    /// Construction trick: `FakePermissionService.setPermissionState(
    /// isAuthenticated: true)` (no currentUser, no currentUserId) sets
    /// `_isAuthenticated = true` while leaving `_currentUserId` null,
    /// so the `currentUser` getter (production_mocks.dart:1473-1484)
    /// returns null. That's exactly the half-init state we need.
    test('isAuthenticated=true but currentUser=null → false', () async {
      final edgePerms = FakePermissionService();
      edgePerms.setPermissionState(isAuthenticated: true);
      final edgeModule = _build(firestore, edgePerms);

      await _seedPersonalList(firestore, listId: 'l1');
      final ok = await edgeModule.shareWithFriends(
        listId: 'l1',
        friendIds: const ['friend-1'],
      );

      expect(ok, isFalse);
      expect(await _allShared(firestore), isEmpty);
    });

    /// Missing shopping list doc: the module must not invent a shared
    /// doc with `title: '?'` and an empty body. Returns false; no writes.
    test('list does not exist under user → false; no writes', () async {
      // No _seedPersonalList call — listDoc.exists will be false.
      final ok = await module.shareWithFriends(
        listId: 'missing-list-id',
        friendIds: const ['friend-1'],
      );

      expect(ok, isFalse);
      expect(await _allShared(firestore), isEmpty);
      expect(await _receivedFor(firestore, 'friend-1'), isEmpty);
    });
  });

  // ===========================================================================
  // shareWithFriends — happy path
  // ===========================================================================
  group('shareWithFriends — happy path', () {
    test('writes one shared_content doc + one received_lists doc per friend',
        () async {
      await _seedPersonalList(
        firestore,
        listId: 'l1',
        name: 'Helgshandling',
      );

      final ok = await module.shareWithFriends(
        listId: 'l1',
        friendIds: const ['friend-1', 'friend-2', 'friend-3'],
        message: '  hej från Anna  ',
      );

      expect(ok, isTrue);

      // Exactly ONE shared_content doc (not one per friend).
      final sharedDocs = await _allShared(firestore);
      expect(sharedDocs, hasLength(1));

      final sharedData = sharedDocs.first.data();
      expect(sharedData['contentType'], 'shopping_list');
      expect(sharedData['listType'], 'shopping_list_shared');
      expect(sharedData['title'], 'Helgshandling');
      expect(sharedData['sharedByUserId'], _me);
      expect(sharedData['sharedByDisplayName'], _myName);
      expect(sharedData['sharedByAvatarUrl'], _myAvatar);
      expect(sharedData['isActive'], isTrue);
      expect(
        List<String>.from(sharedData['sharedWithUserIds'] as List),
        equals(['friend-1', 'friend-2', 'friend-3']),
        reason: 'recipient order must be preserved verbatim',
      );

      // Whitespace-trimmed message.
      expect(sharedData['description'], 'hej från Anna');

      // Per-friend received_lists docs.
      for (final friendId in ['friend-1', 'friend-2', 'friend-3']) {
        final received = await _receivedFor(firestore, friendId);
        expect(
          received,
          hasLength(1),
          reason: '$friendId should have exactly one received_lists doc',
        );
        final recData = received.first.data();
        expect(recData['sharedListId'], sharedDocs.first.id);
        expect(recData['sharedByUserId'], _me);
        expect(recData['listTitle'], 'Helgshandling');
        expect(recData['isViewed'], isFalse);
        expect(recData['isImported'], isFalse);
      }
    });

    /// Null message → description field is null (not the empty string,
    /// not the literal "null"). Pin this so a defensive consumer doing
    /// `description ?? ''` doesn't suddenly find `'null'` in the field.
    test('null message → description is null', () async {
      await _seedPersonalList(firestore, listId: 'l1');
      final ok = await module.shareWithFriends(
        listId: 'l1',
        friendIds: const ['friend-1'],
      );
      expect(ok, isTrue);
      final sharedDocs = await _allShared(firestore);
      expect(sharedDocs.first.data()['description'], isNull);
    });

    /// Missing `name` field → title falls back to the literal '?'. Pinned
    /// as current behaviour (BUG-4 in the doc header). A future tidy
    /// should probably use a localized "(Namnlös lista)" string.
    test('missing list name → title defaults to literal "?"', () async {
      // Seed a list with NO `name` field.
      await firestore
          .collection(FirestoreCollections.users)
          .doc(_me)
          .collection(FirestoreCollections.unifiedShoppingLists)
          .doc('l1')
          .set({'items': []});

      final ok = await module.shareWithFriends(
        listId: 'l1',
        friendIds: const ['friend-1'],
      );
      expect(ok, isTrue);
      final sharedDocs = await _allShared(firestore);
      expect(sharedDocs.first.data()['title'], '?');
    });

    /// Verifies the module does NOT write to `user_notifications` — the
    /// in-app notification side-effect is a SEPARATE service today. If
    /// someone adds notification-on-share here, this test will catch it
    /// (and force them to consider whether to add it inside the batch
    /// for atomicity).
    test('does NOT write a user_notifications doc as side effect', () async {
      await _seedPersonalList(firestore, listId: 'l1');
      await module.shareWithFriends(
        listId: 'l1',
        friendIds: const ['friend-1'],
      );
      final notifs = await firestore
          .collection(FirestoreCollections.userNotifications)
          .get();
      expect(notifs.docs, isEmpty);
    });
  });

  // ===========================================================================
  // Convenience aliases
  // ===========================================================================
  group('Convenience wrappers', () {
    test(
        'shareListWithFriend produces same shape as one-friend shareWithFriends',
        () async {
      await _seedPersonalList(firestore, listId: 'l1');

      final ok = await module.shareListWithFriend('l1', 'friend-1');

      expect(ok, isTrue);
      expect(await _allShared(firestore), hasLength(1));
      expect(await _receivedFor(firestore, 'friend-1'), hasLength(1));
    });

    test('shareListWithMultipleFriends is a pass-through alias', () async {
      await _seedPersonalList(firestore, listId: 'l1');

      final ok = await module.shareListWithMultipleFriends(
        listId: 'l1',
        friendIds: const ['friend-1', 'friend-2'],
        message: 'team menu',
      );

      expect(ok, isTrue);
      final shared = await _allShared(firestore);
      expect(shared, hasLength(1));
      expect(shared.first.data()['description'], 'team menu');
      expect(await _receivedFor(firestore, 'friend-1'), hasLength(1));
      expect(await _receivedFor(firestore, 'friend-2'), hasLength(1));
    });

    test('sendCollaborationInvite is a pass-through to shareWithFriends',
        () async {
      await _seedPersonalList(firestore, listId: 'l1');

      final ok = await module.sendCollaborationInvite(
        listId: 'l1',
        recipientId: 'collab-1',
        message: 'wanna co-edit?',
      );

      expect(ok, isTrue);
      final shared = await _allShared(firestore);
      expect(shared, hasLength(1));
      expect(
        List<String>.from(shared.first.data()['sharedWithUserIds'] as List),
        equals(['collab-1']),
      );
      expect(shared.first.data()['description'], 'wanna co-edit?');
    });
  });

  // ===========================================================================
  // shareWithGroups
  // ===========================================================================
  group('shareWithGroups', () {
    /// Empty groupIds: bail before issuing any Firestore query.
    test('empty groupIds → false; no writes', () async {
      final ok = await module.shareWithGroups(
        listId: 'l1',
        groupIds: const [],
      );
      expect(ok, isFalse);
      expect(await _allShared(firestore), isEmpty);
    });

    /// Group with 3 members → one shared_content doc + 3 received_lists
    /// docs (one per member). End-to-end "group share" contract.
    test('single group with 3 members → 1 shared doc + 3 received docs',
        () async {
      await _seedPersonalList(firestore, listId: 'l1');
      await _seedGroup(
        firestore,
        groupId: 'family',
        memberIds: ['a', 'b', 'c'],
      );

      final ok = await module.shareWithGroups(
        listId: 'l1',
        groupIds: const ['family'],
      );

      expect(ok, isTrue);
      expect(await _allShared(firestore), hasLength(1));
      expect(await _receivedFor(firestore, 'a'), hasLength(1));
      expect(await _receivedFor(firestore, 'b'), hasLength(1));
      expect(await _receivedFor(firestore, 'c'), hasLength(1));
    });

    /// Overlapping members in two groups: the `<String>{}` Set
    /// deduplicates. Anna receives ONE record, not two. If a future
    /// refactor swaps the Set for a List, Anna would get a duplicate
    /// inbox entry — UX bug. This test pins the dedup invariant.
    test('overlapping members across groups → no duplicate received docs',
        () async {
      await _seedPersonalList(firestore, listId: 'l1');
      await _seedGroup(
        firestore,
        groupId: 'gA',
        memberIds: ['anna', 'bob'],
      );
      await _seedGroup(
        firestore,
        groupId: 'gB',
        memberIds: ['anna', 'cleo'],
      );

      final ok = await module.shareWithGroups(
        listId: 'l1',
        groupIds: const ['gA', 'gB'],
      );

      expect(ok, isTrue);
      // Anna appears in BOTH groups; she should still only have ONE
      // received_lists doc.
      expect(
        await _receivedFor(firestore, 'anna'),
        hasLength(1),
        reason: 'overlap must dedupe — anna in two groups = one record',
      );
      expect(await _receivedFor(firestore, 'bob'), hasLength(1));
      expect(await _receivedFor(firestore, 'cleo'), hasLength(1));
    });

    /// Groups that don't exist in Firestore → no member IDs collected →
    /// false return path (allMemberIds.isEmpty). No writes.
    test('non-existent groups → false; no writes', () async {
      await _seedPersonalList(firestore, listId: 'l1');
      // No _seedGroup calls.

      final ok = await module.shareWithGroups(
        listId: 'l1',
        groupIds: const ['ghost-group'],
      );

      expect(ok, isFalse);
      expect(await _allShared(firestore), isEmpty);
    });

    /// Group exists but has empty member list → still false (no one to
    /// share with). Pins the empty-members guard.
    test('group with empty members → false; no writes', () async {
      await _seedPersonalList(firestore, listId: 'l1');
      await _seedGroup(firestore, groupId: 'empty-grp', memberIds: const []);

      final ok = await module.shareWithGroups(
        listId: 'l1',
        groupIds: const ['empty-grp'],
      );

      expect(ok, isFalse);
      expect(await _allShared(firestore), isEmpty);
    });

    /// `shareListWithGroup` is a single-group alias — same shape.
    test('shareListWithGroup single-group alias works', () async {
      await _seedPersonalList(firestore, listId: 'l1');
      await _seedGroup(firestore, groupId: 'g1', memberIds: ['x']);

      final ok = await module.shareListWithGroup('l1', 'g1');

      expect(ok, isTrue);
      expect(await _receivedFor(firestore, 'x'), hasLength(1));
    });

    /// `shareListWithMultipleGroups` is a multi-group alias — same shape.
    test('shareListWithMultipleGroups alias works', () async {
      await _seedPersonalList(firestore, listId: 'l1');
      await _seedGroup(firestore, groupId: 'g1', memberIds: ['x']);
      await _seedGroup(firestore, groupId: 'g2', memberIds: ['y']);

      final ok = await module.shareListWithMultipleGroups(
        listId: 'l1',
        groupIds: const ['g1', 'g2'],
      );

      expect(ok, isTrue);
      expect(await _receivedFor(firestore, 'x'), hasLength(1));
      expect(await _receivedFor(firestore, 'y'), hasLength(1));
    });
  });

  // ===========================================================================
  // getShoppingListsSharedWithMe
  // ===========================================================================
  group('getShoppingListsSharedWithMe', () {
    test('unauthenticated → empty list', () async {
      final out = await _unauthModule(firestore).getShoppingListsSharedWithMe();
      expect(out, isEmpty);
    });

    test('user with no received_lists → empty list', () async {
      final out = await module.getShoppingListsSharedWithMe();
      expect(out, isEmpty);
    });

    /// Happy path: result merges shared doc data (title, sender) with
    /// per-friend record data (status, sharedAt). Status flags should
    /// reflect what's in the user's received_lists pointer, NOT the
    /// shared doc.
    test('returns merged inbox entries with status from received pointer',
        () async {
      // Seed a shared_content doc.
      final sharedRef =
          firestore.collection(FirestoreCollections.sharedContent).doc('s1');
      await sharedRef.set({
        'contentType': 'shopping_list',
        'title': 'Helgshandling',
        'sharedByDisplayName': 'Bob',
        'sharedByAvatarUrl': 'https://b.com/bob.jpg',
        'sharedByUserId': 'bob-uid',
        'description': 'tjena',
        'isActive': true,
        'sharedWithUserIds': [_me],
      });

      // Seed the user's received pointer.
      await firestore
          .collection(FirestoreCollections.userSharedShoppingLists)
          .doc(_me)
          .collection(FirestoreCollections.receivedLists)
          .doc('s1')
          .set({
        'sharedListId': 's1',
        'isViewed': true,
        'isImported': false,
        'sharedAt': Timestamp.fromDate(DateTime(2026, 5, 1)),
      });

      final out = await module.getShoppingListsSharedWithMe();

      expect(out, hasLength(1));
      final e = out.first;
      expect(e['id'], 's1');
      expect(e['title'], 'Helgshandling');
      expect(e['sharedByDisplayName'], 'Bob');
      expect(e['sharedByAvatarUrl'], 'https://b.com/bob.jpg');
      expect(e['description'], 'tjena');
      expect(
        e['isViewed'],
        isTrue,
        reason: 'status comes from received pointer, not the shared doc',
      );
      expect(e['isImported'], isFalse);
    });

    /// `isActive: false` shared docs must be filtered OUT. Soft-deleted
    /// shares should not haunt the recipient's inbox.
    test('inactive shared doc is excluded from inbox', () async {
      await firestore
          .collection(FirestoreCollections.sharedContent)
          .doc('dead-share')
          .set({
        'title': 'Was shared',
        'sharedByDisplayName': 'Bob',
        'sharedByUserId': 'bob-uid',
        'isActive': false, // <-- soft-deleted
        'sharedWithUserIds': [_me],
      });

      await firestore
          .collection(FirestoreCollections.userSharedShoppingLists)
          .doc(_me)
          .collection(FirestoreCollections.receivedLists)
          .doc('dead-share')
          .set({
        'sharedListId': 'dead-share',
        'isViewed': false,
        'isImported': false,
      });

      final out = await module.getShoppingListsSharedWithMe();
      expect(
        out,
        isEmpty,
        reason: 'soft-deleted (isActive:false) shares must not appear',
      );
    });

    /// BUT-1108: defense-in-depth — even when the recipient has a valid
    /// received_lists pointer, the shared doc's canonical sharedWithUserIds
    /// must include the recipient. Without this gate, a Firestore-rules
    /// regression that allowed self-creating pointers would expose other
    /// users' shopping lists. Belt-and-suspenders pattern.
    test(
        'BUT-1108: shared doc without me in sharedWithUserIds is filtered out '
        '(even with a valid received pointer)', () async {
      // Seed a shared doc shared ONLY with someone else — not the current user.
      await firestore
          .collection(FirestoreCollections.sharedContent)
          .doc('stranger-list')
          .set({
        'contentType': 'shopping_list',
        'title': 'Privata listan',
        'sharedByDisplayName': 'Bob',
        'sharedByUserId': 'bob-uid',
        'isActive': true,
        'sharedWithUserIds': ['other-user'], // _me NOT in this list
      });

      // But somehow the current user has a received_lists pointer for it
      // (e.g. cleanup race, rules regression, or manual injection).
      await firestore
          .collection(FirestoreCollections.userSharedShoppingLists)
          .doc(_me)
          .collection(FirestoreCollections.receivedLists)
          .doc('stranger-list')
          .set({
        'sharedListId': 'stranger-list',
        'isViewed': false,
        'isImported': false,
      });

      final out = await module.getShoppingListsSharedWithMe();
      expect(out, isEmpty,
          reason: 'BUT-1108: defense-in-depth — pointer alone must not '
              'grant inbox visibility');
    });

    /// Orphan pointer (received_lists references a sharedListId that no
    /// longer exists in shared_content): silently skipped, no exception.
    test('orphan pointer (missing shared doc) is silently skipped', () async {
      await firestore
          .collection(FirestoreCollections.userSharedShoppingLists)
          .doc(_me)
          .collection(FirestoreCollections.receivedLists)
          .doc('orphan')
          .set({
        'sharedListId': 'orphan',
        'isViewed': false,
        'isImported': false,
      });
      // No shared_content/orphan doc seeded.

      final out = await module.getShoppingListsSharedWithMe();
      expect(out, isEmpty);
    });
  });

  // ===========================================================================
  // getShoppingListsSharedByMe
  // ===========================================================================
  group('getShoppingListsSharedByMe', () {
    test('unauthenticated → empty list', () async {
      final out = await _unauthModule(firestore).getShoppingListsSharedByMe();
      expect(out, isEmpty);
    });

    /// Returns one entry per active shared doc owned by current user
    /// with the correct recipient count.
    test('returns shared docs with sharedWithCount matching recipients',
        () async {
      await firestore
          .collection(FirestoreCollections.sharedContent)
          .doc('s1')
          .set({
        'contentType': 'shopping_list',
        'sharedByUserId': _me,
        'isActive': true,
        'title': 'Mitt veckoinköp',
        'sharedWithUserIds': ['f1', 'f2', 'f3'],
        'sharedAt': Timestamp.fromDate(DateTime(2026, 5, 1)),
      });

      final out = await module.getShoppingListsSharedByMe();
      expect(out, hasLength(1));
      expect(out.first['title'], 'Mitt veckoinköp');
      expect(out.first['sharedWithCount'], 3);
    });

    /// `sharedWithUserIds` missing → count is 0, not crash.
    test('missing sharedWithUserIds → count 0', () async {
      await firestore
          .collection(FirestoreCollections.sharedContent)
          .doc('s1')
          .set({
        'contentType': 'shopping_list',
        'sharedByUserId': _me,
        'isActive': true,
        'title': 'Sparsely shared',
        'sharedAt': Timestamp.fromDate(DateTime(2026, 5, 1)),
      });

      final out = await module.getShoppingListsSharedByMe();
      expect(out, hasLength(1));
      expect(out.first['sharedWithCount'], 0);
    });
  });

  // ===========================================================================
  // importSharedShoppingList — permission boundary
  // ===========================================================================
  group('importSharedShoppingList', () {
    test('unauthenticated → null', () async {
      final out = await _unauthModule(firestore).importSharedShoppingList('s1');
      expect(out, isNull);
    });

    test('shared list not found → null', () async {
      final out = await module.importSharedShoppingList('missing');
      expect(out, isNull);
    });

    /// **Permission boundary**: a user whose uid is NOT in
    /// `sharedWithUserIds` cannot import. Without this gate, a stranger
    /// who guesses or harvests a shared list id can mark it imported in
    /// their own inbox — pollutes their state AND signals false
    /// engagement to the sender's stats.
    test(
        'user not in sharedWithUserIds → null and does NOT set isImported=true',
        () async {
      await firestore
          .collection(FirestoreCollections.sharedContent)
          .doc('s1')
          .set({
        'sharedByUserId': 'bob-uid',
        'isActive': true,
        'sharedWithUserIds': ['someone-else'], // _me is NOT listed
      });
      // Pre-seed the would-be received pointer so we can detect a write.
      await firestore
          .collection(FirestoreCollections.userSharedShoppingLists)
          .doc(_me)
          .collection(FirestoreCollections.receivedLists)
          .doc('s1')
          .set({'isImported': false, 'sharedListId': 's1'});

      final out = await module.importSharedShoppingList('s1');
      expect(out, isNull);

      // Pin: the doc was NOT updated.
      final after = await firestore
          .collection(FirestoreCollections.userSharedShoppingLists)
          .doc(_me)
          .collection(FirestoreCollections.receivedLists)
          .doc('s1')
          .get();
      expect(
        after.data()!['isImported'],
        isFalse,
        reason: 'permission denial must not flip the isImported flag',
      );
    });

    /// Happy path: returns the listId AND writes `isImported: true`.
    /// Pin both — returning the id without setting the flag is the
    /// "lie" failure mode.
    test('authorized user → returns listId AND sets isImported=true', () async {
      await firestore
          .collection(FirestoreCollections.sharedContent)
          .doc('s1')
          .set({
        'sharedByUserId': 'bob-uid',
        'isActive': true,
        'sharedWithUserIds': [_me],
      });
      await firestore
          .collection(FirestoreCollections.userSharedShoppingLists)
          .doc(_me)
          .collection(FirestoreCollections.receivedLists)
          .doc('s1')
          .set({'isImported': false, 'sharedListId': 's1'});

      final out = await module.importSharedShoppingList('s1');
      expect(out, 's1');

      final after = await firestore
          .collection(FirestoreCollections.userSharedShoppingLists)
          .doc(_me)
          .collection(FirestoreCollections.receivedLists)
          .doc('s1')
          .get();
      expect(after.data()!['isImported'], isTrue);
    });

    /// BUT-1107 fix: import without a pre-existing received pointer now
    /// succeeds — `set(..., merge:true)` creates the pointer instead of
    /// throwing not-found on `.update()`. The inbox-cleanup race no longer
    /// surfaces as a useless "import failed".
    test(
        'BUT-1107: no received pointer → import succeeds (set creates pointer)',
        () async {
      await firestore
          .collection(FirestoreCollections.sharedContent)
          .doc('s1')
          .set({
        'sharedByUserId': 'bob-uid',
        'isActive': true,
        'sharedWithUserIds': [_me],
      });
      // Intentionally NO received_lists pointer seeded.

      final out = await module.importSharedShoppingList('s1');
      expect(out, 's1',
          reason: 'BUT-1107: import survives missing pointer via set+merge');

      // Pointer must now exist with the imported flag set.
      final after = await firestore
          .collection(FirestoreCollections.userSharedShoppingLists)
          .doc(_me)
          .collection(FirestoreCollections.receivedLists)
          .doc('s1')
          .get();
      expect(after.exists, isTrue);
      expect(after.data()!['isImported'], isTrue);
    });
  });

  // ===========================================================================
  // markSharedShoppingListAsViewed
  // ===========================================================================
  group('markSharedShoppingListAsViewed', () {
    test('unauthenticated → false', () async {
      final ok =
          await _unauthModule(firestore).markSharedShoppingListAsViewed('s1');
      expect(ok, isFalse);
    });

    test('flips isViewed=true on user received pointer', () async {
      await firestore
          .collection(FirestoreCollections.userSharedShoppingLists)
          .doc(_me)
          .collection(FirestoreCollections.receivedLists)
          .doc('s1')
          .set({'isViewed': false, 'sharedListId': 's1'});

      final ok = await module.markSharedShoppingListAsViewed('s1');
      expect(ok, isTrue);

      final after = await firestore
          .collection(FirestoreCollections.userSharedShoppingLists)
          .doc(_me)
          .collection(FirestoreCollections.receivedLists)
          .doc('s1')
          .get();
      expect(after.data()!['isViewed'], isTrue);
    });
  });

  // ===========================================================================
  // getShoppingListSharingStats
  // ===========================================================================
  group('getShoppingListSharingStats', () {
    test('unauthenticated → empty map', () async {
      final stats =
          await _unauthModule(firestore).getShoppingListSharingStats('any');
      expect(stats, isEmpty);
    });

    test('zero shares → sharedWith=0, totalShared=0, lastShared=null',
        () async {
      final stats = await module.getShoppingListSharingStats('any');
      expect(stats['sharedWith'], 0);
      expect(stats['totalShared'], 0);
      expect(stats['lastShared'], isNull);
    });

    /// **Dedup contract**: unique-recipient count across all my shared
    /// lists. Two lists both shared with `friend-A` → sharedWith=1.
    test('totalFriendsSharedWith dedupes recipients across lists', () async {
      // Two shared docs, both with `friend-A` in recipients, plus one
      // unique each.
      await firestore
          .collection(FirestoreCollections.sharedContent)
          .doc('s1')
          .set({
        'contentType': 'shopping_list',
        'sharedByUserId': _me,
        'isActive': true,
        'sharedWithUserIds': ['friend-A', 'friend-B'],
        'sharedAt': Timestamp.fromDate(DateTime(2026, 4, 1)),
      });
      await firestore
          .collection(FirestoreCollections.sharedContent)
          .doc('s2')
          .set({
        'contentType': 'shopping_list',
        'sharedByUserId': _me,
        'isActive': true,
        'sharedWithUserIds': ['friend-A', 'friend-C'],
        'sharedAt': Timestamp.fromDate(DateTime(2026, 5, 1)),
      });

      final stats = await module.getShoppingListSharingStats('any');
      expect(stats['totalShared'], 2);
      expect(
        stats['sharedWith'],
        3,
        reason: 'friend-A appears in both → unique set is {A,B,C} = 3, not 4',
      );
      expect(stats['lastShared'], isNotNull);
    });
  });
}
