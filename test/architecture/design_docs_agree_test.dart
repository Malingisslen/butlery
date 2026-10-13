// The design documents must say what the tokens and the decision log say.
// They are read as text, so a document edited back to an old number, or a
// product decision file without a log row, fails here instead of in review.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) fail('$path is gone; update the guard');
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

void main() {
  group('checkbox size', () {
    // "Kryssruta 20 px", "kryssruta <b>20 px</b>", "kryssrutan är 20 px",
    // "20 px-kryssruta".
    final sizeInText = RegExp(
      r'(?:[Kk]ryssrut\w*(?::| är)?\s*(?:<b>)?(\d+) ?px|(\d+) ?px-kryssrut)',
    );

    for (final doc in const [
      'design/Butlery Grafisk manual v6.dc.html',
      'design/Butlery Komponentark v1.dc.html',
      'design/produktregler.md',
      'design/evidensmatris.md',
    ]) {
      test('$doc states the size in tokens.controls.checkbox', () {
        final tokens = jsonDecode(_read('design/tokens.json')) as Map;
        final size = (tokens['controls'] as Map)['checkbox']['size'] as num;
        final stated = [
          for (final m in sizeInText.allMatches(_read(doc)))
            int.parse(m.group(1) ?? m.group(2)!),
        ];
        expect(stated, isNotEmpty, reason: '$doc no longer states the size');
        expect(
          stated.toSet(),
          {size.toInt()},
          reason: '$doc and design/tokens.json disagree on the checkbox size',
        );
      });
    }
  });

  group('decision log', () {
    List<int> rowsOf(String log) => RegExp(
      r'^\| B-(\d+) \|',
      multiLine: true,
    ).allMatches(log).map((m) => int.parse(m.group(1)!)).toList();

    test('no B number is used twice', () {
      final rows = rowsOf(_read('design/beslutslogg.md'));
      expect(rows.toSet().length, rows.length);
    });

    test('every product decision file row has a log row', () {
      final log = _read('design/beslutslogg.md');
      final ids = <String>[];
      for (final f in Directory('design/fas2').listSync()) {
        final name = f.path.replaceAll(r'\', '/').split('/').last;
        if (f is! File || !RegExp(r'^produktbeslut-.*\.json$').hasMatch(name)) {
          continue;
        }
        final doc = jsonDecode(f.readAsStringSync()) as Map;
        ids.addAll([for (final r in doc['rader'] as List) r['id'] as String]);
      }
      expect(ids, isNotEmpty);
      final missing = [
        for (final id in ids)
          if (!log.contains('| **$id')) id,
      ];
      expect(missing, isEmpty, reason: 'product decisions missing in the log');
    });

    test('a superseding status points at a row that exists', () {
      final log = _read('design/beslutslogg.md');
      final rows = rowsOf(log);
      final refs = RegExp(
        r'(?:ersatt|preciserad|preciserar) (?:av )?B-(\d+)',
      ).allMatches(log).map((m) => int.parse(m.group(1)!));
      for (final n in refs) {
        expect(rows, contains(n), reason: 'status points at B-$n');
      }
    });
  });
}
