/// CookSnap model — a photo posted by a user who cooked a recipe.
library;

import 'package:clock/clock.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// BUT-1214: per-snap visibility override. A snap can be made MORE private
/// than its parent recipe (never more public — the recipe's audience is the
/// cap, enforced by the existing friends-gated read rules).
enum CookSnapVisibility {
  /// Default — the snap inherits the parent recipe's audience (BUT-901).
  sameAsRecipe,

  /// Author-only: filtered from every other viewer in the read path AND
  /// denied by Firestore rules.
  onlyMe;

  /// Missing/unknown wire values resolve to [sameAsRecipe] so legacy docs
  /// (written before the field existed) keep their inherited behaviour.
  static CookSnapVisibility fromWire(String? value) => value == 'onlyMe'
      ? CookSnapVisibility.onlyMe
      : CookSnapVisibility.sameAsRecipe;
}

/// A cooking photo posted on a recipe by any authenticated user.
///
/// BUT-949: a snap can hold up to [maxPhotos] photos (an album). The wire
/// format moved from a singular `photoUrl` to a `photoUrls` list; legacy docs
/// (written before the field existed) are read-mapped into a one-element list,
/// so existing snaps keep rendering. The singular [photoUrl] getter is retained
/// for call-sites that only need the cover image.
class CookSnap {
  final String id;
  final String recipeId;
  final String userId;
  final String userDisplayName;
  final String? userAvatarUrl;

  /// The album's photo URLs, cover-first. Always non-empty for a valid snap
  /// (capped at [maxPhotos]). Legacy single-photo snaps have length 1.
  final List<String> photoUrls;
  final String? thumbnailUrl;
  final String? caption;

  /// Cover photo — the first URL in the album. Retained for the many
  /// call-sites that only render a single image.
  String get photoUrl => photoUrls.first;

  /// Whether this snap is a multi-photo album.
  bool get hasMultiplePhotos => photoUrls.length > 1;

  /// Optimistic client time. Server timestamp is authoritative — see
  /// `FirebaseCookSnapRepository.addCookSnap`, which overwrites this
  /// field with `FieldValue.serverTimestamp()` at the write boundary
  /// (BUT-965). The in-memory value here is what the immediate UI
  /// displays; subsequent reads resolve to the server-set time.
  final DateTime createdAt;

  /// BUT-1214: per-snap visibility override; see [CookSnapVisibility].
  final CookSnapVisibility visibility;

  CookSnap({
    required this.id,
    required this.recipeId,
    required this.userId,
    required this.userDisplayName,
    this.userAvatarUrl,
    String? photoUrl,
    List<String>? photoUrls,
    this.thumbnailUrl,
    this.caption,
    this.visibility = CookSnapVisibility.sameAsRecipe,
    DateTime? createdAt,
  })  : assert(
          photoUrl != null || (photoUrls != null && photoUrls.isNotEmpty),
          'A CookSnap requires at least one photo (photoUrl or photoUrls).',
        ),
        photoUrls = _capPhotos(photoUrls ?? <String>[photoUrl!]),
        createdAt = createdAt ?? clock.now();

  /// Maximum caption length.
  static const int maxCaptionLength = 200;

  /// BUT-949: maximum photos per snap (album cap).
  static const int maxPhotos = 5;

  /// Normalises an album: drops empty URLs, caps at [maxPhotos]. The caller
  /// guarantees non-emptiness via the constructor assert.
  static List<String> _capPhotos(List<String> urls) {
    final cleaned = urls.where((u) => u.trim().isNotEmpty).toList();
    if (cleaned.isEmpty) return urls.take(maxPhotos).toList();
    return cleaned.length > maxPhotos ? cleaned.sublist(0, maxPhotos) : cleaned;
  }

  factory CookSnap.create({
    required String recipeId,
    required String userId,
    required String userDisplayName,
    String? userAvatarUrl,
    String? photoUrl,
    List<String>? photoUrls,
    String? thumbnailUrl,
    String? caption,
    CookSnapVisibility visibility = CookSnapVisibility.sameAsRecipe,
  }) {
    return CookSnap(
      id: const Uuid().v4(),
      recipeId: recipeId,
      userId: userId,
      userDisplayName: userDisplayName,
      userAvatarUrl: userAvatarUrl,
      photoUrl: photoUrl,
      photoUrls: photoUrls,
      thumbnailUrl: thumbnailUrl,
      caption: _sanitizeCaption(caption),
      visibility: visibility,
      createdAt: clock.now(),
    );
  }

  /// BUT-949: resolve an album from a Firestore map. Prefers `photoUrls`
  /// (album format); falls back to the legacy singular `photoUrl`. Always
  /// returns a non-empty list (one empty-string element for a corrupt/empty
  /// doc) so the constructor's non-empty invariant holds — a missing photo is
  /// a degenerate doc, not a crash.
  static List<String> _photosFromMap(Map<String, dynamic> data) {
    final urls = SerializationUtils.safeStringList(data, 'photoUrls')
        .where((u) => u.trim().isNotEmpty)
        .toList();
    if (urls.isNotEmpty) return urls;
    final legacy = SerializationUtils.safeString(data, 'photoUrl');
    return <String>[legacy];
  }

  static String? _sanitizeCaption(String? caption) {
    if (caption == null) return null;
    final trimmed = caption.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length > maxCaptionLength) {
      return trimmed.substring(0, maxCaptionLength);
    }
    return trimmed;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'recipeId': recipeId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userAvatarUrl': userAvatarUrl,
      'photoUrls': photoUrls,
      // BUT-949: keep the legacy singular cover field so any consumer still
      // reading `photoUrl` (older clients, activity-feed extraData) keeps
      // working. New reads prefer `photoUrls`.
      'photoUrl': photoUrl,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
      'visibility': visibility.name,
      'createdAt': AppTimestamp.fromDateTime(createdAt).toFirestore(),
    };
  }

  factory CookSnap.fromMap(String id, Map<String, dynamic> data) {
    return CookSnap(
      id: id,
      recipeId: SerializationUtils.safeString(data, 'recipeId'),
      userId: SerializationUtils.safeString(data, 'userId'),
      userDisplayName: SerializationUtils.safeString(
        data,
        'userDisplayName',
        defaultValue: '?',
      ),
      userAvatarUrl:
          SerializationUtils.safeNullableString(data, 'userAvatarUrl'),
      // BUT-949: prefer the album list; fall back to the legacy singular
      // `photoUrl` so pre-album docs read into a one-element album.
      photoUrls: _photosFromMap(data),
      thumbnailUrl: SerializationUtils.safeNullableString(data, 'thumbnailUrl'),
      caption: SerializationUtils.safeNullableString(data, 'caption'),
      visibility: CookSnapVisibility.fromWire(
        SerializationUtils.safeNullableString(data, 'visibility'),
      ),
      createdAt:
          SerializationUtils.safeDateTime(data, 'createdAt') ?? clock.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CookSnap && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CookSnap(id: $id, user: $userDisplayName, recipe: $recipeId)';
}
