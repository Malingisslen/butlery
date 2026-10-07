/// BUT-953: One-shot handoff of the heirloom ("släktrecept") scan from
/// PhotoImportView to the recipe form that saves the parsed recipe.
///
/// BUT-2280: a draft is handed out only to the recipe it was bound to.
/// PhotoImportView sets the draft, `TextImportViewModel.parseText` binds it to
/// the recipe it parsed, and the recipe form opened as a template of that
/// recipe takes it. Any other form — a duplicate, an unrelated import — gets
/// nothing, so a scan never lands on the wrong recipe.
///
/// Pure-state holder: no async, no Firebase, no notify.

import 'package:butlery/models/recipe/heirloom_draft.dart';

class HeirloomBridge {
  HeirloomDraft? _draft;
  String? _boundRecipeId;

  /// Set the pending heirloom draft. Overwrites any existing draft — the
  /// most recent photo-import navigation wins — and drops any earlier binding.
  void setDraft(HeirloomDraft draft) {
    _draft = draft;
    _boundRecipeId = null;
  }

  /// Bind the pending draft to the recipe parsed from its scan. No-op when no
  /// draft is pending.
  void bindTo(String recipeId) {
    if (_draft == null || recipeId.isEmpty) return;
    _boundRecipeId = recipeId;
  }

  /// Hand the draft to [recipeId] and clear the slot, or return null when no
  /// draft is bound to that recipe.
  HeirloomDraft? takeFor(String recipeId) {
    final draft = _draft;
    if (draft == null || _boundRecipeId != recipeId) return null;
    clear();
    return draft;
  }

  /// Drop the pending draft — e.g. when the photo import screen goes away.
  void clear() {
    _draft = null;
    _boundRecipeId = null;
  }

  /// True when a draft is queued.
  bool get hasPending => _draft != null;
}
