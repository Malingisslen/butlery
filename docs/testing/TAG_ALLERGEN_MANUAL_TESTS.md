# Manual Testing Plan: Tag & Allergen System

**Created**: 2026-01-30
**Last Updated**: 2026-01-30
**Status**: Ready for Testing

---

## Overview

This plan covers comprehensive manual testing of:
1. **Personal Tags** - User-created tag organization with automation rules
2. **Allergen/Dietary System** - Tri-state allergen tracking and preferences
3. **Recipe Integration** - How both systems display and filter recipes

---

## Test Summary

| Part | Section | Tests | Completed | Passed | Failed | Notes |
|------|---------|-------|-----------|--------|--------|-------|
| 1 | Tag Management | 13 | 0 | 0 | 0 | - |
| 1 | Tag Groups | 11 | 0 | 0 | 0 | - |
| 1 | Sorting | 3 | 0 | 0 | 0 | - |
| 1 | Automation Rules | 25 | 0 | 0 | 0 | - |
| 1 | Tag Statistics | 5 | 0 | 0 | 0 | - |
| 2 | Allergen Preferences | 11 | 0 | 0 | 0 | - |
| 2 | Tri-State Badges | 6 | 0 | 0 | 0 | - |
| 2 | Dietary Preferences | 7 | 0 | 0 | 0 | - |
| 2 | Coverage Indicator | 4 | 0 | 0 | 0 | - |
| 3 | Tags on Recipes | 10 | 0 | 0 | 0 | - |
| 3 | Adding/Removing Tags | 5 | 0 | 0 | 0 | - |
| 3 | Filtering by Tags | 6 | 0 | 0 | 0 | - |
| 3 | Search + Tags | 3 | 0 | 0 | 0 | - |
| 4 | Edge Cases | 16 | 0 | 0 | 0 | - |
| 5 | Performance | 4 | 0 | 0 | 0 | - |
| **TOTAL** | | **129** | **0** | **0** | **0** | - |

---

## PART 1: PERSONAL TAGS SYSTEM

### 1.1 Tag Management (Basic CRUD) - 13 tests

#### Create Tag

| Test ID | Step | Action | Expected Result | Status | Notes |
|---------|------|--------|-----------------|--------|-------|
| TAG-CREATE-01 | 1 | Open Personal Tags view (Settings → Mina taggar) | View loads with existing tags or empty state | Pending | - |
| TAG-CREATE-02 | 2 | Tap + button → "Skapa tagg" | Dialog opens with name field | Pending | - |
| TAG-CREATE-03 | 3 | Enter "Testtagg" → Skapa | Success: "Tagg skapad", tag appears in list | Pending | - |

#### Validation Tests

| Test ID | Test | Input | Expected Error | Status | Notes |
|---------|------|-------|----------------|--------|-------|
| TAG-VALID-01 | Empty name | (blank) → Skapa | "Taggnamn krävs" | Pending | - |
| TAG-VALID-02 | Too long | 51+ characters | "Taggnamn för långt (max 50 tecken)" | Pending | - |
| TAG-VALID-03 | Comma | "Test, tag" | "Taggnamn får inte innehålla kommatecken" | Pending | - |
| TAG-VALID-04 | Duplicate | Same name as existing | "En tagg med namnet finns redan" | Pending | - |

#### Edit Tag

| Test ID | Step | Action | Expected | Status | Notes |
|---------|------|--------|----------|--------|-------|
| TAG-EDIT-01 | 1 | Long-press tag → "Redigera namn" | Edit dialog with current name | Pending | - |
| TAG-EDIT-02 | 2 | Change name → Spara | "Tagg uppdaterad" | Pending | - |

#### Delete Tag

| Test ID | Step | Action | Expected | Status | Notes |
|---------|------|--------|----------|--------|-------|
| TAG-DEL-01 | 1 | Long-press tag → "Ta bort tagg" | Confirmation dialog | Pending | - |
| TAG-DEL-02 | 2 | Confirm delete | "Tagg borttagen", removed from list | Pending | - |
| TAG-DEL-03 | 3 | Check recipes that had this tag | Tag removed from all recipes | Pending | - |

---

### 1.2 Tag Groups - 11 tests

