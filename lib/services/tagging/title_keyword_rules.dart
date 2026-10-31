import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/generated/occasion_vocabulary.g.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';

/// Tags a recipe's title asks for (Malin 2026-10-30, kärnflöde steg 5 beslut 1).
///
/// A SET word adds its tag on the title alone. A BOOST or CONFIRM word adds
/// it only when the recipe itself already points the same way, so a title can
/// tip a recipe over but never carry a tag the ingredients contradict.
///
/// Allergy and diet tags (glutenfri, vegansk …) are never set from a title:
/// a dish called "glutenfri" with wheat flour in it is not gluten free.
abstract final class TitleKeywordRules {
  static Set<String> apply({
    required Set<String> tags,
    required Recipe recipe,
    required Phase1Result phase1,
  }) {
    final title = recipe.core.title.toLowerCase();
    bool says(List<String> words) => words.any((w) => titleHasWord(title, w));

    final result = Set<String>.from(tags);
    final time = recipe.core.timeMinutes;

    if (says(OccasionVocabulary.titleKeywordsStarkSet) ||
        (says(OccasionVocabulary.titleKeywordsStarkBoost) &&
            phase1.hasProperty('is-spicy'))) {
      result.add('stark');
    }

    if (says(OccasionVocabulary.titleKeywordsLyxigSet) ||
        (says(OccasionVocabulary.titleKeywordsLyxigBoost) &&
            phase1.lookup.matched.any(
              (i) => i.priceCategory == 'premium' || i.priceCategory == 'high',
            ))) {
      result.add('lyxig');
    }

    final hearty = const [
      'krämig',
      'pastabaserad',
      'potatisbaserad',
      'risbaserad',
      'soppa',
      'gryta',
      'gratäng',
    ].any(result.contains);
    if (says(OccasionVocabulary.titleKeywordsComfortFoodSet) ||
        (says(OccasionVocabulary.titleKeywordsComfortFoodBoost) && hearty)) {
      result.add('comfort-food');
    }

    if (says(OccasionVocabulary.titleKeywordsSnabblagatSet) ||
        (says(OccasionVocabulary.titleKeywordsSnabblagatBoost) &&
            time != null &&
            time > 0 &&
            time <= 30)) {
      result.add('snabblagat');
    }

    // Child friendly means neither strong nor alcoholic (beslut 3), so the
    // title only adds it when the ingredients show no alcohol and nothing has
    // made the dish strong, its own title included.
    if ((says(OccasionVocabulary.titleKeywordsBarnvanligConfirm) ||
            says(OccasionVocabulary.titleKeywordsBarnvanligBoost)) &&
        !result.contains('stark') &&
        phase1.getAllergenStatus('alkohol') == TriState.free) {
      result.add('barnvänlig');
    }

    return result;
  }

  /// True when [word] begins a word in [title]: "chili" finds "chilisås" and
  /// "Kyckling i chilisås", but "het" does not find "nyhet".
  static bool titleHasWord(String title, String word) {
    var from = 0;
    while (true) {
      final at = title.indexOf(word, from);
      if (at < 0) return false;
      if (at == 0 || !_isWordChar(title.codeUnitAt(at - 1))) return true;
      from = at + 1;
    }
  }

  /// Letters and digits continue a word, so "15 min" is not found in
  /// "115 min".
  static bool _isWordChar(int c) =>
      (c >= 0x30 && c <= 0x39) ||
      String.fromCharCode(c).toLowerCase() !=
          String.fromCharCode(c).toUpperCase();
}
