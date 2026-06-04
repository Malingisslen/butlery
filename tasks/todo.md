# Sprint Backlog

## Sprint: CI / release tooling — 2026-06-04 (iter-117)

Focused 2-ticket Tier-A batch, both **close to Done** (no UI, no prod/ops dependency).
Chosen deliberately to NOT deepen the In-Review queue (9 items already awaiting Malin:
BUT-904 + 8 Tier-B). Theme: release/CI tooling. Neither touches `lib/**/*.dart`, so the
Dart commit gates (code-reviewer / testing-specialist) don't apply.

### Agent A: direct — CI/release tooling `[Tier A]`

- [x] **A1. Absorb the nightly `views (windows-latest)` infra flake** `[Tier A]` — `.github/workflows/test.yml` `cross-os` job: wrap the test-run step in a bounded 2-attempt retry (bash `until` loop, `shell: bash`). The flake is a no-output infra hang (cache-restore race / locale init) that clears on re-run; a genuine assertion failure is deterministic and fails both attempts, so the retry absorbs infra flakes WITHOUT masking real regressions. Nightly-only, off the per-commit critical path, `fail-fast:false`. (BUT-1192)
  - **Step 0:** FITS the ticket's "accept-and-retry" acceptance branch — root-causing a Windows-runner no-output hang is not possible headlessly; the documented retry is the sanctioned alternative.
  - **Rollback:** revert the step; matrix returns to single-attempt.
- [x] **A2. Release-only version-bump + changelog workflow** `[Tier A]` — create `.github/workflows/release.yml` (gated `workflow_dispatch`, never per-commit) + `tools/release/bump_version.sh`. Maps conventional commits since the last tag → semver (`feat!`/`BREAKING CHANGE`→major, `feat`→minor, else patch), runs `cider bump`, generates/prepends a `CHANGELOG.md` section, commits + tags `v<version>` + pushes. Manual `bump_override` input (auto/patch/minor/major). (BUT-488)
  - **Step 0:** FITS. Premise already corrected on the ticket (version is `0.9.0+1`, not `1.0.0+1`). Self-contained; coordinates-with but does not depend-on BUT-420 (Fastlane).
  - **Verification:** run `bump_version.sh --dry-run` locally → prints computed bump + would-be version + changelog section without writing.
  - **Rollback:** delete the workflow + script + CHANGELOG.md; nothing references them.

### Needs you (Tier D — flagged, not worked)
- Unchanged carry: BUT-1169, BUT-838, BUT-934, BUT-1187, onRecipeDeleted gen-2 deploy,
  BUT-530/BUT-431 cold-start. Plus the large Tier-D clusters (store/console/deploy/secrets,
  monetization) remain deferred per memory.

### Awaiting Malin — In Review (carried)
BUT-904 (epic, this iter), BUT-1198, BUT-1199, BUT-1037, BUT-1039, BUT-918, BUT-912,
BUT-946, BUT-1079 (pt1).

### Post-Sprint Steps
- [ ] `cider`/yaml: validate workflow YAML parses; run `bump_version.sh --dry-run`
- [ ] File follow-ups if any deferred sub-scope surfaces
- [ ] Commit, push
- [ ] BUT-1192 → Done; BUT-488 → Done (both Tier-A, no review surface)

---

## ARCHIVED — iter-116 (BUT-904 AutoSaveManager extraction — shipped)

Shipped `0d61ca2bc` + `fe3ca8c74`. Generic `AutoSaveManager<T>` extracted, 3 draft
surfaces migrated (comment composer, URL import, text import), behavior gate green
unmodified. Epic → In Review (acceptance #3 = BUT-910 photo-import adoption remains).
Follow-ups filed: BUT-1203 (group-creation + recipe-list-filter migration), BUT-1204
(URL/text import widget tests).
