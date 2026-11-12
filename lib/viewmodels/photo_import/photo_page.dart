import 'package:flutter/foundation.dart';
import 'package:butlery/services/ocr/text_layout.dart';

/// BUT-903: one captured page of a multi-page photo import — the raw bytes and
/// the OCR text extracted from just that page. Pages are concatenated in list
/// order to form the combined recipe text.
class PhotoPage {
  final Uint8List bytes;
  final String text;

  /// Where the words sat on this page, when the reader measured them.
  ///
  /// Null unless the free on-device tier read it AND
  /// `enable_layout_recipe_split` is on. A page from a paid tier, from the
  /// handwriting path, or restored from a draft has none — and one such page
  /// makes the whole document decline, by design: `DocumentLayout.isComplete`
  /// is false, its text is null, and the splitter's row-count precondition
  /// refuses it. Mixed provenance means mixed engines, whose type sizes are
  /// not comparable in the first place.
  final PageLayout? layout;

  /// Q4-04: false while the page waits for "Läs av N sidor".
  final bool isRead;

  const PhotoPage({
    required this.bytes,
    required this.text,
    this.layout,
    this.isRead = false,
  });
}
