// test/golden/llm/_golden_runner.dart
//
// BUT-784 — LLM golden-set foundation.
//
// Foundation only: case loader + scoring contract. The actual model wiring
// per corpus is a per-corpus follow-up ticket — see README.md.
//
// Why a custom skeleton instead of `flutter test`-driven cases?
//   * Corpora come from external JSON; flutter_test fixture wiring would
//     scatter case files into Dart literals.
//   * Cost guard must wrap the runner, not per-test invocations.
//   * Failure shape is "list of regressed case ids", not "test failure
//     stack trace" — the operator wants a triageable JSON report.

library;

import 'dart:convert';
import 'dart:io';

/// One row of `cases.json`. Schema documented in `README.md`.
class GoldenCase {
  final String id;
  final Object input;
  final Object expected;
  final String tolerance; // 'exact' | 'similarity' | 'jaccard'
  final List<String> tags;
  final String? notes;

  GoldenCase({
    required this.id,
    required this.input,
    required this.expected,
    required this.tolerance,
    this.tags = const [],
    this.notes,
  });

  factory GoldenCase.fromJson(Map<String, dynamic> json) {
    return GoldenCase(
      id: json['id'] as String,
      input: json['input'] as Object,
      expected: json['expected'] as Object,
      tolerance: json['tolerance'] as String? ?? 'exact',
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      notes: json['notes'] as String?,
    );
  }
}

/// Result of running one case.
class GoldenResult {
  final String id;
  final bool passed;
  final String? failureReason;
  final int tokensIn;
  final int tokensOut;
  GoldenResult({
    required this.id,
    required this.passed,
    this.failureReason,
    this.tokensIn = 0,
    this.tokensOut = 0,
  });
}

/// A callable that runs the model under test against the case input
/// and returns the actual output. Per-corpus runners implement this and
/// hand the result to [scoreCase].
typedef ModelRunner = Future<Object> Function(Object input);

/// Resolve a corpus directory path relative to the repo root, with a
/// fallback for runners that resolve cwd to the test file's directory.
///
/// Shared by per-corpus test files so neither has to reimplement cwd
/// resilience.
String resolveCorpusPath(String corpus) {
  final repoRelative = 'test/golden/llm/$corpus';
  if (Directory(repoRelative).existsSync()) return repoRelative;
  final testLocal = './$corpus';
  if (Directory(testLocal).existsSync()) return testLocal;
  return repoRelative;
}

/// Load + parse a corpus directory's `cases.json`.
List<GoldenCase> loadCases(String corpusPath) {
  final file = File('$corpusPath/cases.json');
  if (!file.existsSync()) {
    throw StateError('No cases.json at $corpusPath');
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! List) {
    throw StateError(
      'cases.json at $corpusPath must be a top-level JSON array, '
      'got ${decoded.runtimeType}',
    );
  }
  return decoded
      .cast<Map<String, dynamic>>()
      .map(GoldenCase.fromJson)
      .toList(growable: false);
}

/// Score one case. Pure function — caller supplies the actual output.
GoldenResult scoreCase(GoldenCase c, Object actual) {
  switch (c.tolerance) {
    case 'exact':
      final ok = _normalizeForExact(actual) == _normalizeForExact(c.expected);
      return GoldenResult(
        id: c.id,
        passed: ok,
        failureReason: ok ? null : 'expected="${c.expected}" actual="$actual"',
      );
    case 'similarity':
      // Foundation pass: similarity scoring needs an embedding model. Throwing
      // (rather than silently failing) so a corpus author who picks this
      // tolerance gets a loud signal at authoring time instead of nightly
      // false-regression noise. Wire-up tracked in BUT-889.
      throw UnimplementedError(
        'similarity tolerance not wired in foundation pass; '
        'see BUT-889 follow-up',
      );
    case 'jaccard':
      final score = _jaccardForEntityLists(actual, c.expected);
      final ok = score >= 0.80;
      return GoldenResult(
        id: c.id,
        passed: ok,
        failureReason: ok
            ? null
            : 'jaccard=$score < 0.80 (expected=${c.expected} actual=$actual)',
      );
    default:
      return GoldenResult(
        id: c.id,
        passed: false,
        failureReason: 'unknown tolerance: ${c.tolerance}',
      );
  }
}

String _normalizeForExact(Object o) => o.toString().trim().toLowerCase();

/// Jaccard similarity over entity-span lists. Each entry compared by
/// (text, label) tuple. Returns 1.0 when both sets are empty.
double _jaccardForEntityLists(Object actual, Object expected) {
  Set<String> asKeySet(Object o) {
    if (o is! List) return {};
    return o
        .cast<Map>()
        .map((m) => '${m['text']}|${m['label']}'.toLowerCase())
        .toSet();
  }

  final a = asKeySet(actual);
  final b = asKeySet(expected);
  if (a.isEmpty && b.isEmpty) return 1.0;
  final intersection = a.intersection(b).length;
  final union = a.union(b).length;
  return union == 0 ? 0.0 : intersection / union;
}

/// Drive a corpus end-to-end: load cases, run them through [runner],
/// score, return per-case results. Emit a JSON summary to stdout.
///
/// Foundation only: per-corpus integration (wiring `runner` to the live
/// model) is a follow-up ticket per corpus.
Future<List<GoldenResult>> runCorpus(
  String corpusPath, {
  required ModelRunner runner,
  String? corpusLabel,
}) async {
  final cases = loadCases(corpusPath);
  final results = <GoldenResult>[];
  for (final c in cases) {
    try {
      final actual = await runner(c.input);
      results.add(scoreCase(c, actual));
    } catch (e) {
      results.add(
        GoldenResult(
          id: c.id,
          passed: false,
          failureReason: 'runner threw: $e',
        ),
      );
    }
  }

  final passed = results.where((r) => r.passed).length;
  final summary = {
    'corpus': corpusLabel ?? corpusPath,
    'total': results.length,
    'passed': passed,
    'failed': results.length - passed,
    'failures': results
        .where((r) => !r.passed)
        .map((r) => {'id': r.id, 'reason': r.failureReason})
        .toList(),
  };
  stdout.writeln(jsonEncode(summary));
  return results;
}
