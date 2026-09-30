/// B96-2: the locked logo lockup (Skarmar v12 del 2 #inloggning rad 1467-1490,
/// #inloggningmorkt rad 1205-1228). The logo is never written as text
/// (beslut 2026-09-30, B96-2 = A) -- this widget paints the vendored SVG
/// masters synchronously, the same approach `ButleryIcon` uses for glyphs
/// (`lib/widgets/common/icons/butlery_glyph.dart`), so there is no asset
/// load and no new package (B-02: our own family, no library).
///
/// The two masters are vendored byte-identical to `assets/brand/*.svg` and
/// embedded here as exact-text consts;
/// `test/widget/common/brand/butlery_lockup_test.dart` checks both stay in
/// sync with the files on disk.
library;

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart'
    show parseSvgPath;

/// Exact text of
/// `assets/brand/Butlery-logo-stacked-tight-light-L4-3-outlined.svg`.
const String kButleryLockupLightSvg = '''
<?xml version="1.0"?>
<svg width="600" height="245" viewBox="0 0 600 245" version="1.1" id="svg14" xmlns="http://www.w3.org/2000/svg" xmlns:svg="http://www.w3.org/2000/svg">
  <defs id="defs18"></defs>
  <g transform="matrix(0.88461538,0,0,0.88461538,229.23077,1.5384615)" id="g10">
    <path d="m 37,104 c 2,-25 18.92,-43 43,-43 24.08,0 41,18 43,43 z" fill="#24382c" id="path2"></path>
    <path d="M 28,113 H 132" stroke="#CE7C1E" stroke-width="7" stroke-linecap="round" id="path4"></path>
    <path d="m 80,55 v 5" stroke="#CE7C1E" stroke-width="3.5" stroke-linecap="round" id="path6"></path>
    <path id="rect8" style="fill:#CE7C1E" d="m 76,48 h 8 c 2.216,0 4,1.784 4,4 0,2.216 -1.784,4 -4,4 h -8 c -2.216,0 -4,-1.784 -4,-4 0,-2.216 1.784,-4 4,-4 z"></path>
  </g>
  <g aria-label="Butlery" id="text12" style="font-weight:600;font-size:92px;font-family:&#39;Butlery Sans&#39;;letter-spacing:-1.35;text-anchor:middle;fill:#24382c">
    <path d="m 146.68414,180 v -67.068 h 33.396 c 13.708,0 20.7,6.808 20.7,17.204 0,7.36 -3.956,12.972 -11.5,14.812 v 0.552 c 9.016,1.472 13.34,7.636 13.34,15.548 0,12.328 -8.832,18.952 -23.736,18.952 z m 12.236,-9.476 h 18.4 c 8.832,0 12.604,-4.14 12.604,-10.304 0,-6.624 -4.324,-9.936 -11.776,-9.936 h -20.424 v -9.2 h 19.872 c 7.36,0 10.764,-3.588 10.764,-9.292 0,-6.256 -4.508,-9.384 -11.408,-9.384 h -18.032 z" id="path21"></path>
    <path d="m 228.5021,180.828 c -7.452,0 -13.064,-2.944 -15.732,-8.832 -1.38,-2.944 -2.116,-6.532 -2.116,-10.856 v -30.084 h 11.592 v 27.14 c 0,8.464 3.128,13.156 10.672,13.156 7.544,0 12.328,-5.888 12.328,-13.8 v -26.496 h 11.592 V 180 h -11.132 l -0.46,-9.476 h -0.644 c -2.484,6.624 -8.74,10.304 -16.1,10.304 z" id="path23"></path>
    <path d="m 284.0081,180 c -8.004,0 -11.868,-3.68 -11.868,-11.868 V 140.44 h -9.108 v -9.384 h 9.108 V 117.44 l 11.868,-1.564 v 15.18 h 10.856 v 9.384 h -10.856 v 25.208 c 0,3.312 1.564,4.508 4.508,4.508 h 6.44 V 180 Z" id="path25"></path>
    <path d="m 302.34602,180 v -67.068 h 11.868 V 180 Z" id="path27"></path>
    <path d="m 346.35201,180.828 c -15.64,0 -24.748,-9.936 -24.748,-25.024 0,-15.824 9.476,-25.576 24.38,-25.576 16.928,0 25.024,11.408 23.736,27.784 h -36.248 c 0.184,9.2 5.244,13.984 12.972,13.984 5.98,0 10.212,-2.76 11.408,-6.808 h 11.408 c -1.472,9.752 -10.764,15.64 -22.908,15.64 z m -12.972,-29.072 -0.92,-1.196 h 26.496 l -1.012,1.196 c 0.184,-8.648 -4.6,-12.788 -11.96,-12.788 -7.544,0 -12.236,4.692 -12.604,12.788 z" id="path29"></path>
    <path d="m 377.10992,180 v -48.944 h 10.672 l 0.552,8.188 h 0.46 c 2.116,-5.98 7.452,-8.924 13.8,-8.924 1.196,0 2.208,0.092 3.22,0.184 v 11.04 c -0.828,-0.092 -2.208,-0.184 -3.404,-0.184 -8.648,0 -13.064,4.232 -13.432,12.328 V 180 Z" id="path31"></path>
    <path d="m 412.37594,195.364 v -9.66 h 5.704 c 4.6,0 6.992,-1.748 8.464,-5.428 l 2.484,-6.072 v 4.14 l -20.792,-47.288 h 12.972 l 8.924,24.564 3.588,9.752 h 0.552 l 3.404,-9.752 8.464,-24.564 h 12.604 l -20.976,52.164 c -3.68,9.2 -9.292,12.144 -17.756,12.144 z" id="path33"></path>
  </g>
</svg>''';

