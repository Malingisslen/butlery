/// A sentence from the ARB with the names it was built from set in bold,
/// the way the approved pictures write "**Erik** delade menyn **Snabb
/// vardag**". The strings stay whole sentences for the translator; the names
/// are found again in the finished text.
library;

import 'package:flutter/widgets.dart';

/// [text] as spans, the first occurrence of each of [names], in order, in
/// [bold]. A name that is empty or not found is left out.
List<InlineSpan> boldNameSpans(
  String text,
  List<String> names,
  TextStyle bold,
) {
  final spans = <InlineSpan>[];
  var rest = text;
  for (final name in names) {
    final at = name.isEmpty ? -1 : rest.indexOf(name);
    if (at < 0) continue;
    if (at > 0) spans.add(TextSpan(text: rest.substring(0, at)));
    spans.add(TextSpan(text: name, style: bold));
    rest = rest.substring(at + name.length);
  }
  if (rest.isNotEmpty) spans.add(TextSpan(text: rest));
  return spans;
}
