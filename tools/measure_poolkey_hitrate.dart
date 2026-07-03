// Step 0 GATE + ongoing C6/C7 regression harness for the pooled-ratings plan
// (tasks/pooled-ratings-plan.md).
//
// Deterministic, no LLM. Runs the PRODUCTION pool key over known same-recipe
// pairs imported via different methods (URL / OCR / Instagram) and reports the
// exact-match hit-rate per method-pair plus the precision guard (distinct
// recipes must never collide into one pool).
//
// Run: dart run tools/measure_poolkey_hitrate.dart
//
// HISTORY: the Step-0 comparison of four candidate keys (proposed / strengthened
// / ingredient-dominant / hybrid) picked the HYBRID key; that decision is
// recorded in the plan's key-design table and does not need re-running. Per
// condition C5, this tool no longer carries its own copy of the key algorithm
// or its word-lists (that third copy had already drifted — it held an extra
// 'krama' qualifier the production lists never had). It now calls the single
// production implementation, [CanonicalPoolKey.compute] (the Dart hint, twin of
// the TS server authority functions/src/ratings/canonical-pool-key.ts), so the
// number measured here is the number that ships — the requirement C5 states for
// C6: "point the Step-0 tool's HYBRID keyer at CanonicalPoolKey.compute so C6
// measures production, not a stale copy".
//
// DATA HONESTY: the sample set below is hand-built (real cookbook scans are
// pending per memory/project_cookbook_gold_corpus.md). OCR/Instagram variants
// are modeled on real failure modes (a-ring/umlaut misreads, l<->1 / O<->0
// confusion, emoji + hashtags + missing amounts) but they are synthetic. Treat
// the cross-method number as an indicative prior, not a production metric — the
// harness is built so the same run against real scans (C6/C7) drops in
// unchanged: replace [_cases] with the corpus batch and re-run.

import 'dart:io';
import 'package:butlery/services/rating/canonical_pool_key.dart';

// ---------------------------------------------------------------------------
// Sample set: each recipe rendered as it would arrive from several methods.
// ---------------------------------------------------------------------------

enum ImportMethod { url, ocr, instagram }

class RecipeVariant {
  final ImportMethod method;
  final String title;
  final List<String> ingredients;
  const RecipeVariant(this.method, this.title, this.ingredients);
}

class RecipeCase {
  final String name;
  final List<RecipeVariant> variants;
  const RecipeCase(this.name, this.variants);
}

