# Scan — Role #25 Creative Director / Brand Lead

Lens: brand-token integrity, square-corner design language, color/logo/illustration system, butler voice.
Date: 2026-06-27. Two passes.

---

## PASS 1 — primary (brand-token inconsistencies)

### F1 [HIGH] Butler-voice violation — 69 Swedish UI strings use exclamation marks
The voice guide's rule #1 is absolute: "Inga utropstecken. Aldrig. Butlern höjer inte
rösten." Rule #4 explicitly bans "Grattis!". Yet `app_sv.arb` ships 69 strings ending in
`!`, including the one the guide names as forbidden.
- Evidence: `lib/l10n/app_sv.arb:4001` `celebrationFirstRecipeTitle` = `"Grattis!"`
  (directly the guide's banned example), `:4002` `...Message` ends `"...Välkommen till Butlery!"`.
- More: `:463` `successItemCreated` `"{itemType} skapades!"`, `:3986` `recipeSaved`
  `"Recept sparat!"`, `:3945` `profileSaved` `"Profil sparad!"`, `:662`
  `profileDeleteIrreversible` `"Denna åtgärd kan INTE ångras!"` (guide says
  "Åtgärden är slutgiltig."), `:451` `urlSuggestionOptimal` `"Perfekt — redo att importera!"`.
- Count: `grep -cE '": *"[^"]*!"' lib/l10n/app_sv.arb` → 69.
- This is the `butler-voice-guide.md` "~6,500 strings audit deferred" gap made concrete:
  the highest-visibility success/celebration strings are the worst offenders. A bounded
  first sweep (the ~69 exclamation strings) is the high-ROI slice of that audit.

### F2 [LOW] Brand-color discipline is clean — no NEW finding
Swept `lib/views` + `lib/widgets` for hardcoded `Color(0x...)` bypassing the palette:
exactly 1 hit — `vegetable_illustration.dart:214` `Color(0xFFFFFFFF)`, a deliberate
identity-modulate (white = preserve source) with an in-code comment. Not a violation.
Square-corner theme layer (FAB/dialog/snackbar) guarded by tests. Reported as a
clean result, not a ticket.

---

## PASS 2 — second sweep (doc↔code drift, assets, dark mode)

### F3 [MEDIUM] Mockup-reference doc drifted from the live palette — misleads future brand work
`docs/design/butlery-mockup-reference.md` is the cited brand color source but several rows
no longer match `lib/theme/app_colors.dart`. A designer trusting the doc would reintroduce
pre-WCAG / pre-rename values:
- `--green-muted` doc `#7A9A80` (`:20`) vs code `greenMuted` `#526A55`
  (`app_colors.dart:51`, darkened for WCAG AA on creamDarker). Doc shows the failing value.
- `--green-light` doc `#5A8F6A` (`:18`) vs code `forestGreenLight` `#6B9B7A`
  (`app_colors.dart:29`).
- `--rust-light` doc `#A67B5B` (`:22`) vs code `rustLight` `#A77B5E` (`app_colors.dart:36`).
- `--cream-dark`/`--cream-darker` naming shifted: doc maps `cream-dark`=`#E8E2D6`,
  `cream-darker`=`#D8D2C6` (`:25-26`); code has `creamDark`=`#F0EAD6`,
  `creamDarker`=`#E8E2D6` (`app_colors.dart:42,45`). The token names point at different hexes.
- NOTE: the cream *scale* itself is an accepted deviation (left-as-is) — the finding is the
  **doc**, not the colors. The fix is to update the doc to the WCAG-corrected, renamed
  reality so it stops being a trap, per the dossier's existing BUT-695-style "document at
  source" concern.

### F4 [LOW] Dark-mode brand correctness is sound — no NEW finding
`darkColorScheme` (`app_colors.dart:233-260`) seeds from forestGreen, then explicitly warms
the surfaces (brown-tinted, not cold auto-green) and overrides secondary toward a rust tone
(`#D4A88A` rust-80) and error to a true red — preserving the green-primary / rust-accent /
warm-cream brand identity in dark. FAB-square test already asserts both Brightness modes.
No drift found.

### F5 [LOW] Brand assets complete — no NEW finding
All 12 seasonal vegetable `.webp` illustrations present in `assets/illustrations/`
(broccoli, champinjon, artskida, morot, rodlok, sparris, rabarber, bar, pumpa, kal, citrus,
rodbeta) matching `vegetable_illustration.dart:85-98`. The earlier "seasonal variants map to
placeholders" note (BUT-409) is resolved — dedicated assets shipped. No missing-asset gap.

---

## Already-known (NOT filed — dedup)
- AppLogo defaults to `Icons.restaurant_menu` instead of a butler-branded icon → already a
  dossier Watch item (`app_logo.dart:67`). Confirmed still present; not NEW.
- Square-corner call-site lint/CI gate absence → dossier Watch item + BUT-695. Not NEW.
- WebP illustrations → BUT-429 (tracker). Cream scale, rating-badge green, "Lagat idag"
  chip, UNKNOWN allergen hidden → accepted-deviations.md / memory. Not filed.

---

## NEW findings: 3 (F1 HIGH, F3 MEDIUM; F2/F4/F5 are clean-result notes, not tickets)

COVERAGE: butler-voice (app_sv.arb exclamation sweep), palette discipline (lib/views +
lib/widgets hardcoded-color sweep), square-corner theme layer (button_themes.dart + fab test),
mockup-reference doc vs app_colors.dart, dark-mode ColorScheme brand overrides, brand assets
(12/12 illustrations + app-icon set), AppLogo widget. Owned paths all read.
