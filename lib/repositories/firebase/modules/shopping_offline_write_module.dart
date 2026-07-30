// lib/repositories/firebase/modules/shopping_offline_write_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';

/// Narrow write payloads for collaborative shopping lists, plus the offline
/// half they were first built for: reading the cached document, deciding
/// whether a mutation is a pure append, and auditing a replay the rules reject.
///
/// BUT-1719 widened the remit past "offline". The reason a queued write may not
/// re-send `ownerId` / `memberPermissions` / `createdAt` — a stale copy of an
/// access-control decision made elsewhere — is not a property of being offline;
/// it is a property of writing fields the caller did not change. The ONLINE
/// whole-list path had the same hole, so the narrowing rule lives here once and
/// both paths use it ([narrowUpdatePayload]).
///
/// Split out of `ShoppingRepositoryRoutingModule` so that module stays a
/// routing facade under the 500-line limit. The rule mirrors that decide
/// WHETHER a caller may write live in `ShoppingListPermissionGuards`; this
/// module only decides WHAT the write says.
class ShoppingOfflineWriteModule {
  /// The three keys `firestore.rules` forbids a non-owner from touching on
  /// `/unified_shared_shopping_lists`. A write that carries one of them is
  /// making an access-control statement, so it needs a base it can vouch for.
  static const Set<String> privilegedKeys = {
    'ownerId',
    'memberPermissions',
    'createdAt',
  };

  /// Document fields an offline write may carry alongside the items it changes.
  ///
  /// Excludes `ownerId`, `memberPermissions` and `createdAt` — the three keys the
  /// Firestore rule forbids a non-owner from touching, so a narrowed write can
  /// never be the reason a replay is rejected, and an owner's queued write can
  /// never re-send a stale access-control decision. That exclusion is ENFORCED,
  /// not merely stated: the payload builders read [_writableActivityKeys].
  static const List<String> _activityFieldKeys = [
    'updatedAt',
    'lastActivityAt',
    'lastActivityByUserId',
    'lastActivityByDisplayName',
  ];

  /// The activity keys a queued write may actually carry.
  ///
  /// BUT-1706: the exclusion above used to live in the doc comment alone, i.e.
  /// in whatever the literal happened to say. Filtering against
  /// [privilegedKeys] here makes the whitelist unable to express an
  /// access-control field at all: adding `ownerId` or `memberPermissions` to the
  /// literal now changes nothing, instead of shipping a queued write that
  /// re-sends a stale ACL (owner: silently overwrites a change made on another
  /// device; non-owner: the rule counts the key as affected and denies the whole
  /// replay, rolling the shopper's ticks back).
  static final List<String> _writableActivityKeys = _activityFieldKeys
      .where((key) => !privilegedKeys.contains(key))
      .toList(growable: false);

  /// Every key an offline payload can actually carry — the items array plus the
  /// activity stamp. A change to anything else is DROPPED by both builders.
  static final Set<String> offlineCarriableKeys = {
    'items',
    ..._writableActivityKeys,
  };

