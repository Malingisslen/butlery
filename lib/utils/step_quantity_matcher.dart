/// BUT-1601: finds where a cooking step names an ingredient, so cooking mode
/// can show that ingredient's (scaled) amount right after the word —
/// "tärna tomaterna (4)" — without the cook glancing back at the list.
///
/// Deterministic on purpose (cost principle, no LLM). A wrong amount in a
/// step is worse than none, so every doubt resolves to "mark nothing".
library;

import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/utils/text/ingredient_parser.dart';
import 'package:butlery/utils/text/unit_definitions.dart';

/// One ingredient mention in a step: [start]..[end] is the word as written
/// in the step, [label] the amount to show after it ("2 dl", "4").
class StepQuantityMark {
  final int start;
  final int end;
  final String label;

  const StepQuantityMark({
    required this.start,
    required this.end,
    required this.label,
  });

  @override
  bool operator ==(Object other) =>
      other is StepQuantityMark &&
      other.start == start &&
      other.end == end &&
      other.label == label;

  @override
  int get hashCode => Object.hash(start, end, label);

  @override
  String toString() => 'StepQuantityMark($start, $end, $label)';
}

class StepQuantityMatcher {
  StepQuantityMatcher._();

  // Dart's `\b` is ASCII-only, so å/ä/ö would count as boundaries.
  static final RegExp _word = RegExp(
    r'(?<![a-zåäöéü0-9])[a-zåäöéü]+(?![a-zåäöéü0-9])',
    caseSensitive: false,
  );

  // Longest first so "tomaterna" loses "erna", not just "na".
  static const List<String> _suffixes = [
    'arna',
    'erna',
    'orna',
    'na',
    'en',
    'et',
    'ar',
    'er',
    'or',
    'e',
  ];

  static const int _minStem = 3;

  // A mention after one of these is a part of the ingredient, so the
  // full amount would be wrong there.
  static const Set<String> _partitives = {
    'hälften',
    'halva',
    'halvan',
    'halv',
    'halvt',
    'resten',
    'resterande',
    'återstående',
    'övriga',
    'lite',
    'del',
    'delen',
    'delar',
    'ytterligare',
    'mer',
    'mera',
    'extra',
    'par',
    'klick',
    'nypa',
    'två',
    'tre',
    'fyra',
    'fem',
    'sex',
    'sju',
    'åtta',
    'nio',
    'tio',
  };

  static const Set<String> _conjunctions = {'och', 'eller'};

  static final RegExp _leadingQuantity = RegExp(
    r'^\s*('
    r'(?:\d+(?:[.,]\d+)?(?:\s*/\s*\d+)?(?:\s+(?:[½¼¾⅓⅔]|\d+/\d+))?|[½¼¾⅓⅔])'
    r'(?:\s*[-–—]\s*(?:\d+(?:[.,]\d+)?|[½¼¾⅓⅔]))?'
    r')(?=\s|$)',
  );

  /// Marks for every step. [ingredients] and [displayLines] are index-aligned
  /// (the scaled lines the ingredient list shows); on a length mismatch
  /// nothing is marked.
  static List<List<StepQuantityMark>> matchAll(
    List<String> steps,
    List<RecipeIngredient> ingredients,
    List<String> displayLines,
  ) {
    if (ingredients.length != displayLines.length) {
      return [for (final _ in steps) const <StepQuantityMark>[]];
    }
    final targets = <_Target>[
      for (var i = 0; i < ingredients.length; i++)
        ?_Target.from(i, ingredients[i], displayLines[i]),
    ];
    return [for (final step in steps) _matchStep(step, targets)];
  }

