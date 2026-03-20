// lib/services/presence_service.dart

import 'dart:async';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:flutter/widgets.dart';

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

  /// Returns true if the heartbeat is stale (older than the given threshold).
  /// A stale heartbeat means the user's app was likely killed without
  /// a graceful shutdown, so they should be treated as offline.
  bool isHeartbeatStale(Duration threshold) {
    return DateTime.now().difference(lastSeen) > threshold;
  }

  /// Returns the effective status, treating stale heartbeats as offline.
  PresenceStatus effectiveStatus(Duration heartbeatStaleThreshold) {
    if (status == PresenceStatus.offline) return PresenceStatus.offline;
    if (isHeartbeatStale(heartbeatStaleThreshold)) {
      return PresenceStatus.offline;
    }
    return status;
  }

  bool isTypingIn(String conversationId) {
    final typingTime = typingIn[conversationId];
    if (typingTime == null) return false;

    // Consider typing if within last 5 seconds
    return DateTime.now().difference(typingTime).inSeconds < 5;
  }
}

/// Service managing user presence and typing indicators
/// Handles:
/// - Online/offline status tracking
/// - Automatic presence updates
/// - Typing indicator management
/// - Last seen timestamps
/// **Firebase Structure:**
/// ```
/// /presence/{userId}
///   - status: "online" | "offline" | "away"
///   - lastSeen: Timestamp
///   - typingIn: { conversationId: Timestamp }
/// ```
class PresenceService extends BaseService with WidgetsBindingObserver {
  @override
  String get serviceName => 'PresenceService';
  final FirestoreRepository _firestoreRepository;
  final auth_repo.AuthRepository _authRepository;

  Timer? _heartbeatTimer;
  Timer? _typingCleanupTimer;
  final Map<String, Timer> _typingDebounceTimers = {};

  static const Duration _heartbeatInterval =
      Duration(minutes: 2); // Optimized: 50% write reduction
  static const Duration _heartbeatStaleThreshold =
      Duration(minutes: 4); // 2x heartbeat — treat as offline
  static const Duration _typingTimeout = Duration(seconds: 5);
  static const Duration _typingDebounce = Duration(milliseconds: 500);
  static const Duration _typingCleanupInterval =
      Duration(seconds: 30); // Optimized: 83% write reduction (#037)

  PresenceService({
    required FirestoreRepository firestoreRepository,
    required auth_repo.AuthRepository authRepository,
  })  : _firestoreRepository = firestoreRepository,
        _authRepository = authRepository;

  /// Access Firestore instance via repository
  FirebaseFirestore get _firestore => _firestoreRepository.firestore;

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
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _typingCleanupTimer?.cancel();

    for (final timer in _typingDebounceTimers.values) {
      timer.cancel();
    }
    _typingDebounceTimers.clear();

