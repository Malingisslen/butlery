// lib/repositories/firebase/modules/shopping_list_permission_guards.dart

import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/modules/shopping_offline_write_module.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

/// The client-side mirrors of the Firestore rules for
/// `/unified_shared_shopping_lists`.
///
/// The rules are the real enforcement; these turn a raw `permission-denied`
/// from the server into a decision the audit log records, and stop an audit
/// row claiming a grant nobody made. Every write path in
/// `ShoppingRepositoryRoutingModule` runs them, which is why they live in one
/// place rather than beside a single caller.
///
/// Split out of that module when BUT-1719/BUT-1725 pushed it past the 500-line
/// limit; the module stays a routing facade, as its own doc says it should.
class ShoppingListPermissionGuards {
  /// BUT-1741: the audit sink is asynchronous, so the callback type says so.
  /// Typed `void` it still ACCEPTED the async implementation — Dart allows a
  /// `Future<void>` function where `void` is expected — and every call here
  /// silently dropped the future, which turns a failing audit write into an
  /// unhandled async error instead of a caught one. Each call is now awaited,
  /// so the row is on its way before the guard throws.
  final Future<void> Function({
    required String userId,
    required String resource,
    required String operation,
    required bool granted,
    String? details,
  })
  logPermissionCheck;

  final Future<bool> Function(
    String userId,
    String resourceId,
    UnifiedShoppingList entity,
  )
  validateUpdatePermission;

  ShoppingListPermissionGuards({
    required this.logPermissionCheck,
    required this.validateUpdatePermission,
  });

