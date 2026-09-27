// lib/services/offline/queued_change.dart
//
// P4-U19: one waiting change as the "Väntar på synk" view shows it
// (produktregler.md:190), independent of the platform's database.
library;

import 'package:flutter/foundation.dart';

/// Which queue a [QueuedChange] lives in.
enum QueuedChangeKind {
  /// A write in the sync queue (today always a recipe).
  recipe,

  /// An image in the upload queue.
  image,
}

/// What a recipe write does, as the queue stores it (SyncOperation).
enum QueuedOperation { create, update, delete, tag, upload }

/// Why a change waits for the user, in the words produktregler.md:188 names.
///
/// The queue stores the reason as text in `lastError`. The flow-08 classifier
/// (P6-U08b) writes these codes; anything else reads as [unknown], which still
/// says what happened, never the raw error.
enum QueuedChangeReason {
  notFound,
  permissionDenied,
  tooLarge,
  dependencyFailed,

  /// The queue retried for 24 h without success (produktregler.md:188).
  retriesExhausted,
  unknown
  ;

  /// The stored codes, as the classifier writes them.
  static const Map<String, QueuedChangeReason> _codes = {
    'not-found': notFound,
    'permission-denied': permissionDenied,
    'too-large': tooLarge,
    'dependency-failed': dependencyFailed,
    'retries-exhausted': retriesExhausted,
  };

  /// The code stored for this reason, or null for [unknown].
  String? get code {
    for (final entry in _codes.entries) {
      if (entry.value == this) return entry.key;
    }
    return null;
  }

  /// Reads a stored `lastError`. Only an exact code counts: a raw exception
  /// text is never shown to the user.
  static QueuedChangeReason parse(String? stored) =>
      _codes[stored?.trim()] ?? unknown;
}

/// One change that has not reached the server, as the queue view shows it.
///
/// Identity is [id] in its [kind]'s queue: the sync entry's opId or the
/// upload's id. Never the position in the list or the visible text.
@immutable
class QueuedChange {
  const QueuedChange({
    required this.kind,
    required this.id,
    required this.operation,
    required this.queuedAt,
    this.subject,
    this.needsUser = false,
    this.reason = QueuedChangeReason.unknown,
    this.waitsOnEarlier = false,
    this.nextAttemptAt,
  });

  final QueuedChangeKind kind;

  /// The opId (sync queue) or upload id (upload queue).
  final String id;

  final QueuedOperation operation;

  /// When the change was queued. The view shows its age.
  final DateTime queuedAt;

  /// The recipe's title when the device knows it, else null.
  final String? subject;

  /// A permanent failure that waits for the user ("Väntar på dig").
  final bool needsUser;

  /// Why it waits for the user. Only meaningful when [needsUser].
  final QueuedChangeReason reason;

  /// Whether it waits for another change still in the queue (dependsOn,
  /// produktregler.md:187).
  final bool waitsOnEarlier;

  /// When the queue sends it again after a failed attempt, or null when it
  /// has not failed (produktregler.md:188; #synkko "nästa försök om 8 s").
  final DateTime? nextAttemptAt;

  /// A recipe the server has never had: the entry creates it. Throwing the
  /// entry away would lose the recipe itself, so until the product owner
  /// decides otherwise such an entry offers "Försök igen" and "Spara som
  /// kopia" but not "Släng" (the lead's interim choice for P6-U08b).
  bool get isNeverSyncedRecipe =>
      kind == QueuedChangeKind.recipe && operation == QueuedOperation.create;

  /// "Spara som kopia" (produktregler.md:188): the device's content is kept
  /// as a new recipe of the user's own. Only a recipe write carries content.
  bool get canSaveAsCopy =>
      needsUser &&
      kind == QueuedChangeKind.recipe &&
      (operation == QueuedOperation.create ||
          operation == QueuedOperation.update);

  /// "Försök mindre" (#synkko): an image the server refused as too large is
  /// sent again as a smaller copy.
  bool get canTrySmaller =>
      needsUser &&
      kind == QueuedChangeKind.image &&
      reason == QueuedChangeReason.tooLarge;

  /// "Släng ändringen" (produktregler.md:188), except for a recipe the
  /// server has never had ([isNeverSyncedRecipe]).
  bool get canDiscard => needsUser && !isNeverSyncedRecipe;

  @override
  bool operator ==(Object other) =>
      other is QueuedChange &&
      other.kind == kind &&
      other.id == id &&
      other.operation == operation &&
      other.queuedAt == queuedAt &&
      other.subject == subject &&
      other.needsUser == needsUser &&
      other.reason == reason &&
      other.waitsOnEarlier == waitsOnEarlier &&
      other.nextAttemptAt == nextAttemptAt;

  @override
  int get hashCode => Object.hash(
    kind,
    id,
    operation,
    queuedAt,
    subject,
    needsUser,
    reason,
    waitsOnEarlier,
    nextAttemptAt,
  );
}

/// The queue as the view groups it: permanent failures first
/// (produktregler.md:190), then the rest, each oldest first.
@immutable
class QueueSnapshot {
  QueueSnapshot(Iterable<QueuedChange> changes)
    : needsUser = List.unmodifiable(
        changes.where((c) => c.needsUser).toList()
          ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt)),
      ),
      draining = List.unmodifiable(
        changes.where((c) => !c.needsUser).toList()
          ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt)),
      );

  static final QueueSnapshot empty = QueueSnapshot(const []);

  /// "Väntar på dig": never retried by themselves.
  final List<QueuedChange> needsUser;

  /// "I kö": the queue sends these by itself.
  final List<QueuedChange> draining;

  int get total => needsUser.length + draining.length;

  bool get isEmpty => total == 0;
}