  /// Throws when [mutated] changes a field neither offline payload can carry.
  ///
  /// BUT-1706: this whitelist was documented and unenforced, and its failure
  /// mode is silent. A mutator that appended a row AND renamed the list queued
  /// only the row, handed the caller the renamed object back, and the rename was
  /// gone on the next read — the caller was told the mutation applied. No live
  /// mutator touches anything but items, so this cannot fire today; that is
  /// precisely why it has to be mechanical instead of a comment aimed at
  /// whoever widens `mutateCollaborativeList` next (it takes an arbitrary
  /// mutator and sits on the public repository interface).
  ///
  /// [privilegedKeys] are deliberately NOT part of this refusal. Dropping those
  /// is the designed behaviour, not an accident: a queued write must never
  /// re-send a possibly-stale `ownerId` / `memberPermissions` / `createdAt`
  /// (see [cachedBasePayload]), and two tests pin that strip. Only the fields
  /// whose loss is BOTH silent and unintended land here.
  void requireOfflineWritableMutation(
    UnifiedShoppingList live,
    UnifiedShoppingList mutated,
  ) {
    const equality = DeepCollectionEquality();
    final before = live.toFirestore();
    final after = mutated.toFirestore();
    final dropped =
        after.keys
            .where(
              (key) =>
                  !offlineCarriableKeys.contains(key) &&
                  !privilegedKeys.contains(key),
            )
            .where((key) => !equality.equals(after[key], before[key]))
            .toList()
          ..sort();
    if (dropped.isEmpty) return;

    AppLogger.error(
      'Offline: refused a collaborative-list mutation that changed '
      '${dropped.join(", ")} — the queued payload cannot carry those, so '
      'applying it would report success and lose the change',
    );
    throw ArgumentError.value(
      dropped.join(', '),
      'mutate',
      'An offline collaborative-list mutation can only carry items and the '
          'activity stamp; these changes would be dropped silently',
    );
  }

  /// BUT-1741: the audit sink is asynchronous. Typed `void` this field still
  /// accepted the async implementation and then dropped its future, so a
  /// failing audit write escaped as an unhandled async error rather than one
  /// this module could observe. Each call below is awaited.
  final Future<void> Function({
    required String userId,
    required String resource,
    required String operation,
    required bool granted,
    String? details,
  })
  logPermissionCheck;

  ShoppingOfflineWriteModule({required this.logPermissionCheck});

  /// Reads the locally cached copy, turning "not cached" into the same
  /// [ResourceNotFoundException] the transactional path throws.
  ///
  /// BUT-1696: real Firestore THROWS `unavailable` on a `Source.cache` miss
  /// rather than returning a snapshot with `exists == false`, so the old
  /// `if (!cached.exists)` branch was unreachable in production and an offline
  /// mutation of a never-seen list escaped as a raw [FirebaseException]. Both
  /// shapes are handled here because `fake_cloud_firestore` ignores
  /// `GetOptions.source` and produces the other one.
  Future<DocumentSnapshot<Map<String, dynamic>>> readCachedDoc(
    DocumentReference<Map<String, dynamic>> docRef,
    String listId,
  ) async {
    DocumentSnapshot<Map<String, dynamic>> cached;
    try {
      cached = await docRef.get(const GetOptions(source: Source.cache));
    } on FirebaseException catch (e) {
      throw ResourceNotFoundException(
        'Collaborative shopping list not in the offline cache (${e.code})',
        resourceType: 'collaborative_shopping_list',
        resourceId: listId,
      );
    }
    if (!cached.exists) {
      throw ResourceNotFoundException(
        'Collaborative shopping list not found',
        resourceType: 'collaborative_shopping_list',
        resourceId: listId,
      );
    }
    return cached;
  }

  /// The rows [mutated] adds on top of [live], or null when the mutation is
  /// not a pure append (an existing row changed, moved or disappeared).
  ///
  /// Identity is the serialized row, not the id: a tick rewrites `bought` on a
  /// row whose id is unchanged, and that must NOT qualify as an append.
  List<UnifiedShoppingItem>? appendedItems(
    UnifiedShoppingList live,
    UnifiedShoppingList mutated,
  ) {
    if (mutated.items.length <= live.items.length) return null;
    const equality = DeepCollectionEquality();
    for (var i = 0; i < live.items.length; i++) {
      if (!equality.equals(
        live.items[i].toFirestore(),
        mutated.items[i].toFirestore(),
      )) {
        return null;
      }
    }
    return mutated.items.sublist(live.items.length);
  }

