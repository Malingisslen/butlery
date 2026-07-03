// Step 0 GATE for the pooled-ratings plan (tasks/pooled-ratings-plan.md).
//
// Deterministic, no LLM. Computes the PROPOSED v1 ratingPoolKey for known
// same-recipe pairs imported via different methods (URL / OCR / Instagram) and
// reports the exact-match hit-rate per method-pair. The plan gates all
// CF/rules/backfill work on this number: if cross-method (OCR/Instagram <-> URL)
// hit-rate is near zero, normalization must be extended for OCR noise and
// caption junk and re-measured BEFORE building the aggregation backend.
// URL<->URL pooling alone still justifies v1 — but the number is reported
// either way (AC1).
//
// Run: dart run tools/measure_poolkey_hitrate.dart
//
// The poolKey algorithm mirrors ContentFingerprint's normalization
// (lib/services/import/cache/content_fingerprint.dart) with two deliberate
// differences per plan decision 1:
//   - instructionCount is EXCLUDED (a rating belongs to the dish, not to how
//     many steps a given source wrote it up in);
//   - a "v1:" version prefix is baked into the key string.
// This file recomputes the normalization locally (rather than importing the
// private ContentFingerprint methods) so the gate is a self-contained, honest
// measurement of the proposed key. The shared, extracted normalizer
// (recipe_text_normalizer.dart) is a later build step; if its behavior ever
// diverges from what is measured here, this tool must be re-run.
//
// DATA HONESTY: the sample set below is hand-built (real cookbook scans are
// pending per memory/project_cookbook_gold_corpus.md). OCR/Instagram variants
// are modeled on real failure modes (a/a-ring/o-umlaut misreads, l<->1 / O<->0
// confusion, emoji + hashtags + missing amounts) but they are synthetic. Treat
// the cross-method number as an indicative prior, not a production metric — the
// harness is built so the same run against real scans drops in unchanged.

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

// ---------------------------------------------------------------------------
// Proposed v1 poolKey (ContentFingerprint normalization, minus instructionCount)
// ---------------------------------------------------------------------------

const _units = {
  'dl',
  'msk',
  'tsk',
  'krm',
  'g',
  'kg',
  'ml',
  'l',
  'cl',
  'st',
  'stk',
  'port',
  'portion',
  'portioner',
  'nypa',
  'nypor',
  'bit',
  'bitar',
  'skiva',
  'skivor',
  'klyfta',
  'klyftor',
  'kvist',
  'kvistar',
  'blad',
  'paket',
  'burk',
  'burkar',
  'påse',
  'påsar',
  'ask',
  'askar',
};

const _stopWords = {
  'och',
  'med',
  'på',
  'i',
  'till',
  'för',
  'av',
  'en',
  'ett',
  'den',
  'det',
  'de',
  'som',
  'från',
  'and',
  'with',
  'the',
  'a',
  'an',
  'of',
  'for',
  'to',
  'in',
  'on',
  'enkel',
  'enkelt',
  'lätt',
  'snabb',
  'snabbt',
  'god',
  'gott',
  'bästa',
  'klassisk',
  'klassiskt',
  'hemlagad',
  'hemlagat',
  'äkta',
};

final _punctuationRe = RegExp(r'[^\wåäö\s]');
final _multiSpaceRe = RegExp(r'\s+');
final _leadingNumbersRe = RegExp(r'^\s*\d+[\s,./]*\d*\s*');
final _approximateWordsRe = RegExp(
  r'\b(ca|cirka|ungefär|about|approximately)\b',
);
final _parentheticalRe = RegExp(r'\([^)]*\)');
final _allUnitsRe = RegExp('\\b(${_units.join('|')})\\b', caseSensitive: false);

const _poolKeyVersion = 'v1';

List<String> _extractTitleKeywords(String title) {
  final normalized = title
      .toLowerCase()
      .replaceAll(_punctuationRe, ' ')
      .replaceAll(_multiSpaceRe, ' ')
      .trim();
  return normalized
      .split(' ')
      .where((w) => w.length > 2)
      .where((w) => !_stopWords.contains(w))
      .toList();
}

