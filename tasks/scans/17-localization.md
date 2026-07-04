# Scan — Role #17 Localization / i18n

Date: 2026-06-27
Lens: en/sv ARB parity, locale switching, date/time/number formatting, hardcoded strings.
ARB state: app_sv.arb 4287 keys / app_en.arb 4286 keys (verified by parsing both files).

## PASS 1 — key parity, hardcoded strings, placeholder/ICU integrity

### NEW-1 [Medium] English users see a Swedish string for `privacyActivityFeedHint`
The only en/sv key-parity gap. `privacyActivityFeedHint` (BUT-1220 — one-time hint shown
the first time a user broadcasts an activity event) exists in `app_sv.arb` but is MISSING
from `app_en.arb`. gen-l10n's untranslated-message fallback has baked the **Swedish** value
straight into the generated English class:
- `lib/l10n/app_localizations_en.dart:5934-5935` → `String get privacyActivityFeedHint => 'Klart! Dina vänner ser nu din aktivitet i sitt flöde. Du kan stänga av det här när som helst.';`

So an English-locale user who first broadcasts activity reads Swedish copy. Fix = add the
EN translation key + value to `app_en.arb` and regenerate. This is a real translation gap,
not a metadata artifact (key is referenced via the generated getter).
Evidence: lib/l10n/app_sv.arb (privacyActivityFeedHint present), lib/l10n/app_en.arb (absent),
lib/l10n/app_localizations_en.dart:5934.

### NEW-2 [Low] Hardcoded Swedish strings in maintenance_mode_blocker.dart
`lib/widgets/maintenance_mode_blocker.dart` renders two user-facing Swedish literals not
routed through l10n:
- line 63: `Text('Underhållsläge', ...)` (the maintenance-mode title)
- line 88: `child: const Text('Försök igen')` (the retry button)
The body message uses an injected `displayMessage` variable, but the title and button are
hardcoded. EN users see Swedish. Not covered by BUT-609 (3 specific literals) or BUT-1381
(shopping-list name + message FAB label). Add `maintenanceMode*` keys to both ARBs.
Evidence: lib/widgets/maintenance_mode_blocker.dart:62-63, 88.

### Verified CLEAN (no findings)
- **Placeholder parity:** 0 real `{placeholder}` mismatches across the 4286 shared keys.
  (A naive scan flags 22 "mismatches" but every one is just ICU plural literal text differing
  by language — e.g. `Inga`/`No`, `1` count words — with identical actual placeholders
  `{count}`/`{name}`/`{days}`. These are correct, NOT bugs.)
- **ICU plural integrity:** 0 keys where `plural,` appears in one language but not the other.
- **Hardcoded `Text('...')` in lib/views + lib/widgets:** only the maintenance_mode_blocker
  hits above; everything else routes through `context.l10n`.

## PASS 2 — formatting locale-awareness, persistence, metric descriptor

No NEW findings. Everything in scope is either already in the role dossier or already
ticketed:
- **metric_descriptor.dart:70** hardcodes `NumberFormat.decimalPattern('sv')` — confirmed
  still present, but this is a **named dossier watch-item** for role #17 (not NEW). Admin-only
  surface; admin app is Swedish anyway.
- **ContextualTimeFormatter call sites missing `localeName`** (10+ sites) — confirmed, but a
  **named dossier watch-item** (not NEW).
- **share_service.dart formatWeekMenu hardcodes 'sv'** for weekday key lookup — confirmed, a
  **named dossier watch-item** (not NEW).
- **DateFormat locale-awareness sweep** → already BUT-622.
- **Standardise date/time formatting** → already BUT-961.
- **Locale-aware currency on shopping prices** → already BUT-988.
- **hintText/labelText/errorText/tooltip hardcoded-string audit (258 sites)** → already BUT-615.
- **Localise route names** → already BUT-967.
- **iOS Info.plist permission descriptions Swedish-only** → already BUT-705.
- **ICU pluralization coverage audit** → already BUT-712.
- **native-EN spot-check of app_en.arb** → already BUT-713.
- **488-key gap reconcile + @key descriptions** → already BUT-703 / BUT-704 (+ follow-up).
- **Locale-switch persistence:** LocaleProvider (SharedPreferences `preferred_locale`) +
  singleton-identity guard test (locale_provider_singleton_test.dart, BUT-801) — healthy,
  no gap.

## DEDUP
Checked against tasks/_scan_dedup_titles.txt, .claude/linear-tracker.json (366 open + done),
.claude/rules/accepted-deviations.md, and role-#17 dossier watch-items. NEW-1 and NEW-2 are
not present in any of them. (BUT-704 ARB descriptions, BUT-703 key gap, BUT-622/961/988/615/
967/705/712/713 formatting/hardcoded/plural items all pre-tracked and excluded.)

COVERAGE: 2 passes complete. 2 NEW findings (1 Medium, 1 Low). The big-ticket i18n surface
(key gap, descriptions, formatting locale-awareness, hardcoded sweeps, route names) is
saturated by existing BUT- tickets + dossier watch-items; only two genuinely untracked items
surfaced — the EN-missing `privacyActivityFeedHint` string and the maintenance-blocker
hardcoded literals.
