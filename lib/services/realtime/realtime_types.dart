/// Shared types for realtime synchronization services.
///
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
