import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/components/butlery_field_border.dart';

void main() {
  group('visualBox', () {
    test('a decorator at the touch target loses the slack above and below', () {
      final box = ButleryFieldBorder.visualBox(
        const Rect.fromLTWH(0, 0, 200, 48),
      );
      expect(box.height, AppDimensions.controlVisualHeight);
      expect(box.top, AppDimensions.fieldTapPad);
    });

    test('a decorator already at the visual height is left alone', () {
      const rect = Rect.fromLTWH(0, 0, 200, 40);
      expect(ButleryFieldBorder.visualBox(rect), rect);
    });

    test('a decorator taller than the touch target is drawn whole', () {
      const rect = Rect.fromLTWH(0, 0, 200, 96);
      expect(ButleryFieldBorder.visualBox(rect), rect);
    });
  });

  test('the outer path follows the visual box', () {
    const border = ButleryFieldBorder();
    final path = border.getOuterPath(const Rect.fromLTWH(0, 0, 200, 48));
    expect(path.getBounds().height, AppDimensions.controlVisualHeight);
  });

  const radius = BorderRadius.all(Radius.circular(8));
  const drawnBox = Rect.fromLTWH(0, 4, 200, 40);

  test('the inner path follows the visual box', () {
    final path = const ButleryFieldBorder(
      borderRadius: radius,
    ).getInnerPath(const Rect.fromLTWH(0, 0, 200, 48));
    final expected = const OutlineInputBorder(
      borderRadius: radius,
    ).getInnerPath(drawnBox);
    expect(path.getBounds(), expected.getBounds());
  });

  test('the outline is painted where a plain border paints a 40 box', () {
    RRect outline(InputBorder border, Rect rect) {
      final canvas = TestRecordingCanvas();
      border.paint(canvas, rect);
      return canvas.invocations
          .where((i) => i.invocation.memberName == #drawRRect)
          .map((i) => i.invocation.positionalArguments.first as RRect)
          .single;
    }

    expect(
      outline(
        const ButleryFieldBorder(borderRadius: radius),
        const Rect.fromLTWH(0, 0, 200, 48),
      ),
      outline(const OutlineInputBorder(borderRadius: radius), drawnBox),
    );
  });

  test('a lerp between two field borders stays a field border', () {
    const a = ButleryFieldBorder(borderSide: BorderSide(color: Colors.red));
    const b = ButleryFieldBorder(borderSide: BorderSide(color: Colors.blue));
    expect(ShapeBorder.lerp(a, b, 0.5), isA<ButleryFieldBorder>());
  });

  test('copyWith and scale keep the type', () {
    const border = ButleryFieldBorder();
    expect(border.copyWith(), isA<ButleryFieldBorder>());
    expect(border.scale(2), isA<ButleryFieldBorder>());
  });
}
