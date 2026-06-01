/// Filesystem layout resolver for the cookbook gold corpus.
///
/// The corpus lives OUTSIDE the app repo (binary scans + copyrighted source),
/// defaulting to a sibling `butlery-corpus/` directory. Override with the
/// `BUTLERY_CORPUS_DIR` environment variable. Pure `dart:io`.
library;

import 'dart:io';

class CorpusPaths {
  /// Absolute path to the corpus root.
  final String root;

  CorpusPaths(this.root);

  /// Resolves the root from `BUTLERY_CORPUS_DIR`, else `<repoRoot>/../butlery-corpus`.
  /// [repoRoot] defaults to the current working directory (the app repo when
  /// run via `flutter test` / `dart run`).
  factory CorpusPaths.resolve({String? repoRoot}) {
    final override = Platform.environment['BUTLERY_CORPUS_DIR'];
    if (override != null && override.trim().isNotEmpty) {
      return CorpusPaths(_clean(override.trim()));
    }
    final base = repoRoot ?? Directory.current.path;
    return CorpusPaths(_clean('$base/../butlery-corpus'));
  }

  Directory get rootDir => Directory(root);

  bool get exists => rootDir.existsSync();

  String book(String bookSlug) => '$root/$bookSlug';

  String bookMetaFile(String bookSlug) => '${book(bookSlug)}/book.json';

  String inbox(String bookSlug) => '${book(bookSlug)}/inbox';

  String recipe(String bookSlug, String recipeId) =>
      '${book(bookSlug)}/$recipeId';

  String ocrText(String bookSlug, String recipeId) =>
      '${recipe(bookSlug, recipeId)}/ocr.txt';

  String ocrMeta(String bookSlug, String recipeId) =>
      '${recipe(bookSlug, recipeId)}/ocr.meta.json';

  String draft(String bookSlug, String recipeId) =>
      '${recipe(bookSlug, recipeId)}/draft.json';

  String gold(String bookSlug, String recipeId) =>
      '${recipe(bookSlug, recipeId)}/gold.json';

  String reportsDir() => '$root/_reports';

  /// Every book directory (children of root, excluding the `_reports` sink).
  List<Directory> books() {
    if (!exists) return const [];
    return rootDir
        .listSync()
        .whereType<Directory>()
        .where((d) => !_basename(d.path).startsWith('_'))
        .toList();
  }

  /// Recipe directories inside [bookSlug] — children that hold a `gold.json`
  /// (so an empty `inbox/` is never mistaken for a recipe).
  List<Directory> recipeDirs(String bookSlug) {
    final dir = Directory(book(bookSlug));
    if (!dir.existsSync()) return const [];
    return dir
        .listSync()
        .whereType<Directory>()
        .where((d) => File('${d.path}/gold.json').existsSync())
        .toList();
  }

  // --- Multi-recipe layout (BUT: cookbook spreads hold several recipes) ---
  //
  // A page image whose OCR yields N>1 recipes nests one `recipe-NN/` dir per
  // recipe under the image dir, while `ocr.txt` / `page-01.jpg` stay shared at
  // the image level. Single-recipe pages keep the flat `<imageId>/gold.json`
  // form. [recipeEntries] discovers BOTH so existing flat corpora keep scoring.

  String recipeBlock(String bookSlug, String imageId, String blockId) =>
      '${recipe(bookSlug, imageId)}/$blockId';

  String goldBlock(String bookSlug, String imageId, String blockId) =>
      '${recipeBlock(bookSlug, imageId, blockId)}/gold.json';

  String draftBlock(String bookSlug, String imageId, String blockId) =>
      '${recipeBlock(bookSlug, imageId, blockId)}/draft.json';

  /// Every scorable recipe in [bookSlug], flattening the two layouts into one
  /// list. A flat image dir (gold.json directly inside) → one entry; an image
  /// dir with `recipe-NN/` children → one entry per block. OCR text is always
  /// resolved at the image level.
  List<RecipeEntry> recipeEntries(String bookSlug) {
    final dir = Directory(book(bookSlug));
    if (!dir.existsSync()) return const [];
    final entries = <RecipeEntry>[];
    for (final imageDir in dir.listSync().whereType<Directory>()) {
      final imageId = _basename(imageDir.path);
      if (imageId == 'inbox') continue;
      final ocrPath = ocrText(bookSlug, imageId);

      // Flat (single-recipe) layout.
      if (File('${imageDir.path}/gold.json').existsSync()) {
        entries.add(RecipeEntry(
          bookSlug: bookSlug,
          imageId: imageId,
          blockId: null,
          goldPath: gold(bookSlug, imageId),
          draftPath: draft(bookSlug, imageId),
          ocrTextPath: ocrPath,
        ));
        continue;
      }

      // Nested (multi-recipe) layout.
      final blocks = imageDir
          .listSync()
          .whereType<Directory>()
          .where((b) => File('${b.path}/gold.json').existsSync())
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final blockDir in blocks) {
        final blockId = _basename(blockDir.path);
        entries.add(RecipeEntry(
          bookSlug: bookSlug,
          imageId: imageId,
          blockId: blockId,
          goldPath: goldBlock(bookSlug, imageId, blockId),
          draftPath: draftBlock(bookSlug, imageId, blockId),
          ocrTextPath: ocrPath,
        ));
      }
    }
    return entries;
  }

  static String _clean(String p) => p.replaceAll('\\', '/');

  static String _basename(String p) {
    final cleaned = _clean(p);
    final i = cleaned.lastIndexOf('/');
    return i < 0 ? cleaned : cleaned.substring(i + 1);
  }
}

/// A single scorable recipe location, abstracting over the flat (single-recipe)
/// and nested (`recipe-NN/`, multi-recipe) layouts. The eval engine consumes
/// these without caring which on-disk form produced them.
class RecipeEntry {
  final String bookSlug;
  final String imageId;

  /// `null` for the flat single-recipe layout; `recipe-NN` for a nested block.
  final String? blockId;

  final String goldPath;
  final String draftPath;
  final String ocrTextPath;

  const RecipeEntry({
    required this.bookSlug,
    required this.imageId,
    required this.blockId,
    required this.goldPath,
    required this.draftPath,
    required this.ocrTextPath,
  });

  /// Stable per-recipe id, e.g. `scan_007` (flat) or `scan_007/recipe-02`.
  String get recipeId => blockId == null ? imageId : '$imageId/$blockId';
}
