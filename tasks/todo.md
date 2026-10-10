# BUT-722 Nyheter efter uppdatering (2026-10-10)

Design decided by Malin on decision cards in the project thread "Nyheter efter uppdatering";
mockup https://claude.ai/artifact/1KbrRKzW2zEDEAWnuNhf5i.

Stakeholder router: tier `single` (Accessibility, IA/Wayfinding, i18n, PM, UX Writer), no
high-stakes hits.

## Steps

- [ ] `lib/services/whats_new/whats_new_catalog.dart`: const list of releases (version name +
      items). Each item: title/body resolved from `AppLocalizations`, optional route. Starts
      EMPTY: 0.9.0 is the first upload, so nobody updates into it; entries are added per
      release after Malin approves the texts.
- [ ] `lib/services/whats_new/whats_new_service.dart`: SharedPreferences key
      `whats_new_last_seen_version_v1`. No key → first install: store current version, show
      nothing. Key older than current → items of every release newer than the key and not
      newer than current, newest first, max 5; empty → store and show nothing. Unknown
      version (web/test) → never show. Pure version compare on major.minor.patch.
- [ ] `lib/widgets/whats_new/whats_new_sheet.dart`: modal bottom sheet (drag handle, safe
      area, colors/typography from lib/theme, no new Icons.*). Items with a route are
      buttons with chevron; tap closes the sheet and pushes the route. "Toppen" closes.
- [ ] Trigger: post-frame in `_MainMenuLayoutState.initState` (layout_scaffolds.dart), once
      per app start; marks seen when shown.
- [ ] About view: "Nyheter" row (shown only when the catalog has an entry ≤ current
      version) opens the sheet with the latest release's items.
- [ ] Strings in app_sv.arb / app_en.arb.
- [ ] Tests: service unit tests (first install, update, skipped versions + cap 5, same
      version, unknown version); widget test for the sheet (tap item navigates, Toppen
      closes) and the About row (hidden when catalog empty, via injectable catalog).

## Acceptance

- Never shown on first install; shown once after an update that has entries.
- Screen readers: sheet announced with header; tappable items are buttons with labels;
  tap targets ≥ 48 dp.
- analyze clean; changed tests pass; code-reviewer gate.

## Summary for Malin

Efter en uppdatering glider en ruta upp med det som är nytt, en gång. Man kan trycka på en
nyhet för att komma dit. Har man missat flera versioner visas allt, högst fem punkter. Under
Om Butlery kan man läsa igen. Texterna lägger jag in först när du godkänt dem inför varje
version, så rutan syns inte förrän efter nästa uppladdning.
