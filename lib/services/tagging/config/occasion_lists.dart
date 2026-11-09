import 'package:flutter/foundation.dart' show immutable;

import 'package:butlery/services/tagging/config/generated/occasion_vocabulary.g.dart';

/// One tagging word list an admin can propose a change to (admin-vy step D).
@immutable
class OccasionList {
  const OccasionList(this.key, this.words);

  /// `group.field` in `occasions.json`, as firestore.rules and the
  /// server's `OCCASION_LIST_KEYS` name it.
  final String key;

  /// The words compiled into this build.
  final List<String> words;

  String get group => key.substring(0, key.indexOf('.'));
  String get field => key.substring(key.indexOf('.') + 1);
}

/// Every list in `occasions.json`, in file order. A group's `tag` and the
/// christmas `titleStem` are single words, not lists, and cannot be edited.
/// `occasion_lists_test.dart` pins this to the data file.
const kOccasionLists = <OccasionList>[
  OccasionList(
    'christmas.titleStemFalsePositives',
    OccasionVocabulary.christmasTitleStemFalsePositives,
  ),
  OccasionList('christmas.titleWords', OccasionVocabulary.christmasTitleWords),
  OccasionList(
    'christmas.mainIngredients',
    OccasionVocabulary.christmasMainIngredients,
  ),
  OccasionList(
    'christmas.sideIngredients',
    OccasionVocabulary.christmasSideIngredients,
  ),
  OccasionList('lucia.titleWords', OccasionVocabulary.luciaTitleWords),
  OccasionList(
    'lucia.saffronIngredients',
    OccasionVocabulary.luciaSaffronIngredients,
  ),
  OccasionList('lucia.bakeTitleWords', OccasionVocabulary.luciaBakeTitleWords),
  OccasionList('easter.titleWords', OccasionVocabulary.easterTitleWords),
  OccasionList(
    'easter.lambIngredients',
    OccasionVocabulary.easterLambIngredients,
  ),
  OccasionList(
    'easter.eggIngredients',
    OccasionVocabulary.easterEggIngredients,
  ),
  OccasionList(
    'easter.herringIngredients',
    OccasionVocabulary.easterHerringIngredients,
  ),
  OccasionList('midsummer.titleWords', OccasionVocabulary.midsummerTitleWords),
  OccasionList(
    'midsummer.herringIngredients',
    OccasionVocabulary.midsummerHerringIngredients,
  ),
  OccasionList(
    'midsummer.newPotatoIngredients',
    OccasionVocabulary.midsummerNewPotatoIngredients,
  ),
  OccasionList(
    'midsummer.strawberryIngredients',
    OccasionVocabulary.midsummerStrawberryIngredients,
  ),
  OccasionList(
    'midsummer.creamIngredients',
    OccasionVocabulary.midsummerCreamIngredients,
  ),
  OccasionList('crayfish.titleWords', OccasionVocabulary.crayfishTitleWords),
  OccasionList('crayfish.ingredients', OccasionVocabulary.crayfishIngredients),
  OccasionList(
    'crayfish.dillIngredients',
    OccasionVocabulary.crayfishDillIngredients,
  ),
  OccasionList('newYear.titleWords', OccasionVocabulary.newYearTitleWords),
  OccasionList('newYear.ingredients', OccasionVocabulary.newYearIngredients),
  OccasionList('spring.ingredients', OccasionVocabulary.springIngredients),
  OccasionList('summer.ingredients', OccasionVocabulary.summerIngredients),
  OccasionList('autumn.ingredients', OccasionVocabulary.autumnIngredients),
  OccasionList('winter.ingredients', OccasionVocabulary.winterIngredients),
  OccasionList('luxury.ingredients', OccasionVocabulary.luxuryIngredients),
  OccasionList(
    'titleKeywords.starkSet',
    OccasionVocabulary.titleKeywordsStarkSet,
  ),
  OccasionList(
    'titleKeywords.starkBoost',
    OccasionVocabulary.titleKeywordsStarkBoost,
  ),
  OccasionList(
    'titleKeywords.lyxigSet',
    OccasionVocabulary.titleKeywordsLyxigSet,
  ),
  OccasionList(
    'titleKeywords.lyxigBoost',
    OccasionVocabulary.titleKeywordsLyxigBoost,
  ),
  OccasionList(
    'titleKeywords.comfortFoodSet',
    OccasionVocabulary.titleKeywordsComfortFoodSet,
  ),
  OccasionList(
    'titleKeywords.comfortFoodBoost',
    OccasionVocabulary.titleKeywordsComfortFoodBoost,
  ),
  OccasionList(
    'titleKeywords.barnvanligConfirm',
    OccasionVocabulary.titleKeywordsBarnvanligConfirm,
  ),
  OccasionList(
    'titleKeywords.barnvanligBoost',
    OccasionVocabulary.titleKeywordsBarnvanligBoost,
  ),
  OccasionList(
    'titleKeywords.snabblagatBoost',
    OccasionVocabulary.titleKeywordsSnabblagatBoost,
  ),
  OccasionList(
    'titleKeywords.snabblagatSet',
    OccasionVocabulary.titleKeywordsSnabblagatSet,
  ),
];

/// Why a proposed word list is refused; the same checks as the server's
/// `validateNewWords` in `functions/src/admin/occasion-change-plan.ts`.
enum OccasionWordsError { empty, tooMany, tooLong, invalidWord, duplicate }

const int kMaxOccasionWords = 200;
const int kMaxOccasionWordLength = 60;

final RegExp _word = RegExp(
  r"^[\p{L}\p{N}'-]+( [\p{L}\p{N}'-]+)*$",
  unicode: true,
);

/// Reads one word per line (a comma also separates, since no word may hold
/// one): trimmed, lower case, inner spaces collapsed, blanks dropped and
/// repeats dropped, in the order typed.
List<String> parseOccasionWords(String text) {
  final seen = <String>{};
  return [
    for (final raw in text.split(RegExp(r'[\n,]')))
      if (raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') case final w
          when w.isNotEmpty && seen.add(w))
        w,
  ];
}

OccasionWordsError? validateOccasionWords(List<String> words) {
  if (words.isEmpty) return OccasionWordsError.empty;
  if (words.length > kMaxOccasionWords) return OccasionWordsError.tooMany;
  final seen = <String>{};
  for (final w in words) {
    if (w.length > kMaxOccasionWordLength) return OccasionWordsError.tooLong;
    if (!_word.hasMatch(w) || w != w.toLowerCase()) {
      return OccasionWordsError.invalidWord;
    }
    if (!seen.add(w)) return OccasionWordsError.duplicate;
  }
  return null;
}
