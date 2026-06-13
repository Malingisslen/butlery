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

/// BUT-1163: a single field-level difference between the local and remote
/// snapshots of a conflicted resource. Pure value object — holds the rendered
/// string forms so the diff view stays dumb and the computation is testable
/// without a Flutter context.
class ConflictFieldDiff {
  /// Serialized map key the values came from (e.g. `title`, `instructions`).
  final String fieldKey;

  /// The local (current user's) value, stringified for display. Null when the
  /// field is absent on the local side.
  final String? localText;

  /// The remote (collaborator's) value, stringified for display. Null when the
  /// field is absent on the remote side.
  final String? remoteText;

  const ConflictFieldDiff({
    required this.fieldKey,
    required this.localText,
    required this.remoteText,
  });

  @override
  String toString() =>
      'ConflictFieldDiff($fieldKey: local=$localText remote=$remoteText)';
}

/// BUT-1163: deterministic, Firebase-free field-level diff between two
/// serialized resource snapshots.
///
/// The conflict diff view renders local-vs-remote columns; rather than teach it
/// about every [RealtimeResource] subtype, we diff over the serialized
/// `toFirestore()` maps. This keeps the comparison generic (recipe, menu,
/// shopping list all serialize to maps) and the result is a plain list of
/// [ConflictFieldDiff] the UI just lays out.
class ConflictDiff {
  /// Only fields where local and remote differ, sorted by key for stable
  /// rendering. Empty when the two snapshots serialize identically.
  final List<ConflictFieldDiff> changedFields;

  const ConflictDiff(this.changedFields);

  bool get isEmpty => changedFields.isEmpty;
  bool get isNotEmpty => changedFields.isNotEmpty;

  /// Metadata keys that are bookkeeping noise rather than user content — they
  /// change on every save and would drown out the meaningful diff.
  static const Set<String> _ignoredKeys = {
    'lastEditedAt',
    'lastEditedBy',
    'lastEditedByDisplayName',
    'editCount',
    'createdAt',
    'metadata',
  };

  /// Build a diff from two serialized snapshots (typically
  /// `localValue.toFirestore()` and `remoteValue.toFirestore()`).
  factory ConflictDiff.fromMaps(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final keys = <String>{...local.keys, ...remote.keys}
      ..removeAll(_ignoredKeys);
    final sortedKeys = keys.toList()..sort();

    final diffs = <ConflictFieldDiff>[];
    for (final key in sortedKeys) {
      final localText = _stringify(local[key]);
      final remoteText = _stringify(remote[key]);
      if (localText == remoteText) continue;
      diffs.add(ConflictFieldDiff(
        fieldKey: key,
        localText: localText,
        remoteText: remoteText,
      ));
    }
    return ConflictDiff(diffs);
  }

  /// Build a diff straight from a [ConflictEvent].
  factory ConflictDiff.fromEvent(ConflictEvent event) => ConflictDiff.fromMaps(
        event.localValue.toFirestore(),
        event.remoteValue.toFirestore(),
      );

  static String? _stringify(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Iterable) return value.map(_stringify).join('\n');
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => '${a.key}'.compareTo('${b.key}'));
      return entries.map((e) => '${e.key}: ${_stringify(e.value)}').join('\n');
    }
    return value.toString();
  }
}
