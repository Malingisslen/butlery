# Sprint Backlog

## Sprint: under-15 age-gate UX — 2026-06-04 (iter-113)

Clean tree on main (prior commits …0cbd81cb0, 990134f83). BUT-925 found plan-stale (confidence not
threaded to the assisted dialog — VM holds strings; commented, left in Backlog). Picked BUT-946 —
contained single-view UX improvement.

### Agent A: account — supportive age-gate
- [ ] **A1. BUT-946** `[Tier B]` — `onboarding_age_gate_blocked_view.dart`: add a secondary
      "En vuxen kan skapa ett konto åt dig" affordance → info dialog explaining a parent can
      create an account (the bounded option; the full parent-consent FLOW is the larger BUT-674).
      The existing supportive title/body + GDPR sign-out path are unchanged. l10n sv/en.

### Needs you (Tier D / deferred — carried)
- BUT-1169, BUT-838, BUT-934, BUT-1187, onRecipeDeleted gen-2 deploy.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos`
- [ ] Commit, push
- [ ] Linear: In Review + notify (Tier B; child-data sensitive — Malin's eyes on copy)

---

## ARCHIVED — iter-112: a11y announcements (shipped 990134f83)
BUT-905 → Done (favorite + comment). Shopping/OCR → BUT-1201.

## ARCHIVED — iter-111/110/109/108/107/106
912 online-status privacy (0cbd81cb0); 918 analytics transparency (23ac13e5d); 1039 bulk-unblock
(f33b0f708); 1037 import cost-guard (64be6fd1f); 1199 gesture hints (ba7c7a4e3); 5 Tier-A + 1198.
