# Scan — Role #28 Information Architect / Wayfinding

Date: 2026-06-27
Scope: routing correctness, deep-link resolution, adaptive-nav, back-stack, detail-view bottom-nav, doc-vs-route drift.
Owned paths reviewed: routes.dart, app_router.dart, deep_link_handler.dart, deep_link_service.dart, layout_scaffolds.dart, adaptive_navigation.dart, BUTLERY_VIEWS_AND_STATES.md, butlery_app.dart (+ deferred module routers).

Method: 2 passes, verified against code (file:line). Dedup against `_scan_dedup_titles.txt`, `linear-tracker.json`, `accepted-deviations.md`, dossier watch-items.

---

## NEW findings

### N1 [High] `/fileImport` route is unregistered in routes.dart — auth-gate bypass + `isValidRoute` returns false
`Routes.fileImport = '/fileImport'` is declared (routes.dart:38) and is fully handled by
`ExtractionDeferredModule` (extraction_deferred_module.dart:31,80 → `FileImportView`), but the
constant is **absent from every route set** in routes.dart:
- not in `allRoutes` (236–302) → `Routes.isValidRoute('/fileImport')` is `false`;
- not in `authenticatedRoutes` (112–150) → `Routes.requiresAuth('/fileImport')` is `false`;
- not in `bottomSlideRoutes`/`rightSlideRoutes`/`fadeRoutes` → falls to the default
  `slideFromRight` animation (functional, but unintended — sibling import routes use
  slide-from-bottom).

Consequence: the router (app_router.dart:140) runs the auth check **before** dispatching to the
deferred module (app_router.dart:151). Because `fileImport` is missing from `authenticatedRoutes`,
the auth gate is skipped and the deferred module builds `FileImportView` for a signed-out user —
unlike its four sibling import routes (importViaUrl/photoImport/smartImport/importFromArchive),
which ARE in `authenticatedRoutes` (routes.dart:114–119) and so are gated. This is a lone
inconsistency, not a design choice. Fix: add `fileImport` to `allRoutes`, `authenticatedRoutes`,
and `bottomSlideRoutes` (to match the other import modals).
Evidence: routes.dart:38, routes.dart:112–162, routes.dart:236–302; app_router.dart:140,151;
extraction_deferred_module.dart:27–33,80–81.

### N2 [Medium] Deep-link expiration never enforced on the live recipe path (re-confirms dossier watch-item, now with the cross-user-access angle)
Dossier already flags that `parseDeepLink` doesn't validate expiry and that two divergent checks
exist (`isLinkValid` 7-day vs `isLinkExpired` 7-day). NEW angle worth a ticket: the **active**
handler `_handleRecipeLink` (deep_link_handler.dart:226–243) fetches the recipe by ID and pushes
`recipeDetail` with **no** timestamp/expiry check and **no** sharing-membership check — it relies
solely on `RecipeRepository.read(recipeId)` + Firestore rules to deny. A `/recipe?id=...&timestamp=`
link generated 8+ days ago still resolves and navigates if the reader can read the doc. Either wire
`DeepLinkService.isLinkValid` into the handler before navigation, or delete the unused expiry methods
(`isLinkValid`, `isLinkExpired`, deprecated `handleDeepLink`) so the "links expire after 7 days"
contract isn't falsely implied. (Cross-ref memory `reference_recipe_share_two_paths.md` — the read
gate depends on `memberPermissions`, so expiry is the only client-side staleness control and it's
inert.)
Evidence: deep_link_handler.dart:226–243; deep_link_service.dart:181–253 (no expiry in parse),
255–268 (`isLinkValid`), 410–459 (`@Deprecated handleDeepLink`), 461–472 (`isLinkExpired`).

