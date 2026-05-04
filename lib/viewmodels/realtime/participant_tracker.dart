// lib/viewmodels/realtime/participant_tracker.dart

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Data for a participant's activity
class ParticipantActivity {
  final String userId;
  final String displayName;
  final DateTime lastSeen;
  final bool isOnline;

  ParticipantActivity({
    required this.userId,
    required this.displayName,
    required this.lastSeen,
    required this.isOnline,
  });

  /// Var deltagaren aktiv inom specifik tidsperiod?
  bool wasActiveWithin(Duration period) {
    return clock.now().difference(lastSeen) <= period;
  }

  @override
  String toString() =>
      'ParticipantActivity($displayName, $lastSeen, online: $isOnline)';
}

/// Tracker for participant activity in realtime resources
class ParticipantTracker {
  final Map<String, DateTime> _participantActivity = {};
  final Map<String, String> _participantNames = {};

  /// Callback when participant data is updated
  final VoidCallback? onUpdated;

  ParticipantTracker({this.onUpdated});

  /// Antal aktiva deltagare
  int get activeCount => _participantActivity.length;

  /// List of active participants
  List<String> get activeParticipantIds => _participantActivity.keys.toList();

  /// Alla participant activities
  List<ParticipantActivity> get allActivities {
    return _participantActivity.entries.map((entry) {
      return ParticipantActivity(
        userId: entry.key,
        displayName: getDisplayName(entry.key),
        lastSeen: entry.value,
        isOnline: wasRecentlyActive(entry.key, const Duration(minutes: 5)),
      );
    }).toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen)); // Most recent first
  }

  /// Update participant activity based on menu changes
  void updateFromMenu(RealtimeMenu menu) {
    // Update latest activity for the editor
    if (menu.lastEditedBy.isNotEmpty) {
      _participantActivity[menu.lastEditedBy] = menu.lastEditedAt;
      _participantNames[menu.lastEditedBy] = menu.lastEditedByDisplayName;
    }

    // Cache all participant names from menu participants
    for (final userId in menu.participants.keys) {
      if (!_participantNames.containsKey(userId)) {
        // Try to find display name from other sources
        if (userId == menu.ownerId) {
          _participantNames[userId] = menu.ownerDisplayName;
        } else {
          _participantNames[userId] =
              AppLocale.current.labelParticipantFallback;
        }
      }
    }

    _cleanupOldActivity();
    onUpdated?.call();

    AppLogger.debug('👥 Participant aktivitet uppdaterad: $activeCount aktiva');
  }

  /// Get display name for participant
  String getDisplayName(String userId) {
    return _participantNames[userId] ?? AppLocale.current.displayUnknownUser;
  }

  /// Kontrollera om deltagare var aktiv nyligen
  bool wasRecentlyActive(String userId, Duration within) {
    final lastSeen = _participantActivity[userId];
    if (lastSeen == null) return false;

    return clock.now().difference(lastSeen) <= within;
  }

  /// Get latest activity for participant
  DateTime? getLastActivity(String userId) {
    return _participantActivity[userId];
  }

  /// Get list of participants who are online now (active in last 5 min)
  List<String> get onlineParticipants {
    return _participantActivity.entries
        .where(
            (entry) => wasRecentlyActive(entry.key, const Duration(minutes: 5)))
        .map((entry) => entry.key)
        .toList();
  }

  /// Få lista över deltagare som var aktiva senaste timmen
  List<String> get recentlyActiveParticipants {
    return _participantActivity.entries
        .where(
            (entry) => wasRecentlyActive(entry.key, const Duration(hours: 1)))
        .map((entry) => entry.key)
        .toList();
  }

  /// Update display name for participant (from other sources)
  void updateDisplayName(String userId, String displayName) {
    if (_participantNames[userId] != displayName) {
      _participantNames[userId] = displayName;
      onUpdated?.call();
      AppLogger.debug(
          '👤 Display name uppdaterat för ${userId.maskedUserId}: ${displayName.maskedName}');
    }
  }

  /// Markera deltagare som aktiv nu
  void markActiveNow(String userId, String displayName) {
    _participantActivity[userId] = clock.now();
    _participantNames[userId] = displayName;
    onUpdated?.call();
    AppLogger.debug('✅ ${displayName.maskedName} markerad som aktiv');
  }

  /// Clean up old activities (older than 1 hour)
  void _cleanupOldActivity() {
    final cutoff = clock.now().subtract(const Duration(hours: 1));
    final oldCount = _participantActivity.length;

    _participantActivity
        .removeWhere((userId, lastSeen) => lastSeen.isBefore(cutoff));

    if (_participantActivity.length != oldCount) {
      final cleaned = oldCount - _participantActivity.length;
      AppLogger.debug('🧹 $cleaned gamla aktiviteter rensade');
    }
  }

  /// Force cleanup of old activity (for manual cleanup)
  void forceCleanup() {
    _cleanupOldActivity();
    onUpdated?.call();
  }

  /// Rensa all tracking data
  void clear() {
    final hadData =
        _participantActivity.isNotEmpty || _participantNames.isNotEmpty;
    _participantActivity.clear();
    _participantNames.clear();

    if (hadData) {
      onUpdated?.call();
      AppLogger.debug('🧹 All participant data rensad');
    }
  }

  /// Remove specific participant from tracking
  void removeParticipant(String userId) {
    final removed = _participantActivity.remove(userId) != null;
    _participantNames.remove(userId);

    if (removed) {
      onUpdated?.call();
      AppLogger.debug(
          '🚫 Deltagare ${userId.maskedUserId} borttagen från tracking');
    }
  }

  void dispose() {
    clear();
    AppLogger.debug('🗑️ ParticipantTracker disposed');
  }
}
