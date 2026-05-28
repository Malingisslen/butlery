# Linear Bug Tickets Audit — 2026-05-28

Audit covered 38 tickets (excludes BUT-892, BUT-1086 in progress). Most were silently swept by recent commits.

## Parsing/LLM batch (BUT-512 → BUT-616)

### BUT-512 DELETE — LLM amount validation range too loose
**Evidence:** Linear status=Done, archivedAt 2026-05-03, completed 2026-05-03 17:45.
**Reason:** Closed; archived. Stale ticket reference.
**Action:** delete (already archived — no Linear action required).

### BUT-516 DELETE — Unknown units pass through LlmTier
**Evidence:** Linear status=Done, archived 2026-05-03.
**Action:** delete (already archived).

### BUT-522 DELETE — Description length spec drift
**Evidence:** Linear status=Done, archived 2026-05-21.
**Action:** delete (already archived).

### BUT-528 DELETE — No length cap on LLM instruction array
**Evidence:** Linear status=Done, archived 2026-05-03.
**Action:** delete (already archived).

### BUT-534 DELETE — scrubUrlParams swallows fragment
**Evidence:** Linear status=Done, archived 2026-05-21.
**Action:** delete (already archived).

### BUT-546 DELETE — validateDifficulty silently drops
**Evidence:** Linear status=Done, archived 2026-05-04.
**Action:** delete (already archived).

### BUT-577 DELETE — parseIngredientLines partial-array recovery
**Evidence:** Linear status=Done, archived 2026-05-02.
**Action:** delete (already archived).

### BUT-582 DELETE — LlmException maps deadline-exceeded == unavailable
**Evidence:** Linear status=Done, archived 2026-05-21.
**Action:** delete (already archived).

### BUT-586 DELETE — ValidationUtils coverage audit
**Evidence:** Linear status=Done, archived 2026-05-04.
**Action:** delete (already archived).

### BUT-595 DELETE — Entity not found
**Evidence:** Linear API returned `Entity not found: Issue` for BUT-595.
**Reason:** Already deleted/archived.
**Action:** none (gone).

### BUT-606 DELETE — Include promptVersion in ParseEventLogger
**Evidence:** Done, archived 2026-04-29.
**Action:** delete (archived).

### BUT-611 DELETE — Viterbi confidence calibration
**Evidence:** Done, archived 2026-04-30.
**Action:** delete (archived).

### BUT-616 DELETE — logParseEvent silently swallows failures
**Evidence:** Done, archived 2026-05-21.
**Action:** delete (archived).

## Wave-12+ batch (BUT-893 → BUT-973)

### BUT-893 DELETE — Recipe deletion orphans weekly-menu entries
**Evidence:** Done 2026-05-22, archived.
**Action:** delete (archived).

### BUT-894 DELETE — Recipe deletion orphans shared-content
**Evidence:** Done 2026-05-27 (not yet archived but completedAt is set).
**Action:** delete (closed; let auto-archive sweep).

### BUT-897 DELETE — Group deletion doesn't scrub group IDs
**Evidence:** Linear status=Canceled 2026-05-27.
**Action:** none (already canceled).

### BUT-899 DELETE — Unit converter handles negative quantities inconsistently
**Evidence:** Done 2026-05-24, archived 2026-05-25. Commit `1249b01f6 fix(iter-55): make unit-converter threshold-checks sign-symmetric (BUT-899)`.
**Action:** delete (archived).

### BUT-924 DELETE — Don't wipe parsed recipe on parse error
**Evidence:** Done 2026-05-22, archived 2026-05-22.
**Action:** delete (archived).

### BUT-926 DELETE — Make recipe seeding synchronous
**Evidence:** Done 2026-05-23, archived 2026-05-23.
**Action:** delete (archived).

### BUT-953 KEEP/IMPROVE — Heirloom upload is dead code
**File:line evidence:** `lib/viewmodels/photo_import_viewmodel.dart:311` `Future<HeirloomMetadata?> uploadHeirloomImage(...)` exists but `grep uploadHeirloomImage` returns only that one file — **zero callers** confirm in `lib/`. Ticket premise verified live.
**Reason:** Real bug, still unresolved. Ticket body is already well-scoped (re-scoped 2026-05-22 with Step 0 verification).
**Action:** **KEEP as-is**. Title and scope are precise; ready to implement. Priority could be bumped (currently Medium) — it's not just a bug, it's a feature-completion gap that silently nukes heirloom metadata on every photo save.

