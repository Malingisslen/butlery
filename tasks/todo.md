# Sprint Backlog

## Sprint: surface allergen+dietary settings (BUT-923 re-scoped) — 2026-06-08 (iter-129)

**Step 0:** BUT-923 premise OBSOLETE — `AllergenPreferencesView` already edits allergens AND
dietary safely (pre-loaded). Guided re-onboarding rejected as unsafe (re-seeds starter recipes,
blank-page pref-overwrite footgun). Re-scoped to the real gap: discoverability. Linear ticket
body updated.

### Agent A: flutter-developer — settings discoverability (BUT-923) `[Tier B]`
- [x] **A1. Subtitle support on `_SettingsTile`** `[Tier B]` — `settings_hub_view.dart`: added optional `String? subtitle` → ListTile subtitle (bodySmall/onSurfaceVariant). (BUT-923)
- [x] **A2. Relabel + subtitle the food-settings entry** `[Tier B]` — `allergenSettingsTitle` → "Allergener & kostpreferenser" / "Allergens & dietary"; new `allergenSettingsHubSubtitle`; wired subtitle on the hub tile. gen-l10n + analyze clean. (BUT-923)

### Post-Sprint Steps
- [ ] gen-l10n + `dart analyze --fatal-infos` + format
- [ ] code-reviewer + testing-specialist gates
- [ ] Commit, push
- [ ] BUT-923 → In Review + notify

---
## ARCHIVED — iter-128 (BUT-944 In Review; BUT-1213 filed) · iter-127 (BUT-1210 Done + BUT-1211 In Review; BUT-1212 filed) · iter-126 (BUT-914 In Review) · iter-125 (triage)
