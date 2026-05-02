# Codex Run Guide — Butlery Forensic Analysis

**Purpose:** This guide tells you how to run the 12-prompt forensic analysis system in OpenAI Codex (the CLI / agent) instead of Claude. Use it together with `docs/analysis/prompts/MASTER_ANALYSIS_ORCHESTRATOR.md`.

---

## Why this guide exists

The 12 prompts in `docs/analysis/prompts/` were originally designed for Claude. They are 95% tool-agnostic — Codex can execute them — but Claude has two pieces of context that Codex does not:

1. **Tier 2 specialist subagents** (`code-reviewer`, `firebase-backend-security`, `testing-specialist`, `firestore-rules-tester`, `cloud-functions-specialist`, `e2e-test-specialist`, `performance-optimizer`, `uiux-designer`, `flutter-developer`) that Claude can dispatch automatically.
2. **Accumulated agent knowledge** in `.claude/agents/*.knowledge.md` (~3220 lines of "we hit this bug, here's the pattern that prevents it"). Claude's subagents read these as Step 0 of every invocation.

Codex sees neither. So it would re-discover problems we already solved, miss subtle patterns that only show up after months of iteration, and produce a shallower review than Claude would.

This guide closes that gap by telling Codex which knowledge file to read for which prompt.

---

## Recommended Codex execution model

**One Codex session per prompt.** Don't try to run all 12 in one session — context window pressure degrades depth quickly, and Phase 1 explicitly requires forensic depth.

Per the orchestrator's Wave model:

- **Wave 1 (parallel):** prompts 01, 02, 05 — start three Codex sessions
- **Wave 2 (after Wave 1):** prompts 03, 04, 06
- **Wave 3 (parallel with Wave 2 OK):** prompts 07, 08, 09, 10
- **Wave 4 (LAST — needs Waves 1-3 evidence):** prompts 11, 12

Save each Phase 1 report into `docs/analysis/runs/<YYYY-MM>-codex/<NN>-<topic>.md` for the synthesis pass.

---

## Per-prompt context bundle for Codex

For each Codex session, paste **in this exact order**:

1. **System framing** (always first):
   > "You are running a forensic Phase 1 investigation on the Butlery codebase. Document findings only — make ZERO code changes and ZERO file writes outside the report file. Use file:line references for every claim. Read the prompt below in full before starting."

2. **The orchestrator** — `docs/analysis/prompts/MASTER_ANALYSIS_ORCHESTRATOR.md` (so Codex understands cross-prompt boundaries and dedup rules)

3. **The specific prompt** — one of `docs/analysis/prompts/NN_*.md`

4. **The relevant knowledge files** per the injection map below