**Sharper title suggestion (optional):**
> `Heirloom photo metadata never persists — wire uploadHeirloomImage into photo-import save flow`

### BUT-958 KEEP/MERGE INTO BUT-1031 — Sync conflict resolution visibility
**File:line evidence:** `lib/services/realtime_sync_service.dart:51` declares `_errorController` (SyncError only); `:319` `resolveConflict<T>` does last-write-wins; **no** `ConflictEvent` / `conflictStream` exists (grep returned zero matches across `lib/services/realtime`).
**Reason:** Real bug, still live. But BUT-1031 is the **deferred follow-up** with the same scope plus concrete architecture (CollaborativeConflictEvent + banner widget). Two tickets cover identical work.
**Action:** **merge BUT-958 INTO BUT-1031** (BUT-1031 is the better-scoped one); close BUT-958 with reference.

### BUT-960 DELETE — Client-side timeout on parse Cloud Function
**Evidence:** Done 2026-05-22, archived 2026-05-22.
**Action:** delete (archived).

### BUT-963 DELETE — Differentiate LLM extraction error types
**Evidence:** Done 2026-05-23, archived 2026-05-23.
**Action:** delete (archived).

### BUT-966 DELETE — Surface auth-token expiry
**Evidence:** Done 2026-05-23, archived 2026-05-23.
**Action:** delete (archived).

### BUT-968 DELETE — Friendly error messages for permission-denied
**Evidence:** Done 2026-05-23, archived 2026-05-23.
**Action:** delete (archived).

### BUT-971 DELETE — Friendly handling of Storage quota
**Evidence:** Done 2026-05-23, archived 2026-05-23.
**Action:** delete (archived).

### BUT-973 DELETE — Make malformed-import errors specific
**Evidence:** Done 2026-05-24, archived 2026-05-25.
**Action:** delete (archived).

### BUT-1031 KEEP/IMPROVE — Sync conflict banner needs ConflictEvent stream
**File:line evidence:** Verified live — `realtime_sync_service.dart:319` `resolveConflict<T>` runs last-write-wins, no event broadcast. `_errorController` is for SyncError only, not conflicts.
**Reason:** Real, well-scoped High-priority bug ticket. Acceptance criteria already concrete.
**Action:** **KEEP**. Also absorb BUT-958's scope here (de-dup).

**Sharper title:**
> `Collaborative-edit conflicts silently overwrite — emit ConflictEvent + surface banner`

## Draft-persistence rollup (BUT-904 EPIC + children)

### BUT-904 KEEP — EPIC reusable AutoSaveManager
**File:line evidence:** No `AutoSaveManager` exists. `lib/viewmodels/recipe_form/recipe_auto_save_manager.dart` is recipe-specific (`RecipeFormState`-coupled); not generic. Grep for `AutoSaveManager|auto_save_manager` matches 6 files all in recipe-form / comment-form scope.
**Reason:** Epic premise verified — no generic facade exists. **However**, 4 of 6 children (BUT-911, 915, 917, 919) have shipped as one-off per-surface persistence without the abstraction. The epic's value (the abstraction) is now half-spoken-for.
**Action:** **KEEP but re-scope.** The "reusable AutoSaveManager" abstraction is now a refactor of already-shipped per-surface persistence rather than a foundation. Rewrite scope: "Extract shared autosave abstraction from recipe + URL + text + comment + group drafts."

**Sharper title:**
> `EPIC: Extract shared AutoSaveManager from per-surface draft persistence (recipe/URL/text/comment/group)`

### BUT-910 KEEP — Persist photo-import draft
**File:line evidence:** `lib/viewmodels/photo_import_viewmodel.dart:397-415` `clearPhoto()` still wipes `_imageBytes` (line 400) and `_ocrText` (line 401). No on-disk persistence. Ticket premise valid.
**Reason:** Only remaining unshipped child of BUT-904. Photo-bytes persistence needs special handling (gzipped temp file, not SharedPreferences).
**Action:** **KEEP**. Sibling of done BUT-911/915/917/919.

