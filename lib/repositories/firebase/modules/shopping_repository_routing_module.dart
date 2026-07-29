// lib/repositories/firebase/modules/shopping_repository_routing_module.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/modules/shopping_list_permission_guards.dart';
import 'package:butlery/repositories/firebase/modules/shopping_offline_write_module.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';

/// Runs the collaborative-list transaction. Production binds this to
/// `firestore.runTransaction`; tests inject a runner that fails with the
/// offline error codes `fake_cloud_firestore` cannot raise, which is the only
/// way to reach the cached-base fallback in a unit test.
typedef CollaborativeListTransactionRunner =
    Future<UnifiedShoppingList> Function(
      Future<UnifiedShoppingList> Function(Transaction transaction) handler,
    );

/// Module handling collection routing between personal and collaborative shopping lists.
/// Routes CRUD operations to appropriate Firestore collections:
/// - Personal lists: /users/{userId}/unified_shopping_lists
/// - Collaborative lists: /unified_shared_shopping_lists
class ShoppingRepositoryRoutingModule {
  /// How long a shared-list mutation may wait for a server round-trip before
  /// the offline fallback takes over.
  ///
  /// The plugin default is 30 seconds, which is the wrong budget for a
  /// checkbox tap: the checkbox is NOT optimistic — the view awaits this call
  /// all the way down, so this budget is the shopper's stare time, not a
  /// background retry window. Eight seconds is short enough to stay inside the
  /// tap, and long enough that a slow-but-working connection normally still
  /// completes the transaction — which matters, because the fallback trades the
  /// lost-update protection away.
  ///
  /// Note this bounds each ATTEMPT of the handler, not the whole call: the
  /// plugin's own `maxAttempts` (default 5) still applies on top, and the
  /// commit that follows the handler is not covered.
  static const Duration _transactionBudget = Duration(seconds: 8);

  /// Error codes that mean "no server round-trip happened", so the write may
  /// safely be re-based on the local cache.
  ///
  /// `deadline-exceeded` is the code the platform reports when
  /// [_transactionBudget] runs out on a flaky connection, and it is at least as
  /// common in a shop as a clean `unavailable`. Deliberately NOT included:
  /// `aborted` (retry contention — an online failure, where a cached-base write
  /// would actively drop another member's tick) and `unknown` (the commit's
  /// outcome is indeterminate, so re-basing could overwrite a commit that did
  /// land).
  static const Set<String> _offlineCodes = {'unavailable', 'deadline-exceeded'};

  /// BUT-1725: every uid that has ever written an item here, kept as a
  /// top-level array purely so account erasure can FIND the list. A departed
  /// member's name survives inside `items` (`addedByDisplayName`, …), and
  /// Firestore cannot query inside an array of maps — so erasure, which located
  /// lists by `memberPermissions.<uid>` or `ownerId`, missed every list the
  /// user had left. Unioned on each write: leaving cannot erase the trail.
  static const String contributorsField = 'contributorUserIds';

  final FirebaseFirestore firestore;
  final AuthRepository authRepository;
  final CollectionReference<Map<String, dynamic>> sharedListsRef;
  final String Function() requireCurrentUserId;
  final void Function({
    required Map<String, dynamic> data,
    required List<String> requiredFields,
    required String resourceType,
  })
  validateRequiredFields;
  final void Function({
    required String userId,
    required String resource,
    required String operation,
    required bool granted,
    String? details,
  })
  logPermissionCheck;
  final UnifiedShoppingList Function(DocumentSnapshot<Map<String, dynamic>> doc)
  fromFirestore;
  final Future<bool> Function(
    String userId,
    String resourceId,
    UnifiedShoppingList entity,
  )
  validateUpdatePermission;

  /// Test seam — see [CollaborativeListTransactionRunner]. Null in production.
  final CollaborativeListTransactionRunner? transactionRunner;

