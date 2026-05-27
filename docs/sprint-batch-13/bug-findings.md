# Intent-Test Sprint Batch 13 — Bug Findings

**Sprint-final batch.** Linear MCP was disconnected at filing time; these
bugs need to be moved to Linear tickets when the integration reconnects.

Each bug includes the test that pins the current (buggy) behaviour so
the fix-PR author can flip the assertion and prove the fix.

---

## HIGH-severity — data loss / GDPR integrity

### BUG-AUTOSAVE-1: scheduleAutoSave cancels timer before guard check
- **File:** `lib/viewmodels/recipe_form/recipe_auto_save_manager.dart:100-107`
- **Symptom:** User types during an in-flight save with `skipIfBusy: true`.
  Any previously-queued debounce timer (representing an unwritten edit)
  is silently cancelled, and the new schedule is dropped. If the user
  stops typing right then, the edit is **LOST until they type again**.
- **Code shape:**
  ```dart
  void scheduleAutoSave(...) {
    _autoSaveTimer?.cancel();             // ← cancels FIRST
    if (_isAutoSaving && skipIfBusy) {    // ← then guards
      return;
    }
    ...
  }
  ```
- **Fix:** Swap order — check the guard first, cancel only if proceeding.
  Or queue a single follow-up timer in a `finally` inside
  `_performAutoSave`.
- **Test pin:** see `test/unit/viewmodels/recipe_form/recipe_auto_save_manager_test.dart`.
- **Discovered:** Batch 13, 2026-05-27.

### BUG-BACKUP-1: user_email never restored from export envelope
- **File:** `lib/services/backup_service.dart:35` (export) and `:245` (import)
- **Symptom:** Export writes `user_id: currentUser?.uid`. Import reads
  `backupData['user_email']` — which is never written by export.
  Effect: every round-trip backup made by current builds yields
  `ImportResult.exportEmail == null`. UI "imported by user@x.com on
  date Y" breadcrumb is silently broken. GDPR-adjacent data-portability gap.
- **Fix:** one-line — export should also write `'user_email': currentUser?.email`.
- **Test pin:** `test/unit/services/backup_service_test.dart` — test name
  `'exportEmail comes from user_email field, not user_id (asymmetry)'`.
- **Discovered:** Batch 13, 2026-05-27.

---

## MED-severity — race conditions / diagnostic loss

### BUG-AUTOSAVE-2: clearCurrentDraft fires unawaited deleteDraft
- **File:** `lib/viewmodels/recipe_form/recipe_auto_save_manager.dart:387-392`
- **Symptom:** Consumer pattern `clearCurrentDraft(); saveNow(form);`
  races the unawaited `deleteDraft` against the new save's metadata
  write. The `_metadataWriteLock` doesn't help because `deleteDraft`
  is fired BEFORE the lock is acquired by the next save.
- **Code shape:**
  ```dart
  void clearCurrentDraft() {
    if (_currentDraftId != null) {
      deleteDraft(_currentDraftId!);  // unawaited!
      _currentDraftId = null;
    }
  }
  ```
- **Fix:** Make `clearCurrentDraft` `async` and `await deleteDraft(...)`.
  Update callers.
- **Discovered:** Batch 13, 2026-05-27.

### BUG-BACKUP-2: per-recipe import error always reads "Okänt recept"
- **File:** `lib/services/backup_service.dart:235`
- **Symptom:** Catch block reads `recipeJson['title']` but `Recipe.toJson()`
  nests `title` under `core.title`. Top-level lookup is always null.
  User importing a backup where 5 recipes fail (Firestore quota, etc.)
  sees 5 identical "Okänt recept: <error>" lines — can't tell which
  recipes to retry.
- **Fix:** `recipeJson['core']?['title'] ?? recipeJson['title'] ?? AppLocale.current.backupUnknownRecipe`.
- **Test pin:** `test/unit/services/backup_service_test.dart` — test name
  `'isolates per-recipe repository failures into errors list'`.
- **Discovered:** Batch 13, 2026-05-27.

---

## LOW-severity — API hygiene

### BUG-AUTOSAVE-3: clearCurrentDraft signature is void despite async work
- **File:** `lib/viewmodels/recipe_form/recipe_auto_save_manager.dart:387-392`
- **Symptom:** Same site as BUG-AUTOSAVE-2. The `void` return type lies
  about the operation — callers can't await the cleanup. Promoting to
  `Future<void>` is a no-op for fire-and-forget callers but enables
  correct sequencing for those that need it.
- **Fix:** Same as BUG-AUTOSAVE-2.
- **Discovered:** Batch 13, 2026-05-27.

---

## Testability friction (production design notes)

- `RecipeFormAutoSaveManager._performAutoSave` is private + tightly bound
  to `SharedPreferences.getInstance()` — no seam for injecting a fake
  store. Tests have to drive everything through
  `SharedPreferences.setMockInitialValues`. Adequate, but can't assert
  "exactly N writes" without inspecting end-state shape.
- `BackupService` constructs `FirebaseAuthRepository()` directly (line 35)
  — not via DI. Untestable without real Firebase init. Should inject
  `AuthRepository` via constructor (same shape as BUT-1062 / BUT-1063
  / BUT-1075 / BUT-1095 — recurring pattern).

---

## Status (when Linear reconnects)

Convert each bug above to a Linear ticket. Cross-link to BUT-1059..BUT-1133
where applicable. The auto-save bugs are recipe-form severity; the backup
bugs are GDPR-adjacent (`backup` / `gdpr` labels).
