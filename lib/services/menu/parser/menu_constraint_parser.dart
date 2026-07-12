/// Deterministic Swedish constraint parser for veckomeny prompts.
///
/// Pure utility — no IO, no async, no state. Delegates to [clause_parser]
/// and [global_extractor] for the heavy lifting. Sprint 2 will overlay
/// operator-edited Firestore data via [LexiconProvider]; the parser sees
/// only the merged [Lexicon] snapshot.
library;

import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/services/menu/parser/clause_parser.dart';
import 'package:butlery/services/menu/parser/global_extractor.dart';
import 'package:butlery/services/menu/parser/lexicon_provider.dart';
import 'package:butlery/services/menu/parser/text_normalizer.dart';

final _hardSepRe = RegExp(r'[,;]');
final _softSepRe = RegExp(r' och | samt | plus ');
final _subdivRe = RegExp(r'\b(varav|där|dar|vilka|den ena)\b');

class MenuConstraintParser {
  MenuConstraintParser._();

  static ParsedMenuRequest parse(String prompt, Lexicon lexicon) {
    if (prompt.trim().isEmpty) return ParsedMenuRequest.empty(prompt);

    var working = normalize(prompt);
    // Spoken-register passes (voice prompts, but harmless for typed text):
    // fillers out first so they can't mask a correction marker, then
    // last-wins self-correction resolution within same-vocabulary tokens.
    working = stripSpokenFillers(working);
    working = resolveSelfCorrections(
      working,
      exactVocabularies: [lexicon.of(LexiconCategory.numbers).keys],
      stemVocabularies: [
        lexicon.of(LexiconCategory.dietaryStems).keys,
        lexicon.of(LexiconCategory.allergenFreeStems).keys,
        lexicon.of(LexiconCategory.cuisineStems).keys,
        lexicon.of(LexiconCategory.mealStems).keys,
      ],
    );
    working = stripPolitePreamble(
      working,
      lexicon.of(LexiconCategory.politePreamble).keys,
    );
    if (working.isEmpty) return ParsedMenuRequest.empty(prompt);

    final understood = <TraceEntry>[];
    final notUnderstood = <String>[];
    final warnings = <String>[];
    final globalAllergenAvoid = <String>{};
    final globalDietaryRequire = <String>{};
    final globalExcludedTags = <String>{};
    final dayPins = <DayPin>[];
    bool skipFrukost = false;

    // Skip-frukost markers (16:8, "ingen frukost")
    final skipMarkers = lexicon.of(LexiconCategory.skipFrukostMarkers);
    for (final marker in skipMarkers.keys) {
      if (working.contains(marker)) {
        skipFrukost = true;
        working = working.replaceAll(marker, ' ');
        understood.add(
          const TraceEntry(
            label: 'ingen frukost',
            category: TraceCategory.mealType,
          ),
        );
      }
    }

    // Day idioms (tacofredag, fredagsmys)
    final dayIdioms = lexicon.of(LexiconCategory.dayIdioms);
    for (final entry in dayIdioms.entries) {
      if (working.contains(entry.key)) {
        final parts = entry.value.split('|');
        if (parts.length == 3) {
          dayPins.add(
            DayPin(
              weekdayIndex: int.tryParse(parts[0]) ?? 5,
              mealType: parts[2],
              constraint: RecipeConstraint(
                count: 1,
                requiredTags: {parts[1]},
              ),
            ),
          );
          understood.add(
            TraceEntry(
              label: entry.key,
              category: TraceCategory.day,
            ),
          );
          working = working.replaceAll(entry.key, ' ');
        }
      }
    }

    working = extractDayFormatPins(working, lexicon, dayPins, understood);
    working = extractGlobalDietary(
      working,
      lexicon,
      globalDietaryRequire,
      understood,
    );
    working = extractAllergenNegations(
      working,
      lexicon,
      globalAllergenAvoid,
      globalExcludedTags,
      understood,
    );

    final clauses = _splitClauses(working);

    final slotRequests = <SlotRequest>[];
    for (final clause in clauses) {
      final slot = parseClause(
        clause,
        lexicon,
        understood,
        notUnderstood,
        warnings,
      );
      if (slot != null) {
        if (skipFrukost && slot.mealType == 'frukost') continue;
        slotRequests.add(slot);
      }
    }

    sweepVerbObjects(working, lexicon, slotRequests, understood);

    final merged = _mergeSlotsByMealType(slotRequests);

    return ParsedMenuRequest(
      slotRequests: merged,
      globalAllergenAvoid: globalAllergenAvoid,
      globalDietaryRequire: globalDietaryRequire,
      globalExcludedTags: globalExcludedTags,
      dayPins: dayPins,
      trace: ExtractionTrace(
        understood: understood,
        notUnderstood: notUnderstood,
        warnings: warnings,
      ),
      rawPrompt: prompt,
    );
  }

  static List<String> _splitClauses(String input) {
    final hard = input
        .split(_hardSepRe)
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    // Don't split on "och" inside subdivisions — "och" is part of the
    // sub-request enumeration (e.g. "varav en glutenfri och två matlådor").
    final result = <String>[];
    for (final clause in hard) {
      if (_subdivRe.hasMatch(clause)) {
        result.add(clause);
      } else {
        result.addAll(
          clause
              .split(_softSepRe)
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty),
        );
      }
    }
    return result;
  }

  static List<SlotRequest> _mergeSlotsByMealType(List<SlotRequest> slots) {
    final byMeal = <String, List<RecipeConstraint>>{};
    final order = <String>[];
    for (final slot in slots) {
      if (!byMeal.containsKey(slot.mealType)) {
        byMeal[slot.mealType] = [];
        order.add(slot.mealType);
      }
      byMeal[slot.mealType]!.addAll(slot.subRequests);
    }
    return [
      for (final m in order) SlotRequest(mealType: m, subRequests: byMeal[m]!),
    ];
  }
}
