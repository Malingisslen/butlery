# scan night — Butlery, 2026-07-31

Ran as repo 1 of 3 in the overnight tri-repo scheduled sweep, with a per-repo token slice.
One full pass. Focus rotated onto the areas the 2026-07-24 run named as uncovered.
(Previous digest archived as `digest-2026-07-24.md`.)

## 1. Census

**Distinct verified issues found: 11.** All 11 were filed, batched into 9 tickets.

By class:
- Defects, measured or read directly off the code: **11**
- Feature gaps (anchored, "Proposed — needs sign-off"): **0** — no candidate cleared the
  anchor gate this run.

By severity: 1 Urgent, 6 High, 1 Medium, 3 Low (the three Lows batched into one ticket).

By area: recipe 5, settings 3, social 3, backend 3, import 2, tagging 2, shopping 1,
performance 1.

Two of the eleven are the same root cause found independently by two agents in two trees
(code targeting a top-level `recipes` collection that does not exist) and were merged into
one ticket listing all five sites.

## 2. Tickets filed, worst first

### Verified — safe to fix

| Ticket | Sev | What breaks |
|---|---|---|
| BUT-1779 | Urgent | Saving a hand-written recipe lands the user on a full-screen error — a bare id is passed to a route that only accepts a `Recipe` object. 4 sites. The recipe IS saved; the screen says it failed. |
| BUT-1780 | High | Allergen badges never render on any recipe card. The setting defaults ON and promises them; the flag is never threaded through `ContentCard`, so `RecipeCard`'s default `false` always wins. |
| BUT-1781 | High | Five call sites read/write a top-level `recipes` collection that has no rules match block and holds no user recipes. The ingredient-change retag cascade is therefore completely dead, the counter that would have shown it reports 0 forever, and rating a shared recipe throws. |
| BUT-1782 | High | The notification-preferences local cache is a stub (`toJson` returns `'{}'`, `fromJson` returns defaults). One failed Firestore read silently restores every preference to default, including re-enabling push the user turned off. |
| BUT-1783 | High | The notification sound and vibration switches control nothing — zero consumers anywhere in either tree. Marked `need-malin`: wiring it is real work, removing the switches is the honest cheap option. |
| BUT-1784 | High | "Listan skapad" fires unconditionally; the create-list dialog discards the success bool and the service swallows the error without logging. A failed write looks like a successful one. |
| BUT-1785 | High | Revoking a shared *group's* recipe access always fails — the group id is passed to a member API keyed by user id. The per-group revoke control can never succeed. |
| BUT-1786 | Medium | `cleanupExpiredCache` reads the whole `globalRecipeCache` with no `limit()` — the only sweep in that directory that does not paginate. |
| BUT-1787 | Low | Three dead code paths that read as working: a duplicate draft-recovery dialog with zero references, a `dispose()` on a `StatelessWidget`, and a comment helper that discards its text and reports success. |

### Proposed — needs your call

Only BUT-1783, and it is a small one: wire the sound/vibration switches, or delete them.
Recommendation is in the ticket (delete them).

No speculative feature gaps were filed. Both anti-fabrication gates were applied and no
gap candidate produced a code, roadmap or benchmark anchor.

## 3. Rejected, and why

- **`dart analyze` findings — the gate could not be run at all.** The machine had 0.94 GB
  free of 15.8 GB; the analysis server needs roughly 2 GB of headroom. Per
  `docs/ops/analyzer-recovery.md` step 1 that is a starved server, not findings, and no
  cache surgery helps. `dart analyze` exited 1 with the truncated
  "Analyzing butlery..." signature the runbook describes. **Nothing was filed from it.**
  This gate is genuinely unrun for this pass.
- **File-size hygiene** — ran, produced no new information; every finding is already
  covered by BUT-1673.
- **Dependency lag** — not re-run; BUT-1674 already covers it.
- **`flutter test`** — deliberately skipped, same reasoning as the 2026-07-24 run: it is
  compile-bound at roughly twelve minutes and CI already runs it.
- **Several singleton-dispose candidates in the social/menu/shopping views** — the
  scanning agent traced each back to `registerFactory` and killed them itself.
- **Two more interpolated-`\b` word-boundary candidates** — checked; both word lists are
  ASCII-bounded, so the Swedish-boundary bug does not apply.
- **Everything in `.claude/rules/accepted-deviations.md`** — every agent was briefed on the
  list and none re-flagged an entry.
- **Findings inside the parallel session's uncommitted work** — the agents were told to
  treat that fileset with extra suspicion. Nothing was filed from it.

## 4. Where it stopped

Stopped on **budget**, not dryness. This is one repo of a three-repo scheduled sweep with a
per-repo slice, and Butlery's slice was spent after one pass. Dryness is unproven — the
skill's stop condition is two consecutive nothing-new passes and only one pass ran.

What this pass DID cover, and had never been covered systematically before:
- `lib/views/` recipe, import, tagging, social, menu and shopping screens
- `lib/views/settings/`, `lib/views/account/`, notification preferences end to end
  (settings was the backlog's biggest blind spot — one open ticket going in)
- `lib/widgets/` as a pattern sweep (dispose / mounted / context-across-await / twin classes)
- `functions/src/social/`, `notifications/`, `storage/`, `cleanup/`

What remains unscanned:
- A second pass over **shopping and analytics**. The 2026-07-24 run's resume pointer asked
  for this and it was deprioritised in favour of the never-covered UI layer. Ten open
  shopping tickets suggest that seam is well mined, but it is not proven dry.
- `lib/services/` and `lib/repositories/` were entered only to verify a call found in a
  view — no systematic pass this run (the 2026-07-24 run covered them).
- `dart analyze`, for the machine reason above.

## 5. Resume pointer

Start with **`dart analyze` once the machine has headroom** — it is the cheapest gate and
it has now been unrun for a full cycle.

Then the **second pass over shopping and analytics** that this run deferred, followed by a
second pass over `lib/widgets/`: this run swept it by grep pattern rather than by reading
files, which is strong for dispose/mounted classes of bug and weak for logic bugs inside
individual widgets.
