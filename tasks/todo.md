# Sprint Backlog

## Sprint: "view captured source" (BUT-1079 part 1) — 2026-06-04 (iter-114)

Clean tree on main (prior commits …990134f83, a3122fd20). BUT-1079 is 3 parts; scoping to the
read-only "view source artefact" sheet (part 1). The re-extract overwrite (part 2) + stale banner
(part 3) genuinely need human UX design (overwrite-vs-append) per the ticket — follow-up.

### Agent A: recipe — view captured source
- [ ] **A1. BUT-1079 (part 1)** `[Tier B]` — recipe-detail overflow → "Visa källtext" (when
      `recipe.sourceArtefact != null`) → modal sheet showing the artefact type label + captured-at
      (`ContextualTimeFormatter.standard`) + scrollable `SelectableText` payload. Distinct from the
      existing `recipeViewSource` (which opens the sourceUrl externally). l10n sv/en (6 type labels).
      Re-extract + stale banner → follow-up.

### Needs you (Tier D / deferred — carried)
- BUT-1169, BUT-838, BUT-934, BUT-1187, onRecipeDeleted gen-2 deploy.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos`
- [ ] Commit, push
- [ ] Linear: In Review (Tier B); file re-extract follow-up

---

## ARCHIVED — recent ships
iter-113 BUT-946 age-gate (a3122fd20); iter-112 BUT-905 a11y (990134f83); iter-111 BUT-912 privacy
(0cbd81cb0); iter-110 BUT-918 (23ac13e5d); iter-109 BUT-1039 (f33b0f708); iter-108 BUT-1037
(64be6fd1f); iter-107 BUT-1199 (ba7c7a4e3); iter-106 5 Tier-A + BUT-1198 (9c8946120).
