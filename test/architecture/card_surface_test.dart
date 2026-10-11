// The one card (BUT-2370): a card's edge, corner and lack of shadow come from
// the theme, so none of these may creep back into lib/.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

String _rel(File f) => f.path.replaceAll(r'\', '/');

String _call(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    if ('([{'.contains(code[i])) depth++;
    if (')]}'.contains(code[i])) depth--;
    if (depth == 0) return code.substring(open, i + 1);
  }
  return code.substring(open);
}

void main() {
  test('no Card squares its corners with an empty RoundedRectangleBorder', () {
    final card = RegExp(r'(?<![\w.])Card\(');
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      final code = file.readAsStringSync();
      for (final m in card.allMatches(code)) {
        final args = _call(code, m.end - 1);
        if (args.contains('RoundedRectangleBorder()')) {
          offenders.add(_rel(file));
        }
      }
    }
    expect(offenders, isEmpty, reason: 'drop the shape: the theme rounds it');
  });

  test('content cards draw no shadow of their own', () {
    final offenders = <String>[];
    for (final file in _dartFiles('lib/widgets/common/content_cards')) {
      if (_rel(file).endsWith('/image_preview_card.dart')) continue;
      final code = file.readAsStringSync();
      if (code.contains('boxShadow') || code.contains('AppShadows')) {
        offenders.add(_rel(file));
      }
    }
    expect(offenders, isEmpty, reason: 'use StyledCard.decorationOf');
  });

  test('StyledCard has a single constructor', () {
    final named = RegExp(r'(?<![\w.])StyledCard\.([a-z]\w*)\(');
    const helpers = {
      'decorationOf',
      'hoverDecorationOf',
      'inkOverlayOf',
      'pressFillOf',
    };
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      for (final m in named.allMatches(file.readAsStringSync())) {
        if (!helpers.contains(m.group(1))) {
          offenders.add('${_rel(file)}: StyledCard.${m.group(1)}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
