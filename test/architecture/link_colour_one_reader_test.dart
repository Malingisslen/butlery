// A link reads ModeColors.textLink (semantic text.link).
// ModeColors.info and ColorScheme.onSecondaryContainer carry the same two
// values today, but each is a different token, so a link that reads one of
// them changes colour when that token moves for its own reasons.
//
// ModeColors.info stays. So the guard is not "info is gone"; it
// is "a file that draws a link never reads info or onSecondaryContainer".
// Link files are the ones named below plus every file that uses the generated
// linkSmall style, which bakes the light value only and must be overridden.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String path) => _strip(File(path).readAsStringSync());

/// Drops comments; a `//` after a colon is a URL inside a string, not one.
String _strip(String source) => source
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'(?<!:)//[^\n]*'), '');

/// The argument list of the call whose `(` is at [open], without nested
/// calls' arguments.
String _ownArguments(String code, int open) {
  final own = StringBuffer();
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (depth == 1 && c != '(') own.write(c);
    if (depth == 0) break;
  }
  return own.toString();
}

/// Files that draw a link without using linkSmall.
const _namedLinkFiles = [
  'lib/views/hem/hem_empty_state.dart',
  'lib/views/hem/hem_plan_states.dart',
  'lib/views/legal/markdown_body.dart',
  'lib/views/receive_share_view.dart',
  'lib/widgets/common/feedback/inline_error.dart',
  'lib/widgets/common/linkified_text.dart',
  'lib/widgets/menu/parsed_extraction_chips.dart',
  'lib/widgets/menu/shopping_merge_sheet_parts.dart',
  'lib/widgets/social/report_content_dialog.dart',
];

final _infoReader = RegExp(
  r'(modeColors|ModeColors\.of\((?:[^()]|\([^()]*\))*\)|'
  r'ModeColors\.(light|dark)|AppColors(Dark)?)\.info\b',
);

/// A local holding the mode colours, e.g. `final colors = context.modeColors;`.
final _modeColorsAlias = RegExp(
  r'\b(?:final|var)\s+(\w+)\s*=\s*'
  r'(?:context\.modeColors|ModeColors\.(?:of\(|light\b|dark\b))',
);
final _secondaryContainerReader = RegExp(
  r'\b(cs|colorScheme|scheme)\.onSecondaryContainer\b',
);

/// Reads of the two look-alike tokens in a file that draws a link.
List<String> lookAlikeReads(String path, String code) => [
  for (final m in _infoReader.allMatches(code)) '$path ${m.group(0)}',
  for (final a in _modeColorsAlias.allMatches(code))
    for (final m in RegExp(
      r'(?<![.\w])' + a.group(1)! + r'\.info\b',
    ).allMatches(code))
      '$path ${m.group(0)}',
  for (final m in _secondaryContainerReader.allMatches(code))
    '$path ${m.group(0)}',
];

/// A `linkSmall` use whose own `color:` is not textLink, including a bare
/// `linkSmall` that keeps the baked light-only colour.
List<String> linkSmallWithoutTextLink(String path, String code) {
  final found = <String>[];
  for (final m in RegExp(r'\blinkSmall\b').allMatches(code)) {
    final after = code.substring(m.end);
    final call = RegExp(r'^\s*\.copyWith\(').firstMatch(after);
    if (call == null) {
      found.add('$path linkSmall without copyWith');
      continue;
    }
    final own = _ownArguments(code, m.end + call.end - 1);
    if (!RegExp(r'\bcolor:[^,]*\btextLink\b').hasMatch(own)) {
      found.add('$path linkSmall.copyWith colour is not textLink');
    }
  }
  return found;
}

/// A button's `foregroundColor:` naming one of the look-alike tokens.
List<String> lookAlikeButtonForeground(String path, String code) {
  final found = <String>[];
  for (final m in RegExp(r'\.styleFrom\(').allMatches(code)) {
    final own = _ownArguments(code, m.end - 1);
    final hit = RegExp(
      r'\bforegroundColor:[^,]*(\.info\b|\bonSecondaryContainer\b)',
    ).firstMatch(own);
    if (hit != null) found.add('$path ${hit.group(0)}');
  }
  return found;
}

