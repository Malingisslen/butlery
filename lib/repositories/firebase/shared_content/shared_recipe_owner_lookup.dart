import 'package:cloud_firestore/cloud_firestore.dart';

/// A share the current user made of one of their own recipes.
typedef OwnRecipeShare = ({
  String id,
  String ownerId,
  List<String> sharedToUserIds,
});

/// Finds the share rows a user made of their own recipe and unions their
/// recipients: every share writes its own row, so one recipe can have several.
///
/// Two writers produce these rows and they spell the recipe key differently:
/// the share repository writes `originalRecipeId`, `RecipeSharingManager`
/// writes `recipeId`. Both are read, as `removeRecipientsFromOwnShares` does.
/// The filter on `sharedByUserId` is the signed-in user, never a parameter, so
/// the query is the one `firestore.rules` allows the sharer to list.
class SharedRecipeOwnerLookup {
  SharedRecipeOwnerLookup(this._shares, this._currentUserId);

  final CollectionReference<Map<String, dynamic>> _shares;
  final String Function() _currentUserId;

  Future<OwnRecipeShare?> find(String recipeId) async {
    final uid = _currentUserId();
    final snapshots = await Future.wait(
      ['originalRecipeId', 'recipeId'].map(
        (key) => _shares
            .where('contentType', isEqualTo: 'recipe')
            .where('sharedByUserId', isEqualTo: uid)
            .where(key, isEqualTo: recipeId)
            .get(),
      ),
    );
    String? firstId;
    final recipients = <String>{};
    for (final doc in snapshots.expand((s) => s.docs)) {
      firstId ??= doc.id;
      final ids = doc.data()['sharedToUserIds'];
      if (ids is List) recipients.addAll(ids.whereType<String>());
    }
    if (firstId == null) return null;
    return (id: firstId, ownerId: uid, sharedToUserIds: recipients.toList());
  }
}
