// lib/services/realtime/conflict_resolution_module.dart

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/realtime/realtime_types.dart';

/// Module handling conflict resolution for concurrent edits in realtime sync.
/// Provides conflict detection, resolution algorithm, and update execution.
class ConflictResolutionModule {
  final FirestoreRepository firestoreRepository;
  final Future<T> Function<T extends RealtimeResource>(String resourceId)
  getLatestResource;

  /// BUT-1031: optional sink for conflict events. RealtimeSyncService wires
  /// this to a broadcast StreamController; null in standalone tests.
  final void Function(ConflictEvent event)? onConflict;

  /// Firestore collection path injected by the parent service so emitted
  /// [ConflictEvent]s can identify which collection the conflict was in.
  /// Empty string when the module is used outside a typed collection context.
  final String collectionPath;

  /// Conflict resolution window (5 seconds)
  static const int conflictResolutionWindowMs = 5000;

  /// Track last local updates for conflict detection
  final Map<String, DateTime> _lastLocalUpdate = {};

  ConflictResolutionModule({
    required this.firestoreRepository,
    required this.getLatestResource,
    this.onConflict,
    this.collectionPath = '',
  });

  /// Check if conflict resolution is needed
  Future<bool> shouldResolveConflict(RealtimeResource resource) async {
    final lastUpdate = _lastLocalUpdate[resource.id];
    if (lastUpdate == null) return false;

    // If less than 5 seconds since last local update, check remote
    final timeSinceUpdate = clock.now().difference(lastUpdate).inMilliseconds;
    if (timeSinceUpdate < conflictResolutionWindowMs) {
      try {
        final remoteResource = await getLatestResource<RealtimeResource>(
          resource.id,
        );
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
    T local,
    T remote,
  ) async {
    AppLogger.info('⚠️ Löser konflikt för resurs: ${local.id}');

    try {
      // Standard conflict resolution: latest editCount wins
      if (local.editCount > remote.editCount) {
        AppLogger.info(
          '📝 Lokal version vinner (editCount: ${local.editCount} > ${remote.editCount})',
        );
        _emitConflict(local, remote, ConflictResolutionStrategy.localWon);
        return local;
      } else if (remote.editCount > local.editCount) {
        AppLogger.info(
          '☁️ Remote version vinner (editCount: ${remote.editCount} > ${local.editCount})',
        );
        _emitConflict(local, remote, ConflictResolutionStrategy.remoteWon);
        return remote;
      } else {
        // Same editCount - use timestamp
        if (local.lastEditedAt.isAfter(remote.lastEditedAt)) {
          AppLogger.info('📝 Lokal version vinner (nyare timestamp)');
          _emitConflict(local, remote, ConflictResolutionStrategy.localWon);
          return local;
        } else {
          AppLogger.info('☁️ Remote version vinner (nyare timestamp)');
          _emitConflict(local, remote, ConflictResolutionStrategy.remoteWon);
          return remote;
        }
      }
    } catch (e) {
      AppLogger.error('❌ Fel vid conflict resolution för ${local.id}', e);

      // On error, choose remote version (safer). BUT-1031: do NOT emit a
      // ConflictEvent here — a resolver crash is "we punted, our code has a
      // bug" rather than "your edit was overwritten," and the banner copy
      // assumes the latter. Logged via the SyncError side-channel instead.
      AppLogger.warning(
        '🛡️ Väljer remote version vid conflict resolution-fel',
      );
      return remote;
    }
  }

  void _emitConflict<T extends RealtimeResource>(
    T local,
    T remote,
    ConflictResolutionStrategy strategy,
  ) {
    final sink = onConflict;
    if (sink == null) return;
    sink(
      ConflictEvent(
        collectionPath: collectionPath,
        docId: local.id,
        localValue: local,
        remoteValue: remote,
        chosenStrategy: strategy,
        occurredAt: clock.now(),
      ),
    );
  }

  /// Perform the update to Firebase
  Future<void> performUpdate(
    DocumentReference<Map<String, dynamic>> docRef,
    RealtimeResource resource,
  ) async {
    await firestoreRepository.setDocument(docRef, resource.toFirestore());
  }

  /// Record local update for conflict detection
  void recordLocalUpdate(String resourceId) {
    _lastLocalUpdate[resourceId] = clock.now();
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