#### Create Group

| Test ID | Step | Action | Expected | Status | Notes |
|---------|------|--------|----------|--------|-------|
| GROUP-CREATE-01 | 1 | Tap + → "Skapa grupp" | Dialog opens | Pending | - |
| GROUP-CREATE-02 | 2 | Enter "Måltider" → Skapa | Group appears in list with no tags | Pending | - |

#### Move Tag to Group

| Test ID | Step | Action | Expected | Status | Notes |
|---------|------|--------|----------|--------|-------|
| GROUP-MOVE-01 | 1 | Long-press tag → "Flytta till grupp" | Selection dialog | Pending | - |
| GROUP-MOVE-02 | 2 | Select group | "Tagg flyttad", tag now under group header | Pending | - |

#### Create Group During Move

| Test ID | Step | Action | Expected | Status | Notes |
|---------|------|--------|----------|--------|-------|
| GROUP-MOVE-NEW-01 | 1 | Long-press tag → "Flytta till grupp" | Selection dialog | Pending | - |
| GROUP-MOVE-NEW-02 | 2 | Tap "Skapa ny grupp" | Name dialog | Pending | - |
| GROUP-MOVE-NEW-03 | 3 | Enter name → Skapa | "Grupp skapad och tagg flyttad" | Pending | - |

#### Ungroup Tag

| Test ID | Step | Action | Expected | Status | Notes |
|---------|------|--------|----------|--------|-------|
| GROUP-UNGROUP-01 | 1 | Long-press grouped tag → "Flytta till grupp" | Selection dialog | Pending | - |
| GROUP-UNGROUP-02 | 2 | Select "Ingen grupp" | Tag moves to ungrouped section | Pending | - |

#### Rename/Delete Group

| Test ID | Action | Expected | Status | Notes |
|---------|--------|----------|--------|-------|
| GROUP-RENAME-01 | Tap group menu (⋮) → "Byt namn" → Change → Spara | "Grupp uppdaterad" | Pending | - |
| GROUP-DELETE-01 | Tap group menu → "Ta bort grupp" → Confirm | Group deleted, tags become ungrouped | Pending | - |

---

### 1.3 Sorting - 3 tests

| Test ID | Sort Option | Action | Verify | Status | Notes |
|---------|-------------|--------|--------|--------|-------|
| SORT-01 | By Usage | Select "Användning" | Most-used tags first | Pending | - |
| SORT-02 | By Name | Select "Namn" | Alphabetical A-Z | Pending | - |
| SORT-03 | By Rules | Select "Antal regler" | Tags with most active rules first | Pending | - |

---

### 1.4 Automation Rules - 25 tests

#### Create Rule

| Test ID | Step | Action | Expected | Status | Notes |
|---------|------|--------|----------|--------|-------|
| RULE-CREATE-01 | 1 | Tap tag → open detail view | Tag detail with rules section | Pending | - |
| RULE-CREATE-02 | 2 | Tap "Lägg till" | Rule builder bottom sheet | Pending | - |
| RULE-CREATE-03 | 3 | Enter rule name "Fiskrecept" | Name field filled | Pending | - |
| RULE-CREATE-04 | 4 | Set condition: Ingredient contains "lax" | Condition card configured | Pending | - |
| RULE-CREATE-05 | 5 | Tap "Skapa" | "Regel skapad", rule appears in list | Pending | - |

#### Rule Conditions (12 tests)

| Test ID | Type | Operator | Example Value | Expected Match | Status | Notes |
|---------|------|----------|---------------|----------------|--------|-------|
| RULE-COND-01 | Ingrediens | innehåller | "kyckling" | Recipes with chicken | Pending | - |
| RULE-COND-02 | Egenskap | har | "seafood" | Recipes with seafood ingredients | Pending | - |
| RULE-COND-03 | Nyckelord | innehåller | "snabb" | Title/description contains "snabb" | Pending | - |
| RULE-COND-04 | Källa | innehåller | "ica.se" | Source URL contains domain | Pending | - |
| RULE-COND-05 | Kök | är exakt | "italian" | Cuisine tag equals "italian" | Pending | - |
| RULE-COND-06 | Kost | är exakt | "vegetarian" | Dietary status is vegetarian | Pending | - |
| RULE-COND-07 | Tid | mindre än | "30" | Cooking time < 30 minutes | Pending | - |
| RULE-COND-08 | Betyg | minst | "4" | Rating >= 4 stars | Pending | - |
| RULE-COND-09 | Nyligen | inom dagar | "7" | Added within last 7 days | Pending | - |
| RULE-COND-10 | Ägarskap | är exakt | "mine" | User owns the recipe | Pending | - |
| RULE-COND-11 | Har bild | är exakt | "true" | Recipe has image | Pending | - |
| RULE-COND-12 | Fullständighet | är exakt | "complete" | Recipe is complete | Pending | - |

