// Package 7, P7-U04: the old radius constants are gone for good.
//
// Every corner in the app comes from the canonical radius scale
// (tokens.json space.radius: sharp 0, knob 2, control 8, card 12, pill 999,
// and $radiusNote for which role takes which step), read as
// AppDimensions.radiusSharp / radiusKnob / radiusControl / radiusCard /
// radiusPill, plus the checkbox's locked 6 (checkboxRadius). The legacy
// names below were 0.0 whatever their number said, so a call site that
// used them could not say what it meant. This test reddens when one of
// them comes back, in the app or in the tests, as a member or as a use.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';

/// Strips comments so a sentence that names a retired constant is allowed.
String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

List<String> _dartFiles(String dir) =>
    Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path.replaceAll(r'\', '/'))
        .where((p) => p.endsWith('.dart'))
        .toList()
      ..sort();

/// The retired names: borderRadius0…borderRadius100, borderRadiusRound,
/// the size aliases S/M/L/Xs and the component aliases.
final RegExp retiredRadius = RegExp(
  r'\b(borderRadius(0|2|4|6|7|8|10|12|16|20|25|100|Round|S|M|L|Xs|XL|Xl)'
  r'|cardBorderRadius|chipRadius|bottomSheetBorderRadius)\b',
);

void main() {
  group('retired radius names (P7-U04)', () {
    test('the pattern catches every retired name and no scale name', () {
      for (final retired in [
        'AppDimensions.borderRadius0',
        'AppDimensions.borderRadius8',
        'AppDimensions.borderRadius100',
        'AppDimensions.borderRadiusRound',
        'AppDimensions.borderRadiusS',
        'AppDimensions.borderRadiusM',
        'AppDimensions.borderRadiusL',
        'AppDimensions.borderRadiusXs',
        'AppDimensions.cardBorderRadius',
        'AppDimensions.chipRadius',
        'AppDimensions.bottomSheetBorderRadius',
      ]) {
        expect(retiredRadius.hasMatch(retired), isTrue, reason: retired);
      }
      for (final allowed in [
        'AppDimensions.radiusSharp',
        'AppDimensions.radiusKnob',
        'AppDimensions.radiusControl',
        'AppDimensions.radiusCard',
        'AppDimensions.radiusPill',
        'AppDimensions.checkboxRadius',
        'borderRadius: BorderRadius.circular(8)',
        'final BorderRadius borderRadius;',
      ]) {
        expect(retiredRadius.hasMatch(allowed), isFalse, reason: allowed);
      }
    });

    test('the scale is the tokens.json scale', () {
      expect(AppDimensions.radiusSharp, 0);
      expect(AppDimensions.radiusKnob, 2);
      expect(AppDimensions.radiusControl, 8);
      expect(AppDimensions.radiusCard, 12);
      expect(AppDimensions.radiusPill, 999);
    });

    test('no file in lib or test names a retired radius', () {
      final hits = <String>[];
      for (final path in [..._dartFiles('lib'), ..._dartFiles('test')]) {
        if (path.endsWith('test/architecture/retired_radius_names_test.dart')) {
          continue;
        }
        final lines = _code(path).split('\n');
        for (var i = 0; i < lines.length; i++) {
          final m = retiredRadius.firstMatch(lines[i]);
          if (m != null) hits.add('$path:${i + 1} ${m.group(0)}');
        }
      }
      expect(
        hits,
        isEmpty,
        reason:
            'Use the radius scale by role (tokens.json \$radiusNote): '
            'radiusControl for buttons, fields and trays, radiusCard for '
            'cards and sheets, radiusPill for chips, avatars and status '
            'pills, radiusKnob for thin bars, radiusSharp for editorial '
            'surfaces.',
      );
    });
  });
}
