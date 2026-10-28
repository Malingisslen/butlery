/// Pure scoring for the import gate (BUT-2236): gold model, line matching,
/// metrics, floor checks and the Markdown table the CI log prints.
///
/// No Flutter, no I/O beyond reading the gold files, so the scoring rules can
/// be read and tested without running a parser.
library;

import 'dart:convert';
import 'dart:io';

/// One expected ingredient. [key] is the word that must survive into some
/// imported ingredient line; [allergen] marks a line whose loss would make the
/// recipe "free from" something it contains.
class GoldIngredient {
  final String key;
  final String? allergen;
  const GoldIngredient(this.key, this.allergen);

  factory GoldIngredient.fromJson(Map<String, dynamic> j) =>
      GoldIngredient(j['key'] as String, j['allergen'] as String?);
}

class GoldRecipe {
  final String id;
  final String title;
  final int steps;

  /// A phrase from the last real step. A recipe-end rule that cuts too early
  /// loses it, which the step count alone cannot show.
  final String? lastStepKey;
  final int? portions;
  final int? timeMinutes;
  final List<GoldIngredient> ingredients;
  final List<String> headings;

  const GoldRecipe({
    required this.id,
    required this.title,
    required this.steps,
    required this.ingredients,
    required this.headings,
    this.lastStepKey,
    this.portions,
    this.timeMinutes,
  });

  factory GoldRecipe.fromJson(String id, Map<String, dynamic> j) => GoldRecipe(
    id: id,
    title: j['title'] as String,
    steps: j['steps'] as int,
    lastStepKey: j['lastStepKey'] as String?,
    portions: j['portions'] as int?,
    timeMinutes: j['timeMinutes'] as int?,
    ingredients: [
      for (final i in j['ingredients'] as List)
        GoldIngredient.fromJson(i as Map<String, dynamic>),
    ],
    headings: [for (final h in j['headings'] as List? ?? const []) h as String],
  );
}

/// What one import produced, reduced to what the gate scores.
class Produced {
  final String? title;
  final List<String> ingredientLines;
  final List<String> stepLines;
  final int? portions;
  final int? timeMinutes;
  final int llmCalls;
  final String? failure;

  const Produced({
    required this.title,
    required this.ingredientLines,
    required this.stepLines,
    required this.llmCalls,
    this.portions,
    this.timeMinutes,
    this.failure,
  });

  int get steps => stepLines.length;
}

/// Block markers that are never ingredients whatever the recipe, on top of
/// each gold file's own headings.
const _genericHeadings = {
  'ingredienser',
  'ingrediens',
  'du behöver',
  'gör så här',
  'så gör du',
  'så här gör du',
  'instruktioner',
  'tillagning',
  'till servering',
  'tillbehör',
};

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9åäöéü ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class RecipeScore {
  final GoldRecipe gold;
  final Produced produced;
  final List<GoldIngredient> dropped;
  final List<String> headingLeaks;

  /// Produced ingredient lines no gold line claimed: page junk, headings, or a
  /// real line the gold keys do not name.
  final int extraIngredients;

  RecipeScore(
    this.gold,
    this.produced,
    this.dropped,
    this.headingLeaks,
    this.extraIngredients,
  );

  int get kept => gold.ingredients.length - dropped.length;

  /// Steps are gold-counted, not gold-listed, so only the surplus is visible.
  int get extraSteps =>
      produced.steps > gold.steps ? produced.steps - gold.steps : 0;
  bool? get lastStepKept {
    final key = gold.lastStepKey;
    if (key == null) return null;
    return produced.stepLines.any((s) => _norm(s).contains(_norm(key)));
  }

  bool get titleExact => _norm(produced.title ?? '') == _norm(gold.title);
  bool get stepsExact => produced.steps == gold.steps;
  bool? get portionsExact =>
      gold.portions == null ? null : produced.portions == gold.portions;
  bool? get timeExact => gold.timeMinutes == null
      ? null
      : produced.timeMinutes == gold.timeMinutes;
  List<GoldIngredient> get droppedAllergens => [
    for (final d in dropped)
      if (d.allergen != null) d,
  ];
}

/// Greedy one-to-one match, longest key first so "ägg" cannot claim the
/// "äggnudlar" line before the key "äggnudlar" has had its turn.
RecipeScore scoreRecipe(GoldRecipe gold, Produced produced) {
  final lines = [for (final l in produced.ingredientLines) _norm(l)];
  final used = List<bool>.filled(lines.length, false);
  final order = [...gold.ingredients]
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  final dropped = <GoldIngredient>[];
  for (final g in order) {
    final key = _norm(g.key);
    var hit = -1;
    for (var i = 0; i < lines.length; i++) {
      if (!used[i] && lines[i].contains(key)) {
        hit = i;
        break;
      }
    }
    if (hit < 0) {
      dropped.add(g);
    } else {
      used[hit] = true;
    }
  }
  final headingSet = {
    ..._genericHeadings,
    for (final h in gold.headings) _norm(h),
  };
  final leaks = [
    for (final l in produced.ingredientLines)
      if (headingSet.contains(_norm(l))) l,
  ];
  return RecipeScore(
    gold,
    produced,
    dropped,
    leaks,
    used.where((u) => !u).length,
  );
}

