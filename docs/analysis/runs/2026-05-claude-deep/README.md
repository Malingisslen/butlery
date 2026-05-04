# 2026-05 Claude Deep Run

Third parallel forensic analysis run of the Butlery codebase. Sister runs:
- `2026-05-codex/` — OpenAI Codex (manual knowledge injection per `CODEX_RUN_GUIDE.md`)
- `2026-05-claude/` — Claude default (fast pass, ~15 file:line refs/report)
- `2026-05-claude-deep/` — **this run** — senior-engineer depth, two-pass per prompt, ≥50 file:line refs/report

## Methodology differences vs sister runs

1. **Tier 2 specialist agents as primary investigators** (not general-purpose). Specialists read their `.claude/agents/*.knowledge.md` as Step 0 — knowledge that the Codex run had to inject manually and the default-Claude run skipped using.
2. **Two-pass per prompt.** Pass 1 = investigator agent produces draft. Pass 2 = separate critic agent verifies claims against live source, hunts for missing risks/opportunities, enforces ≥50 file:line refs.
3. **Knowledge files treated as hypotheses, not authority.** Every cited pattern from a knowledge file gets verified against current source before inclusion.
4. **30%+ of every analysis spent on what's missing** — invariants nobody tests, antaganden som inte håller vid skala, normaliserad teknisk skuld, strategiska möjligheter.
5. **Pre-analysis reused** from `../2026-05-codex/_pre-analysis/` — no re-running of `flutter analyze` / `pub outdated` / etc.

## Wave plan

- Wave 1 (parallel): 01 code-quality, 02 security, 05 dependencies
- Wave 2 (parallel): 03 infrastructure, 04 performance, 06 user-experience
- Wave 3 (parallel): 07 ai-llm-quality, 08 product-analytics, 09 trust-safety-privacy, 10 monetization
- Wave 4 (last, needs Waves 1-3 on disk): 11 legal, 12 doc-drift
- Synthesis: SYNTHESIS.md (weighted 12-prompt rollup)

## Pre-known facts (do not re-discover)

- `flutter analyze` flagged `ConsentPurpose undefined` at `lib/services/notifications/notification_service.dart:648`. The file was edited 3 minutes after the analyze run — the error may already be resolved on disk. Verify before flagging as live.
- `flutter test --coverage` was aborted after ~45 min — `test/views/helpers/infrastructure_integration_test.dart` hangs ~10 min/test. 10122 tests passed before the hang, 89 skipped, 200 failed.
- 6 GitHub Actions workflows on disk vs 5 documented in orchestrator.
- Firestore rules: 1788 lines / 95 match rules vs documented 1465 / 74.
- 1252 hand-written .dart files / 327 280 lines vs documented ~850 / ~150k.
- 132 files >500 lines vs documented 33.
