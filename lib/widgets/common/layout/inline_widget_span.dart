// lib/widgets/common/layout/inline_widget_span.dart
//
// A widget inside running text. The paragraph already scales a WidgetSpan's
// child by the text scale, so a Text inside it that also scales itself comes
// out at the square of the setting: a link in a sentence at 200 % is four
// times its size and its word is laid out in half the width.
library;

import 'package:flutter/widgets.dart';

WidgetSpan inlineWidgetSpan({
  required Widget child,
  PlaceholderAlignment alignment = PlaceholderAlignment.baseline,
  TextBaseline? baseline = TextBaseline.alphabetic,
}) => WidgetSpan(
  alignment: alignment,
  baseline: alignment == PlaceholderAlignment.baseline ? baseline : null,
  child: MediaQuery.withNoTextScaling(child: child),
);
