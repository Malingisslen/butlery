import 'package:flutter/painting.dart';

/// Overrides for a span inside running text: size, family and the rest stay
/// those of the surrounding text, so only the one property is set.
abstract final class SpanStyles {
  static const TextStyle bold = TextStyle(fontWeight: FontWeight.w700);
  static const TextStyle semibold = TextStyle(fontWeight: FontWeight.w600);

  static TextStyle colour(Color colour) => TextStyle(color: colour);
}
