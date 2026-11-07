import 'package:cloud_firestore/cloud_firestore.dart';

/// Upper bound on rows read for one lookup. Every share writes its own row;
/// past the cap the sheet shows the marks it got rather than paying for the
/// rest.
const int ownMenuShareReadCap = 100;

/// The people the signed-in user has shared each of their saved menus with.
///
/// Only rows written after saving stamped `originalMenuId`, so older shares
/// and shares of the menu on screen carry no mark. Equality filters only, as `firestore.rules` lets the sharer list.
class SharedMenuOwnerLookup {
  SharedMenuOwnerLookup(this._shares, this._currentUserId);

  final CollectionReference<Map<String, dynamic>> _shares;
  final String Function() _currentUserId;

  Future<Map<String, Set<String>>> recipientsByMenu() async {
    final uid = _currentUserId();
    final snapshot = await _shares
        .where('contentType', isEqualTo: 'menu')
        .where('sharedByUserId', isEqualTo: uid)
        .limit(ownMenuShareReadCap)
        .get();
    final byMenu = <String, Set<String>>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['isActive'] == false) continue;
      final menuId = data['originalMenuId'];
      if (menuId is! String || menuId.isEmpty) continue;
      final ids = data['sharedToUserIds'];
      if (ids is! List) continue;
      final recipients = ids.whereType<String>().where((id) => id != uid);
      byMenu.putIfAbsent(menuId, () => <String>{}).addAll(recipients);
    }
    byMenu.removeWhere((_, recipients) => recipients.isEmpty);
    return byMenu;
  }
}
