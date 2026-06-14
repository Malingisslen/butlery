# Sprint Backlog

## Sprint: import-ssrf-parity + veckomeny-cooking-card-tests — close the two clean Tier-A test-gap/security follow-ups this iteration's verifiers filed (2 tickets) — 2026-06-14 (iter-161)

The iter-160 sprint shipped fully in commit `8b91c165b` (BUT-1300 reextract DI seam → Done; BUT-1301 import-flow specialist re-review → Done; BUT-1277 → Done; BUT-1258 veckomeny selection-widget extraction → In Review for Malin's eyes). Working tree clean, no carry-forward.

Backlog re-read: 98 open Backlog + 0 Todo + 0 In Progress + 0 Triage. The genuinely-clean Tier-A code slice is thin — the overwhelming majority are launch-gated/ops (BUT-415/420/451/486/492/646/813/814/819/880/1166/1229/1239...), monetization/marketing scaffolding (BUT-650/658/661/664/668/672/683/685/686/916/...), epics (BUT-907/1156/1157/1159/520), SDK-blocked dependency bumps (BUT-435/503/507/509/554/1218), or product/UX decisions that are Malin's call (BUT-976/941/945/1261/1276/1290/1043-style). Two honest, fully-disjoint Tier-A items remain that I can vouch for — both follow-ups this very iteration's verifier filed (BUT-1302, BUT-1303), both confirmed against current code at Step-0. Not padding to N=6 with debatable product work would be false mandate; the rest is surfaced under "Needs you".

### Agent A: import-ssrf-parity — deduplicate / cover the second SSRF host guard
- [ ] **A1. Delegate (or bring to parity + cover) UrlImportViewModel private-host guard** `[Tier A]` (BUT-1303) — `lib/viewmodels/url_import_viewmodel.dart` (`_isPrivateOrReservedHost`, ~line 449; called from `parseUrls`/`isValidUrl` ~line 196 and `getUrlValidationErrors` ~line 438), `test/unit/viewmodels/url_import_viewmodel_test.dart` (extend). Prefer delegating to `HttpContentFetcher.isBlockedHost` (the one fully-pinned implementation at `lib/services/import/fetchers/http_content_fetcher.dart:32`); if a separate copy is justified, bring it to full parity AND cover it. Production blocking behavior must not narrow.
  - Acceptance: `UrlImportViewModel` private-host detection is either delegated to `HttpContentFetcher.isBlockedHost` (single tested implementation) OR a retained copy is brought to documented parity with it · `parseUrls`/validation test asserts every branch the production guard has — 172.16–31/12, 0.0.0.0, [::1], IPv6 fc00, fe80 — not a subset · `getUrlValidationErrors` returns `errorUrlPrivateAddress` for at least one private-host input (one positive test, previously zero coverage) · No public/legitimate host that passed before is newly blocked (e.g. 172.15.x and 172.32.x still allowed)

### Agent B: veckomeny-cooking-card-tests — cover the extracted cooking-session card
- [ ] **B1. Widget-test VeckomenyCookingSessionCard hide-branches + populated StreamBuilder path** `[Tier A]` (BUT-1302) — new `test/widget/widgets/menu/veckomeny_cooking_session_card_test.dart` (sibling to existing `veckomeny_view_mode_toggle_test.dart`); subject is `lib/widgets/menu/veckomeny_selection_widgets.dart` `VeckomenyCookingSessionCard` (~line 103, `_VeckomenyCookingSessionCardState.build` ~line 126). Test-only addition; no production code change expected.
  - Acceptance: Four hide-branch tests each assert `SizedBox.shrink` — (a) `CookingSessionModule` absent from ServiceLocator, (b) userId null, (c) friend groups empty, (d) presence stream null · Populated-path test: a non-null scripted presence stream renders the inner `CookingSessionCard` via the `StreamBuilder` · Test scaffolds a fake `CookingSessionModule` + `UnifiedFriendsService` via ServiceLocator and a scripted presence stream (does not mock away the branch logic under test) · `flutter analyze` clean on the new test file and all assertions pass

### Needs you (not built — flagged for your call)
- **BUT-1261** (Medium) — carried. Conflict diff view uses one generic renderer + stringified ingredient lists rather than semantic add/remove/reorder. Recommendation: lean **narrow the acceptance** to the shipped generic diff once you confirm it reads clearly — per-type semantic diffing is a sizeable build for a feature not yet requested.
- **BUT-1290** (Medium) — carried. Fate of the one-time activity-feed hint banner (backend mechanism + ARB string exist; only the visible `privacy_section.dart` banner is missing). Recommendation: lean **won't-build** — the in-feed hint already nudges once; a settings-page banner is redundant.
- **BUT-1276** (Low) — carried. BUT-1205 overwrite-confirm is unconditional, not edit-aware. Recommendation: **accept-and-close** — always-confirming is the safe choice under the BUT-954 destructive-action convention; building `hasUserEdits` dirty-tracking is disproportionate.
- **BUT-1260** (Medium) — carried, recommend **reframe**. Asks for a Phase-A/Phase-B cold-start ordering seam, but `runPhaseA`/`runPhaseB` don't exist — the BUT-431 cold-start split was never shipped. No ordering to test. Re-file against the real (un-done) BUT-431, or drop.
- **BUT-1268** (Medium) — recommend **do it as a deliberate decision ticket, not a sprint auto-pick**. Asks to resolve the recurring cold-start split branch (BUT-1258/1259/1260/530/431 keep recycling) once. It's a meta/hygiene decision about whether to commit to the main.dart decomposition — your call on scope, not auto-implementable.
- **BUT-884** (Low) — PREMISE STALE, recommend **reframe or drop**. Only 14 raw `CircularProgressIndicator` refs in lib/, most are indicator infrastructure itself; the determinate constructor already shipped (BUT-1173). What's left is a debatable handful of overlay sites.
- **BUT-1169** (Low) — recommend **leave deferred**. Drop-legacy-`meat_fish`/`fruit_veg` constants needs a prod backfill + Cloud Function this loop can't reach (Tier D); removing constants while old docs carry the keys breaks rendering.
- **BUT-840** (Low) — recommend **reframe / drop**. Asks to extend `on-profile-updated.ts` to update an Algolia mirror, but there is NO Algolia integration — indexing is client-side. New external-API surface (Algolia admin key + deploy = Tier D), not the "extend an existing CF" the ticket implies.
- **BUT-1288** (Low) — carried. iOS Info.plist/AppDelegate doc-confirm is trivial, but the substantive half (on-device test that a real timer notification fires) needs a Mac the loop can't reach (Tier D).
- **BUT-1299** (Low) — carried. Confirm BUT-675 close-out referencing the nextPage() forward-persistence commit; verification/bookkeeping task, your call whether worth tracking.

### Needs you (Tier D — true ops/launch blockers, not worked)
- BUT-1229 / BUT-814 / BUT-880 / BUT-819 / BUT-821 / BUT-813 / BUT-1166 / BUT-486 / BUT-451 / BUT-492 / BUT-731 / BUT-646 / BUT-415 / BUT-420 — deploy/console/cert-capture/store-submission/secrets the loop can't reach.

### Obsolete (done in git, still open in Linear)
- (none — iter-160's BUT-1300/1301/1277 all correctly Done via `8b91c165b`; BUT-1258 correctly In Review)

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run `test/unit/viewmodels/url_import_viewmodel_test.dart` + new `test/widget/widgets/menu/veckomeny_cooking_session_card_test.dart`
- [ ] Commit, push to main
- [ ] Update Linear: BUT-1303 → Done (Tier A, fully verifiable test+parity); BUT-1302 → Done (Tier A, test-only). Leave BUT-1261/1290/1276/1260/1268/884/1169/840/1288/1299 untouched (flagged for Malin).

---
## ARCHIVED — iter-160 (recipe-detail-import-seam + veckomeny-decomp: BUT-1300 reextract DI seam + BUT-1301 import re-review + BUT-1258 veckomeny extraction — `8b91c165b`) · iter-159 (activity-feed-test-gap BUT-1297 + import-flow re-review BUT-1277 → BUT-1300/1301 — `18a8739a5`) · iter-158 (backend-rules + dart-test-gaps: BUT-1294/1295/1296/1287; BUT-1282 cancelled — `fe28279d0`/`ee3f6b487`/`565f1d330`) · iter-157 (verifier-followups BUT-1293/1289/1291/1292 — `74825b1f2`) · iter-156 (completeness-sweep widget-test gaps BUT-1274/1275/1280/1269/1270/1271 + BUT-1281) · iter-155 (cooking-mode + user-repo BUT-1283/1284/1285/1286 — `3bf7a50f3`) · iter-154 (BUT-734 + BUT-1242 — `22ab49ae9`) · iter-153 (tagging drained) · iter-152 (menu — `1711d297c`) · iter-151 (import — `673f80c87`) · iter-150..143 — se git-historiken
