// Migration script: replaces `DateTime.now()` → `clock.now()` across a
// directory of Dart sources, adding `package:clock/clock.dart` to the
// imports (alphabetically). Preserves `DateTime.now().millisecondsSinceEpoch`
// and `DateTime.now().microsecondsSinceEpoch` patterns — these are
// unique-ID generators where deterministic time would risk collisions
// inside `withClock` test zones.
//
// Usage:
//   dart scripts/migrate_clock_now.dart --dry-run lib/core/
//   dart scripts/migrate_clock_now.dart lib/core/        # apply
//   dart scripts/migrate_clock_now.dart lib/             # apply across whole tree
//
// One-shot: idempotent re-runs are safe. If `clock.now()` is already
// present and no `DateTime.now()` remains, the file is untouched.

import 'dart:io';

/// Matches `DateTime.now()` NOT followed by `.millisecondsSinceEpoch` or
/// `.microsecondsSinceEpoch`. Negative lookahead preserves ID-generation
/// patterns where deterministic time would risk collisions in withClock zones.
final _migrateRegex = RegExp(
  r'DateTime\.now\(\)(?!\.(milli|micro)secondsSinceEpoch)',
);

/// True if [line] is a Dart comment line (doc comment, line comment, or
/// inside a /* */ block we treat conservatively as code-only).
bool _isCommentLine(String line) {
  final t = line.trimLeft();
  return t.startsWith('///') || t.startsWith('//');
}

const _clockImport = "import 'package:clock/clock.dart';";

void main(List<String> args) {
  final dryRun = args.contains('--dry-run');
  final paths = args.where((a) => !a.startsWith('--')).toList();
  if (paths.isEmpty) {
    stderr.writeln(
        'Usage: dart scripts/migrate_clock_now.dart [--dry-run] <path>...');
    exit(2);
  }

  final files = <File>[];
  for (final p in paths) {
    final entity = FileSystemEntity.typeSync(p);
    if (entity == FileSystemEntityType.directory) {
      files.addAll(
        Directory(p)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) =>
                !f.path.endsWith('.g.dart') &&
                !f.path.endsWith('.freezed.dart') &&
                !f.path.contains(
                    '${Platform.pathSeparator}generated${Platform.pathSeparator}')),
      );
    } else if (entity == FileSystemEntityType.file) {
      files.add(File(p));
    }
  }

  final summary = _MigrationSummary();
  for (final file in files) {
    _migrateFile(file, dryRun: dryRun, summary: summary);
  }

  stdout.writeln('---');
  stdout.writeln(
    'Files scanned: ${summary.scanned}, edited: ${summary.edited}, '
    'skipped (no DateTime.now timestamp use): ${summary.skipped}, '
    'preserved id-gen-only: ${summary.idGenOnly}',
  );
  stdout.writeln('Total replacements: ${summary.replacements}');
  if (dryRun) {
    stdout.writeln('(dry run — no files written)');
  }
}

class _MigrationSummary {
  int scanned = 0;
  int edited = 0;
  int skipped = 0;
  int idGenOnly = 0;
  int replacements = 0;
}

void _migrateFile(File file,
    {required bool dryRun, required _MigrationSummary summary}) {
  summary.scanned++;
  final original = file.readAsStringSync();

  // Migrate per-line, skipping comment lines so doc-comment example
  // code blocks don't get rewritten (which would dangle as unused
  // imports when no real code uses clock.now()).
  final lines = original.split('\n');
  var timestampMatches = 0;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (_isCommentLine(line)) continue;
    final migratedLine = line.replaceAllMapped(_migrateRegex, (_) {
      timestampMatches++;
      return 'clock.now()';
    });
    lines[i] = migratedLine;
  }

  if (timestampMatches == 0) {
    // Nothing actionable (only id-gen patterns or only doc-comment
    // example-code uses).
    summary.idGenOnly++;
    return;
  }

  final migrated = lines.join('\n');
  final withImport = _ensureClockImport(migrated);

  summary.edited++;
  summary.replacements += timestampMatches;

  if (dryRun) {
    stdout.writeln('[would edit $timestampMatches×] ${file.path}');
    return;
  }

  file.writeAsStringSync(withImport);
}

/// Inserts `import 'package:clock/clock.dart';` if absent, placed
/// alphabetically among existing `package:` imports (or after the last
/// `dart:` import if no package: imports exist).
String _ensureClockImport(String source) {
  if (source.contains(_clockImport)) return source;
  // Don't add the import if `clock.` is already imported under a different name
  // (defensive; very unlikely in this codebase).
  if (RegExp(r"import 'package:clock/").hasMatch(source)) return source;

  final lines = source.split('\n');
  // Find the first import line that comes alphabetically after package:clock,
  // among `import 'package:...'` or `import 'dart:...'` lines at the top.
  // Strategy: find the last contiguous block of import lines starting from
  // the first `import` line; insert at the right spot.
  int firstImportIdx = -1;
  int lastImportIdx = -1;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trimLeft();
    if (line.startsWith('import ') && line.endsWith(';')) {
      firstImportIdx = (firstImportIdx == -1) ? i : firstImportIdx;
      lastImportIdx = i;
    } else if (firstImportIdx != -1 &&
        line.isNotEmpty &&
        !line.startsWith('//')) {
      // Stop scanning at first non-import non-comment non-blank line after
      // we've started seeing imports.
      break;
    }
  }

  if (firstImportIdx == -1) {
    // No imports at all — add at the top after any leading comments / library
    // directives.
    var insertAt = 0;
    while (insertAt < lines.length) {
      final line = lines[insertAt].trim();
      if (line.startsWith('//') ||
          line.startsWith('library') ||
          line.startsWith('@') ||
          line.isEmpty) {
        insertAt++;
        continue;
      }
      break;
    }
    lines.insert(insertAt, '');
    lines.insert(insertAt + 1, _clockImport);
    return lines.join('\n');
  }

  // Find the alphabetical insertion point within the package: import
  // block, AFTER all dart: imports.
  int insertAt = lastImportIdx + 1;
  var seenAnyPackageImport = false;
  for (var i = firstImportIdx; i <= lastImportIdx; i++) {
    final line = lines[i].trim();
    if (line.startsWith("import 'dart:")) {
      // Always insert after dart: imports.
      continue;
    }
    if (line.startsWith("import 'package:")) {
      if (!seenAnyPackageImport) {
        // First package: import seen — provisional insertion point if
        // all package: imports sort after `clock`.
        insertAt = i;
        seenAnyPackageImport = true;
      }
      final pkgName =
          RegExp(r"package:([^/']+)").firstMatch(line)?.group(1) ?? '';
      if (pkgName.compareTo('clock') < 0) {
        // This package sorts before `clock`; insertion point is just
        // past it (we keep advancing as we see later sorts).
        insertAt = i + 1;
      } else if (pkgName.compareTo('clock') > 0) {
        // First package after `clock` alphabetically — insert here.
        insertAt = i;
        break;
      }
    }
  }

  lines.insert(insertAt, _clockImport);
  return lines.join('\n');
}
