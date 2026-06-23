/// Per-clause parsing: count detection, meal-type detection, subdivision
/// handling, and modifier extraction. Called by [MenuConstraintParser] for
/// each clause after global extraction and clause splitting.
library;

import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/services/menu/parser/lexicon_provider.dart';
import 'package:butlery/services/menu/parser/parser_utils.dart';

final _digitRangeRe = RegExp(r'^(\d+)\s*[-–]\s*(\d+)');
final _digitTillRe = RegExp(r'^(\d+)\s+till\s+(\d+)');
final _wordRangeRe = RegExp(r'^([a-zåäö]+)\s+till\s+([a-zåäö]+)');
final _digitRe = RegExp(r'^(\d+)');
final _wordRe = RegExp(r'^([a-zåäö]+)');
final _timeRe = RegExp(
  r'(?:max|under|tar|på)?\s*(\d+)\s*(?:min|minut|minuter)',
);
final _tokenSplitRe = RegExp(r'[\s\-_]+');
final _digitOnlyRe = RegExp(r'^\d+$');
final _subClauseSplitRe = RegExp(r' och | eller |,');
final _whitespaceSplitRe = RegExp(r'\s+');

const _stopWords = {
  'och',
  'eller',
  'samt',
  'plus',
  'som',
  'ska',
  'vara',
  'är',
  'ar',
  'en',
  'ett',
  'med',
  'till',
  'för',
  'for',
  'av',
  'i',
  'på',
  'pa',
  'denna',
  'vecka',
  'veckan',
  'helst',
  'gärna',
  'garna',
  'minst',
  'dagar',
  'dag',
};

const _softMarkers = {'helst', 'gärna', 'garna', 'minst'};

SlotRequest? parseClause(
  String clause,
  Lexicon lexicon,
  List<TraceEntry> understood,
  List<String> notUnderstood,
  List<String> warnings,
) {
  var rest = clause.trim();
  if (rest.isEmpty) return null;

  final verbs = lexicon.of(LexiconCategory.verbObjectMap);
  final firstWord = _wordRe.firstMatch(rest)?.group(1);
  if (firstWord != null && verbs.containsKey(firstWord)) return null;

  final countResult = detectCount(rest, lexicon);
  final count = countResult.count;
  rest = countResult.remaining.trim();

  final mealResult = detectMealType(rest, lexicon);
  final mealType = mealResult.mealType;
  rest = mealResult.remaining.trim();

  if (mealType == null && countResult.count == 1) {
    if (hasAnyModifier(rest, lexicon)) {
      return _buildSlot(
        'middag',
        count,
        rest,
        lexicon,
        understood,
        notUnderstood,
        warnings,
      );
    }
    if (rest.isNotEmpty) notUnderstood.add(clause);
    return null;
  }

  final effectiveMealType = mealType ?? 'middag';

  if (countResult.label != null) {
    understood.add(
      TraceEntry(
        label:
            '${countResult.label} ${mealResult.matchedStem ?? effectiveMealType}',
        category: TraceCategory.count,
      ),
    );
  } else if (mealResult.matchedStem != null) {
    understood.add(
      TraceEntry(
        label: mealResult.matchedStem!,
        category: TraceCategory.mealType,
      ),
    );
  }

  return _buildSlot(
    effectiveMealType,
    count,
    rest,
    lexicon,
    understood,
    notUnderstood,
    warnings,
  );
}

SlotRequest _buildSlot(
  String mealType,
  int outerCount,
  String modifierTail,
  Lexicon lexicon,
  List<TraceEntry> understood,
  List<String> notUnderstood,
  List<String> warnings,
) {
  final subdivKeys = lexicon.of(LexiconCategory.subdivisionWords).keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  String? subdivWord;
  int subdivIdx = -1;
  for (final key in subdivKeys) {
    final i = modifierTail.indexOf(key);
    if (i >= 0 && (subdivIdx < 0 || i < subdivIdx)) {
      subdivWord = key;
      subdivIdx = i;
    }
  }

  final subRequests = <RecipeConstraint>[];
  final String tail;
  final String head;
  if (subdivWord != null && subdivIdx >= 0) {
    head = modifierTail.substring(0, subdivIdx).trim();
    tail = modifierTail.substring(subdivIdx + subdivWord.length).trim();
  } else {
    head = modifierTail;
    tail = '';
  }

  final outerConstraint = extractModifierSet(
    head,
    lexicon,
    understood,
    notUnderstood,
    warnings,
    countOverride: outerCount,
  );

  if (subdivWord == null) {
    subRequests.add(outerConstraint);
    return SlotRequest(mealType: mealType, subRequests: subRequests);
  }

  int remaining = outerCount;
  for (final subClause in tail.split(_subClauseSplitRe)) {
    final trimmed = subClause.trim();
    if (trimmed.isEmpty) continue;
    final subCount = detectCount(trimmed, lexicon);
    final subRest = subCount.remaining.trim();
    final asNum = subCount.count;
    final sub = extractModifierSet(
      subRest,
      lexicon,
      understood,
      notUnderstood,
      warnings,
      countOverride: asNum,
    );
    if (!sub.isUnconstrained || subCount.label != null) {
      subRequests.add(sub);
      remaining -= asNum;
    }
  }

  if (remaining > 0) {
    subRequests.add(RecipeConstraint(count: remaining));
  }
  if (subRequests.isEmpty) {
    subRequests.add(RecipeConstraint(count: outerCount));
  }
  return SlotRequest(mealType: mealType, subRequests: subRequests);
}