String _normalizeIngredient(String ingredient) {
  var n = ingredient.toLowerCase().trim();
  n = n.replaceAll(_leadingNumbersRe, '');
  n = n.replaceAll(_approximateWordsRe, '');
  n = n.replaceAll(_allUnitsRe, '');
  n = n.replaceAll(_parentheticalRe, '');
  n = n.replaceAll(_multiSpaceRe, ' ').trim();
  return n.length < 2 ? '' : n;
}

/// The proposed v1 pool key. Returns null when there is too little to key on.
String? poolKey({required String title, required List<String> ingredients}) {
  if (title.trim().isEmpty || ingredients.isEmpty) return null;
  final titleKeywords = _extractTitleKeywords(title);
  if (titleKeywords.isEmpty) return null;
  final normalized =
      ingredients
          .map(_normalizeIngredient)
          .where((i) => i.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  if (normalized.isEmpty) return null;
  final raw = [
    titleKeywords.take(3).join('_'),
    normalized.take(10).join('|'),
  ].join(':');
  final hash = sha256.convert(utf8.encode(raw)).toString().substring(0, 16);
  return '$_poolKeyVersion:$hash';
}

// ---------------------------------------------------------------------------
// Strengthened normalization (the plan's "extend for OCR noise + caption junk"
// lever). These are poolKey-ONLY transforms — they must never be folded back
// into ContentFingerprint (that would silently change the live cache dedup key,
// plan decision 3). Measured here to quantify the achievable ceiling before
// any backend is built.
// ---------------------------------------------------------------------------

final _hashtagRe = RegExp(r'#\w+', unicode: true);

/// Fold Swedish diacritics: OCR routinely drops the ring/umlaut, so 'köttbullar'
/// and 'kottbullar' must collapse to the same token. Also normalizes genuine
/// spelling so URL variants agree.
String _foldDiacritics(String s) =>
    s.replaceAll('å', 'a').replaceAll('ä', 'a').replaceAll('ö', 'o');

/// Repair the classic OCR digit/letter confusions INSIDE an alphabetic token
/// (e.g. 'sa1t' -> 'salt', 'freste1se' -> 'frestelse', 'd1' -> 'dl'). Only
/// applied to tokens that already contain letters, so pure quantities ('500')
/// are never corrupted.
String _fixOcrDigits(String token) {
  if (!RegExp(r'[a-zåäö]').hasMatch(token)) return token;
  return token.replaceAll('0', 'o').replaceAll('1', 'l');
}

List<String> _extractTitleKeywordsStrong(String title) {
  final deHashed = title.replaceAll(_hashtagRe, ' ');
  final folded = _foldDiacritics(
    deHashed.toLowerCase(),
  ).replaceAll(_punctuationRe, ' ').replaceAll(_multiSpaceRe, ' ').trim();
  final foldedStops = _stopWords.map(_foldDiacritics).toSet();
  return folded
      .split(' ')
      .map(_fixOcrDigits)
      .where((w) => w.length > 2)
      .where((w) => !foldedStops.contains(w))
      .toList();
}

String _normalizeIngredientStrong(String ingredient) {
  var n = _foldDiacritics(ingredient.toLowerCase().trim());
  n = n.replaceAll(_leadingNumbersRe, '');
  n = n.replaceAll(_approximateWordsRe, '');
  n = n.replaceAll(_allUnitsRe, '');
  n = n.replaceAll(_parentheticalRe, '');
  n = n.replaceAll(_multiSpaceRe, ' ').trim();
  n = n.split(' ').map(_fixOcrDigits).join(' ').trim();
  return n.length < 2 ? '' : n;
}

/// Strengthened key: same title+ingredient STRUCTURE as the proposed key, but
/// with diacritic folding, OCR digit repair, and hashtag stripping.
String? poolKeyStrengthened({
  required String title,
  required List<String> ingredients,
}) {
  if (title.trim().isEmpty || ingredients.isEmpty) return null;
  // No sort here: keep the ONLY differences vs the proposed key the three
  // labelled levers (fold + OCR-fix + hashtag-strip), so the comparison stays
  // apples-to-apples. Word-order independence is a separate lever, not tested.
  final titleKeywords = _extractTitleKeywordsStrong(title);
  if (titleKeywords.isEmpty) return null;
  final normalized =
      ingredients
          .map(_normalizeIngredientStrong)
          .where((i) => i.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  if (normalized.isEmpty) return null;
  final raw = [
    titleKeywords.take(3).join('_'),
    normalized.take(10).join('|'),
  ].join(':');
  final hash = sha256.convert(utf8.encode(raw)).toString().substring(0, 16);
  return 'v1s:$hash';
}

/// Ingredient-dominant key: strengthened normalization, ingredients ONLY (no
/// title in the key). Tests whether the title component is the main fragility.
/// Trades recall UP for precision DOWN (dishes with near-identical ingredient
/// sets — pannkakor vs våfflor — risk a false merge). Reported so the
/// precision/recall tradeoff is visible, NOT proposed for shipping.
String? poolKeyIngredientDominant({
  required String title,
  required List<String> ingredients,
}) {
  if (ingredients.isEmpty) return null;
  final normalized =
      ingredients
          .map(_normalizeIngredientStrong)
          .where((i) => i.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  if (normalized.isEmpty) return null;
  final raw = normalized.take(12).join('|');
  final hash = sha256.convert(utf8.encode(raw)).toString().substring(0, 16);
  return 'v1i:$hash';
}

// ---------------------------------------------------------------------------
// HYBRID key (Malin's decision 2026-07-03): ingredients drive identity, a
// single "dish anchor" from the title acts as a precision guard so two
// genuinely different dishes with the same ingredient set (sockerkaka vs
// muffins) do NOT pool. The anchor is the LONGEST significant title token
// after folding + qualifier removal — in Swedish, dish names are long
// compounds (köttbullar, havregrynsgröt, räksmörgås) while descriptive
// additions (bacon, jul, vatten) are short, so the core noun survives while
// qualifiers (klassiska/gammaldags/tunna...) are stripped. This keeps the key
// a clean exact string (ADR-0004 doc-ID keying holds), no fuzzy infra (that is
// still v2). Validated empirically below before the backend is built.
// ---------------------------------------------------------------------------

/// Descriptive qualifiers that vary between sources but do not change the dish.
/// Superset of the title stopwords, used ONLY for the hybrid dish anchor.
const _dishQualifiers = {
  'gammaldags',
  'tunna',
  'tunn',
  'tunt',
  'mjuk',
  'mjuka',
  'mjukt',
  'kramig',
  'kramiga',
  'saftig',
  'saftiga',
  'nyttig',
  'nyttiga',
  'festlig',
  'festliga',
  'matig',
  'matiga',
  'krispig',
  'krispiga',
  'ugnsbakad',
  'ugnsbakade',
  'grillad',
  'grillade',
  'stekt',
  'stekta',
  'kokt',
  'kokta',
  'perfekt',
  'perfekta',
  'krama',
  'lyxig',
  'lyxiga',
  'billig',
  'billiga',
  'vardaglig',
  'vardagliga',
  'fina',
  'godaste',
  'allra',
};

/// Generic dish-CATEGORY nouns that carry almost no disambiguating power. If the
/// dish anchor reduces to one of these (a bare "Soppa", or an OCR compound-split
/// leaving "bullar" from "köttbullar"), the anchor cannot guard precision, so
/// per the panel (T&S must-have + Data/Integrations OCR-split finding) the recipe
/// FAILS CLOSED: it does not pool rather than risk a silent false merge.
/// Folded (å/ä/ö→a/o) to match the anchor's normalized form.
const _genericAnchors = {
  'soppa',
  'sas',
  'kaka',
  'kakor',
  'bullar',
  'bulle',
  'paj',
  'gryta',
  'grateng',
  'sallad',
  'rora',
  'pytt',
  'lada',
  'form',
  'gratin',
  'mos',
  'stuvning',
  'soppor',
  'ratt',
  'ratter',
  'mat',
  'middag',
  'lunch',
  'frukost',
  'efterratt',
  'dessert',
  'bakelse',
  'tarta',
  'paltbrod',
  'brod',
  'kex',
  // Common Swedish definite-singular forms of the same generics (soppa->soppan).
  'soppan',
  'sasen',
  'kakan',
  'grytan',
  'pajen',
  'salladen',
  'roran',
  'tartan',
  'bakelsen',
  'stuvningen',
  'gratengen',
  'brodet',
  'moset',
};

String? poolKeyHybrid({
  required String title,
  required List<String> ingredients,
}) {
  if (ingredients.isEmpty) return null;
  final normalized =
      ingredients
          .map(_normalizeIngredientStrong)
          .where((i) => i.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  if (normalized.isEmpty) return null;

  // Dish anchor: longest significant title token, qualifiers removed.
  // Tie-break is FIRST-WINS (strict >), pinned so the Dart hint and the TS
  // authority agree — the cross-language golden fixture must cover a tie case.
  final foldedQualifiers = _dishQualifiers.map(_foldDiacritics).toSet();
  final tokens = _extractTitleKeywordsStrong(
    title,
  ).where((w) => !foldedQualifiers.contains(w)).toList();
  var anchor = '';
  for (final t in tokens) {
    if (t.length > anchor.length) anchor = t;
  }

  // Fail closed: no usable anchor (empty OR a generic category noun) => do NOT
  // pool. Silently degrading to ingredient-only here would reintroduce the
  // false-merge risk the anchor exists to prevent (panel: 3/3 must-have).
  if (anchor.isEmpty || _genericAnchors.contains(anchor)) return null;

  final raw = '$anchor::${normalized.take(12).join('|')}';
  final hash = sha256.convert(utf8.encode(raw)).toString().substring(0, 16);
  return 'v1h:$hash';
}

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
  int get crossHits => ocrHits + igHits;
  int get crossTotal => ocrTotal + igTotal;
  double _pct(int h, int t) => t == 0 ? 0 : 100.0 * h / t;
  double get urlPct => _pct(urlHits, urlTotal);
  double get crossPct => _pct(crossHits, crossTotal);
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
  final keyers = <String, Keyer>{
    'proposed  (title+ingredients, exact)': poolKey,
    'strengthened (fold+OCR-fix+#strip)': poolKeyStrengthened,
    'ingredient-dominant (no title)': poolKeyIngredientDominant,
    'HYBRID (ingredients + dish anchor)': poolKeyHybrid,
  };

  stdout.writeln(
    '=== poolKey hit-rate: same recipe -> same key across import methods ===',
  );
  stdout.writeln(
    '    (${_cases.length} recipes, each in URL/OCR/Instagram variants)\n',
  );

  KeyerResult? proposed;
  for (final e in keyers.entries) {
    stdout.writeln('--- ${e.key} ---');
    final res = _evaluate(e.value, verbose: true);
    proposed ??= res;
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
  }

  stdout.writeln('=== GATE VERDICT ===');
  final p = proposed!;
  if (p.crossPct < 20) {
    stdout.writeln(
      '  The PROPOSED exact key (plan decision 1) is too fragile: '
      '${p.urlPct.toStringAsFixed(0)}% URL<->URL, ${p.crossPct.toStringAsFixed(0)}% '
      'cross-method. Per the plan, do NOT build CF/rules/backfill on it as-is.',
    );
    stdout.writeln(
      '  The comparison above quantifies the lever: strengthened '
      'normalization (diacritic folding + OCR digit repair + hashtag strip) '
      'is a pure-normalization change the plan explicitly authorizes; '
      'dropping the title from the key raises recall further but risks '
      'false merges (precision). This is a decision for Malin/panel, not a '
      'unilateral redesign of the approved key.',
    );
  } else {
    stdout.writeln(
      '  Proposed key clears the gate; proceed with v1 as planned.',
    );
  }
  stdout.writeln(
    '\n  NOTE: sample set is synthetic (real scans pending, see '
    'memory/project_cookbook_gold_corpus.md). Re-run unchanged against '
    'corpus scans when available; the harness does not change.',
  );
}

String _label(ImportMethod m) => switch (m) {
  ImportMethod.url => 'URL',
  ImportMethod.ocr => 'OCR',
  ImportMethod.instagram => 'Instagram',
};
