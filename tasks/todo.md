# Sprint Backlog

## Sprint: iter-47 — BUT-917 persist comment-composer draft — 2026-05-24 (Sun)

Theme: Plan-fil FÖRST per iter-46 lessons-entry. Picked BUT-917 (Medium-priority, autonomous-safe, single-form scope).

### Step 0 — premise verification

- BUT-917 ticket fortfarande giltig: `comment_form_widget.dart:78-92` har `TextField(onChanged: socialViewModel.updateNewCommentText)` — state är memory-only via `SocialCommentsManager._newCommentText`. Confirmed at line 23 + 145-148 of `lib/viewmodels/social_recipe/social_comments_manager.dart`.
- Ticket föreslår "via AutoSaveManager (#1)" — referrerar till BUT-904 (Reusable AutoSaveManager EPIC). Den är INTE shipped. Autonomt-scope-säkert: använd `SharedPreferences` direkt i denna form, file follow-up att consolidera när BUT-904 landar.
- Per-recipe draft key (per ticket): `comment_draft_v1_<recipeId>`.

### Design choices

- **Widget shape**: `CommentFormWidget` är StatelessWidget. Konvertera till StatefulWidget för att äga `TextEditingController` lifecycle (initState init + dispose) + load-on-mount/save-on-change/clear-on-post-success hooks.
- **No debounce**: comments are short (typically < 200 chars), write volume per recipe is low — eager save på varje keystroke är acceptabelt.
- **Don't namespace by userId**: SharedPreferences clears on logout per existing app convention. Per-recipe key is sufficient.
- **Reply state separate**: `_replyToCommentId` är inte persisted — om reply-target försvinner mellan sessioner är det inte värt att försöka återupprätta. Draft text följer dock med, så user kan paste-in-igen.

### Ship this sprint

- [ ] **A1. BUT-917** — Persist comment-composer draft per recipe.
  - Convert `CommentFormWidget` Stateless→Stateful + own `TextEditingController`.
  - `initState`: async load prefs key `comment_draft_v1_<recipeId>`, om non-empty: set controller.text + sync `socialViewModel.updateNewCommentText(savedText)` så send-knappen aktiveras direkt.
  - `onChanged`: pipe to both `socialViewModel.updateNewCommentText` AND `SharedPreferences.setString(key, value)`.
  - Post-success path (after `await socialViewModel.postComment(recipeId)`): `controller.clear()` + `SharedPreferences.remove(key)`.
  - Dispose: `controller.dispose()` (DON'T clear prefs — draft survives widget teardown).
- [ ] **A2. Tests** — Add widget-test or unit-test pinning the draft load→edit→post-clear cycle. Mock SharedPreferences via `SharedPreferences.setMockInitialValues({})` pattern already used in `social_events_tracker_milestone_test.dart`.

### Acceptance

- [ ] User types comment → navigates away → returns → draft text in field.
- [ ] User posts comment → returns later → field empty (draft cleared on success).
- [ ] Two recipes open: drafts isolated per `recipeId`.

### Post-Sprint Steps

- [ ] `flutter analyze` clean
- [ ] Tier-2: `code-reviewer` + `testing-specialist` (lib/ + new test)
- [ ] `/code-review high` (simplify marker)
- [ ] Commit + push
- [ ] Stäng BUT-917 i Linear → Done
- [ ] File BUT-XXX follow-up: migrate this form to `AutoSaveManager` (BUT-904) when that EPIC lands

---

## Archived iter-46 (commit `a1c2d658d`) — 2026-05-24 (Sun)

BUT-883 CPI Phase 2: 18 sites of inline `SizedBox + CircularProgressIndicator` migrated to `LoadingIndicator` across `lib/widgets/common/buttons/action_buttons.dart` + 9 dialog files. Used base constructor (not `.small()` — padding inflation issue). +91 / -103 net delta. BUT-883 → Done.
