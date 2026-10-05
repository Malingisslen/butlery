/// P8-U07: the token check in the build.
///
/// lib/theme/app_colors.dart and app_colors_dark.dart are generated in the
/// design repo from tokens.json (their header: "VÄRDET kommer ur
/// tokens.json"). Every colour member names its token on its doc line
/// ("· semantic.text.primary", "· palette.inkDeep", "(dark)" in the dark
/// file). This test reads both files as text and checks each member's value
/// against that token in test/fixtures/design/tokens-semantic.json, the
/// vendored copy of tokens.json with its sha256. A hand edit of a generated
/// colour, or tokens that moved on without a regeneration, turns it red.
///
/// Refresh the fixture with tools/vendor_design_tokens.dart when the design
/// tokens change. Parity against the vendored copy stands in for re-running
/// the generator, which lives in the design repo (Q8-10).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Semantic tokens that no generated member carries today, with the ticket
/// that owns the gap. Shrink-only (Q8-01 = A, Q8-03): the test fails when a
/// key gets a member but its entry is still here, and when a key without a
/// member is missing here.
const semanticKeysWithoutMember = <String, String>{};

/// The package 8 tickets this file registered in Linear: title in one line.
/// Empty: every semantic key has a member since BUT-2198 was delivered.
const tokenRegisteredTickets = <String, String>{};

const _fixture = 'test/fixtures/design/tokens-semantic.json';
const _contrastFixture = 'test/fixtures/design/contrast_pairs.json';
const _light = 'lib/theme/app_colors.dart';
const _dark = 'lib/theme/app_colors_dark.dart';

/// One generated colour member.
class Member {
  const Member(this.name, this.argb, this.ref, {required this.line});

  final String name;
  final int argb;

  /// "semantic.text.primary", "palette.inkDeep", or null when the doc line
  /// names no token.
  final String? ref;
  final int line;
}

final _member = RegExp(
  r'^\s*static const Color (\w+) = Color\(0x([0-9A-Fa-f]{8})\);',
);
final _ref = RegExp(
  r'(?:·\s*|///\s*)((?:semantic|palette)\.[\w.]+)(?: \(dark\))?\s*$',
);

/// Every `static const Color x = Color(0x...)` in [source], with the token
/// its doc comment names last.
List<Member> parseMembers(String source) {
  final out = <Member>[];
  String? pending;
  final lines = const LineSplitter().convert(source);
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();
    if (trimmed.startsWith('///')) {
      pending = _ref.firstMatch(trimmed)?.group(1);
      continue;
    }
    final m = _member.firstMatch(line);
    if (m != null) {
      out.add(
        Member(
          m.group(1)!,
          int.parse(m.group(2)!, radix: 16),
          pending,
          line: i + 1,
        ),
      );
    }
    if (trimmed.isNotEmpty) pending = null;
  }
  return out;
}

/// "#24382C" or "rgba(245,244,237,0.18)" as 0xAARRGGBB, with the alpha the
/// generator writes: round(a * 255).
int parseTokenColour(String value) {
  final v = value.trim();
  if (v.startsWith('#') && v.length == 7) {
    return 0xFF000000 | int.parse(v.substring(1), radix: 16);
  }
  final m = RegExp(
    r'^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)$',
  ).firstMatch(v);
  if (m == null) throw FormatException('not a colour token value', value);
  final a = (double.parse(m.group(4)!) * 255).round();
  return (a << 24) |
      (int.parse(m.group(1)!) << 16) |
      (int.parse(m.group(2)!) << 8) |
      int.parse(m.group(3)!);
}

/// The value [ref] has in [mode] ('light' or 'dark'), or null when the
/// fixture has no such token. Palette values have no mode.
int? tokenValue(Map<String, dynamic> fixture, String ref, String mode) {
  if (ref.startsWith('palette.')) {
    final v = (fixture['palette'] as Map<String, dynamic>)[ref.substring(8)];
    return v == null ? null : parseTokenColour(v as String);
  }
  final t =
      (fixture['semantic'] as Map<String, dynamic>)[ref.substring(9)]
          as Map<String, dynamic>?;
  return t == null ? null : parseTokenColour(t[mode] as String);
}

/// Every member whose value differs from its token, as one line each.
List<String> drift(
  Map<String, dynamic> fixture,
  List<Member> members,
  String mode,
) {
  final out = <String>[];
  for (final m in members) {
    final ref = m.ref;
    if (ref == null) continue;
    final want = tokenValue(fixture, ref, mode);
    if (want == null) {
      out.add(
        '${m.name} (line ${m.line}) names $ref, which tokens.json has not',
      );
    } else if (want != m.argb) {
      out.add(
        '${m.name} (line ${m.line}) is ${_hex(m.argb)}, '
        '$ref $mode is ${_hex(want)}',
      );
    }
  }
  return out;
}

String _hex(int argb) =>
    '0x${argb.toRadixString(16).toUpperCase().padLeft(8, '0')}';

String? _header(String source, RegExp pattern) =>
    pattern.firstMatch(source)?.group(1);