/// Exact text of
/// `assets/brand/Butlery-logo-stacked-tight-reversed-transparent-L4-3-outlined.svg`.
const String kButleryLockupDarkSvg = '''
<?xml version="1.0"?>
<svg width="600" height="245" viewBox="0 0 600 245" version="1.1" id="svg16" xmlns="http://www.w3.org/2000/svg" xmlns:svg="http://www.w3.org/2000/svg">
  <defs id="defs20"></defs>
  <g transform="matrix(0.88461538,0,0,0.88461538,229.23077,1.5384615)" id="g12">
    <path d="m 37,104 c 2,-25 18.92,-43 43,-43 24.08,0 41,18 43,43 z" fill="#CE7C1E" id="path4"></path>
    <path d="M 28,113 H 132" stroke="#f5f4ed" stroke-width="7" stroke-linecap="round" id="path6"></path>
    <path d="m 80,55 v 5" stroke="#CE7C1E" stroke-width="3.5" stroke-linecap="round" id="path8"></path>
    <path id="rect10" style="fill:#CE7C1E" d="m 76,48 h 8 c 2.216,0 4,1.784 4,4 0,2.216 -1.784,4 -4,4 h -8 c -2.216,0 -4,-1.784 -4,-4 0,-2.216 1.784,-4 4,-4 z"></path>
  </g>
  <g aria-label="Butlery" id="text14" style="font-weight:600;font-size:92px;font-family:&#39;Butlery Sans&#39;;letter-spacing:-1.35;text-anchor:middle;fill:#f5f4ed">
    <path d="m 146.68414,180 v -67.068 h 33.396 c 13.708,0 20.7,6.808 20.7,17.204 0,7.36 -3.956,12.972 -11.5,14.812 v 0.552 c 9.016,1.472 13.34,7.636 13.34,15.548 0,12.328 -8.832,18.952 -23.736,18.952 z m 12.236,-9.476 h 18.4 c 8.832,0 12.604,-4.14 12.604,-10.304 0,-6.624 -4.324,-9.936 -11.776,-9.936 h -20.424 v -9.2 h 19.872 c 7.36,0 10.764,-3.588 10.764,-9.292 0,-6.256 -4.508,-9.384 -11.408,-9.384 h -18.032 z" id="path23"></path>
    <path d="m 228.5021,180.828 c -7.452,0 -13.064,-2.944 -15.732,-8.832 -1.38,-2.944 -2.116,-6.532 -2.116,-10.856 v -30.084 h 11.592 v 27.14 c 0,8.464 3.128,13.156 10.672,13.156 7.544,0 12.328,-5.888 12.328,-13.8 v -26.496 h 11.592 V 180 h -11.132 l -0.46,-9.476 h -0.644 c -2.484,6.624 -8.74,10.304 -16.1,10.304 z" id="path25"></path>
    <path d="m 284.0081,180 c -8.004,0 -11.868,-3.68 -11.868,-11.868 V 140.44 h -9.108 v -9.384 h 9.108 V 117.44 l 11.868,-1.564 v 15.18 h 10.856 v 9.384 h -10.856 v 25.208 c 0,3.312 1.564,4.508 4.508,4.508 h 6.44 V 180 Z" id="path27"></path>
    <path d="m 302.34602,180 v -67.068 h 11.868 V 180 Z" id="path29"></path>
    <path d="m 346.35201,180.828 c -15.64,0 -24.748,-9.936 -24.748,-25.024 0,-15.824 9.476,-25.576 24.38,-25.576 16.928,0 25.024,11.408 23.736,27.784 h -36.248 c 0.184,9.2 5.244,13.984 12.972,13.984 5.98,0 10.212,-2.76 11.408,-6.808 h 11.408 c -1.472,9.752 -10.764,15.64 -22.908,15.64 z m -12.972,-29.072 -0.92,-1.196 h 26.496 l -1.012,1.196 c 0.184,-8.648 -4.6,-12.788 -11.96,-12.788 -7.544,0 -12.236,4.692 -12.604,12.788 z" id="path31"></path>
    <path d="m 377.10992,180 v -48.944 h 10.672 l 0.552,8.188 h 0.46 c 2.116,-5.98 7.452,-8.924 13.8,-8.924 1.196,0 2.208,0.092 3.22,0.184 v 11.04 c -0.828,-0.092 -2.208,-0.184 -3.404,-0.184 -8.648,0 -13.064,4.232 -13.432,12.328 V 180 Z" id="path33"></path>
    <path d="m 412.37594,195.364 v -9.66 h 5.704 c 4.6,0 6.992,-1.748 8.464,-5.428 l 2.484,-6.072 v 4.14 l -20.792,-47.288 h 12.972 l 8.924,24.564 3.588,9.752 h 0.552 l 3.404,-9.752 8.464,-24.564 h 12.604 l -20.976,52.164 c -3.68,9.2 -9.292,12.144 -17.756,12.144 z" id="path35"></path>
  </g>
</svg>''';

