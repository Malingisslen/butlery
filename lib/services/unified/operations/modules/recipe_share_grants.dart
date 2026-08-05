// lib/services/unified/operations/modules/recipe_share_grants.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

/// The outcome of revoking one group's share (BUT-1797).
class GroupRevocationResult {
  /// `memberPermissions` after the revoke — the only thing that decides access.
  final Map<String, ResourcePermission>? permissions;

  /// `grants` after the revoke, with the group's reason removed from everyone.
  final Map<String, List<String>>? grants;

  /// Members who lost access because the group was their only reason to be here.
  final List<String> removedMemberIds;

  /// Members who kept access — because they hold another grant, or because they
  /// own the recipe. The owner reaches this list with NO grant left — one way
  /// there is a transfer (member via `group:X`, promoted to owner, X later
  /// revoked), but it is not the only one: a member re-sharing to a group that
  /// contains the owner also grants them a `group:` token.
  final List<String> retainedMemberIds;

  const GroupRevocationResult({
    required this.permissions,
    required this.grants,
    required this.removedMemberIds,
    required this.retainedMemberIds,
  });
}

/// Pure grant algebra for collaborative recipe shares.
///
/// Separated from `RecipeMemberManager` so the decided behaviour can be tested
/// without the manager's five injected seams, and because the manager is already
/// at its size limit.
///
/// `grants` is descriptive only: it records WHY each member has access.
/// `memberPermissions` remains the sole source of truth, and `firestore.rules`
/// reads only that, so nothing here can widen what anyone may see.
class RecipeShareGrants {
  const RecipeShareGrants._();

  /// Records [grant] for [memberId], keeping any grant they already hold.
  ///
  /// Re-sharing by the same route is idempotent — a second `'direct'` share does
  /// not stack, so one revoke is enough to undo one decision.
  static Map<String, List<String>> add(
    Map<String, List<String>>? current,
    String memberId,
    String grant,
  ) {
    final next = _copy(current);
    final existing = next[memberId] ?? const <String>[];
    if (existing.contains(grant)) return next;
    next[memberId] = [...existing, grant];
    return next;
  }

  /// Drops [memberId]'s entry entirely, whatever grants it held.
  ///
  /// Used by an explicit "remove this person", which overrides every grant at
  /// once. Leaving a stale group grant behind would make a later group-revoke
  /// look like it had already run.
  static Map<String, List<String>>? dropMember(
    Map<String, List<String>>? current,
    String memberId,
  ) {
    if (current == null) return null;
    final next = _copy(current)..remove(memberId);
    return next;
  }

  /// Revokes [groupId]'s share.
  ///
  /// For each member holding `group:<groupId>`: drop that reason. If they have
  /// none left, they lose access; if they still hold `'direct'` or another
  /// group, they keep it (Malin's decision, 2026-08-03 — two separate decisions
  /// were made about that person, and only one is being undone).
  ///
  /// [ownerId] is never removed, whatever the grants say — and the owner CAN
  /// legitimately hold one: `transferOwnership` promotes a member and keeps
  /// their existing tokens, and a non-owner re-sharing to a roster containing
  /// the owner grants them one. Even a stray token would be no reason to orphan
  /// the recipe.
  static GroupRevocationResult revokeGroup({
    required Map<String, List<String>>? grants,
    required Map<String, ResourcePermission>? permissions,
    required String groupId,
    required String? ownerId,
  }) {
    // No provenance recorded means no member holds a group grant, so there is
    // nothing to revoke and only the display label drops. Deliberately NOT read
    // as "everyone is direct": the field is written from the start, and the only
    // documents without it are test data (Malin, 2026-08-03).
    if (grants == null || grants.isEmpty) {
      return GroupRevocationResult(
        permissions: permissions,
        grants: grants,
        removedMemberIds: const [],
        retainedMemberIds: const [],
      );
    }

    final token = RecipeSocialData.groupGrant(groupId);
    final nextGrants = _copy(grants);
    final nextPermissions = permissions == null
        ? null
        : Map<String, ResourcePermission>.from(permissions);
    final removed = <String>[];
    final retained = <String>[];

    for (final entry in grants.entries) {
      if (!entry.value.contains(token)) continue;

      final remaining = entry.value.where((g) => g != token).toList();

      if (remaining.isNotEmpty) {
        nextGrants[entry.key] = remaining;
        retained.add(entry.key);
        continue;
      }

      nextGrants.remove(entry.key);
      if (entry.key == ownerId) {
        retained.add(entry.key);
        continue;
      }
      nextPermissions?.remove(entry.key);
      removed.add(entry.key);
    }

    return GroupRevocationResult(
      permissions: nextPermissions,
      grants: nextGrants,
      removedMemberIds: removed,
      retainedMemberIds: retained,
    );
  }

