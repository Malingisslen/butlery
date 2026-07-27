// lib/services/unified/shopping_failure_message.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// The one place a failed shopping mutation becomes a Swedish sentence.
///
/// BUT-1696: a denied edit, a list that is gone and a broken connection are
/// three different things to tell someone standing in a shop, and collapsing
/// them into one message is what made a rejected tick look like a checkbox that
/// un-ticks itself. This mapping was written twice — once in
/// `ShoppingItemManagementModule` and once in `UnifiedShoppingService` — which
/// is exactly how a fourth failure class ends up handled in one seam and
/// silently mis-worded in the other.
///
/// [shared] picks the wording: telling someone their PERSONAL list is a shared
/// one they lack rights to is its own small lie.
String shoppingFailureMessage(Object error, {required bool shared}) {
  final noPermission = shared
      ? AppLocale.current.shoppingNoEditPermissionShared
      : AppLocale.current.shoppingNoEditPermission;
  return switch (error) {
    PermissionDeniedException() => noPermission,
    // A row that vanished is NOT a missing list. Saying "Lista hittades inte"
    // about a list the shopper is looking at is the invented cause this whole
    // mapping exists to remove, so the row case gets the cause-neutral message.
    ResourceNotFoundException(resourceType: 'shopping_item') =>
      AppLocale.current.errorGeneric,
    ResourceNotFoundException() => AppLocale.current.shoppingListNotFound,
    // A denial decided by the RULES rather than by a client-side guard arrives
    // as a raw FirebaseException. Without this arm the server's verdict would
    // reach the shopper as "check your connection".
    FirebaseException(code: 'permission-denied') => noPermission,
    FirebaseException(code: 'not-found') =>
      AppLocale.current.shoppingListNotFound,
    _ => AppLocale.current.errorNetwork,
  };
}
