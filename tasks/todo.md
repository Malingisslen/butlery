# Sprint Backlog

## Sprint: iter-32 — Trivial autonom-batch (BUT-965/967/955/969/1046/984) — 2026-05-24 (Sun)

Theme: Backlog-svep avslöjade jag missade ~50 tickets (filtrerade fel på priority). Plockar 6 trivial-autonoma med noll UX-risk för att bryta loopen ur "well är tom"-läget. Större tickets (BUT-995 prompt-cache, BUT-440 repo-refactor, BUT-804 LLM-hardening) lämnas till nästa iter eftersom de kräver längre läs-pass.

### Ship this sprint

- [ ] **A1. BUT-965 (Low, Bug)** — `FieldValue.serverTimestamp()` på cook snaps writes (lokal `DateTime.now()` ersätts). Read first → klassifiera Step 0.
- [ ] **A2. BUT-967 (Low, tech-debt)** — Rename svenska route-konstanter till engelska. Search `route` constants på svenska. Mekanisk rename.
- [ ] **A3. BUT-955 (Medium, Bug)** — Cap-guard på `sharedWithUserIds` (storleksgräns + tydligt fel). 1 fil.
- [ ] **A4. BUT-969 (Low, tech-debt)** — Ersätt `Map`-access med typade modeller i `account_deletion`-services (2 filer).
- [ ] **A5. BUT-1046 (Low, analytics)** — Wire `logSocialOnboardingStarted` vid social-tab entry-point. 1 callsite.
- [ ] **A6. BUT-984 (Low, idea)** — Tråda `AppLocale` till `structureRecipe` + OCR Cloud Functions (param threading).

### Post-Sprint Steps

- [ ] `dart analyze --fatal-infos` på ändrade filer
- [ ] Tier-2: `code-reviewer` (auto-trigger), `testing-specialist` om lib/ ändras
- [ ] `/code-review high` (simplify-marker)
- [ ] Commit + push till main
- [ ] Stäng BUT-XXX i Linear → Done

---

## Archived iter-31 (2026-05-24) — BUT-1002 assessment-only, ingen kod

Lämnade BUT-1002 i Backlog med detaljerad Linear-kommentar varför contact-import inte är autonomt säker även i pre-prod (GDPR Art. 9, hash-schema, permission-strings, rate-limit, CF-endpoint kräver design-pass).
