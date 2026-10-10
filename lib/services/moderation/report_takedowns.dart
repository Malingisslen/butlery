import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

/// The moderator's takedown writes behind [ReportService]'s
/// `deleteReportedContent` and `suspendReportedProfile`, which wrap each
/// call in their service operation.
class ReportTakedowns {
  final FirestoreRepository _firestore;

  ReportTakedowns(this._firestore);

  /// The server takes `moderatorAction` off a report only when it closes, so
  /// a stamp written on an already-closed report would stay on it.
  bool refusesClosed(ContentReport report) {
    if (report.status != ReportStatus.closed) return false;
    AppLogger.warning(
      '[ReportService] takedown on closed report ${report.id}; refusing',
    );
    return true;
  }

  Future<bool> removeContent(ContentReport report) async {
    if (report.contentType == ContentType.menuDish) {
      return _removeMenuDish(report);
    }
    final ref = _resolveContentRef(report);
    if (ref == null) {
      AppLogger.warning(
        '[ReportService] Unknown contentType ${report.contentType}; cannot delete',
      );
      return false;
    }
    final batch = _firestore.firestore.batch()
      ..delete(ref)
      ..update(
        _reportRef(report),
        _moderatorAction(_ModeratorAction.contentRemoved),
      );
    // An owner who deleted the recipe first left a copy in their
    // trash, which they could restore after the moderator's delete
    // found nothing live to remove (BUT-907, risk R4).
    final trashCopy = _resolveTrashCopyRef(report);
    if (trashCopy != null) batch.delete(trashCopy);
    await batch.commit();
    AppLogger.info(
      '[ReportService] Admin deleted ${report.contentType}/${report.contentId} via report ${report.id}',
    );
    return true;
  }

  Future<bool> hideProfile(ContentReport report) async {
    if (report.contentType != ContentType.profile) {
      AppLogger.warning(
        '[ReportService] suspendReportedProfile called on contentType ${report.contentType}; refusing',
      );
      return false;
    }
    final ownerId = report.contentOwnerId;
    if (ownerId == null || ownerId.isEmpty) {
      AppLogger.warning(
        '[ReportService] profile report ${report.id} missing contentOwnerId',
      );
      return false;
    }
    await (_firestore.firestore.batch()
          ..update(
            _firestore
                .collection(FirestoreCollections.publicProfiles)
                .doc(ownerId),
            {'isHidden': true, 'hiddenAt': FieldValue.serverTimestamp()},
          )
          ..update(
            _reportRef(report),
            _moderatorAction(_ModeratorAction.profileHidden),
          ))
        .commit();
    AppLogger.info(
      '[ReportService] Admin hid profile ${ownerId.maskedUserId} via report ${report.id}',
    );
    return true;
  }

  // A menu dish is an element of the shared menu's `menuSnapshot`, not a
  // document, so the takedown rewrites that map and touches nothing else.
  Future<bool> _removeMenuDish(ContentReport report) async {
    final dishId = report.dishId;
    if (dishId == null || dishId.isEmpty) {
      AppLogger.warning(
        '[ReportService] menu_dish report ${report.id} has no dishId',
      );
      return false;
    }
    final ref = _firestore
        .collection(FirestoreCollections.sharedContent)
        .doc(report.contentId);
    final removed = await _firestore.firestore.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final snapshot = snap.data()?['menuSnapshot'];
      if (!snap.exists || snapshot is! Map) return false;
      var matched = false;
      final next = <String, dynamic>{};
      for (final entry in snapshot.entries) {
        final dishes = entry.value;
        if (dishes is! List) {
          next[entry.key.toString()] = dishes;
          continue;
        }
        next[entry.key.toString()] = dishes.where((dish) {
          final hit = dish is Map && dish['id'] == dishId;
          matched = matched || hit;
          return !hit;
        }).toList();
      }
      if (!matched) return false;
      tx.update(ref, {'menuSnapshot': next});
      tx.update(
        _reportRef(report),
        _moderatorAction(_ModeratorAction.contentRemoved),
      );
      return true;
    });
    if (!removed) {
      AppLogger.warning(
        '[ReportService] menu_dish report ${report.id}: no dish removed '
        '(shared menu missing or dish already gone)',
      );
      return false;
    }
    AppLogger.info(
      '[ReportService] Admin removed a dish from shared menu '
      '${report.contentId} via report ${report.id}',
    );
    return true;
  }

  DocumentReference<Map<String, dynamic>> _reportRef(ContentReport report) =>
      _firestore.collection(FirestoreCollections.reports).doc(report.id);

  /// BUT-2330: the takedown is stamped on the report in the same batch, so
  /// the server's decision record (`moderation/report-decision.ts`) can say
  /// what was done when the case closes. The server removes the field again
  /// at the close.
  Map<String, Object> _moderatorAction(_ModeratorAction action) => {
    'moderatorAction': action.wireName,
  };

  DocumentReference<Map<String, dynamic>>? _resolveTrashCopyRef(
    ContentReport report,
  ) {
    if (report.contentType != ContentType.recipe) return null;
    final ownerId = report.contentOwnerId;
    if (ownerId == null || ownerId.isEmpty) return null;
    return _firestore
        .collection(FirestoreCollections.users)
        .doc(ownerId)
        .collection(FirestoreCollections.userTrash)
        .doc(report.contentId);
  }

  DocumentReference<Map<String, dynamic>>? _resolveContentRef(
    ContentReport report,
  ) {
    switch (report.contentType) {
      case ContentType.recipe:
        // Recipes live under users/{ownerId}/recipes/{recipeId}.
        final ownerId = report.contentOwnerId;
        if (ownerId == null || ownerId.isEmpty) return null;
        return _firestore
            .collection(FirestoreCollections.users)
            .doc(ownerId)
            .collection(FirestoreCollections.userRecipes)
            .doc(report.contentId);
      case ContentType.comment:
        return _firestore
            .collection(FirestoreCollections.recipeComments)
            .doc(report.contentId);
      case ContentType.message:
        return _firestore
            .collection(FirestoreCollections.messages)
            .doc(report.contentId);
      case ContentType.cookSnap:
        return _firestore
            .collection(FirestoreCollections.cookSnaps)
            .doc(report.contentId);
      case ContentType.group:
        // FriendCategory lives under users/{ownerId}/friend_categories/{id};
        // we need the ownerId to resolve the path.
        final groupOwnerId = report.contentOwnerId;
        if (groupOwnerId == null || groupOwnerId.isEmpty) return null;
        return _firestore
            .collection(FirestoreCollections.users)
            .doc(groupOwnerId)
            .collection(FirestoreCollections.userFriendCategories)
            .doc(report.contentId);
      case ContentType.profile:
        // Profile uses a separate primitive — see hideProfile.
        return null;
      case ContentType.menuDish:
        // Not a document — see _removeMenuDish.
        return null;
    }
  }
}

/// Wire values shared with `MODERATOR_ACTIONS` in
/// `functions/src/moderation/report-decision.ts`.
enum _ModeratorAction {
  contentRemoved('content_removed'),
  profileHidden('profile_hidden')
  ;

  const _ModeratorAction(this.wireName);
  final String wireName;
}
