/// Firebase implementation of menu voting persistence.

// lib/repositories/firebase/firebase_menu_voting_repository.dart

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/realtime/menu_ballot.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/menu_voting_repository.dart';

/// `realtime_resources/{menuId}/votes/{uid}`: each person writes only their
/// own document, which is what lets `firestore.rules` pin a ballot to its
/// voter by path (BUT-2118).
class FirebaseMenuVotingRepository extends BaseFirebaseRepository<MenuBallot>
    implements MenuVotingRepository {
  FirebaseMenuVotingRepository({
    required super.authRepository,
    super.firestore,
    super.auditRepository,
  });

  /// The rules accept an `expireAt` up to 91 days ahead of the server's
  /// clock; 60 leaves room for a phone whose clock runs ahead.
  static const Duration retention = Duration(days: 60);

  // Bounded by the people on a menu; the limit keeps a flood of stray
  // documents from growing every listener's snapshot.
  static const int maxBallots = 200;

  @override
  String get collectionName => FirestoreCollections.liveMenuVotes;

  CollectionReference<Map<String, dynamic>> _votesRef(String menuId) =>
      firestore
          .collection(FirestoreCollections.realtimeResources)
          .doc(menuId)
          .collection(FirestoreCollections.liveMenuVotes);

  @override
  MenuBallot fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      MenuBallot.fromMap(doc.id, doc.data() ?? const {});

  @override
  Map<String, dynamic> toFirestore(MenuBallot entity) => {
    ...entity.toFirestore(),
    'updatedAt': FieldValue.serverTimestamp(),
    'expireAt': Timestamp.fromDate(clock.now().add(retention)),
  };

  @override
  String getId(MenuBallot entity) => entity.userId;

  // Who may vote on which menu is decided by the rules, which read the
  // menu's roster; the client check is only that a document is the caller's.
  @override
  Future<bool> validateCreatePermission(
    String userId,
    MenuBallot entity,
  ) async => entity.userId == userId;

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    MenuBallot? entity,
  ) async => true;

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    MenuBallot entity,
  ) async => entity.userId == userId && resourceId == userId;

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async => resourceId == userId;

  @override
  Stream<List<MenuBallot>> watchBallots(String menuId) => _votesRef(menuId)
      .limit(maxBallots)
      .snapshots()
      .map((snap) => snap.docs.map(fromFirestore).toList());

  @override
  Future<void> updateOwnBallot(
    String menuId,
    MenuBallot Function(MenuBallot current) change,
  ) async {
    final userId = requireCurrentUserId();
    final ref = _votesRef(menuId).doc(userId);
    await firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = snap.exists
          ? fromFirestore(snap)
          : MenuBallot(userId: userId);
      final next = change(current);
      if (identical(next, current)) return;
      final allowed = await validateUpdatePermission(userId, userId, next);
      if (!allowed) {
        await logPermissionCheck(
          userId: userId,
          resource: 'MenuBallot/$menuId/$userId',
          operation: 'update',
          granted: false,
          auditRepository: auditRepository,
        );
        throw PermissionDeniedException(
          'A ballot document can only be written by its owner',
        );
      }
      tx.set(ref, toFirestore(next));
    });
  }
}
