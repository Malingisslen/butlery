# BUT-1655 (build half) — OCR retry per-user rate-limit cap guard

<!-- Plan approved via ExitPlanMode 2026-07-23; refreshed 2026-07-24 after /login reset the session marker. -->

**Decision (Malin, 2026-07-23):** build the OCR retry per-user cap guard now; defer the
global-counter sharding half (revisit at ~1 write/s). This plan covers only the guard.

## Problem (premise verified against current code)

The OCR image import has a text-mode auto-retry: when an image parse fails but Gemini
returned legible `rawText`, `runOcrRetry` (`functions/src/llm/ocr-retry.ts`) feeds it into
`runStructureRecipe` — the **unwrapped** core, not the `withRateLimit`-wrapped callable.
The retry today enforces the **global** LLM cap (`checkGlobalLimit`, Guard 4) but **not** the
**per-user** cap (`checkRateLimit(userId, 'structureRecipe')` — token bucket + BUT-1477 daily
cap of 100/day). Two consequences:
1. A user can make one extra `structureRecipe` call per import beyond their per-user budget.
2. Because Guard 4 *increments the shared global counter* with no per-user gate before it, a
   user already over their own cap can still inflate the global counter — the exact bug
   BUT-1577 fixed in the wrapped path by ordering **per-user before global**.

## Fix

Add a per-user cap check to `runOcrRetry`, placed as a new guard **before** the existing
global-cap guard (mirrors `withRateLimit`'s BUT-1577 ordering). Reuse Option A (resolve the
cap in the OCR core alongside the existing `checkGlobalLimit`), which follows the module's
own precedent (`checkGlobalLimit` is already resolved in-core at ocr-recipe-image.ts:282).

### Steps
1. **`functions/src/llm/ocr-retry.ts`**
   - Add `skipped_user_limit` to the `RetryOutcome` union.
   - Add `checkUserLimit?: () => Promise<boolean>` to `RetryDeps` (optional test seam;
     omitted -> allow, mirroring `checkGlobalLimit`).
   - Insert **Guard 4 (per-user)** *before* the current global guard (which becomes Guard 5):
     if `deps.checkUserLimit` returns `false`, return `retryOutcome: 'skipped_user_limit'`,
     `retryCount: 0`, `additionalCost: 0` (skip retry -> fall back to rawText, same UX as the
     global skip). Update the header/decision-tree comments.
2. **`functions/src/llm/ocr-recipe-image.ts`**
   - Add a **required** `userId: string` field to `OcrCoreOptions` (raw uid). Required, not
     optional, so TS forces every call site to wire it (no runtime fail-open).
   - Comment it: raw uid, used ONLY as the `checkRateLimit` doc key; **never** logged /
     emitted — logging stays on `authUidHash`.
   - Resolve `checkUserLimit` in-core with the same two-hop pattern as `checkGlobalLimit`:
     `const userLimitCheck = opts.checkUserLimit ?? (() => checkRateLimit(opts.userId, 'structureRecipe').then(r => r.allowed));`
     then thread it into the `runOcrRetry(...)` deps object at ~L484.
   - `onCall` wrapper (L118-124): pass `userId: request.auth!.uid`.
   - Import `checkRateLimit` from `../middleware/rate_limiter`.
3. **`functions/src/__tests__/ocr-retry.test.ts`**
   - Per-user-deny: outcome `skipped_user_limit`, `structureRecipe` NOT called, **and
     `checkGlobalLimit` NOT called** (call-count assertion — locks the ordering so a later
     refactor can't regress to "global increments regardless").
   - Per-user-allow: proceeds to the global guard, then `structureRecipe`.
   - `skipped_user_limit` is distinct from `skipped_global_limit`.
   - Fail-closed inherited: a `checkUserLimit` that resolves false (Firestore error path in
     production) -> skip -> rawText fallback.
   - Update the existing `runOcrRecipeImage(...)` test call sites (10) + kill-switch /
     handwritten / validation tests to pass the now-required `userId`.
4. Verify: `npx tsc --noEmit -p functions`, run `functions/src/__tests__/ocr-retry.test.ts`
   (+ the three other touched suites), then cloud-functions-specialist review (commit gate).

## Binding acceptance criteria (folded from the blind FinOps + Security + Architect panel)
- **AC1 — ordering:** per-user guard strictly before the global guard in the actual diff.
- **AC2 — same bucket:** call `checkRateLimit(userId, 'structureRecipe')` with default
  `tokensRequired=1` — the **same** operation key + cost the primary path uses (NOT a new
  operationType), so the retry draws from the one shared per-user `structureRecipe` budget.
- **AC3 — no fail-open:** raw `userId` is a **required** field; only one production caller
  (the `onCall` wrapper) exists — confirmed by grep. Test-seam default-allow stays test-only.
- **AC4 — hash-only logs:** raw `userId` consumed solely by `checkRateLimit`; `logger.*`,
  `emitTiming`, `captureLlmSample` keep using `authUidHash`.
- **AC5 — ordering regression test:** the per-user-deny test asserts `checkGlobalLimit` was
  never called.
- **AC6 — observability (follow-up, not this diff):** the new `skipped_user_limit` value
  flows through `retryOutcome` as pass-through telemetry (verified: no CF-side bucketing).
  The downstream dashboard should treat it like `skipped_global_limit` — note for whoever
  owns OCR-retry metrics; out of scope for the function code.

## Open questions
No architecture-changing unknowns needing founder input. Two technical design calls were
made and are recorded above: (a) **Option A** (resolve the per-user cap in-core) over Option
B (build the closure at the boundary) — chosen because it follows the module's existing
`checkGlobalLimit` precedent and can't fail open; (b) the raw-uid field is **required** so
the compiler, not runtime, catches an unwired caller. Both were endorsed by the blind panel.

## What this means in plain language
- Right now, when you import a recipe by photo and the first read fails, the app quietly
  tries a second time. That second try wasn't counting against your personal daily limit for
  AI recipe-reading — so a user could squeeze out a few extra AI calls per import than the
  limit intends, which costs us money.
- This fix makes that second try count against the same personal daily allowance as
  everything else, and check it in the right order so a user who's already at their limit
  can't nudge up the shared system-wide meter either.
- Nothing changes for a normal user: imports still work exactly the same, retries still
  happen when there's budget. The only difference is a heavy/abusive user can't get free
  extra AI calls through the retry back door.
- Risk is low and contained: three backend files, no data model change, no change to what's
  stored or shown. Fully covered by tests. Easy to undo (revert one commit) if anything looks
  off; nothing is deployed until the functions are next deployed.
