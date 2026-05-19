# Sprint Backlog

## Sprint: tech-debt sweep + UI consolidation — 2026-05-19 (Tu) wave 3

Theme: 7 backlog tickets across UI consolidation, CI hardening, and refactor cleanup. Prior sprint (BUT-817/842) fully closed in Linear (BUT-855/856/853/857 also closed as premise-gone).

### Agent A: flutter-developer — UI widget consolidation
- [ ] **A1. BUT-861** — Migrate centered full-screen `CircularProgressIndicator` → `StateWidget.loading()` (Phase 1 of BUT-798). Grep `Center(\s*child:\s*CircularProgressIndicator` in `lib/views/`. ~25 sites.
- [ ] **A2. BUT-579** — Consolidate parallel button systems (`styled_button` + `common/buttons` + `adaptive`). Pick canonical family, `@Deprecated` the others, document in `lib/widgets/common/buttons/README.md`.
- [ ] **A3. BUT-801** — Settings → locale switcher (sv/en); fix macOS `APP_NAME` placeholder in Info.plist (×6); fix Windows `L"butlery"` → `L"Butlery"` in `windows/runner/main.cpp`.

### Agent B: testing-specialist — CI + integration test
- [ ] **B1. BUT-825** — Wire `dart run tools/measure_adoption.dart` into nightly CI (`.github/workflows/adoption-status-nightly.yml`, `0 3 * * *` cron, auto-commit `docs/architecture/adoption-status.md` on diff).
- [ ] **B2. BUT-823** — Integration test for `_verifyModelIntegrity` short-circuit: assert no `.tmp` on hash mismatch, `ensureModelAvailable()` returns null, Crashlytics non-fatal `ModelIntegrityCheckFailure` emitted. Both `ner_model_manager` + `line_classifier_model_manager`.

### Agent C: refactor cluster
- [ ] **C1. BUT-530** — Extract `lib/widgets/app/butlery_app.dart` from `lib/main.dart` (~+357 line drift, real number; ticket said +63 but stale). Bring imports + tests.
- [ ] **C2. BUT-841** — Bulk migrate `as String? ?? default` (and `as int? ?? …`) in `lib/models/` to `SerializationUtils.safeString/safeInt` etc. Cosmetic but consistent.

### Step 0 status
- All 7 tickets need Step 0 verification before implementation (read current code, classify fits/premise-gone/stale).
- **Dropped:** BUT-520 (multi-sprint EPIC, not in-sprint scope — reverted to Backlog).

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` clean
- [ ] Tier-2 agent reviews (code-reviewer + testing-specialist) — markers written before commit
- [ ] File follow-ups in Linear (mandatory before commit, see Follow-up rule)
- [ ] Commit (inline) + push direct to main (solo workflow)
- [ ] Close Linear tickets for completed work
- [ ] CI watcher

---

## Archived prior sprint (commit 4b2cea116)

CI-test verification sweep + LRU/GDPR hardening — 2026-05-19 (Tu) — BUT-817 (5 LruMap caches) + BUT-842 (GDPR catch-swallow → transient/fatal split) shipped. BUT-855/856/853/857 closed as premise-gone (Step 0 re-verification). Follow-ups BUT-864/865/866 filed.