  /// Append-only payload: the new rows unioned in, so a replay merges with
  /// whatever the household did meanwhile instead of replacing it.
  Map<String, Object?> appendPayload(
    UnifiedShoppingList mutated,
    List<UnifiedShoppingItem> appended,
  ) {
    final serialized = mutated.toFirestore();
    return {
      'items': FieldValue.arrayUnion([
        for (final item in appended) item.toFirestore(),
      ]),
      // Non-null only: a mutator that does not stamp activity would otherwise
      // queue three nulls and wipe another member's attribution on the server.
      for (final key in _writableActivityKeys)
        if (serialized[key] != null) key: serialized[key],
    };
  }

  /// Cached-base payload: the whole `items` array, and nothing beyond the
  /// activity fields.
  ///
  /// A whole-document `set(merge: true)` built from the cached base would
  /// re-send `ownerId`, `memberPermissions` and `createdAt` AS CACHED. The rule
  /// compares values (`diff(resource.data).affectedKeys()`), so re-sending an
  /// unchanged copy is harmless — but the moment the cache is STALE for one of
  /// those fields, both outcomes are wrong. For a non-owner the rule counts the
  /// key as affected and denies the entire replay over a field the shopper
  /// never touched, rolling their ticks back. For an owner the rule allows it,
  /// so a permission change made elsewhere while this device was offline is
  /// silently overwritten with the stale copy — a removed member gets their
  /// edit rights back. Sending only `items` plus the activity fields makes the
  /// queued write say exactly what the shopper did.
  ///
  /// The whole array still goes: Firestore has no offline-replayable primitive
  /// for "change element X of this array", which is the residual lost-update
  /// window recorded as an accepted deviation (BUT-1683).
  ///
  /// Consequence worth knowing before you widen the mutator: a change to any
  /// OTHER field — `name`, `description`, `settings`, `categoryIds`,
  /// `allowGuestEditing`, `autoRemoveCompleted` — is silently dropped while the
  /// caller is told the mutation applied. Safe today because every live mutator
  /// only touches items, but `mutateCollaborativeList` takes an arbitrary
  /// mutator and is on the public repository interface.
  Map<String, Object?> cachedBasePayload(UnifiedShoppingList mutated) {
    final serialized = mutated.toFirestore();
    return {
      'items': [for (final item in mutated.items) item.toFirestore()],
      // Non-null only — see the note on [appendPayload].
      for (final key in _writableActivityKeys)
        if (serialized[key] != null) key: serialized[key],
    };
  }

  /// BUT-1719: the keys of [proposed] that actually DIFFER from [stored], as a
  /// payload for `update()`.
  ///
  /// The whole-list path used to write `set(proposed.toFirestore(), merge:
  /// true)`. Two things go wrong with that, and a rename triggers both.
  ///
  /// `merge: true` UNIONS map fields rather than replacing them, so the whole
  /// `memberPermissions` map rode along on every rename — and a key the caller
  /// had dropped was merged straight back in. Removing a member therefore never
  /// actually removed them, and a caller holding a stale copy (an offline cache
  /// outlives a membership change made on another device) re-granted edit
  /// rights to someone who had been removed. [_memberDiff] emits per-key field
  /// paths so both halves of that are impossible.
  ///
  /// And re-sending unchanged fields is not free even when the values match:
  /// the rule compares `diff(resource.data).affectedKeys()`, so a stale copy of
  /// a field the caller never touched either denies the whole write (non-owner)
  /// or silently overwrites someone else's change (owner). Sending only what
  /// changed makes the write say exactly what the caller did.
  ///
  /// An empty result means "nothing to write" — the caller must skip the write
  /// rather than send an empty update.
  ///
  /// [baseIsCached] refuses the write outright when the narrowed payload
  /// touches a [privilegedKeys] field: offline, `stored` is whatever this
  /// device last saw, so "the caller changed memberPermissions" is
  /// indistinguishable from "someone else changed it while we were offline",
  /// and replaying the local answer is exactly how a removed member gets their
  /// edit rights back. Renames and item edits still queue offline; only
  /// membership and ownership wait for a server read.
  Future<Map<String, Object?>> narrowUpdatePayload(
    String uid,
    UnifiedShoppingList proposed,
    UnifiedShoppingList stored, {
    required bool baseIsCached,
  }) async {
    const equality = DeepCollectionEquality();
    final next = proposed.toFirestore();
    final current = stored.toFirestore();
    final payload = <String, Object?>{};

    for (final entry in next.entries) {
      if (entry.key == _memberPermissions) {
        payload.addAll(_memberDiff(entry.value, current[entry.key]));
        continue;
      }
      if (!equality.equals(entry.value, current[entry.key])) {
        payload[entry.key] = entry.value;
      }
    }

    final privileged = payload.keys
        .map((key) => key.split('.').first)
        .where(privilegedKeys.contains)
        .toSet()
        .toList();
    if (privileged.isEmpty || !baseIsCached) return payload;

    await logPermissionCheck(
      userId: uid,
      resource: 'collaborative_shopping_list',
      operation: 'update',
      granted: false,
      details:
          'List: ${proposed.id}, refused ${privileged.join(", ")} change made '
          'against a cached document',
    );
    throw PermissionDeniedException(
      'Changing ${privileged.join(", ")} on collaborative shopping list '
      '${proposed.id} needs a server read; this device is offline',
      resource: 'collaborative_list:${proposed.id}',
      userId: uid,
    );
  }

