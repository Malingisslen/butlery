import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'friends_repository.dart';

class FirebaseFriendsRepository implements FriendsRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirebaseFriendsRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  @override
  CollectionReference<Map<String, dynamic>> get friendRequestsRef =>
      _firestore.collection('friend_requests');

  @override
  CollectionReference<Map<String, dynamic>> get profilesRef =>
      _firestore.collection('public_profiles');

  @override
  CollectionReference<Map<String, dynamic>> userFriendsCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('friends');

  @override
  WriteBatch batch() => _firestore.batch();

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;
}