/// The locked Butlery logo lockup, painted from its SVG master.
///
/// Picks the light or dark variant from `Theme.of(context).brightness` (both
/// share the 600x245 viewBox, so the aspect ratio is identical either way).
/// [width] follows the drawing's 148 px block width by default.
class ButleryLockup extends StatelessWidget {
  /// Creates a lockup.
  const ButleryLockup({super.key, this.width = 148});

  /// The rendered width; height follows the viewBox aspect ratio.
  final double width;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawing = ButleryLockupDrawing.of(
      isDark ? kButleryLockupDarkSvg : kButleryLockupLightSvg,
    );
    final height = width * drawing.viewBoxHeight / drawing.viewBoxWidth;
    return Semantics(
      label: 'Butlery',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(painter: ButleryLockupPainter(drawing)),
        ),
      ),
    );
  }
}

/// Paints a parsed [ButleryLockupDrawing], scaled to fill the canvas width
/// while keeping the viewBox aspect ratio.
class ButleryLockupPainter extends CustomPainter {
  /// Creates a painter.
  ButleryLockupPainter(this.drawing);

  /// The parsed lockup to paint.
  final ButleryLockupDrawing drawing;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || drawing.viewBoxWidth <= 0) return;
    final scale = size.width / drawing.viewBoxWidth;
    canvas.save();
    canvas.scale(scale);
    for (final shape in drawing.shapes) {
      canvas.save();
      canvas.transform(shape.transform.storage);
      if (shape.fillColor != null) {
        canvas.drawPath(
          shape.path,
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.fill
            ..color = shape.fillColor!,
        );
      }
      if (shape.strokeColor != null) {
        canvas.drawPath(
          shape.path,
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke
            ..color = shape.strokeColor!
            ..strokeCap = shape.cap
            ..strokeWidth = shape.strokeWidth,
        );
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ButleryLockupPainter oldDelegate) =>
      oldDelegate.drawing != drawing;
}

/// One painted path of the lockup, with the affine transform of its parent
/// `<g>` (identity when the group has none).
@immutable
class ButleryLockupShape {
  /// Creates a shape.
  const ButleryLockupShape({
    required this.path,
    required this.transform,
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
    required this.cap,
  });

  /// Geometry in viewBox units, before [transform].
  final Path path;

  /// The parent `<g>`'s `transform="matrix(...)"`, or identity.
  final Matrix4 transform;