  static const String _memberPermissions = 'memberPermissions';

  /// The member map as per-key FIELD PATHS rather than one map value.
  ///
  /// Whether a whole-map value merges or replaces depends on the call used to
  /// write it — `set(merge: true)` merges, `update()` replaces — and a removal
  /// silently becomes a no-op if that assumption is ever wrong. Emitting
  /// `memberPermissions.<uid>` per changed key, with `FieldValue.delete()` for
  /// a removed one, says what happened under either call and matches how the
  /// erasure cascade removes the same key server-side.
  Map<String, Object?> _memberDiff(Object? proposed, Object? stored) {
    const equality = DeepCollectionEquality();
    final next = (proposed as Map?)?.cast<String, Object?>() ?? const {};
    final current = (stored as Map?)?.cast<String, Object?>() ?? const {};

    return {
      for (final uid in {...next.keys, ...current.keys})
        if (!equality.equals(next[uid], current[uid]))
          '$_memberPermissions.$uid': next[uid] ?? FieldValue.delete(),
    };
  }

  /// BUT-1696: a replay rejected by the rules is not network noise. Firestore
  /// rolls the local cache back either way, so the audit trail is the only
  /// place the earlier optimistic `granted: true` row gets corrected.
  ///
  /// Scoped to this process: the callback is attached to the future returned by
  /// the queued write, so a replay that happens after the app is killed and
  /// reopened denies with no audit row. Closing that needs a local pending-write
  /// journal reconciled at startup, which is tracked separately.
  Future<void> onReplayRejected(String uid, String listId, Object error) async {
    final denied =
        error is FirebaseException && error.code == 'permission-denied';
    if (denied) {
      await logPermissionCheck(
        userId: uid,
        resource: 'collaborative_shopping_list',
        operation: 'update',
        granted: false,
        details:
            'List: $listId, offline mutation REJECTED on replay by rules — '
            'edit rights were revoked while offline; the local tick has been '
            'rolled back',
      );
    }
    final gone = error is FirebaseException && error.code == 'not-found';
    AppLogger.error(
      denied
          ? 'Queued offline mutation of collaborative list $listId was denied '
                'on replay (permission-denied) — the member no longer has edit '
                'rights'
          : gone
          ? 'Queued offline mutation of collaborative list $listId hit a list '
                'that no longer exists (not-found) — the queued ticks are '
                'dropped rather than recreating a deleted list'
          : 'Queued offline mutation of collaborative list $listId failed on '
                'replay',
      error,
    );
  }
}