const _cases = <RecipeCase>[
  RecipeCase('Köttbullar', [
    RecipeVariant(ImportMethod.url, 'Köttbullar', [
      '500 g blandfärs',
      '1 gul lök',
      '1 dl ströbröd',
      '1 dl mjölk',
      '1 ägg',
      '2 msk smör',
      'salt och peppar',
    ]),
    // Second blog, same dish, different wording/order/qualifier.
    RecipeVariant(ImportMethod.url, 'Klassiska köttbullar', [
      '1 ägg',
      '500 g blandfärs',
      '2 msk smör',
      '1 dl ströbröd',
      '1 gul lök',
      '1 dl mjölk',
      'salt och peppar',
    ]),
    // OCR: a-ring/umlaut misreads, l<->1, broken spacing.
    RecipeVariant(ImportMethod.ocr, 'Kottbullar', [
      '500 g blandfars',
      '1 gul lok',
      '1 d1 strobrod',
      '1 dl mjolk',
      '1 agg',
      '2 msk smor',
      'salt och peppar',
    ]),
    // Instagram: emoji, hashtags, missing some amounts.
    RecipeVariant(ImportMethod.instagram, 'Köttbullar 🧆 #husmanskost', [
      'blandfärs 500g',
      'gul lök',
      'ströbröd',
      'mjölk',
      'ägg',
      'smör',
      'salt & peppar 🧂',
    ]),
  ]),
  RecipeCase('Kladdkaka', [
    RecipeVariant(ImportMethod.url, 'Kladdkaka', [
      '2 ägg',
      '2,5 dl socker',
      '1,5 dl vetemjöl',
      '4 msk kakao',
      '100 g smör',
      '1 tsk vaniljsocker',
    ]),
    RecipeVariant(ImportMethod.url, 'Enkel kladdkaka', [
      '100 g smör',
      '2 ägg',
      '4 msk kakao',
      '2,5 dl socker',
      '1,5 dl vetemjöl',
      '1 tsk vaniljsocker',
    ]),
    RecipeVariant(ImportMethod.ocr, 'Kladdkaka', [
      '2 agg',
      '2,5 dl socker',
      '1,5 dl vetemjol',
      '4 msk kakao',
      '1OO g smor',
      '1 tsk vaniljsocker',
    ]),
    RecipeVariant(ImportMethod.instagram, 'KLADDKAKA 🍫🍫 #fika', [
      'ägg',
      'socker',
      'vetemjöl',
      'kakao',
      'smör',
      'vaniljsocker',
    ]),
  ]),
  RecipeCase('Pannkakor', [
    RecipeVariant(ImportMethod.url, 'Pannkakor', [
      '3 dl vetemjöl',
      '6 dl mjölk',
      '3 ägg',
      '0,5 tsk salt',
      '2 msk smör',
    ]),
    RecipeVariant(ImportMethod.url, 'Tunna pannkakor', [
      '3 ägg',
      '6 dl mjölk',
      '3 dl vetemjöl',
      '2 msk smör',
      '0,5 tsk salt',
    ]),
    RecipeVariant(ImportMethod.ocr, 'Pannkakor', [
      '3 dl vetemjol',
      '6 dl mjolk',
      '3 agg',
      '0,5 tsk sa1t',
      '2 msk smor',
    ]),
    RecipeVariant(ImportMethod.instagram, 'Pannkakor 🥞 #fredagsmys', [
      'vetemjöl',
      'mjölk',
      'ägg',
      'salt',
      'smör',
    ]),
  ]),
  RecipeCase('Flygande Jakob', [
    RecipeVariant(ImportMethod.url, 'Flygande Jakob', [
      '800 g kycklingfilé',
      '2 dl grädde',
      '2 msk chilisås',
      '1 banan',
      '2 dl jordnötter',
      '3 skivor bacon',
      'salt och peppar',
    ]),
    RecipeVariant(ImportMethod.url, 'Flygande jakob med bacon', [
      '2 dl grädde',
      '800 g kycklingfilé',
      '1 banan',
      '2 msk chilisås',
      '3 skivor bacon',
      '2 dl jordnötter',
      'salt och peppar',
    ]),
    RecipeVariant(ImportMethod.ocr, 'Flygande Jakob', [
      '8OO g kycklingfile',
      '2 dl gradde',
      '2 msk chilisas',
      '1 banan',
      '2 dl jordnotter',
      '3 skivor bacon',
      'salt och peppar',
    ]),
    RecipeVariant(ImportMethod.instagram, 'Flygande Jakob 🍗🍌 #70talsmat', [
      'kycklingfilé',
      'grädde',
      'chilisås',
      'banan',
      'jordnötter',
      'bacon',
    ]),
  ]),
  RecipeCase('Ärtsoppa', [
    RecipeVariant(ImportMethod.url, 'Ärtsoppa', [
      '500 g gula ärter',
      '1 gul lök',
      '1 morot',
      '2 tsk timjan',
      '400 g fläsk',
      'salt',
    ]),
    RecipeVariant(ImportMethod.url, 'Gammaldags ärtsoppa', [
      '1 morot',
      '500 g gula ärter',
      '400 g fläsk',
      '1 gul lök',
      '2 tsk timjan',
      'salt',
    ]),
    RecipeVariant(ImportMethod.ocr, 'Artsoppa', [
      '500 g gula arter',
      '1 gul lok',
      '1 morot',
      '2 tsk timjan',
      '4OO g flask',
      'salt',
    ]),
    RecipeVariant(ImportMethod.instagram, 'Ärtsoppa 🟡🥣 #torsdag', [
      'gula ärter',
      'gul lök',
      'morot',
      'timjan',
      'fläsk',
      'salt',
    ]),
  ]),
  RecipeCase('Räksmörgås', [
    RecipeVariant(ImportMethod.url, 'Räksmörgås', [
      '200 g räkor',
      '2 skivor bröd',
      '1 ägg',
      '2 msk majonnäs',
      '1 blad sallad',
      '1 citron',
    ]),
    RecipeVariant(ImportMethod.url, 'Klassisk räksmörgås', [
      '2 msk majonnäs',
      '200 g räkor',
      '1 citron',
      '2 skivor bröd',
      '1 ägg',
      '1 blad sallad',
    ]),
    RecipeVariant(ImportMethod.ocr, 'Raksmorgas', [
      '2OO g rakor',
      '2 skivor brod',
      '1 agg',
      '2 msk majonnas',
      '1 blad sallad',
      '1 citron',
    ]),
    RecipeVariant(ImportMethod.instagram, 'Räksmörgås 🦐🍋 #lyxlunch', [
      'räkor',
      'bröd',
      'ägg',
      'majonnäs',
      'sallad',
      'citron',
    ]),
  ]),
  RecipeCase('Janssons frestelse', [
    RecipeVariant(ImportMethod.url, 'Janssons frestelse', [
      '8 potatisar',
      '2 gul lök',
      '2 burkar ansjovis',
      '3 dl grädde',
      '2 msk smör',
      'ströbröd',
    ]),
    RecipeVariant(ImportMethod.url, 'Janssons frestelse till jul', [
      '3 dl grädde',
      '8 potatisar',
      'ströbröd',
      '2 gul lök',
      '2 burkar ansjovis',
      '2 msk smör',
    ]),
    RecipeVariant(ImportMethod.ocr, 'Janssons freste1se', [
      '8 potatisar',
      '2 gul lok',
      '2 burkar ansjovis',
      '3 dl gradde',
      '2 msk smor',
      'strobrod',
    ]),
    RecipeVariant(ImportMethod.instagram, 'Janssons frestelse 🥔 #julbord', [
      'potatis',
      'gul lök',
      'ansjovis',
      'grädde',
      'smör',
      'ströbröd',
    ]),
  ]),
  RecipeCase('Havregrynsgröt', [
    RecipeVariant(ImportMethod.url, 'Havregrynsgröt', [
      '1 dl havregryn',
      '2,5 dl vatten',
      '1 nypa salt',
    ]),
    RecipeVariant(ImportMethod.url, 'Havregrynsgröt på vatten', [
      '2,5 dl vatten',
      '1 dl havregryn',
      '1 nypa salt',
    ]),
    RecipeVariant(ImportMethod.ocr, 'Havregrynsgrot', [
      '1 dl havregryn',
      '2,5 dl vatten',
      '1 nypa sa1t',
    ]),
    RecipeVariant(ImportMethod.instagram, 'Havregrynsgröt 🥣 #frukost', [
      'havregryn',
      'vatten',
      'salt',
    ]),
  ]),
  // Adversarial precision pair: two DIFFERENT dishes with an identical
  // normalized ingredient set. An ingredient-only key MUST merge them (wrong);
  // a title-bearing key MUST keep them apart. This is what makes the
  // "false merges" column falsifiable — without it, 0 is untested (per review).
  RecipeCase('Sockerkaka', [
    RecipeVariant(ImportMethod.url, 'Sockerkaka', [
      '3 ägg',
      '3 dl socker',
      '3 dl vetemjöl',
      '100 g smör',
      '2 tsk bakpulver',
    ]),
  ]),
  RecipeCase('Muffins', [
    RecipeVariant(ImportMethod.url, 'Muffins', [
      '3 ägg',
      '3 dl socker',
      '3 dl vetemjöl',
      '100 g smör',
      '2 tsk bakpulver',
    ]),
  ]),
  // Generic-anchor precision pair (panel must-have): two different soups with an
  // identical base but bare generic titles. Under ingredient-only they merge;
  // under the hybrid they must FAIL CLOSED (generic anchor -> null -> no pool),
  // so they neither pool wrongly nor count as a false merge.
  RecipeCase('Soppa A (generic title)', [
    RecipeVariant(ImportMethod.url, 'Soppa', [
      '1 gul lök',
      '2 morötter',
      '1 l buljong',
      'salt',
    ]),
  ]),
  RecipeCase('Soppa B (generic title)', [
    RecipeVariant(ImportMethod.url, 'Soppan', [
      '1 gul lök',
      '2 morötter',
      '1 l buljong',
      'salt',
    ]),
  ]),
];

