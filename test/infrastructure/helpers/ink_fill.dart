import 'package:flutter/gestures.dart';
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

/// Whether an opaque fill sits between [target] and the ink layer its press
/// paints on. Such a fill is painted after the ink, so it hides the press
/// (BUT-2205, the hidden InkWells).
bool pressIsCovered(WidgetTester tester, Finder target) {
  RenderObject? node = tester.renderObject(target);
  while (node != null && node.runtimeType.toString() != '_RenderInkFeatures') {
    if (node is RenderDecoratedBox) {
      final decoration = node.decoration;
      if (decoration is BoxDecoration &&
          (decoration.color?.a ?? 0) == 1 &&
          node.position == DecorationPosition.background) {
        return true;
      }
    }
    if (node.runtimeType.toString() == '_RenderColoredBox') return true;
    node = node.parent;
  }
  expect(node, isNotNull, reason: 'no Material above the pressed widget');
  return false;
}

/// Whether a border is drawn between [target] and the ink layer its press
/// paints on, so the press fill cannot cover it. A border drawn by an `Ink`
/// sits on the ink layer, beneath the press (BUT-2205).
bool borderIsAbovePress(WidgetTester tester, Finder target) {
  RenderObject? node = tester.renderObject(target);
  while (node != null && node.runtimeType.toString() != '_RenderInkFeatures') {
    if (node is RenderDecoratedBox) {
      final decoration = node.decoration;
      if (decoration is BoxDecoration && decoration.border != null) return true;
    }
    node = node.parent;
  }
  expect(node, isNotNull, reason: 'no Material above the pressed widget');
  return false;
}