  /// Merges the provenance of one share into whatever the recipe already held.
  ///
  /// [grantsByUserId] is non-null only for a group share, and maps each member
  /// to the groups that actually contained them; a plain user share records
  /// [RecipeSocialData.directGrant]. Existing grants are preserved, so a person
  /// shared with twice keeps both reasons and revoking one leaves the other
  /// standing — the decided asymmetry, implemented once.
  ///
  /// Returns null rather than an empty map when nothing is recorded, matching
  /// [mergeCategoryIds].
  static Map<String, List<String>>? forShare({
    required Map<String, List<String>>? existing,
    required List<String> userIds,
    Map<String, List<String>>? grantsByUserId,
    String? excludeUserId,
  }) {
    var grants = existing;
    for (final userId in userIds) {
      // The sharer is not a sharee, on any path that passes their own id.
      if (userId == excludeUserId) continue;
      final tokens =
          grantsByUserId?[userId] ?? const [RecipeSocialData.directGrant];
      for (final token in tokens) {
        grants = add(grants, userId, token);
      }
    }
    // Null, not `{}`, when there is nothing to record — the same rule
    // `mergeCategoryIds` follows for its sibling field. Two shapes for one fact
    // is the drift this codebase has already paid for once.
    return (grants == null || grants.isEmpty) ? null : grants;
  }

  /// The groups on the recipe after this share: what was there, plus what the
  /// share added.
  ///
  /// Display/filter only — `memberPermissions` decides access. Returns null when
  /// there is nothing, so the field stays NULL rather than an empty list.
  /// (`toJson` writes the key either way; the distinction is null vs `[]`, not
  /// present vs absent.)
  static List<String>? mergeCategoryIds(
    List<String>? existing,
    Map<String, List<String>>? grantsByUserId,
  ) {
    final merged = <String>{...?existing};
    for (final tokens in grantsByUserId?.values ?? const <List<String>>[]) {
      for (final token in tokens) {
        // Two guards, neither redundant, and each for a DIFFERENT input — the
        // six-character coincidence between 'group:' and 'direct' is what makes
        // that easy to get wrong. `'direct'.substring(6)` is '', so guard 2
        // catches that one; guard 1 earns its place on the other shapes.
        //
        // Guard 1 — a non-group token whose remainder is NOT empty
        // ('direct-share' would merge '-share' as a category id), and one
        // SHORTER than the prefix, where `substring` throws RangeError.
        if (!token.startsWith(_groupPrefix)) continue;
        final categoryId = token.substring(_groupPrefix.length);
        // Guard 2 — `groupGrant('')` is exactly the prefix, so it clears guard 1
        // and yields an empty id. Merged, that becomes a NAMELESS row in the
        // sharing panel: the panel falls back to the raw id for its label, and
        // no friend_categories doc has id ''. Kept out, a stray 'group:' grant
        // is simply never shown — and never revocable, since `removeGroup`
        // refuses a groupId absent from `categoryIds`. The nameless row is the
        // harm; this is the trade.
        if (categoryId.isEmpty) continue;
        merged.add(categoryId);
      }
    }
    return merged.isEmpty ? null : merged.toList();
  }

  static const String _groupPrefix = 'group:';

  static Map<String, List<String>> _copy(Map<String, List<String>>? source) {
    if (source == null) return <String, List<String>>{};
    return source.map((k, v) => MapEntry(k, List<String>.from(v)));
  }
}
