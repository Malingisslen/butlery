/// BUT-953: One-shot draft of the user's heirloom form, captured before
/// navigation from photo-import to text-import.
///
/// The heirloom form lives on `PhotoImportViewModel`. This value
/// object survives the navigation hop via `HeirloomBridge`.
///
/// Note: holds raw image bytes. No serialization; not persisted to disk.

import 'dart:typed_data';

class HeirloomDraft {
  /// Raw bytes of the captured scan, in their original format.
  final Uint8List imageBytes;

  /// Optional writer attribution ("Farmor Elsa"). Trimmed to ≤100 chars by the
  /// form bindings on PhotoImportView.
  final String? writerName;

  /// Year the original was written, in [1800, currentYear]. Null when the
  /// user typed an invalid value (silently zeroed by the form).
  final int? year;

  /// Short origin note (≤200 chars).
  final String? note;

  const HeirloomDraft({
    required this.imageBytes,
    this.writerName,
    this.year,
    this.note,
  });
}
