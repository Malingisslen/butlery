# Sprint Backlog

## Sprint: wave-17 — Settings UX + bulk recipe→menu + backend hygiene — 2026-05-23 (Sa)

Theme: 8 tickets across three batches. Settings/account UX visibility (BUT-913, 958, 932), bulk recipe→menu suite completion (BUT-1029→1013, 1014), backend hygiene (BUT-995 prompt caching, BUT-970 dead-code decision). Wave-16 verified closed in Linear by parallel session.

### Batch A — Settings/Account UX (`flutter-developer`)
- [ ] **A1. BUT-913 (High)** — Surface Sign-out + Delete-Account in Settings UI (GDPR). `lib/views/settings/settings_view.dart` + new account section. Delete-Account calls server-side `requestAccountDeletion` CF.
- [ ] **A2. BUT-958 (High)** — Sync conflict resolution visible to user. New `sync_conflict_banner.dart` widget + wire to `offline_sync_manager.dart`.
- [ ] **A3. BUT-932 (Medium)** — Recipe photo deletion undo. SnackBar-with-Ångra pattern in `recipe_edit_form.dart` + viewmodel snapshot.

### Batch B — Bulk recipe→menu suite (`flutter-developer`, sequenced)
- [ ] **B1. BUT-1029 (Medium)** — SlotPickerDialog widget (prereq for B2). `lib/widgets/menu/slot_picker_dialog.dart` + 5–6 l10n keys.
- [ ] **B2. BUT-1013 (High)** — Bulk add-to-menu on selection. Uses B1. `selection_app_bar.dart` + `bulkAddRecipesToMenuSlots` on menu VM with undo.
- [ ] **B3. BUT-1014 (Medium)** — Bulk export selected recipes (clipboard markdown + file JSON). `selection_app_bar.dart` + `recipe_export_service.dart`.

### Batch C — Backend hygiene
- [ ] **C1. BUT-995 (High)** — Adopt prompt caching on LLM calls (`cloud-functions-specialist`). `functions/src/llm/` Anthropic `cache_control: ephemeral` wrap.
- [ ] **C2. BUT-970 (High)** — Wire or delete `backup_service.dart` (`flutter-developer`). Decision in commit message.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` clean across all changed files
- [ ] `dart format --set-exit-if-changed lib test` clean
- [ ] Tier-2 reviews: `code-reviewer` + `testing-specialist` + `firebase-backend-security` (A1+C2 touch auth/account)
- [ ] File follow-ups in Linear (anything deferred / reviewer findings / test gaps)
- [ ] Commit + push to main
- [ ] Close Linear tickets to Done
- [ ] CI watcher

---

## Archived wave-16 (commit ae7cc297e + tier-2 follow-ups) — 2026-05-23 (Sa)

Theme: 2 High tickets + 1 obsoletion. Wave-15 was found 8/8 Done in Linear at sprint start (parallel session shipped without checking off `todo.md`). BUT-1013 was deferred mid-sprint after Step 0 verification revealed the prereq picker dialog doesn't exist; filed BUT-1029 for the prereq.

### Batch A — Recipe-list bulk tag (`flutter-developer`)
- [x] **A1. BUT-1012 (High)** — `lib/views/mina_recept/selection_app_bar.dart` + `lib/viewmodels/recipe_list_viewmodel.dart`: new bulk-tag IconButton + inline `_BulkTagPicker` modal sheet + `bulkApplyPersonalTag` (merge, skip already-tagged) + `undoBulkApplyPersonalTag` with per-recipe snapshot. l10n: 5 new bulk-tag keys (sv + en + generated). Tests: 5 new VM unit tests covering modified-count, already-tagged skip, empty selection, undo safety.

### Batch B — Image upload size reduction (`flutter-developer`)
- [x] **B1. BUT-992 (High)** — `lib/services/image_picker_service.dart`: defaults `2400→1600`, `quality 90→80` across `pickImage`, `pickMultipleImages`, `cropImage.compressQuality`. Existing tests updated + 2 regression-guard assertions added that the new literals are passed through.

### Batch C — Obsoletion housekeeping
- [x] **BUT-938** — closed as obsolete (multi-image carousel already shipped via `UniversalImageManager.recipeDetail` at `recipe_detail_content.dart:560-567`).

### Mid-sprint scope changes
- [~] **BUT-1013** — deferred. Plan-stale: ticket assumed a single-recipe slot picker existed for reuse, but no such picker exists. Filed prereq BUT-1029 (SlotPickerDialog widget), blocked BUT-1013 on it. Re-picked in wave-17.

## Archived wave-15 (parallel-session ships) — 2026-05-23 (Sa)

wave-15 — 8 tickets planned (BUT-1022, 1026, 1020, 1015, 1017, 1019, 1018, 1027). Parallel session shipped 8/8 at 2026-05-23T17:59 without checking off this file. Lesson re-reinforced: Linear state is authoritative; local `todo.md` lies when two sessions run concurrently.

## Archived wave-14 (parallel-session ships) — 2026-05-23 (Sa)

wave-14 — 7 planned, 5 shipped by parallel session (BUT-1024, 1025, 1021, 1023, 1016). Carry-over BUT-1022 + BUT-1026 absorbed into wave-15.

## Archived wave-13 (commits 3fc2d1edc + 66a786479 + 3f7d40412) — 2026-05-22 (Fr)

wave-13 — 9 Bug/UX tickets. 7 shipped, 2 obsoleted/rescoped. Follow-ups BUT-1012–1017.

## Archived wave-12 (commits 185ba807e + eb4562bc6) — 2026-05-22 (Fr)

wave-12 — 7 done + 2 deferred.

## Archived wave-11 (commits 7551c14c2 + bca2f5bc7) — 2026-05-22 (Fr)

wave-11 — BUT-788 server-side account-deletion. New `requestAccountDeletion` CF. Follow-ups BUT-1009/1010/1011.

## Archived wave-10 (commit 826dceed1) — 2026-05-22 (Fr)

wave-10 — BUT-782 FCMService static→instance + DI refactor.

## Archived wave-9 (commits 55d49d993 + 602420b91) — 2026-05-22 (Fr)

wave-9 — LLM golden runners + repo test-coverage. BUT-888.

## Archived wave-8 (commit 633595561) — 2026-05-22

wave-8 — BUT-784/886/882/887.

## Archived wave-7 (commit 5bd98f8e8 / 7ed82246c)

wave-7 — BUT-878/455/811/798.

## Archived wave-6 (commit 273152149)

wave-6 — BUT-876/802/452.

## Archived wave-5 (commit b66f5892f)

wave-5 — BUT-660/872/865/866/873.

## Archived wave-4 (commit 90d88cfca / b115d7519)

wave-3 follow-ups — BUT-868/869/870/871/867/776/864.

## Archived wave-3 (commit 8e54f68f2)

UI consolidation + CI + model integrity tests — BUT-861/579/801/841/825/823.
