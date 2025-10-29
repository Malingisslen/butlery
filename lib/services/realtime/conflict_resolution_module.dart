// lib/services/realtime/conflict_resolution_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/core/utils/logger.dart';

/// Module handling conflict resolution for concurrent edits in realtime sync.
///
/// Provides conflict detection, resolution algorithm, and update execution.
class ConflictResolutionModule {
  final FirestoreRepository firestoreRepository;
  final Future<T> Function<T extends RealtimeResource>(String resourceId)
      getLatestResource;

  /// Conflict resolution window (5 seconds)
  static const int conflictResolutionWindowMs = 5000;

  /// Track last local updates for conflict detection
  final Map<String, DateTime> _lastLocalUpdate = {};

  ConflictResolutionModule({
    required this.firestoreRepository,
    required this.getLatestResource,
  });

  /// Check if conflict resolution is needed
  Future<bool> shouldResolveConflict(RealtimeResource resource) async {
    final lastUpdate = _lastLocalUpdate[resource.id];
    if (lastUpdate == null) return false;

    // If less than 5 seconds since last local update, check remote
    final timeSinceUpdate =
        DateTime.now().difference(lastUpdate).inMilliseconds;
    if (timeSinceUpdate < conflictResolutionWindowMs) {
      try {
        final remoteResource =
            await getLatestResource<RealtimeResource>(resource.id);
        return remoteResource.lastEditedAt.isAfter(lastUpdate);
      } catch (e) {
        // If we can't fetch remote version, assume no conflict
        return false;
      }
    }

    return false;
  }

  /// Resolve conflicts using edit count and timestamp strategy
  Future<T> resolveConflict<T extends RealtimeResource>(
      T local, T remote) async {
    AppLogger.info('⚠️ Löser konflikt för resurs: ${local.id}');

    try {
      // Standard conflict resolution: latest editCount wins
      if (local.editCount > remote.editCount) {
        AppLogger.info(
            '📝 Lokal version vinner (editCount: ${local.editCount} > ${remote.editCount})');
        return local;
      } else if (remote.editCount > local.editCount) {
        AppLogger.info(
            '☁️ Remote version vinner (editCount: ${remote.editCount} > ${local.editCount})');
        return remote;
      } else {
        // Same editCount - use timestamp
        if (local.lastEditedAt.isAfter(remote.lastEditedAt)) {
          AppLogger.info('📝 Lokal version vinner (nyare timestamp)');
          return local;
        } else {
          AppLogger.info('☁️ Remote version vinner (nyare timestamp)');
          return remote;
        }
      }
    } catch (e) {
      AppLogger.error('❌ Fel vid conflict resolution för ${local.id}', e);

      // On error, choose remote version (safer)
      AppLogger.warning(
          '🛡️ Väljer remote version vid conflict resolution-fel');
      return remote;
    }
  }

  /// Perform the update to Firebase
  Future<void> performUpdate(
      DocumentReference<Map<String, dynamic>> docRef,
      RealtimeResource resource) async {
    await firestoreRepository.setDocument(docRef, resource.toFirestore());
  }

  /// Record local update for conflict detection
  void recordLocalUpdate(String resourceId) {
    _lastLocalUpdate[resourceId] = DateTime.now();
  }

  /// Remove tracking for resource
  void removeTracking(String resourceId) {
    _lastLocalUpdate.remove(resourceId);
  }

  /// Clear all tracking
  void clearTracking() {
    _lastLocalUpdate.clear();
  }
}