// ---------------------------------------------------------------------------
// Measurement
// ---------------------------------------------------------------------------

typedef Keyer =
    String? Function({
      required String title,
      required List<String> ingredients,
    });

class KeyerResult {
  int urlHits = 0, urlTotal = 0, falseMerges = 0, excluded = 0;
  int ocrHits = 0, ocrTotal = 0, igHits = 0, igTotal = 0;
  double _pct(int h, int t) => t == 0 ? 0 : 100.0 * h / t;
  double get urlPct => _pct(urlHits, urlTotal);
  double get ocrPct => _pct(ocrHits, ocrTotal);
  double get igPct => _pct(igHits, igTotal);
}

/// Run one keyer over the whole sample set. Recall = same recipe -> same key.
/// Precision guard = different recipes must NOT collide (false merge).
KeyerResult _evaluate(Keyer key, {bool verbose = false}) {
  final r = KeyerResult();
  final refKeyByCase = <String, String?>{};

  for (final rc in _cases) {
    final keyed = rc.variants
        .map(
          (v) => (
            v.method,
            v.title,
            key(title: v.title, ingredients: v.ingredients),
          ),
        )
        .toList();
    final refIndex = keyed.indexWhere((e) => e.$1 == ImportMethod.url);
    final ref = refIndex >= 0 ? keyed[refIndex] : keyed.first;
    final refI = refIndex >= 0 ? refIndex : 0;
    refKeyByCase[rc.name] = ref.$3;
    // A null reference key = intentionally excluded from pooling (fail-closed
    // guard), not a recall failure — count it separately so it does not distort
    // the hit-rate denominators.
    if (ref.$3 == null) r.excluded++;

    for (var i = 0; i < keyed.length; i++) {
      if (i == refI) continue;
      final e = keyed[i];
      final hit = e.$3 != null && ref.$3 != null && e.$3 == ref.$3;
      switch (e.$1) {
        case ImportMethod.url:
          r.urlTotal++;
          if (hit) r.urlHits++;
        case ImportMethod.ocr:
          r.ocrTotal++;
          if (hit) r.ocrHits++;
        case ImportMethod.instagram:
          r.igTotal++;
          if (hit) r.igHits++;
      }
      if (verbose && !hit) {
        stdout.writeln('  [MISS] ${rc.name}: "${e.$2}" (${_label(e.$1)})');
      }
    }
  }

  // Precision guard: every DISTINCT recipe's reference key must be unique.
  final seen = <String, String>{};
  for (final entry in refKeyByCase.entries) {
    final k = entry.value;
    if (k == null) continue;
    if (seen.containsKey(k)) {
      r.falseMerges++;
      stdout.writeln(
        '  [FALSE-MERGE] "${entry.key}" collides with "${seen[k]}" ($k)',
      );
    } else {
      seen[k] = entry.key;
    }
  }
  return r;
}

