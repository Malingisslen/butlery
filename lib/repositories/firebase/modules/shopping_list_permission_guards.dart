// lib/repositories/firebase/modules/shopping_list_permission_guards.dart

import 'package:collection/collection.dart';

import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart'
    show MembershipWriteIntent;
import 'package:butlery/repositories/firebase/modules/shopping_offline_write_module.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

/// The client-side mirrors of the Firestore rules for
/// `/unified_shared_shopping_lists`.
///
/// The rules are the real enforcement; these turn a raw `permission-denied`
/// from the server into a decision the audit log records, and stop an audit
/// row claiming a grant nobody made. Every write path in
/// `ShoppingRepositoryRoutingModule` runs one of them, which is why they live
/// in one place rather than beside a single caller.
///
/// "One of them" and not "both", since BUT-1718: a SELF-REMOVAL runs
/// [requireSelfRemovalOnly] INSTEAD of [requireEditRights] +
/// [requireNoPrivilegeEscalation], because those two refuse exactly the write
/// leaving a list has to make. It is still a guard in this class and still
/// audited; what changes is which predicate the write is held to, and that
/// predicate is scoped to the same two fields as the rule's own allowlist so
/// client and server cannot drift (ADR-0004).
///
/// Split out of that module by BUT-1719/BUT-1725.
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

  /// Throws [SecurityViolationException] when [data] lacks a required key.
  /// Injected rather than mixed in so the audit-free field check and the
  /// audited conjuncts stay in one guard.
  final void Function({
    required Map<String, dynamic> data,
    required List<String> requiredFields,
    required String resourceType,
  })
  validateRequiredFields;

  ShoppingListPermissionGuards({
    required this.logPermissionCheck,
    required this.validateUpdatePermission,
    required this.validateRequiredFields,
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
    //
    // BUT-1755: this exact comparison is only safe because the parse seam now
    // hands a legacy document a FIXED sentinel
    // (`UnifiedShoppingList.unknownCreatedAt`) rather than `clock.now()`. While
    // it synthesised a fresh value per read, `proposed` and `stored` — two
    // separate parses of the same document — could never agree, so every
    // non-owner edit of a list with no stored `createdAt` was refused as an
    // escalation attempt. Do not reintroduce a now-based fallback there.
    //
    // `isAtSameMomentAs`, not `!=`/`==`: the sentinel is UTC
    // (`DateTime.utc(1970)`), but once it round-trips through Firestore
    // (`Timestamp.fromDate` then `.toDate()`), it comes back LOCAL — same
    // instant, different `isUtc`. Dart's `==`/`!=` compares `isUtc` too, so a
    // client holding the pre-persist UTC sentinel while `stored` now reflects
    // the post-persist local value would reopen the exact permanent-denial
    // bug this ticket exists to close, just retriggered by a Firestore
    // round-trip instead of a fresh-clock read. Confirmed live: the same
    // sentinel value is `!=` itself after one write-then-read cycle.
    final rewritesCreatedAt = !proposed.createdAt.isAtSameMomentAs(
      stored.createdAt,
    );
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
      // the creation time, so the key is stripped unconditionally: the caller
      // demonstrably did not ask to change it, and the owner branch of the
      // update rule carries no field constraints, so the server WOULD accept
      // whatever rode along.
      //
      // BUT-1755 removed the way it used to ride along (a legacy document's
      // `createdAt` was re-synthesised per read, so `narrowUpdatePayload`'s
      // `toFirestore()` diff always saw it change, permanently stamping the
      // list's creation time as "the moment someone changed a member"). The
      // strip stays anyway — it is the statement about intent, not a patch for
      // that one seam.
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

  /// The create rule's `hasRequiredFields` conjunct, plus the client-side extra
  /// `name` the rule does not ask for. A superset of the rule's list is safe;
  /// a subset is not (BUT-1706).
  static const List<String> collaborativeCreateRequiredFields = [
    'name',
    'ownerId',
    'memberPermissions',
    'items',
    'createdAt',
  ];

  /// Throws unless [uid] is creating a list it owns itself, mirroring all THREE
  /// conjuncts of the create rule beyond `isAuthenticated()`.
  ///
  /// BUT-1706: the third conjunct
  /// (`hasRequiredFields(['ownerId', 'memberPermissions', 'items', 'createdAt'])`)
  /// used to be checked by the caller and was missing `items` and `createdAt`,
  /// so a create lacking either was refused by the SERVER after the audit row
  /// had already recorded a grant. All three now live together, so a fourth
  /// conjunct cannot be mirrored in only one of two places again.
  ///
  /// The rule's remaining bound — `contributorUserIds.size() <= 200` — cannot
  /// fail on create: the caller seats exactly `[uid]`.
  Future<void> requireSelfOwnedCreate(
    String uid,
    UnifiedShoppingList entity,
  ) async {
    // Before any audit row: a missing-field refusal is not a permission
    // decision, so it must not log a check either way.
    validateRequiredFields(
      data: entity.toFirestore(),
      requiredFields: collaborativeCreateRequiredFields,
      resourceType: 'collaborative_shopping_list',
    );

    final ownsIt = entity.ownerId == uid;
    // Mirroring only `ownerId == uid` is how an audit row ends up claiming a
    // grant the server then refuses: the rule also requires the creator's own
    // key in `memberPermissions`. The `UnifiedShoppingList.collaborative`
    // factory always seats the owner, but the plain constructor does not, and
    // it is on the public interface.
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

  /// Runs the guard [intent] calls for and answers with the entity that may
  /// actually be written.
  ///
  /// BUT-1718: a departure's answer is NOT the caller's entity. It is derived
  /// from [stored] — the caller's own key removed.
  /// Before this, a departure built from a
  /// stream copy that another member had ticked an item into carried `items`,
  /// which the allowlist refuses; the user was told they lacked permission to
  /// EDIT a list they were trying to leave. That is the invented-cause class
  /// BUT-1696 exists to remove, on the one action this ticket exists to make
  /// work.
  ///
  /// [requireSelfRemovalOnly] still runs on the derived entity. Three of its
  /// five conditions are then satisfied by construction and only two can fail —
  /// owner, and not a member — which are the authorization decision. Measured:
  /// neutralising each condition in turn and re-running
  /// `shopping_repository_routing_module_test.dart` reddens it for those two and for
  /// neither of the other three.
  ///
  /// It is kept whole anyway. The three are the client mirror ADR-0004 requires
  /// the rule to be checked against, and the day somebody hands this method an
  /// entity from somewhere other than the derivation above, they are the only
  /// thing between that entity and the write.
  Future<UnifiedShoppingList> resolveMembershipWrite(
    String uid,
    UnifiedShoppingList proposed,
    UnifiedShoppingList stored,
    MembershipWriteIntent intent,
  ) async {
    if (intent != MembershipWriteIntent.selfRemoval) {
      // Same edit-rights bar as the item path: `validateUpdatePermission` alone
      // accepts any member key including a view-only one, and this writes the
      // WHOLE list, so it must not be the weaker of the two gates.
      await requireEditRights(uid, proposed.id, stored);
      await requireNoPrivilegeEscalation(uid, proposed, stored);
      return proposed;
    }

    final departed = stored.copyWith(
      memberPermissions: Map<String, SharedListPermission>.from(
        stored.memberPermissions,
      )..remove(uid),
      updatedAt: proposed.updatedAt,
    );
    await requireSelfRemovalOnly(uid, departed, stored);
    return departed;
  }

  /// BUT-1718: throws unless [proposed] removes exactly [uid]'s own key from
  /// [stored]'s `memberPermissions` and changes nothing else.
  ///
  /// The client-side mirror of the `removesOnlySelfFromMembers()` arm, scoped
  /// to the same five conditions so the two cannot drift: the caller is not the
  /// owner, was a member, is gone afterwards, no other member's entry moved,
  /// and no other field moved either.
  ///
  /// [requireEditRights] is deliberately NOT run for this write, and that is
  /// the point rather than an oversight. Leaving is not an edit — it is the
  /// removal of one's own membership — and a VIEW-ONLY member, who that guard
  /// refuses outright, is the person most likely to need it. Do not "fix" a
  /// self-removal by routing it back through the ordinary update path.
  ///
  /// The last conjunct is the one a reader is most likely to drop as
  /// redundant. It is not: without it the client would happily send a write
  /// carrying `items` alongside the membership change, the server would refuse
  /// the whole thing, and the audit row would already have claimed a grant.
  Future<void> requireSelfRemovalOnly(
    String uid,
    UnifiedShoppingList proposed,
    UnifiedShoppingList stored,
  ) async {
    final isOwner = stored.ownerId == uid;
    final wasMember = stored.memberPermissions.containsKey(uid);
    final isGone = !proposed.memberPermissions.containsKey(uid);
    final othersUntouched = _sameMembers(
      {...stored.memberPermissions}..remove(uid),
      proposed.memberPermissions,
    );
    final onlyMembersChanged = _touchesNothingBut(proposed, stored);

    if (!isOwner &&
        wasMember &&
        isGone &&
        othersUntouched &&
        onlyMembersChanged) {
      // Refusal-only, like the three guards beside it. A grant row here would
      // be written BEFORE the write, so a departure the server then refuses —
      // a cached-base refusal, a stale base, a rules denial — would leave a
      // standing grant for something that never happened, and every successful
      // leave would log two. `updateCollaborativeList` writes the grant once
      // the write has landed.
      return;
    }

    final reason = isOwner
        ? 'the owner cannot leave their own list'
        : !wasMember
        ? 'not a member of the list'
        : !isGone
        ? 'the write does not remove the caller'
        : !othersUntouched
        ? "the write also changes another member's entry"
        : 'the write also changes a field outside memberPermissions';
    await logPermissionCheck(
      userId: uid,
      resource: 'collaborative_shopping_list',
      operation: 'update',
      granted: false,
      details: 'List: ${stored.id}, refused self-removal — $reason',
    );
    throw PermissionDeniedException(
      'User $uid may not leave collaborative shopping list ${stored.id}: '
      '$reason',
      resource: 'collaborative_list:${stored.id}',
      userId: uid,
    );
  }

  /// True when [proposed] and [stored] differ in nothing but their member map.
  ///
  /// `updatedAt` is excluded because the rule's allowlist names it — the leave
  /// write stamps it, and a comparison that counted it would refuse every real
  /// departure.
  bool _touchesNothingBut(
    UnifiedShoppingList proposed,
    UnifiedShoppingList stored,
  ) {
    const equality = DeepCollectionEquality();
    final next = proposed.toFirestore();
    final current = stored.toFirestore();
    return next.keys
        .followedBy(current.keys)
        .toSet()
        .every(
          (key) =>
              key == 'memberPermissions' ||
              key == 'updatedAt' ||
              equality.equals(next[key], current[key]),
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
    // The original reason was that the parse seam re-synthesised the field on
    // every read, so base could never equal stored. BUT-1755 fixed that seam —
    // `UnifiedShoppingList.fromMap` now defaults to a fixed sentinel — but the
    // exclusion STAYS, on its own merits: `ownerId` and `memberPermissions` ARE
    // the access-control claim, and both are compared exactly as before.
    // `createdAt` is immutable in practice — the payload strip above removes it
    // outright — so the only case it could uniquely catch is a document deleted
    // and re-created under the same id with byte-identical membership.
    // Re-adding it would only buy a new class of refusal whose advice ("reload
    // the list") the user cannot act on.
  ];

  bool _sameMembers(
    Map<String, SharedListPermission> a,
    Map<String, SharedListPermission> b,
  ) => a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}
