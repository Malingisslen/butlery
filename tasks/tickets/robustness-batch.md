# Linear Ticket Drafts — Robustness & Recovery Audit (2026-05-22)

> Paste-ready ticket bodies. Linear MCP was not connected when these were prepared, so they have not been created in Linear yet. Each section is one ticket. Separator `---` marks ticket boundaries.

Findings from the robustness / recovery audit — gaps where the happy path works but interruption, failure, or destructive actions leave users stuck or losing data. Organised under four themes plus two foundation epics that several tickets depend on.

---

## 1. EPIC — Reusable AutoSaveManager: generalise the recipe-edit autosave to all forms

**Labels:** `tech-debt`, `recipe`, `import`, `social`
**Priority:** High
**State:** Triage

### Opportunity
`lib/services/recipe/recipe_auto_save_manager.dart:84-150` already implements a working autosave: saves drafts to `SharedPreferences` on app lifecycle pause and presents a "Restore draft?" dialog via `recipe_draft_recovery_handler.dart:19-100`. **No other form in the app uses it.** Every interruption-loss ticket below depends on this foundation existing as a reusable facade.

### Current State
- Working autosave: recipe edit form only.
- Reusable surface: zero — the manager is tightly coupled to the recipe form's state shape.
- Other surfaces (photo/URL/text import, comments, group creation, filter state) hold state in memory only and lose it on background/nav.

### Proposed Improvement
Extract a generic `AutoSaveManager<T>` interface:
- Pluggable `Codec<T>` for serialising form state to JSON.
- Pluggable storage key per surface.
- Hooks into `AppLifecycleState.paused` to write; reads on init to offer recovery.
- Reuse the existing `DraftRecoveryHandler` UI pattern.