#### Match Modes

| Test ID | Mode | Behavior | Test | Status | Notes |
|---------|------|----------|------|--------|-------|
| RULE-MATCH-01 | Alla (AND) | All conditions must match | Create 2 conditions, verify both required | Pending | - |
| RULE-MATCH-02 | Något (OR) | Any condition matches | Create 2 conditions, verify either works | Pending | - |

#### Rule Operations

| Test ID | Action | Expected | Status | Notes |
|---------|--------|----------|--------|-------|
| RULE-TOGGLE-01 | Toggle rule switch OFF | "Regel inaktiverad" | Pending | - |
| RULE-TOGGLE-02 | Toggle rule switch ON | "Regel aktiverad" | Pending | - |
| RULE-DELETE-01 | Tap rule menu → "Ta bort" → Confirm | "Regel borttagen" | Pending | - |
| RULE-BULK-01 | Long-press tag → "Aktivera alla regler" | All rules enabled, success message | Pending | - |
| RULE-BULK-02 | Long-press tag → "Inaktivera alla regler" | All rules disabled, success message | Pending | - |

#### Apply Rules to Existing Recipes

| Test ID | Step | Action | Expected | Status | Notes |
|---------|------|--------|----------|--------|-------|
| RULE-APPLY-01 | 1 | In tag detail → menu → "Kör regler" | Progress dialog | Pending | - |
| RULE-APPLY-02 | 2 | Wait for completion | "X taggar tillämpade på Y recept" | Pending | - |

---

### 1.5 Tag Statistics - 5 tests

| Test ID | Check | Location | Expected | Status | Notes |
|---------|-------|----------|----------|--------|-------|
| STAT-01 | Recipe count | Tag tile subtitle | "X recept" | Pending | - |
| STAT-02 | Rule count | Tag tile subtitle | "X regler aktiva" | Pending | - |
| STAT-03 | Match count | Rule tile in detail | "X recept matchar" (green if >0) | Pending | - |
| STAT-04 | Unused indicator | Tag tile | Grayed out if 0 recipes | Pending | - |
| STAT-05 | Group count | Group header | Shows member count | Pending | - |

---

## PART 2: ALLERGEN/DIETARY SYSTEM

### 2.1 Allergen Preferences - 11 tests

#### Access Settings

| Test ID | Step | Action | Expected | Status | Notes |
|---------|------|--------|----------|--------|-------|
| ALLERG-ACCESS-01 | 1 | Settings → Allergeninställningar | Preferences view opens | Pending | - |
| ALLERG-ACCESS-02 | 2 | See tracked allergens | FilterChips for allergens/dietary | Pending | - |

#### Configure Allergens

| Test ID | Action | Expected | Status | Notes |
|---------|--------|----------|--------|-------|
| ALLERG-CONFIG-01 | Toggle "gluten" ON | Gluten tracking enabled | Pending | - |
| ALLERG-CONFIG-02 | Toggle "mjölk" OFF | Dairy tracking disabled | Pending | - |
| ALLERG-CONFIG-03 | Tap "Spara" | "Inställningar sparade" | Pending | - |

#### Display Settings

| Test ID | Setting | Effect | Status | Notes |
|---------|---------|--------|--------|-------|
| ALLERG-DISPLAY-01 | "Visa på receptkort" ON | Badges appear on recipe cards | Pending | - |
| ALLERG-DISPLAY-02 | "Visa på receptkort" OFF | Badges hidden on cards | Pending | - |
| ALLERG-DISPLAY-03 | "Visa på receptdetaljer" ON | Full allergen section in detail | Pending | - |
| ALLERG-DISPLAY-04 | "Visa på receptdetaljer" OFF | Allergen section hidden | Pending | - |
| ALLERG-DISPLAY-05 | "Visa täckning" ON/OFF | Coverage % shown/hidden | Pending | - |

