// Guards for design decisions that had no test naming them (design/beslutslogg.md):
// B-120 opacity ladder, B-121 and B-125 dark text on raised surfaces, B-161
// legal text language, B-162 save in the footer of "Skriv nytt recept", B-167
// no confirm dialog on deleting an own comment. See decision_guards_b62_b65.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

String _source(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is gone; update the guard');
  return file
      .readAsStringSync()
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//[^\n]*'), '');
}

Map<String, dynamic> _tokens() =>
    jsonDecode(File('design/tokens.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> _semantic(String name) =>
    (_tokens()['semantic'] as Map<String, dynamic>)[name]
        as Map<String, dynamic>;

double _luminance(String hex) {
  final v = int.parse(hex.substring(1), radix: 16);
  double channel(int c) {
    final s = c / 255;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel((v >> 16) & 0xFF) +
      0.7152 * channel((v >> 8) & 0xFF) +
      0.0722 * channel(v & 0xFF);
}

double _contrast(String fg, String bg) {
  final a = _luminance(fg);
  final b = _luminance(bg);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  group(
    'B-120 every transparency in tokens.json is a step in opacityLadder',
    () {
      test('overlay, scrim and shadow alphas sit on the ladder', () {
        final ladder = _tokens()['opacityLadder'] as Map<String, dynamic>;
        final steps = <double>{
          for (final key in ['onPaper', 'onInk'])
            for (final v in ladder[key] as List<dynamic>) (v as num).toDouble(),
        };
        final semantic = _tokens()['semantic'] as Map<String, dynamic>;
        final checked = <String>[];
        semantic.forEach((name, value) {
          final isLayer =
              name.startsWith('overlay.') ||
              name == 'scrim' ||
              name == 'elevation.shadow';
          if (!isLayer) return;
          for (final mode in ['light', 'dark']) {
            final raw = (value as Map<String, dynamic>)[mode] as String;
            final alpha = double.parse(
              RegExp(r'rgba\([^)]*,\s*([0-9.]+)\)').firstMatch(raw)!.group(1)!,
            );
            checked.add('$name.$mode');
            expect(
              steps,
              contains(alpha),
              reason:
                  'B-120: $name ($mode) uses alpha $alpha outside the ladder',
            );
          }
        });
        expect(checked.length, 16, reason: 'the guard lost a layer token');
      });
    },
  );

  group('B-121 and B-125 dark text on raised and tinted surfaces', () {
    test('text.danger.onRaised carries the danger tint in dark mode', () {
      final danger = _semantic('text.danger.onRaised');
      final tint = _semantic('surface.tint.danger');
      expect(danger['dark'], '#E5A08A');
      expect(danger['light'], '#9C3B23');
      expect(
        _contrast(danger['dark'] as String, tint['dark'] as String),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(
          _semantic('text.danger')['dark'] as String,
          tint['dark'] as String,
        ),
        lessThan(4.5),
        reason: 'B-121 exists because plain text.danger fails here',
      );
    });

    test('text.secondary is identical to text.secondary.onRaised', () {
      final plain = _semantic('text.secondary');
      final raised = _semantic('text.secondary.onRaised');
      for (final mode in ['light', 'dark']) {
        expect(plain[mode], raised[mode], reason: 'B-125 ($mode)');
      }
      expect(plain['light'], '#5B6959');
      expect(plain['dark'], '#A9B2A0');
    });

    test('text.secondary clears 4.5:1 on surface.raised in both modes', () {
      final raised = _semantic('surface.raised');
      final plain = _semantic('text.secondary');
      for (final mode in ['light', 'dark']) {
        expect(
          _contrast(plain[mode] as String, raised[mode] as String),
          greaterThanOrEqualTo(4.5),
          reason: 'B-125 ($mode)',
        );
      }
    });
  });

  group('B-161 legal documents follow the app language', () {
    test('every legal view reads the app locale, never the device locale', () {
      final dir = Directory('lib/views/legal');
      final views = dir
          .listSync()
          .whereType<File>()
          .map((f) => f.path.replaceAll('\\', '/'))
          .where((p) => p.endsWith('_view.dart'))
          .toList();
      expect(views, isNotEmpty);
      for (final path in views) {
        final src = _source(path);
        expect(
          src,
          contains('Localizations.localeOf(context)'),
          reason: 'B-161: $path no longer follows the app language',
        );
        expect(
          src,
          isNot(
            anyOf(
              contains('PlatformDispatcher'),
              contains('Platform.localeName'),
            ),
          ),
          reason: 'B-161: $path reads the phone language',
        );
      }
    });
  });

  group('B-162 Skriv nytt recept saves from the footer', () {
    test('the top bar actions hold only the draft indicator', () {
      final src = _source('lib/views/skriv_sjalv_recept_view.dart');
      final start = src.indexOf('showTabBar: false');
      final end = src.indexOf('body:', start);
      expect(start, greaterThan(-1));
      final bar = src.substring(start, end);
      expect(bar, contains('DraftSaveIndicator'));
      expect(bar, isNot(contains('Icons.check')));
      expect(bar, isNot(contains('IconButton')));
      expect(bar, isNot(contains('commonSave')));
    });
  });

  group('B-167 deleting an own comment has no confirm dialog', () {
    test('the delete runs through the undo snackbar only', () {
      final src = _source(
        'lib/views/recipe_detail/recipe_detail_comments.dart',
      );
      final start = src.indexOf('void _deleteComment');
      final end = src.indexOf('Future<void> _editComment', start);
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final body = src.substring(start, end);
      expect(body, contains('SnackBarUtils.showUndoDeferred'));
      expect(body, isNot(contains('showDialog')));
      expect(body, isNot(contains('showButleryDialog')));
      expect(body, isNot(contains('ConfirmationDialog')));
    });
  });
}
