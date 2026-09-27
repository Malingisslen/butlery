// Package 7, track D: the old typography and the off-scale spacing stay out.
//
// - Type: every text size comes from a type role (tokens.json
//   typography.roles; tokens.json:522 "Ingen handskriven ... i app- eller
//   speckod"). A raw `fontSize: <number>` outside lib/theme is refused. The
//   allowlist below holds the two sizes no role covers yet and may only
//   shrink.
// - Space: the spacing scale is 4/8/12/16/24/32 and the layout margin is 20
//   at 320 dp and 24 from 360 dp (tokens.json:463-475). The off-scale
//   AppDimensions constants retired in package 7 may not come back.
// - Control geometry: a badge is 2 × 7 and a status pill 3 × 9 (tokens.json
//   controls.badge / controls.statusPill; Komponentark v1:34).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_roles_pending.dart';

/// Files that may still carry a raw font size, and how many. Each entry is a
/// known gap with a Linear follow-up; the count may only go down.
const _rawFontSizeAllowlist = <String, int>{
  // The wordmark drawn as text. Grafisk manual v6:86: the wordmark is a
  // locked vector and is never recreated as text; no vector asset ships yet.
  'lib/views/auth_view.dart': 1,
  // The cooking timer's 56 px digits. No type role is larger than stat 38,
  // which is reserved for the statistics view (tokens.json typography.roles).
  'lib/widgets/cooking/step_timer_widget.dart': 1,
};

/// The AppDimensions members retired in package 7 (P7-U09).
const _retiredSpacing = <String>[
  'spacingXxs', // 2
  'spacingS', // 3
  'spacingTight', // 6
  'spacing6', // 6
  'paddingXxs', // 2
  'paddingMs', // 10
  'spacingModerate', // 14
  'paddingXl', // 20, outside the layout margin
  'spacingHuge', // 80
  'paddingAll2',
  'paddingAll3',
  'paddingSymmetric20x12',
  'paddingSymmetric12x6',
  'paddingSymmetric4x3',
  'paddingSymmetric4x2',
  'paddingSymmetric6x2',
  'paddingSymmetric8x2',
  'paddingSymmetric20x16',
  'paddingOnlyBottom3',
];

final _rawFontSize = RegExp(r'fontSize:\s*[0-9]');

Iterable<File> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

String _rel(File f) => f.path.replaceAll(r'\', '/');

/// The file's code lines, with whole-line comments left out.
Iterable<String> _codeLines(File f) =>
    f.readAsLinesSync().where((l) => !l.trimLeft().startsWith('//'));

void main() {
  group('type roles, not raw sizes', () {
    test('no raw fontSize outside lib/theme beyond the allowlist', () {
      final found = <String, int>{};
      for (final file in _dartFiles('lib')) {
        final path = _rel(file);
        if (path.startsWith('lib/theme/')) continue;
        final n = _codeLines(file).where(_rawFontSize.hasMatch).length;
        if (n > 0) found[path] = n;
      }
      final offenders = {
        for (final e in found.entries)
          if (e.value > (_rawFontSizeAllowlist[e.key] ?? 0)) e.key: e.value,
      };
      expect(
        offenders,
        isEmpty,
        reason:
            'Use an AppTextStyles role (tokens.json typography.roles). A '
            'size with no role is a D1 question for the design system, not '
            'a literal.',
      );
    });

    test('the allowlist only shrinks: every entry is still needed', () {
      for (final e in _rawFontSizeAllowlist.entries) {
        final n = _codeLines(File(e.key)).where(_rawFontSize.hasMatch).length;
        expect(
          n,
          e.value,
          reason:
              '${e.key} now has $n raw font sizes; lower or remove its '
              'allowlist entry.',
        );
      }
    });

    test('the retired font aliases and families are gone', () {
      final alias = RegExp(
        r'AppTextStyles\.(headerFont|bodyFont|mainViewTitle)\b',
      );
      final family = RegExp(
        'JosefinSans|SpaceGrotesk|Josefin Sans|Space Grotesk',
      );
      final hits = <String>[];
      for (final file in _dartFiles('lib')) {
        final path = _rel(file);
        if (path == 'lib/theme/app_text_styles.dart') continue;
        for (final line in _codeLines(file)) {
          if (alias.hasMatch(line) || family.hasMatch(line)) {
            hits.add('$path: ${line.trim()}');
          }
        }
      }
      expect(hits, isEmpty);
      expect(family.hasMatch(File('pubspec.yaml').readAsStringSync()), isFalse);
    });

    test('calendarCell matches its token: 11/600 at 1.45', () {
      final style = AppTextRolesPending.calendarCell;
      expect(style.fontSize, 11);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.height, 1.45);
    });
  });

  group('the spacing scale', () {
    test('no retired spacing constant is used or declared', () {
      final use = RegExp(
        'AppDimensions\\.(${_retiredSpacing.join('|')})\\b',
      );
      final hits = <String>[];
      for (final root in ['lib', 'test']) {
        for (final file in _dartFiles(root)) {
          for (final line in _codeLines(file)) {
            if (use.hasMatch(line)) hits.add('${_rel(file)}: ${line.trim()}');
          }
        }
      }
      expect(hits, isEmpty, reason: 'Use the scale: space4 … space32.');

      final dims = File('lib/theme/app_dimensions.dart').readAsStringSync();
      for (final name in _retiredSpacing) {
        expect(
          RegExp('static const \\w+ $name\\b').hasMatch(dims),
          isFalse,
          reason: 'AppDimensions.$name is retired (P7-U09).',
        );
      }
    });

    test('the scale is the token scale', () {
      expect(
        [
          AppDimensions.space4,
          AppDimensions.space8,
          AppDimensions.space12,
          AppDimensions.space16,
          AppDimensions.space24,
          AppDimensions.space32,
        ],
        [4, 8, 12, 16, 24, 32],
      );
      expect(AppDimensions.paddingAll4, const EdgeInsets.all(4));
    });

    test('badge and status pill keep their locked geometry', () {
      expect(
        AppDimensions.badgePadding,
        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      );
      expect(
        AppDimensions.statusPillPadding,
        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      );
    });

    for (final (width, margin) in [
      (320.0, 20.0),
      (359.0, 20.0),
      (360.0, 24.0),
      (430.0, 24.0),
    ]) {
      testWidgets('the layout margin is $margin at $width dp', (tester) async {
        late double got;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: Size(width, 800)),
            child: Builder(
              builder: (context) {
                got = AppDimensions.layoutMarginOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(got, margin);
      });
    }
  });
}
