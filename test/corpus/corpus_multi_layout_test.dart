@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import '../../tools/corpus/corpus_eval_core.dart';
import '../../tools/corpus/corpus_paths.dart';

/// Minimal verified gold/draft pair JSON for a recipe with one ingredient.
const _goldJson = '''
{ "verified": true, "title": "T", "ingredients":
  [ { "name": "mjöl", "originalLine": "3 dl mjöl", "quantity": "3", "unit": "dl" } ],
  "instructions": ["Rör."] }''';

void main() {
  late Directory tmp;
  late CorpusPaths paths;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('corpus_multi_');
    paths = CorpusPaths(tmp.path.replaceAll('\\', '/'));

    // Flat single-recipe image dir.
    final flat = Directory('${tmp.path}/testbok/flatrecipe')
      ..createSync(recursive: true);
    File('${flat.path}/ocr.txt').writeAsStringSync('3 dl mjöl');
    File('${flat.path}/gold.json').writeAsStringSync(_goldJson);
    File('${flat.path}/draft.json').writeAsStringSync(_goldJson);

    // Multi-recipe image dir: shared ocr.txt + two recipe-NN blocks.
    final multi = Directory('${tmp.path}/testbok/multipage')
      ..createSync(recursive: true);
    File('${multi.path}/ocr.txt').writeAsStringSync('3 dl mjöl');
    for (final b in ['recipe-01', 'recipe-02']) {
      final block = Directory('${multi.path}/$b')..createSync(recursive: true);
      File('${block.path}/gold.json').writeAsStringSync(_goldJson);
      File('${block.path}/draft.json').writeAsStringSync(_goldJson);
    }
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  group('recipeEntries', () {
    test('discovers both the flat dir and each nested recipe-NN block', () {
      final entries = paths.recipeEntries('testbok');
      final ids = entries.map((e) => e.recipeId).toSet();

      expect(entries, hasLength(3));
      expect(ids, contains('flatrecipe'));
      expect(ids, contains('multipage/recipe-01'));
      expect(ids, contains('multipage/recipe-02'));
    });

    test('nested blocks share the image-level ocr.txt', () {
      final nested =
          paths.recipeEntries('testbok').where((e) => e.imageId == 'multipage');
      expect(nested, hasLength(2));
      for (final e in nested) {
        expect(e.ocrTextPath, endsWith('multipage/ocr.txt'));
        expect(File(e.ocrTextPath).existsSync(), isTrue);
      }
    });
  });

  group('eval loadEntries', () {
    test('loads each flat + nested recipe as its own CorpusEntry', () {
      final load = loadEntries(paths);
      expect(load.entries, hasLength(3));
      // Every entry resolved its shared/own OCR text.
      expect(load.entries.every((e) => e.ocrText.contains('mjöl')), isTrue);
    });
  });
}
