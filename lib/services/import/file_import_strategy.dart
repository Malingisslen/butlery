import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/file_content_provider.dart';
import 'package:butlery/services/import/spreadsheet_recipe_mapper.dart';
import 'package:butlery/services/import/xlsx_reader.dart';
import 'package:butlery/services/import/decompression_guard.dart';
import 'package:butlery/services/import/parsers/line_role.dart';
import 'package:butlery/utils/text/structured_ingredient_deriver.dart';
import 'package:butlery/core/utils/logger.dart';

/// File import strategy for CSV and Excel files
/// Supports importing recipes from structured spreadsheet formats
class FileImportStrategy extends ImportStrategy {
  final FileContentProvider _contentProvider;

  FileImportStrategy({FileContentProvider? contentProvider})
    : _contentProvider = contentProvider ?? DefaultFileContentProvider();
  static const _extensions = ['csv', 'xlsx', 'xls', 'paprikarecipes', 'json'];

  @override
  String get strategyName => 'File Import (CSV/Excel)';

  @override
  String get description => 'Import recipes from CSV or Excel files';

  @override
  String get inputExample =>
      'CSV or Excel file with columns: title, ingredients, instructions';

  @override
  bool validateInput(String input) {
    // File imports are handled through file picker, not text validation
    return false;
  }

  @override
  bool canHandle(String input) {
    // This strategy handles file picker operations, not direct text input
    return false;
  }

  @override
  Future<ImportResult> import(
    String input, {
    Map<String, dynamic>? options,
  }) async {
    // This method uses file picker to select files
    try {
      final result = await _contentProvider.pickFiles(
        type: FileType.custom,
        allowedExtensions: _extensions,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult.failure('No file selected');
      }

      final file = result.files.first;
      if (file.bytes == null) {
        return ImportResult.failure('Could not read file');
      }

      return await importFromContent(
        file.bytes!,
        (file.extension?.toLowerCase()).orEmpty(),
        options: options,
      );
    } catch (e) {
      AppLogger.error('File import failed', e);
      return ImportResult.failure(
        'Could not import from file. Please try again.',
      );
    }
  }

  /// The first recipe in [content]; the file-import screen goes through
  /// [importMultipleFromContent] and takes them all.
  Future<ImportResult> importFromContent(
    Uint8List content,
    String extension, {
    Map<String, dynamic>? options,
  }) async {
    if (!_extensions.contains(extension)) {
      return ImportResult.failure('Unsupported file format: $extension');
    }
    final recipes = await importMultipleFromContent(
      content,
      extension,
      options: options,
    );
    return recipes.isEmpty
        ? ImportResult.failure('Failed to parse file')
        : ImportResult.success(recipes.first);
  }

  /// Asks the user for one file; null when they picked none.
  Future<PlatformFile?> pickFile() async {
    final result = await _contentProvider.pickFiles(
      type: FileType.custom,
      allowedExtensions: _extensions,
      withData: true,
    );
    return result?.files.firstOrNull;
  }

  /// Every recipe in a file the user picked.
  Future<List<Recipe>> importPicked(
    PlatformFile file, {
    Map<String, dynamic>? options,
  }) async {
    final bytes = file.bytes;
    if (bytes == null) {
      AppLogger.error('File import failed: could not read file');
      return [];
    }
    return importMultipleFromContent(
      bytes,
      (file.extension?.toLowerCase()).orEmpty(),
      options: options,
    );
  }

  /// Every recipe in [content], read as an [extension] file.
  Future<List<Recipe>> importMultipleFromContent(
    Uint8List content,
    String extension, {
    Map<String, dynamic>? options,
  }) async {
    try {
      return switch (extension) {
        'csv' => _recipesFromRows(_csvRows(content)),
        // XlsxReader returns the first sheet that actually has rows, as plain
        // string rows.
        'xlsx' || 'xls' => _recipesFromRows(XlsxReader.readFirstSheet(content)),
        // BUT-1371: an entire migrated Paprika library imports, not just the
        // first recipe.
        'paprikarecipes' => _parsePaprikaRecipes(content),
        'json' => _parseJsonRecipes(content),
        _ => throw Exception('Unsupported file format: $extension'),
      };
    } catch (e) {
      AppLogger.error('Multiple content import failed', e);
      return [];
    }
  }

