/// Extracts global constraints from the prompt: day pins, allergen negations,
/// skip-frukost markers. Called before clause splitting.
library;

import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/services/menu/parser/lexicon_provider.dart';
import 'package:butlery/services/menu/parser/parser_utils.dart';

String extractDayFormatPins(
  String working,
  Lexicon lexicon,
  List<DayPin> dayPins,
  List<TraceEntry> understood,
) {
  final dayNames = lexicon.of(LexiconCategory.dayNames);
  final formats = lexicon.of(LexiconCategory.formatStems);
  final dietary = lexicon.of(LexiconCategory.dietaryStems);
  final cuisines = lexicon.of(LexiconCategory.cuisineStems);
  final themes = lexicon.of(LexiconCategory.themeStems);

  var result = working;
  for (final dayEntry in dayNames.entries) {
    final dayWord = dayEntry.key;
    // Support both "måndag pasta" and "måndag: pasta"
    final pattern = RegExp(
      '\\b${RegExp.escape(dayWord)}[:\\s]+([a-zåäö]+)',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(result).toList()) {
      final next = match.group(1)!;
      // Cascading lookup: format → dietary → cuisine → theme
      final formatTag = formats[next];
      final dietaryTag = dietary[next];
      final cuisineTag = cuisines[next];
      final themeTag = themes[next];
      if (formatTag == null &&
          dietaryTag == null &&
          cuisineTag == null &&
          themeTag == null) {
        continue;
      }

      final weekday = int.tryParse(dayEntry.value) ?? 1;
      dayPins.add(DayPin(
        weekdayIndex: weekday,
        mealType: 'middag',
        constraint: RecipeConstraint(
          count: 1,
          requiredTags: {
            if (formatTag != null) formatTag,
            if (themeTag != null) themeTag,
          },
          dietaryFree: {if (dietaryTag != null) dietaryTag},
          requiredCuisines: {if (cuisineTag != null) cuisineTag},
        ),
      ));
      understood.add(TraceEntry(
        label: '$dayWord $next',
        category: TraceCategory.day,
      ));
      final span = match.group(0)!;
      result = result.replaceFirst(span, ' ' * span.length);
    }
  }
  return result;
}

/// Extracts global dietary requirements from phrases like "bara vegetariskt",
/// "allt veganskt", "hela veckan vegetariskt".
String extractGlobalDietary(
  String working,
  Lexicon lexicon,
  Set<String> require,
  List<TraceEntry> understood,
) {
  final dietary = lexicon.of(LexiconCategory.dietaryStems);
  if (dietary.isEmpty) return working;

  const prefixes = ['bara ', 'allt ', 'enbart ', 'helt '];
  var result = working;

  for (final prefix in prefixes) {
    int searchFrom = 0;
    while (true) {
      final idx = result.indexOf(prefix, searchFrom);
      if (idx < 0) break;
      if (idx > 0 && isWordChar(result.codeUnitAt(idx - 1))) {
        searchFrom = idx + prefix.length;
        continue;
      }
      int cursor = idx + prefix.length;
      cursor = skipSpaces(result, cursor);
      final tok = readWord(result, cursor);
      if (tok == null) {
        searchFrom = idx + prefix.length;
        continue;
      }
      final key = dietary[tok];
      if (key == null) {
        searchFrom = idx + prefix.length;
        continue;
      }
      require.add(key);
      understood.add(TraceEntry(
        label: '$prefix$tok'.trim(),
        category: TraceCategory.dietary,
      ));
      final spanEnd = cursor + tok.length;
      result = result.substring(0, idx) +
          ' ' * (spanEnd - idx) +
          result.substring(spanEnd);
      searchFrom = spanEnd;
    }
  }
  return result;
}