### BUT-911 DELETE — URL-import draft
**Evidence:** Done 2026-05-24, commit `feb2622ba feat(iter-49): persist URL-import draft across navigation (BUT-911)`.
**Action:** delete (archived).

### BUT-915 DELETE — Text-import draft
**Evidence:** Done 2026-05-24, commit `f5e291cfd feat(iter-48): persist text-import draft across navigation (BUT-915)`.
**Action:** delete (archived).

### BUT-917 DELETE — Comment-composer draft
**Evidence:** Done 2026-05-24, commit `ae4b25143 feat(iter-47): persist comment-composer draft per recipe (BUT-917)`.
**Action:** delete (archived).

### BUT-919 DELETE — Group-creation form draft
**Evidence:** Done 2026-05-24, commit `744624eb9 feat(iter-50): persist group-creation form draft (BUT-919)`.
**Action:** delete (archived).

### BUT-921 DELETE — Recipe-list filter and scroll state
**Evidence:** Done 2026-05-23, archived 2026-05-23.
**Action:** delete (archived).

## Undo / Trash-recovery rollup (BUT-907 EPIC + children)

### BUT-907 KEEP/IMPROVE — EPIC soft-delete + trash recovery
**File:line evidence:** No `trash` collection / `deletedAt` TTL pattern in `lib/services/`. Ticket premise valid.
**Reason:** Most children have shipped as **per-surface snackbar undo** (BUT-927/929/932/937/943/702 all Done) — i.e., the cheap option. The persistent-trash + restore subsystem was never built.
**Action:** **KEEP but re-scope** — the urgency dropped (snackbars cover the panic case). Reframe as "Trash & Recovery view for users who want >7-second recovery window" — much lower priority. Consider downgrading from High to Medium/Low or marking as `future` / `idea`.

**Sharper title:**
> `EPIC: Trash & Recovery view (persistent undo beyond 7-second snackbars)`

### BUT-927 DELETE — Recipe single-delete undo
**Evidence:** Done 2026-05-22, archived 2026-05-22.
**Action:** delete (archived).

### BUT-929 DELETE — Tag delete undo + cascade preview
**Evidence:** Done 2026-05-22, archived 2026-05-22.
**Action:** delete (archived).

### BUT-932 DELETE — Recipe photo deletion undo
**Evidence:** Done 2026-05-23, archived 2026-05-25. Commit `27e8ee6df feat(wave-17): … photo-delete undo`.
**Action:** delete (archived).

### BUT-935 KEEP — Menu plan "Clear week" needs undo
**File:line evidence:** `lib/viewmodels/menu/weekly_menu_plan_viewmodel.dart:180` `_service.clearWeek(current)` followed by direct `_plan = cleared`. No undo path or snackbar. `lib/services/menu/weekly_menu_plan_service.dart:418` `clearWeek` returns empty entries — destructive. Verified premise.
**Reason:** Only un-shipped child of BUT-907. High-friction action (5 minutes' planning lost on misclick).
**Action:** **KEEP**. Snackbar stopgap is half-day; pair with BUT-907 if/when trash subsystem lands.

**Sharper title:**
> `Menu plan "Rensa veckan" needs 7s snackbar undo (no recovery currently)`

**Tightened fix:** Capture `current.entries` before `clearWeek`; show snackbar with action that calls `_service.setWeekEntries(captured)` or equivalent restore.

### BUT-937 DELETE — Cook-snap delete undo
**Evidence:** Done 2026-05-24, archived 2026-05-25. Commit `a891ee724 feat(iter-59): cook-snap delete gets confirm + 7s snackbar undo (BUT-937)`.
**Action:** delete (archived).

### BUT-943 DELETE — Comment delete undo
**Evidence:** Done 2026-05-24, archived 2026-05-25. Commit `11b0d7afc feat(comments): 7s undo snackbar on own-comment delete (BUT-943)`.
**Action:** delete (archived).

### BUT-702 DELETE — A11y: undo SnackBar for destructive actions
**Evidence:** Done 2026-05-06, archived 2026-05-21.
**Action:** delete (archived).
