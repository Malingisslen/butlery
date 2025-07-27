// lib/services/unified/friends/friends_presence_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';

/// Friends presence service
/// 
/// Handles real-time presence tracking for friends:
/// - Online/offline status
/// - Last seen timestamps
/// - Activity indicators
/// - Presence subscriptions
class FriendsPresenceService {
  final FirebaseFirestore _firestore;
  final Map<String, StreamSubscription> _presenceSubscriptions = {};
  final Map<String, bool> _presenceStatus = {};
  
  FriendsPresenceService(this._firestore);
  
  String? get currentUserId => sl<PermissionService>().currentUserId;
  
  /// Get presence status for a friend
  bool getFriendPresence(String friendId) {
    return _presenceStatus[friendId] ?? false;
  }
  
  /// Get all friends' presence status
  Map<String, bool> getAllPresenceStatus() {
    return Map.unmodifiable(_presenceStatus);
  }
  
  /// Subscribe to friend's presence
  void subscribeToFriendPresence(String friendId) {
    if (_presenceSubscriptions.containsKey(friendId)) {
      return; // Already subscribed
    }
    
    try {
      // ignore: cancel_subscriptions - cancelled in dispose()
      final subscription = _firestore
          .collection('users')
          .doc(friendId)
          .snapshots()
          .listen((doc) {
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final isOnline = data['isOnline'] ?? false;
          final lastActiveAt = data['lastActiveAt'] as Timestamp?;
          
          // Consider user online if they were active in the last 5 minutes
          bool effectivelyOnline = isOnline;
          if (!isOnline && lastActiveAt != null) {
            final lastActive = lastActiveAt.toDate();
            final now = DateTime.now();
            effectivelyOnline = now.difference(lastActive).inMinutes < 5;
          }
          
          _presenceStatus[friendId] = effectivelyOnline;
          onPresenceChanged?.call(friendId, effectivelyOnline);
          
          AppLogger.debug('Friend presence updated: $friendId -> $effectivelyOnline');
        }
      });
      
      _presenceSubscriptions[friendId] = subscription;
    } catch (e) {
      AppLogger.error('Failed to subscribe to friend presence: $e');
    }
  }
  
  /// Unsubscribe from friend's presence
  void unsubscribeFromFriendPresence(String friendId) {
    final subscription = _presenceSubscriptions.remove(friendId);
    subscription?.cancel();
    _presenceStatus.remove(friendId);
    
    AppLogger.debug('Unsubscribed from friend presence: $friendId');
  }
  
  /// Subscribe to multiple friends' presence
  void subscribeToFriendsPresence(List<String> friendIds) {
    for (final friendId in friendIds) {
      subscribeToFriendPresence(friendId);
    }
  }
  
  /// Unsubscribe from multiple friends' presence
  void unsubscribeFromFriendsPresence(List<String> friendIds) {
    for (final friendId in friendIds) {
      unsubscribeFromFriendPresence(friendId);
    }
  }
  
  /// Update current user's presence
  Future<void> updateMyPresence(bool isOnline) async {
    if (currentUserId == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .update({
        'isOnline': isOnline,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
      
      AppLogger.debug('My presence updated: $isOnline');
    } catch (e) {
      AppLogger.error('Failed to update my presence: $e');
    }
  }
  
  /// Set up presence for current user (call when app starts)
  Future<void> setupMyPresence() async {
    if (currentUserId == null) return;
    
    try {
      // Set online status
      await updateMyPresence(true);
      
      // Set up offline cleanup when user disconnects
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .update({
        'isOnline': false,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
      
      AppLogger.debug('Presence setup completed for current user');
    } catch (e) {
      AppLogger.error('Failed to setup presence: $e');
    }
  }
  
  /// Clean up presence (call when app closes)
  Future<void> cleanupMyPresence() async {
    if (currentUserId == null) return;
    
    try {
      await updateMyPresence(false);
      AppLogger.debug('Presence cleanup completed for current user');
    } catch (e) {
      AppLogger.error('Failed to cleanup presence: $e');
    }
  }
  
  /// Get friends who are currently online
  List<String> getOnlineFriends() {
    return _presenceStatus.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }
  
  /// Get friends who are currently offline
  List<String> getOfflineFriends() {
    return _presenceStatus.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();
  }
  
  /// Get online friends count
  int getOnlineFriendsCount() {
    return _presenceStatus.values.where((isOnline) => isOnline).length;
  }
  
  /// Dispose all subscriptions
  void dispose() {
    for (final subscription in _presenceSubscriptions.values) {
      subscription.cancel();
    }
    _presenceSubscriptions.clear();
    _presenceStatus.clear();
    
    AppLogger.debug('Friends presence service disposed');
  }
  
  // ===== CALLBACKS =====
  
  /// Called when a friend's presence changes
  Function(String friendId, bool isOnline)? onPresenceChanged;
}