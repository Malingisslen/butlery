# Codex System Review Run — May 2026

This folder captures the artifacts of one full forensic-analysis run executed by OpenAI Codex against the Butlery codebase, following `docs/analysis/prompts/MASTER_ANALYSIS_ORCHESTRATOR.md` and the `docs/analysis/CODEX_RUN_GUIDE.md` overlay.

## Folder layout

```
_pre-analysis/                Tooling output captured BEFORE any prompt runs.
                              Shared by every prompt session.
01-code-quality.md            Phase 1 report, prompt 01
02-security.md                Phase 1 report, prompt 02
03-infrastructure.md          Phase 1 report, prompt 03
04-performance.md             Phase 1 report, prompt 04
05-dependencies.md            Phase 1 report, prompt 05
06-user-experience.md         Phase 1 report, prompt 06
07-ai-llm-quality.md          Phase 1 report, prompt 07
08-product-analytics.md       Phase 1 report, prompt 08
09-trust-safety.md            Phase 1 report, prompt 09
10-monetization.md            Phase 1 report, prompt 10
11-legal.md                   Phase 1 report, prompt 11
12-doc-drift.md               Phase 1 report, prompt 12
SYNTHESIS.md                  Final consolidated audit (after all 12 reports exist)
```

## Run protocol (short form)

1. `_pre-analysis/` is filled in by the script in `docs/analysis/CODEX_RUN_GUIDE.md` ("Pre-analysis tooling — run once").
2. Run prompts in waves per the orchestrator (Wave 1: 01/02/05 → Wave 2: 03/04/06 → Wave 3: 07/08/09/10 → Wave 4: 11/12).
3. Per Codex session, paste the orchestrator + prompt + injected knowledge files + `_pre-analysis/` content (see `CODEX_RUN_GUIDE.md` for the per-prompt knowledge-injection map).
4. Save each Phase 1 report into the matching file above.
5. After all 12 reports exist, run the synthesis session and save to `SYNTHESIS.md`.

## What good looks like

- Every finding cites `file:line` on both the documentation side (when applicable) and the code side.
- Phase 1 reports made ZERO changes to code or production docs.
- Severities are calibrated to actual risk for a pre-launch Swedish-market app, not theoretical perfection.
- `SYNTHESIS.md` produces a single weighted overall score and a sprint-structured remediation roadmap.