String extractAllergenNegations(
  String working,
  Lexicon lexicon,
  Set<String> avoid,
  Set<String> excludeTags,
  List<TraceEntry> understood,
) {
  final negs = lexicon.of(LexiconCategory.negationWords).keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final nouns = lexicon.of(LexiconCategory.allergenNounStems);
  final formats = lexicon.of(LexiconCategory.formatStems);
  final themes = lexicon.of(LexiconCategory.themeStems);

  var result = working;
  for (final neg in negs) {
    int searchFrom = 0;
    while (true) {
      final idx = result.indexOf(neg, searchFrom);
      if (idx < 0) break;
      if (idx > 0 && isWordChar(result.codeUnitAt(idx - 1))) {
        searchFrom = idx + neg.length;
        continue;
      }
      int cursor = idx + neg.length;
      cursor = skipSpaces(result, cursor);
      bool found = false;
      int spanEnd = idx + neg.length;
      while (cursor < result.length) {
        final tok = readWord(result, cursor);
        if (tok == null) break;
        // Check allergen nouns first, then format/theme tags
        final allergenKey = nouns[tok];
        final formatKey = formats[tok];
        final themeKey = themes[tok];
        if (allergenKey == null && formatKey == null && themeKey == null) {
          // Not a known tag — capture as raw ingredient exclusion word.
          // Min 3 chars to avoid false positives on short prepositions.
          const minIngredientWordLength = 3;
          if (tok.length >= minIngredientWordLength) {
            excludeTags.add(tok);
            understood.add(TraceEntry(
              label: 'inget $tok',
              category: TraceCategory.format,
            ));
            found = true;
            cursor += tok.length;
            spanEnd = cursor;
          }
          break;
        }
        if (allergenKey != null) {
          avoid.add(allergenKey);
          understood.add(TraceEntry(
            label: 'inget $tok',
            category: TraceCategory.allergen,
          ));
        } else {
          final tag = formatKey ?? themeKey!;
          excludeTags.add(tag);
          understood.add(TraceEntry(
            label: 'inget $tok',
            category: TraceCategory.format,
          ));
        }
        found = true;
        cursor += tok.length;
        spanEnd = cursor;
        final after = skipSpaces(result, cursor);
        if (after >= result.length) break;
        if (result.startsWith('och ', after)) {
          cursor = after + 4;
        } else if (result.startsWith('eller ', after)) {
          cursor = after + 6;
        } else if (result[after] == ',') {
          cursor = after + 1;
        } else {
          break;
        }
        cursor = skipSpaces(result, cursor);
      }
      if (found) {
        result = result.substring(0, idx) +
            ' ' * (spanEnd - idx) +
            result.substring(spanEnd);
        searchFrom = spanEnd;
      } else {
        searchFrom = idx + neg.length;
      }
    }
  }
  return result;
}

void sweepVerbObjects(
  String working,
  Lexicon lexicon,
  List<SlotRequest> slots,
  List<TraceEntry> understood,
) {
  final verbs = lexicon.of(LexiconCategory.verbObjectMap);
  if (verbs.isEmpty) return;

  for (final verbEntry in verbs.entries) {
    final verb = verbEntry.key;
    final tag = verbEntry.value;
    final pattern = RegExp(
      '\\b${RegExp.escape(verb)}\\s+([a-zåäö]+)'
      r'(?:\s+(\d+|en|två|tre|fyra|fem)\s*(?:dagar|gånger|ganger))?',
    );
    for (final match in pattern.allMatches(working)) {
      final qtyToken = match.group(2);
      int count = 1;
      if (qtyToken != null) {
        count = int.tryParse(qtyToken) ??
            int.tryParse(lexicon.of(LexiconCategory.numbers)[qtyToken] ?? '') ??
            1;
      }
      final already = slots.any((slot) =>
          slot.subRequests.any((sub) => sub.requiredTags.contains(tag)));
      if (already) continue;

      slots.add(SlotRequest(
        mealType: 'ovrigt',
        subRequests: [
          RecipeConstraint(count: count, requiredTags: {tag})
        ],
      ));
      understood.add(TraceEntry(
        label: '$tag × $count',
        category: TraceCategory.format,
      ));
    }
  }
}
