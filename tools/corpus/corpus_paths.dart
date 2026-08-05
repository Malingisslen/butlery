/// Filesystem layout resolver for the cookbook gold corpus.
///
/// The corpus lives OUTSIDE the app repo (binary scans + copyrighted source),
/// defaulting to a sibling `butlery-corpus/` directory. Override with the
/// `BUTLERY_CORPUS_DIR` environment variable. Pure `dart:io`.
library;

import 'dart:convert';
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

  /// Per-line geometry for the page, captured once from an offline OCR engine
  /// and replayed forever. Held separately from [ocrText] because the text and
  /// the geometry come from DIFFERENT engines: the text is the paid tier's
  /// (better Swedish), the geometry is Windows' offline recognizer (free, and
  /// the only one that runs on a dev machine). They must never be read as one
  /// page — a heading index from one does not address the other.
  String ocrLayout(String bookSlug, String recipeId) =>
      '${recipe(bookSlug, recipeId)}/layout-winocr.json';

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

      final blocks =
          imageDir
              .listSync()
              .whereType<Directory>()
              .where((b) => File('${b.path}/gold.json').existsSync())
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      // A page can carry gold at BOTH levels: the prelabel writes a page-level
      // draft AND one per block, so whichever shape the transcriber did not use
      // is left behind as an unverified leftover. VERIFIED gold is the truth
      // wherever it sits, so the level is chosen by where the verification is —
      // never by which file exists.
      //
      // Choosing on existence alone (as this did until 2026-08-04) let a flat
      // leftover SHADOW verified blocks: `recipeEntries` returned one
      // unverified entry, the eval skipped it as "not verified yet", and every
      // verified recipe on that spread left the score without a word. It was
      // most of the long-standing "scores far fewer than the verified count"
      // gap. Deliberately no page counts here — the corpus is live and outside
      // the repo, so any number pinned in this comment is false within hours
      // (the first draft of it went stale the same night). Run
      // `tools/corpus_split_eval.dart` for the current figures.
      final flatGold = File('${imageDir.path}/gold.json');
      final useBlocks =
          blocks.isNotEmpty &&
          (!flatGold.existsSync() ||
              !_isVerified(flatGold) ||
              blocks.any((b) => _isVerified(File('${b.path}/gold.json'))));

      if (!useBlocks) {
        if (!flatGold.existsSync()) continue;
        entries.add(
          RecipeEntry(
            bookSlug: bookSlug,
            imageId: imageId,
            blockId: null,
            goldPath: gold(bookSlug, imageId),
            draftPath: draft(bookSlug, imageId),
            ocrTextPath: ocrPath,
          ),
        );
        continue;
      }

      for (final blockDir in blocks) {
        final blockId = _basename(blockDir.path);
        entries.add(
          RecipeEntry(
            bookSlug: bookSlug,
            imageId: imageId,
            blockId: blockId,
            goldPath: goldBlock(bookSlug, imageId, blockId),
            draftPath: draftBlock(bookSlug, imageId, blockId),
            ocrTextPath: ocrPath,
          ),
        );
      }
    }
    return entries;
  }

  /// True only when the file exists AND says `verified: true`. A missing or
  /// malformed gold file is NOT verified — an unreadable file must never pass
  /// for a transcription someone stood behind.
  static bool _isVerified(File goldFile) {
    if (!goldFile.existsSync()) return false;
    try {
      final m = jsonDecode(goldFile.readAsStringSync());
      return m is Map && m['verified'] == true;
    } catch (_) {
      return false;
    }
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