#### Reset to Defaults

| Test ID | Step | Action | Expected | Status | Notes |
|---------|------|--------|----------|--------|-------|
| ALLERG-RESET-01 | 1 | Tap "Återställ till standard" | Confirmation dialog | Pending | - |
| ALLERG-RESET-02 | 2 | Confirm | Default allergens restored (gluten, mjölk, nötter, jordnötter) | Pending | - |

---

### 2.2 Tri-State Badge Display - 6 tests

#### Badge States

| Test ID | State | Visual | Meaning | Status | Notes |
|---------|-------|--------|---------|--------|-------|
| BADGE-STATE-01 | FREE | Green circle + ✓ | Safe - no allergen detected | Pending | - |
| BADGE-STATE-02 | CONTAINS | Red triangle + ⚠ | Warning - allergen present | Pending | - |
| BADGE-STATE-03 | UNKNOWN | Gray circle + ? | Uncertain - incomplete data | Pending | - |

#### Test Each State

| Test ID | Test | Recipe Condition | Expected Badge | Status | Notes |
|---------|------|------------------|----------------|--------|-------|
| BADGE-TEST-01 | Glutenfri | Recipe with no gluten ingredients, 100% coverage | Green "glutenfri" | Pending | - |
| BADGE-TEST-02 | Innehåller gluten | Recipe with bread/pasta | Red "innehåller gluten" | Pending | - |
| BADGE-TEST-03 | Unknown | Recipe with unknown ingredients | Gray "?" | Pending | - |

---

### 2.3 Dietary Preferences - 7 tests

| Test ID | Dietary | What It Means | Test Recipe | Status | Notes |
|---------|---------|---------------|-------------|--------|-------|
| DIET-01 | Vegetarisk | No meat/fish | Recipe with only vegetables | Pending | - |
| DIET-02 | Vegansk | No animal products | Recipe with no eggs/dairy/meat | Pending | - |
| DIET-03 | Pescetarian | Has fish, no meat | Recipe with fish | Pending | - |
| DIET-04 | Graviditetssäker | No high-mercury fish, no alcohol | Recipe with safe ingredients | Pending | - |
| DIET-05 | Barnvänlig | No spicy, no alcohol | Recipe suitable for kids | Pending | - |
| DIET-06 | Halalanpassad | No pork, no alcohol | Halal-compatible recipe | Pending | - |
| DIET-07 | Kosheranpassad | No pork, no shellfish | Kosher-compatible recipe | Pending | - |

---

### 2.4 Coverage Indicator - 4 tests

| Test ID | Coverage | Display | Meaning | Status | Notes |
|---------|----------|---------|---------|--------|-------|
| COVER-01 | 100% | "100% av ingredienser analyserade" | All ingredients in database | Pending | - |
| COVER-02 | 80-99% | "X% av ingredienser analyserade" | Most recognized | Pending | - |
| COVER-03 | <80% | Warning indicator | Unreliable allergen claims | Pending | - |
| COVER-04 | 0% | "Inga ingredienser analyserade" | No ingredients matched | Pending | - |

---

## PART 3: RECIPE INTEGRATION

### 3.1 Viewing Tags on Recipes - 10 tests

#### On Recipe Card

| Test ID | Element | Location | Expected | Status | Notes |
|---------|---------|----------|----------|--------|-------|
| CARD-TAG-01 | Auto-generated tags | Below title | Up to 5 gray chips | Pending | - |
| CARD-TAG-02 | Personal tags | With auto tags | Accent colored chips | Pending | - |
| CARD-TAG-03 | Allergen badges | Inline/compact | Only tracked allergens | Pending | - |
| CARD-TAG-04 | Tag overflow | When >5 tags | Shows "+N" chip | Pending | - |
| CARD-TAG-05 | No tags state | Recipe without tags | No tag section shown | Pending | - |

#### On Recipe Detail

