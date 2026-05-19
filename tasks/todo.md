# Sprint Backlog

## Sprint: wave-3 follow-ups + UI consolidation continuation — 2026-05-19 (Tu) wave 4

Theme: 7 tickets, heavy on test-gap closure for wave 3 (BUT-868/869/870/871) plus a UI consolidation continuation (BUT-867) and two backend hygiene items (BUT-776/864). All small/medium scope; the follow-ups were filed in fresh context so files and call-sites are already named.

### Agent A: testing-specialist — wave 3 test-gap closure
- [x] **A1. BUT-868** — `test/unit/core/di/locale_provider_singleton_test.dart` asserts `identical()` between `DIContainer.get` and `ServiceLocator.get` paths.
- [x] **A2. BUT-869** — `test/widget/views/settings/language_tile_test.dart` covers render + dialog + setLocale (`_LanguageTile` made public for testability).
- [x] **A3. BUT-870** — `test/unit/services/parsing/model_manager_integrity_test.dart` extended with 2 scenarios: unregistered version aborts; stale-`.tmp` cleanup on cache load. (Transient-throw scenario deferred — `firebase_storage_mocks` can't fake mid-call throws.)
- [x] **A4. BUT-871** — `test/unit/models/notification_history_entry_test.dart` covers `displayTitle` / `displayBody` getters + BUT-841 coercion contract.

### Agent B: flutter-developer — UI consolidation
- [x] **B1. BUT-867** — All 28 `StyledButton.primary` / `.secondary` / bare-ctor sites migrated to `ActionButtons.primaryButton` / `.secondaryButton`. `styled_button.dart` + `StyledButtons` helper + `styled_button_test.dart` deleted. `styled_widgets.dart` barrel + `lib/widgets/common/buttons/README.md` updated.

### Agent C: backend hygiene + tooling
- [x] **C1. BUT-776 (rescoped inline)** — Step 0 found site-packages exclusion + adoption-status.md migration already shipped in BUT-825. Remaining scope: created `tools/check_no_inline_adoption_pct.sh` (narrowed regex — keyword + %) + wired into `architecture-validation.yml`. Fixed 4 actual violations in `docs/analysis/prompts/02_SECURITY_AND_COMPLIANCE.md`.
- [x] **C2. BUT-864** — `DataExportService.exportUserData` now aggregates per-section `error_code` markers into `export_metadata.warnings[]`. Two unit tests in `data_export_service_test.dart` pin the contract (transient → warning; happy-path → no warnings key).

### Step 0 status
- All 7 tickets need Step 0 verification before implementation. Wave-3 follow-ups (A1–A4, B1, C2) are recent context so most should classify as "fits"; C1 (BUT-776) is older and may need rescoping.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` clean
- [ ] Tier-2 agent reviews (code-reviewer + testing-specialist + firebase-backend-security on C2) — markers written before commit
- [ ] File follow-ups in Linear (mandatory before commit, see Follow-up rule)
- [ ] Commit (inline) + push direct to main (solo workflow)
- [ ] Close Linear tickets for completed work
- [ ] CI watcher

---

## Archived prior sprint (commit 8e54f68f2)

UI consolidation + CI + model integrity tests — 2026-05-19 (Tu) wave 3 — BUT-861/579/801/841/825/823 shipped. BUT-520/530 reverted as multi-sprint EPICs. Follow-ups BUT-867/868/869/870/871 filed (now this sprint).

## Archived two-sprints-ago (commit 4b2cea116)

CI-test verification sweep + LRU/GDPR hardening — BUT-817 + BUT-842 shipped. BUT-855/856/853/857 closed as premise-gone. Follow-ups BUT-864/865/866 filed.