### N3 [Low] Detail-view bottom-nav convention is applied inconsistently — settings/legal/notifications/faq detail views have no bottom nav
Memory convention: "Detail views should have bottom navigation bar (all detail views, not just
recipe)" and "Bottom nav behavior from detail views: `pushNamed` (stack-based)". Recipe detail
honors this (recipe_detail_view.dart:219–227, `ButleryBottomNavigation` + `pushNamed`). But
`grep showBottomNav: true` across `lib/views/` returns **zero** call sites, and no
`bottomNavigationBar`/`ButleryBottomNavigation` exists in any `settings/`, `legal/`,
`notifications/`, or `faq_view.dart` detail view. So `LayoutScaffolds.simpleLayout`'s
`showBottomNav` path (layout_scaffolds.dart:356–374) is dead — nothing passes `true`. Result: from
Settings → Allergens (and the other ~12 right-slide detail routes) the user has no bottom-nav
wayfinding back to the main tabs; only the system/app-bar back works. Either apply the convention
to these detail views or record an accepted deviation (recipe detail = only detail surface that
gets bottom nav). Worth a decision, not silent drift.
Evidence: recipe_detail_view.dart:219; layout_scaffolds.dart:39–57,356–374; no `showBottomNav: true`
in lib/views/; settings/legal/notifications/faq views carry no bottom nav.

### N4 [Low] Detail-view bottom nav hardcodes `currentIndex: 0` and uses `pushNamed`, stacking duplicate shells
recipe_detail_view.dart:220 sets `currentIndex: 0` unconditionally, so on the recipe detail the
"recept" tab always shows selected regardless of where the user came from (e.g. arriving from the
meny or inköp tab). Tapping a tab uses `Navigator.pushNamed` (recipe_detail_view.dart:226), which
pushes a fresh `LayoutScaffolds.mainMenu()` **on top of** the existing shell rather than returning
to the live IndexedStack — back then lands on the detail again, and the preserved-tab state
(BUT-188 IndexedStack) is bypassed. The same `pushNamed`-onto-shell pattern is in
`_SimpleLayout` (layout_scaffolds.dart:367–371) and `AdaptiveNavigationScaffold` uses
`pushReplacementNamed` (adaptive_navigation.dart:236) — three different back-stack behaviors for
"tap a nav destination". Wayfinding inconsistency; pick one (likely `popUntil` to the shell +
set tab) and document it.
Evidence: recipe_detail_view.dart:219–227; layout_scaffolds.dart:367–371;
adaptive_navigation.dart:227–237.

---

## Checked, NOT new (already covered / by-design)

- Deep-link expiry inconsistency + dead `handleDeepLink` — in dossier watch-items (#28). N2 adds
  only the live-recipe-path/cross-user angle.
- Route localisation (Swedish URL values /laggTill etc.) — BUT-967 (tracker), deliberate per
  routes.dart:14–16; not a bug.
- iOS Universal Links / associated-domains — already in dedup backlog ("iOS: configure
  associated-domains entitlement for Universal Links", launch-gated).
- Tablet multi-column master-detail — BUT-723 / dedup ("Tablet: implement multi-column...").
- Foldable hinge (`displayFeatures`) — dedup ("Foldable: handle MediaQuery.displayFeatures").
- CupertinoNavigationBar adoption — BUT-706 (tracker).
- Adaptive-nav breakpoints (mobile<600 bar / tablet rail / desktop extended) — correct vs M3
  guidance (adaptive_navigation.dart:108–142); nav landmarks present (BUT-557). No issue.
- `realtimeMenu` stub (returns plain VeckomenyView) — documented deferral (app_router.dart:320–329);
  by-design, not new.
- Deep-link default fallback auth-gates the home shell for signed-out users — correct
  (app_router.dart:447–473).
- Social/extraction deferred routes (collaborativeShopping, menuPreview, publicProfile, etc.) all
  registered + handled in their modules; no dead/unregistered route there.
- BUTLERY_VIEWS_AND_STATES.md route mentions cross-checked against routes.dart — paths align
  (/laggTill, /veckomeny, /receptDetalj, /smartImport, /settings/* etc.); no doc-vs-route drift
  found in the path references (the doc's stale-content risk is a Tech-Writer #20 concern, already
  an un-owned-gap on the map).

---

COVERAGE: 4 NEW (1 High auth/route-registration, 1 Medium deep-link, 2 Low wayfinding/back-stack).
Strongest = N1 (`/fileImport` unregistered → auth-gate bypass). All verified at file:line. No
tickets created.