5. **The pre-analysis tooling output** (run the commands listed in the prompt's Pre-Analysis section, save the output, paste it)

6. **The handoff**:
   > "Begin Phase 1 investigation. Output the report in the format defined by the prompt's Output Format section. Save the final report to `docs/analysis/runs/<YYYY-MM>-codex/<NN>-<topic>.md`."

---

## Knowledge-file injection map

This is the gap-closing step. For each prompt, attach the listed knowledge files so Codex inherits the accumulated wisdom Claude's subagents would normally bring.

| Prompt | Inject these knowledge files | Why |
|--------|------------------------------|-----|
| 01 Code Quality & Architecture | `testing-specialist.knowledge.md`, `performance-optimizer.knowledge.md` | Architecture violations often surface as testing or perf pain — these knowledge files document the patterns we've seen repeatedly |
| 02 Security & Compliance | `firebase-backend-security.knowledge.md` (1700 lines — the biggest knowledge file we have), `firestore-rules-tester.knowledge.md` | Most security drift in this codebase comes from Firestore rules and PermissionValidationMixin patterns these files document |
| 03 Infrastructure & Operations | `e2e-test-specialist.knowledge.md`, `testing-specialist.knowledge.md`, `cloud-functions-specialist.knowledge.md` | E2E + CI + Cloud Functions deployment patterns live here |
| 04 Performance & Scalability | `performance-optimizer.knowledge.md`, `cloud-functions-specialist.knowledge.md` | 60fps Flutter patterns + cold-start cost / region pinning |
| 05 Dependencies & Supply Chain | (none — prompt is fully tool-agnostic) | Dependency audit relies on `pub outdated` / `osv-scanner` not subagent knowledge |
| 06 User Experience & Platform | `uiux-designer.knowledge.md` | Material 3 + Swedish localization + WCAG patterns we've codified |
| 07 AI/LLM Quality & Reliability | `cloud-functions-specialist.knowledge.md` (LLM-family functions live there) | LLM routing, prompt caching, retry semantics |
| 08 Product Analytics & Growth | (none — schema review is self-contained) | |
| 09 Trust, Safety & Privacy | `firebase-backend-security.knowledge.md`, `cloud-functions-specialist.knowledge.md` | Consent service + audit logs + cleanup functions |
| 10 Monetization & Competitive | (none — strategic review is self-contained) | |
| 11 Legal Review | `firebase-backend-security.knowledge.md` (consent + audit log retention numbers) | Catches the doc-vs-code retention drift we know exists |
| 12 Doc & Operational Drift | **ALL seven** knowledge files | This prompt's job is to verify them against code — needs to read every one |

The knowledge files live in `.claude/agents/*.knowledge.md`. They are append-only and dated; Codex should treat the most recent dated entry as authoritative when entries conflict.

---

## Pre-analysis tooling — run once, share across all 12 sessions

Run this first, save outputs into `docs/analysis/runs/<YYYY-MM>-codex/_pre-analysis/`:

```bash
RUN=docs/analysis/runs/$(date +%Y-%m)-codex/_pre-analysis
mkdir -p "$RUN"

# Flutter / Dart
flutter --version > "$RUN/flutter-version.txt" 2>&1
flutter analyze > "$RUN/flutter-analyze.txt" 2>&1
flutter pub outdated > "$RUN/pub-outdated.txt" 2>&1
flutter pub deps --style=compact > "$RUN/pub-deps.txt" 2>&1

# Firestore / Firebase surface
wc -l firestore.rules storage.rules firestore.indexes.json > "$RUN/firebase-sizes.txt"
grep -c "match " firestore.rules >> "$RUN/firebase-sizes.txt"

# Cloud Functions
ls functions/src > "$RUN/functions-tree.txt"
grep -rh "region(" functions/src --include="*.ts" | sort -u > "$RUN/functions-regions.txt"

# Codebase scale
find lib -name "*.dart" ! -name "*.g.dart" ! -name "*.freezed.dart" ! -name "app_localizations*.dart" | wc -l > "$RUN/dart-file-count.txt"
find lib -name "*.dart" ! -name "*.g.dart" ! -name "*.freezed.dart" ! -name "app_localizations*.dart" -exec cat {} + | wc -l > "$RUN/dart-line-count.txt"
find lib -name "*.dart" ! -name "*.g.dart" ! -name "*.freezed.dart" ! -name "app_localizations*.dart" -exec wc -l {} + | awk '$1 > 500' | sort -rn > "$RUN/files-over-500-lines.txt"

# CI
ls .github/workflows > "$RUN/ci-workflows.txt"

# Test coverage (slow — optional)
flutter test --coverage > "$RUN/flutter-test.txt" 2>&1 || echo "test run failed/skipped" > "$RUN/flutter-test.txt"
```

Optional but recommended if installed:
```bash
osv-scanner --lockfile=pubspec.lock > "$RUN/osv-scanner.txt" 2>&1 || true
dcm analyze lib/ > "$RUN/dcm.txt" 2>&1 || true
dart tools/code_intelligence_platform.dart > "$RUN/code-intelligence.txt" 2>&1 || true
```

Every Codex session in this run gets to read the contents of `_pre-analysis/`.

---

## Differences vs the Claude execution model

| Aspect | Claude run | Codex run |
|--------|-----------|-----------|
| Subagent dispatch | Automatic via `Agent` tool | Not available — knowledge injected manually per this guide |
| Knowledge file reading | Subagent does it as Step 0 | Codex must be handed the files in the context bundle |
| Hook enforcement (markers, plan-review gate) | Active — protects against half-baked output | Not active — instruct Codex explicitly: "Phase 1 investigation only, no code changes, no doc writes outside the report" |
| File-size limit (500 lines) | Reinforced via `code-style.md` and the facade-pattern-detector skill | Reinforced via the prompt itself + `code-style.md` in the context bundle |
| Stop-hook behavior | Blocks on errors in modified files | N/A — Codex won't be modifying files |

---

## Output filename convention

Save each Phase 1 report at:

```
docs/analysis/runs/<YYYY-MM>-codex/<NN>-<topic>.md
```

Examples:
- `docs/analysis/runs/2026-05-codex/01-code-quality.md`
- `docs/analysis/runs/2026-05-codex/02-security.md`
- ...
- `docs/analysis/runs/2026-05-codex/12-doc-drift.md`
- `docs/analysis/runs/2026-05-codex/SYNTHESIS.md` (final consolidation per orchestrator)

The `runs/` folder is suitable for tracking via git (these are valuable historical artifacts — score trends matter), but if you'd rather not commit them, add `docs/analysis/runs/` to `.gitignore`.

---

## Synthesis session

After all 12 Phase 1 reports exist, open one final Codex session. Paste:

1. The orchestrator (for the synthesis instructions)
2. All 12 reports
3. The pre-analysis tooling output

Ask: *"Synthesize these 12 analysis reports using the Final Synthesis instructions from the Master Analysis Orchestrator. Save the result to `docs/analysis/runs/<YYYY-MM>-codex/SYNTHESIS.md`."*

The output is your consolidated audit report with the weighted overall score, top risks/strengths, sprint-structured remediation roadmap, and items needing immediate attention.
