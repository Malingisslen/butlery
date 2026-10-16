/// Finds text that Flutter broke inside a word.
///
/// A paragraph given less width than its longest word breaks that word
/// between letters ("LUNC" / "H"), which reads as a typing error. The check
/// asks every wrapping paragraph on screen whether it was given at least the
/// width of its longest word. A single-line paragraph is skipped: it is cut
/// with an ellipsis or scrolled, never wrapped.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The text of every paragraph in [within] (the whole tree by default) whose
/// longest word is wider than the paragraph.
List<String> findMidWordBreaks(WidgetTester tester, {Finder? within}) {
  final root = within == null
      ? tester.binding.rootElement!
      : tester.element(within);
  final broken = <String>[];
  void visit(Element element) {
    final object = element.renderObject;
    if (object is RenderParagraph &&
        object.hasSize &&
        object.softWrap &&
        object.maxLines != 1) {
      final text = object.text.toPlainText(includePlaceholders: false);
      final widest = _longestWord(object);
      if (text.trim().isNotEmpty && object.size.width + 0.5 < widest) {
        broken.add(
          '"$text" is ${object.size.width.toStringAsFixed(1)} wide, '
          'its longest word ${widest.toStringAsFixed(1)}',
        );
      }
    }
    element.visitChildren(visit);
  }

  visit(root);
  return broken;
}

double _longestWord(RenderParagraph paragraph) {
  final text = paragraph.text.toPlainText(includePlaceholders: false);
  var widest = 0.0;
  for (final word in text.split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    final painter = TextPainter(
      text: TextSpan(text: word, style: paragraph.text.style),
      textScaler: paragraph.textScaler,
      textDirection: paragraph.textDirection,
      locale: paragraph.locale,
    )..layout();
    if (painter.width > widest) widest = painter.width;
    painter.dispose();
  }
  return widest;
}