void main() {
  final libFiles = [
    for (final f in Directory('lib').listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart')) f.path.replaceAll('\\', '/'),
  ].where((p) => !p.contains('lib/theme/app_colors')).toList();

  test('a link file reads textLink and never info or onSecondaryContainer', () {
    final found = <String>[];
    var linkFiles = 0;
    for (final path in libFiles) {
      if (path == 'lib/theme/app_text_styles.dart') continue;
      final code = _code(path);
      final isLinkFile =
          _namedLinkFiles.contains(path) ||
          RegExp(r'\blinkSmall\b').hasMatch(code);
      if (!isLinkFile) continue;
      linkFiles++;
      found.addAll(lookAlikeReads(path, code));
      if (!code.contains('textLink')) found.add('$path never reads textLink');
    }
    expect(linkFiles, greaterThanOrEqualTo(_namedLinkFiles.length));
    expect(
      found,
      isEmpty,
      reason: 'a link takes modeColors.textLink (or ModeColors.of(b).textLink)',
    );
  });

  test('every named link file exists', () {
    for (final path in _namedLinkFiles) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('linkSmall always overrides its baked light-only colour', () {
    final found = <String>[];
    for (final path in libFiles) {
      if (path == 'lib/theme/app_text_styles.dart') continue;
      found.addAll(linkSmallWithoutTextLink(path, _code(path)));
    }
    expect(found, isEmpty);
  });

  test('no button foreground takes info or onSecondaryContainer', () {
    final found = <String>[];
    for (final path in libFiles) {
      found.addAll(lookAlikeButtonForeground(path, _code(path)));
    }
    expect(found, isEmpty);
  });

  test('the scans find each shape they guard', () {
    const reads = [
      'final a = context.modeColors.info;',
      'final b = ModeColors.of(theme.brightness).info;',
      'final c = ModeColors.dark.info;',
      'final d = Theme.of(context).colorScheme.onSecondaryContainer;',
      'final e = cs.onSecondaryContainer;',
      'final f = ModeColors.of(Theme.of(context).brightness).info;',
      'final g = AppColorsDark.info;',
      'final c = context.modeColors;\nfinal h = c.info;',
      "final u = 'https://x'; final i = context.modeColors.info;",
    ];
    for (final shape in reads) {
      expect(lookAlikeReads('x', _strip(shape)), hasLength(1), reason: shape);
    }
    const notReads = [
      'final f = context.modeColors.infoContainer;',
      'final g = context.modeColors.onInfo;',
      'final h = context.modeColors.textLink;',
      'final i = ButleryIcons.info;',
    ];
    for (final shape in notReads) {
      expect(lookAlikeReads('x', shape), isEmpty, reason: shape);
    }

    expect(
      linkSmallWithoutTextLink('x', 'final a = AppTextStyles.linkSmall;'),
      hasLength(1),
    );
    expect(
      linkSmallWithoutTextLink(
        'x',
        'final b = AppTextStyles.linkSmall.copyWith(color: c.info);',
      ),
      hasLength(1),
    );
    expect(
      linkSmallWithoutTextLink(
        'x',
        'final c = AppTextStyles.linkSmall.copyWith(\n'
            '  color: context.modeColors.textLink,\n);',
      ),
      isEmpty,
    );

    for (final shape in [
      'final a = TextButton.styleFrom(foregroundColor: context.modeColors.info);',
      'final b = TextButton.styleFrom(foregroundColor: cs.onSecondaryContainer);',
    ]) {
      expect(
        lookAlikeButtonForeground('x', shape),
        hasLength(1),
        reason: shape,
      );
    }
    expect(
      lookAlikeButtonForeground(
        'x',
        'final c = TextButton.styleFrom(foregroundColor: modeColors.textLink);',
      ),
      isEmpty,
    );
  });
}
