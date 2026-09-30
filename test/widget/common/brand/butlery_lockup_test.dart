/// B96-2: the locked logo lockup (Skarmar v12 del 2 #inloggning,
/// #inloggningmorkt). The masters embedded in [kButleryLockupLightSvg] and
/// [kButleryLockupDarkSvg] must stay byte-identical to the vendored files in
/// `assets/brand/`, and the widget must pick the dark variant by theme
/// brightness, paint without error, and size to the viewBox aspect ratio.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/brand/butlery_lockup.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('embedded SVG parity', () {
    test('the light const is byte-identical to the vendored asset', () {
      expect(
        kButleryLockupLightSvg,
        File(
          'assets/brand/Butlery-logo-stacked-tight-light-L4-3-outlined.svg',
        ).readAsStringSync(),
      );
    });

    test('the dark const is byte-identical to the vendored asset', () {
      expect(
        kButleryLockupDarkSvg,
        File(
          'assets/brand/Butlery-logo-stacked-tight-reversed-transparent-L4-3-outlined.svg',
        ).readAsStringSync(),
      );
    });
  });

  group('ButleryLockupDrawing.parse', () {
    test('both masters share the 600x245 viewBox', () {
      final light = ButleryLockupDrawing.parse(kButleryLockupLightSvg);
      final dark = ButleryLockupDrawing.parse(kButleryLockupDarkSvg);
      expect(light.viewBoxWidth, 600);
      expect(light.viewBoxHeight, 245);
      expect(dark.viewBoxWidth, 600);
      expect(dark.viewBoxHeight, 245);
    });

    test('resolves fill/stroke from attributes and from style, with group '
        'inheritance', () {
      final light = ButleryLockupDrawing.parse(kButleryLockupLightSvg);
      // The first group's paths: an attribute fill, an attribute stroke, and
      // a style-only fill (the "rect8" path uses style="fill:#CE7C1E").
      final glyphShapes = light.shapes.take(4).toList();
      expect(glyphShapes[0].fillColor, const Color(0xFF24382C));
      expect(glyphShapes[0].strokeColor, isNull);
      expect(glyphShapes[1].strokeColor, const Color(0xFFCE7C1E));
      expect(glyphShapes[1].strokeWidth, 7);
      expect(glyphShapes[1].cap, StrokeCap.round);
      expect(glyphShapes[3].fillColor, const Color(0xFFCE7C1E));

      // The second group carries fill only on the <g style="...">, and every
      // child path inherits it.
      final wordmarkShapes = light.shapes.skip(4);
      expect(wordmarkShapes, isNotEmpty);
      for (final shape in wordmarkShapes) {
        expect(shape.fillColor, const Color(0xFF24382C));
        expect(shape.strokeColor, isNull);
      }
    });

    test('the first group carries a non-identity matrix transform', () {
      final light = ButleryLockupDrawing.parse(kButleryLockupLightSvg);
      final m = light.shapes.first.transform;
      expect(m.entry(0, 0), closeTo(0.88461538, 0.0001));
      expect(m.entry(0, 3), closeTo(229.23077, 0.0001));
      expect(m.entry(1, 3), closeTo(1.5384615, 0.0001));

      // The second group has no transform attribute, so it is identity.
      final wordmarkShape = light.shapes.skip(4).first;
      expect(wordmarkShape.transform, Matrix4.identity());
    });

    test('the dark master swaps the glyph and word colours', () {
      final dark = ButleryLockupDrawing.parse(kButleryLockupDarkSvg);
      expect(dark.shapes.first.fillColor, const Color(0xFFCE7C1E));
      expect(dark.shapes.skip(4).first.fillColor, const Color(0xFFF5F4ED));
    });
  });

  group('ButleryLockup widget', () {
    testWidgets('paints without error and carries the Butlery label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const ButleryLockup()));
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Butlery'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a screen reader hears one image named Butlery', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const ButleryLockup()));
      expect(
        tester.getSemantics(find.byType(ButleryLockup)),
        matchesSemantics(label: 'Butlery', isImage: true),
      );
      handle.dispose();
    });

    testWidgets('sizes to width x width*245/600', (tester) async {
      await tester.pumpWidget(_host(const ButleryLockup(width: 148)));
      final size = tester.getSize(find.byType(ButleryLockup));
      expect(size.width, 148);
      expect(size.height, closeTo(148 * 245 / 600, 0.01));
    });

    testWidgets('a custom width still keeps the viewBox aspect ratio', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const ButleryLockup(width: 200)));
      final size = tester.getSize(find.byType(ButleryLockup));
      expect(size.width, 200);
      expect(size.height, closeTo(200 * 245 / 600, 0.01));
    });

    testWidgets('picks the dark variant under a dark theme', (tester) async {
      await tester.pumpWidget(
        _host(const ButleryLockup(), brightness: Brightness.dark),
      );
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(ButleryLockup),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter
              as ButleryLockupPainter;
      expect(
        painter.drawing.shapes.first.fillColor,
        const Color(0xFFCE7C1E),
        reason: 'the dark master paints the glyph in the saffron colour',
      );
    });

    testWidgets('picks the light variant under a light theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const ButleryLockup(), brightness: Brightness.light),
      );
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(ButleryLockup),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter
              as ButleryLockupPainter;
      expect(
        painter.drawing.shapes.first.fillColor,
        const Color(0xFF24382C),
        reason: 'the light master paints the glyph in ink',
      );
    });
  });
}