| Test ID | Section | Content | Status | Notes |
|---------|---------|---------|--------|-------|
| DETAIL-TAG-01 | Description | Recipe description | Pending | - |
| DETAIL-TAG-02 | Tags section | Auto + personal tags | Pending | - |
| DETAIL-TAG-03 | Allergen section | Full allergen/dietary status | Pending | - |
| DETAIL-TAG-04 | Coverage | Percentage indicator | Pending | - |
| DETAIL-TAG-05 | Unknown ingredients | List if any | Pending | - |

---

### 3.2 Adding/Removing Tags from Recipe - 5 tests

#### Quick Add (From Detail)

| Test ID | Step | Action | Expected | Status | Notes |
|---------|------|--------|----------|--------|-------|
| QUICK-ADD-01 | 1 | Open recipe detail | Recipe view | Pending | - |
| QUICK-ADD-02 | 2 | Tap tags section or FAB | Tag selector bottom sheet | Pending | - |
| QUICK-ADD-03 | 3 | Tap tag chip to toggle | Chip becomes selected/deselected | Pending | - |
| QUICK-ADD-04 | 4 | Tap "Spara" | "X taggar sparade" | Pending | - |

#### Verify Tag Applied

| Test ID | Check | Expected | Status | Notes |
|---------|-------|----------|--------|-------|
| QUICK-VERIFY-01 | Recipe card | Shows new tag | Pending | - |

---

### 3.3 Filtering by Tags - 6 tests

#### Personal Tag Filters

| Test ID | Step | Action | Expected | Status | Notes |
|---------|------|--------|----------|--------|-------|
| FILTER-TAG-01 | 1 | Open recipe list | Full list | Pending | - |
| FILTER-TAG-02 | 2 | Tap filter icon | Filter panel expands | Pending | - |
| FILTER-TAG-03 | 3 | Select "Fiskrecept" tag | Only fish recipes shown | Pending | - |
| FILTER-TAG-04 | 4 | Select second tag | AND logic - narrower results | Pending | - |

#### Allergen-Free Filters

| Test ID | Filter | Expected Results | Status | Notes |
|---------|--------|------------------|--------|-------|
| FILTER-ALLERG-01 | Glutenfri | Only recipes with gluten=FREE | Pending | - |
| FILTER-ALLERG-02 | Mjölkfri | Only recipes with dairy=FREE | Pending | - |

---

### 3.4 Search + Tags - 3 tests

| Test ID | Search Query | Expected | Status | Notes |
|---------|--------------|----------|--------|-------|
| SEARCH-TAG-01 | "pasta" | Recipes with "pasta" in title/ingredients | Pending | - |
| SEARCH-TAG-02 | Search + tag filter | Intersection of search + filter | Pending | - |
| SEARCH-TAG-03 | Tag name search | Matches recipes with that tag | Pending | - |

---

## PART 4: EDGE CASES & ERROR HANDLING

### 4.1 Tag Edge Cases - 6 tests

| Test ID | Scenario | Test | Expected | Status | Notes |
|---------|----------|------|----------|--------|-------|
| EDGE-TAG-01 | Very long name | Enter 50 characters | Accepts at limit | Pending | - |
| EDGE-TAG-02 | Special characters | "Tag (test) #1" | Accepts (except comma) | Pending | - |
| EDGE-TAG-03 | Unicode | "Recept 🍕" | May work (test it) | Pending | - |
| EDGE-TAG-04 | Empty group | Create group, don't add tags | Shows "Inga taggar i denna grupp" | Pending | - |
| EDGE-TAG-05 | Delete tag with recipes | Delete applied tag | Removed from all recipes | Pending | - |
| EDGE-TAG-06 | Reserved name | Try to create "vegetarian" | Should reject or warn | Pending | - |

### 4.2 Rule Edge Cases - 6 tests

