import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/decompression_guard.dart';
import 'package:butlery/services/import/file_import_strategy.dart';

/// BUT-1371: a `.paprikarecipes` archive holds one gzip-compressed JSON recipe
/// per entry. The import used to `return` on the first parseable entry (and the
/// bulk path the file-import UI actually calls had no Paprika branch at all, so
/// it returned nothing), silently dropping a migrating user's whole library.
/// These tests pin that the multi-recipe path now recovers every recipe.
void main() {
  late FileImportStrategy strategy;

  setUp(() {
    strategy = FileImportStrategy();
  });

  /// Builds a real `.paprikarecipes` archive: each recipe is JSON → gzip → one
  /// zip entry, exactly the shape Paprika exports.
  Uint8List paprikaArchive(List<Map<String, dynamic>> recipes) {
    final archive = Archive();
    for (var i = 0; i < recipes.length; i++) {
      final gz = const GZipEncoder().encode(
        utf8.encode(jsonEncode(recipes[i])),
      );
      archive.addFile(ArchiveFile('recipe_$i.paprikarecipe', gz.length, gz));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  test(
    'importMultipleFromContent returns every recipe in the archive',
    () async {
      final bytes = paprikaArchive([
        {
          'name': 'Pannkakor',
          'ingredients': '3 ägg\n6 dl mjölk',
          'directions': 'Vispa\nStek',
        },
        {
          'name': 'Köttbullar',
          'ingredients': '500 g färs',
          'directions': 'Rulla\nStek',
        },
        {
          'name': 'Äppelpaj',
          'ingredients': '4 äpplen',
          'directions': 'Skala\nGrädda',
        },
      ]);

      final recipes = await strategy.importMultipleFromContent(
        bytes,
        'paprikarecipes',
      );

      expect(recipes, hasLength(3));
      expect(
        recipes.map((r) => r.title),
        containsAll(['Pannkakor', 'Köttbullar', 'Äppelpaj']),
      );
    },
  );

  test('skips an unparseable entry but keeps the valid recipes', () async {
    final archive = Archive();
    final ok = const GZipEncoder().encode(
      utf8.encode(jsonEncode({'name': 'Soppa'})),
    );
    archive.addFile(ArchiveFile('ok.paprikarecipe', ok.length, ok));
    // A non-gzip entry: GZipDecoder throws, the entry is skipped, not fatal.
    final junk = utf8.encode('this is not gzip');
    archive.addFile(ArchiveFile('junk.paprikarecipe', junk.length, junk));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

    final recipes = await strategy.importMultipleFromContent(
      bytes,
      'paprikarecipes',
    );

    expect(recipes, hasLength(1));
    expect(recipes.first.title, 'Soppa');
  });

  test(
    'single importFromContent path still returns the first recipe',
    () async {
      final bytes = paprikaArchive([
        {'name': 'First'},
        {'name': 'Second'},
      ]);

      final result = await strategy.importFromContent(bytes, 'paprikarecipes');

      expect(result.isSuccess, isTrue);
      expect(result.recipe, isNotNull);
      expect(result.recipe!.title, 'First');
    },
  );

  test(
    'an entry whose gunzipped JSON exceeds the bomb-guard cap is skipped, '
    'not imported and not fatal — valid siblings are still collected',
    () async {
      // Build an archive with one oversized entry (inflates past the per-entry
      // cap that DecompressionGuard.accept() enforces) followed by a valid one.
      // The per-entry cap is DecompressionGuard.defaultMaxEntryBytes (20 MB).
      // We build the oversized payload at cap+1 bytes so the guard throws
      // DecompressionBombException, which the per-entry catch in
      // _parsePaprikaRecipes absorbs — so the bomb entry is skipped and the
      // valid recipe is still returned.
      final oversizedJson = List.filled(
        DecompressionGuard.defaultMaxEntryBytes + 1,
        0x20, // space — valid UTF-8 filler
      );
      final oversizedGz = const GZipEncoder().encode(oversizedJson);

      final validGz = const GZipEncoder().encode(
        utf8.encode(jsonEncode({'name': 'Fruktsoppa'})),
      );

      final archive = Archive()
        ..addFile(
          ArchiveFile('bomb.paprikarecipe', oversizedGz.length, oversizedGz),
        )
        ..addFile(ArchiveFile('ok.paprikarecipe', validGz.length, validGz));

      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

      final recipes = await strategy.importMultipleFromContent(
        bytes,
        'paprikarecipes',
      );

      expect(recipes, hasLength(1));
      expect(recipes.first.title, 'Fruktsoppa');
    },
  );
}
