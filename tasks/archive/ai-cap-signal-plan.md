# AI-taken i nya prod: snåla starttak + signal när de måste höjas

Repo-copy goes to `tasks/ai-cap-signal-plan.md` on approval (plan mode only allows this file).

## Context

Malin: "Kan vi börja snålt och sätta ihop ett system som gör att vi vet när vi måste öka?"
The new EU prod project (epic BUT-2427) starts with `aiEnabled: false`; Fas 3 writes
`system/config` and turns AI on once caps are set and read back. Today a cap that bites is
invisible: the global cap logs a plain-text warn per denied call, the guest-capacity cap logs
nothing, and nobody reads either. Decided by Malin 2026-10-21 (cards):
- **Starting caps = staging values.**
- **Signal = morning koll only** (no email, no GCP alert policy).

## The caps that can bite (measured in code 2026-10-21)

| Cap | Where | Value source | Raise by |
|---|---|---|---|
| Global AI calls/hour, /day | `checkGlobalLimit` in `functions/src/middleware/rate_limiter.ts` (counter `system/llmLimits`) | `system/config.globalHourlyLimit` / `globalDailyLimit` | Console edit |
| Guest new imports/day (shared) | `consumeGuestCall` in `functions/src/llm/guest-import-quota.ts` (counter `system/guestImportLimits`) | `system/config.guestDailyImportLimit` | Console edit |
| Per-user AI calls/day | `evaluateDailyCap` via `withRateLimit` — `structureRecipe` 100, `ocrRecipeImage` 50 | `RATE_LIMIT_CONFIGS` (code) | Code + deploy |
| Per-user AI spend/day, /month | `checkCostCeiling` in `llm_cost_ledger.ts` — $0.5 / $10 | `LLM_COST_CEILINGS` (code); already logs `llm_cost_ceiling_denied` | Code + deploy |

Only `structureRecipe` and `ocrRecipeImage` use `withRateLimit`; `ocr-retry.ts` also calls
`checkGlobalLimit`. Per-guest 3 imports / 12 calls are product limits, not cost knobs — out of scope.

## 1. Starting values for new prod `system/config` (Fas 3 input, not written by this session)

`globalHourlyLimit: 20`, `globalDailyLimit: 100`, `guestDailyImportLimit: 5` (= staging; these
live only in staging Firestore, so they are read back from staging before the Fas 3 comment).
Design ceiling 5 öre/import (`functions/src/analytics/import-tier-weekly.ts`) → at most ≈5 kr/day at full use. That is a
design constant, not a measured cost. Caveat: per-user `structureRecipe` is 100/day, so one heavy
user can use the whole global day — the signal below is what surfaces that.

## 2. Signal in the functions (one new small module + minimal hooks)

New `functions/src/middleware/ai_cap_signal.ts`:
- `capCrossing(newCount, limit)` → `"reached"` when `newCount === limit`, `"near"` when
  `newCount === ceil(0.8 × limit)` and below the limit, else null. Exact equality on a
  transaction-serialised counter means each crossing logs **once per window, no extra read or
  write**. (Limit ≤ 4: only "reached".)
- `emitCapSignal({cap, level, count, limit, operationType?, userIdHash?})` →
  `logger.warn("ai_cap_signal", {...})`. Caps: `global_hour`, `global_day`, `guest_day`,
  `user_day`. Only `user_day` carries `userIdHash` (existing `hashUid`), needed to count
  distinct users; no raw uid anywhere.

Hooks (emit **after** the transaction resolves, so a retried transaction never double-logs):
- `checkGlobalLimit`: transaction returns the new hourly/daily counts; emit for each window.
  A facade split of rate_limiter.ts is out of scope here and is proposed as a follow-up session.
- `checkRateLimit`: its result gains optional `dailyCount`; it emits `user_day` for the AI
  operations (`structureRecipe`, `ocrRecipeImage`) that declare a `dailyLimit`, so the OCR
  retry's direct call is counted too. Non-AI ops with daily caps are not signalled.
- `consumeGuestCall`: on a new import, return the new shared day count; the wrapper emits `guest_day`.

Known gaps (stated, not fixed): `refundGuestCall` decrements the guest day counter when an import
is refused before any spend, so `guest_day` near/reached can log more than once a day; the
report deduplicates per cap per day, and a test pins the reach → refund → reach sequence. If a cap is LOWERED below today's count mid-window, no crossing is
logged; the existing denial warn still fires. Limits are cached per warm instance, so a raised
cap takes effect at next cold start (≤ about an hour under traffic) — the koll card says so.

Tests (`functions/src/__tests__/`): `ai-cap-signal.test.ts` for `capCrossing` edges (limit 1, 4,
5, 20, 100, beyond limit) and that each hook emits exactly once at the crossing and not on the
call before/after, including the guest refund case. All in the new file.

## 3. Morning report (deterministic, no LLM, no Firestore reads)

New `tools/ai_cap_report.py`:
- `gcloud logging read` over the last 24 h in `--project` for `jsonPayload.message="ai_cap_signal"`
  and `"llm_cost_ceiling_denied"`.
