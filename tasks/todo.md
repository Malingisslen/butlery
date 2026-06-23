# Sprint Backlog

## Sprint: session follow-ups — 2026-06-23

### Agent A: FAQ Swedish copy fix (BUT-1359)
- [ ] **A1. Restore å/ä/ö in the FAQ Swedish copy** `[Tier A]` — `lib/l10n/app_sv.arb` faqA1/faqQ2/faqA2/faqQ3/faqA3/faqA4/faqA5; gen-l10n. (BUT-1359)
  - Acceptance: no FAQ Swedish key uses an ASCII substitution for å/ä/ö (på/sätt/Lägg/välj/vänner/Öppna/Gå/måltider/inköpslistan/höger/skärmavbild/läser etc.) · gen-l10n regenerated · faq_view_test green (reads from AppLocalizationsSv, auto-follows) · analyze clean.

### Agent B: import offline fast-fail (BUT-1360 item 1)
- [ ] **B1. Offline pre-check on text/social import** `[Tier A]` — `lib/viewmodels/import_base_viewmodel.dart` parseTextToRecipe: connectivity pre-check before the 60s Cloud-Function call (mirror BUT-610's URL/photo pattern). (BUT-1360)
  - Acceptance: when offline, parseTextToRecipe returns the offline message immediately WITHOUT calling strategy.import (no 60s wait) · online path unchanged · focused test asserts offline → fast error, zero network call · analyze clean.

### Agent C: menu calendar cache-first read (BUT-1360 item 7)
- [ ] **C1. Cache-first weekly-menu read** `[Tier A]` — `lib/repositories/firebase/firebase_weekly_menu_plan_repository.dart:73`: read Source.cache first, fall back to serverAndCache, so a never-cached week fails gracefully offline. (BUT-1360)
  - Acceptance: fetchForWeek tries cache first then server · returns null/empty gracefully when neither available (no uncaught throw) · existing menu tests green · analyze clean.

### Needs you (Tier D / design — flagged, not worked)
- BUT-1361 — real-device airplane-mode manual QA (needs a physical phone; already documented).
- BUT-1362 — optional iOS large-title CupertinoSliverNavigationBar for 2 social headers (design decision; unverifiable headless; already documented).

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos`
- [ ] tests green
- [ ] code-reviewer + testing-specialist
- [ ] Commit, push
- [ ] BUT-1359 → Done; BUT-1360 stays open (remaining items: ConnectivityAware mixin, pending-sync UI, cooking-mode banner, web/RTDB)

---

_(Prior sprint scratch archived in git history.)_
