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
      final nested = paths
          .recipeEntries('testbok')
          .where((e) => e.imageId == 'multipage');
      expect(nested, hasLength(2));
      for (final e in nested) {
        expect(e.ocrTextPath, endsWith('multipage/ocr.txt'));
        expect(File(e.ocrTextPath).existsSync(), isTrue);
      }
    });
  });

  // A page can carry gold at BOTH levels, because the prelabel writes a
  // page-level draft AND one per block, so whichever shape the transcriber did
  // not use is left behind unverified. Until 2026-08-04 the level was chosen by
  // which FILE EXISTS, so the flat leftover shadowed the blocks: one unverified
  // entry came back, the eval skipped it as "not verified yet", and every
  // verified recipe on those spreads silently left the score. (No page counts
  // here on purpose — the corpus lives outside the repo and keeps growing, so a
  // number pinned in a comment is false within hours. The fixtures below are
  // self-contained; run `tools/corpus_split_eval.dart` for live figures.) That is a measurement failure no eval
  // number can show — it reports a confident percentage over a corpus quietly
  // missing most of a book.
  group('recipeEntries chooses the level by VERIFICATION, not by existence', () {
    late Directory tmp2;
    late CorpusPaths mixed;

    /// [verified] is the only thing that differs between the two levels, so a
    /// wrong choice cannot be explained by anything else in the fixture.
    String goldWith({required bool verified}) =>
        _goldJson.replaceFirst('"verified": true', '"verified": $verified');

    void page(
      String imageId, {
      required bool flatVerified,
      required bool blocksVerified,
    }) {
      final dir = Directory('${tmp2.path}/testbok/$imageId')
        ..createSync(recursive: true);
      File('${dir.path}/ocr.txt').writeAsStringSync('3 dl mjöl');
      File(
        '${dir.path}/gold.json',
      ).writeAsStringSync(goldWith(verified: flatVerified));
      for (final b in ['recipe-01', 'recipe-02']) {
        final block = Directory('${dir.path}/$b')..createSync(recursive: true);
        File(
          '${block.path}/gold.json',
        ).writeAsStringSync(goldWith(verified: blocksVerified));
      }
    }

    setUp(() {
      tmp2 = Directory.systemTemp.createTempSync('corpus_level_');
      mixed = CorpusPaths(tmp2.path.replaceAll('\\', '/'));
    });

    tearDown(() => tmp2.deleteSync(recursive: true));

    test('verified blocks win over an unverified flat leftover', () {
      page('spread', flatVerified: false, blocksVerified: true);

      final ids = mixed.recipeEntries('testbok').map((e) => e.recipeId).toSet();
      expect(ids, {'spread/recipe-01', 'spread/recipe-02'});
      expect(
        ids,
        isNot(contains('spread')),
        reason: 'the flat leftover must not shadow the verified blocks',
      );
    });

    test('a verified flat page wins over unverified block leftovers', () {
      // The mirror, and the reason the rule is not simply "blocks always win":
      // the prelabel writes block seeds for a page the transcriber then
      // verified flat. Scoring the empty seeds instead would drop the recipe.
      page('single', flatVerified: true, blocksVerified: false);

      final ids = mixed.recipeEntries('testbok').map((e) => e.recipeId).toSet();
      expect(ids, {'single'});
    });

    test('with neither level verified the blocks are still preferred', () {
      // Nothing is scorable either way, but the blocks are the truer shape of
      // the page, so a later verification lands where the eval already looks.
      page('unverified', flatVerified: false, blocksVerified: false);

      final ids = mixed.recipeEntries('testbok').map((e) => e.recipeId).toSet();
      expect(ids, {'unverified/recipe-01', 'unverified/recipe-02'});
    });

    test('a malformed flat gold never passes for a verified transcription', () {
      final dir = Directory('${tmp2.path}/testbok/broken')
        ..createSync(recursive: true);
      File('${dir.path}/ocr.txt').writeAsStringSync('3 dl mjöl');
      File('${dir.path}/gold.json').writeAsStringSync('{ not json');
      final block = Directory('${dir.path}/recipe-01')
        ..createSync(recursive: true);
      File(
        '${block.path}/gold.json',
      ).writeAsStringSync(goldWith(verified: true));

      final ids = mixed.recipeEntries('testbok').map((e) => e.recipeId).toSet();
      expect(ids, {'broken/recipe-01'});
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