  /// CRIT-10: Decodes bytes to string with charset fallback.
  /// Tries UTF-8 first, falls back to Latin-1 (ISO-8859-1) for Swedish files.
  String _decodeWithFallback(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException catch (e) {
      AppLogger.warning(
        'CRIT-10: UTF-8 decode failed, trying Latin-1 (ISO-8859-1): $e',
        'FileImportStrategy',
      );
      // Fall back to Latin-1, which can decode any byte sequence
      return latin1.decode(bytes);
    }
  }

  List<List<dynamic>> _csvRows(Uint8List bytes) {
    var csvString = _decodeWithFallback(bytes);
    if (csvString.startsWith('\uFEFF')) {
      csvString = csvString.substring(1);
    }
    // Excel writes a `sep=;` line above the header when asked to; it names
    // the separator and is not a row.
    final sep = RegExp(r'^sep=(.)\r?\n').firstMatch(csvString);
    if (sep != null) {
      return CsvDecoder(
        fieldDelimiter: sep.group(1),
      ).convert(csvString.substring(sep.end));
    }
    return CsvDecoder(
      fieldDelimiter: csvDelimiter(csvString),
    ).convert(csvString);
  }

  /// The separator of a CSV file, read off its header row. Swedish Excel saves
  /// with `;` because `,` is the decimal mark. Only the header row is counted:
  /// ingredient cells further down are full of commas whatever the separator.
  @visibleForTesting
  static String csvDelimiter(String csv) {
    final header = csv.split(RegExp(r'\r\n|\r|\n')).first;
    final counts = {
      for (final d in const [',', ';', '\t']) d: 0,
    };
    var quoted = false;
    for (final char in header.split('')) {
      if (char == '"') quoted = !quoted;
      if (!quoted && counts.containsKey(char)) counts[char] = counts[char]! + 1;
    }
    final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    return best.value == 0 ? ',' : best.key;
  }

  /// The first row is the header row; every row after it is one recipe.
  List<Recipe> _recipesFromRows(List<List<dynamic>> rows) {
    if (rows.length < 2) return [];
    final headers = rows.first
        .map(SpreadsheetRecipeMapper.normalizeHeader)
        .toList();
    return [
      for (final row in rows.skip(1))
        ?SpreadsheetRecipeMapper.fromRow({
          for (var i = 0; i < headers.length && i < row.length; i++)
            headers[i]: (row[i]?.toString()).orEmpty(),
        }),
    ];
  }

  static String _jsonValueToString(dynamic v) {
    if (v == null) return '';
    if (v is List) return v.map((e) => '$e').join('\n');
    return '$v';
  }

