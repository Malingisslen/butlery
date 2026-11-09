import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/tagging/config/occasion_lists.dart';

/// An unknown group or field falls back to its raw key, so a list added to
/// `occasions.json` stays readable before it gets a label.
String occasionGroupLabel(AppLocalizations l10n, String group) =>
    switch (group) {
      'christmas' => l10n.adminOccasionGroupChristmas,
      'lucia' => l10n.adminOccasionGroupLucia,
      'easter' => l10n.adminOccasionGroupEaster,
      'midsummer' => l10n.adminOccasionGroupMidsummer,
      'crayfish' => l10n.adminOccasionGroupCrayfish,
      'newYear' => l10n.adminOccasionGroupNewYear,
      'spring' => l10n.adminOccasionGroupSpring,
      'summer' => l10n.adminOccasionGroupSummer,
      'autumn' => l10n.adminOccasionGroupAutumn,
      'winter' => l10n.adminOccasionGroupWinter,
      'luxury' => l10n.adminOccasionGroupLuxury,
      'titleKeywords' => l10n.adminOccasionGroupTitleKeywords,
      _ => group,
    };

String occasionFieldLabel(AppLocalizations l10n, String field) =>
    switch (field) {
      'titleStemFalsePositives' =>
        l10n.adminOccasionFieldTitleStemFalsePositives,
      'titleWords' => l10n.adminOccasionFieldTitleWords,
      'mainIngredients' => l10n.adminOccasionFieldMainIngredients,
      'sideIngredients' => l10n.adminOccasionFieldSideIngredients,
      'saffronIngredients' => l10n.adminOccasionFieldSaffronIngredients,
      'bakeTitleWords' => l10n.adminOccasionFieldBakeTitleWords,
      'lambIngredients' => l10n.adminOccasionFieldLambIngredients,
      'eggIngredients' => l10n.adminOccasionFieldEggIngredients,
      'herringIngredients' => l10n.adminOccasionFieldHerringIngredients,
      'newPotatoIngredients' => l10n.adminOccasionFieldNewPotatoIngredients,
      'strawberryIngredients' => l10n.adminOccasionFieldStrawberryIngredients,
      'creamIngredients' => l10n.adminOccasionFieldCreamIngredients,
      'ingredients' => l10n.adminOccasionFieldIngredients,
      'dillIngredients' => l10n.adminOccasionFieldDillIngredients,
      'starkSet' => l10n.adminOccasionFieldStarkSet,
      'starkBoost' => l10n.adminOccasionFieldStarkBoost,
      'lyxigSet' => l10n.adminOccasionFieldLyxigSet,
      'lyxigBoost' => l10n.adminOccasionFieldLyxigBoost,
      'comfortFoodSet' => l10n.adminOccasionFieldComfortFoodSet,
      'comfortFoodBoost' => l10n.adminOccasionFieldComfortFoodBoost,
      'barnvanligConfirm' => l10n.adminOccasionFieldBarnvanligConfirm,
      'barnvanligBoost' => l10n.adminOccasionFieldBarnvanligBoost,
      'snabblagatSet' => l10n.adminOccasionFieldSnabblagatSet,
      'snabblagatBoost' => l10n.adminOccasionFieldSnabblagatBoost,
      _ => field,
    };

/// "Jul: Ord i titeln" for `christmas.titleWords`.
String occasionListLabel(AppLocalizations l10n, String listKey) {
  final dot = listKey.indexOf('.');
  if (dot < 0) return listKey;
  return l10n.adminOccasionListName(
    occasionGroupLabel(l10n, listKey.substring(0, dot)),
    occasionFieldLabel(l10n, listKey.substring(dot + 1)),
  );
}

String occasionWordsErrorText(
  AppLocalizations l10n,
  OccasionWordsError error,
) => switch (error) {
  OccasionWordsError.empty => l10n.adminOccasionErrorEmpty,
  OccasionWordsError.tooMany => l10n.adminOccasionErrorTooMany(
    kMaxOccasionWords,
  ),
  OccasionWordsError.tooLong => l10n.adminOccasionErrorTooLong(
    kMaxOccasionWordLength,
  ),
  OccasionWordsError.invalidWord => l10n.adminOccasionErrorInvalid,
  OccasionWordsError.duplicate => l10n.adminOccasionErrorDuplicate,
};

/// What a proposal adds and removes; both empty means only the order changed.
({List<String> added, List<String> removed}) wordListDiff(
  List<String> old,
  List<String> now,
) => (
  added: [
    for (final w in now)
      if (!old.contains(w)) w,
  ],
  removed: [
    for (final w in old)
      if (!now.contains(w)) w,
  ],
);