void main(List<String> args) {
  stdout.writeln(
    '=== poolKey hit-rate: same recipe -> same key across import methods ===',
  );
  stdout.writeln(
    '    (${_cases.length} recipes, each in URL/OCR/Instagram variants)',
  );
  stdout.writeln(
    '    keyer = production CanonicalPoolKey.compute (v1 HYBRID, C5-wired)\n',
  );

  final res = _evaluate(CanonicalPoolKey.compute, verbose: true);
  stdout.writeln(
    '  URL<->URL     : ${res.urlHits}/${res.urlTotal} '
    '(${res.urlPct.toStringAsFixed(0)}%)',
  );
  stdout.writeln(
    '  URL<->OCR     : ${res.ocrHits}/${res.ocrTotal} '
    '(${res.ocrPct.toStringAsFixed(0)}%)  <- normalization-fixable (v1 scope)',
  );
  stdout.writeln(
    '  URL<->Instagr : ${res.igHits}/${res.igTotal} '
    '(${res.igPct.toStringAsFixed(0)}%)  <- caption content loss (v2 fuzzy)',
  );
  stdout.writeln(
    '  false merges  : ${res.falseMerges} '
    '(distinct recipes wrongly pooled — precision cost)',
  );
  stdout.writeln(
    '  excluded      : ${res.excluded} '
    '(no usable dish anchor — fail-closed, not a recall miss)\n',
  );

  stdout.writeln('=== GATE VERDICT ===');
  if (res.falseMerges > 0) {
    stdout.writeln(
      '  STOP: ${res.falseMerges} false merge(s) — distinct recipes pooled '
      'together. The precision guard failed; do NOT run the backfill (C6/C8).',
    );
  } else if (res.urlPct >= 90) {
    stdout.writeln(
      '  Production HYBRID key clears the gate on this sample: '
      '${res.urlPct.toStringAsFixed(0)}% URL<->URL recall, 0 false merges. '
      'Cross-method recall is the documented v1 ceiling (OCR = v1-fixable '
      'normalization; Instagram = v2 fuzzy). Proceed with v1 as planned.',
    );
  } else {
    stdout.writeln(
      '  URL<->URL recall is only ${res.urlPct.toStringAsFixed(0)}% — below the '
      'expected floor for the production key. Investigate before building on it.',
    );
  }
  stdout.writeln(
    '\n  NOTE: sample set is synthetic (real scans pending, see '
    'memory/project_cookbook_gold_corpus.md). C6/C7: replace _cases with a real '
    'corpus batch (>=20-30 scans) and re-run — the harness does not change.',
  );
}

String _label(ImportMethod m) => switch (m) {
  ImportMethod.url => 'URL',
  ImportMethod.ocr => 'OCR',
  ImportMethod.instagram => 'Instagram',
};