  /// Parses every recipe in a `.paprikarecipes` archive.
  ///
  /// A Paprika export is a zip whose entries are each one gzip-compressed JSON
  /// recipe, so a real library holds many recipes. We collect them all (BUT-1371:
  /// the old path returned only the first, silently dropping the rest of the
  /// user's migrated library). Unparseable or oversized entries are skipped with
  /// a warning rather than failing the whole import.
  List<Recipe> _parsePaprikaRecipes(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    // Bound decompression so a crafted .paprikarecipes (a zip of gzipped JSON,
    // possibly shared by a third party) can't OOM the app (BUT-1370). One guard
    // spans the whole archive: it caps each outer zip entry before it inflates
    // and bounds the total gunzipped JSON we retain across all recipes.
    final guard = DecompressionGuard();
    final recipes = <Recipe>[];

    for (final file in archive.files) {
      if (!file.isFile) continue;
      try {
        // The outer .gz is transient (count:false) — capped, but only the
        // gunzipped JSON we keep is charged to the archive total.
        final gzipped = guard.read(file, count: false);
        final decompressed = guard.accept(
          '${file.name} (gunzipped)',
          const GZipDecoder().decodeBytes(gzipped),
        );
        final json =
            jsonDecode(utf8.decode(decompressed)) as Map<String, dynamic>;
        final recipe = _createRecipeFromPaprikaJson(json);
        if (recipe != null) recipes.add(recipe);
      } catch (e) {
        // Per-entry: a corrupt/oversized entry (incl. a DecompressionBomb-
        // Exception from the guard) is skipped, not fatal. Once the archive
        // total cap trips, every remaining entry trips it too, so a pathological
        // archive degrades to "import what fit under the cap" with warnings —
        // never an OOM, never a silent all-or-nothing drop.
        AppLogger.warning('Skipping Paprika entry ${file.name}: $e');
      }
    }

    return recipes;
  }

  Recipe? _createRecipeFromPaprikaJson(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    if (name == null || name.isEmpty) return null;

    // A colon-terminated heading ("Garnering:") groups the rows below it, as
    // on the URL and text paths; as an ingredient it left the recipe's
    // allergens unknown.
    final ingredientLines = <String>[];
    final sections = <String?>[];
    String? section;
    for (final line in (json['ingredients'] as String?).orEmpty().split('\n')) {
      if (line.trim().isEmpty) continue;
      final role = line.trim().endsWith(':') ? LineRoles.of(line) : null;
      switch (role?.kind) {
        case LineRoleKind.heading:
          section = role!.label;
        case LineRoleKind.blockMarker:
          section = null;
        case LineRoleKind.ingredient:
          ingredientLines.add(role!.label!);
          sections.add(section);
        case LineRoleKind.undecided || null:
          ingredientLines.add(line);
          sections.add(section);
      }
    }
    final directionLines = (json['directions'] as String?)
        .orEmpty()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    final recipe = SpreadsheetRecipeMapper.fromRow({
      'title': name,
      'description': (json['description'] as String?).orEmpty(),
      'ingredients': ingredientLines.join('\n'),
      'instructions': directionLines.join('\n'),
      'source':
          json['source_url'] as String? ?? json['source'] as String? ?? '',
      'rating': '${json['rating'] ?? ''}',
      'servings': (json['servings'] as String?).orEmpty(),
      'time': (json['total_time'] as String?).orEmpty(),
      // Paprika categories are the user's own labels ("Desserts",
      // "Favoriter"); only one that names a meal type sets it.
      'mealtype': SpreadsheetRecipeMapper.mealTypeFor(
        (json['categories'] is List ? json['categories'] as List : const [])
            .whereType<String>(),
      ).orEmpty(),
    });
    if (recipe == null || sections.every((s) => s == null)) return recipe;
    return recipe.copyWith(
      structuredIngredients: StructuredIngredientDeriver.deriveAll(
        recipe.ingredients,
        sections: sections,
      ),
    );
  }

  /// A JSON file holds one recipe object or a list of them, keyed like the
  /// spreadsheet columns. Anything else in it is skipped, not fatal.
  List<Recipe> _parseJsonRecipes(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(_decodeWithFallback(bytes));
    } on FormatException catch (e) {
      AppLogger.warning(
        'JSON import: not valid JSON: $e',
        'FileImportStrategy',
      );
      return [];
    }
    return [
      for (final item in decoded is List ? decoded : [decoded])
        if (item is Map)
          ?SpreadsheetRecipeMapper.fromRow({
            for (final e in item.entries)
              SpreadsheetRecipeMapper.normalizeHeader(
                e.key,
              ): _jsonValueToString(
                e.value,
              ),
          }),
    ];
  }
}
