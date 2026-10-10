/// BUT-953: One-shot handoff of the heirloom ("släktrecept") scan from
/// PhotoImportView to the recipe form that saves the parsed recipe.
///
/// BUT-2280: a draft is handed out only to the recipe it was bound to.
/// PhotoImportView sets the draft, `TextImportViewModel.parseText` binds it to
/// the recipe it parsed, and the recipe form opened as a template of that
/// recipe takes it. Any other form — a duplicate, an unrelated import — gets
/// nothing, so a scan never lands on the wrong recipe.
///
/// BUT-2286: a scan that parses into several recipes is bound to all of them,
/// and the multi-recipe picker attaches it to each recipe the user saves.
///
/// Pure-state holder: no async, no Firebase, no notify.

import 'package:butlery/models/recipe/heirloom_draft.dart';

class HeirloomBridge {
  HeirloomDraft? _draft;
  Set<String> _boundRecipeIds = const {};

  /// Set the pending heirloom draft. Overwrites any existing draft — the
  /// most recent photo-import navigation wins — and drops any earlier binding.
  void setDraft(HeirloomDraft draft) {
    _draft = draft;
    _boundRecipeIds = const {};
  }

  /// Bind the pending draft to the recipe parsed from its scan. No-op when no
  /// draft is pending.
  void bindTo(String recipeId) => bindToAll([recipeId]);

  /// Bind the pending draft to every recipe parsed from its scan.
  void bindToAll(Iterable<String> recipeIds) {
    if (_draft == null) return;
    _boundRecipeIds = {...recipeIds.where((id) => id.isNotEmpty)};
  }

  /// Hand the draft to [recipeId] and clear the slot, or return null when no
  /// draft is bound to that recipe.
  HeirloomDraft? takeFor(String recipeId) {
    final draft = _draft;
    if (draft == null || !_boundRecipeIds.contains(recipeId)) return null;
    clear();
    return draft;
  }

  /// The pending draft and those of [recipeIds] it is bound to, or null when
  /// none is. Leaves the slot as it is, so a failed save can be retried; the
  /// caller clears it once its recipes are saved.
  ({HeirloomDraft draft, Set<String> recipeIds})? draftFor(
    Iterable<String> recipeIds,
  ) {
    final draft = _draft;
    final bound = recipeIds.where(_boundRecipeIds.contains).toSet();
    if (draft == null || bound.isEmpty) return null;
    return (draft: draft, recipeIds: bound);
  }

  /// Drop the pending draft — e.g. when the photo import screen goes away.
  void clear() {
    _draft = null;
    _boundRecipeIds = const {};
  }

  /// True when a draft is queued.
  bool get hasPending => _draft != null;
}