  /// The offline write half: cached read, append detection, narrow payloads and
  /// the replay-rejection audit. Lazy so it can close over
  /// [logPermissionCheck] after the constructor binds it.
  late final ShoppingOfflineWriteModule _offline = ShoppingOfflineWriteModule(
    logPermissionCheck: logPermissionCheck,
  );

  /// The client-side mirrors of the Firestore rules. Lazy for the same reason
  /// as [_offline]: they close over callbacks the constructor binds.
  late final ShoppingListPermissionGuards _guards =
      ShoppingListPermissionGuards(
        logPermissionCheck: logPermissionCheck,
        validateUpdatePermission: validateUpdatePermission,
      );

  ShoppingRepositoryRoutingModule({
    required this.firestore,
    required this.authRepository,
    required this.sharedListsRef,
    required this.requireCurrentUserId,
    required this.validateRequiredFields,
    required this.logPermissionCheck,
    required this.fromFirestore,
    required this.validateUpdatePermission,
    this.transactionRunner,
  });

  /// Create collaborative list in shared collection
  Future<UnifiedShoppingList> createCollaborativeList(
    UnifiedShoppingList entity,
  ) async {
    final uid = requireCurrentUserId();

    // Validate required fields for collaborative lists
    validateRequiredFields(
      data: entity.toFirestore(),
      requiredFields: ['name', 'ownerId', 'memberPermissions'],
      resourceType: 'collaborative_shopping_list',
    );

    // SECURITY (BUT-1696): mirror the create rule for
    // /unified_shared_shopping_lists — `request.auth.uid ==
    // request.resource.data.ownerId`. This was the one write path in the file
    // that logged `granted: true` behind no client-side decision at all: the
    // server refused a foreign-owner create anyway, but the audit row claimed
    // a grant nobody made. Note this also fails
    // `createCollaborativeListFromInvitation` locally instead of at the
    // server — that path has always been dead against the same rule.
    _guards.requireSelfOwnedCreate(uid, entity);

    final docRef = sharedListsRef.doc();
    final listToSave = UnifiedShoppingList(
      id: docRef.id,
      name: entity.name,
      ownerId: entity.ownerId,
      ownerDisplayName: entity.ownerDisplayName,
      items: entity.items,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      lastSyncedAt: entity.lastSyncedAt,
      syncStatus: entity.syncStatus,
      type: entity.type,
      memberPermissions: entity.memberPermissions,
      lastActivityAt: entity.lastActivityAt,
      lastActivityByUserId: entity.lastActivityByUserId,
      lastActivityByDisplayName: entity.lastActivityByDisplayName,
      description: entity.description,
      settings: entity.settings,
      categoryIds: entity.categoryIds,
      allowGuestEditing: entity.allowGuestEditing,
      autoRemoveCompleted: entity.autoRemoveCompleted,
    );

    // BUT-1725: seat the creator immediately. A list created from a conversion
    // arrives with items already stamped `addedByUserId: <creator>`, and those
    // never pass through the mutate path that would otherwise union the uid in.
    await docRef.set({
      ...listToSave.toFirestore(),
      contributorsField: [uid],
    });

    logPermissionCheck(
      userId: uid,
      resource: 'collaborative_shopping_list',
      operation: 'create',
      granted: true,
      details:
          'List: ${listToSave.name}, Members: ${entity.memberPermissions.length}',
    );

    AppLogger.success(
      'Created collaborative list "${listToSave.name}" with ${entity.items.length} items in shared collection',
    );
    return listToSave;
  }

  /// Update collaborative list in shared collection
  Future<UnifiedShoppingList> updateCollaborativeList(
    UnifiedShoppingList entity,
  ) async {
    final uid = requireCurrentUserId();

    // Validate entity exists
    final docRef = sharedListsRef.doc(entity.id);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      throw ResourceNotFoundException(
        'Collaborative shopping list not found',
        resourceType: 'collaborative_shopping_list',
        resourceId: entity.id,
      );
    }

