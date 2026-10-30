import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

// The cloche is drawn from design/brand-mark.json by
// tools/generate_brand_assets.dart. These tests fail when a file that draws the
// mark stops agreeing with that source, so the icons, the splash and the
// in-app mark's lift and dome outline cannot drift apart.

Map<String, dynamic> _master() =>
    jsonDecode(File('design/brand-mark.json').readAsStringSync())
        as Map<String, dynamic>;

String _text(String path) => File(path).readAsStringSync();

List<double> _numbers(String d) => [
  for (final m in RegExp(r'-?\d*\.?\d+').allMatches(d))
    double.parse(m.group(0)!),
];

String _fmt(double v) {
  final s = v.toStringAsFixed(3);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = _master();
  final shapes = m['shapes'] as Map<String, dynamic>;
  final lift = m['opticalLift'] as Map<String, dynamic>;
  final android = m['android'] as Map<String, dynamic>;
  final scale = (android['scale'] as num).toDouble();
  final offset = (android['offset'] as num).toDouble();

  String translateY(String kind) =>
      _fmt(offset - (lift[kind] as num).toDouble() * scale);

  group('vector files read the master', () {
    for (final entry in {
      'android/app/src/main/res/drawable/ic_launcher_foreground.xml': 'filled',
      'android/app/src/main/res/drawable/ic_launcher_monochrome.xml': 'outline',
    }.entries) {
      test('${entry.key} is placed and drawn from the master', () {
        final xml = _text(entry.key);
        expect(
          xml,
          contains('android:translateY="${translateY(entry.value)}"'),
        );
        expect(xml, contains('android:translateX="${_fmt(offset)}"'));
        expect(xml, contains('android:scaleX="$scale"'));
        final dome = entry.value == 'filled' ? 'domeFilled' : 'domeOutline';
        expect(xml, contains('android:pathData="${shapes[dome]}"'));
        expect(xml, contains('android:pathData="${shapes['plate']}"'));
      });
    }

    for (final entry in {
      'design/exports/android/ic_launcher_foreground.svg': 'filled',
      'design/exports/android/ic_launcher_monochrome.svg': 'outline',
    }.entries) {
      test('${entry.key} is placed and drawn from the master', () {
        final svg = _text(entry.key);
        expect(
          svg,
          contains(
            'translate(${_fmt(offset)},${translateY(entry.value)}) '
            'scale($scale)',
          ),
        );
        final dome = entry.value == 'filled' ? 'domeFilled' : 'domeOutline';
        expect(svg, contains('d="${shapes[dome]}"'));
      });
    }

    test('the iOS master is raised by the filled lift', () {
      final svg = _text('design/exports/ios/AppIcon-1024.svg');
      expect(
        svg,
        contains('translate(0,${_fmt(-(lift['filled'] as num).toDouble())})'),
      );
      expect(svg, contains('d="${shapes['domeFilled']}"'));
    });
  });

  group('the in-app mark reads the master', () {
    final source = _text('lib/widgets/common/brand/butlery_cloche.dart');

    test('the plate crop is raised by the outline lift', () {
      final constant = RegExp(
        r'const double _opticalLift = ([\d.]+);',
      ).firstMatch(source)!.group(1)!;
      expect(double.parse(constant), (lift['outline'] as num).toDouble());
    });

    test('the dome is the master outline', () {
      final dome = RegExp(
        r"_dome = parseSvgPath\(\s*'([^']+)'",
      ).firstMatch(source)!.group(1)!;
      expect(_numbers(dome), _numbers(shapes['domeOutline'] as String));
    });
  });

  test('the iOS app icons have no alpha channel', () {
    final icons = [
      'design/exports/ios/AppIcon-1024.png',
      for (final e in Directory(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset',
      ).listSync())
        if (e.path.endsWith('.png')) e.path,
    ];
    for (final path in icons) {
      // Byte 25 of a PNG is its colour type: 2 is RGB, 6 is RGBA.
      expect(File(path).readAsBytesSync()[25], 2, reason: path);
    }
  });

  group('every raster icon has the mark optically centred', () {
    final files = <String>[
      'design/exports/ios/AppIcon-1024.png',
      for (final e in Directory(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset',
      ).listSync())
        if (e.path.endsWith('.png')) e.path,
      for (final e in Directory('android/app/src/main/res').listSync())
        if (e is Directory &&
            e.path.contains('mipmap-') &&
            !e.path.contains('anydpi'))
          '${e.path}/ic_launcher.png',
      'web/icons/Icon-192.png',
      'web/icons/Icon-512.png',
      'web/icons/Icon-maskable-192.png',
      'web/icons/Icon-maskable-512.png',
      'web/favicon.png',
      for (final s in ['', '@2x', '@3x'])
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$s.png',
    ];

    for (final path in files) {
      test(path, () async {
        await expectLater(
          Future(() async {
            final codec = await ui.instantiateImageCodec(
              File(path).readAsBytesSync(),
            );
            final image = (await codec.getNextFrame()).image;
            final data = (await image.toByteData())!;
            final w = image.width, h = image.height;
            // Ink is whatever is neither transparent nor the ground colour.
            var minY = h, maxY = -1, minX = w, maxX = -1;
            var sumY = 0.0, n = 0;
            for (var y = 0; y < h; y++) {
              for (var x = 0; x < w; x++) {
                final i = (y * w + x) * 4;
                final a = data.getUint8(i + 3);
                if (a < 200) continue;
                final r = data.getUint8(i);
                final g = data.getUint8(i + 1);
                final b = data.getUint8(i + 2);
                final nearGround =
                    (r - 0x24).abs() < 40 &&
                    (g - 0x38).abs() < 40 &&
                    (b - 0x2C).abs() < 40;
                if (nearGround) continue;
                minY = y < minY ? y : minY;
                maxY = y > maxY ? y : maxY;
                minX = x < minX ? x : minX;
                maxX = x > maxX ? x : maxX;
                sumY += y;
                n++;
              }
            }
            final tolerance = (h * 0.02).clamp(1.0, 1e9);
            final opticalY = ((minY + maxY + 1) / 2 + sumY / n + 0.5) / 2;
            expect(opticalY, closeTo(h / 2, tolerance), reason: path);
            expect(
              (minX + maxX + 1) / 2,
              closeTo(w / 2, tolerance),
              reason: path,
            );
          }),
          completes,
        );
      });
    }
  });
}