  static List<StepQuantityMark> _matchStep(String step, List<_Target> targets) {
    if (targets.isEmpty) return const [];
    final marks = <StepQuantityMark>[];
    final marked = <int>{};
    final words = _word.allMatches(step).toList();
    for (var w = 0; w < words.length; w++) {
      final word = words[w];
      final stems = stemsOf(word[0]!.toLowerCase());
      final hits = targets
          .where((t) => t.stems.any(stems.contains))
          .toList(growable: false);
      // Two ingredients answering to the same word: we can't know which.
      if (hits.length != 1) continue;
      final target = hits.single;
      if (target.label == null || !marked.add(target.index)) continue;
      if (_followsAmount(step, words, w) || _forServing(words, w)) continue;
      marks.add(
        StepQuantityMark(
          start: word.start,
          end: word.end,
          label: target.label!,
        ),
      );
    }
    return marks;
  }

  /// The step already states an amount ("2 dl grädden") or names a part of
  /// the ingredient ("hälften av löken").
  static bool _followsAmount(String step, List<RegExpMatch> words, int w) {
    // A numeral is not a word to _word, so "2 stora tomater" and "2 msk av
    // smöret" are found by scanning the text up to three words back.
    final windowStart = w >= 3 ? words[w - 3].start : 0;
    final window = step.substring(windowStart, words[w].start);
    final sentence = window.substring(
      window.lastIndexOf(RegExp(r'[.;!?:]')) + 1,
    );
    if (RegExp(r'[0-9½¼¾⅓⅔]').hasMatch(sentence)) return true;
    for (var back = 1; back <= 3 && w - back >= 0; back++) {
      final prev = words[w - back][0]!.toLowerCase();
      if (_partitives.contains(prev)) return true;
      if (back == 1 && UnitDefinitions.isKnownUnit(prev)) return true;
    }
    return false;
  }

  /// "persiljan till servering" is a garnish share, not the whole amount.
  static bool _forServing(List<RegExpMatch> words, int w) =>
      w + 2 < words.length &&
      words[w + 1][0]!.toLowerCase() == 'till' &&
      words[w + 2][0]!.toLowerCase() == 'servering';

  /// The word itself plus each form left after stripping one Swedish
  /// plural/definite ending, keeping only stems of at least [_minStem]
  /// letters. Public for tests.
  static Set<String> stemsOf(String word) {
    final stems = <String>{word};
    for (final suffix in _suffixes) {
      if (word.endsWith(suffix) && word.length - suffix.length >= _minStem) {
        stems.add(word.substring(0, word.length - suffix.length));
      }
    }
    // Definite singular of an -a noun: "oljan" is "olja" plus "n".
    if (word.endsWith('an') && word.length - 1 > _minStem) {
      stems.add(word.substring(0, word.length - 1));
    }
    return stems;
  }

  /// The amount as the ingredient list shows it: the leading quantity, plus
  /// the next word when it is a known unit. Null when the line opens with no
  /// number ("salt och peppar", "en nypa salt"). Public for tests.
  static String? labelFor(String displayLine) {
    final match = _leadingQuantity.firstMatch(displayLine);
    if (match == null) return null;
    final quantity = match[1]!.replaceAll(RegExp(r'\s+'), ' ');
    final rest = displayLine.substring(match.end).trimLeft();
    final next = rest.split(RegExp(r'\s+')).first.replaceAll(',', '');
    if (next.isNotEmpty && UnitDefinitions.isKnownUnit(next)) {
      return '$quantity $next';
    }
    return quantity;
  }
}

class _Target {
  final int index;
  final Set<String> stems;
  final String? label;

  const _Target(this.index, this.stems, this.label);

  static _Target? from(int index, RecipeIngredient entry, String displayLine) {
    final name = entry.isStructured
        ? entry.name
        : IngredientParser.parseIngredient(entry.raw).name;
    final words = StepQuantityMatcher._word
        .allMatches(name.toLowerCase())
        .map((m) => m[0]!)
        .toList();
    // "salt och peppar" and "salt, peppar" are two ingredients on one line;
    // the amount belongs to neither word alone.
    if (words.isEmpty ||
        words.any(StepQuantityMatcher._conjunctions.contains) ||
        name.contains(RegExp(r'[,&+/]'))) {
      return null;
    }
    return _Target(
      index,
      StepQuantityMatcher.stemsOf(words.last),
      StepQuantityMatcher.labelFor(displayLine),
    );
  }
}
