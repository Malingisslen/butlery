# Scan — Role #20 Technical Writer / Documentation

Two passes complete. Reviewed owned paths through the doc/code-divergence + staleness + auto-reachability lens:
`.claude/plan-review-checklist.md`, `.claude/rules/*.md`, `CLAUDE.md`, `docs/architecture/**`,
`lib/repositories/CLAUDE.md`, `lib/services/CLAUDE.md`.

All figures below verified against actual files (file:line) and `bash tools/count_large_files.sh`.

---

## NEW

### 1. Stale "148 files >500 lines" claim in 3 owned files — actual is 169 (tech-debt)

`bash tools/count_large_files.sh` returns **169** today (2026-06-27). Three doc surfaces still state **148**
(re-counted 2026-06-21), a +21 drift never refreshed:

- `.claude/rules/code-style.md:6` — "**148 files currently >500 lines** (re-counted 2026-06-21…)"
- `docs/architecture/ACCEPTED_LARGE_FILES.md:3` — "**Last Updated**: 2026-06-21 (148 files >500 lines…)"
- `docs/architecture/ACCEPTED_LARGE_FILES.md:13` — "**148 files currently >500 lines** in lib/ … expect ±2 churn"

The ±2 churn caveat is now off by ~19. The count is the headline number reviewers trust before deciding
whether a large-file finding is in-scope; a 169-vs-148 gap means ~21 newly-oversized files have no recorded
rationale in ACCEPTED_LARGE_FILES.md and would be (correctly) flaggable but the doc implies they're catalogued.
Fix: re-run the counter, update all three numbers + the date, and audit which of the 21 net-new files need a
rationale row vs. genuine refactor candidates.

**Evidence:** `tools/count_large_files.sh` → 169 · `.claude/rules/code-style.md:6` ·
`docs/architecture/ACCEPTED_LARGE_FILES.md:3,13`

### 2. ROLE_RESPONSIBILITY_MAP §20 contradicts its own existence — "no Technical Writer role" / "18 roles" (tech-debt)

Section **20. Technical Writer / Documentation** (the very section this scan owns) carries prose and a watch
item written *as if it were a gap proposal*, never reconciled after the role was actually added to the map:

- `docs/architecture/ROLE_RESPONSIBILITY_MAP.md:590` (§20 body): "**Not yet in ROLE_RESPONSIBILITY_MAP** —
  no dedicated Technical Writer role defined." — false: it is §20.
- `:598` (§20 watch item): "ROLE_RESPONSIBILITY_MAP … **enumerates 18 roles** but does not include a Technical
  Writer / Documentation owner …" — false on both counts: the map's index lists **28 roles** (`:8` "staff 28
  notional roles"; index `:30–60`) and §20 *is* the Technical Writer owner.

A role-map that misstates its own role count and denies the existence of one of its own sections is exactly the
"doc contradicted by code" the role guards against — and it's self-inflicted. Fix: rewrite the §20 body's last
sentence and the third watch item to reflect that the role now exists (the meta-gap it described is closed), or
repoint the watch item at the still-open operational gap ("Documentation Drift Has No Operational Owner" already
in the map's gaps section — see DEDUP note).

**Evidence:** `docs/architecture/ROLE_RESPONSIBILITY_MAP.md:8,30–60` (28 roles) · `:590` · `:598`

### 3. ROLE_RESPONSIBILITY_MAP §20 body has stale doc-inventory counts (tech-debt, minor)

§20's narrative (`docs/architecture/ROLE_RESPONSIBILITY_MAP.md:590`) miscounts the corpus it claims to govern:

- "**6 per-directory CLAUDE.md guides** (services, repositories, viewmodels, views, widgets, and a root)" —
  there are **5** per-directory guides + 1 root (verified: `lib/{repositories,services,viewmodels,views,widgets}/CLAUDE.md`
  + root `CLAUDE.md`). The parenthetical lists 5 dirs but the headline says 6 "per-directory".
- "**8 ops/ docs** (age-rating, moderation, cert-rotation, llm-kill-switch, presence-ttl, storage-lifecycle,
  gcp-alerting, app-review-demo)" — there are **9** files in `docs/ops/`, and the named list is wrong:
  `cert-rotation` does not exist; the actual set adds `backups.md` and `freerasp-runbook.md`.
- "plus **4 security/** … docs" — `docs/security/` contains **3** `.md` files.
- "lessons.md with **22** dated post-correction entries" — now **23** (`grep -cE '^### ' tasks/lessons.md`).
- Also still cites adoption "measured **2026-06-26**" (`:590`) while `docs/architecture/adoption-status.md:7`
  now reads `2026-06-27T04:26:23Z`. The percentages it quotes (66.7% BaseService, 53.1% perm-validation
  effective) still match, so only the date is stale.

Low individual stakes but they cluster in the one section a Technical Writer is most expected to keep exact.
Bundle the fix with #2 (same paragraph).

**Evidence:** `docs/architecture/ROLE_RESPONSIBILITY_MAP.md:590` · `lib/*/CLAUDE.md` (5) + `CLAUDE.md` ·
`docs/ops/` (9 files) · `docs/security/` (3) · `tasks/lessons.md` (23 `###`) · `docs/architecture/adoption-status.md:7`

---

## Verified-clean (no finding)

- `docs/architecture/adoption-status.md` figures (66.7%/53.1% etc.) are auto-generated and current
  (measured 2026-06-27); the "nightly" claim is backed by real CI `.github/workflows/adoption-status-nightly.yml`.
- adoption-status.md and ROLE_RESPONSIBILITY_MAP.md are both reachable (referenced by `.claude/rules/`,
  `.claude/commands/`, `.claude/hooks/`, `docs/org/role-paths.json`) — not orphaned/write-only.
- `lib/services/CLAUDE.md` and `lib/repositories/CLAUDE.md` correctly *link* to adoption-status.md instead of
  inlining percentages (BUT-776 discipline holds) — no figure drift.
- Map §6 references to `docs/org/adr/` resolve (ADR-0001/0002 exist); §5/§21 evidence paths spot-checked exist.
- `docs/FEATURE_INVENTORY.md` figures (137/80/40/17) internally consistent and match memory.
- The map's two §20 watch items about *unfiled tracking tickets* (app-review-demo seed CF; LLM golden-test
  corpora) — both docs exist, but these are already represented in the backlog dedup list (BUT-416-followup
  seed work; "BUT-784 follow-up: 4 paid-API LLM golden corpora") → NOT new.

## DEDUP

The map's own "Documentation Drift Has No Operational Owner" gap covers the *systemic* lack of a doc-freshness
owner — findings #1–#3 above are concrete, already-stale instances (specific numbers in specific files), not a
restatement of that systemic gap, so they are filed as discrete actionables per instructions. Nothing here
overlaps `tasks/_scan_dedup_titles.txt`, `.claude/linear-tracker.json`, or `accepted-deviations.md`.

COVERAGE: owned paths fully reviewed (2 passes). 3 NEW findings (all tech-debt: one cross-file stale count, two
self-referential staleness in ROLE_RESPONSIBILITY_MAP §20). No tickets created.
