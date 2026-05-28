/// Shared types for realtime synchronization services.
/// Contains error types and models used across realtime modules to avoid circular dependencies.

import 'package:butlery/models/realtime/realtime_resource.dart';

/// Synchronization error types for error handling and recovery.
enum SyncErrorType {
  connectionLost,
  permissionDenied,
  conflictResolution,
  documentNotFound,
  firestoreError,
  unknown,
}

/// Synchronization error with contextual information.
class SyncError {
  final SyncErrorType type;
  final String message;
  final String? resourceId;
  final RealtimeResourceType? resourceType;
  final dynamic originalError;

  SyncError({
    required this.type,
    required this.message,
    this.resourceId,
    this.resourceType,
    this.originalError,
  });

  @override
  String toString() => 'SyncError($type): $message';
}

/// Which side won during a collaborative-edit conflict resolution.
enum ConflictResolutionStrategy {
  localWon,
  remoteWon,
}

/// BUT-1031: Broadcast when two users edit the same resource and
/// `ConflictResolutionModule.resolveConflict` picks a winner.
///
/// Last-write-wins used to be silent — one user's changes disappeared without
/// any UI feedback. Emitting this event lets [RealtimeSyncService.conflictStream]
/// drive a banner (see `widgets/realtime/conflict_banner.dart`).
class ConflictEvent {
  /// Firestore collection path the conflict was resolved in (e.g. `recipes`).
  final String collectionPath;

  /// Document id within [collectionPath].
  final String docId;

  /// Local snapshot at conflict time (the version the current user just saved).
  final RealtimeResource localValue;

  /// Remote snapshot at conflict time (the version that arrived from another
  /// collaborator).
  final RealtimeResource remoteValue;

  /// Which side the resolver picked.
  final ConflictResolutionStrategy chosenStrategy;

  /// Wall-clock when resolution happened — used by listeners to dedup or
  /// auto-dismiss old banners.
  final DateTime occurredAt;

  ConflictEvent({
    required this.collectionPath,
    required this.docId,
    required this.localValue,
    required this.remoteValue,
    required this.chosenStrategy,
    required this.occurredAt,
  });

  @override
  String toString() =>
      'ConflictEvent($chosenStrategy on $collectionPath/$docId)';
}
