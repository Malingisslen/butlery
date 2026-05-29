# Sprint Backlog

## Sprint: iter-103 — 4 code-only tech-debt tickets (PLANNED, not yet implemented) — 2026-05-29 (Fri)

**Status: PLANNED ONLY.** Selection done in a long session; implementation deferred to a fresh session for quality. All 4 transitioned to "Todo" in Linear. None are risk-gated (all P3/P4 tech-debt, no security/Bug → no Phase 1.5 expansion). Ops-blocked tickets (App Check client BUT-1166, AI ops BUT-1167, store/deploy/MFA) and EPICs were deliberately excluded.

**Fresh session: re-run Step 0 per ticket** (`get_issue` for the full description — the lines below are summaries; current code-read wins over ticket text).

### Batch A — backend / realtime (independent files)

- [ ] **A1. BUT-1165: iter-99 review follow-ups** — apply the non-blocking code-reviewer / testing-specialist findings deferred from iter-99 (BUT-1099, 1101, 1133, 1152, 1106, 1110, …). `get_issue BUT-1165` for the full finding list; scattered across the iter-99 touched files. (BUT-1165, P3)
- [x] **A2. BUT-472: audit `lib/services/unified/modules/realtime_session_manager.dart`** — DONE (iter-103a). Premise re-scoped: file is a stateless static helper; maps owned by `RealtimeRecipeModule`; dispose chain (`UnifiedRecipeService.dispose` → `module.dispose` → `RealtimeCacheManager.dispose`) is complete + tested at every layer. No leak. Added a module-level leak guard asserting `dispose()` leaves zero outstanding handles across all 3 maps. (BUT-472, P3)

### Batch B — tech-debt / data

- [ ] **B1. BUT-520: migrate 3 standalone ViewModels from `ChangeNotifier` → `BaseViewModel`** — pick 3 simple standalone VMs (NOT the 6 heavy priority ones unless clean). Map loading/error/dispose to the base; verify no behavioural regression; update tests. (BUT-520, P4)
- [x] **B2. BUT-1164: migrate legacy `meatFish`/`fruitVeg` shopping categories → fine-grained `meat`/`fish`/`fruit`/`veg`** — DONE (iter-103a, write-side slice). `ShoppingCategoryMapper` now emits fine-grained buckets (deterministic from group path, no data migration). Backfill of existing docs + legacy-constant removal deferred to BUT-1169 (needs telemetry + Cloud Function). (BUT-1164, P4)

### Post-Sprint Steps (for the implementing session)

- [ ] Per-ticket Step 0 (read code; classify fits / premise-gone / plan-stale).
- [ ] `dart analyze --fatal-infos` clean.
- [ ] Relevant unit tests pass.
- [ ] code-reviewer + testing-specialist on staged Dart (commit-gate hooks).
- [ ] Commit (conventional; footer Co-Authored-By Claude Opus 4.8), push to main.
- [ ] Close BUT-1165, BUT-472, BUT-520, BUT-1164 in Linear with the commit SHA.
- [ ] File any deferred follow-ups in Linear before commit.

---

Prior sprints (iter-100 / iter-101 / iter-102) shipped and closed — see git history (`43b3aadb3`, `b091da229`, `c2d95fb65`). This file is sprint-scratch; the durable record is Linear + git.
