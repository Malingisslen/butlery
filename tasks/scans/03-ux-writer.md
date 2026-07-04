# UX Writer / Content Strategist — scan (role #3)

Scope: docs/design/butler-voice-guide.md, lib/l10n/app_sv.arb, lib/l10n/app_en.arb,
lib/widgets/common/first_recipe_celebration_overlay.dart, .claude/rules/code-style.md.

Note on dedup: The dossier (ROLE_RESPONSIBILITY_MAP #3 watch-items) already documents the four
big tone gaps — exclamation marks (now 76 sv / 76 en, drifted down from 87/86), 21× "Är du säker"
vs prescribed "Bekräftelse krävs", the "Grattis!" celebration overlay, and the missing tone
enforcement mechanism. Those are documented, so per the dedup rule I file NEW tickets only for
concrete actionables not already captured. Two qualify.

---

### Add the butler-voice PR-template link the guide explicitly requires (and create the missing PR template)
- type: chore  area: content  priority: medium
- pass: 2
- finding: butler-voice-guide.md lines 67–68 prescribe a concrete mechanism — "Länka till den i
  PR-mallen när en ny sträng läggs till i `app_sv.arb` eller `app_en.arb`." No PR template exists
  at all (`.github/PULL_REQUEST_TEMPLATE.md` / `pull_request_template.md` absent). The guide's own
  required enforcement hook is therefore unimplemented.
- why: This is the ONE enforcement step the guide itself mandates, distinct from the dossier's
  broader "no linter/CI gate" observation. It is small, mechanical, and self-prescribed — a concrete
  actionable, not the open-ended governance gap. Solo workflow pushes direct to main, so a PR
  template alone won't gate commits; pair it with a one-line note in `.claude/rules/code-style.md`
  (Commenting/voice section) pointing at the guide so new ARB strings get a voice check at authoring
  time. (A real CI linter for exclamation marks / "Är du säker" / "Grattis" is the larger
  already-documented governance gap — not re-filed here.)
- fix: Either create `.github/PULL_REQUEST_TEMPLATE.md` with the voice-guide link, or (better for
  this solo direct-to-main workflow) add a voice-guide pointer to `.claude/rules/code-style.md` so
  the rule auto-loads when ARB files are edited. File: docs/design/butler-voice-guide.md:67–68,
  .claude/rules/code-style.md (Commenting section), .github/ (no template present).

### Add English translation for sv-only key privacyActivityFeedHint (also fix its off-voice "Klart!")
- type: bug  area: content  priority: medium
- finding: `privacyActivityFeedHint` exists in app_sv.arb (line 3908) but is entirely MISSING from
  app_en.arb — the only real message-key drift between the two files (4287 sv keys vs 4286 en after
  excluding @-metadata; all other counts match). English-locale users see no string / a fallback
  for this privacy activity-feed hint. The Swedish value also breaks butler-voice rule #1: it opens
  with "Klart!" (exclamation) and uses chatty "Dina vänner ser nu…".
- pass: 1
- why: A user-facing privacy hint silently untranslated is a localization defect (en falls through);
  bundling the voice fix is free since the key has to be touched anyway. Distinct from the dossier's
  aggregate exclamation count — this is a specific, fixable two-in-one key, and the sole en/sv key
  drift, neither of which the dossier names.
- fix: Add `privacyActivityFeedHint` to app_en.arb (butler register, e.g. "Done. Friends now see
  your activity in their feed; this can be turned off at any time." — drop the "!"), and rewrite the
  sv value off the exclamation per rule #1/#3 (e.g. "Klart. Vänner ser nu aktiviteten i sitt flöde;
  detta kan stängas av när som helst."). Files: lib/l10n/app_sv.arb:3908,
  lib/l10n/app_en.arb (key absent).

---

COVERAGE:
PASS 1 (butler-voice violations + en/sv drift): verified live counts — 76 exclamation marks each in
sv/en (down from dossier's 87/86), 21× "Är du säker" vs 1× "Bekräftelse krävs", "Grattis!" still in
celebrationFirstRecipeTitle and rendered by first_recipe_celebration_overlay.dart; all four are
already in the dossier watch-items so not re-filed. Found ONE undocumented item: `privacyActivityFeedHint`
is sv-only (missing en) AND off-voice ("Klart!"). No placeholder/lorem strings.
PASS 2 (ARB descriptions + microcopy + enforcement): ~1040 sv / ~1029 en @-descriptions vs ~4287 keys
— broad description gap already tracked by BUT-704 follow-up (deferred), so not re-filed; found ONE
undocumented actionable — the voice guide's own prescribed PR-template link (lines 67–68) is
unimplemented and no PR template exists.
