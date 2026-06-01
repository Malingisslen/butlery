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

  static String _clean(String p) => p.replaceAll('\\', '/');

  static String _basename(String p) {
    final cleaned = _clean(p);
    final i = cleaned.lastIndexOf('/');
    return i < 0 ? cleaned : cleaned.substring(i + 1);
  }
}
