/// CLI: turn parser shadow samples (ADR-0037) into import gate DRAFTS for a
/// person to review. Nothing is promoted: a person decides which answer is
/// right, marks the allergens and rewrites third-party text before anything
/// reaches `test/import_gate/`.
///
/// `dart run tools/shadow_promote.dart <shadow-export.json> [--out <dir>]`
///
/// Drafts go to `../butlery-shadow-drafts` (or `--out`), which must lie
/// outside this repository: the input text is a user's import, so it must
/// never be committed by accident.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'shadow_eval.dart';

/// An import gate gold (`test/import_gate/gate_scoring.dart`) drafted from one
/// side's answer. `allergen` is left for the reviewer: a guessed allergen in
/// a gate gold is worse than none.
Map<String, dynamic> gateDraft(
  Map<String, dynamic> answer, {
  required String side,
}) {
  final gold = shadowGold(answer);
  return {
    'form': 'UTKAST från $side — granska innan det flyttas in',
    'title': gold.title,
    'steps': gold.instructions.length,
    if (gold.instructions.isNotEmpty) 'lastStepKey': gold.instructions.last,
    'portions': ?int.tryParse(gold.portions ?? ''),
    'timeMinutes': ?gold.timeMinutes,
    'ingredients': [
      for (final i in gold.ingredients)
        if (i.name.isNotEmpty) {'key': i.name.toLowerCase()},
    ],
    'headings': <String>[],
    'absent': <String>[],
  };
}

/// The nearest directory at or above [start] holding `.git`, so the refusal
/// below holds wherever the tool is run from; [start] when there is none.
String repoRootFrom(String start) {
  var dir = p.normalize(p.absolute(start));
  while (true) {
    if (Directory(p.join(dir, '.git')).existsSync() ||
        File(p.join(dir, '.git')).existsSync()) {
      return dir;
    }
    final parent = p.dirname(dir);
    if (parent == dir) return p.normalize(p.absolute(start));
    dir = parent;
  }
}

/// Whether [dir] lies inside [repoRoot] — the one place drafts must not go.
bool insideRepo(String dir, String repoRoot) {
  final d = p.normalize(p.absolute(dir));
  final r = p.normalize(p.absolute(repoRoot));
  return p.equals(d, r) || p.isWithin(r, d);
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: dart run tools/shadow_promote.dart <shadow-export.json> [--out <dir>]',
    );
    exitCode = 64;
    return;
  }
  final repoRoot = repoRootFrom(Directory.current.path);
  final o = args.indexOf('--out');
  final out = o != -1 && o + 1 < args.length
      ? args[o + 1]
      : p.join(repoRoot, '..', 'butlery-shadow-drafts');
  if (insideRepo(out, repoRoot)) {
    stderr.writeln('Refusing to write drafts inside the repository: $out');
    exitCode = 1;
    return;
  }
  Directory(out).createSync(recursive: true);

  final rows = jsonDecode(File(args.first).readAsStringSync()) as List;
  const encoder = JsonEncoder.withIndent('  ');
  var written = 0;
  for (final raw in rows) {
    final row = (raw as Map).cast<String, dynamic>();
    final id = row['id']?.toString();
    final text = row['scrubbedInput'];
    final parser = row['parserOutput'];
    final output = row['scrubbedOutput'];
    if (id == null || text is! String || parser is! Map || output is! String) {
      continue;
    }
    Object? ai;
    try {
      ai = jsonDecode(output);
    } on FormatException {
      continue;
    }
    if (ai is! Map) continue;
    File(p.join(out, '$id.txt')).writeAsStringSync(text);
    File(p.join(out, '$id.ai.gold.json')).writeAsStringSync(
      encoder.convert(gateDraft(ai.cast<String, dynamic>(), side: 'AI')),
    );
    File(p.join(out, '$id.parser.gold.json')).writeAsStringSync(
      encoder.convert(
        gateDraft(parser.cast<String, dynamic>(), side: 'parsern'),
      ),
    );
    written++;
  }
  stdout.writeln('$written drafts written to $out. Nothing was promoted.');
}
