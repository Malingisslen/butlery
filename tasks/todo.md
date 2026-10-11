# Mer, omtänkt: ny struktur och ett formspråk för allt under Mer (2026-10-10)

Malin approved the proposal on 2026-10-10 ("Kör", thread "Mer, omtänkt"; mockup
https://claude.ai/artifact/DgYQzTN2nmHNRMQoJZEWiM) and chose on a card to remove Inställningar
as a level. This plan builds that mockup. The previous plan in this file (BUT-2287/2288) shipped
in #700 and #703.

Router: `python tools/stakeholder_router.py --json <the paths below>` → tier `single`
(Software Architect, Product Manager), no high-stakes hits. No Firestore, rules, Cloud Functions or
model change anywhere in this plan: every slice moves, merges or restyles existing UI and keeps the
existing handlers and services (AuthActionHandler, GdprConsentHandler, BackupRestoreHandler,
UserService, ThemeService, LocaleProvider).

## Target structure (from the approved mockup)

```
Mer (rot)
 ├ [Profil-rad: avatar, namn, "Profil och synlighet"] → Profil (UserProfileEditView, utan tema/språk)
 ├ [Band "N ändringar väntar på synk", bara när något väntar] → Väntar på synk
 ├ TILLSAMMANS: Notiser · Meddelanden · Vänner & grupper · Delat med mig
 ├ HUSHÅLL & MAT: Familj & hushåll · Allergener & kost
 ├ DITT KÖK: Egna taggar · Statistik · Papperskorgen
 └ KONTO & APP: Konto & säkerhet · Integritet & data · Appinställningar · Hjälp & om
```

- Konto & säkerhet: E-postadress, Lösenord, Tvåstegsverifiering, Logga ut, Radera kontot (sist, lerröd).
- Integritet & data: Samtycken, Blockerade personer, Exportera mina data, Säkerhetskopia (ark:
  ladda ner / återställ), Integritetspolicy.
- Appinställningar: Språk (ark), Tema (ark), Notisinställningar, Lägg köpta varor i skafferiet.
- Hjälp & om: Vanliga frågor, Användarvillkor, Gemenskapsriktlinjer, Mina rapporter (överklaga
  där), Granska rapporter (bara admin), Version, Licenser.
- Profilmenyn bakom avataren (ProfileMenu-arket, RecipeListAvatarBadge) tas bort; SettingsHubView
  och AboutButleryView tas bort; HouseholdSizeView går upp i Familj & hushåll.

## Design rules every slice follows (mockup tab "Designreglerna")

One home per thing; at most two levels under Mer; ButleryTopBar.rot on Mer and .undersida with
`backTo` everywhere else; rows, not cards, for settings and navigation; one section header (the
green overline); toggles and choices save at once with a short snackbar, only text forms have a
Spara at the bottom; one primary button per view; destructive actions last or in the ⋯ menu,
confirmed through the existing ConfirmationDialog; choices in a bottom sheet; the row's name is the
page's title. Colours, type and spacing from lib/theme only. The input fields thread owns
lib/theme/** input decoration and StyledInput: use StyledInput as-is, touch neither.

## Slices (one PR each, in this order; 2–4 can run in parallel after 1 merges)

1. **Mer och de fyra områdena** (this thread first)
   - New shared `lib/widgets/common/list/butlery_list.dart`: `ButleryListSection` (overline +
     rows with dividers) and `ButleryListRow` (nav, value, count, toggle, add, danger), extracted
     from MoreView's `_Section`/`_MoreRow` so every Mer page draws the same row.
   - MoreView: profile row, sync band, four sections as above; avatar slot removed.
   - New views under `lib/views/more/`: `account_area_view.dart`, `privacy_area_view.dart`,
     `app_settings_view.dart`, `help_area_view.dart`, plus a small choice sheet for språk/tema.
     Konto & säkerhet's three login rows open the existing AccountSecurityView until slice 5.
   - Routes: new `settingsAccount`, `settingsPrivacy`, `settingsHelp`; `Routes.settings` now opens
     Appinställningar (keeps old links alive); `group_household_join_tile` goes to settingsFamily.
   - Delete SettingsHubView, AboutButleryView, ProfileMenu + its builders, RecipeListAvatarBadge;
     move AutoAddPantryTile and LanguageTile's logic into app settings; theme + language leave
     UserProfileEditView.
   - Mer's own row labels follow the mockup; the pages' own titles (Notiser, Statistik, Notisinställningar,
     Samtycken) are aligned in slice 3, where those pages are touched anyway. MinFamiljView gets the
     Portioner row and the three household allergen tiles as they are, so nothing from the old hub is
     lost; slice 2 restyles them.
   - Update tests that pinned the old surfaces; new widget tests for MoreView, the four areas and
     the list widgets; workflow map, package4 adoption list, design/beslutslogg.md B-52.
2. **Familj & hushåll**: MinFamiljView gets Portioner (sheet) and the three household allergen
   toggles; HouseholdSizeView and its route go; family rows use ButleryListRow; lowercase titles fixed.
3. **Enhetliga undersidor**: Allergener & kost (autosave, no cards, no double Spara), Notisinställningar,
   Samtycken, Papperskorgen (row → sheet), Statistik, Egna taggar + tagg, Väntar på synk. Page titles
   match their Mer rows; Blockerade personer gets its own row on Integritet & data.
4. **Socialt**: Vänner & grupper (three tabs, requests row, search in the bar, no FABs), group
   detail (each action once, ⋯ menu), friend profile, Meddelanden (one new-message button, ⋯ per
   row), Delat med mig (chips). Bugs: group vote's `'/add-recipe'` → `Routes.addRecipe`; the
   friend-request push opens Vänförfrågningar.
5. **Konto & säkerhet** (after #641 merges): AccountSecurityView splits into E-postadress,
   Lösenord and Tvåstegsverifiering pages; legal rows leave it.

## Verification per slice

`flutter analyze` clean on touched files; `flutter test` on changed and new tests plus
`test/architecture/`; the review gates in `.claude/shared-plugin.json → reviewGates`
(code-reviewer, testing-specialist, integration-reviewer; max three files per run); run the app on
web and screenshot Mer and each area in light and dark before "done"; CI green before merge.

## Open questions

No architecture-changing unknowns. Assumptions: `/settings` keeps working as a link (now
Appinställningar); the "Nyheter" row joins Hjälp & om when #702 merges, not in this plan; the
chat view itself is out of scope.

## För Malin

Jag bygger förslaget i fem delar, en PR var. Först Mer och de fyra nya raderna (Konto & säkerhet,
Integritet & data, Appinställningar, Hjälp & om), så att Inställningar och profilmenyn försvinner.
Sedan Familj & hushåll, sedan att undersidorna ser likadana ut, sedan vänner och meddelanden.
Kontosäkerheten delas upp sist, när tvåstegsverifieringen är mergad. Ingen data eller säkerhetsregel
ändras; det är bara var saker ligger och hur de ser ut.