/// Aggregate over one corpus.
class CorpusScore {
  final String name;
  final List<RecipeScore> recipes;
  CorpusScore(this.name, this.recipes);

  int get goldLines => recipes.fold(0, (n, r) => n + r.gold.ingredients.length);
  int get keptLines => recipes.fold(0, (n, r) => n + r.kept);
  double get recall => goldLines == 0 ? 1 : keptLines / goldLines;
  int get headingLeaks => recipes.fold(0, (n, r) => n + r.headingLeaks.length);
  int get titleExact => recipes.where((r) => r.titleExact).length;
  int get stepsExact => recipes.where((r) => r.stepsExact).length;
  int get portionsExact => recipes.where((r) => r.portionsExact == true).length;
  int get timeExact => recipes.where((r) => r.timeExact == true).length;
  int get failures => recipes.where((r) => r.produced.failure != null).length;
  int get extraIngredients => recipes.fold(0, (n, r) => n + r.extraIngredients);
  int get extraSteps => recipes.fold(0, (n, r) => n + r.extraSteps);
  List<RecipeScore> get lastStepLost => [
    for (final r in recipes)
      if (r.lastStepKept == false) r,
  ];
  int get llmCalls => recipes.fold(0, (n, r) => n + r.produced.llmCalls);
  int get maxLlmCallsPerImport => recipes.fold(
    0,
    (m, r) => r.produced.llmCalls > m ? r.produced.llmCalls : m,
  );

  List<({String id, GoldIngredient line})> get droppedAllergens => [
    for (final r in recipes)
      for (final d in r.droppedAllergens) (id: r.gold.id, line: d),
  ];
}

/// A dropped allergen line the gate already knows about, owned by a named fix.
class KnownRed {
  final String fixture;
  final String key;
  final String reason;
  const KnownRed(this.fixture, this.key, this.reason);

  factory KnownRed.fromJson(Map<String, dynamic> j) => KnownRed(
    j['fixture'] as String,
    j['key'] as String,
    j['reason'] as String,
  );
}

class Floors {
  final Map<String, Map<String, num>> corpora;
  final List<KnownRed> knownRed;
  const Floors(this.corpora, this.knownRed);

  static Floors read(File f) {
    final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final corpora = <String, Map<String, num>>{};
    for (final e in (j['corpora'] as Map<String, dynamic>).entries) {
      corpora[e.key] = (e.value as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as num),
      );
    }
    return Floors(corpora, [
      for (final k in j['knownRed'] as List)
        KnownRed.fromJson(k as Map<String, dynamic>),
    ]);
  }
}

/// Every way a corpus can fail the gate, in Swedish for the job log.
List<String> checkFloors(
  CorpusScore c,
  Floors floors, {
  required int networkCalls,
}) {
  final problems = <String>[];
  final f = floors.corpora[c.name];
  if (f == null) return ['${c.name}: golv saknas i floors.json'];

  void atLeast(String metric, num measured) {
    final floor = f[metric];
    if (floor == null) {
      problems.add('${c.name}: golvet "$metric" saknas i floors.json');
    } else if (measured < floor - 1e-9) {
      problems.add('${c.name}: $metric sjönk till $measured (golv $floor)');
    }
  }

  void atMost(String metric, num measured) {
    final ceiling = f[metric];
    if (ceiling == null) {
      problems.add('${c.name}: taket "$metric" saknas i floors.json');
    } else if (measured > ceiling) {
      problems.add('${c.name}: $metric steg till $measured (tak $ceiling)');
    }
  }

  atLeast('recall', double.parse(c.recall.toStringAsFixed(4)));
  atMost('headingLeaks', c.headingLeaks);
  atLeast('titleExact', c.titleExact);
  atLeast('stepsExact', c.stepsExact);
  atLeast('portionsExact', c.portionsExact);
  atLeast('timeExact', c.timeExact);
  atMost('failures', c.failures);
  atMost('extraIngredients', c.extraIngredients);
  atMost('extraSteps', c.extraSteps);
  for (final r in c.lastStepLost) {
    problems.add(
      '${c.name}/${r.gold.id}: sista steget ("${r.gold.lastStepKey}") '
      'saknas. Receptets slut har kapats för tidigt.',
    );
  }

  if (c.maxLlmCallsPerImport > 1) {
    problems.add(
      '${c.name}: en import gjorde ${c.maxLlmCallsPerImport} AI-anrop (tak 1)',
    );
  }
  if (c.llmCalls > 0) {
    problems.add(
      '${c.name}: ${c.llmCalls} AI-anrop över samlingen (snittet ska vara 0)',
    );
  }
  if (networkCalls > 0) {
    problems.add('$networkCalls nätanrop under körningen (ska vara 0)');
  }

  final known = {
    for (final k in floors.knownRed) '${k.fixture}|${k.key}',
  };
  final droppedNow = <String>{};
  for (final d in c.droppedAllergens) {
    final id = '${c.name}/${d.id}|${d.line.key}';
    droppedNow.add(id);
    if (!known.contains(id)) {
      problems.add(
        '${c.name}/${d.id}: raden "${d.line.key}" (${d.line.allergen}) '
        'tappades. Tappade allergenrader ska vara noll.',
      );
    }
  }
  for (final k in floors.knownRed) {
    if (!k.fixture.startsWith('${c.name}/')) continue;
    if (!droppedNow.contains('${k.fixture}|${k.key}')) {
      problems.add(
        '${k.fixture}: "${k.key}" kommer nu med. Ta bort raden ur knownRed '
        'i floors.json och höj golven, så att rättningen inte kan gå förlorad.',
      );
    }
  }
  return problems;
}

