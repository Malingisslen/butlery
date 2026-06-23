/// Firebase implementation of menu voting persistence.
/// Votes stored as subcollection: realtime_menus/{menuId}/votes/{voteId}

// lib/repositories/firebase/firebase_menu_voting_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/menu_voting_repository.dart';
import 'package:butlery/models/realtime/menu_slot_vote.dart';
import 'package:butlery/core/utils/logger.dart';

class FirebaseMenuVotingRepository extends BaseFirebaseRepository<MenuSlotVote>
    implements MenuVotingRepository {
  FirebaseMenuVotingRepository({
    required super.authRepository,
    super.firestore,
    super.auditRepository,
  });

  // Not used directly — votes live in subcollections
  @override
  String get collectionName => 'menu_votes';

  CollectionReference<Map<String, dynamic>> _votesRef(String menuId) =>
      firestore.collection('realtime_menus').doc(menuId).collection('votes');

  @override
  MenuSlotVote fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      MenuSlotVote.fromMap(doc.id, doc.data() ?? {});

  @override
  Map<String, dynamic> toFirestore(MenuSlotVote entity) => entity.toFirestore();

  @override
  String getId(MenuSlotVote entity) => entity.id;

  // --- Permission validators ---

  Future<bool> _isMenuParticipant(String menuId) async {
    final userId = requireCurrentUserId();
    final menuDoc = await firestore
        .collection('realtime_menus')
        .doc(menuId)
        .get();
    if (!menuDoc.exists) return false;
    final participantIds = menuDoc.data()?['participantIds'] as List?;
    return participantIds?.contains(userId) ?? false;
  }

  @override
  Future<bool> validateCreatePermission(
    String userId,
    MenuSlotVote entity,
  ) async => _isMenuParticipant(entity.menuId);

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    MenuSlotVote? entity,
  ) async => true; // Reads validated at query level

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    MenuSlotVote entity,
  ) async => _isMenuParticipant(entity.menuId);

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async => true; // Deletion handled by vote creator check

  // --- CRUD operations ---

  @override
  Future<MenuSlotVote> createVote(MenuSlotVote vote) async {
    final userId = requireCurrentUserId();
    await validateCreatePermission(userId, vote);

    await _votesRef(vote.menuId).doc(vote.id).set(vote.toFirestore());
    AppLogger.info('Created vote ${vote.id} for menu ${vote.menuId}');
    return vote;
  }

  @override
  Future<MenuSlotVote?> getVote(String menuId, String voteId) async {
    final doc = await _votesRef(menuId).doc(voteId).get();
    if (!doc.exists) return null;
    return MenuSlotVote.fromMap(doc.id, doc.data() ?? {});
  }

  @override
  Future<void> castVote(
    String menuId,
    String voteId,
    String userId,
    String optionId,
  ) async {
    await _votesRef(menuId).doc(voteId).update({
      'votes.$userId': optionId,
    });
  }

  @override
  Future<void> resolveVote(
    String menuId,
    String voteId,
    String winningOptionId,
  ) async {
    await firestore.runTransaction((transaction) async {
      final voteRef = _votesRef(menuId).doc(voteId);
      final snapshot = await transaction.get(voteRef);
      if (!snapshot.exists) return;

      transaction.update(voteRef, {
        'isResolved': true,
        'winningOptionId': winningOptionId,
      });
    });
  }

  @override
  Stream<List<MenuSlotVote>> watchVotesForMenu(String menuId) {
    // BUT-478: `.limit(200)` defence-in-depth — votes are bounded by group
    // size (a menu's voters are its group members), but without an explicit
    // limit a future feature change or adversarial write could blow up
    // snapshot payload on every change. 200 is well clear of any realistic
    // group size.
    return _votesRef(menuId)
        .limit(200)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MenuSlotVote.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> addAlternative(
    String menuId,
    String voteId,
    VoteOption option,
  ) async {
    await _votesRef(menuId).doc(voteId).update({
      'alternatives': FieldValue.arrayUnion([option.toFirestore()]),
    });
  }
}
