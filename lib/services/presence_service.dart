import 'dart:async';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';
import 'package:rxdart/rxdart.dart';

enum PresenceStatus { online, offline, away }

/// User presence data combining RTDB status with Firestore typing indicators.
class UserPresence {
  final String userId;
  final PresenceStatus status;
  final DateTime lastSeen;
  final Map<String, DateTime> typingIn;

  const UserPresence({
    required this.userId,
    required this.status,
    required this.lastSeen,
    this.typingIn = const {},
  });

  /// Parse from RTDB event data (status + lastSeen only).
  factory UserPresence.fromRtdb(Map<dynamic, dynamic> data, String userId) {
    return UserPresence(
      userId: userId,
      status: _parseStatus(data['status'] as String?),
      lastSeen: data['lastSeen'] is int
          ? DateTime.fromMillisecondsSinceEpoch(data['lastSeen'] as int)
          : DateTime.now(),
    );
  }

  /// Parse from Firestore (typing indicators only — merged with RTDB data).
  factory UserPresence.fromFirestore(Map<String, dynamic> data, String userId) {
    return UserPresence(
      userId: userId,
      status: _parseStatus(data['status'] as String?),
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      typingIn: _parseTypingMap(data['typingIn'] as Map<String, dynamic>?),
    );
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
      if (v is Timestamp) return MapEntry(k, v.toDate());
      return MapEntry(k, DateTime.now());
    });
  }

  bool isTypingIn(String conversationId) {
    final typingTime = typingIn[conversationId];
    if (typingTime == null) return false;
    return DateTime.now().difference(typingTime).inSeconds < 5;
  }
}

/// Hybrid presence service: RTDB for online/offline (server-side onDisconnect),
/// Firestore for typing indicators (field-level merge/delete).
class PresenceService extends BaseService with WidgetsBindingObserver {
  @override
  String get serviceName => 'PresenceService';

  final FirestoreRepository _firestoreRepository;
  final auth_repo.AuthRepository _authRepository;
  final FirebaseDatabase _database;

  bool _isInitialized = false;
  Timer? _typingCleanupTimer;
  final Map<String, Timer> _typingDebounceTimers = {};
  DatabaseReference? _presenceRef;

  static const Duration _typingTimeout = Duration(seconds: 5);
  static const Duration _typingDebounce = Duration(milliseconds: 500);
  static const Duration _typingCleanupInterval = Duration(seconds: 30);

  PresenceService({
    required FirestoreRepository firestoreRepository,
    required auth_repo.AuthRepository authRepository,
    required FirebaseDatabase database,
  })  : _firestoreRepository = firestoreRepository,
        _authRepository = authRepository,
        _database = database;

