# Sprint Backlog

## Sprint: autonomous-lane (deploy rollback + coverage floor) — 2026-06-30

The `autonomous` lane holds exactly 5 tickets. Three are ops/credential-gated (Tier D):
BUT-889 (paid Vertex/Mistral API + WIF service account), BUT-1240 (device-capable CI runner),
and the live-verification half of BUT-1424. BUT-1176 is Low/optional ("pick up only if
custom_lint is being added for other reasons" — zero current leaks) so it's deliberately
deprioritized, not silently skipped. That leaves two genuinely workable picks this batch.

Both router `single`-tier, no high-stakes hits, both Medium priority → Phase 1.5 plan-gate does
NOT fire. Phase 1.4 stakeholder critique (owning role) runs per ticket before build.

### Agent A: deploy reliability — Stakeholders: DevOps/SRE (single)
- [ ] **A1. Add an executable rollback path to the backend deploy** `[Tier C]` (BUT-1424) — `.github/workflows/deploy-firebase.yml`
  - Capture pre-deploy state (functions manifest + the rules/indexes/storage config being replaced) → workflow artifact; add an `if: failure()` rollback that redeploys the previous-good source for in-scope targets.
  - Acceptance:
    - The workflow captures pre-deploy state (functions:list manifest + replaced rules/indexes/storage config) and uploads it as a workflow artifact.
    - A rollback step runs ONLY on deploy failure (`if: failure()`), redeploying the in-scope targets from a resolved previous ref (prior `v*` tag on tag-push, `HEAD^` on dispatch) — never on the pre-deploy rules-gate failure.
    - The previous ref is resolved dynamically (no hardcoded revision) and the rollback no-ops gracefully (logs, exit 0) when no previous ref exists.
    - Success-path deploy behaviour is unchanged (same targets/commands); the workflow YAML parses.
  - Negative constraint: do NOT change the deploy targets, project, or the existing rules-gate / smoke-gate logic.

### Agent B: test coverage floor — Stakeholders: QA/Test Engineer (single)
- [!] **B1. Restore coverage floor to 60.0% — BLOCKED on a trustworthy measurement** `[Tier A]` (BUT-1149) — `.github/workflows/test.yml:305`
  - Step-0 outcome: MEASURED. A ~99%-complete `flutter test test/unit --coverage` run (15406 passed) → filtered coverage **56.76%** (parser `tasks/cov_filter.py` replicates the CI `lcov --remove` filter; lcov binary absent locally). That is a near-lower-bound and is ~3.2pp below the 60.0 floor — so the ticket's premise still holds and raising the floor would red-CI main. Disposition: floor NOT raised (stays 55.0); ticket stays in Backlog. Acceptance "<60 → don't raise + post measured number" satisfied. (Side note: run showed 6 failing tests on Windows-local — flag to confirm against ubuntu CI, likely env-specific; not chased this batch.)
  - Step 0: MEASURE current filtered unit coverage at HEAD (a 12-min background run is in progress). The floor is currently 55.0; ticket reported 55.5% at filing; much test work has shipped since.
  - Acceptance:
    - Current filtered coverage measured at HEAD and recorded.
    - If measured ≥60.0 → `OVERALL_FLOOR` raised to `60.0`; close Done with the measured number.
    - If measured <60.0 → floor NOT raised (raising it would red-CI main, a real regression); ticket stays open, post measured coverage + the remaining gap, file/keep the DI-seam test follow-ups.
  - Negative constraint: never raise the floor above the actual measured coverage.

### Needs you (Tier D — flagged, not worked)
- BUT-889 — 4 paid-API LLM golden corpora: needs CI Vertex AI/Mistral credentials (a GCP service account + Workload Identity Federation binding) and paid API budget to generate gold standards. Ops/secrets the loop can't reach.
- BUT-1240 — NER golden corpus real-signal lane: needs a device-capable CI runner provisioned.

### Deprioritized (autonomous-lane, deliberately not worked)
- BUT-1176 — custom_lint/AST upgrade: Low priority, explicitly optional ("pick up only if custom_lint is being added for other reasons"); zero current production leaks and the file-level arch-test already guards regressions. Adding the custom_lint dependency slows every analyzer run for marginal value — not worth it now.

### Post-Sprint Steps
- [x] No Dart/TS changed — workflow YAML only; no code-reviewer/testing-specialist markers apply
- [x] BUT-1424 verified (fresh-context grader: 6/6 acceptance criteria pass)
- [ ] Commit BUT-1424, push to main
- [ ] Linear: BUT-1424 → In Review + notify (Tier C, prod-pipeline, unverifiable without a real failed deploy); BUT-1149 stays Backlog with disposition comment

---

## Sprint: autonomous-lane batch (notifications, a11y, voice, search) — 2026-06-29

(archived — all shipped: BUT-1427 Done; BUT-1426/1431 In Review; BUT-1442 descoped + Linear body rewritten)
