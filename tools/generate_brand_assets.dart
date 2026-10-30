// tools/generate_brand_assets.dart
// Writes every file that draws the cloche mark from design/brand-mark.json, so
// the launcher icons, the splash, the store icons and the web icons share one
// source. test/architecture/brand_mark_single_source_test.dart fails when one
// of them stops agreeing with it.
//
// Usage: dart run tools/generate_brand_assets.dart && dart format \
//          lib/widgets/common/brand/brand_mark_geometry.dart

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const _ss = 8;

late final Map<String, dynamic> _m;
late final Map<String, dynamic> _shapes;
late final Map<String, dynamic> _strokes;
late final Map<String, dynamic> _android;
late final Map<String, dynamic> _lift;
late final double _vb;

double _d(Object? v) => (v as num).toDouble();

List<int> _rgb(String hex) => [
  for (var i = 1; i < 7; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
];

String _num(double v) {
  final s = v.toStringAsFixed(3);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

String _hex(String name) => (_m['colors'] as Map)[name] as String;

String _knobPath() {
  final k = _shapes['knob'] as Map;
  final x = _d(k['x']), y = _d(k['y']), w = _d(k['width']), h = _d(k['height']);
  final r = _d(k['radius']);
  String n(double v) => _num(v);
  return 'M${n(x + r)} ${n(y)}H${n(x + w - r)}A${n(r)} ${n(r)} 0 0 1 ${n(x + w)} ${n(y + r)}'
      'A${n(r)} ${n(r)} 0 0 1 ${n(x + w - r)} ${n(y + h)}H${n(x + r)}'
      'A${n(r)} ${n(r)} 0 0 1 ${n(x)} ${n(y + r)}A${n(r)} ${n(r)} 0 0 1 ${n(x + r)} ${n(y)}Z';
}

double _groupTy(String kind) =>
    _d(_android['offset']) - _d(_lift[kind]) * _d(_android['scale']);

String _androidGroup(String kind) =>
    'translate(${_num(_d(_android['offset']))},${_num(_groupTy(kind))}) '
    'scale(${_d(_android['scale'])})';

void _write(String path, String text) {
  final f = File(path)..createSync(recursive: true);
  f.writeAsStringSync(text);
}

String _svgForeground() {
  final d = _num(_d(_android['canvas']));
  return '<svg xmlns="http://www.w3.org/2000/svg" width="$d" height="$d" viewBox="0 0 $d $d">'
      '<g transform="${_androidGroup('filled')}">'
      '<path d="${_shapes['stem']}" stroke="${_hex('saffron')}" stroke-width="${_strokes['stem']}" stroke-linecap="round" fill="none"></path>'
      '<path d="${_shapes['domeFilled']}" fill="${_hex('saffron')}"></path>'
      '<path d="${_shapes['plate']}" stroke="${_hex('cream')}" stroke-width="${_strokes['plate']}" stroke-linecap="round" fill="none"></path>'
      '<path d="${_knobPath()}" fill="${_hex('saffron')}"></path>'
      '</g></svg>';
}

String _svgMonochrome() {
  final d = _num(_d(_android['canvas']));
  return '<svg xmlns="http://www.w3.org/2000/svg" width="$d" height="$d" viewBox="0 0 $d $d">'
      '<g transform="${_androidGroup('outline')}" fill="none" stroke="#000000" stroke-width="${_strokes['dome']}">'
      '<path d="${_shapes['stem']}" stroke-width="${_strokes['stem']}" stroke-linecap="round"></path>'
      '<path d="${_shapes['domeOutline']}" stroke-linecap="butt"></path>'
      '<path d="${_shapes['plate']}" stroke-linecap="round"></path>'
      '<path d="${_knobPath()}" fill="#000000" stroke="none"></path>'
      '</g></svg>';
}

String _svgBackground() {
  final d = _num(_d(_android['canvas']));
  return '<svg xmlns="http://www.w3.org/2000/svg" width="$d" height="$d" viewBox="0 0 $d $d">'
      '<rect width="$d" height="$d" fill="${_hex('ground')}"></rect></svg>';
}

String _svgIosMaster() {
  final v = _num(_vb);
  return '<?xml version="1.0"?>\n'
      '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 $v $v">'
      '<rect width="$v" height="$v" fill="${_hex('ground')}"></rect>'
      '<g transform="translate(0,${_num(-_d(_lift['filled']))})">'
      '<path d="${_shapes['stem']}" stroke="${_hex('saffron')}" stroke-width="${_strokes['stem']}" stroke-linecap="round"></path>'
      '<path d="${_shapes['domeFilled']}" fill="${_hex('saffron')}"></path>'
      '<path d="${_shapes['plate']}" stroke="${_hex('cream')}" stroke-width="${_strokes['plate']}" stroke-linecap="round"></path>'
      '<path d="${_knobPath()}" fill="${_hex('saffron')}"></path>'
      '</g></svg>';
}

String _xmlVector(String kind) {
  final mono = kind == 'outline';
  String col(String c) => mono ? '#FFFFFF' : _hex(c).toUpperCase();
  final d = _num(_d(_android['canvas']));
  final dome = mono
      ? '        <path\n            android:pathData="${_shapes['domeOutline']}"\n'
            '            android:strokeColor="#FFFFFF"\n            android:strokeWidth="${_strokes['dome']}"\n'
            '            android:strokeLineCap="butt"/>\n'
      : '        <path\n            android:fillColor="${col('saffron')}"\n'
            '            android:pathData="${_shapes['domeFilled']}"/>\n';
  final head = mono
      ? "    <!-- Source: design/brand-mark.json. Android 13+ tints this from the user's\n"
            '         wallpaper, so every shape is solid white. -->\n'
      : '    <!-- Source: design/brand-mark.json -->\n';
  return '<?xml version="1.0" encoding="utf-8"?>\n'
      '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
      '    android:width="${d}dp"\n    android:height="${d}dp"\n'
      '    android:viewportWidth="$d"\n    android:viewportHeight="$d">\n'
      '$head'
      '    <group\n'
      '        android:translateX="${_num(_d(_android['offset']))}"\n'
      '        android:translateY="${_num(_groupTy(kind))}"\n'
      '        android:scaleX="${_d(_android['scale'])}"\n        android:scaleY="${_d(_android['scale'])}">\n'
      '        <path\n            android:pathData="${_shapes['stem']}"\n'
      '            android:strokeColor="${col('saffron')}"\n            android:strokeWidth="${_strokes['stem']}"\n'
      '            android:strokeLineCap="round"/>\n'
      '$dome'
      '        <path\n            android:pathData="${_shapes['plate']}"\n'
      '            android:strokeColor="${col('cream')}"\n            android:strokeWidth="${_strokes['plate']}"\n'
      '            android:strokeLineCap="round"/>\n'
      '        <path\n            android:fillColor="${col('saffron')}"\n'
      '            android:pathData="${_knobPath()}"/>\n'
      '    </group>\n</vector>\n';
}

String _dartGeometry() {
  final k = _shapes['knob'] as Map;
  final crop = ((_m['inAppMark'] as Map)['crop'] as List).map(_d).toList();
  return '// GENERATED by tools/generate_brand_assets.dart from design/brand-mark.json.\n'
      '// Do not edit by hand; edit the JSON and rerun the tool.\n'
      'library;\n\n'
      "const String brandDomeOutlinePath = '${_shapes['domeOutline']}';\n"
      "const String brandPlatePath = '${_shapes['plate']}';\n"
      "const String brandStemPath = '${_shapes['stem']}';\n"
      'const double brandKnobLeft = ${_d(k['x'])};\n'
      'const double brandKnobTop = ${_d(k['y'])};\n'
      'const double brandKnobWidth = ${_d(k['width'])};\n'
      'const double brandKnobHeight = ${_d(k['height'])};\n'
      'const double brandKnobRadius = ${_d(k['radius'])};\n'
      'const double brandPlateStroke = ${_d(_strokes['plate'])};\n'
      'const double brandDomeStroke = ${_d(_strokes['dome'])};\n'
      'const double brandStemStroke = ${_d(_strokes['stem'])};\n'
      'const double brandOpticalLiftOutline = ${_d(_lift['outline'])};\n'
      'const double brandMarkCropLeft = ${crop[0]};\n'
      'const double brandMarkCropTop = ${crop[1]};\n'
      'const double brandMarkCropSize = ${crop[2]};\n';
}

typedef _Pt = (double, double);

/// The subset of SVG path syntax the mark uses: M, C, L, H, V, Z, absolute.
List<_Pt> _parsePath(String d) {
  final toks = RegExp(
    r'[MCLHVZ]|-?\d*\.?\d+',
  ).allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  double nxt() => double.parse(toks[i++]);
  final out = <_Pt>[];
  _Pt cur = (0, 0);
  String? cmd;
  while (i < toks.length) {
    if ('MCLHVZ'.contains(toks[i]) && toks[i].length == 1) {
      cmd = toks[i++];
      if (cmd == 'Z') continue;
    }
    switch (cmd) {
      case 'M':
        cur = (nxt(), nxt());
        out.add(cur);
        cmd = 'L';
      case 'L':
        cur = (nxt(), nxt());
        out.add(cur);
      case 'H':
        cur = (nxt(), cur.$2);
        out.add(cur);
      case 'V':
        cur = (cur.$1, nxt());
        out.add(cur);
      case 'C':
        final p1 = (nxt(), nxt());
        final p2 = (nxt(), nxt());
        final p3 = (nxt(), nxt());
        for (var k = 1; k <= 60; k++) {
          final t = k / 60;
          double b(double a, double b1, double c, double e) =>
              math.pow(1 - t, 3) * a +
              3 * math.pow(1 - t, 2) * t * b1 +
              3 * (1 - t) * t * t * c +
              t * t * t * e;
          out.add((
            b(cur.$1, p1.$1, p2.$1, p3.$1),
            b(cur.$2, p1.$2, p2.$2, p3.$2),
          ));
        }
        cur = p3;
    }
  }
  return out;
}

/// An RGBA canvas drawn at [_ss] times its final size.
class _Canvas {
  _Canvas(this.w, this.h) : px = Uint8List(w * _ss * h * _ss * 4);
  final int w, h;
  final Uint8List px;
  int get sw => w * _ss;
  int get sh => h * _ss;

  void fillAll(List<int> c) {
    for (var i = 0; i < px.length; i += 4) {
      px[i] = c[0];
      px[i + 1] = c[1];
      px[i + 2] = c[2];
      px[i + 3] = 255;
    }
  }

  /// Even-odd scanline fill; points are in final-size units.
  void poly(List<_Pt> pts, List<int> c) {
    final p = [for (final q in pts) (q.$1 * _ss, q.$2 * _ss)];
    var minY = p.first.$2, maxY = p.first.$2;
    for (final q in p) {
      minY = math.min(minY, q.$2);
      maxY = math.max(maxY, q.$2);
    }
    for (
      var y = math.max(0, minY.floor());
      y <= math.min(sh - 1, maxY.ceil());
      y++
    ) {
      final cy = y + 0.5;
      final xs = <double>[];
      for (var i = 0; i < p.length; i++) {
        final a = p[i], b = p[(i + 1) % p.length];
        if ((a.$2 <= cy && b.$2 > cy) || (b.$2 <= cy && a.$2 > cy)) {
          xs.add(a.$1 + (cy - a.$2) / (b.$2 - a.$2) * (b.$1 - a.$1));
        }
      }
      xs.sort();
      for (var k = 0; k + 1 < xs.length; k += 2) {
        final x0 = math.max(0, (xs[k] - 0.5).ceil());
        final x1 = math.min(sw - 1, (xs[k + 1] - 0.5).floor());
        for (var x = x0; x <= x1; x++) {
          final i = (y * sw + x) * 4;
          px[i] = c[0];
          px[i + 1] = c[1];
          px[i + 2] = c[2];
          px[i + 3] = 255;
        }
      }
    }
  }

  List<_Pt> _circle(double cx, double cy, double r) => [
    for (var i = 0; i < 160; i++)
      (
        cx + r * math.cos(i / 160 * 2 * math.pi),
        cy + r * math.sin(i / 160 * 2 * math.pi),
      ),
  ];

  void disk(double cx, double cy, double r, List<int> c) =>
      poly(_circle(cx, cy, r), c);

  /// A horizontal or vertical line with round or flat caps.
  void line(_Pt a, _Pt b, double width, List<int> c, {bool round = true}) {
    final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
    final len = math.sqrt(dx * dx + dy * dy);
    final nx = -dy / len * width / 2, ny = dx / len * width / 2;
    poly([
      (a.$1 + nx, a.$2 + ny),
      (b.$1 + nx, b.$2 + ny),
      (b.$1 - nx, b.$2 - ny),
      (a.$1 - nx, a.$2 - ny),
    ], c);
    if (round) {
      disk(a.$1, a.$2, width / 2, c);
      disk(b.$1, b.$2, width / 2, c);
    }
  }

  img.Image finish() {
    final out = img.Image(width: w, height: h, numChannels: 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var r = 0, g = 0, b = 0, a = 0;
        for (var j = 0; j < _ss; j++) {
          for (var i = 0; i < _ss; i++) {
            final k = ((y * _ss + j) * sw + x * _ss + i) * 4;
            final al = px[k + 3];
            r += px[k] * al;
            g += px[k + 1] * al;
            b += px[k + 2] * al;
            a += al;
          }
        }
        if (a == 0) {
          out.setPixelRgba(x, y, 0, 0, 0, 0);
        } else {
          out.setPixelRgba(
            x,
            y,
            (r / a).round(),
            (g / a).round(),
            (b / a).round(),
            (a / (_ss * _ss)).round(),
          );
        }
      }
    }
    return out;
  }
}

void _drawMark(_Canvas cv, double left, double top, double size, String kind) {
  final s = size / _vb;
  final dy = -_d(_lift[kind]);
  _Pt t(_Pt p) => (left + p.$1 * s, top + (p.$2 + dy) * s);
  final saffron = _rgb(_hex('saffron')), cream = _rgb(_hex('cream'));
  final stem = _parsePath(_shapes['stem'] as String);
  cv.line(t(stem[0]), t(stem[1]), _d(_strokes['stem']) * s, saffron);
  cv.poly([
    for (final p in _parsePath(_shapes['domeFilled'] as String)) t(p),
  ], saffron);
  final plate = _parsePath(_shapes['plate'] as String);
  cv.line(t(plate[0]), t(plate[1]), _d(_strokes['plate']) * s, cream);
  final k = _shapes['knob'] as Map;
  final x = _d(k['x']),
      y = _d(k['y']),
      w = _d(k['width']),
      h = _d(k['height']),
      r = _d(k['radius']);
  final pts = <_Pt>[];
  for (var q = 0; q < 4; q++) {
    final cx = q < 2 ? x + w - r : x + r;
    final cy = q == 0 || q == 3 ? y + r : y + h - r;
    for (var i = 0; i <= 24; i++) {
      final a = (q * 90 - 90 + i / 24 * 90) * math.pi / 180;
      pts.add((cx + r * math.cos(a), cy + r * math.sin(a)));
    }
  }
  cv.poly([for (final p in pts) t(p)], saffron);
}

img.Image _fullBleed(int px, [double scale = 1]) {
  final cv = _Canvas(px, px)..fillAll(_rgb(_hex('ground')));
  final size = px * scale;
  _drawMark(cv, (px - size) / 2, (px - size) / 2, size, 'filled');
  // App Store Connect rejects an app icon with an alpha channel.
  return cv.finish().convert(numChannels: 3);
}

/// The ground-coloured disk with the mark, as the Android 12 splash draws it,
/// on a transparent canvas.
img.Image _splashDisk(int w, int h, int diameter) {
  final cv = _Canvas(w, h);
  cv.disk(w / 2, h / 2, diameter / 2, _rgb(_hex('ground')));
  final size =
      diameter * _d(_android['scale']) * _vb / _d(_android['splashCircle']);
  _drawMark(cv, (w - size) / 2, (h - size) / 2, size, 'filled');
  return cv.finish();
}

void _png(String path, img.Image image) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(image));
}

