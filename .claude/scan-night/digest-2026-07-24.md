# Scan Night Digest — Butlery, 2026-07-24

Real overnight run (the previous digest here was a 10-minute mechanics smoke test from
2026-07-09 and is superseded). Six scoped area scanners plus the deterministic hygiene
gates. Nothing was filed without being re-verified against the code in the main session.

## 1. Census

**14 distinct verified issues filed.** All 14 were confirmed by opening the cited file and
reading the code — none are inferred.

By severity: 1 Urgent, 3 High, 6 Medium, 4 Low.

By class:
- **Measured** (a deterministic tool produced the finding): 2 — the large-file inventory
  drift (`tools/count_large_files.sh`) and the dependency lag (`flutter pub outdated`).
- **Confirmed at file:line** (read and reasoned, failure path stated): 12.
- **Anchored-but-judged** (feature gaps needing product sign-off): 0. No new unticketed
  roadmap anchors were found — every unchecked item in
  `PIPELINE_IMPROVEMENT_ROADMAP.md` already carries a BUT- id except the GlobalRecipeCache
  write-back, which is an explicitly accepted deferral in that document.

By area: shopping 4, recipe 3, backend 3, menu 2, account 2, analytics 2, import 1,
parsing 1, tagging 1, social 2 (tickets carry multiple area labels, so these overlap).

Clean gates: `dart analyze --fatal-infos` — no issues. Cloud Functions `npm test` — passed.

## 2. Tickets filed, worst first

### Verified — safe to fix without a product decision

| Ticket | Sev | What |
|---|---|---|
| BUT-1663 | Urgent | Household allergen union silently drops a member whose profile read fails — the weekly menu can under-filter an allergen with no signal to anyone |
| BUT-1661 | High | `looksLikeIngredient` can never match `ägg` (Dart's ASCII word boundary) — headerless text imports silently drop unitless egg lines, producing a false "fritt från ägg" |
| BUT-1664 | High | `sendNotificationBatch` charges the wrong rate-limit bucket and 1 token per 100 pushes — its dedicated stricter config is dead code |
| BUT-1665 | High | Collaborative shopping-list edits overwrite the whole items array from a stale local cache — concurrent household ticks are silently lost |
| BUT-1662 | Medium | GDPR export falsely stamps `truncated: true` on ~15 sections; the BUT-1562 fix was applied to one call site only |
| BUT-1666 | Medium | `IngredientCategorizer` substring collisions: nuts → meat, "rostad" → dairy, paprika and coconut milk in the wrong aisle |
| BUT-1667 | Medium | `RecipeFormState.dispose()` no longer disposes its three `FormFieldsManager`s — text controllers leak on every recipe form close |
| BUT-1668 | Medium | Weekday pins ignore the today-anchor and can place a recipe on a day that has already passed |
| BUT-1669 | Medium | A queued concurrent recipe save double-completes its `Completer` and throws `StateError` out of `saveRecipe` |
| BUT-1670 | Medium | Shopping analytics: the menu-generated flow fires nothing, recipe bulk-adds log as "manual", unchecks log as checks |
| BUT-1671 | Low | Two scheduled sweeps can silently strand work at scale — family purge has no persisted cursor, lapsed-user detection has no query limit |
| BUT-1672 | Low | `addItemsFromRecipe`'s dedup-and-merge branch is unreachable — bulk recipe adds always duplicate |
| BUT-1673 | Low | Large-file inventory drifted to 8 unlisted files; `lib/app/butlery_app.dart` at 861 lines never had a rationale row |
| BUT-1674 | Low | Five direct dependencies a full major behind with no pin rationale (the documented pins are fine and were excluded) |

### Proposed — needs your call

None this run. Both anti-fabrication gates were applied and no feature-gap candidate
cleared the anchor requirement, so nothing speculative was filed.

## 3. Rejected, and why

- **NFC vs NFD normalization in the voice→text→parse pipeline** — no normalization step
  exists anywhere in that chain, which is suspicious, but the scanner could not confirm
  that the on-device transcriber actually emits decomposed Swedish characters. Unconfirmable
  → discarded rather than filed as a guess.
- **A second and third interpolated `\b` word-boundary site** (`recipe_text_normalizer.dart`,
  `ingredient_line_detector.dart`) — checked every word in both lists; all begin and end with
  ASCII characters, so the ASCII-boundary bug does not apply. Only `ägg` is affected. Filed
  the one real site, not the pattern.
- **GlobalRecipeCache retag write-back** — an unchecked roadmap item with no ticket, but the
  roadmap records it as a conscious "accepted for now, revisit before user growth" decision
  under a documented no-pre-filed-tickets convention. Not a gap.
- **Everything listed in `.claude/rules/accepted-deviations.md`** — pooled-ratings edge cases,
  the no-edit-detachment design, presence not scoping menu generation, draft-ingredient FREE
  authority, `socialFeatures` consent, parse_events retention, cook_snaps age gating. Each
  scanner was briefed on these and none re-flagged them.

## 4. Where it stopped

Stopped on **budget**, not dryness — this run is one repo of a three-repo scheduled sweep
with a per-repo token slice, and Butlery's slice was spent after one full pass.

Coverage of that pass was complete across all eleven area labels: every area was scanned by
one of the six agents, plus the four hygiene checks. What a further pass would add:

- A second pass over the same areas (the stop condition in the skill is two consecutive
  nothing-new passes; only one pass ran, so dryness is unproven).
- `lib/widgets/` and `lib/views/` beyond the specific screens each agent covered — the
  scanners were pointed at services, viewmodels and repositories.
- The full `flutter test` suite as a hygiene gate. It was deliberately skipped: it is
  compile-bound at roughly twelve minutes per invocation and CI already runs it. `dart
  analyze` and the Cloud Functions suite were run and both passed.
- `functions/src/` families the backend agent did not reach: parts of `social/`,
  `notifications/` beyond `send-notification.ts`, and `storage/`.

## 5. Resume pointer

A resumed run should start with a **second pass over shopping and analytics** — they were
the backlog blind spots going in and produced six of the fourteen findings, which suggests
the seam is not exhausted. Then `lib/widgets/` and `lib/views/`, which no agent covered
systematically this pass.
