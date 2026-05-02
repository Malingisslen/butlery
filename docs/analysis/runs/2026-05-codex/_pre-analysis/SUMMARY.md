# Pre-Analysis Summary — 2026-05 Codex Run

Captured before any prompt session. Shared as context across all 12 prompt sessions per `docs/analysis/CODEX_RUN_GUIDE.md`.

## Files captured

| File | What it contains |
|------|------------------|
| `firebase-sizes.txt` | Line counts for `firestore.rules`, `storage.rules`, `firestore.indexes.json` + match-rule count |
| `firestore-index-counts.txt` | Composite indexes + field overrides (parsed from JSON) |
| `functions-tree.txt` | Top-level subdirectories under `functions/src/` |
| `functions-regions.txt` | Unique `.region(...)` declarations across `functions/src/**/*.ts` |
| `dart-file-count.txt` | Hand-written `.dart` file count (excludes `*.g.dart`, `*.freezed.dart`, `app_localizations*.dart`) |
| `dart-line-count.txt` | Hand-written total line count |
| `files-over-500-lines.txt` | All hand-written `.dart` files exceeding 500 lines, sorted by size desc |
| `ci-workflows.txt` | `.github/workflows/` listing |
| `docs-by-mtime.txt` | All markdown docs in `docs/`, `.claude/`, root — sorted by modification time |
| `knowledge-file-mtimes.txt` | Sizes + mtimes of `.claude/agents/*.knowledge.md` |
| `service-locator-types.txt` | Every `ServiceLocator.get<Type>()` resolution used in `lib/` |
| `stockholm-mentions.txt` | Every "Stockholm" occurrence in `lib/` and `functions/` (drift signal — region is europe-west1 = Belgium) |

## Tooling not run in this environment

The remote environment lacks Flutter. Run these locally and add the outputs to this folder before opening any Codex session:

```bash
RUN=docs/analysis/runs/2026-05-codex/_pre-analysis
flutter --version > "$RUN/flutter-version.txt" 2>&1
flutter analyze > "$RUN/flutter-analyze.txt" 2>&1
flutter pub outdated > "$RUN/pub-outdated.txt" 2>&1
flutter pub deps --style=compact > "$RUN/pub-deps.txt" 2>&1
flutter test --coverage > "$RUN/flutter-test.txt" 2>&1
osv-scanner --lockfile=pubspec.lock > "$RUN/osv-scanner.txt" 2>&1 || true
dcm analyze lib/ > "$RUN/dcm.txt" 2>&1 || true
```

## Immediate drift signals visible from pre-analysis alone

These are confirmed before any Codex prompt has run. They will show up in prompt 12 (Documentation & Operational Drift) — listing here so the analyst can cross-check rather than re-discover.

| Doc claim | Source | Reality | Drift |
|-----------|--------|---------|-------|
| "1465 lines" firestore.rules | `MASTER_ANALYSIS_ORCHESTRATOR.md:57` | 1788 lines | +323 lines (+22%) |
| "74 match rules" | `MASTER_ANALYSIS_ORCHESTRATOR.md:57` | 95 match rules | +21 rules (+28%) |
| "61 lines" storage.rules | `MASTER_ANALYSIS_ORCHESTRATOR.md:58` | 76 lines | +15 lines (+25%) |
| "34 composite Firestore indexes" | `MASTER_ANALYSIS_ORCHESTRATOR.md:59` | 30 composite + 6 field overrides | -4 composite, +6 field overrides |
| "33 files intentionally >500 lines" | `CLAUDE.md` (Code Style section) | 132 files >500 lines | +99 files (4× understated) |
| "~850+ .dart files" | `MASTER_ANALYSIS_ORCHESTRATOR.md:29` | 1252 hand-written .dart files | +402 files (+47%) |
| "~150k+ lines hand-written" | `MASTER_ANALYSIS_ORCHESTRATOR.md:29` | 327 280 lines | +177k (+118% — codebase has more than doubled) |
| "5 GitHub Actions workflows: analyze, test, build-validation, architecture-validation, e2e_tests" | `MASTER_ANALYSIS_ORCHESTRATOR.md:53-55` | 6 workflows: architecture-validation, build-validation, dep-audit, e2e_tests, firestore-rules, test (no analyze.yml; new dep-audit.yml + firestore-rules.yml) | -1 named workflow, +2 new workflows |
| "europe-west1 (Belgium — NOT Stockholm despite code comments)" | `11_LEGAL_REVIEW.md:54` | Confirmed europe-west1 in functions; **41 "Stockholm" mentions still in lib/ and functions/** | Region claim correct; code comments still drifted |

The "33 files >500 lines" claim being off by 4× is the most operationally significant — it means ACCEPTED_LARGE_FILES.md is severely out of date and the file-size discipline is no longer being enforced as the rule states.

## Knowledge file ages

All `.claude/agents/*.knowledge.md` files mtime = `2026-05-01 07:02`. Sizes:

| File | Size |
|------|------|
| firebase-backend-security.knowledge.md | 88 KB |
| cloud-functions-specialist.knowledge.md | 32 KB |
| testing-specialist.knowledge.md | 17 KB |
| uiux-designer.knowledge.md | 8.6 KB |
| firestore-rules-tester.knowledge.md | 7.3 KB |
| performance-optimizer.knowledge.md | 6.5 KB |
| e2e-test-specialist.knowledge.md | 3.9 KB |

`firebase-backend-security.knowledge.md` (88 KB) is the heavyweight — Codex must read this in full when running prompts 02, 09, 11, and 12.

## Doc inventory snapshot

96 markdown documents in scope (`docs-by-mtime.txt`). Sorted ascending by mtime, the oldest entries are highest drift risk. Codex prompt 12 should walk this list from top.
