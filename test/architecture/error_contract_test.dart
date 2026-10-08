// P5-U00: the error contract (content-style-guide.md:87-97).
//
// A failure says what happened, what was kept when something was at stake,
// and what you can do, as a button that is never "OK"
// (content-style-guide.md:96; Komponentark v1:750). Code shows it with
// SnackBarUtils.showFailure or the InlineError widget; both always carry
// that structure.
//
// The legacy one-line error channels (SnackBarUtils.showError,
// UtilityComponents.showErrorSnackbar, SnackbarWidgets.showErrorSnackbar and
// the context.showError extension) were frozen per file from package 5 and
// removed in package 7 (P7-Z). The ratchet is now a ban: no call may come
// back.
//
// Q-E7 (nattplan, package 5): an errorPrefix is shown to the user as the
// whole message (base_viewmodel.dart:183-198), so a hard-coded string there
// is untranslated user text. The last ones moved to l10n in package 7; the
// ratchet is now a ban.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The one private inline-error copy left: the week menu's full-section
/// generation error, which is a state view with two actions, not a line.
/// ping_compose_sheet.dart's copy became InlineError.
const _privateInlineErrors = {'lib/widgets/menu/menu_content_widgets.dart'};

final _legacy = RegExp(
  r'(?:\bSnackBarUtils\s*\.\s*showError\s*\('
  r'|\bUtilityComponents\s*\.\s*showErrorSnackbar(?:WithRetry)?\s*\('
  r'|\bSnackbarWidgets\s*\.\s*showErrorSnackbar(?:WithRetry)?\s*\('
  r'|\bcontext\s*\.\s*showError\s*\()',
);

final _prefix = RegExp(r'''errorPrefix\s*:\s*['"]''');

final _okAction = RegExp(
  r'''(?:actionLabel\s*:\s*[\w.]*\bcommonOk\b|actionLabel\s*:\s*['"]OK['"]'''
  r'''|FailureAction\s*\.\s*named\s*\(\s*(?:[\w.]*\bcommonOk\b|['"]OK['"]))''',
);

final _inlineErrorCopy = RegExp(
  r'(?:class\s+_\w*InlineError\b|\b_build\w*InlineError\s*\()',
);

Iterable<String> _libFiles() sync* {
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (path.startsWith('lib/l10n/')) continue;
    yield path;
  }
}

/// The source without whole-line comments, so a doc comment that names a
/// call is not counted as one.
String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

Map<String, int> _count(RegExp pattern) {
  final out = <String, int>{};
  for (final path in _libFiles()) {
    final n = pattern.allMatches(_code(path)).length;
    if (n > 0) out[path] = n;
  }
  return out;
}

void main() {
  test('no call into the retired one-line error channels', () {
    expect(
      _count(_legacy),
      isEmpty,
      reason:
          'Show a failure with SnackBarUtils.showFailure(what:, preserved:, '
          'action:) or InlineError (content-style-guide.md:87-97).',
    );
  });

  test('no hard-coded errorPrefix (Q-E7)', () {
    expect(
      _count(_prefix),
      isEmpty,
      reason: 'An errorPrefix is user text: pass AppLocale.current.<key>.',
    );
  });

  test('no snackbar action is named OK', () {
    final offenders = <String>[];
    for (final path in _libFiles()) {
      if (_okAction.hasMatch(_code(path))) offenders.add(path);
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'content-style-guide.md:96: a snackbar never has OK as its '
          'action; name what it does, or Stäng.',
    );
  });

  test('inline errors come from InlineError, not a private copy', () {
    final found = _count(_inlineErrorCopy).keys.toSet();
    expect(found.difference(_privateInlineErrors), isEmpty);
    expect(
      _privateInlineErrors.difference(found),
      isEmpty,
      reason: 'remove the entry that no longer has a private copy',
    );
  });
}
