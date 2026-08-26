// lib/services/account/export/social_export_redaction.dart

import 'package:butlery/models/messaging/message_type.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show sanitizeForJson;
import 'package:butlery/services/account/export/shared_shopping_list_export.dart';

/// Everything the social half of the GDPR export removes before a bundle
/// leaves the device — and, just as importantly, everything it deliberately
/// KEEPS.
///
/// These helpers were extracted from `SocialExportManager` when it
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

  /// Whether a stored message row is another participant's duplicate-guard
  /// notice, and therefore not the requester's to receive (BUT-1904).
  ///
  /// SHAPE DIFFERS FROM ITS NEIGHBOURS ON PURPOSE. The helpers around it take a
  /// row and return a row; this one answers a question about a row and the
  /// caller drops it. A field cannot be stripped out of existence — the
  /// whole record is somebody else's — so there is nothing to return.
  ///
  /// FAILS OPEN, which is the OPPOSITE of `dropAvatarUnlessOwn` directly above,
  /// and the asymmetry is the decision rather than an oversight. That one
  /// strips a FIELD, where withholding on doubt costs the requester a URL they
  /// did not need. This one drops a ROW: a record whose `senderId` cannot be
  /// read would be withheld from its own subject, and under-disclosure is the
  /// worse Art. 15 failure. So an unrecognisable sender KEEPS the row.
  ///
  /// What makes failing open safe is the CREATE RULE, not the row's emptiness:
  /// `messages` pins `request.auth.uid == request.resource.data.senderId` and
  /// requires the field, so no client write can produce a row whose sender is
  /// absent or non-String — this branch is unreachable from a client. The
  /// avatar helper above then runs on the kept row and fails closed.
  ///
  /// The EMPTY-CONTENT conjunct is not belt-and-braces, it is what makes the
  /// predicate match the guard's product instead of the type name. No
  /// `firestore.rules` limb bounds what `type` is written TO on a create or a
  /// sender update — B16/B17 in `cook-snaps-and-message-mod-rules.test.ts`
  /// both ALLOW, and B17 creates a stamped row still carrying its full
  /// sentence. Any client can therefore stamp a real message it sent you, and
  /// without this conjunct the bundle would withhold text the requester
  /// genuinely RECEIVED. That is Art. 15 under-disclosure, the failure this
  /// whole helper exists to avoid on the other side. A client-stamped row is
  /// possible whatever `enable_chat_duplicate_guard` is set to, so do not
  /// re-argue this conjunct from the flag's current position.
  ///
  /// A row whose `content` is absent rather than empty is likewise not the
  /// guard's product, so it is KEPT — same direction, same reason.
  ///
  /// This makes the predicate NARROWER than the chat screen's
  /// (`MessagingService._withoutOthersBlockedRows`, which tests type and sender
  /// only), and the divergence is deliberate: hiding a row costs a reader
  /// nothing, while withholding one from an Art. 15 bundle costs its subject a
  /// record they are owed. Do not "harmonise" the two — dropping this conjunct
  /// to match the screen re-opens the under-disclosure.
  ///
  /// Do NOT re-argue the fail-open branch above from emptiness either; that
  /// one rests on the create rule, and ADR-0009 records the emptiness premise
  /// being written back in by the round that removed it.
  bool isOthersBlockedRow(Map<String, dynamic> row, {required String userId}) {
    if (row['type'] != MessageType.duplicateBlocked.name) return false;
    if (row['content'] != '') return false;
    final senderId = row['senderId'];
    if (senderId is! String || senderId.isEmpty) return false;
    return senderId != userId;
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
