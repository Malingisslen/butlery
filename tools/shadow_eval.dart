/// CLI: score the parser shadow samples (ADR-0037) — how often the free
/// parser AGREES WITH THE AI on the same input. This is not accuracy: the AI
/// is a reference, not a gold, and a disagreement can be the AI's mistake.
///
/// `dart run tools/shadow_eval.dart <shadow-export.json> [--corrections <corrections.json>]`
///
/// `<shadow-export.json>` is the output of
/// `export-llm-samples.ts --mode shadow`; `--corrections` takes the output of
/// `export-corrections.ts`, which is human ground truth and is reported
/// beside the agreement figures, never mixed into them. Pure file IO.
library;

import 'dart:convert';
import 'dart:io';

import 'corpus/corpus_metrics.dart';
import 'corpus/corpus_models.dart';

/// The one adapter both sides go through, so neither is scored on a
/// different reading of the same recipe. It accepts the AI's
/// `ExtractedRecipe` keys (`amount`, `prepTimeMinutes` + `cookTimeMinutes`)
/// and the parser's GoldRecipe keys (`quantity`, `timeMinutes`).
GoldRecipe shadowGold(Map<String, dynamic> json) {
  String? text(Object? v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }

  int? minutes(Object? v) => v is num ? v.round() : null;

  final total = minutes(json['timeMinutes']);
  final prep = minutes(json['prepTimeMinutes']);
  final cook = minutes(json['cookTimeMinutes']);
  final time =
      total ??
      (prep == null && cook == null ? null : (prep ?? 0) + (cook ?? 0));

  final ingredients = <GoldIngredient>[];
  for (final raw in json['ingredients'] as List? ?? const []) {
    if (raw is! Map) continue;
    final i = raw.cast<String, dynamic>();
    final name = text(i['name']) ?? '';
    final quantity = text(i['quantity'] ?? i['amount']);
    final unit = text(i['unit']);
    final line = text(i['originalLine']) ?? [?quantity, ?unit, name].join(' ');
    ingredients.add(
      GoldIngredient(
        name: name,
        originalLine: line,
        quantity: quantity,
        unit: unit,
        size: text(i['size']),
        preparation: text(i['preparation']),
      ),
    );
  }

  return GoldRecipe(
    verified: false,
    title: text(json['title']) ?? '',
    portions: text(json['portions']),
    timeMinutes: time,
    ingredients: ingredients,
    instructions: [
      for (final s in json['instructions'] as List? ?? const [])
        if (text(s) != null) text(s)!,
    ],
  );
}

/// One shadow row: the AI's answer as the reference, the parser's as the
/// prediction. Null when either side is missing or unreadable — a truncated
/// AI answer is a real case, since capture caps the stored output.
({String channel, String tier, RecipeScore score})? scoreSample(
  Map<String, dynamic> row,
) {
  final output = row['scrubbedOutput'];
  final parser = row['parserOutput'];
  if (output is! String || parser is! Map) return null;
  Object? ai;
  try {
    ai = jsonDecode(output);
  } on FormatException {
    return null;
  }
  if (ai is! Map) return null;
  return (
    channel: row['channel']?.toString() ?? 'unknown',
    tier: row['successfulTier']?.toString() ?? 'unknown',
    score: scoreRecipe(
      shadowGold(ai.cast<String, dynamic>()),
      shadowGold(parser.cast<String, dynamic>()),
    ),
  );
}

class _Bucket {
  int n = 0;
  double names = 0;
  double full = 0;

  void add(RecipeScore s) {
    n++;
    names += s.ingredientNames.f1;
    full += s.ingredientsFull.f1;
  }

  String row(String label) =>
      '| $label | $n | ${_pct(names / n)} | ${_pct(full / n)} |';
}

String _pct(double v) => '${(v * 100).toStringAsFixed(1)} %';

/// The Markdown report: agreement per channel and per channel × tier.
String formatShadowReport(List<Map<String, dynamic>> rows) {
  final byChannel = <String, _Bucket>{};
  final byTier = <String, _Bucket>{};
  var unreadable = 0;
  for (final row in rows) {
    final s = scoreSample(row);
    if (s == null) {
      unreadable++;
      continue;
    }
    byChannel.putIfAbsent(s.channel, _Bucket.new).add(s.score);
    byTier.putIfAbsent('${s.channel} / ${s.tier}', _Bucket.new).add(s.score);
  }

  final out = StringBuffer()
    ..writeln('## Agreement with the AI (not accuracy)')
    ..writeln()
    ..writeln('${rows.length} samples, $unreadable unreadable (skipped).')
    ..writeln()
    ..writeln('| Channel | n | Name F1 | Full F1 |')
    ..writeln('|---|---|---|---|');
  for (final k in byChannel.keys.toList()..sort()) {
    out.writeln(byChannel[k]!.row(k));
  }
  out
    ..writeln()
    ..writeln('| Channel / tier | n | Name F1 | Full F1 |')
    ..writeln('|---|---|---|---|');
  for (final k in byTier.keys.toList()..sort()) {
    out.writeln(byTier[k]!.row(k));
  }
  return out.toString();
}

/// Users' own corrections, counted per tier and type: where people had to
/// fix the parser by hand.
String formatCorrectionsReport(List<Map<String, dynamic>> corrections) {
  final counts = <String, int>{};
  for (final c in corrections) {
    final key =
        '${c['successfulTier'] ?? 'unknown'} / ${c['type'] ?? 'unknown'}';
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final out = StringBuffer()
    ..writeln('## Users\' own corrections (human ground truth)')
    ..writeln()
    ..writeln('${corrections.length} corrected lines.')
    ..writeln()
    ..writeln('| Tier / type | Lines |')
    ..writeln('|---|---|');
  for (final k in counts.keys.toList()..sort()) {
    out.writeln('| $k | ${counts[k]} |');
  }
  return out.toString();
}

List<Map<String, dynamic>> _readRows(String path) => [
  for (final r in jsonDecode(File(path).readAsStringSync()) as List)
    (r as Map).cast<String, dynamic>(),
];

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: dart run tools/shadow_eval.dart <shadow-export.json> '
      '[--corrections <corrections.json>]',
    );
    exitCode = 64;
    return;
  }
  stdout.writeln(formatShadowReport(_readRows(args.first)));
  final c = args.indexOf('--corrections');
  if (c != -1 && c + 1 < args.length) {
    stdout.writeln(formatCorrectionsReport(_readRows(args[c + 1])));
  }
}