void main() {
  final fixture =
      jsonDecode(File(_fixture).readAsStringSync()) as Map<String, dynamic>;
  final lightSource = File(_light).readAsStringSync();
  final darkSource = File(_dark).readAsStringSync();
  final light = parseMembers(lightSource);
  final dark = parseMembers(darkSource);
  final semantic = fixture['semantic'] as Map<String, dynamic>;

  test('the fixture is the tokens.json the contrast pairs came from', () {
    final contrast =
        jsonDecode(File(_contrastFixture).readAsStringSync())
            as Map<String, dynamic>;
    final source = fixture['source'] as Map<String, dynamic>;
    expect(source['sha256'], (contrast['source'] as Map)['sha256']);
    expect(fixture['version'], (contrast['source'] as Map)['tokens_version']);
    expect(fixture['date'], (contrast['source'] as Map)['tokens_date']);
  });

  test('both generated files were generated from this tokens version', () {
    final version = RegExp(
      r'^// system [\d.]+ · tokens ([\d.]+)$',
      multiLine: true,
    );
    final date = RegExp(
      r'^// genererad ur källdatum (\d{4}-\d{2}-\d{2})',
      multiLine: true,
    );
    for (final source in [lightSource, darkSource]) {
      expect(_header(source, version), fixture['version']);
      expect(_header(source, date), fixture['date']);
    }
  });

  test('every generated colour names its token, brand colours excepted', () {
    // The header of app_colors.dart: the brand* colours are external brand
    // identities and are not tokenised.
    for (final entry in {_light: light, _dark: dark}.entries) {
      final unnamed = [
        for (final m in entry.value)
          if (m.ref == null && !m.name.startsWith('brand'))
            '${m.name} (line ${m.line})',
      ];
      expect(unnamed, isEmpty, reason: '${entry.key}: no token named');
      expect(entry.value.where((m) => m.ref != null), isNotEmpty);
    }
  });

  test('every light colour equals its token in tokens.json', () {
    expect(drift(fixture, light, 'light'), isEmpty);
  });

  test('every dark colour equals its token in tokens.json', () {
    expect(drift(fixture, dark, 'dark'), isEmpty);
  });

  test('a hand edit of a generated colour is caught', () {
    final edited = lightSource.replaceFirst(
      'static const Color textDark = Color(0xFF24382C);',
      'static const Color textDark = Color(0xFF000000);',
    );
    expect(edited, isNot(lightSource));
    expect(
      drift(fixture, parseMembers(edited), 'light'),
      [contains('textDark')],
    );
  });

  test(
    'a translucent colour on an opacityLadder step has that exact alpha',
    () {
      final ladder = [
        for (final steps in (fixture['opacityLadder'] as Map).values)
          for (final s in steps as List) (s as num).toDouble(),
      ];
      expect(ladder, isNotEmpty);
      for (final entry in {'light': light, 'dark': dark}.entries) {
        for (final m in entry.value) {
          if (m.ref == null || !m.ref!.startsWith('semantic.')) continue;
          final raw =
              (semantic[m.ref!.substring(9)] as Map<String, dynamic>)[entry.key]
                  as String;
          final a = RegExp(r',\s*([\d.]+)\s*\)$').firstMatch(raw)?.group(1);
          if (a == null || !ladder.contains(double.parse(a))) continue;
          expect(
            m.argb >> 24,
            (double.parse(a) * 255).round(),
            reason: '${m.name} ${entry.key}: ${m.ref} is on the ladder at $a',
          );
        }
      }
    },
  );

  test('semantic tokens without a generated member are exactly the listed '
      'gaps, each with a ticket', () {
    final carried = {
      for (final m in [...light, ...dark])
        if (m.ref != null && m.ref!.startsWith('semantic.'))
          m.ref!.substring(9),
    };
    final missing = semantic.keys.where((k) => !carried.contains(k)).toSet();
    expect(
      missing.difference(semanticKeysWithoutMember.keys.toSet()),
      isEmpty,
      reason: 'a semantic token has no member and no entry here',
    );
    expect(
      semanticKeysWithoutMember.keys.toSet().difference(missing),
      isEmpty,
      reason: 'these keys have a member now: remove their entries',
    );
    for (final ticket in semanticKeysWithoutMember.values) {
      expect(ticket, matches(RegExp(r'^BUT-\d+$')));
    }
  });

  group('the parser', () {
    test('reads rgba with the generator alpha', () {
      expect(parseTokenColour('rgba(245,244,237,0.18)'), 0x2EF5F4ED);
      expect(parseTokenColour('rgba(23,37,29,0.10)'), 0x1A17251D);
      expect(parseTokenColour('#24382C'), 0xFF24382C);
    });

    test('takes the token at the end of the doc line, not one quoted in it', () {
      final members = parseMembers(
        '  /// Lag tidigare pa palette.saffronLink (#A15A0A) · semantic.text.link\n'
        '  static const Color info = Color(0xFF8A5212);\n',
      );
      expect(members.single.ref, 'semantic.text.link');
    });
  });
}