/// The Markdown table for the job log and the step summary.
String formatReport(
  List<CorpusScore> corpora,
  Floors floors,
  int networkCalls,
) {
  final b = StringBuffer()
    ..writeln('## Importgrinden (BUT-2236)')
    ..writeln()
    ..writeln('| Mått | ${corpora.map((c) => c.name).join(' | ')} |')
    ..writeln('|---|${corpora.map((_) => '---').join('|')}|');
  void row(String label, String Function(CorpusScore) cell) =>
      b.writeln('| $label | ${corpora.map(cell).join(' | ')} |');
  String pct(double v) => '${(v * 100).toStringAsFixed(1)} %';
  String floor(CorpusScore c, String m) {
    final v = floors.corpora[c.name]?[m];
    return v == null ? '' : ' (golv $v)';
  }

  row('Recept', (c) => '${c.recipes.length}');
  row(
    'Ingrediensrader som kom med',
    (c) =>
        '${c.keptLines}/${c.goldLines} = ${pct(c.recall)}${floor(c, 'recall')}',
  );
  row('Tappade allergenrader', (c) {
    final known = floors.knownRed
        .where((k) => k.fixture.startsWith('${c.name}/'))
        .length;
    return '${c.droppedAllergens.length} (varav känt rött: $known)';
  });
  row(
    'Rubriker i ingredienslistan',
    (c) => '${c.headingLeaks}${floor(c, 'headingLeaks')}',
  );
  row('Titel exakt rätt', (c) => '${c.titleExact}${floor(c, 'titleExact')}');
  row('Antal steg rätt', (c) => '${c.stepsExact}${floor(c, 'stepsExact')}');
  row(
    'Portioner rätt',
    (c) => '${c.portionsExact}${floor(c, 'portionsExact')}',
  );
  row('Tid rätt', (c) => '${c.timeExact}${floor(c, 'timeExact')}');
  row('Misslyckade importer', (c) => '${c.failures}${floor(c, 'failures')}');
  row(
    'Extra ingrediensrader (skräp)',
    (c) => '${c.extraIngredients}${floor(c, 'extraIngredients')}',
  );
  row(
    'Extra steg (skräp)',
    (c) => '${c.extraSteps}${floor(c, 'extraSteps')}',
  );
  row('Sista steget saknas', (c) => '${c.lastStepLost.length}');
  row(
    'AI-anrop (totalt / högst per import)',
    (c) => '${c.llmCalls} / ${c.maxLlmCallsPerImport}',
  );
  b
    ..writeln()
    ..writeln('Nätanrop under körningen: $networkCalls');

  final red = floors.knownRed;
  if (red.isNotEmpty) {
    b
      ..writeln()
      ..writeln('### Känt rött (räknas, är inte överhoppat)')
      ..writeln();
    for (final k in red) {
      b.writeln('- ${k.fixture}: "${k.key}". ${k.reason}');
    }
  }

  b
    ..writeln()
    ..writeln('### Per recept')
    ..writeln();
  for (final c in corpora) {
    for (final r in c.recipes) {
      final notes = <String>[
        if (r.produced.failure != null) 'misslyckades: ${r.produced.failure}',
        if (r.dropped.isNotEmpty)
          'tappade: ${r.dropped.map((d) => d.key).join(', ')}',
        if (r.headingLeaks.isNotEmpty)
          'rubriker som ingredienser: ${r.headingLeaks.join(', ')}',
        if (!r.titleExact) 'titel: "${r.produced.title}"',
        if (!r.stepsExact) 'steg: ${r.produced.steps} av ${r.gold.steps}',
        if (r.extraIngredients > 0)
          'extra ingrediensrader: ${r.extraIngredients}',
        if (r.lastStepKept == false) 'sista steget saknas',
      ];
      if (notes.isEmpty) continue;
      b.writeln('- ${c.name}/${r.gold.id}: ${notes.join('; ')}');
    }
  }
  return b.toString();
}
