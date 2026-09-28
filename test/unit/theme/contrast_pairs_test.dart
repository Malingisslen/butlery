/// P8-U02: every declared contrast pair, measured on the colours the app
/// was generated with, in light and in dark.
///
/// Source: tokens.json contrastPairs (36 pairs) and contrastPolicy, vendored
/// in test/fixtures/design/contrast_pairs.json with the file's sha256. Each
/// token is resolved to the generated member whose doc line names it
/// ("· semantic.text.primary", "(dark)" in app_colors_dark.dart), so the
/// measure follows the generated files and never a copy of their values.
///
/// A pair with no generated member cannot be measured in the app. It must be
/// listed in [knownContrastGaps] with its ticket, and the test fails when the
/// member arrives but the entry is still there (decision Q8-01 = A).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

/// Pairs that cannot be measured today, by "fg on bg", with their ticket.
const knownContrastGaps = <String, String>{
  'text.bodyMuted on surface.base': 'BUT-2159',
  'text.completed on surface.base': 'BUT-2147',
  'text.accent on surface.base': 'BUT-2191',
  'text.disabled on surface.base': 'BUT-2191',
  'control.checked.foreground on control.checked.background': 'BUT-2191',
  'dataScale.onFill.step1 on dataScale.sequential[0]': 'BUT-2191',
  'dataScale.onFill.step2 on dataScale.sequential[1]': 'BUT-2191',
  'dataScale.onFill.step3 on dataScale.sequential[2]': 'BUT-2191',
  'dataScale.onFill.step4 on dataScale.sequential[3]': 'BUT-2191',
  'dataScale.onFill.step5 on dataScale.sequential[4]': 'BUT-2191',
  'text.body on surface.tint.warning': 'BUT-2191',
  'text.accent.onRaised on surface.tint.warning': 'BUT-2191',
  'text.danger on surface.tint.warning': 'BUT-2191',
  'text.primary on surface.tint.accent': 'BUT-2191',
  'text.accent.onRaised on surface.tint.accent': 'BUT-2191',
  'text.success on surface.tint.success': 'BUT-2191',
  'text.danger on surface.tint.danger': 'BUT-2191',
  'text.accent on surface.raised': 'BUT-2191',
};

const _fixture = 'test/fixtures/design/contrast_pairs.json';
const _tokensSha256 =
    '444b332bda5241a5e6450d3ee6a5f7e3b76e9e8af4b06a4616ddec7478ae1f02';

final _member = RegExp(
  r'static const Color (\w+) = Color\(0x([0-9A-Fa-f]{8})\);',
);

/// token -> every member value that names it, from one generated file.
Map<String, Set<int>> _tokenValues(String path, {required bool dark}) {
  final doc = RegExp(
    r'(?:·\s*|///\s*)semantic\.([\w.]+)' + (dark ? r' \(dark\)' : r'\s*$'),
  );
  final out = <String, Set<int>>{};
  String? pending;
  for (final line in File(path).readAsLinesSync()) {
    final d = doc.firstMatch(line);
    if (d != null) {
      pending = d.group(1);
      continue;
    }
    final m = _member.firstMatch(line);
    if (m != null && pending != null) {
      out.putIfAbsent(pending, () => {}).add(int.parse(m.group(2)!, radix: 16));
    }
    if (line.trim().isNotEmpty && !line.trim().startsWith('///')) {
      pending = null;
    }
  }
  return out;
}

double _channel(int c) {
  final s = c / 255;
  return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) * 1.0;
}

double _luminance(int rgb) =>
    0.2126 * _channel((rgb >> 16) & 0xFF) +
    0.7152 * _channel((rgb >> 8) & 0xFF) +
    0.0722 * _channel(rgb & 0xFF);

/// [top] composed over an opaque [under], as the screen shows it.
int _over(int top, int under) {
  final a = (top >> 24) / 255;
  int mix(int shift) =>
      (((top >> shift) & 0xFF) * a + ((under >> shift) & 0xFF) * (1 - a))
          .round();
  return (mix(16) << 16) | (mix(8) << 8) | mix(0);
}

/// WCAG 2.x contrast ratio of [fg] on [bg]; a translucent background is
/// first laid on [page].
double contrast(int fg, int bg, int page) {
  final ground = (bg >> 24) == 0xFF ? bg & 0xFFFFFF : _over(bg, page);
  final text = _over(fg, 0xFF000000 | ground);
  final l1 = _luminance(text);
  final l2 = _luminance(ground);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  final fixture =
      jsonDecode(File(_fixture).readAsStringSync()) as Map<String, dynamic>;
  final pairs = (fixture['contrastPairs'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final modes = {
    'light': _tokenValues('lib/theme/app_colors.dart', dark: false),
    'dark': _tokenValues('lib/theme/app_colors_dark.dart', dark: true),
  };

  test('the fixture is tokens.json as vendored, 36 pairs', () {
    expect((fixture['source'] as Map)['sha256'], _tokensSha256);
    expect(pairs, hasLength(36));
    final policy = fixture['contrastPolicy'] as Map<String, dynamic>;
    expect((policy['floors'] as Map)['smallText'], 4.5);
  });

  test('the measure is WCAG 2.x: 21:1, 1:1, and the ratio tokens.json '
      'quotes for text.accent on surface.raised in dark (4.95)', () {
    expect(contrast(0xFF000000, 0xFFFFFFFF, 0xFFFFFFFF), closeTo(21, 0.01));
    expect(contrast(0xFFF5F4ED, 0xFFF5F4ED, 0xFFF5F4ED), closeTo(1, 0.001));
    expect(contrast(0xFFDCA968, 0xFF2F4437, 0xFF17251D), closeTo(4.95, 0.01));
  });

  test('a token has one value per mode', () {
    for (final entry in modes.entries) {
      for (final token in entry.value.entries) {
        expect(
          token.value,
          hasLength(1),
          reason:
              '${entry.key}: semantic.${token.key} is delivered as '
              '${token.value.map((v) => v.toRadixString(16))}',
        );
      }
    }
  });

  for (final pair in pairs) {
    final fg = pair['fg'] as String;
    final bg = pair['bg'] as String;
    final floor = (pair['floor'] as num).toDouble();
    final name = '$fg on $bg';

    test('$name reaches ${floor.toStringAsFixed(1)}:1 in both modes', () {
      final gap = knownContrastGaps[name];
      final measurable = modes.values.every(
        (tokens) => tokens.containsKey(fg) && tokens.containsKey(bg),
      );
      if (!measurable) {
        expect(
          gap,
          isNotNull,
          reason:
              '$name has no generated member in ${modes.entries.where((m) => !m.value.containsKey(fg) || !m.value.containsKey(bg)).map((m) => m.key).join(' and ')} '
              'mode, and is not listed in knownContrastGaps',
        );
        return;
      }
      expect(
        gap,
        isNull,
        reason: '$name is measurable now: remove it from knownContrastGaps',
      );
      for (final entry in modes.entries) {
        final tokens = entry.value;
        final ratio = contrast(
          tokens[fg]!.single,
          tokens[bg]!.single,
          tokens['surface.base']!.single,
        );
        expect(
          ratio,
          greaterThanOrEqualTo(floor),
          reason:
              '$name in ${entry.key} mode: ${ratio.toStringAsFixed(2)}:1, '
              'floor ${floor.toStringAsFixed(1)}:1',
        );
      }
    });
  }

  test('every listed gap is one of the declared pairs', () {
    final names = {for (final p in pairs) '${p['fg']} on ${p['bg']}'};
    for (final key in knownContrastGaps.keys) {
      expect(names, contains(key));
    }
  });
}
