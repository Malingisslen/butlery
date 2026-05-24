# Sprint Backlog

## Sprint: iter-48 — BUT-915 persist text-import draft — 2026-05-24 (Sun)

Theme: Mirror BUT-917 draft-pattern (iter-47) onto the text-import flow. Plan-fil FÖRST per iter-46 lessons.

### Step 0 — premise verification

- BUT-915 ticket valid: `lib/viewmodels/text_import_viewmodel.dart` exposes `updateInputText` + state is memory-only via `ImportBaseViewModel.inputText`.
- The actual VIEW is `lib/views/fran_sociala_medier_view.dart` (text-import surfaces as the "från sociala medier" import flow — single consumer of `TextImportViewModel` confirmed via grep).
- View is already StatefulWidget with `_textController` lifecycle (initState + dispose) — clean seam for persistence hooks.

### Design choices

- **Key**: single global `text_import_draft_v1`. Unlike comment-draft (per-recipe), text-import is a CREATE flow with one-at-a-time user intent. No multi-instance concern.
- **What to persist**: `inputText` only. Per ticket also mentions `parsedRecipe` but that's parser-output (cheap to regenerate from inputText) and more complex to serialize. File follow-up if real-user "lost-parsed-result" pain materializes.
- **Don't persist when initialText provided**: if the user came from URL-import sharing a snippet, the `initialText` widget arg takes precedence over any saved draft — they're starting fresh content.
- **Clear-on-success**: when `parseText()` succeeds + navigation to SkrivSjalv happens, the user has explicitly moved past the input stage. Drop the prefs key there.

### Ship this sprint

- [ ] **A1. BUT-915** — Persist text-import inputText.
  - Add `_draftPrefsKey = 'text_import_draft_v1'` const + 3 helper methods (`_loadDraft`, `_saveDraft`, `_clearDraft`) mirroring `comment_form_widget.dart`.
  - `initState` post-frame callback: if `initialText` is null/empty, async-load prefs. If non-empty: set `_textController.text` + `viewModel.updateInputText(saved)`.
  - `onChanged` on the text field: existing `viewModel.updateInputText` PLUS new `_saveDraft(text)` call (eager save, no debounce — pasted recipes are larger than comments but write volume is still low per second).
  - `_parseAndNavigate` success path: `_clearDraft()` before the `Navigator.push`.
  - Dispose: controller-only; don't clear prefs.

### Acceptance

- [ ] User pastes long recipe text → backgrounds app → returns → text in field.
- [ ] User parses + navigates to edit-view → returns to social-media-import later → field empty.
- [ ] Sharing snippet via URL-import passes initialText → draft NOT loaded (initialText wins).

### Post-Sprint Steps

- [ ] `flutter analyze` clean
- [ ] Tier-2: `code-reviewer`
- [ ] `/code-review high` (simplify marker)
- [ ] Commit + push
- [ ] Stäng BUT-915 i Linear → Done
- [ ] File follow-up if `parsedRecipe` persistence becomes needed (currently YAGNI — text re-parses fast)

---

## Archived iter-47 (commit `ae4b25143`) — 2026-05-24 (Sun)

BUT-917 comment-composer draft persist. `CommentFormWidget` Stateless→Stateful + per-recipe `comment_draft_v1_<recipeId>` SharedPreferences. Load/save/clear lifecycle. Bonus: caught leftover CPI site on send button. +138 / -43. BUT-917 → Done. BUT-1058 filed for widget test.
