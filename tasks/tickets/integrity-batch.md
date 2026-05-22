# Linear Ticket Drafts — Integrity & Correctness Audit (2026-05-22)

> Paste-ready ticket bodies. Linear MCP was not connected when these were prepared, so they have not been created in Linear yet. Each section is one ticket. Separator `---` marks ticket boundaries.

Findings from the fifth audit sweep. After 109 tickets in earlier batches, this sweep deliberately applied a high quality bar: only flag findings with concrete evidence + real impact + actually-would-fix-it. **Two of three lenses came back nearly clean** — that is the headline, not a non-finding. Five tickets total below.

---

# Theme 1 — Recipe-delete cascade (orphan data)

The recipe deletion path in `lib/services/unified/modules/service_adapters/recipe_service_adapter.dart:71-84` cleans up its own comments, ratings, social-stats aggregate, and storage images. **It does not clean up records owned by other users that point back to this recipe.** Three concrete orphans.

## 1. Recipe deletion orphans cook snaps posted by other users

**Labels:** `bug`, `recipe`, `social`
**Priority:** High
**State:** Triage

### Finding
`lib/services/unified/modules/service_adapters/recipe_service_adapter.dart:101-147` (`_cleanupRecipeReferences`) cleans comments and ratings but not cook snaps. Concrete scenario:
1. User A creates Recipe R.
2. User B (with access via share) posts a cook snap on Recipe R.
3. User A deletes Recipe R.
4. Result: `cook_snaps/{snapId}` document persists in Firestore with `recipeId` pointing to a deleted recipe. User B's snap can't render anywhere — it references a 404.

Cook snaps by the recipe owner ARE cleaned up indirectly when the owner's account is deleted (`account_deletion_service.dart:171`), but **not when the recipe is deleted while the owner stays active**.

### Proposed Improvement
Add a paginated cleanup loop in `_cleanupRecipeReferences`, mirroring the comment / rating cleanup pattern (lines 107-136):

```dart
// Cook snaps cleanup
await _paginatedDelete(
  firestore.collection('cook_snaps'),
  query: (q) => q.where('recipeId', isEqualTo: recipeId),
);
```

### Effort vs Impact
Trivial / medium. Concrete data-integrity bug with a clear fix.

---

## 2. Recipe deletion orphans weekly-menu entries

**Labels:** `bug`, `recipe`, `menu`
**Priority:** High
**State:** Triage

### Finding
Same file, same gap. Weekly menu plans store `entries[].recipeId` (`lib/services/menu/weekly_menu_plan_service.dart`). When the source recipe is deleted, those entries are not removed — users see blank slots in their menu, or taps that 404. Visible breakage, not just hidden data.

