// lib/services/presence_service.dart

import 'dart:async';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth_repo;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Presence states for users
enum PresenceStatus {
  online,
  offline,
  away,
}

/// User presence data model
class UserPresence {
  final String userId;
  final PresenceStatus status;
  final DateTime lastSeen;
  final Map<String, DateTime> typingIn; // conversationId -> started typing at

  const UserPresence({
    required this.userId,
    required this.status,
    required this.lastSeen,
    this.typingIn = const {},
  });

  factory UserPresence.fromFirestore(Map<String, dynamic> data, String userId) {
    return UserPresence(
      userId: userId,
      status: _parseStatus(data['status'] as String?),
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      typingIn: _parseTypingMap(data['typingIn'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'status': status.name,
      'lastSeen': FieldValue.serverTimestamp(),
      'typingIn': typingIn.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
    };
  }

  static PresenceStatus _parseStatus(String? status) {
    switch (status) {
      case 'online':
        return PresenceStatus.online;
      case 'away':
        return PresenceStatus.away;
      default:
        return PresenceStatus.offline;
    }
  }

  static Map<String, DateTime> _parseTypingMap(Map<String, dynamic>? data) {
    if (data == null) return {};
    return data.map((k, v) {
      if (v is Timestamp) {
        return MapEntry(k, v.toDate());
      }
      return MapEntry(k, DateTime.now());
    });
  }

  bool isTypingIn(String conversationId) {
    final typingTime = typingIn[conversationId];
    if (typingTime == null) return false;

    // Consider typing if within last 5 seconds
    return DateTime.now().difference(typingTime).inSeconds < 5;
  }
}

/// Service managing user presence and typing indicators
///
/// Handles:
/// - Online/offline status tracking
/// - Automatic presence updates
/// - Typing indicator management
/// - Last seen timestamps
///
/// **Firebase Structure:**
/// ```
/// /presence/{userId}
///   - status: "online" | "offline" | "away"
///   - lastSeen: Timestamp
///   - typingIn: { conversationId: Timestamp }
/// ```
class PresenceService extends BaseService {
  @override
  String get serviceName => 'PresenceService';
  final FirebaseFirestore _firestore;
  final auth_repo.AuthRepository _authRepository;

  Timer? _heartbeatTimer;
  Timer? _typingCleanupTimer;
  final Map<String, Timer> _typingDebounceTimers = {};

  static const Duration _heartbeatInterval = Duration(minutes: 1);
  static const Duration _typingTimeout = Duration(seconds: 5);
  static const Duration _typingDebounce = Duration(milliseconds: 500);

  PresenceService({
    required FirebaseFirestore firestore,
    required auth_repo.AuthRepository authRepository,
  })  : _firestore = firestore,
        _authRepository = authRepository;

  /// Initialize presence tracking for current user
  @override
  Future<void> initialize() async {
    try {
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        AppLogger.warning('Cannot initialize presence: No authenticated user');
        return;
      }

      AppLogger.info('Initializing presence for user: ${currentUser.uid}');

      // Set initial online status
      await _setPresenceStatus(PresenceStatus.online);

      // Set up automatic offline on disconnect
      await _setupDisconnectHandler();

      // Start heartbeat to maintain online status
      _startHeartbeat();

      // Start typing cleanup timer
      _startTypingCleanup();

      AppLogger.success('Presence tracking initialized');
    } catch (e) {
      AppLogger.error('Failed to initialize presence', e);
    }
  }

  /// Clean up presence tracking
  @override
  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    _typingCleanupTimer?.cancel();

    for (final timer in _typingDebounceTimers.values) {
      timer.cancel();
    }
    _typingDebounceTimers.clear();

    // Set offline status
    await _setPresenceStatus(PresenceStatus.offline);
  }

