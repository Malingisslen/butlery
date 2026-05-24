# Sprint Backlog

## Sprint: iter-58 — BUT-895 a11y label on LoadingIndicator — 2026-05-24 (Sun)

Theme: A11y screen-reader fix. **Wrapper-level fix** beats site-by-site migration. Plan-fil FÖRST.

### Step 0 — premise verification

- Ticket lists 7+ sites without `Semantics(label:)`.
- Verified `lib/widgets/common/indicators/loading_indicator.dart`: NO `Semantics` wrapping — bug confirmed at source.
- No `a11yLoading` key in ARB; ticket text is aspirational on that key.
- Ticket explicitly proposes wrapper: "Better: create a `BranderedLoader` widget that bakes this in, and migrate offenders." Iter 46 + iter 51 already migrated 29 sites to `LoadingIndicator` (the canonical wrapper). Adding Semantics to LoadingIndicator = single-source fix that benefits all 50+ existing callsites.

### Design choices

- **Wrap in `LoadingIndicator.build()` not site-by-site**. All `LoadingIndicator(...)` callsites instantly become a11y-compliant.
- **Add `semanticLabel` param** with `String?` default `null`. If null, falls back to `context.l10n.a11yLoading` ("Loading" / "Laddar"). Allows specific contexts to override with more meaningful text.
- **New l10n key**: `a11yLoading` — short, reused everywhere.
- **`liveRegion: true`**: tells screen reader to announce when loading appears/disappears. Improves UX for async state changes.

### Ship this sprint

- [ ] **A1. ARB**: add `a11yLoading` to sv + en.
- [ ] **A2. gen-l10n**: regenerate.
- [ ] **A3. LoadingIndicator**: add optional `semanticLabel` param + wrap build output in `Semantics(label, liveRegion, child)`.

### Acceptance

- [ ] All `LoadingIndicator` callsites get Semantics for free.
- [ ] Optional override `LoadingIndicator(semanticLabel: 'Loading recipes')` works.
- [ ] `flutter analyze` clean.

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Stäng BUT-895 i Linear → Done

---

## Archived iter-57 (commit `11f31967d`) — 2026-05-24 (Sun)

BUT-896 comment-edit labelText. +40 / -13. BUT-896 → Done. Step 0 caught auth_view-site as stale.
