// lib/viewmodels/realtime/participant_tracker.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/core/utils/logger.dart';


/// Data för en deltagares aktivitet
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
    return DateTime.now().difference(lastSeen) <= period;
  }

  @override
  String toString() =>
      'ParticipantActivity($displayName, $lastSeen, online: $isOnline)';
}

/// Tracker för deltagares aktivitet i realtidsresurser
class ParticipantTracker {
  final Map<String, DateTime> _participantActivity = {};
  final Map<String, String> _participantNames = {};

  /// Callback när participant data uppdateras
  final VoidCallback? onUpdated;

  ParticipantTracker({this.onUpdated});

  /// Antal aktiva deltagare
  int get activeCount => _participantActivity.length;

  /// Lista över aktiva deltagare
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
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen)); // Senaste först
  }

  /// Uppdatera deltagares aktivitet baserat på menu-ändringar
  void updateFromMenu(RealtimeMenu menu) {
    // Uppdatera senaste aktivitet för den som redigerade
    if (menu.lastEditedBy.isNotEmpty) {
      _participantActivity[menu.lastEditedBy] = menu.lastEditedAt;
      _participantNames[menu.lastEditedBy] = menu.lastEditedByDisplayName;
    }

    // Cache alla deltagares namn från menu participants
    for (final userId in menu.participants.keys) {
      if (!_participantNames.containsKey(userId)) {
        // Försök att hitta display name från andra källor
        if (userId == menu.ownerId) {
          _participantNames[userId] = menu.ownerDisplayName;
        } else {
          _participantNames[userId] = 'Deltagare'; // Default fallback
        }
      }
    }

    _cleanupOldActivity();
    onUpdated?.call();

    AppLogger.debug('👥 Participant aktivitet uppdaterad: $activeCount aktiva');
  }

  /// Hämta display name för deltagare
  String getDisplayName(String userId) {
    return _participantNames[userId] ?? 'Okänd användare';
  }

  /// Kontrollera om deltagare var aktiv nyligen
  bool wasRecentlyActive(String userId, Duration within) {
    final lastSeen = _participantActivity[userId];
    if (lastSeen == null) return false;

    return DateTime.now().difference(lastSeen) <= within;
  }

  /// Hämta senaste aktivitet för deltagare
  DateTime? getLastActivity(String userId) {
    return _participantActivity[userId];
  }

  /// Få lista över deltagare som är online nu (aktiva senaste 5 min)
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

  /// Uppdatera display name för deltagare (från andra källor)
  void updateDisplayName(String userId, String displayName) {
    if (_participantNames[userId] != displayName) {
      _participantNames[userId] = displayName;
      onUpdated?.call();
      AppLogger.debug('👤 Display name uppdaterat för $userId: $displayName');
    }
  }

  /// Markera deltagare som aktiv nu
  void markActiveNow(String userId, String displayName) {
    _participantActivity[userId] = DateTime.now();
    _participantNames[userId] = displayName;
    onUpdated?.call();
    AppLogger.debug('✅ $displayName markerad som aktiv');
  }

  /// Rensa gamla aktiviteter (äldre än 1 timme)
  void _cleanupOldActivity() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    final oldCount = _participantActivity.length;

    _participantActivity
        .removeWhere((userId, lastSeen) => lastSeen.isBefore(cutoff));

    if (_participantActivity.length != oldCount) {
      final cleaned = oldCount - _participantActivity.length;
      AppLogger.debug('🧹 $cleaned gamla aktiviteter rensade');
    }
  }

  /// Tvinga cleanup av old activity (för manuell rensning)
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

  /// Ta bort specifik deltagare från tracking
  void removeParticipant(String userId) {
    final removed = _participantActivity.remove(userId) != null;
    _participantNames.remove(userId);

    if (removed) {
      onUpdated?.call();
      AppLogger.debug('🚫 Deltagare $userId borttagen från tracking');
    }
  }

  void dispose() {
    clear();
    AppLogger.debug('🗑️ ParticipantTracker disposed');
  }
}
