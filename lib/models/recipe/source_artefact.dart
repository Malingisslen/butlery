/// BUT-1045: the raw source artefact a recipe was extracted from.
///
/// Persisted on `RecipeCore.sourceArtefact` so the import pipeline can be
/// re-run offline (BUT-940). Different import paths use different
/// payloads — see [SourceArtefactType] for the per-type semantics.
///
/// Backward compat: nullable on RecipeCore. Recipes created before the
/// field shipped have `null` and just lose the re-extract affordance.
library;

import 'package:butlery/core/utils/serialization_utils.dart' as utils;

/// Discriminates which extraction pipeline owns the payload + how to
/// interpret it on a re-extract run.
enum SourceArtefactType {
  /// Generic web-scrape import. `payload` is the source URL.
  url,

  /// YouTube transcript text (transcript fetched once at import time).
  /// `payload` is the raw transcript string.
  youtubeTranscript,

  /// TikTok caption text (the video description / caption).
  /// `payload` is the raw caption string.
  tiktokCaption,

  /// Instagram caption text (the post / reel caption extracted via
  /// WebScraper). `payload` is the raw caption string.
  instagramCaption,

  /// User-pasted plain text. `payload` is the original pasted text
  /// (pre-LLM-extraction).
  textPaste,

  /// Photo OCR output. `payload` is the OCR'd text (re-OCR'ing the
  /// original image would need the raw bytes, which we don't store —
  /// the OCR result is the practical re-extract source).
  photoOcr,
}

class SourceArtefact {
  final SourceArtefactType type;

  /// Text content (transcript, caption, pasted text, OCR output) or a
  /// URL (for [SourceArtefactType.url] — same value as `sourceUrl`).
  /// Interpretation is per [type].
  final String payload;

  /// When the artefact was originally captured. Lets the re-extract
  /// flow surface "Source captured X days ago — re-fetching may differ"
  /// when the artefact is stale.
  final DateTime fetchedAt;

  const SourceArtefact({
    required this.type,
    required this.payload,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'payload': payload,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  /// Parses from JSON. Unknown [type] strings fall back to
  /// [SourceArtefactType.url] (safest default — re-extract via URL
  /// retains some value even if the type label was corrupted).
  factory SourceArtefact.fromJson(Map<String, dynamic> json) {
    final typeStr = utils.SerializationUtils.safeString(json, 'type',
        defaultValue: SourceArtefactType.url.name);
    final type = SourceArtefactType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => SourceArtefactType.url,
    );
    return SourceArtefact(
      type: type,
      payload: utils.SerializationUtils.safeString(json, 'payload'),
      fetchedAt:
          utils.SerializationUtils.safeRequiredDateTime(json, 'fetchedAt'),
    );
  }

  SourceArtefact copyWith({
    SourceArtefactType? type,
    String? payload,
    DateTime? fetchedAt,
  }) =>
      SourceArtefact(
        type: type ?? this.type,
        payload: payload ?? this.payload,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceArtefact &&
          type == other.type &&
          payload == other.payload &&
          fetchedAt == other.fetchedAt;

  @override
  int get hashCode => Object.hash(type, payload, fetchedAt);
}
