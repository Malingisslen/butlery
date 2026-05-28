/// BUT-953: One-shot draft of the user's heirloom form, captured before
/// navigation from photo-import to text-import.
///
/// The heirloom form lives on `PhotoImportViewModel`, but recipe saves happen
/// in `TextImportViewModel.completeImport()` after a route push. This value
/// object survives the navigation hop via `HeirloomBridge` so the heirloom
/// upload can run against the actual parsed recipe id at save time.
///
/// Note: holds raw image bytes — short-lived (set on photo→text navigation,
/// consumed on next save attempt). No serialization; not persisted to disk.

import 'dart:typed_data';

class HeirloomDraft {
  /// Raw bytes of the captured scan, in their original format.
  final Uint8List imageBytes;

  /// Optional writer attribution ("Farmor Elsa"). Trimmed to ≤100 chars by the
  /// form bindings on PhotoImportView — empty string normalised to null at
  /// build time by the consumer.
  final String? writerName;

  /// Year the original was written, in [1800, currentYear]. Null when the
  /// user typed an invalid value (silently zeroed by the form).
  final int? year;

  /// Short origin note (≤200 chars). Empty string normalised to null at build.
  final String? note;

  const HeirloomDraft({
    required this.imageBytes,
    this.writerName,
    this.year,
    this.note,
  });
}
