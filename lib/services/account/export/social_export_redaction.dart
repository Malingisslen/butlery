// lib/services/account/export/social_export_redaction.dart

import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show sanitizeForJson;
import 'package:butlery/services/account/export/shared_shopping_list_export.dart';

/// Everything the social half of the GDPR export removes before a bundle
/// leaves the device — and, just as importantly, everything it deliberately
/// KEEPS.
///
/// These three helpers were extracted from `SocialExportManager` when it
/// crossed the 500-line limit, but the real reason they live together is the
/// one `.claude/rules/accepted-deviations.md` states outright: several export
/// sections implement ONE founder decision each, and a second copy of the
/// logic is exactly how two sections drift apart. One file, one place to read
/// what the bundle discloses.
///
/// Each verdict here is a dated decision by Malin, not an engineering choice.
/// Read the accepted-deviations entries before changing any of them:
///   * BUT-1772 / BUT-1775 — avatars stripped, display names kept
///   * BUT-1798 — `shared_content` recipients' UIDs and the sharer's name kept
///   * BUT-1798 — inside a shared list's nested copy, other members' names go
mixin SocialExportRedaction {
  /// The ONE implementation of Malin's avatar rule, shared by the conversations
  /// section and the shared-content section so the two cannot drift apart
  /// (BUT-1772, extended to `shared_content` by BUT-1775). An avatar URL is
  /// different in kind from a name: a durable, directly dereferenceable pointer
  /// to another person's photograph, which survives in any file this bundle is
  /// forwarded to and keeps resolving after they leave the thread or delete
  /// their account — and it buys the requester nothing.
  ///
  /// The requester's OWN avatar stays. Withholding the subject's own data is
  /// the opposite failure to the one this guards against.
  ///
  /// FAILS CLOSED on a row whose owner id is missing or unrecognised: it is
  /// treated as somebody else's and stripped, never passed through while the
  /// section's `data_minimisation` line claims otherwise.
  Map<String, dynamic> dropAvatarUnlessOwn(
    Map<String, dynamic> row, {
    required String ownerIdField,
    required String avatarField,
    required String userId,
  }) {
    if (row[ownerIdField] == userId) return row;
    return Map<String, dynamic>.from(row)..remove(avatarField);
  }

  /// One shared-recipe / shared-menu row with the SHARER's avatar URL removed,
  /// unless the sharer is the requester (BUT-1775).
  ///
  /// Three sections below the conversations one, the same durable pointer to
  /// another person's photograph was still shipping: when a friend shares a
  /// recipe with you, their `sharedByAvatarUrl` lands in the `shared_content`
  /// document and then verbatim in your bundle. Same rule, same helper — a
  /// second copy of the logic is exactly how two sections that implement one
  /// decision drift apart.
  ///
  /// The MENU leg only started carrying anything to strip once
  /// `exportSharedMenusReceived` was repointed off the top-level `menus`
  /// collection, which holds neither `sharedToUserIds` nor `sharedByAvatarUrl`,
  /// onto the `shared_content` documents menu shares actually land in. Before
  /// that the leg returned zero rows and this strip was dead code — while the
  /// `data_minimisation` sentence below already described it as active.
  Map<String, dynamic> dropSharerAvatar(
    Map<String, dynamic> entry,
    String userId,
  ) => dropAvatarUnlessOwn(
    sanitizeForJson(entry['data']) as Map<String, dynamic>,
    ownerIdField: 'sharedByUserId',
    avatarField: 'sharedByAvatarUrl',
    userId: userId,
  );

  /// Other members' display names, stripped from the nested `listData` copy a
  /// shopping-list share carries.
  ///
  /// BUT-1798, **Malin's explicit call, 2026-08-01.** A shopping-list share
  /// embeds a whole copy of the sender's list, and a top-level strip never
  /// reaches inside it: `memberPermissions` is keyed by uid, and every item
  /// carries three uid + displayName pairs (added / purchased / last modified).
  /// Her decision matches the one she made for `unified_shared_shopping_lists`
  /// (BUT-1732) — other members' **UIDs and permission levels stay, their
  /// display names go** — because that is the same class of data seen from the
  /// same angle. The requester's OWN name is kept: stripping it would leave
  /// them unable to recognise their own entries.
  ///
  /// Not derived by analogy from the recipe/menu call in the same section:
  /// that one governs the sharer's single `sharedByDisplayName` on the wrapper
  /// document, not a nested roster of everyone who ever touched the list.
  Map<String, dynamic> dropOtherMembersNamesInListData(
    Map<String, dynamic> data,
    String userId,
  ) {
    final listData = data['listData'];
    if (listData is! Map) return data;

    // Each display-name field is paired with the uid field that says whose name
    // it is; keep the requester's own, drop everyone else's. Fail CLOSED — an
    // unrecognised shape drops the name rather than passing it through.
    //
    // Borrowed from `SharedShoppingListExport`, NOT re-listed here. Both
    // sections implement the SAME founder decision (BUT-1732, extended
    // 2026-08-01) over the same model, and a second hand-written copy had
    // already drifted on its first day: it omitted `assignedToDisplayName`,
    // so a third party's name shipped in a section whose own
    // `data_minimisation` note promised it had been removed. One map, one
    // decision, and adding a field to the model can only be missed once.
    const ownerOf = SharedShoppingListExport.nameKeysByOwnerIdKey;

    Object? walk(Object? node) {
      if (node is List) return node.map(walk).toList();
      if (node is! Map) return node;
      final copy = Map<String, dynamic>.from(node);
      // Driven off `ownerOf` alone. A second parallel list would fail OPEN in
      // one direction: add a field to `ownerOf` only and nothing visits it, so
      // the name ships — the single disclosure this file exists to prevent.
      for (final entry in ownerOf.entries) {
        if (!copy.containsKey(entry.key)) continue;
        if (copy[entry.value] != userId) copy.remove(entry.key);
      }
      for (final key in copy.keys.toList()) {
        copy[key] = walk(copy[key]);
      }
      return copy;
    }

    final copy = Map<String, dynamic>.from(data);
    copy['listData'] = walk(listData);
    return copy;
  }
}
