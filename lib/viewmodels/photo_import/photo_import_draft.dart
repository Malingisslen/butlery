import 'dart:convert';

import 'package:butlery/core/extensions/default_value_extensions.dart';

/// BUT-910: the persistence contract for the photo-import draft — the OCR text
/// plus a pointer to the on-disk staged image. Extracted as a codec (mirroring
/// `group_draft_codec.dart`) so the JSON shape and the nothing-worth-keeping
/// rule are unit-testable independently of the ViewModel.
///
/// Image bytes deliberately do NOT live here: SharedPreferences is the wrong
/// home for megabytes of JPEG. The bytes are staged as a gzipped temp file by
/// `draft_image_store_*.dart` and only the *path* is persisted. On web there is
/// no staging, so [imagePath] is null and a restore recovers text only.
class PhotoImportDraft {
  const PhotoImportDraft({
    required this.ocrText,
    this.imagePath,
    this.savedAtMs,
  });

  /// The extracted OCR text — the expensive artefact worth persisting.
  final String ocrText;

  /// Absolute path to the gzipped staged image, or null when staging was
  /// unavailable (web) or failed (best-effort).
  final String? imagePath;

  /// Wall-clock save time (milliseconds since epoch). Not consumed yet —
  /// persisted so a future staleness cutoff doesn't need a key migration.
  final int? savedAtMs;
}

/// Encodes a draft to its persisted string, or `null` when there is no OCR
/// text. Returning null makes [AutoSaveManager] remove the key — a photo
/// without a completed extraction is not worth a draft.
String? encodePhotoImportDraft(PhotoImportDraft draft) {
  if (draft.ocrText.isEmpty) return null;
  return jsonEncode(<String, dynamic>{
    'ocrText': draft.ocrText,
    'imagePath': draft.imagePath,
    'savedAtMs': draft.savedAtMs,
  });
}

/// Decodes a persisted draft string. Returns null (treated as "no draft" by
/// the manager) when the blob has no usable OCR text; a corrupt blob throws
/// and is swallowed by the manager's best-effort load.
PhotoImportDraft? decodePhotoImportDraft(String raw) {
  final map = jsonDecode(raw) as Map<String, dynamic>;
  final ocrText = (map['ocrText'] as String?).orEmpty();
  if (ocrText.isEmpty) return null;
  return PhotoImportDraft(
    ocrText: ocrText,
    imagePath: map['imagePath'] as String?,
    savedAtMs: map['savedAtMs'] as int?,
  );
}
