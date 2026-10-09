# BUT-2301 + BUT-2302 del 2 (2026-10-09)

Malin approved both in the backlog thread ("gör det"). Redesign owns layout, so the change
reuses existing components only (`TextButton.icon` with the plus glyph, `_SettingsTile`).

Step-0 measurements, read on `main` 576abde:

- `sectioned_ingredient_list_builder.dart` `_handleLineChange` and
  `dynamic_list_builder.dart` `_handleChange` add a line only when `value.length == 1`, so a
  paste, dictation or word suggestion that lands several characters at once never adds one.
  Neither widget shows an add-line button (the dynamic list shows one only when empty).
- `skriv_sjalv_recept_view.dart` `_buildDynamicList` (instructions in "Skriv manuellt") has
  no auto-add by design (its comment points at a "+ Add" button) but renders the button only
  when the list is empty, so only one instruction can be entered.
- `GdprConsentHandler.handleExportData` always `Navigator.pop`s first (it assumes the
  profile sheet); `SettingsHubView` has no export row. `BackupRestoreHandler` already solved
  the same thing with `closeModal: false` (BUT-2150).

- [ ] BUT-2301
  - AC1: in both list widgets the auto-add fires when the LAST line becomes non-empty,
    whatever the number of characters in the change. It calls new view-model methods
    (`ensureTrailingIngredientLine` / `ensureTrailingInstructionLine`) that add only when the
    manager's last value is non-empty, because the widgets get a fresh controller-list copy
    per build and cannot tell that a line was already added.
  - AC2: both list widgets and the skriv-själv instruction list always show "Lägg till
    ingrediens" / "Lägg till instruktion" below the rows.
  - AC3: widget tests — a paste into the last field asks for a line, into an earlier field
    does not; the button adds one. VM tests — two requests add one line.
- [ ] BUT-2302 del 2
  - AC4: `handleExportData` takes `closeModal` (default true); Settings → Konto shows
    "Exportera mina data" and opens the export without popping Settings.
  - AC5: widget tests — the row renders in Settings, and tapping it leaves Settings open.
- [ ] Verify: analyze + changed tests, PR, CI green, merge, close both tickets.

## Sammanfattning för Malin

Receptformuläret får en ny tom rad även när man klistrar in eller dikterar, och en synlig
knapp "Lägg till ingrediens" (och "Lägg till instruktion"). Under Inställningar → Konto
finns nu "Exportera mina data". Inga nya vyer eller layoutändringar.
