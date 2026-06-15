# Sprint Backlog

## Sprint: backend-slice-drained — no honest backend build mandate this iteration (0 picks) — 2026-06-15 (iter-166)

Backlog re-read: 93 open Backlog + 0 Todo + 0 In Progress + 0 Triage. Working tree had only two untracked scratch files (tmp_linear_chunk*.txt). iter-165 shipped its two test files in `f20bdb555` and filed three new test-symmetry follow-ups (BUT-1312/1313/1314).

This sprint was scoped to **area label `backend`** (21 of the 93 tickets carry it). Every one of those 21 was read or premise-checked. **None is an honest `build` or `build-review` pick** — each is either Tier-D ops-blocked, deferred-by-design (the ticket body itself says "premature / speculative dead code / file when telemetry warrants"), or a monetization/scope decision that is Malin's call. Padding to N with deferred work would be false mandate, so the honest batch is 0.

### Backend slice classification (all 21 backend-labeled tickets)

**Deferred-by-design — the ticket text itself says don't build yet (needsApproval / leave asleep):**
- BUT-1248 — schemaVersion migration-dispatch. Body: "building the dispatcher now would be speculative dead code." Build only when the first v2 schema change lands.
- BUT-1011 — async status-polling for very large account deletion. Body: "premature optimization. File this if telemetry shows timeouts."
- BUT-1169 — backfill legacy shopping categories + drop legacy constants. Backfill needs prod telemetry + a Cloud Function; dropping the constants "would break rendering while old docs exist." Both halves blocked.
- BUT-1224 — BUT-1032 phase-2 explicit cachedContents. Decision gate pending 2 weeks of production telemetry.
- BUT-840 — Algolia search-index freshness. Needs Algolia admin key + a deploy the loop can't verify; low impact (stale display-name-in-search only).
- BUT-610 — audit + harden offline mode. Audit-then-harden spanning many surfaces; needs a defined scope first.

**Monetization / product-scope — no monetization decision exists (needsApproval):**
- BUT-650 (server-only writes for subscription tier fields), BUT-644 (subscription tier schema), BUT-661 (RevenueCat webhook CF), BUT-686 (email win-back channel). All gated on a monetization decision memory records as not-yet-made.

**Tier D — genuine ops/deploy/console/CI/secrets blockers (flagged, never coded):**
- BUT-451 (staging Firebase project), BUT-486 (CI deploy automation), BUT-813 (GCP alert policies), BUT-1229 (cook-snap visibility backfill + rules deploy), BUT-818 (Vision SafeSearch — credentials), BUT-821 (Cloud Monitoring alert), BUT-1239 (model-hash CI guard), BUT-594 (macOS sandbox entitlements audit), BUT-420 (Fastlane deploy pipeline), BUT-491 (desktop CI builds).
- BUT-1167 (AI/LLM hardening ops remainder) — its AI1 (live-deploy verify) and AI8 (CI changelog gate) are ops/CI-blocked; only its AI6 (splitter consolidation) is theoretically code-only, but the duplicated-splitter sites aren't locatable from the ticket without a deep investigation and AI6 is bundled with the two blocked sub-parts, so the ticket can't cleanly auto-close. Left for a focused investigation, not auto-pick.

### Agent batches
- (none — no honest backend build/build-review pick this iteration)

### Needs you (worth doing eventually — your call, not auto-pick mandate)
- **BUT-1248 / BUT-1011 / BUT-1224** — deferred-by-design; build when the named trigger fires (first v2 schema change / real timeout telemetry / 2-week cache telemetry). Recommendation: leave asleep.
- **BUT-1169** — needs a production backfill CF + telemetry; constant-drop is unsafe while old docs exist. Recommendation: leave deferred until a backfill run is scheduled.
- **BUT-840** — Algolia freshness. Recommendation: build-review once the admin-key path + deploy are decided.
- **BUT-610** — offline-mode audit+harden. Recommendation: build-review as its own scoped sprint with a defined surface list.
- **BUT-650 / BUT-644 / BUT-661 / BUT-686** — monetization scaffolding. Recommendation: drop until a monetization decision exists.
- **BUT-1167** — split out AI6 (splitter consolidation) into its own code-only ticket if you want it built; AI1/AI8 stay ops/CI-blocked.

### Needs you (Tier D — true ops/deploy/CI/secrets blockers, not worked)
- BUT-451, BUT-486, BUT-813, BUT-1229, BUT-818, BUT-821, BUT-1239, BUT-594, BUT-420, BUT-491 (and the AI1/AI8 halves of BUT-1167) — all need live console/deploy/CI access the autonomous loop cannot reach.

### Obsolete (done in git, still open in Linear)
- (none this iteration)

### Post-Sprint Steps
- [ ] No code changes — selection-only sprint. Nothing to analyze/test/commit beyond this scratchpad.
- [ ] No Linear transitions (zero tickets selected).

---
## ARCHIVED — iter-165 (a11y+hover-test-completeness: BUT-1311 card-hover positive assertion + BUT-1309 focus-traversal view coverage -> Done -- `f20bdb555`; BUT-1312/1313/1314 filed as follow-ups) · iter-164 (hover+focus-test-safety-nets: BUT-1308 + BUT-1307 -> Done -- `79c2cc98f`) · iter-163 (a11y-focus + web-hover + pantry-settings-ui: BUT-701 -> Done, BUT-710 + BUT-1306 -> In Review -- `83695735b`) · iter-162 (mvvm-tag-routing + cooking-card-deadpath: BUT-1304/1305 -> Done -- `c0fb5081e`) · iter-161 (import-ssrf-parity + veckomeny-cooking-card-tests -- `130d9547c`) · iter-160 (recipe-detail-import-seam + veckomeny-decomp -- `8b91c165b`) · iter-159 (activity-feed-test-gap -- `18a8739a5`) · iter-158 (backend-rules + dart-test-gaps -- `fe28279d0`) · iter-157 (verifier-followups -- `74825b1f2`) · iter-156..143 — se git-historiken