  /// Get real-time presence stream for a user
  Stream<UserPresence?> getPresenceStream(String userId) {
    return _firestore
        .collection('presence')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return UserPresence.fromFirestore(
        snapshot.data() as Map<String, dynamic>,
        userId,
      );
    });
  }

  /// Get presence for multiple users
  Stream<Map<String, UserPresence>> getMultiplePresenceStream(List<String> userIds) {
    if (userIds.isEmpty) {
      return Stream.value({});
    }

    // Firestore 'in' queries limited to 10 items, so batch if needed
    final batches = <List<String>>[];
    for (var i = 0; i < userIds.length; i += 10) {
      batches.add(
        userIds.sublist(i, i + 10 > userIds.length ? userIds.length : i + 10),
      );
    }

    // Combine streams from all batches
    final streams = batches.map((batch) {
      return _firestore
          .collection('presence')
          .where(FieldPath.documentId, whereIn: batch)
          .snapshots()
          .map((snapshot) {
        final presenceMap = <String, UserPresence>{};
        for (final doc in snapshot.docs) {
          presenceMap[doc.id] = UserPresence.fromFirestore(
            doc.data(),
            doc.id,
          );
        }
        return presenceMap;
      });
    }).toList();

    // Merge all batch streams
    return _mergePresenceStreams(streams);
  }

  /// Mark user as typing in a conversation
  Future<void> startTyping(String conversationId) async {
    try {
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) return;

      // Cancel existing debounce timer for this conversation
      _typingDebounceTimers[conversationId]?.cancel();

      // Set typing status
      await _firestore
          .collection('presence')
          .doc(currentUser.uid)
          .set({
        'typingIn.$conversationId': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Set up debounce timer to auto-clear typing
      _typingDebounceTimers[conversationId] = Timer(_typingDebounce, () {
        stopTyping(conversationId);
      });
    } catch (e) {
      AppLogger.error('Failed to set typing status', e);
    }
  }

  /// Clear typing indicator for a conversation
  Future<void> stopTyping(String conversationId) async {
    try {
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) return;

      _typingDebounceTimers[conversationId]?.cancel();
      _typingDebounceTimers.remove(conversationId);

      await _firestore
          .collection('presence')
          .doc(currentUser.uid)
          .set({
        'typingIn.$conversationId': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      AppLogger.error('Failed to clear typing status', e);
    }
  }

  /// Get typing users in a conversation
  Stream<List<String>> getTypingUsersStream(String conversationId, List<String> participantIds) {
    if (participantIds.isEmpty) {
      return Stream.value([]);
    }

    return getMultiplePresenceStream(participantIds).map((presenceMap) {
      final typingUsers = <String>[];

      for (final entry in presenceMap.entries) {
        final presence = entry.value;
        if (presence.isTypingIn(conversationId)) {
          typingUsers.add(entry.key);
        }
      }

      return typingUsers;
    });
  }

  /// Check if user is currently online
  Future<bool> isUserOnline(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('presence')
          .doc(userId)
          .get();

      if (!snapshot.exists) return false;

      final presence = UserPresence.fromFirestore(
        snapshot.data() as Map<String, dynamic>,
        userId,
      );

      return presence.status == PresenceStatus.online;
    } catch (e) {
      AppLogger.error('Failed to check online status', e);
      return false;
    }
  }

  // Private methods

  Future<void> _setPresenceStatus(PresenceStatus status) async {
    try {
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) return;

      await _firestore
          .collection('presence')
          .doc(currentUser.uid)
          .set({
        'status': status.name,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      AppLogger.error('Failed to set presence status', e);
    }
  }

  Future<void> _setupDisconnectHandler() async {
    // Note: Firestore doesn't have native onDisconnect like Realtime Database
    // Instead, we rely on heartbeat timeout and app lifecycle
    // For production, consider using Firebase Realtime Database for presence
    // or implementing Cloud Functions to detect stale presence

    final currentUser = _authRepository.currentUser;
    if (currentUser == null) return;

    // Set offline status when dispose is called
    // In production, use Cloud Functions to detect stale lastSeen timestamps
    AppLogger.debug('Disconnect handler set up (manual cleanup on dispose)');
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _setPresenceStatus(PresenceStatus.online);
    });
  }

  void _startTypingCleanup() {
    _typingCleanupTimer?.cancel();
    _typingCleanupTimer = Timer.periodic(_typingTimeout, (_) {
      _cleanupStaleTypingIndicators();
    });
  }

  Future<void> _cleanupStaleTypingIndicators() async {
    try {
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) return;

      final snapshot = await _firestore
          .collection('presence')
          .doc(currentUser.uid)
          .get();

      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final typingIn = data['typingIn'] as Map<String, dynamic>?;

      if (typingIn == null || typingIn.isEmpty) return;

      // Remove stale typing indicators (older than timeout)
      final now = DateTime.now();
      final updates = <String, dynamic>{};

      for (final entry in typingIn.entries) {
        final timestamp = (entry.value as Timestamp).toDate();
        if (now.difference(timestamp) > _typingTimeout) {
          updates['typingIn.${entry.key}'] = FieldValue.delete();
        }
      }

      if (updates.isNotEmpty) {
        await _firestore
            .collection('presence')
            .doc(currentUser.uid)
            .update(updates);
      }
    } catch (e) {
      AppLogger.error('Failed to cleanup typing indicators', e);
    }
  }

  Stream<Map<String, UserPresence>> _mergePresenceStreams(
    List<Stream<Map<String, UserPresence>>> streams,
  ) {
    if (streams.isEmpty) return Stream.value({});
    if (streams.length == 1) return streams.first;

    // Combine multiple streams into one
    return streams.first.asyncMap((firstMap) async {
      final combined = Map<String, UserPresence>.from(firstMap);

      for (var i = 1; i < streams.length; i++) {
        await for (final map in streams[i].take(1)) {
          combined.addAll(map);
        }
      }

      return combined;
    });
  }
}