- Emits koll decision JSON in the `seed-decisions.json` shape, source `morgonkoll`, stable ids:
  `butlery-ai-tak-global-dag` (reached → stakes 4, near → 3), `-global-timme` (3/2),
  `-gast-dag` (3/2), `-per-anvandare` (distinct users who reached a per-user cap or cost
  ceiling → 2). Each card: what happened, which field, suggested new value (double), a
  copy-ready prompt, and a "Låt ligga" route with the honest consequence.
- Exit non-zero + a "kunde inte hämtas" line if gcloud fails (D8 blind spot, not "lugnt").
- `--self-test` runs on canned log JSON, no network.

Edit `~/.claude/scheduled-tasks/synat-morgonkoll/SKILL.md` (outside the repo; approving this
plan approves that edit): new step **BU4. AI-TAK** that runs the script, upserts its items and
adds their ids to `seen`; new trigger **D10 — Ett AI-tak är nära eller nått**. Project id stays
`butlery-app-1` until Fas 3 switches the routine to the new project (Fas 3 already must).

## 4. Fas 3 handover

Comment on BUT-2431 (or the Fas 3 issue under BUT-2427): the three values, that functions with
this commit must be deployed before `aiEnabled: true`, read-back command, and "switch morgonkoll
BU2/BU4 `--project` to the new id". No GCP alert policy is part of this (Malin chose koll only).

## Verification

1. `npm --prefix functions run build` + the new/extended tests green; `python tools/ai_cap_report.py --self-test`.
2. Commit gates (cloud-functions-specialist etc., whichever the gate names), push to main.
3. **Staging E2E** (current `butlery-app-staging`, Firestore europe-west3), restoring everything:
   - Read back and note staging `system/config` (also the Fas 3 values). Set `globalHourlyLimit: 5`,
     `guestDailyImportLimit: 2`; deploy `structureRecipe` to staging via CLI so fresh instances read them.
   - App Check: a server-minted one-off token, `admin.appCheck().createToken(<staging web appId>,
     {ttlMillis: 30 min})`, used only by the test script. Malin chose this 2026-10-21 as distinct from
     the device test key she declined; nothing in staging's App Check config changes.
   - Sign up one anonymous test guest via Identity Toolkit REST. Exact call sequence (guest quota runs
     first, then the per-user bucket of 10, then the global counter):
     A1 (new import A: guest_day 1, global 1) → B1 (new import B: guest_day 2 = reached) → A2 (global 3)
     → A3 (global 4 = near) → A4 (global 5 = reached) → A5 denied "Systemets kapacitetsgräns".
     Five real Gemini calls, a few öre.
   - `python tools/ai_cap_report.py --project butlery-app-staging` → expect cards for `global-timme`
     and `gast-dag`. `koll.mjs upsert` one clearly labelled test item, then `resolve` it, no `deploy`.
   - Restore staging `system/config` to the noted values, redeploy `structureRecipe`, delete the test guest.
   - `user_day` and cost-ceiling paths are covered by unit tests only (their caps are code constants).
4. If any step fails: report it, don't claim done.

## Files

New: `functions/src/middleware/ai_cap_signal.ts`, `functions/src/__tests__/ai-cap-signal.test.ts`,
`tools/ai_cap_report.py`, `tasks/ai-cap-signal-plan.md`.
Changed: `rate_limiter.ts`, `guest-import-quota.ts`, `guest-import-quota.test.ts`; outside repo:
morgonkoll SKILL.md. Stakeholder router: full-panel (FinOps, Vendor, DPO via guest quota, SRE…);
conditions folded in above: no raw uid, no new stored data, no new reads, no LLM.

## Open questions

No architecture-changing unknowns left. Decided by Malin 2026-10-21: staging caps as start values,
koll-only signal, one-off server-minted App Check token for the staging test. Weakest point: the
staging run depends on minting an App Check token with gcloud user credentials (may need
service-account impersonation); if that fails, I stop and report rather than add a debug token.

## Sammanfattning för Malin

- Nya prod startar med samma AI-tak som staging: 20 anrop i timmen, 100 per dygn, 5 gästimporter per dygn.
- När ett tak är till 80 % använt, eller nått, skrivs en rad i loggen — en gång per tak och period, utan extra databaskostnad.
- Morgonkollen läser de raderna varje morgon och lägger ett kort i koll-kön: "taket X nåddes igår — höj från 100 till 200?", med färdig prompt. Inget mejl, som du valde.
- Tak per användare och kostnadstaket per användare syns också (hur många som slog i), men de höjs med en kodändring, inte i konsolen.
- Jag provar hela kedjan på staging med tillfälligt låga tak, en testgäst och ett engångspass förbi App Check som gäller en halvtimme, och återställer sedan allt. Det kostar några öre.
- Risken: en loggrad till per tak och period, och ett nytt steg i morgonkollen. Ångras genom att ta bort steget och kodraderna. Staging-testet ändrar taken där en kort stund och återställer dem.
- Fas 3-sessionen får värdena och stegen som kommentar i Linear; jag rör inte nya prod.