    // Set offline status
    await _setPresenceStatus(PresenceStatus.offline);
  }

  /// Reset all state for logout. Cancels timers and sets offline status.
  /// Safe to call mid-operation — timer cancellation is synchronous.
  Future<void> resetForLogout() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _typingCleanupTimer?.cancel();
    _typingCleanupTimer = null;

    for (final timer in _typingDebounceTimers.values) {
      timer.cancel();
    }
    _typingDebounceTimers.clear();

    // Best-effort offline status update (user is signing out)
    try {
      await _setPresenceStatus(PresenceStatus.offline);
    } catch (_) {
      // Ignore — user is leaving anyway
    }

    AppLogger.info('PresenceService reset for logout');
  }

  /// Get real-time presence stream for a user.
  /// Applies staleness check: if lastSeen is older than 2x heartbeat interval,
  /// the effective status is treated as offline regardless of stored value.
  Stream<UserPresence?> getPresenceStream(String userId) {
    return _firestore
        .collection(FirestoreCollections.presence)
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      final presence = UserPresence.fromFirestore(
        snapshot.data() as Map<String, dynamic>,
        userId,
      );
      final effectiveStatus =
          presence.effectiveStatus(_heartbeatStaleThreshold);
      if (effectiveStatus != presence.status) {
        return UserPresence(
          userId: presence.userId,
          status: effectiveStatus,
          lastSeen: presence.lastSeen,
          typingIn: presence.typingIn,
        );
      }
      return presence;
    });
  }

  /// Get presence for multiple users
  Stream<Map<String, UserPresence>> getMultiplePresenceStream(
      List<String> userIds) {
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
          .collection(FirestoreCollections.presence)
          .where(FieldPath.documentId, whereIn: batch)
          .snapshots()
          .map((snapshot) {
        final presenceMap = <String, UserPresence>{};
        for (final doc in snapshot.docs) {
          final presence = UserPresence.fromFirestore(
            doc.data(),
            doc.id,
          );
          final effectiveStatus =
              presence.effectiveStatus(_heartbeatStaleThreshold);
          presenceMap[doc.id] = effectiveStatus != presence.status
              ? UserPresence(
                  userId: presence.userId,
                  status: effectiveStatus,
                  lastSeen: presence.lastSeen,
                  typingIn: presence.typingIn,
                )
              : presence;
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
          .collection(FirestoreCollections.presence)
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
          .collection(FirestoreCollections.presence)
          .doc(currentUser.uid)
          .set({
        'typingIn.$conversationId': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      AppLogger.error('Failed to clear typing status', e);
    }
  }

  /// Get typing users in a conversation
  Stream<List<String>> getTypingUsersStream(
      String conversationId, List<String> participantIds) {
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

  /// Check if user is currently online.
  /// Returns false if the heartbeat is stale (app was likely killed).
  Future<bool> isUserOnline(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.presence)
          .doc(userId)
          .get();

      if (!snapshot.exists) return false;

      final presence = UserPresence.fromFirestore(
        snapshot.data() as Map<String, dynamic>,
        userId,
      );

      return presence.effectiveStatus(_heartbeatStaleThreshold) ==
          PresenceStatus.online;
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
          .collection(FirestoreCollections.presence)
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
    // Register lifecycle observer to set offline on app pause/detach.
    // This catches normal backgrounding; the staleness check on read
    // handles force-kill where no lifecycle callback fires.
    WidgetsBinding.instance.addObserver(this);
    AppLogger.debug(
        'Disconnect handler set up (lifecycle observer + staleness check)');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _setPresenceStatus(PresenceStatus.offline);
        _heartbeatTimer?.cancel();
        break;
      case AppLifecycleState.resumed:
        _setPresenceStatus(PresenceStatus.online);
        _startHeartbeat();
        break;
      default:
        break;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _setPresenceStatus(PresenceStatus.online);
    });
  }

  void _startTypingCleanup() {
    _typingCleanupTimer?.cancel();
    _typingCleanupTimer = Timer.periodic(_typingCleanupInterval, (_) {
      _cleanupStaleTypingIndicators();
    });
  }

  Future<void> _cleanupStaleTypingIndicators() async {
    try {
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) return;

      final snapshot = await _firestore
          .collection(FirestoreCollections.presence)
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
            .collection(FirestoreCollections.presence)
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

    // Use Rx.combineLatest to merge all streams without blocking
    return _combineLatestMaps(streams);
  }

  /// Combines multiple map streams, emitting the merged map whenever any stream updates.
  Stream<Map<String, UserPresence>> _combineLatestMaps(
    List<Stream<Map<String, UserPresence>>> streams,
  ) {
    final latestValues =
        List<Map<String, UserPresence>?>.filled(streams.length, null);
    final controller = StreamController<Map<String, UserPresence>>.broadcast();
    final subscriptions = <StreamSubscription<Map<String, UserPresence>>>[];

    for (var i = 0; i < streams.length; i++) {
      final index = i;
      subscriptions.add(streams[index].listen(
        (map) {
          latestValues[index] = map;
          // Emit combined map only when all streams have emitted at least once
          if (latestValues.every((v) => v != null)) {
            final combined = <String, UserPresence>{};
            for (final map in latestValues) {
              combined.addAll(map!);
            }
            controller.add(combined);
          }
        },
        onError: controller.addError,
      ));
    }

    controller.onCancel = () {
      for (final sub in subscriptions) {
        sub.cancel();
      }
      controller.close();
    };

    return controller.stream;
  }
}
