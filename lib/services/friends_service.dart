// lib/services/friends_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../models/friend_request.dart';
import 'package:butlery/core/utils/logger.dart';
import '../core/error/error_handler.dart';


class FriendsService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State
  List<UserProfile> _friends = [];
  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> _sentRequests = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<UserProfile> get friends => List.unmodifiable(_friends);
  List<FriendRequest> get incomingRequests =>
      List.unmodifiable(_incomingRequests);
  List<FriendRequest> get sentRequests => List.unmodifiable(_sentRequests);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  String? get currentUserId => _auth.currentUser?.uid;
  int get friendsCount => _friends.length;
  int get pendingRequestsCount => _incomingRequests.length;

  /// Firestore references
  CollectionReference get _friendRequestsRef =>
      _firestore.collection('friend_requests');

  CollectionReference get _profilesRef =>
      _firestore.collection('public_profiles');

  /// Initialize service
  Future<void> initialize() async {
    AppLogger.info('🔄 Initialiserar FriendsService...');

    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _loadFriends();
        _loadFriendRequests();
      } else {
        _friends.clear();
        _incomingRequests.clear();
        _sentRequests.clear();
        notifyListeners();
      }
    });

    if (_auth.currentUser != null) {
      await _loadFriends();
      await _loadFriendRequests();
    }
  }

  /// Send friend request
  Future<bool> sendFriendRequest(String toUserId, {String? message}) async {
    final fromUserId = currentUserId;
    if (fromUserId == null) {
      _setError('Ingen användare inloggad');
      return false;
    }

    if (fromUserId == toUserId) {
      _setError('Du kan inte skicka vänförfrågan till dig själv');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      // Check if already friends
      if (await _areAlreadyFriends(fromUserId, toUserId)) {
        _setError('Ni är redan vänner');
        return false;
      }

      // Check if request already exists
      if (await _requestExists(fromUserId, toUserId)) {
        _setError('Vänförfrågan redan skickad');
        return false;
      }

      // Create friend request
      final request = FriendRequest.create(
        fromUserId: fromUserId,
        toUserId: toUserId,
        message: message,
      );

      await _friendRequestsRef.doc(request.id).set(request.toFirestore());

      // Add to sent requests
      _sentRequests.add(request);

      AppLogger.success('✅ Vänförfrågan skickad till $toUserId');
      notifyListeners();
      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte skicka vänförfrågan', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Accept friend request
  Future<bool> acceptFriendRequest(String requestId) async {
    final userId = currentUserId;
    if (userId == null) {
      _setError('Ingen användare inloggad');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      // Get the request
      final requestDoc = await _friendRequestsRef.doc(requestId).get();
      if (!requestDoc.exists) {
        _setError('Vänförfrågan hittades inte');
        return false;
      }

      final request = FriendRequest.fromFirestore(requestDoc);
      if (request.toUserId != userId) {
        _setError('Du kan bara acceptera förfrågningar skickade till dig');
        return false;
      }

      if (!request.isPending) {
        _setError('Vänförfrågan är inte längre aktiv');
        return false;
      }

      // Update request status
      final acceptedRequest = request.accept();
      await _friendRequestsRef
          .doc(requestId)
          .update(acceptedRequest.toFirestore());

      // Add to both users' friends lists
      await _addMutualFriends(request.fromUserId, request.toUserId);

      // Remove from incoming requests
      _incomingRequests.removeWhere((r) => r.id == requestId);

      // Reload friends list
      await _loadFriends();

      AppLogger.success('✅ Vänförfrågan accepterad från ${request.fromUserId}');
      notifyListeners();
      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte acceptera vänförfrågan', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Reject friend request
  Future<bool> rejectFriendRequest(String requestId) async {
    final userId = currentUserId;
    if (userId == null) {
      _setError('Ingen användare inloggad');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      // Get the request
      final requestDoc = await _friendRequestsRef.doc(requestId).get();
      if (!requestDoc.exists) {
        _setError('Vänförfrågan hittades inte');
        return false;
      }

      final request = FriendRequest.fromFirestore(requestDoc);
      if (request.toUserId != userId) {
        _setError('Du kan bara avvisa förfrågningar skickade till dig');
        return false;
      }

      // Update request status
      final rejectedRequest = request.reject();
      await _friendRequestsRef
          .doc(requestId)
          .update(rejectedRequest.toFirestore());

      // Remove from incoming requests
      _incomingRequests.removeWhere((r) => r.id == requestId);

      AppLogger.info('❌ Vänförfrågan avvisad från ${request.fromUserId}');
      notifyListeners();
      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte avvisa vänförfrågan', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Remove friend (unfriend)
  Future<bool> removeFriend(String friendUserId) async {
    final userId = currentUserId;
    if (userId == null) {
      _setError('Ingen användare inloggad');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      // Remove from both users' friends lists
      await _removeMutualFriends(userId, friendUserId);

      // Remove from local list
      _friends.removeWhere((f) => f.uid == friendUserId);

      AppLogger.info('👋 Vänskap avslutad med $friendUserId');
      notifyListeners();
      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte ta bort vän', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Cancel sent friend request
  Future<bool> cancelSentRequest(String requestId) async {
    try {
      _setLoading(true);
      _clearError();

      // Update request status to cancelled
      await _friendRequestsRef.doc(requestId).update({
        'status': FriendRequestStatus.cancelled.name,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Remove from sent requests
      _sentRequests.removeWhere((r) => r.id == requestId);

      AppLogger.info('🚫 Skickad vänförfrågan avbruten');
      notifyListeners();
      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte avbryta vänförfrågan', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Check if two users are friends
  Future<bool> areFriends(String userId1, String userId2) async {
    try {
      return await _areAlreadyFriends(userId1, userId2);
    } catch (e) {
      AppLogger.error('Kunde inte kontrollera vänskap', e);
      return false;
    }
  }

  /// Get mutual friends between current user and another user
  Future<List<UserProfile>> getMutualFriends(String otherUserId) async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      // Get other user's friends
      final otherUserFriendsRef =
          _firestore.collection('users').doc(otherUserId).collection('friends');

      final otherFriendsQuery = await otherUserFriendsRef.get();
      final otherFriendIds =
          otherFriendsQuery.docs.map((doc) => doc.id).toSet();

      // Find mutual friends
      final mutualFriendIds = _friends
          .map((f) => f.uid)
          .where((id) => otherFriendIds.contains(id))
          .toList();

      // Return the UserProfile objects for mutual friends
      return _friends.where((f) => mutualFriendIds.contains(f.uid)).toList();
    } catch (e) {
      AppLogger.error('Kunde inte hämta gemensamma vänner', e);
      return [];
    }
  }

  /// Private methods
  Future<void> _loadFriends() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      final friendsRef =
          _firestore.collection('users').doc(userId).collection('friends');

      final snapshot = await friendsRef.get();
      final friendIds = snapshot.docs.map((doc) => doc.id).toList();

      if (friendIds.isNotEmpty) {
        // Fetch friend profiles in batches
        _friends = await _getUserProfilesBatch(friendIds);
      } else {
        _friends = [];
      }

      AppLogger.info('👥 ${_friends.length} vänner laddade');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Kunde inte ladda vänner', e);
    }
  }

  Future<void> _loadFriendRequests() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      // Load incoming requests
      final incomingQuery = await _friendRequestsRef
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: FriendRequestStatus.pending.name)
          .get();

      _incomingRequests = incomingQuery.docs
          .map((doc) => FriendRequest.fromFirestore(doc))
          .where((req) => !req.isExpired)
          .toList();

      // Load sent requests
      final sentQuery = await _friendRequestsRef
          .where('fromUserId', isEqualTo: userId)
          .where('status', isEqualTo: FriendRequestStatus.pending.name)
          .get();

      _sentRequests = sentQuery.docs
          .map((doc) => FriendRequest.fromFirestore(doc))
          .where((req) => !req.isExpired)
          .toList();

      AppLogger.info(
        '📨 ${_incomingRequests.length} inkommande, ${_sentRequests.length} skickade förfrågningar',
      );
      notifyListeners();
    } catch (e) {
      AppLogger.error('Kunde inte ladda vänförfrågningar', e);
    }
  }

  Future<bool> _areAlreadyFriends(String userId1, String userId2) async {
    try {
      final friendDoc = await _firestore
          .collection('users')
          .doc(userId1)
          .collection('friends')
          .doc(userId2)
          .get();

      return friendDoc.exists;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _requestExists(String fromUserId, String toUserId) async {
    try {
      final query = await _friendRequestsRef
          .where('fromUserId', isEqualTo: fromUserId)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: FriendRequestStatus.pending.name)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _addMutualFriends(String userId1, String userId2) async {
    final batch = _firestore.batch();

    // Add user2 to user1's friends
    final user1FriendRef = _firestore
        .collection('users')
        .doc(userId1)
        .collection('friends')
        .doc(userId2);

    batch.set(user1FriendRef, {'addedAt': FieldValue.serverTimestamp()});

    // Add user1 to user2's friends
    final user2FriendRef = _firestore
        .collection('users')
        .doc(userId2)
        .collection('friends')
        .doc(userId1);

    batch.set(user2FriendRef, {'addedAt': FieldValue.serverTimestamp()});

    // Update friend counts in profiles
    final user1ProfileRef = _profilesRef.doc(userId1);
    final user2ProfileRef = _profilesRef.doc(userId2);

    batch.update(user1ProfileRef, {'friendsCount': FieldValue.increment(1)});

    batch.update(user2ProfileRef, {'friendsCount': FieldValue.increment(1)});

    await batch.commit();
  }

  Future<void> _removeMutualFriends(String userId1, String userId2) async {
    final batch = _firestore.batch();

    // Remove from both friends collections
    final user1FriendRef = _firestore
        .collection('users')
        .doc(userId1)
        .collection('friends')
        .doc(userId2);

    final user2FriendRef = _firestore
        .collection('users')
        .doc(userId2)
        .collection('friends')
        .doc(userId1);

    batch.delete(user1FriendRef);
    batch.delete(user2FriendRef);

    // Update friend counts in profiles
    final user1ProfileRef = _profilesRef.doc(userId1);
    final user2ProfileRef = _profilesRef.doc(userId2);

    batch.update(user1ProfileRef, {'friendsCount': FieldValue.increment(-1)});

    batch.update(user2ProfileRef, {'friendsCount': FieldValue.increment(-1)});

    await batch.commit();
  }

  Future<List<UserProfile>> _getUserProfilesBatch(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    final profiles = <UserProfile>[];
    const batchSize = 10; // Firestore whereIn limit

    for (int i = 0; i < userIds.length; i += batchSize) {
      final batch = userIds.skip(i).take(batchSize).toList();

      try {
        final query = await _profilesRef
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in query.docs) {
          try {
            profiles.add(UserProfile.fromFirestore(doc));
          } catch (e) {
            AppLogger.warning('Kunde inte parsa vänprofil ${doc.id}: $e');
          }
        }
      } catch (e) {
        AppLogger.error('Kunde inte hämta profilbatch', e);
      }
    }

    return profiles;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Refresh all data
  Future<void> refresh() async {
    await _loadFriends();
    await _loadFriendRequests();
  }

  /// Public method to load friends - ADDED FOR VECKOMENY_VIEW
  Future<void> loadFriends() async {
    AppLogger.info('🔄 Public loadFriends called');
    await _loadFriends();
  }
}
