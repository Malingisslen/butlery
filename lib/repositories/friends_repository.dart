import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/friend_category.dart';
import '../models/group_invitation.dart';

class FriendsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _categoriesRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('friendCategories');
  }

  Future<List<FriendCategory>> fetchCategories(String userId) async {
    final query = await _categoriesRef(userId).get();
    final categories = query.docs.map((d) => FriendCategory.fromFirestore(d)).toList();
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return categories;
  }

  Future<void> saveCategory(String userId, FriendCategory category) {
    return _categoriesRef(userId).doc(category.id).set(category.toFirestore());
  }

  Future<void> updateCategory(String userId, String categoryId, Map<String, dynamic> data) {
    return _categoriesRef(userId).doc(categoryId).update(data);
  }

  Future<void> deleteCategory(String userId, String categoryId) {
    return _categoriesRef(userId).doc(categoryId).delete();
  }

  Future<FriendCategory?> getCategory(String userId, String categoryId) async {
    final doc = await _categoriesRef(userId).doc(categoryId).get();
    if (!doc.exists) return null;
    return FriendCategory.fromFirestore(doc);
  }

  Future<void> createCategoryForUser(String userId, FriendCategory category) {
    return _categoriesRef(userId)
        .doc(category.id)
        .set(category.toFirestore());
  }

  Future<void> updateCategoryMembers(String userId, String categoryId, List<String> members) {
    return _categoriesRef(userId).doc(categoryId).update({
      'friendUserIds': members,
      'friendCount': members.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  CollectionReference<Map<String, dynamic>> get _invitationsRef =>
      _firestore.collection('group_invitations');

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Stream<List<GroupInvitation>> receivedInvitationsStream(String userId) {
    return _invitationsRef
        .where('toUserId', isEqualTo: userId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => GroupInvitation.fromFirestore(d)).toList());
  }

  Stream<List<GroupInvitation>> sentInvitationsStream(String userId) {
    return _invitationsRef
        .where('fromUserId', isEqualTo: userId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => GroupInvitation.fromFirestore(d)).toList());
  }

  Future<GroupInvitation?> getInvitation(String id) async {
    final doc = await _invitationsRef.doc(id).get();
    if (!doc.exists) return null;
    return GroupInvitation.fromFirestore(doc);
  }

  Future<void> saveInvitation(GroupInvitation invitation) {
    return _invitationsRef.doc(invitation.id).set(invitation.toFirestore());
  }

  Future<void> updateInvitation(String id, Map<String, dynamic> data) {
    return _invitationsRef.doc(id).update(data);
  }

  Future<bool> hasPendingInvitation(String groupId, String toUserId) async {
    final query = await _invitationsRef
        .where('groupId', isEqualTo: groupId)
        .where('toUserId', isEqualTo: toUserId)
        .where('status', isEqualTo: GroupInvitationStatus.pending.name)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> oldInvitations(String userId, DateTime cutoff) async {
    final query = await _invitationsRef
        .where('toUserId', isEqualTo: userId)
        .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
        .get();
    return query.docs;
  }

  Future<void> deleteDocuments(List<DocumentReference> refs) async {
    final batch = _firestore.batch();
    for (final ref in refs) {
      batch.delete(ref);
    }
    await batch.commit();
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> expiredInvitations(Timestamp now) async {
    final query = await _invitationsRef
        .where('expiresAt', isLessThan: now)
        .where('status', isEqualTo: GroupInvitationStatus.pending.name)
        .get();
    return query.docs;
  }

  Future<void> updateDocuments(List<DocumentSnapshot> docs, Map<String, dynamic> updates) async {
    final batch = _firestore.batch();
    for (final doc in docs) {
      batch.update(doc.reference, updates);
    }
    await batch.commit();
  }
}
