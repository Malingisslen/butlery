/// Whether a photo read on the phone probably holds recipes the phone did not
/// find. Kept as plain functions so the rule can be tuned after the corpus
/// measurement without touching the view model.

/// The recipes the page seems to hold: the larger of the text signal
/// ([textCandidates], `MultiRecipeSplitter.countCandidates`) and the blocks the
/// import tried ([blocksTried], successes plus failures). Never their sum:
/// both signals look at the same recipes.
int candidateRecipeCount({
  required int textCandidates,
  required int blocksTried,
}) => textCandidates > blocksTried ? textCandidates : blocksTried;

/// True when the page seems to hold more recipes than the phone returned.
bool mayHaveMissedRecipes({required int candidates, required int found}) =>
    found >= 1 && candidates > found;
