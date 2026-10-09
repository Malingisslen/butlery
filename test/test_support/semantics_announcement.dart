// BUT-1953: a `Semantics(label:)` is concatenated with the visible text it
// wraps, so a label that restates that text is read twice.
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The lines a screen reader announces for the node [finder] resolves to:
/// label, value and tooltip, split where Flutter joins merged children.
List<String> announcedLines(WidgetTester tester, Finder finder) {
  final data = tester.getSemantics(finder).getSemanticsData();
  return [
    data.label,
    data.value,
    data.tooltip,
  ].expand((part) => part.split('\n')).map((l) => l.trim()).where((l) {
    return l.isNotEmpty;
  }).toList();
}

/// Fails when one announced line of the node repeats or contains another,
/// e.g. a label "Öppna Pasta" merged with the visible "Pasta".
void expectNothingAnnouncedTwice(WidgetTester tester, Finder finder) {
  final lines = announcedLines(tester, finder);
  for (var i = 0; i < lines.length; i++) {
    for (var j = 0; j < lines.length; j++) {
      if (i == j) continue;
      final a = lines[i].toLowerCase();
      final b = lines[j].toLowerCase();
      expect(
        a.contains(b),
        isFalse,
        reason:
            '"${lines[i]}" repeats "${lines[j]}" in one announcement: '
            '$lines',
      );
    }
  }
}

/// Fails when the node a screen reader lands on cannot be activated: a
/// wrapper with `excludeSemantics: true` drops the tap of the InkWell or
/// GestureDetector below it unless it passes `onTap` itself.
void expectActivatable(WidgetTester tester, Finder finder) {
  final data = tester.getSemantics(finder).getSemanticsData();
  expect(
    data.hasAction(SemanticsAction.tap),
    isTrue,
    reason: 'the node "${data.label}" has no tap action',
  );
}