  /// Resolved fill colour, or null when `fill="none"`/absent.
  final Color? fillColor;

  /// Resolved stroke colour, or null when `stroke="none"`/absent.
  final Color? strokeColor;

  /// Stroke width in viewBox units.
  final double strokeWidth;

  /// Stroke cap.
  final StrokeCap cap;
}

/// A parsed lockup master: its viewBox size and its shapes, in paint order.
@immutable
class ButleryLockupDrawing {
  /// Creates a drawing.
  const ButleryLockupDrawing(
    this.viewBoxWidth,
    this.viewBoxHeight,
    this.shapes,
  );

  /// The viewBox width (600 for both masters).
  final double viewBoxWidth;

  /// The viewBox height (245 for both masters).
  final double viewBoxHeight;

  /// The shapes in paint order.
  final List<ButleryLockupShape> shapes;

  static final Map<String, ButleryLockupDrawing> _cache = {};

  /// The parsed drawing for the exact SVG text [svg], cached.
  static ButleryLockupDrawing of(String svg) =>
      _cache.putIfAbsent(svg, () => parse(svg));

  /// Parses a lockup master.
  ///
  /// Supports what the two masters use: a `<g transform="matrix(...)">`
  /// wrapping `<path>` elements whose `fill`/`stroke`/`stroke-width`/
  /// `stroke-linecap` come from the element's own attribute, its own
  /// `style`, or (inherited) the parent `<g>`'s attribute or `style` -- in
  /// that priority order.
  static ButleryLockupDrawing parse(String svg) {
    final root = XmlDocument.parse(svg).rootElement;
    final viewBox = root
        .getAttribute('viewBox')!
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.parse)
        .toList();
    final shapes = <ButleryLockupShape>[];
    for (final group in root.childElements.where(
      (e) => e.name.local == 'g',
    )) {
      final groupStyle = _parseStyle(group.getAttribute('style'));
      String? groupAttr(String name) =>
          group.getAttribute(name) ?? groupStyle[name];
      final transform = _parseMatrix(group.getAttribute('transform'));
      for (final el in group.childElements.where(
        (e) => e.name.local == 'path',
      )) {
        final style = _parseStyle(el.getAttribute('style'));
        String? attr(String name) =>
            el.getAttribute(name) ?? style[name] ?? groupAttr(name);
        final fill = attr('fill');
        final stroke = attr('stroke');
        shapes.add(
          ButleryLockupShape(
            path: parseSvgPath(el.getAttribute('d')!),
            transform: transform,
            fillColor: (fill == null || fill == 'none')
                ? null
                : _parseColor(fill),
            strokeColor: (stroke == null || stroke == 'none')
                ? null
                : _parseColor(stroke),
            strokeWidth: double.tryParse(attr('stroke-width').orEmpty()) ?? 1,
            cap: switch (attr('stroke-linecap')) {
              'round' => StrokeCap.round,
              'square' => StrokeCap.square,
              _ => StrokeCap.butt,
            },
          ),
        );
      }
    }
    return ButleryLockupDrawing(
      viewBox[2],
      viewBox[3],
      List.unmodifiable(shapes),
    );
  }

  static Map<String, String> _parseStyle(String? style) {
    if (style == null || style.isEmpty) return const {};
    final map = <String, String>{};
    for (final decl in style.split(';')) {
      final parts = decl.split(':');
      if (parts.length != 2) continue;
      map[parts[0].trim()] = parts[1].trim();
    }
    return map;
  }

  static Matrix4 _parseMatrix(String? transform) {
    if (transform == null) return Matrix4.identity();
    final match = RegExp(r'matrix\(([^)]+)\)').firstMatch(transform);
    if (match == null) return Matrix4.identity();
    final values = match
        .group(1)!
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.parse)
        .toList();
    final a = values[0], b = values[1], c = values[2];
    final d = values[3], e = values[4], f = values[5];
    final m = Matrix4.identity();
    m.setEntry(0, 0, a);
    m.setEntry(1, 0, b);
    m.setEntry(0, 1, c);
    m.setEntry(1, 1, d);
    m.setEntry(0, 3, e);
    m.setEntry(1, 3, f);
    return m;
  }

  static Color _parseColor(String css) {
    final hex = css.trim().replaceFirst('#', '');
    final value = int.parse(hex, radix: 16);
    return Color(0xFF000000 | value);
  }
}
