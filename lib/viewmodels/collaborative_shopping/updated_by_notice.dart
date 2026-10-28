import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/stored_display_name.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/viewmodels/collaborative_shopping/shopping_list_change_summary.dart';

/// BUT-2187: "Listan uppdaterades av namn". Shared by the
/// full-screen shared list and the shopping tab, so a member sees the same
/// notice wherever they have the list open.
///
/// `lastActivityAt` / `lastActivityByUserId` / `lastActivityByDisplayName`
/// ([UnifiedShoppingList]) already exist — no new Firestore field.
/// Returns null when [updated] is not someone else's new activity.
String? updatedByNoticeFor({
  required UnifiedShoppingList previous,
  required UnifiedShoppingList updated,
  required String? currentUserId,
}) {
  final activityAt = updated.lastActivityAt;
  final activityUserId = updated.lastActivityByUserId;
  if (activityAt == null || activityUserId == null) return null;

  // The (timestamp, uid) pair must differ from the previous snapshot's,
  // not `isAfter`: clocks differ across devices, and a queued offline
  // edit can replay with its original — possibly older — timestamp. The
  // pair-differs check still suppresses a re-broadcast of the same
  // unchanged document.
  final previousAt = previous.lastActivityAt;
  final isSameActivity =
      previousAt != null &&
      activityAt.isAtSameMomentAs(previousAt) &&
      activityUserId == previous.lastActivityByUserId;
  if (isSameActivity) return null;

  // currentUserId is the permission/identity check (CLAUDE.md data-source
  // rule) — this compares who acted, not their profile.
  if (activityUserId == currentUserId) return null;

  final name = knownStoredName(updated.lastActivityByDisplayName);
  final l = AppLocale.current;
  if (name == null) return l.shoppingListUpdatedByUnknown;
  return summarizeListChange(
        previous: previous.items,
        updated: updated.items,
        byName: name,
        l10n: l,
      ) ??
      l.shoppingListUpdatedByNotice(name);
}
