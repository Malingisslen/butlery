/// P8-U02: every declared contrast pair, measured on the colours the app
/// was generated with, in light and in dark.
///
/// Source: tokens.json contrastPairs (35 pairs) and contrastPolicy, vendored
/// in test/fixtures/design/contrast_pairs.json with the file's sha256. Each
/// token is resolved to the generated member whose doc line names it
/// ("· semantic.text.primary", "(dark)" in app_colors_dark.dart), so the
/// measure follows the generated files and never a copy of their values.
///
/// A pair with no generated member cannot be measured in the app. It must be
/// listed in [knownContrastGaps] with its ticket, and the test fails when the
/// member arrives but the entry is still there (decision Q8-01 = A). A
/// measured pair under its floor must be listed in [knownContrastFailures]
/// with its ticket.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

/// Pairs that cannot be measured today, by "fg on bg", with their ticket.
/// The dataScale tokens live outside tokens.json semantic, and the generator
/// has no kind for them yet.
const knownContrastGaps = <String, String>{
  'dataScale.onFill.step1 on dataScale.sequential[0]': 'BUT-2191',
  'dataScale.onFill.step2 on dataScale.sequential[1]': 'BUT-2191',
  'dataScale.onFill.step3 on dataScale.sequential[2]': 'BUT-2191',
  'dataScale.onFill.step4 on dataScale.sequential[3]': 'BUT-2191',
  'dataScale.onFill.step5 on dataScale.sequential[4]': 'BUT-2191',
};

/// Pairs that are measured and fall under their floor in at least one mode,
/// by "fg on bg", with their ticket. Shrink-only: the test fails when such a
/// pair reaches its floor in both modes and its entry is still here. Fixing
/// one is a design decision in tokens.json, never an edit here.
const knownContrastFailures = <String, String>{};

const _fixture = 'test/fixtures/design/contrast_pairs.json';
const _tokensSha256 =
    '44c86b645d23225f3e528120f278cd7e58b65b9803cfc6f558ca785998ff5688';

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

  test('the fixture is tokens.json as vendored, 35 pairs', () {
    expect((fixture['source'] as Map)['sha256'], _tokensSha256);
    expect(pairs, hasLength(35));
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
      final ratios = {
        for (final entry in modes.entries)
          entry.key: contrast(
            entry.value[fg]!.single,
            entry.value[bg]!.single,
            entry.value['surface.base']!.single,
          ),
      };
      if (knownContrastFailures.containsKey(name)) {
        expect(
          ratios.values.any((r) => r < floor),
          isTrue,
          reason:
              '$name reaches ${floor.toStringAsFixed(1)}:1 in both modes '
              'now: remove it from knownContrastFailures',
        );
        return;
      }
      for (final entry in ratios.entries) {
        expect(
          entry.value,
          greaterThanOrEqualTo(floor),
          reason:
              '$name in ${entry.key} mode: ${entry.value.toStringAsFixed(2)}:1, '
              'floor ${floor.toStringAsFixed(1)}:1',
        );
      }
    });
  }

  test('every listed gap and failure is one of the declared pairs', () {
    final names = {for (final p in pairs) '${p['fg']} on ${p['bg']}'};
    for (final key in [
      ...knownContrastGaps.keys,
      ...knownContrastFailures.keys,
    ]) {
      expect(names, contains(key));
    }
    for (final ticket in knownContrastFailures.values) {
      expect(ticket, matches(RegExp(r'^BUT-\d+$')));
    }
  });
}
