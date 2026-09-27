/// Concepts the Butlery icon family has no glyph for yet (Q16).
///
/// K-10 (migration-gap.md:46) keeps the app's semantic icon aliases. The
/// "saved template" concept has no glyph in icons.json, so it keeps a
/// Material stand-in here, in one place, until design draws it. Every entry
/// is listed in test/architecture/icon_census_test.dart, which only shrinks.
library;

import 'package:flutter/material.dart';

/// Material stand-ins for concepts without a Butlery glyph.
abstract final class PendingGlyphs {
  /// A saved template (the former savedTemplate alias).
  static const IconData savedTemplate = Icons.bookmark;

  /// A template that is not saved (the former savedTemplateOutline alias).
  static const IconData savedTemplateOutline = Icons.bookmark_border;
}