    // SECURITY: evaluate the permission against the STORED document before
    // the write, so the audit entry below records a decision that was made
    // rather than assumed. The caller-supplied `entity` cannot be trusted for
    // this — it carries whatever memberPermissions the client sent.
    final stored = fromFirestore(docSnapshot);
    // Same edit-rights bar as the item path: `validateUpdatePermission` alone
    // accepts any member key including a view-only one, and this method writes
    // the WHOLE list, so it must not be the weaker of the two gates.
    await _guards.requireEditRights(uid, entity.id, stored);
    _guards.requireNoPrivilegeEscalation(uid, entity, stored);

    // BUT-1719: write only what the caller actually changed, and never let a
    // cached base carry an access-control change. See [narrowUpdatePayload].
    final payload = _offline.narrowUpdatePayload(
      uid,
      entity,
      stored,
      baseIsCached: docSnapshot.metadata.isFromCache,
    );
    if (payload.isNotEmpty) await docRef.update(payload);

    logPermissionCheck(
      userId: uid,
      resource: 'collaborative_shopping_list',
      operation: 'update',
      granted: true,
      details: 'List: ${entity.name}',
    );

    AppLogger.info(
      'Updated collaborative list "${entity.name}" with ${entity.items.length} items in shared collection',
    );
    return entity;
  }

  /// BUT-1665: apply [mutate] to a collaborative list inside a Firestore
  /// transaction.
  ///
  /// A shared list's client cache is NOT a safe base for a write: rebuilding
  /// the whole `items` array from it discards every tick another household
  /// member made since that cache was filled. The transaction re-reads the
  /// live document server-side and Firestore retries it if the document moved
  /// underneath, so concurrent edits to *different* items both survive.
  /// Callers pass the same model mutators they used before ([addItem],
  /// [toggleItemBought], …) — only the base list changes, from cached to live.
  ///
  /// Offline (BUT-1665 review): a transaction cannot run without a server
  /// round-trip, and this is a grocery app used in shops with poor reception.
  /// It therefore runs on a short [_transactionBudget], and any of the
  /// [_offlineCodes] hands over to [_mutateFromCache] so the tick lands in the
  /// UI now and syncs later — see that method for the tradeoff it accepts.
  Future<UnifiedShoppingList> mutateCollaborativeList(
    String listId,
    UnifiedShoppingList Function(UnifiedShoppingList live) mutate,
  ) async {
    final uid = requireCurrentUserId();
    final docRef = sharedListsRef.doc(listId);

    final runTransaction = transactionRunner ?? _runTransactionOnBudget;

    try {
      final result = await runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw ResourceNotFoundException(
            'Collaborative shopping list not found',
            resourceType: 'collaborative_shopping_list',
            resourceId: listId,
          );
        }

        final live = fromFirestore(snapshot);
        // SECURITY: the transaction already holds the live document, so the
        // permission decision costs nothing extra and is made against server
        // state rather than a client cache. Without this the audit trail
        // below would record a grant for a check that never ran.
        await _guards.requireEditRights(uid, listId, live);

        final mutated = mutate(live);
        // SECURITY: [mutate] is caller-supplied and this method is public API
        // on ShoppingRepository, so it needs the same escalation bar as the
        // whole-list path — a mutator returning a list that names itself owner
        // or admin must not be written, and must not be audited as a grant.
        _guards.requireNoPrivilegeEscalation(uid, mutated, live);
        // BUT-1725: the one chokepoint every collaborative item write passes
        // through, so the erasure trail is extended here. The union is computed
        // explicitly rather than via `FieldValue.arrayUnion`: the transaction
        // already holds the live array and retries on conflict, so this is
        // exactly as concurrency-safe and does not depend on how a merge-set
        // treats a sentinel.
        final contributors = {
          ...?(snapshot.data()?[contributorsField] as List?)
              ?.whereType<String>(),
          uid,
        };
        transaction.set(docRef, {
          ...mutated.toFirestore(),
          contributorsField: contributors.toList(),
        }, SetOptions(merge: true));
        return mutated;
      });

      logPermissionCheck(
        userId: uid,
        resource: 'collaborative_shopping_list',
        operation: 'update',
        granted: true,
        details: 'List: ${result.name}, transactional item mutation',
      );

      AppLogger.info(
        'Transactionally mutated collaborative list "${result.name}" — '
        '${result.items.length} items after merge',
      );
      return result;
    } on FirebaseException catch (e) {
      if (!_offlineCodes.contains(e.code)) rethrow;
      return _mutateFromCache(uid, listId, docRef, mutate);
    }
  }

  /// BUT-1725: [payload] with the writer unioned into [contributorsField].
  Map<String, Object?> _withContributor(
    Map<String, Object?> payload,
    String uid,
  ) => {
    ...payload,
    contributorsField: FieldValue.arrayUnion([uid]),
  };

  Future<UnifiedShoppingList> _runTransactionOnBudget(
    Future<UnifiedShoppingList> Function(Transaction transaction) handler,
  ) => firestore.runTransaction<UnifiedShoppingList>(
    handler,
    timeout: _transactionBudget,
  );

  /// Offline path for [mutateCollaborativeList]: apply [mutate] to the cached
  /// document and queue a write, which Firestore replays on reconnect.
  ///
  /// BUT-1683 narrows the lost-update window this path used to open across the
  /// board. A mutation that only APPENDS rows — the add-item path — is queued
  /// as an `arrayUnion` on `items` instead of a whole-array overwrite, so a
  /// replay merges with whatever the household did meanwhile instead of
  /// replacing it: nothing can be lost. Only a mutation that touches an
  /// EXISTING row (tick, edit, remove) still queues the cached base, because
  /// Firestore has no offline-replayable primitive for "change element X of
  /// this array". That residual is an accepted deviation — see
  /// `docs/architecture/ACCEPTED_DEVIATIONS.md` — since the alternative is a
  /// checkbox that refuses to work in a shop with no reception.
  Future<UnifiedShoppingList> _mutateFromCache(
    String uid,
    String listId,
    DocumentReference<Map<String, dynamic>> docRef,
    UnifiedShoppingList Function(UnifiedShoppingList live) mutate,
  ) async {
    final live = fromFirestore(await _offline.readCachedDoc(docRef, listId));
    await _guards.requireEditRights(uid, listId, live);

    final mutated = mutate(live);
    // Same escalation bar as the transactional path — the cached base makes the
    // check weaker, not unnecessary.
    _guards.requireNoPrivilegeEscalation(uid, mutated, live);

    final appended = _offline.appendedItems(live, mutated);
    // BUT-1725: an offline edit stamps the same per-item attribution an online
    // one does, so it owes the same erasure trail; arrayUnion replays as a
    // merge, so it is safe on the cached-base path too.
    final payload = _withContributor(
      appended != null
          ? _offline.appendPayload(mutated, appended)
          : _offline.cachedBasePayload(mutated),
      uid,
    );
    // Deliberately not awaited: while offline this future only settles once
    // the write reaches the server, but the local cache and every snapshot
    // listener update immediately. Errors are caught here so a rejected
    // replay surfaces as a log line rather than an uncaught async error.
    unawaited(
      docRef
          .update(payload)
          .catchError((Object e) => _offline.onReplayRejected(uid, listId, e)),
    );

    logPermissionCheck(
      userId: uid,
      resource: 'collaborative_shopping_list',
      operation: 'update',
      granted: true,
      details:
          'List: ${mutated.name}, offline '
          '${appended != null ? 'append-only (arrayUnion)' : 'cached-base'} '
          'item mutation',
    );

    if (appended == null) {
      AppLogger.warning(
        'Offline: queued a cached-base mutation of collaborative list '
            '"${mutated.name}" — a concurrent edit by another member may be '
            'lost (accepted deviation, BUT-1683)',
        'ShoppingRepository',
      );
    } else {
      AppLogger.info(
        'Offline: queued an append-only mutation of collaborative list '
        '"${mutated.name}" — ${appended.length} row(s) unioned, no concurrent '
        'edit can be lost',
      );
    }
    return mutated;
  }
}