  FirebaseFirestore get _firestore => _firestoreRepository.firestore;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        AppLogger.warning('Cannot initialize presence: No authenticated user');
        return;
      }

      // Skip RTDB if no databaseURL is configured — calling ref() would
      // trigger a Firebase JS SDK fatal() that logs to console even though
      // Dart catches the exception.
      if (_database.app.options.databaseURL == null) {
        AppLogger.warning('RTDB not configured — presence tracking disabled');
        return;
      }

      AppLogger.info(
          'Initializing presence for user: ${currentUser.uid.maskedUserId}');

      _presenceRef = _database.ref('presence/${currentUser.uid}');

      // Register disconnect handler BEFORE setting online — if the process
      // dies between these two calls, onDisconnect is already in place.
      // Timeout prevents hanging boot on flaky networks (BUG-043 RC2).
      await _presenceRef!
          .onDisconnect()
          .set({'status': 'offline', 'lastSeen': ServerValue.timestamp})
          .timeout(const Duration(seconds: 5), onTimeout: () {
        AppLogger.warning('RTDB onDisconnect timed out (5s)');
      });
      await _presenceRef!
          .set({'status': 'online', 'lastSeen': ServerValue.timestamp})
          .timeout(const Duration(seconds: 5), onTimeout: () {
        AppLogger.warning('RTDB presence set timed out (5s)');
      });

      // Register lifecycle observer for graceful backgrounding
      WidgetsBinding.instance.addObserver(this);

      // Start typing cleanup timer (Firestore)
      _startTypingCleanup();

      _isInitialized = true;
      AppLogger.success('Presence tracking initialized (RTDB + onDisconnect)');
    } catch (e) {
      AppLogger.error('Failed to initialize presence', e);
    }
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _typingCleanupTimer?.cancel();
    for (final timer in _typingDebounceTimers.values) {
      timer.cancel();
    }
    _typingDebounceTimers.clear();

    // Set offline in RTDB and cancel the onDisconnect handler
    try {
      await _presenceRef
          ?.set({'status': 'offline', 'lastSeen': ServerValue.timestamp});
      await _presenceRef?.onDisconnect().cancel();
    } catch (e) {
      AppLogger.warning('Failed to set offline status on dispose: $e');
    }
    _presenceRef = null;
  }

  Future<void> resetForLogout() async {
    _typingCleanupTimer?.cancel();
    _typingCleanupTimer = null;
    for (final timer in _typingDebounceTimers.values) {
      timer.cancel();
    }
    _typingDebounceTimers.clear();

    try {
      await _presenceRef
          ?.set({'status': 'offline', 'lastSeen': ServerValue.timestamp});
      await _presenceRef?.onDisconnect().cancel();
    } catch (e) {
      AppLogger.warning('Failed to set offline status on logout: $e');
    }
    _presenceRef = null;

    AppLogger.info('PresenceService reset for logout');
  }

  /// Stream a single user's presence from RTDB.
  Stream<UserPresence?> getPresenceStream(String userId) {
    return _database.ref('presence/$userId').onValue.map((event) {
      if (event.snapshot.value == null) return null;
      final data = Map<dynamic, dynamic>.from(
          event.snapshot.value as Map<dynamic, dynamic>);
      return UserPresence.fromRtdb(data, userId);
    });
  }

  /// Stream presence for multiple users via individual RTDB listeners.
  Stream<Map<String, UserPresence>> getMultiplePresenceStream(
      List<String> userIds) {
    if (userIds.isEmpty) return Stream.value({});

    final latestValues = <String, UserPresence>{};
    final controller = StreamController<Map<String, UserPresence>>.broadcast();
    final subscriptions = <StreamSubscription<DatabaseEvent>>[];

    for (final userId in userIds) {
      subscriptions.add(
        _database.ref('presence/$userId').onValue.listen(
          (event) {
            if (event.snapshot.value != null) {
              final data = Map<dynamic, dynamic>.from(
                  event.snapshot.value as Map<dynamic, dynamic>);
              latestValues[userId] = UserPresence.fromRtdb(data, userId);
            } else {
              latestValues.remove(userId);
            }
            controller.add(Map.unmodifiable(latestValues));
          },
          onError: controller.addError,
        ),
      );
    }

    controller.onCancel = () {
      for (final sub in subscriptions) {
        sub.cancel();
      }
      controller.close();
    };

    return controller.stream;
  }

  Future<void> startTyping(String conversationId) async {
    try {
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) return;

      _typingDebounceTimers[conversationId]?.cancel();

      await _firestore
          .collection(FirestoreCollections.presence)
          .doc(currentUser.uid)
          .set({
        'typingIn.$conversationId': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _typingDebounceTimers[conversationId] = Timer(_typingDebounce, () {
        stopTyping(conversationId);
      });
    } catch (e) {
      AppLogger.error('Failed to set typing status', e);
    }
  }

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

  /// Typing users derived from Firestore presence docs (typingIn field).
  Stream<List<String>> getTypingUsersStream(
      String conversationId, List<String> participantIds) {
    if (participantIds.isEmpty) return Stream.value([]);

    // Typing data is in Firestore — batch query with whereIn (max 10)
    final batches = <List<String>>[];
    for (var i = 0; i < participantIds.length; i += 10) {
      batches.add(participantIds.sublist(
          i, i + 10 > participantIds.length ? participantIds.length : i + 10));
    }

    final streams = batches.map((batch) {
      return _firestore
          .collection(FirestoreCollections.presence)
          .where(FieldPath.documentId, whereIn: batch)
          .snapshots()
          .map((snapshot) {
        final typing = <String>[];
        for (final doc in snapshot.docs) {
          final presence = UserPresence.fromFirestore(doc.data(), doc.id);
          if (presence.isTypingIn(conversationId)) {
            typing.add(doc.id);
          }
        }
        return typing;
      });
    }).toList();

    if (streams.length == 1) return streams.first;
    return _combineTypingStreams(streams);
  }

  Future<bool> isUserOnline(String userId) async {
    try {
      final snapshot = await _database.ref('presence/$userId').get();
      if (!snapshot.exists || snapshot.value == null) return false;
      final data =
          Map<dynamic, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
      return data['status'] == 'online';
    } catch (e) {
      AppLogger.error('Failed to check online status', e);
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Set offline explicitly for graceful backgrounding
        _presenceRef
            ?.set({'status': 'offline', 'lastSeen': ServerValue.timestamp});
        break;
      case AppLifecycleState.resumed:
        // Re-establish onDisconnect first, then set online
        _presenceRef
            ?.onDisconnect()
            .set({'status': 'offline', 'lastSeen': ServerValue.timestamp});
        _presenceRef
            ?.set({'status': 'online', 'lastSeen': ServerValue.timestamp});
        break;
      default:
        break;
    }
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

      final now = DateTime.now();
      final updates = <String, dynamic>{};
      for (final entry in typingIn.entries) {
        final timestamp = SerializationUtils.parseDateTimeValue(entry.value) ??
            DateTime.now();
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

  Stream<List<String>> _combineTypingStreams(
      List<Stream<List<String>>> streams) {
    return Rx.combineLatestList(streams)
        .map((lists) => lists.expand((l) => l).toList());
  }
}