int _width(String path) => img.decodePng(File(path).readAsBytesSync())!.width;

List<String> _pngs(String dir, bool Function(String) keep) => [
  for (final e in Directory(dir).listSync(recursive: true))
    if (e is File && e.path.endsWith('.png') && keep(e.path))
      e.path.replaceAll(r'\', '/'),
]..sort();

void main() {
  _m =
      jsonDecode(File('design/brand-mark.json').readAsStringSync())
          as Map<String, dynamic>;
  _shapes = _m['shapes'] as Map<String, dynamic>;
  _strokes = _m['strokes'] as Map<String, dynamic>;
  _android = _m['android'] as Map<String, dynamic>;
  _lift = _m['opticalLift'] as Map<String, dynamic>;
  _vb = _d(_m['viewBox']);

  _write('design/exports/android/ic_launcher_foreground.svg', _svgForeground());
  _write('design/exports/android/ic_launcher_monochrome.svg', _svgMonochrome());
  _write('design/exports/android/ic_launcher_background.svg', _svgBackground());
  _write('design/exports/ios/AppIcon-1024.svg', _svgIosMaster());
  _write(
    'lib/widgets/common/brand/brand_mark_geometry.dart',
    _dartGeometry(),
  );
  _write(
    'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
    _xmlVector('filled'),
  );
  _write(
    'android/app/src/main/res/drawable/ic_launcher_monochrome.xml',
    _xmlVector('outline'),
  );

  _png('design/exports/ios/AppIcon-1024.png', _fullBleed(1024));
  for (final f in _pngs(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset',
    (_) => true,
  )) {
    _png(f, _fullBleed(_width(f)));
  }
  for (final f in _pngs(
    'android/app/src/main/res',
    (p) => p.contains('/mipmap-') && p.endsWith('ic_launcher.png'),
  )) {
    _png(f, _fullBleed(_width(f)));
  }

  final maskable = _d((_m['web'] as Map)['maskableScale']);
  _png('web/icons/Icon-192.png', _fullBleed(192));
  _png('web/icons/Icon-512.png', _fullBleed(512));
  _png('web/icons/Icon-maskable-192.png', _fullBleed(192, maskable));
  _png('web/icons/Icon-maskable-512.png', _fullBleed(512, maskable));
  _png('web/favicon.png', _fullBleed(32));

  const launch = {'': 1, '@2x': 2, '@3x': 3};
  launch.forEach((suffix, k) {
    _png(
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png',
      _splashDisk(168 * k, 185 * k, 168 * k),
    );
  });
  print('Brand assets written from design/brand-mark.json');
}