  /// Throws [PermissionDeniedException] if a non-owner's whole-list write would
  /// change who owns the list or what anyone's permission is.
  ///
  /// Both write paths take their payload from the caller — an entity for
  /// `updateCollaborativeList`, a mutator for `mutateCollaborativeList` — so
  /// without this an edit-level member could send back a list naming itself
  /// `admin` or `ownerId` and keep the escalation. [proposed] is that payload,
  /// [stored] the server state it is compared against.
  ///
  /// Still needed after BUT-1719 narrowed the update payload: narrowing decides
  /// WHICH keys are written, this decides whether the caller may write them.
  Future<void> requireNoPrivilegeEscalation(
    String uid,
    UnifiedShoppingList proposed,
    UnifiedShoppingList stored,
  ) async {
    if (stored.ownerId == uid) return;

    final rewritesOwner = proposed.ownerId != stored.ownerId;
    // A length change catches both an added and a removed member; the entry
    // scan catches a changed value and any add+remove that keeps the count.
    final rewritesMembers = !_sameMembers(
      proposed.memberPermissions,
      stored.memberPermissions,
    );
    // BUT-1683 review: the rule's forbidden-key set is a triple, not a pair.
    // `copyWith` cannot move createdAt so the mutate path never trips this,
    // but a caller can hand updateCollaborativeList a rebuilt entity.
    final rewritesCreatedAt = proposed.createdAt != stored.createdAt;
    if (!rewritesOwner && !rewritesMembers && !rewritesCreatedAt) return;

    final field = rewritesOwner
        ? 'ownerId'
        : rewritesMembers
        ? 'memberPermissions'
        : 'createdAt';
    await logPermissionCheck(
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

  /// BUT-1726: [payload] with every access-control field path the caller did
  /// not demonstrably intend removed, or a refusal when the intent rests on a
  /// base the server has already moved past.
  ///
  /// `updateCollaborativeList` takes a WHOLE entity and derives "what the
  /// caller changed" by diffing it against a fresh server read. That inference
  /// only holds if the caller built its entity from the SAME server state. It
  /// usually has not: the view holds a list object read minutes ago, so a plain
  /// rename ships a member map that predates whatever happened on the owner's
  /// other device. Diffed against the fresh read, that staleness reads as a
  /// deliberate ACL edit — `memberPermissions.<uid>` field paths that reinstate
  /// a member the owner removed elsewhere, or `FieldValue.delete()` for one
  /// added elsewhere. For the owner nothing stops it: the escalation guard
  /// above returns early, and `narrowUpdatePayload`'s `baseIsCached` refusal
  /// asks whether the FRESH READ came from cache — a question about the very
  /// document the diff is taken against, never about the proposal.
  ///
  /// So the provenance question is asked of the proposal instead. A caller that
  /// means to manage membership passes the base it edited ([declaredBase]);
  /// that base is compared against [stored], and a drift means the answer being
  /// replayed was computed against state that no longer exists — refused, not
  /// applied. A caller that passes nothing is editing content, and its
  /// access-control paths are dropped so a rename can never move the ACL.
  Future<Map<String, Object?>> restrictAccessControlToDeclaredBase(
    String uid,
    String listId,
    Map<String, Object?> payload, {
    required UnifiedShoppingList? declaredBase,
    required UnifiedShoppingList stored,
  }) async {
    final privileged = payload.keys
        .where(
          (key) => ShoppingOfflineWriteModule.privilegedKeys.contains(
            key.split('.').first,
          ),
        )
        .toSet();
    if (privileged.isEmpty) return payload;

    if (declaredBase == null) {
      await logPermissionCheck(
        userId: uid,
        resource: 'collaborative_shopping_list',
        operation: 'update',
        granted: false,
        details:
            'List: $listId, dropped ${privileged.join(", ")} from a whole-list '
            'update that declared no access-control base',
      );
      return {
        for (final entry in payload.entries)
          if (!privileged.contains(entry.key)) entry.key: entry.value,
      };
    }

    final drifted = _accessControlDrift(declaredBase, stored);
    if (drifted.isEmpty) {
      // A declared-base write states an intent about membership, never about
      // the creation time — and `narrowUpdatePayload` diffs `toFirestore()`,
      // so on a legacy document whose `createdAt` is synthesised fresh on each
      // read the two sides differ and the key rides along. The owner branch of
      // the update rule carries no field constraints, so the server WOULD
      // accept it, permanently stamping the list's creation time as "the
      // moment someone changed a member". Strip it: the caller demonstrably
      // did not ask to change it.
      return {
        for (final entry in payload.entries)
          if (entry.key.split('.').first != 'createdAt') entry.key: entry.value,
      };
    }

    await logPermissionCheck(
      userId: uid,
      resource: 'collaborative_shopping_list',
      operation: 'update',
      granted: false,
      details:
          'List: $listId, refused an access-control change computed against a '
          'base the server has moved past (${drifted.join(", ")})',
    );
    throw StaleAccessControlBaseException(
      'The access-control change to collaborative shopping list $listId was '
      'computed against an out-of-date copy (${drifted.join(", ")} changed on '
      'the server); re-read the list and try again',
      resource: 'collaborative_list:$listId',
      userId: uid,
      driftedFields: drifted,
    );
  }

  /// Throws [PermissionDeniedException] unless [uid] is creating a list it
  /// owns itself, mirroring the create rule.
  Future<void> requireSelfOwnedCreate(
    String uid,
    UnifiedShoppingList entity,
  ) async {
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
    await logPermissionCheck(
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
  Future<void> requireEditRights(
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

    await logPermissionCheck(
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

  /// The access-control fields on which [base] and [stored] disagree — the
  /// three keys `firestore.rules` treats as an access-control statement.
  List<String> _accessControlDrift(
    UnifiedShoppingList base,
    UnifiedShoppingList stored,
  ) => [
    if (base.ownerId != stored.ownerId) 'ownerId',
    if (!_sameMembers(base.memberPermissions, stored.memberPermissions))
      'memberPermissions',
    // `createdAt` is deliberately NOT a drift signal, though it IS one of the
    // three keys the rules treat as privileged.
    //
    // `SerializationUtils.safeRequiredDateTime` falls back to `clock.now()`
    // when the stored field is missing or unparseable, and
    // `UnifiedShoppingList.fromMap` passes no `defaultValue` — so a legacy or
    // imported list synthesises a DIFFERENT value on every read. Comparing it
    // would mean base never equals stored, every add / remove / permission
    // change refused forever, and a refusal whose own advice ("reload the
    // list") can never succeed. A freshness WINDOW does not rescue it either:
    // the base's value is anchored to the last snapshot emission, which is
    // unbounded, so a dialog open for four minutes fails just the same.
    //
    // Dropping it costs nothing, because it was never carrying the statement:
    // `ownerId` and `memberPermissions` ARE the access-control claim, and both
    // are compared exactly as before. `createdAt` is also immutable in
    // practice — the payload strip below removes it outright — so the only
    // case it could uniquely catch is a document deleted and re-created under
    // the same id with byte-identical membership. Fixing the non-determinism
    // properly belongs at the parse seam (a stable sentinel default), not
    // here: BUT-1755.
  ];

  bool _sameMembers(
    Map<String, SharedListPermission> a,
    Map<String, SharedListPermission> b,
  ) => a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}
