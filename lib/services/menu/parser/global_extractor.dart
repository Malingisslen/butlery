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

  var result = working;
  for (final dayEntry in dayNames.entries) {
    final dayWord = dayEntry.key;
    final pattern = RegExp(
      '\\b${RegExp.escape(dayWord)}\\s+([a-zåäö]+)',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(result).toList()) {
      final next = match.group(1)!;
      final tag = formats[next];
      if (tag == null) continue;
      final weekday = int.tryParse(dayEntry.value) ?? 1;
      dayPins.add(DayPin(
        weekdayIndex: weekday,
        mealType: 'middag',
        constraint: RecipeConstraint(count: 1, requiredTags: {tag}),
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

String extractAllergenNegations(
  String working,
  Lexicon lexicon,
  Set<String> avoid,
  List<TraceEntry> understood,
) {
  final negs = lexicon.of(LexiconCategory.negationWords).keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final nouns = lexicon.of(LexiconCategory.allergenNounStems);

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
        final key = nouns[tok];
        if (key == null) break;
        avoid.add(key);
        understood.add(TraceEntry(
          label: 'inget $tok',
          category: TraceCategory.allergen,
        ));
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