RecipeConstraint extractModifierSet(
  String fragment,
  Lexicon lexicon,
  List<TraceEntry> understood,
  List<String> notUnderstood,
  List<String> warnings, {
  required int countOverride,
}) {
  if (fragment.trim().isEmpty) {
    return RecipeConstraint(count: countOverride);
  }

  final dietaryFree = <String>{};
  final allergenFree = <String>{};
  final requiredTags = <String>{};
  final requiredCuisines = <String>{};
  int? maxTimeMinutes;
  bool isSoft = false;

  final dietary = lexicon.of(LexiconCategory.dietaryStems);
  final allergenFreeMap = lexicon.of(LexiconCategory.allergenFreeStems);
  final cuisines = lexicon.of(LexiconCategory.cuisineStems);
  final formats = lexicon.of(LexiconCategory.formatStems);
  final themes = lexicon.of(LexiconCategory.themeStems);

  final timeMatch = _timeRe.firstMatch(fragment);
  if (timeMatch != null) {
    maxTimeMinutes = int.tryParse(timeMatch.group(1)!);
    if (maxTimeMinutes != null) {
      understood.add(
        TraceEntry(
          label: 'max $maxTimeMinutes min',
          category: TraceCategory.time,
        ),
      );
      fragment = fragment.replaceFirst(timeMatch.group(0)!, ' ');
    }
  }

  final tokens = fragment
      .split(_tokenSplitRe)
      .where((t) => t.isNotEmpty)
      .toList();
  final consumed = <int>{};

  for (int i = 0; i < tokens.length; i++) {
    if (consumed.contains(i)) continue;
    final tok = tokens[i];

    if (_softMarkers.contains(tok)) {
      isSoft = true;
      consumed.add(i);
      continue;
    }

    if (tok.startsWith('snabb') && maxTimeMinutes == null) {
      maxTimeMinutes = 30;
      understood.add(
        const TraceEntry(
          label: 'snabba (max 30 min)',
          category: TraceCategory.time,
        ),
      );
      consumed.add(i);
      continue;
    }

    var key = lexiconLookup(tok, dietary);
    if (key != null) {
      dietaryFree.add(key);
      understood.add(TraceEntry(label: tok, category: TraceCategory.dietary));
      consumed.add(i);
      continue;
    }
    key = lexiconLookup(tok, allergenFreeMap);
    if (key != null) {
      allergenFree.add(key);
      understood.add(TraceEntry(label: tok, category: TraceCategory.allergen));
      consumed.add(i);
      continue;
    }
    key = lexiconLookup(tok, cuisines);
    if (key != null) {
      requiredCuisines.add(key);
      understood.add(TraceEntry(label: tok, category: TraceCategory.cuisine));
      consumed.add(i);
      continue;
    }
    key = lexiconLookup(tok, formats);
    if (key != null) {
      requiredTags.add(key);
      understood.add(TraceEntry(label: tok, category: TraceCategory.format));
      consumed.add(i);
      continue;
    }
    key = lexiconLookup(tok, themes);
    if (key != null) {
      requiredTags.add(key);
      understood.add(TraceEntry(label: tok, category: TraceCategory.theme));
      consumed.add(i);
      continue;
    }
  }

  for (int i = 0; i < tokens.length; i++) {
    if (consumed.contains(i)) continue;
    final tok = tokens[i];
    if (tok.length < 3) continue;
    if (_stopWords.contains(tok)) continue;
    if (_digitOnlyRe.hasMatch(tok)) continue;
    notUnderstood.add(tok);
  }

  return RecipeConstraint(
    count: countOverride,
    dietaryFree: dietaryFree,
    allergenFree: allergenFree,
    requiredTags: requiredTags,
    requiredCuisines: requiredCuisines,
    maxTimeMinutes: maxTimeMinutes,
    isSoft: isSoft,
  );
}

