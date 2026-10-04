import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether the ink layer that [target] is pressed on paints a rect, rounded
/// rect or path in [color]: the pressed or hovered fill an InkWell draws
/// (BUT-2205). Only the nearest Material's ink layer above [target] is read,
/// so the same colour elsewhere on screen cannot satisfy it. A press paints
/// more than one rect, so every draw is recorded.
bool paintsInkFill(WidgetTester tester, Finder target, Color color) {
  RenderObject? node = tester.renderObject(target);
  while (node != null && node.runtimeType.toString() != '_RenderInkFeatures') {
    node = node.parent;
  }
  expect(node, isNotNull, reason: 'no Material above the pressed widget');
  var found = false;
  expect(
    node,
    paints..everything((method, args) {
      if ((method == #drawRect ||
              method == #drawRRect ||
              method == #drawPath) &&
          args.last is Paint &&
          (args.last as Paint).color.toARGB32() == color.toARGB32()) {
        found = true;
      }
      return true;
    }),
  );
  return found;
}

/// Holds a press on [finder] long enough for the highlight to fade in, also
/// inside a scrollable, where the tap-down arrives after [kPressTimeout].
Future<TestGesture> holdPress(WidgetTester tester, Finder finder) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  await tester.pump();
  await tester.pump(kPressTimeout);
  await tester.pump(const Duration(milliseconds: 300));
  return gesture;
}
