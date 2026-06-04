# Sprint Backlog

## Sprint: analytics-consent transparency — 2026-06-04 (iter-110)

Clean tree on main (prior commits …64be6fd1f, f33b0f708). Clean Tier-A is drained (488 CI-only/low-value,
934 needs CF deploy, 1011 premise-not-triggered, 554 tracking-only). BUT-923 found premise-stale
(combined AllergenPreferencesView already edits allergen+dietary; onboarding re-launch is redundant +
has a pushNamedAndRemoveUntil(home) completion wrinkle). Picked BUT-918 — non-redundant GDPR-transparency.

### Agent A: analytics transparency
- [ ] **A1. BUT-918** `[Tier B]` — "What we log" expansion under the analytics consent toggle.
      - **Step 0:** fits. `consent_management_view.dart` builds the analytics toggle via
        `_buildConsentToggle` (line 250). `AnalyticsEvents` (135 grouped constants) is the source.
      - Add `_buildAnalyticsTransparency()` after the analytics toggle: an ExpansionTile "Vad vi
        loggar" listing plain-language categories (App usage / Recipes / Menu+shopping / Import /
        Social / Onboarding), each referencing real `AnalyticsEvents` constants (compile-time sync).
      - l10n sv/en for the expansion title/intro + category labels.

### Needs you (Tier D / deferred — carried)
- BUT-1169, BUT-838, BUT-934 (re-engagement CF — needs deploy), BUT-1187, onRecipeDeleted gen-2 deploy.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos`
- [ ] Commit, push
- [ ] Linear: In Review + notify (Tier B UI) — also note BUT-923 premise-stale finding

---

## ARCHIVED — iter-109: multi-select bulk-unblock (shipped f33b0f708)
BUT-1039 → In Review. blocked_users_section multi-select, 6 widget tests.

## ARCHIVED — iter-108: import cost-guard (shipped 64be6fd1f)
BUT-1037 → In Review. RecipeTextHeuristic + warn dialog + telemetry, 10 tests.

## ARCHIVED — iter-107: gesture-hint discoverability (shipped ba7c7a4e3)
BUT-1199 → In Review. SwipeHintBanner generalized + 2 surfaces, 6 tests.

## ARCHIVED — iter-106: post-refactor testability (shipped 9c8946120)
5 Tier-A Done + BUT-1198 allergen banner In Review.