CountResult detectCount(String input, Lexicon lexicon) {
  final s = input.trim();

  final rangeMatch = _digitRangeRe.firstMatch(s) ?? _digitTillRe.firstMatch(s);
  if (rangeMatch != null) {
    final upper = int.parse(rangeMatch.group(2)!);
    return CountResult(
      count: upper,
      remaining: s.substring(rangeMatch.end),
      label: '${rangeMatch.group(1)}–${rangeMatch.group(2)}',
    );
  }

  final wordRange = _wordRangeRe.firstMatch(s);
  if (wordRange != null) {
    final w2 = wordRange.group(2)!;
    final n2 = lexicon.of(LexiconCategory.numbers)[w2];
    if (n2 != null) {
      return CountResult(
        count: int.parse(n2),
        remaining: s.substring(wordRange.end),
        label: '${wordRange.group(1)}–$w2',
      );
    }
  }

  final digitMatch = _digitRe.firstMatch(s);
  if (digitMatch != null) {
    // Don't consume numbers followed by nutritional units (kcal, kalorier)
    final afterDigit = s.substring(digitMatch.end).trimLeft();
    if (!afterDigit.startsWith('kcal') &&
        !afterDigit.startsWith('kalorier') &&
        !afterDigit.startsWith('cal ')) {
      return CountResult(
        count: int.parse(digitMatch.group(1)!),
        remaining: s.substring(digitMatch.end),
        label: digitMatch.group(1),
      );
    }
  }

  final vague = lexicon.of(LexiconCategory.vagueQuantity);
  final vagueKeys = vague.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final key in vagueKeys) {
    if (s.startsWith('$key ') || s == key) {
      return CountResult(
        count: int.parse(vague[key]!),
        remaining: s.substring(key.length),
        label: key,
      );
    }
  }

  final everyday = lexicon.of(LexiconCategory.everydayPhrases);
  final everydayKeys = everyday.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final key in everydayKeys) {
    final idx = s.indexOf(key);
    if (idx >= 0) {
      final left = s.substring(0, idx);
      final right = s.substring(idx + key.length);
      return CountResult(
        count: int.parse(everyday[key]!),
        remaining: '$left $right'.trim(),
        label: key,
      );
    }
  }

  final wordMatch = _wordRe.firstMatch(s);
  if (wordMatch != null) {
    final word = wordMatch.group(1)!;
    final numStr = lexicon.of(LexiconCategory.numbers)[word];
    if (numStr != null) {
      return CountResult(
        count: int.parse(numStr),
        remaining: s.substring(wordMatch.end),
        label: word,
      );
    }
  }

  return CountResult(count: 1, remaining: s, label: null);
}

MealResult detectMealType(String input, Lexicon lexicon) {
  final stems = lexicon.of(LexiconCategory.mealStems);
  final s = input.trim();
  if (s.isEmpty) {
    return MealResult(mealType: null, remaining: s, matchedStem: null);
  }

  final wordMatch = _wordRe.firstMatch(s);
  if (wordMatch != null) {
    final word = wordMatch.group(1)!;
    final canonical = stems[word] ?? lexiconLookup(word, stems);
    if (canonical != null) {
      return MealResult(
        mealType: canonical,
        remaining: s.substring(wordMatch.end).trim(),
        matchedStem: word,
      );
    }
  }

  final tokens = s.split(_whitespaceSplitRe);
  for (int i = 0; i < tokens.length; i++) {
    final canonical = lexiconLookup(tokens[i], stems);
    if (canonical != null) {
      final remaining = [
        ...tokens.sublist(0, i),
        ...tokens.sublist(i + 1),
      ].join(' ').trim();
      return MealResult(
        mealType: canonical,
        remaining: remaining,
        matchedStem: tokens[i],
      );
    }
  }
  return MealResult(mealType: null, remaining: s, matchedStem: null);
}

bool hasAnyModifier(String fragment, Lexicon lexicon) {
  final maps = [
    LexiconCategory.dietaryStems,
    LexiconCategory.allergenFreeStems,
    LexiconCategory.cuisineStems,
    LexiconCategory.formatStems,
    LexiconCategory.themeStems,
  ];
  for (final cat in maps) {
    final map = lexicon.of(cat);
    for (final tok in fragment.split(_whitespaceSplitRe)) {
      if (map.containsKey(tok)) return true;
    }
  }
  return false;
}

class CountResult {
  final int count;
  final String remaining;
  final String? label;
  const CountResult({required this.count, required this.remaining, this.label});
}

class MealResult {
  final String? mealType;
  final String remaining;
  final String? matchedStem;
  const MealResult({
    required this.mealType,
    required this.remaining,
    required this.matchedStem,
  });
}
