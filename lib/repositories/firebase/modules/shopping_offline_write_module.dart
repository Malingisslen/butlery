// lib/repositories/firebase/modules/shopping_offline_write_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';

/// The offline half of collaborative shopping-list writes: reading the cached
/// document, deciding whether a mutation is a pure append, building the narrow
/// payload that gets queued, and auditing a replay the rules reject.
///
/// Split out of `ShoppingRepositoryRoutingModule` so that module stays a
/// routing facade under the 500-line limit. The guards (edit rights, privilege
/// escalation) deliberately stay with the routing module: they apply to the
/// online path too, and a guard that lives next to only one caller is a guard
/// waiting to be forgotten.
class ShoppingOfflineWriteModule {
  /// Document fields an offline write may carry alongside the items it changes.
  ///
  /// Deliberately excludes `ownerId`, `memberPermissions` and `createdAt` — the
  /// three keys the Firestore rule forbids a non-owner from touching, so a
  /// narrowed write can never be the reason a replay is rejected, and an
  /// owner's queued write can never re-send a stale access-control decision.
  static const List<String> _activityFieldKeys = [
    'updatedAt',
    'lastActivityAt',
    'lastActivityByUserId',
    'lastActivityByDisplayName',
  ];

  final void Function({
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
      for (final key in _activityFieldKeys)
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
      for (final key in _activityFieldKeys)
        if (serialized[key] != null) key: serialized[key],
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
  void onReplayRejected(String uid, String listId, Object error) {
    final denied =
        error is FirebaseException && error.code == 'permission-denied';
    if (denied) {
      logPermissionCheck(
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