### Proposed Improvement
On recipe delete, query weekly menu plans that contain the recipe ID and either:
- (a) Remove just the affected entry (preferred — keeps the rest of the user's plan intact).
- (b) Show a tombstone "Recipe deleted — pick a replacement" in the slot.

(a) is cheap with a `FieldValue.arrayRemove` against the entries array, or a small denormalised index `menu_entry_index/{recipeId}` listing affected plans. Decide based on how many plans typically reference one recipe — for most users, a single fan-out query is fine.

### Effort vs Impact
Small / high. User-visible: blank menu slots are a clear bug, and recipe deletion is a frequent action.

---

## 3. Recipe deletion orphans shared-content records

**Labels:** `bug`, `recipe`, `social`
**Priority:** Medium
**State:** Triage

### Finding
`shared_content` documents carry `originalRecipeId`. When that recipe is deleted, the share record remains. Detail-view fetches fail; "my shared recipes" lists return broken references. Lower user-visible impact than #2 because shared-content fetches degrade gracefully, but it's still a real integrity violation — and clutters the user's "shared with me" lists.

### Proposed Improvement
Extend `_cleanupRecipeReferences` to delete `shared_content` documents where `originalRecipeId == recipeId`. Mind the recipient side: the share record's `members` subcollection should be deleted as part of the same operation.

This is also a natural caller for the robustness-batch #9 soft-delete epic — if recipes go to trash instead of being purged, shared-content records can stay valid until the trash TTL fires.

### Effort vs Impact
Small / medium. Pair with #1 and #2 in a single "recipe-delete cascade fix" commit.

---

# Theme 2 — Group-delete cascade (theoretical orphans)

## 4. Group deletion doesn't scrub group IDs from shared content

**Labels:** `bug`, `social`
**Priority:** Low
**State:** Triage

### Finding
`lib/services/unified/operations/friend_categories_operations.dart` deletes the category doc and removes local state, but doesn't scrub group IDs from `shared_content` documents that targeted the group. Same applies to any group-scoped weekly menu / shopping list (no cleanup path was found).

The data agent flagged this as **theoretical** — the UI doesn't show broken group refs and group deletion is rare. So the user impact today is near-zero. **But** if future features surface group-targeted shares (e.g. "group activity feed"), the orphans will become visible all at once.

### Proposed Improvement
Either:
- (a) Now: extend the group-delete operation to scrub group IDs from shared content and group-scoped menus / shopping lists.
- (b) Later: rely on the soft-delete epic to keep group records around in a deleted state, and update reads to skip soft-deleted groups.

(b) is consistent with the rest of the soft-delete strategy and avoids one-off cleanups. Sequence behind robustness-batch #9.

### Effort vs Impact
Small / low. Defensive — prevents a class of bugs that would surface if group-targeted features grow.

---

# Theme 3 — Business logic correctness

## 5. Unit converter handles negative quantities inconsistently between mass and volume

**Labels:** `bug`, `parsing`, `recipe`
**Priority:** Low
**State:** Triage

### Finding
`lib/utils/text/unit_converter.dart:162-166` — the gram branch normalises with `.abs()` (so `-500 g` becomes `0.5 kg`), but the volume branch (ml / cl / dl) doesn't (`-500 ml` stays `-500 ml`, no conversion). Negative quantities shouldn't appear in valid inputs, but:

- Engineering-batch #21 already proposes validating ingredient quantities as non-negative. Until that lands, the converter is the last line of defense.
- The asymmetry violates principle of least surprise — gram-based and volume-based ingredients behave differently for the same edge case, which can mask upstream parse bugs.

### Proposed Improvement
Apply `.abs()` consistently across all unit-conversion branches in `unit_converter.dart`. Or — better — reject negative inputs at the converter entry point with a clear error, and rely on engineering-batch #21's validator to prevent them upstream.

### Effort vs Impact
Trivial / low. Defensive consistency fix. Low priority but cheap.

---

## Reference index

| # | Title | Theme | Labels | Priority |
|---|---|---|---|---|
| 1 | Recipe-delete orphans cook snaps (other users') | Cascade | bug, recipe, social | High |
| 2 | Recipe-delete orphans weekly-menu entries | Cascade | bug, recipe, menu | High |
| 3 | Recipe-delete orphans shared-content records | Cascade | bug, recipe, social | Medium |
| 4 | Group-delete orphans group refs in shared content | Cascade | bug, social | Low |
| 5 | Unit converter: inconsistent negative handling (mass vs volume) | Logic | bug, parsing, recipe | Low |

Bundle tickets #1, #2, #3 into a single "recipe-delete cascade fix" change — same file, same pattern, same test setup.

---

## What's confirmed clean (the headline of this sweep)

Two of three lenses produced **zero actionable findings**. This is itself useful information after 109 earlier tickets — it tells you where the codebase doesn't need investment.

### Security & abuse-vector surface — clean
- **File uploads** validate magic bytes server-side (`functions/src/llm/moderate-upload.ts`), not just file extension. SVG-renamed-to-jpg blocked.
- **Firestore rules** have per-operation rate limiters (`rateLimitWrite()`: comments 5s, recipes 10s, messages 5s, friend requests 10s) + structural validation on `tagResult` and user ingredients + 60-minute account-maturity gate (BUT-659) blocking new accounts from mass-friending until verified.
- **Cloud Functions** uniformly wrap callables with `withRateLimit()` (requires `request.auth`) + `enforceAppCheck: true` for device attestation. No unauthenticated mutating callables found.
- **Secrets** correctly handled — Firebase API keys are the public domain-restricted kind; OCR keys come from `String.fromEnvironment()` at build time.
- **Moderation infrastructure** complete: `ReportService` → admin review view → soft-delete + user-hide flag wired through rules.

### Business logic correctness — mostly clean
- **Portion scaling** lossless under integer scale-down round-trips (verified via `TextFormatting.formatFractional` → `.toStringAsFixed(2)`).
- **Ingredient parser** "och" compound inheritance guard works (regex `^\d|^[½¼¾⅓⅔⅛⅜⅝⅞]` correctly detects explicit quantities in the second clause).
- **Duration parser** uses upper bound of ranges intentionally (`"10-15 min"` → 15 min) — documented, not a bug.
- **Shopping-list consolidation** sums quantities correctly per key; "first occurrence wins" for display key is a design choice, not an error.
- **OCR confidence** uses a global text-quality heuristic, not per-line aggregation — but the docstring promise is misleading rather than a real bug.

### User-account deletion cascade — clean
`account_deletion_service.dart:110-273` (verified):
- Recipes, menus, shopping lists, personal tags, cook snaps, activity events, weekly menu plans, pantry items, friend connections (symmetric, transactional), messages, shared content (both as owner and recipient — `FieldValue.arrayRemove` from `sharedToUserIds`), comments & ratings (anonymised or deleted), pings, reports, notifications — all cascade cleanly.
- Audit log retained 180 days per GDPR.
- Residual-data probe runs post-delete to catch regressions (line 221).

### Friend-removal cascade — clean
`friend_relationship_repository.dart:234-259` — symmetric transactional delete of both directions of the friendship + atomic decrement of `friendsCount` on both users.

### Shared-content recipient-deletion cascade — clean
`social_deletion_operations.dart:158-181` — recipient atomically scrubbed from all `sharedToUserIds` arrays and all `members` subcollection docs deleted.

---

## Sweep #5 verdict

After 109 tickets across four previous sweeps, this sweep produced **5 tickets**: three real orphan-data bugs (recipe-delete cascade gaps), one theoretical (group-delete), and one defensive consistency fix (unit converter). The discipline of the high-bar threshold paid off — the alternative (loose threshold) would have produced 20+ low-value tickets and diluted the signal.

The findings that *aren't* tickets are themselves the audit result: security, user-deletion cascade, friend-removal cascade, and most business-logic math are all genuinely well-built. Those are areas where investment is not warranted right now.
