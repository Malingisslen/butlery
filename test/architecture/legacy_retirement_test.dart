// P7-Z: the legacy surface package 7 retired may not come back.
//
// The migration plan (2026-09-20) says "Ingen permanent samexistens": once a
// component has moved to the design system, the old one is deleted, not
// kept beside it. Package 7 deleted the old bars (B-45, beslutslogg.md:52),
// the spinners and the pea pod (B-18, beslutslogg.md:25; produktregler.md:163),
// the coloured snackbars and their one-line error channel
// (Komponentark v1:745-750; content-style-guide.md:87-97), "OK" as a label
// (content-style-guide.md:77, :96), the Cupertino dialogs (B-45) and the
// ButleryColors compatibility extension with its seasonal tint
// (tokens.json:522; NULAGE.md:71-74; Q7-01 = A).
//
// Every name below is matched on code only, so a comment that tells the
// history is allowed. The patterns are word-bounded: showLoadingIndicator,
// a live field name, is not LoadingIndicator, and the design-system
// generator's own ButleryColors class is allowed in its generated file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Each retired name, with what replaced it.
final _retired = <String, RegExp>{
  'AdaptiveAppBar → ButleryTopBar (B-45)': RegExp(r'\bAdaptiveAppBar\b'),
  'MainViewHeader → ButleryTopBar (B-45)': RegExp(r'\bMainViewHeader\b'),
  'ButleryHeader → ButleryTopBar (B-45)': RegExp(r'\bButleryHeader\b'),
  'LoadingIndicator → PlateLine / StateWidget.loading (B-18)': RegExp(
    r'\bLoadingIndicator\b',
  ),
  'PeaLoading* → PlateLine (produktregler.md:163)': RegExp(r'\bPeaLoading\w*'),
  'AdaptiveActivityIndicator → PlateLine (B-18)': RegExp(
    r'\bAdaptiveActivityIndicator\b',
  ),
  'AdaptiveButton (one control on both platforms, B-45)': RegExp(
    r'\bAdaptiveButton\b',
  ),
  'AdaptiveSwitch (one control on both platforms, B-45)': RegExp(
    r'\bAdaptiveSwitch\b',
  ),
  'AdaptiveTextField (one control on both platforms, B-45)': RegExp(
    r'\bAdaptiveTextField\b',
  ),
  'SyncIndicator (retired, package-3 A-03/A-09)': RegExp(
    r'\bSyncIndicator\b',
  ),
  'SnackbarWidgets → SnackBarUtils (Komponentark v1:745-750)': RegExp(
    r'\bSnackbarWidgets\b',
  ),
  'SnackBarUtils.showCustom → SnackBarUtils.showSuccess/showFailure': RegExp(
    r'\bSnackBarUtils\s*\.\s*showCustom\b',
  ),
  'SnackBarUtils.showError → SnackBarUtils.showFailure': RegExp(
    r'\bSnackBarUtils\s*\.\s*showError\s*\(',
  ),
  'SeasonalAccent* (tokens.json:522, Q7-01 = A)': RegExp(r'SeasonalAccent'),
  'JosefinSans → the token typefaces': RegExp(r'JosefinSans'),
  'SpaceGrotesk → the token typefaces': RegExp(r'SpaceGrotesk'),
  'searchBoxDecorationFocused → ButlerySearchBox': RegExp(
    r'searchBoxDecorationFocused',
  ),
  'commonOk → Stäng or a verb (content-style-guide.md:77)': RegExp(
    r'\bcommonOk\b',
  ),
  'CupertinoAlertDialog → the shared dialogs (B-45)': RegExp(
    r'\bCupertinoAlertDialog\b',
  ),
  'showCupertinoDialog → showDialog (B-45)': RegExp(r'\bshowCupertinoDialog\b'),
  'context.butleryColors → context.modeColors': RegExp(
    r'\bcontext\s*\.\s*butleryColors\b',
  ),
  'butlery_colors_extension.dart → app_mode_colors.dart': RegExp(
    r'butlery_colors_extension',
  ),
};

/// The compatibility class ButleryColors; the design-system generator emits
/// a class of the same name, which may live in its generated file only.
final _butleryColors = RegExp(r'\bButleryColors\b');
const _generatedTokens = 'lib/theme/butlery_tokens.dart';

/// Code without comments, so history in a comment is not a use.
String _code(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//.*'), '');

/// Every Dart file under lib, generated localisations excepted.
List<String> _libFiles() => [
  for (final e in Directory('lib').listSync(recursive: true))
    if (e is File && e.path.endsWith('.dart')) e.path.replaceAll(r'\', '/'),
].where((p) => !p.startsWith('lib/l10n/')).toList();

/// The retired names [source] at [path] uses.
List<String> _hits(String path, String source) {
  final code = _code(source);
  return [
    for (final entry in _retired.entries)
      if (entry.value.hasMatch(code)) entry.key,
    if (path != _generatedTokens && _butleryColors.hasMatch(code))
      'ButleryColors → ModeColors (tokens.json:522)',
  ];
}

void main() {
  test('no retired legacy name is used in lib (P7-Z)', () {
    final offenders = <String>[
      for (final path in _libFiles())
        for (final hit in _hits(path, File(path).readAsStringSync()))
          '$path: $hit',
    ];
    expect(
      offenders,
      isEmpty,
      reason:
          'Package 7 retired these. Use what the entry names instead; '
          'the migration plan allows no coexistence.',
    );
  });

  group('the matcher', () {
    test('catches a retired widget', () {
      expect(
        _hits('lib/x.dart', 'final w = AdaptiveAppBar(title: t);'),
        isNotEmpty,
      );
      expect(_hits('lib/x.dart', 'const LoadingIndicator.small()'), isNotEmpty);
      expect(_hits('lib/x.dart', 'SnackBarUtils.showError(c, m);'), isNotEmpty);
      expect(
        _hits('lib/x.dart', 'final c = context.butleryColors;'),
        isNotEmpty,
      );
      expect(_hits('lib/x.dart', 'ButleryColors.light'), isNotEmpty);
    });

    test('leaves live names that only contain a retired one', () {
      expect(_hits('lib/x.dart', 'final bool showLoadingIndicator;'), isEmpty);
      expect(
        _hits('lib/x.dart', 'SnackBarUtils.showErrorWithRetry(c, m);'),
        isEmpty,
      );
      expect(_hits('lib/x.dart', 'context.l10n.commonClose'), isEmpty);
    });

    test('allows ButleryColors in the generated token file only', () {
      expect(_hits(_generatedTokens, 'class ButleryColors {}'), isEmpty);
      expect(_hits('lib/theme/other.dart', 'class ButleryColors {}'), [
        'ButleryColors → ModeColors (tokens.json:522)',
      ]);
    });

    test('ignores a retired name in a comment', () {
      expect(_hits('lib/x.dart', '// the retired AdaptiveAppBar'), isEmpty);
      expect(_hits('lib/x.dart', '/* LoadingIndicator */'), isEmpty);
    });
  });
}
