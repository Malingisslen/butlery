/// BUT-953: One-shot handoff between PhotoImportView and the save flow in
/// ImportBaseViewModel.
///
/// PhotoImportView populates `setDraft` before pushing the text-import route.
/// `ImportBaseViewModel.saveImportedRecipe` calls `consumeDraft` — read-then-
/// clear — so the upload runs once with the actual parsed recipe id, never
/// twice and never against the wrong recipe.
///
/// Pure-state holder: no async, no Firebase, no notify. Documented non-adopter
/// of `BaseService` (see `lib/services/CLAUDE.md`).

import 'package:butlery/models/recipe/heirloom_draft.dart';

class HeirloomBridge {
  HeirloomDraft? _draft;

  /// Set the pending heirloom draft. Overwrites any existing draft — the
  /// most recent photo-import navigation wins.
  void setDraft(HeirloomDraft draft) {
    _draft = draft;
  }

  /// Read the pending draft and clear the slot atomically. Returns null when
  /// no draft is queued — the save flow falls through to the regular path
  /// without an upload attempt.
  HeirloomDraft? consumeDraft() {
    final out = _draft;
    _draft = null;
    return out;
  }

  /// Drop the pending draft without consuming it — e.g. when the user
  /// navigates away from the import flow.
  void clear() {
    _draft = null;
  }

  /// True when a draft is queued for the next save.
  bool get hasPending => _draft != null;
}