| Test ID | Scenario | Test | Expected | Status | Notes |
|---------|----------|------|----------|--------|-------|
| EDGE-RULE-01 | 0 conditions | Try to save with no conditions | Error: at least 1 required | Pending | - |
| EDGE-RULE-02 | Empty value | Condition with blank value | Error: "Alla villkor måste ha ett värde" | Pending | - |
| EDGE-RULE-03 | Numeric 0 | Time = 0 | Error: value required | Pending | - |
| EDGE-RULE-04 | Regex characters | Ingredient contains "C++" | Should not crash | Pending | - |
| EDGE-RULE-05 | Many conditions | Add 10+ conditions | UI handles scrolling | Pending | - |
| EDGE-RULE-06 | Duplicate rule name | Same name as existing rule | Should accept or warn | Pending | - |

### 4.3 Allergen Edge Cases - 4 tests

| Test ID | Scenario | Test | Expected | Status | Notes |
|---------|----------|------|----------|--------|-------|
| EDGE-ALLERG-01 | No ingredients | Recipe with 0 ingredients | Shows "Lägg till ingredienser..." | Pending | - |
| EDGE-ALLERG-02 | All unknown | All ingredients unrecognized | generatorVersion = 'all_unknown' | Pending | - |
| EDGE-ALLERG-03 | Pending | Recipe saved offline | Shows "Analyseras..." | Pending | - |
| EDGE-ALLERG-04 | Failed tagging | Tagging error | Shows error, retry option | Pending | - |

---

## PART 5: PERFORMANCE - 4 tests

| Test ID | Test | Action | Acceptable | Status | Notes |
|---------|------|--------|------------|--------|-------|
| PERF-01 | Many tags | Create 50+ tags | Smooth scrolling | Pending | - |
| PERF-02 | Many rules | Tag with 20+ rules | Detail view loads quickly | Pending | - |
| PERF-03 | Batch apply | Run rules on 500 recipes | Completes, shows progress | Pending | - |
| PERF-04 | Large recipe list | Filter 1000+ recipes | Responsive filtering | Pending | - |

---

## Bug Tracker

### Open Bugs

| Bug ID | Title | Test ID | Severity | Status | Notes |
|--------|-------|---------|----------|--------|-------|

### Fixed Bugs

| Bug ID | Title | Test ID | Severity | Fix Date | Notes |
|--------|-------|---------|----------|----------|-------|

---

## Verification Workflow

1. **Run app**: `flutter run -d chrome`
2. **Navigate**: Settings → Personal Tags / Allergen Preferences
3. **Test each section** in order above
4. **Document**: Note any failures or unexpected behavior
5. **Edge cases**: Test boundary conditions last

---

## Quick Reference: Swedish UI Labels

| English | Swedish |
|---------|---------|
| Create tag | Skapa tagg |
| Create group | Skapa grupp |
| Move to group | Flytta till grupp |
| No group | Ingen grupp |
| Edit name | Redigera namn |
| Delete tag | Ta bort tagg |
| Run rules | Kör regler |
| Enable all rules | Aktivera alla regler |
| Disable all rules | Inaktivera alla regler |
| Allergen settings | Allergeninställningar |
| Save settings | Spara inställningar |
| Reset to defaults | Återställ till standard |
| Contains | Innehåller |
| Free from | Fri från |
| Unknown | Okänd |

---

## Key Files Reference

| Component | File Path |
|-----------|-----------|
| Personal Tags View | `lib/views/personal_tags_view.dart` |
| Tag Detail View | `lib/views/tag_detail_view.dart` |
| Personal Tag ViewModel | `lib/viewmodels/personal_tag_viewmodel.dart` |
| Allergen Preferences View | `lib/views/settings/allergen_preferences_view.dart` |
| Allergen ViewModel | `lib/viewmodels/allergen_preferences_viewmodel.dart` |
| Personal Tag Service | `lib/services/tagging/personal_tag_service.dart` |
| PersonalTag Model | `lib/models/tagging/personal_tag.dart` |
| PersonalTagRule Model | `lib/models/tagging/personal_tag_rule.dart` |
| AllergenStatusBadge Widget | `lib/widgets/tagging/allergen_status_badge.dart` |
| AllergenConfig | `lib/services/tagging/config/allergen_config.dart` |
| TriState Model | `lib/models/tagging/tri_state.dart` |

---

## Session Log

### Session 1: 2026-01-30

**Tester**: _______
**Start Time**: _______
**End Time**: _______

**Tests Completed**: _______
**Bugs Found**: _______
**Notes**:
