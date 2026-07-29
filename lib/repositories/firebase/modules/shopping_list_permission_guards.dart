// lib/repositories/firebase/modules/shopping_list_permission_guards.dart

import 'package:butlery/models/unified/unified_shopping_list.dart';
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
  final void Function({
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
  void requireNoPrivilegeEscalation(
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
    // but a caller can hand updateCollaborativeList a rebuilt entity.
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
  /// owns itself, mirroring the create rule.
  void requireSelfOwnedCreate(String uid, UnifiedShoppingList entity) {
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
