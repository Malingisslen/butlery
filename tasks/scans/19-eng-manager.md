# Scan — Role #19 Engineering Manager / Release Manager

Lens: sprint/commit workflow integrity, CI gating, process-automation correctness, git-workflow safety.
Date: 2026-06-27 · 2 passes done.

Owned paths reviewed: `.claude/commands/sprint-execute.md`, `.claude/hooks/{loop-pace-guard,require-review-before-commit,require-simplify-before-commit}.sh`, `.claude/rules/git-workflow.md`, `.claude/settings.json`, `.claude/settings.local.json`, `.claude/workflows/sprint-execute-parallel.js`, `.github/workflows/test.yml`, `CLAUDE.md`.

---

## NEW findings

### 1. [HIGH] Commit-gate hooks bypassable by a commit MESSAGE containing `-h`/`--help`/`--version` text
Both `require-review-before-commit.sh:37` and `require-simplify-before-commit.sh:30` short-circuit (exit 0, gate skipped) when the help/version regex `(--help|--version|-h[[:space:]]|-h$)` matches **anywhere in the raw command string** — including inside the `-m` message. Verified live:
- `git commit -m "fix -h flag handling in parser"` → matches `-h ` → **gate skipped**
- `git commit -m "document --help output"` → **gate skipped**
- `git commit -m "bump --version handling"` → **gate skipped**

Effect: a normal commit whose message happens to mention a CLI flag ships `.dart` code with NO code-reviewer / testing-specialist / firebase-security / rules-tester / code-review markers enforced. This is a silent, easily-triggered marker-gate bypass — not the narrow help/version passthrough intended.
Fix: detect help/version only as an actual *flag argument* (parse the same way `INCLUDE_UNSTAGED` does with `shlex` and check the args list), not via `grep` over the whole command line. Apply to both hooks (shared logic).
Evidence: `.claude/hooks/require-review-before-commit.sh:37`, `.claude/hooks/require-simplify-before-commit.sh:30`.

### 2. [MEDIUM] `git commit --no-verify` silently skips the entire lefthook layer and nothing detects it
The PreToolUse marker hooks run before git, so they still require markers — but `--no-verify` (or `-n`) bypasses **lefthook** entirely: `secret-scan`, `arch-guard` (BUT-581 `?? ''` ban), `format`, `real-time-guard` (`lefthook.yml` pre-commit). `bash-firewall.sh` does not block it (only `git reset --hard` is guarded), and the only prohibition lives in prose in `sprint-execute.md:420`. The owned `git-workflow.md` rule and `CLAUDE.md` say nothing. So an ad-hoc or agent commit with `--no-verify` ships unscanned secrets / arch-guard violations with no mechanical trip.
Fix: add `--no-verify`/`-n` detection to the commit-gate hooks (block, or at minimum require markers AND warn), OR add a `git-workflow.md` rule + a one-line `bash-firewall.sh` guard. Mechanical guard preferred over prose (consistent with how the loop-pace rule was promoted to a hook).
Evidence: `lefthook.yml` (pre-commit commands), `.claude/hooks/bash-firewall.sh:40`, `.claude/rules/git-workflow.md` (no `--no-verify` mention), `.claude/commands/sprint-execute.md:420`.

### 3. [LOW] `git-workflow.md` omits the project's two hardest-won commit rules
The owned rule file documents lefthook reformat-and-retry but is silent on two rules enforced everywhere else: (a) never `--no-verify` / never `--amend` published commits (only in `sprint-execute.md:420`), and (b) the specialist-marker / `/code-review` commit gates that actually block commits (only in `CLAUDE.md`). A reader of `git-workflow.md` alone would not know commits are gated. Consolidate the commit-safety rules into the file that owns "Git Workflow".
Evidence: `.claude/rules/git-workflow.md` vs `CLAUDE.md` (Agent Usage Rules / Pre-commit) and `sprint-execute.md:420`.

---

## Investigated, NOT filed (no defect / already covered)

- `LEFTHOOK_EXCLUDE=analyze` ship path (`sprint-execute-parallel.js:662`): correct — `lefthook.yml:33` documents the deliberate skip (analyze already run upstream; iter-147 Windows hang). No bug.
- Dry-run safety (`sprint-execute-parallel.js:29,65,229,259`): defensively parses stringified args, skips clean-tree precondition only for read-only dry-run, blocks all mutations. Sound (prior footgun fixed).
- Marker honesty in parallel Ship (`:435–448,656`): markers only touched for reviewers that truly ran; `reviewTargets.length > 0` guard prevents faking cr/ts gates with zero targets. Sound.
- INCLUDE_UNSTAGED arg parser (both hooks): `shlex`-based `-a`/`--all` detection with correct takes-arg skip list; `git commit -F <msg>` handled. Correct.
- test.yml `firebase.json` heredoc fallback (`:507`): dead branch (repo has `firebase.json`), but harmless — not worth a ticket.
- loop-pace-guard regex brittleness + state-dir split: already captured as watch-items under role #18 / #19 dossiers — not re-filed.
- settings.local.json permission drift (54 stale entries): already an existing role-#19 watch-item — not re-filed.
- Phase 2.7 vs Phase 5.5 naming mismatch: already an existing role-#19 watch-item — not re-filed.

---

COVERAGE: sprint-execute.md (commands), sprint-execute-parallel.js (workflow), require-review/require-simplify/loop-pace-guard hooks, bash-firewall+lefthook (gate context), git-workflow.md, settings.json + settings.local.json, test.yml, CLAUDE.md. 3 NEW (1 HIGH, 1 MEDIUM, 1 LOW); remainder already-covered watch-items or no-defect.
