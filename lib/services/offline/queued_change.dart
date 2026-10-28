// lib/services/offline/queued_change.dart
//
// P4-U19: one waiting change as the "Väntar på synk" view shows it
// independent of the platform's database.
library;

import 'package:flutter/foundation.dart';

/// Which queue a [QueuedChange] lives in.
enum QueuedChangeKind {
  /// A write in the sync queue (today always a recipe).
  recipe,

  /// An image in the upload queue.
  image,
}

/// The upload queue's entity types of a cook snap's and a comment's photos.
/// Equal to SyncQueueEntityType.cookSnap and .comment (a test pins them), kept
/// here so this database-free model does not import the Drift tables.
const String cookSnapEntityType = 'cook_snap';
const String commentEntityType = 'comment';

/// A chat image is one row named after its placeholder message, so it is not
/// in [imageGroupEntityTypes]. Equal to SyncQueueEntityType.chatImage.
const String chatImageEntityType = 'chat_image';

/// A new profile picture, one row. Equal to SyncQueueEntityType.avatar.
const String avatarEntityType = 'avatar';

/// The entity types whose photos are one item to the user.
const Set<String> imageGroupEntityTypes = {
  cookSnapEntityType,
  commentEntityType,
};

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

  /// The queue retried for 24 h without success.
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
    this.entityType,
    this.entityId,
    this.photoCount = 1,
    this.unsentSince,
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
  /// has not failed (#synkko "nästa försök om 8 s").
  final DateTime? nextAttemptAt;

  /// What an image row belongs to (SyncQueueEntityType), so the view can name
  /// it. Null for a recipe write.
  final String? entityType;

  /// The recipe, cook snap or comment an image row belongs to.
  final String? entityId;

  /// The photos in the group this item stands for; 1 for everything but a
  /// cook-snap album or a comment's photos, whose rows are one item to the
  /// user.
  final int photoCount;

  /// Where the 30 days an unsent image waits start ([unsentImageSince]); set
  /// for an image that waits for the user, null for everything else.
  final DateTime? unsentSince;

  /// The photos of a cook snap or a comment: one item whose [id] is the
  /// snap's or comment's id and which is retried and thrown away as a whole.
  bool get isImageGroup =>
      kind == QueuedChangeKind.image &&
      imageGroupEntityTypes.contains(entityType) &&
      entityId != null;

  /// A comment's photos, which the list names after the recipe.
  bool get isCommentGroup => isImageGroup && entityType == commentEntityType;

  /// A chat image, whose message was created when it was sent.
  bool get isChatImage =>
      kind == QueuedChangeKind.image &&
      entityType == chatImageEntityType &&
      entityId != null;

  /// A new profile picture.
  bool get isAvatar =>
      kind == QueuedChangeKind.image && entityType == avatarEntityType;

  /// A recipe the server has never had: the entry creates it, so the recipe
  /// exists only on this phone. Throwing the entry away throws the recipe
  /// away, so "Släng" asks first ([discardAsksFirst]).
  bool get isNeverSyncedRecipe =>
      kind == QueuedChangeKind.recipe && operation == QueuedOperation.create;

  /// "Spara som kopia": the device's content is kept
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
      !isImageGroup &&
      reason == QueuedChangeReason.tooLarge;

  /// "Släng ändringen", on every permanent failure.
  /// Q6-11 = B (produktbeslut 2026-09-27b): a recipe the server has never had
  /// can be thrown away too, after a confirmation ([discardAsksFirst]).
  bool get canDiscard => needsUser;

  /// Q6-11 = B: "Släng" on a new recipe that exists only on this phone first
  /// asks, in a confirmation that says just that, before the 7 s Ångra.
  bool get discardAsksFirst => canDiscard && isNeverSyncedRecipe;

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
      other.nextAttemptAt == nextAttemptAt &&
      other.entityType == entityType &&
      other.entityId == entityId &&
      other.photoCount == photoCount &&
      other.unsentSince == unsentSince;

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
    entityType,
    entityId,
    photoCount,
    unsentSince,
  );
}

/// The queue as the view groups it: permanent failures first
/// then the rest, each oldest first.
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
