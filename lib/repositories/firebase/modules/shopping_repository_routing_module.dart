// lib/repositories/firebase/modules/shopping_repository_routing_module.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
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
    _requireSelfOwnedCreate(uid, entity);

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

    await docRef.set(listToSave.toFirestore());

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
    await _requireEditRights(uid, entity.id, stored);
    _requireNoPrivilegeEscalation(uid, entity, stored);

    await docRef.set(entity.toFirestore(), SetOptions(merge: true));

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
  /// Offline (BUT-1665 review): a Firestore transaction cannot run without a
  /// server round-trip, and this is a grocery app used inside shops where
  /// reception is routinely poor. The transaction therefore runs on a short
  /// [_transactionBudget] instead of the plugin's 30-second default, and any
  /// of the [_offlineCodes] hands over to the pre-BUT-1665 behaviour — mutate
  /// the locally cached document and queue a merge write — so the tick lands
  /// in the UI now and syncs later. That fallback carries the old lost-update
  /// risk, but only while offline, where no safer write exists.
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
        await _requireEditRights(uid, listId, live);

        final mutated = mutate(live);
        // SECURITY: [mutate] is caller-supplied and this method is public API
        // on ShoppingRepository, so it needs the same escalation bar as the
        // whole-list path — a mutator returning a list that names itself owner
        // or admin must not be written, and must not be audited as a grant.
        _requireNoPrivilegeEscalation(uid, mutated, live);
        transaction.set(docRef, mutated.toFirestore(), SetOptions(merge: true));
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
    await _requireEditRights(uid, listId, live);

    final mutated = mutate(live);
    // Same escalation bar as the transactional path — the cached base makes the
    // check weaker, not unnecessary.
    _requireNoPrivilegeEscalation(uid, mutated, live);

    final appended = _offline.appendedItems(live, mutated);
    // Deliberately not awaited: while offline this future only settles once
    // the write reaches the server, but the local cache and every snapshot
    // listener update immediately. Errors are caught here so a rejected
    // replay surfaces as a log line rather than an uncaught async error.
    unawaited(
      (appended != null
              ? docRef.update(_offline.appendPayload(mutated, appended))
              : docRef.update(_offline.cachedBasePayload(mutated)))
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

  /// Throws [PermissionDeniedException] if a non-owner's whole-list write would
  /// change who owns the list or what anyone's permission is.
  ///
  /// Both write paths take their payload from the caller — [updateCollaborativeList]
  /// persists a caller-supplied entity verbatim, and [mutateCollaborativeList]
  /// applies a caller-supplied mutator — so without this an edit-level member
  /// could send back a list naming itself as `admin`, or as `ownerId`, and keep
  /// the escalation. [proposed] is that payload; [stored] is the server state it
  /// is being compared against. This mirrors the
  /// Firestore rule for `/unified_shared_shopping_lists` (non-owners may not
  /// touch `ownerId`/`memberPermissions`/`createdAt`); the rule is the real
  /// enforcement, this turns a raw `permission-denied` from the server into a
  /// decision the audit log records.
  void _requireNoPrivilegeEscalation(
    String uid,
    UnifiedShoppingList proposed,
    UnifiedShoppingList stored,
  ) {
    if (stored.ownerId == uid) return;

    final rewritesOwner = proposed.ownerId != stored.ownerId;
    // A length change catches both an added and a removed member; the entry
    // scan catches a changed value and any add+remove that keeps the count.
    final rewritesMembers =
        proposed.memberPermissions.length != stored.memberPermissions.length ||
        stored.memberPermissions.entries.any(
          (e) => proposed.memberPermissions[e.key] != e.value,
        );
    // BUT-1683 review: the rule's forbidden-key set is a triple, not a pair.
    // `copyWith` cannot move createdAt so the mutate path never trips this,
    // but updateCollaborativeList persists a caller-supplied entity verbatim.
    final rewritesCreatedAt = proposed.createdAt != stored.createdAt;
    if (!rewritesOwner && !rewritesMembers && !rewritesCreatedAt) return;

    final field = rewritesOwner
        ? 'ownerId'
        : rewritesMembers
        ? 'memberPermissions'
        : 'createdAt';
    logPermissionCheck(
      userId: uid,
      resource: 'collaborative_shopping_list',
      operation: 'update',
      granted: false,
      details: 'List: ${proposed.id}, non-owner attempted to rewrite $field',
    );
    throw PermissionDeniedException(
      'User $uid may not change ownership, member permissions or the creation '
      'time of collaborative shopping list ${proposed.id}',
      resource: 'collaborative_list:${proposed.id}',
      userId: uid,
    );
  }

  /// Throws [PermissionDeniedException] unless [uid] is creating a list it
  /// owns itself, mirroring the create rule for
  /// `/unified_shared_shopping_lists`.
  void _requireSelfOwnedCreate(String uid, UnifiedShoppingList entity) {
    final ownsIt = entity.ownerId == uid;
    // The create rule has TWO conjuncts, and mirroring only the first one is
    // how an audit row ends up claiming a grant the server then refuses: it
    // also requires the creator's own key in `memberPermissions`. The
    // `UnifiedShoppingList.collaborative` factory always seats the owner, but
    // the plain constructor does not, and it is on the public interface.
    final seatedAsMember = entity.memberPermissions.containsKey(uid);
    if (ownsIt && seatedAsMember) return;

    final reason = !ownsIt
        ? 'attempted to create a list owned by another user'
        : 'attempted to create a list without seating the owner in '
              'memberPermissions';
    logPermissionCheck(
      userId: uid,
      resource: 'collaborative_shopping_list',
      operation: 'create',
      granted: false,
      details: 'List: ${entity.name}, $reason',
    );
    throw PermissionDeniedException(
      !ownsIt
          ? 'User $uid may not create a collaborative shopping list owned by '
                '${entity.ownerId}'
          : 'User $uid may not create a collaborative shopping list without a '
                'memberPermissions entry for themselves',
      resource: 'collaborative_list:${entity.id}',
      userId: uid,
    );
  }

  /// Throws [PermissionDeniedException] unless [uid] may edit [live]'s items.
  ///
  /// Stricter than [validateUpdatePermission] on purpose: that one accepts any
  /// member key, including a view-only member, who must not be able to tick
  /// items off a shared list or rewrite it wholesale.
  Future<void> _requireEditRights(
    String uid,
    String listId,
    UnifiedShoppingList live,
  ) async {
    final permission = live.memberPermissions[uid];
    final granted =
        await validateUpdatePermission(uid, listId, live) &&
        (live.ownerId == uid ||
            permission == SharedListPermission.admin ||
            permission == SharedListPermission.edit);

    if (granted) return;

    logPermissionCheck(
      userId: uid,
      resource: 'collaborative_shopping_list',
      operation: 'update',
      granted: false,
      details: 'List: $listId, permission: $permission',
    );
    throw PermissionDeniedException(
      'User $uid does not have permission to edit collaborative shopping '
      'list $listId',
      resource: 'collaborative_list:$listId',
      userId: uid,
    );
  }
}