Once this exists, the per-surface tickets (#2–#7) are each ~half a day of wiring.

### Effort vs Impact
Medium / high. The foundation unlocks 6+ follow-up tickets that each remove a class of "I lost my work" complaints.

---

## 2. Persist photo-import draft across navigation and background

**Labels:** `tech-debt`, `import`, `recipe`
**Priority:** Medium (blocked on #1)
**State:** Triage

### Finding
`lib/viewmodels/photo_import_viewmodel.dart:397-415` — `clearPhoto()` wipes `_imageBytes` and `_ocrText` on every nav. A user who takes a photo, waits 30 seconds for OCR, then navigates away by accident loses everything.

### Proposed Improvement
Use `AutoSaveManager` (#1) to persist `_imageBytes` (gzipped to a temp file path, not SharedPreferences) + `_ocrText` + extraction state. On return to the screen, offer "Continue with previous photo?" via the existing draft-recovery prompt.

### Effort vs Impact
Small / medium. Image bytes need on-disk staging, not SharedPreferences — see implementation note in #1.

---

## 3. Persist URL-import draft across navigation and background

**Labels:** `tech-debt`, `import`
**Priority:** Medium (blocked on #1)
**State:** Triage

### Finding
`lib/viewmodels/url_import_viewmodel.dart:84-189` — `url`, `extractedText`, `parsedRecipe` are in-memory only. User who pastes a long URL, hits "Fetch", then gets a call → returns to a blank screen.

### Proposed Improvement
Persist `url`, fetched HTML, and parsed-recipe object via `AutoSaveManager` (#1).

### Effort vs Impact
Small / low-medium.

---

## 4. Persist text-import draft across navigation and background

**Labels:** `tech-debt`, `import`
**Priority:** Medium (blocked on #1)
**State:** Triage

### Finding
`lib/viewmodels/text_import_viewmodel.dart:59-145` — `inputText` and `parsedRecipe` are in-memory only.

### Proposed Improvement
Persist `inputText` and `parsedRecipe` via `AutoSaveManager` (#1). Recovery prompt restores both the textarea content and the parsed result if extraction had completed.

### Effort vs Impact
Small / low-medium.

---

## 5. Persist comment-composer draft text

**Labels:** `tech-debt`, `social`, `recipe`
**Priority:** Medium (blocked on #1)
**State:** Triage

### Finding
`lib/widgets/recipe/comment_form_widget.dart:78-92` — comment text is stored in `socialViewModel.newCommentText` (memory only). A long thoughtful comment + interruption = retype from scratch.

### Proposed Improvement
Persist per-recipe in-flight comment draft via `AutoSaveManager` (#1). Key by recipe ID so a user with two recipes open in tabs doesn't get cross-contaminated.

### Effort vs Impact
Small / medium. Comments are short but losing one is a real annoyance.

---

## 6. Persist group-creation form draft

**Labels:** `tech-debt`, `social`
**Priority:** Medium (blocked on #1)
**State:** Triage

### Finding
`lib/viewmodels/create_group_viewmodel.dart:93-240` — name, selected friend IDs, emoji, description are all in-memory. A user who picks 8 friends + names the group and then backgrounds the app for a phone call returns to an empty form.

### Proposed Improvement
Persist the full creation-form state via `AutoSaveManager` (#1). Restore prompt on re-entry: "Resume creating 'Family dinners' with 8 members?".

### Effort vs Impact
Small / medium.

---

## 7. Persist recipe-list filter and scroll state

**Labels:** `tech-debt`, `recipe`
**Priority:** High (blocked on #1)
**State:** Triage

### Finding
`lib/viewmodels/recipe_list_viewmodel.dart:34-150` — sort criteria persist via `_loadDisplayPreferences()` (line 137-149), but `_activeTimeFilters`, `_activeMealTypeFilters` reset on every navigation. Scroll position also resets to top. Half-built persistence.

### Proposed Improvement
Persist active filters and scroll offset alongside sort criteria. The same `_loadDisplayPreferences` / save pattern already exists for sort — extend it.

### Effort vs Impact
Small / high. Daily friction for power users with large libraries.

---

## 8. Don't wipe parsed recipe on parse error — preserve user edits

**Labels:** `bug`, `import`, `recipe`
**Priority:** High
**State:** Triage

### Finding
`lib/viewmodels/import_base_viewmodel.dart:349` — when parsing fails, `parsedRecipe` is cleared. If the user had already manually edited the partially-parsed recipe (changed the title, added an ingredient), those edits go with it. User sees a "Parse failed" toast and the form reverts to empty.

### Proposed Improvement
On parse failure, retain whatever was last successfully parsed AND any user edits applied since. Surface the error in a dismissable banner, not a full state-wipe.

### Effort vs Impact
Small / high. Pure logic fix — guard the clear behind a "user has not yet edited" check, or move clearing into a higher level retry flow.

---

## 9. EPIC — Soft-delete + trash recovery system

**Labels:** `idea`, `recipe`, `tagging`, `menu`, `shopping`
**Priority:** High
**State:** Triage

### Opportunity
Most destructive actions in Butlery are permanent and irreversible (see tickets #10–#16). Bulk-recipe-delete has a 7-second snackbar (`recipe_delete_manager.dart:94`), but that's session-only and inconsistent with every other delete path. A reusable soft-delete subsystem would close the gap once and propagate the fix to every consumer.

### Proposed Improvement
Introduce a "trash" subsystem:
- Soft-delete pattern: items get `deletedAt: Timestamp` instead of being removed.
- TTL job (Cloud Function on schedule) purges items where `deletedAt < now - 30d`.
- Per-user "Trash" view listing recoverable items, grouped by type (recipes, tags, cook snaps, etc.) with "Restore" + "Delete forever".
- Repository-level helpers: `softDelete(id)`, `restore(id)`, `purge(id)`.
- Firestore security rules updated to enforce trash semantics.

### Effort vs Impact
Large / very high. Touches many repositories + rules + a new view + scheduled function. But every per-action undo ticket below shrinks to ~half a day once this exists.

---

## 10. Add undo to recipe single-delete (consistency with bulk-delete)

**Labels:** `bug`, `recipe`
**Priority:** High
**State:** Triage

### Finding
`lib/viewmodels/recipe_detail_viewmodel.dart:227` — single-recipe delete from detail view is permanent. But `lib/viewmodels/recipe_list/recipe_delete_manager.dart:94` provides a 7-second snackbar undo for bulk-delete. **Same action, two different recovery models** depending on entry point. Users hitting the trash icon on the detail view lose recipes they could have recovered from the list view.

### Proposed Improvement
Either (a) thin client-side fix: show the same 7-second snackbar on single-delete, OR (b) wire to soft-delete via #9 for persistent recovery. Recommend (b) once #9 lands; (a) as a same-day stopgap.

### Effort vs Impact
Small (a) / Medium (b) / high. Removes a sharp-edged inconsistency.

---

## 11. Tag delete needs undo + cascade preview

**Labels:** `bug`, `tagging`
**Priority:** High
**State:** Triage

### Finding
`lib/viewmodels/personal_tag_viewmodel.dart:252` → `personal_tag_crud_service.dart:154` — deleting a tag silently removes it from every recipe it tagged (`addRemovePersonalTagFromRecipesToBatch` at line 165). No confirmation showing how many recipes will be affected. No undo. A misclick on "Italian" untags 47 recipes with zero recovery.

### Proposed Improvement
Two-part:
1. Confirmation modal showing affected recipe count before delete.
2. Soft-delete via #9 — restoring a deleted tag also reapplies it to the recipes it was on.

### Effort vs Impact
Small (confirmation) / Medium (soft-delete restore symmetry) / high. The cascade silently destroying organisation is the worst data-loss path in the audit.

---

## 12. Recipe photo deletion from edit form needs undo

**Labels:** `bug`, `recipe`
**Priority:** Medium
**State:** Triage

### Finding
`lib/viewmodels/recipe_form/recipe_image_manager.dart:535-544` — `removeImageAndCleanup()` calls `_storageService.deleteRecipeImage(imageStatus.url!)` immediately. Storage object is gone before the user even saves the recipe. Cancel the edit → image is still gone.

### Proposed Improvement
Defer storage deletion until the recipe edit is saved. While editing, just mark the image as "pending removal" in memory. On save commit, batch all pending image deletions. On cancel, restore all of them. Soft-delete in Storage isn't natively supported by Firebase, but we can move-to-trash-bucket + TTL.

### Effort vs Impact
Medium / medium. Editor needs a "pending changes" model for images, which it doesn't currently have.

---

## 13. Menu plan "Clear week" needs undo

**Labels:** `idea`, `menu`
**Priority:** Medium
**State:** Triage

### Finding
`lib/viewmodels/menu/weekly_menu_plan_viewmodel.dart:174-180` — `_service.clearWeek(current)` wipes all entries with no undo. Most weeks took 5+ minutes to plan; accidental tap = redo from scratch.

### Proposed Improvement
Show a 7-second snackbar undo on clear (stopgap). Or, with #9 landed, snapshot the week into trash and restore.

### Effort vs Impact
Small (snackbar) / medium (full restore) / medium.

---

## 14. Cook-snap delete needs undo

**Labels:** `idea`, `social`, `recipe`
**Priority:** Medium
**State:** Triage

### Finding
`lib/viewmodels/cook_snap_viewmodel.dart:86` — `await _service.deleteCookSnap(snapId)` is permanent. Cook-snaps are personal milestones (a meal someone was proud enough to photograph); accidental deletion is painful.

### Proposed Improvement
Soft-delete via #9.

### Effort vs Impact
Small / medium (once #9 exists).

---

## 15. Comment delete (own) needs undo

**Labels:** `idea`, `social`
**Priority:** Low
**State:** Triage

### Finding
`lib/viewmodels/social_recipe/social_comments_manager.dart:196` — dialog-confirmed but no undo. Comments are usually short and re-typable, so impact is low.

### Proposed Improvement
7-second snackbar undo (no need for full soft-delete here).

### Effort vs Impact
Small / low.

---

## 16. Easier rejoin after unfriend / leave group

**Labels:** `idea`, `social`
**Priority:** Low
**State:** Triage

### Finding
- Unfriend: `lib/viewmodels/friends_viewmodel.dart:272` — must re-send friend request.
- Leave group: `lib/viewmodels/group_detail_viewmodel.dart:298` — must wait for fresh invitation; the group is not discoverable from the user's side.

### Proposed Improvement
- Unfriend: surface "Recently removed friends" in the add-friend flow for 30 days, with one-tap re-add.
- Leave group: keep the group visible in a "Past groups" section with a "Request to rejoin" affordance (sends a notification to a current member or admin).

### Effort vs Impact
Medium / low. Niche but reduces churn-by-mistake.

---

## 17. Investigate: grace period before account deletion

**Labels:** `idea`, `account`
**Priority:** Low
**State:** Triage

### Finding
`lib/services/account/account_deletion_service.dart:110` — instant erasure on confirmation. GDPR-compliant by design (Art. 5 audit log retained 180 days at line 51), but many large apps offer a 30-day grace with "cancel deletion" flow. A user who deletes in a fit of pique can't undo.

### Proposed Improvement
**Investigate first** — needs legal/GDPR review. The technical pattern would be: set `pendingDeletion: { scheduledFor: now+30d }` on the user record, sign them out, but allow login during the grace window to cancel. After 30 days, a scheduled function executes the actual purge.

### Effort vs Impact
Medium / low. May be wontfix depending on legal opinion — close with comment if so.

---

## 18. Heirloom photo upload orphan — block "success" toast until image lands

**Labels:** `bug`, `recipe`, `import`
**Priority:** High
**State:** Triage

### Finding
`lib/viewmodels/photo_import_viewmodel.dart:311-381` / `lib/services/storage/storage_service.dart:56-99` — recipe is saved to Firestore before the heirloom image upload completes. If the upload fails after the recipe save:
- `_isOfflineQueued` (line 331) is in-memory only and lost on app restart.
- The recipe is saved without the image, **success toast shown to the user**.
- No retry. No notification. Image silently lost.

### Proposed Improvement
Either:
- (a) Block recipe save on image upload success — recipe only saves once image is in Storage.
- (b) Add a persistent upload queue (Drift table) so on app restart the upload is retried; flag the recipe as "image pending" with a visible banner until the upload resolves.

(b) is more flexible because it lets users continue working without waiting; (a) is simpler and avoids the orphan entirely.

### Effort vs Impact
Medium / high. Currently masks data loss as success — worst class of UX bug.

---

## 19. Sync conflict resolution must be visible to the user

**Labels:** `bug`, `recipe`, `social`
**Priority:** High
**State:** Triage

### Finding
`lib/services/realtime/realtime_sync_service.dart:142-150` and `lib/services/realtime/realtime_conflict_resolver.dart:104-150` — collaborative edit conflicts use last-write-wins per field and list-merge for arrays, with **no user notification**. User A and User B edit the same recipe within 5 seconds → one of them silently loses their work.

`_errorController` (line 42-43) broadcasts sync errors but no ViewModel subscribes to it.

### Proposed Improvement
- Subscribe to `_errorController` from a top-level provider and surface conflict events as a non-blocking banner: "Your changes to '<recipe>' were merged with edits from <user>. View history."
- Track per-field conflict counts in `realtime_conflict_resolver.dart` and emit them.
- Bonus: per-recipe edit history view (deferred to a follow-up).

### Effort vs Impact
Medium / high. Silent overwrites are the most damaging kind of bug in a collaborative feature.

---

## 20. Add client-side timeout to recipe parse Cloud Function call

**Labels:** `bug`, `import`, `parsing`
**Priority:** High
**State:** Triage

### Finding
`lib/viewmodels/import_base_viewmodel.dart:56-76` — `executeAsync()` wraps the LLM parsing call with no timeout. If Gemini hangs, the spinner spins forever. OCR has explicit `.timeout(const Duration(seconds: 30))` at `ocr_extraction_service.dart:421` — recipe parsing should too.

### Proposed Improvement
Add `.timeout(Duration(seconds: 45))` (or whatever the Cloud Function's own timeout is + 5s buffer) with a friendly error: "This is taking longer than usual. Try again, or import the text manually." Add a retry button.

### Effort vs Impact
Tiny / high. One-line fix prevents app-locked-forever bug.

---

## 21. Differentiate LLM extraction error types

**Labels:** `bug`, `import`, `parsing`
**Priority:** Medium
**State:** Triage

### Finding
`lib/viewmodels/photo_import_viewmodel.dart:546-569` + `lib/services/ocr/ocr_extraction_service.dart:294-402` — multi-provider OCR fallback catches all exceptions in `failureResult` at line 384-401, which always shows "try better lighting or manual input". Wastes the user's time re-photographing when the actual cause was a rate limit, timeout, or network drop.

### Proposed Improvement
Distinguish:
- Rate limit / quota → "Please wait a minute and retry."
- Timeout → "Couldn't reach the parser — check your connection."
- Image unreadable / low confidence → existing "try better lighting" message.
- Generic → "Something went wrong on our side."

Log which provider in the cascade actually failed (line 349-366 currently swallows that).

### Effort vs Impact
Small / medium.

---

## 22. Surface auth-token expiry to the user

**Labels:** `bug`, `account`
**Priority:** Medium
**State:** Triage

### Finding
`lib/services/auth/auth_service.dart:46-74` — when the auth stream emits an error, `forceSignOut()` is called silently. User is mid-recipe-edit, token expires, save fails, no toast, no explanation. They retry, still fails because they're logged out, and only notice when they navigate to a route that demands login.

### Proposed Improvement
On forced sign-out due to token expiry:
- Show a toast: "Your session expired. Please sign in again."
- Preserve current in-flight form state (depends on #1) so the user can resume after re-auth.

### Effort vs Impact
Small / medium.

---

## 23. Friendly error messages for Firestore permission-denied

**Labels:** `bug`, `backend`
**Priority:** Medium
**State:** Triage

### Finding
`lib/services/unified/operations/personal_recipe_operations.dart:54-77` — generic `catch (e)` block surfaces "Failed to add recipe: $e" with the raw `FirebaseException` string when a Firestore rule rejects a write. Users see a cryptic technical error and don't know it's a permissions issue (e.g. trying to edit a recipe they don't own).

### Proposed Improvement
Centralised error mapper: detect `FirebaseException(code: 'permission-denied')` and map to a friendly message ("You don't have permission to edit this — ask the owner to share write access"). Apply across all repositories.

### Effort vs Impact
Small / medium.

---

## 24. Friendly handling of Storage quota exceeded

**Labels:** `bug`, `backend`
**Priority:** Medium
**State:** Triage

### Finding
`lib/services/storage/storage_service.dart:57-99` — `uploadImage()` returns `null` silently on quota / size errors. Caller throws a generic "Upload failed" with no hint about cause. User can't tell if it's a network glitch or that they need to free up space.

### Proposed Improvement
Inspect the Firebase Storage error code:
- `storage/quota-exceeded` → "You've hit your photo limit. Delete some recipes' images to upload more."
- `storage/unauthorized` → permission error path (#23).
- `storage/canceled` / network → "Upload failed. Tap to retry." with retry button.

### Effort vs Impact
Small / medium.

---

## 25. Make malformed-import errors specific

**Labels:** `idea`, `import`, `parsing`
**Priority:** Low
**State:** Triage

### Finding
- `lib/viewmodels/url_import_viewmodel.dart:209-237` — `getUrlValidationErrors()` returns the same "Invalid URL format" for empty input, gibberish, and unsupported schemes.
- `lib/viewmodels/text_import_viewmodel.dart:334-347` — text validation only checks length >10 chars, doesn't catch obvious gibberish.

### Proposed Improvement
URL: distinguish "empty", "not a URL", "unsupported scheme", "unreachable host" with specific messages.

Text: detect obvious non-recipe input (no measurement words, no verbs) and warn before sending to the LLM ("This doesn't look like a recipe — import anyway?").

### Effort vs Impact
Small / low. Saves wasted LLM calls.

---

## 26. Friends-tab empty state needs first-touch onboarding

**Labels:** `idea`, `social`
**Priority:** Medium
**State:** Triage

### Finding
`lib/views/social/friends_list/friends_tab.dart` uses the generic `StateWidget.noFriends()` factory (`state_widget.dart:166`) — no branded illustration, no "Invite friends" CTA, no explanation of why a user might want friends in a recipe app.

### Proposed Improvement
Custom empty-state widget mirroring `MinaReceptEmptyState` (`mina_recept/empty_state_widgets.dart:23`):
- Branded illustration (mushroom or pea pod from the existing set).
- Headline: "Cook together with friends."
- Subtitle: "Share recipes, see what they're cooking, plan menus together."
- Primary CTA: "Invite a friend".
- Secondary CTA: "Find friends by username".

### Effort vs Impact
Small / medium. First impression of social = biggest churn point for that feature.

---

## 27. Groups-tab empty state needs first-touch onboarding

**Labels:** `idea`, `social`
**Priority:** Medium
**State:** Triage

### Finding
No dedicated empty-state widget for the groups tab; falls back to plain text. No illustration, no "Create group" CTA.

### Proposed Improvement
Mirror the friends-tab solution (#26). Headline: "Group cooking, simpler." CTA: "Create a group". Secondary: explanation of group menus + collaborative shopping.

### Effort vs Impact
Small / medium.

---

## 28. Social-feed empty state needs first-touch hint

**Labels:** `idea`, `social`
**Priority:** Low
**State:** Triage

### Finding
`lib/views/social/friends_list/feed_tab.dart:31` — `LoadingStateBuilder` with `emptyTitle` + `emptyIcon` shows a generic icon when the feed is empty. No "follow friends to see their activity" hint for new users.

### Proposed Improvement
Differentiate two empty-state cases:
- No friends yet → "Add friends to see their cooking activity here." → CTA jumps to friends tab.
- Has friends but no activity yet → "Quiet so far. Be the first to share a recipe."

### Effort vs Impact
Small / low.

---

## 29. Replace generic icons with branded illustrations on remaining empty-state factories

**Labels:** `idea`, `settings`
**Priority:** Low
**State:** Triage

### Finding
Brand has illustrated empty states (broccoli, carrot, mushroom, pea pod) in `lib/widgets/common/state/empty_states.dart`, used for recipes and shopping. Tags, notifications, comments, search, and feed all fall back to generic Material icons via `StateWidget.empty(icon: ...)`.

### Proposed Improvement
Add factories using the existing illustrations: `StateWidget.noTags()`, `StateWidget.noNotifications()`, `StateWidget.noComments()`, `StateWidget.noSearchResults()`. Visual polish only — no behavioural change.

### Effort vs Impact
Small / low.

---

## Reference index

Ordered by recommended sequencing within each theme.

### Theme 1 — Draft loss (blocked on epic #1)

| # | Title | Priority |
|---|---|---|
| 1 | EPIC — Reusable AutoSaveManager | High |
| 7 | Persist recipe-list filter and scroll state | High |
| 8 | Don't wipe parsed recipe on parse error | High |
| 2 | Persist photo-import draft | Medium |
| 3 | Persist URL-import draft | Medium |
| 4 | Persist text-import draft | Medium |
| 5 | Persist comment-composer draft | Medium |
| 6 | Persist group-creation form draft | Medium |

### Theme 2 — Destructive actions / no undo (most blocked on epic #9)

| # | Title | Priority |
|---|---|---|
| 9 | EPIC — Soft-delete + trash recovery | High |
| 10 | Recipe single-delete undo | High |
| 11 | Tag delete undo + cascade preview | High |
| 12 | Recipe photo delete undo | Medium |
| 13 | Menu "Clear week" undo | Medium |
| 14 | Cook-snap delete undo | Medium |
| 16 | Easier rejoin after unfriend/leave-group | Low |
| 15 | Comment delete undo | Low |
| 17 | Investigate: account-deletion grace period | Low |

### Theme 3 — Silent failures

| # | Title | Priority |
|---|---|---|
| 18 | Heirloom photo upload orphan — block success until upload lands | High |
| 19 | Sync conflict resolution visible to user | High |
| 20 | Client-side timeout on recipe parse | High |
| 21 | Differentiate LLM extraction error types | Medium |
| 22 | Surface auth-token expiry | Medium |
| 23 | Friendly permission-denied messages | Medium |
| 24 | Friendly storage-quota messages | Medium |
| 25 | Specific malformed-import errors | Low |

### Theme 4 — Empty states / first-touch UX

| # | Title | Priority |
|---|---|---|
| 26 | Friends-tab onboarding empty state | Medium |
| 27 | Groups-tab onboarding empty state | Medium |
| 28 | Social-feed empty-state hint | Low |
| 29 | Branded illustrations on remaining empty states | Low |

---

## Cross-batch dependency notes

- **#1 → #2-7**: per-surface autosave tickets depend on the AutoSaveManager epic landing first.
- **#9 → #10-14**: per-action undo tickets benefit massively from the soft-delete epic. Each could be done with a session-only snackbar as a stopgap, but the long-term home is in the trash subsystem.
- **#22 (auth-expiry feedback)** benefits from #1 — once form state survives a forced sign-out, the resume-after-reauth flow becomes possible.
- **#19 (sync-conflict visibility)** is independent but the per-recipe edit-history follow-up could share infra with the trash-restore history view from #9.
