# Sprint Backlog

## Sprint: draft-persistence + a11y-tests + deps + snap-visibility + LLM-caching — 2026-06-09 (iter-135)

### Agent A: import persistence (BUT-910) `[Tier A]`
- [x] **A1. Persist photo-import draft across nav/background** `[Tier A]` — `lib/viewmodels/recipe_form/photo_import_viewmodel.dart`: adopt `AutoSaveManager<PhotoImportDraft>` for `_ocrText` + extraction state; stage image bytes as gzipped temp file, persist path + text via custom encode/decode; wire "Continue with previous photo?" recovery prompt (existing draft-recovery pattern from BUT-1203). Closes EPIC BUT-904. (BUT-910)

### Agent B: a11y announce tests (BUT-1212) `[Tier A]`
- [x] **B1. Announce-channel tests for 2/3 seam-blocked sites + PRODUCTION BUGFIX** `[Tier A]` — shopping toggle (3 full-shell tests; unmasked + fixed real ProviderNotFoundException: State-context `context.read` above its own provider broke every add/toggle) + comment-posted (3 host-widget tests over the real static handler). Site 3 (recipe_detail favorite) deferred → BUT-1225 (needs first-ever RecipeDetailView scaffolding). Pattern-migration follow-up → BUT-1226. (BUT-1212)

### Agent C: dependency pin verification (BUT-828) `[Tier A]`
- [x] **C1. Verify firebase_app_check 0.4.3 / freerasp 7.5.1 / http_certificate_pinning 3.0.1 pins** `[Tier A]` — DONE (no code change; BUT-828 closed, freerasp 8.0.0 review filed as BUT-1218) — fresh `flutter pub get`; check pub.dev for newer 0.4.x/patch releases + changelogs for iOS fixes; bump pin + pubspec comment if warranted; iOS Build Validation runs in CI on push. (BUT-828)

### Agent D: per-snap visibility override (BUT-1214) `[Tier B]` — CARRIED → next iteration
Deliberately carried, not skipped: full feature slice (model + repo + service read-enforcement + dialog UI + firestore.rules + rules-tester) deserves a fresh-context iteration. Ticket stays Todo in Linear; spec is complete.
- [ ] **D1. CookSnap.visibility field + capped override** `[Tier B]` — `lib/models/cook_snap.dart`: `sameAsRecipe` (default) | `onlyMe`; toggle in BUT-901 disclosure dialog; persist in `firebase_cook_snap_repository`; read-enforce in `cook_snap_service.watchCookSnaps` + gallery query; Firestore rules restrict `onlyMe` reads to author; rules tests + firestore-rules-tester sign-off. → In Review + notify. (BUT-1214)

### Agent E: Vertex context caching (BUT-1032) `[Tier A]` — RISK-GATED (P2)
- [x] **E1. Gemini implicit-cache telemetry (re-scoped from explicit cachedContents)** `[Tier A]` — Step 0 found plan stale: 2.5-flash-lite has implicit caching by default @10% billing; explicit caches bill storage/token-hour. Shipped phase 1: cache-aware calculateGeminiCost + 3 token-count fields in completion logs (structure-recipe all 6 post-Gemini exits + new OCR usage log). 7/7 new tests, tsc clean. Phase 2 = data-gated decision (ticket updated). (BUT-1032)

### Housekeeping
- [x] BUT-1202 → Duplicate of BUT-1205 (same BUT-1079 part-2 scope filed twice)
- [x] BUT-1154 progress comment: 2/4 files decomposed (photo_import_view + photo_import_viewmodel, commits f301e09f9 + ffbcfe224); smart_import_view + user_profile_edit_view remain

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos` + `dart format`
- [ ] Run relevant unit/widget tests
- [ ] Tier-2 review agents per staged paths (code-reviewer, testing-specialist, firebase-backend-security, firestore-rules-tester)
- [ ] Commit per ticket, push
- [ ] Linear: Done for Tier A; In Review + PushNotification for BUT-1214
- [ ] File follow-up tickets for any deferred scope BEFORE commit

---
## ARCHIVED — iter-134 (BUT-1213 shipped 9a086bdfa + BUT-1217 guard d3daa6498) · iter-133 (BUT-1216 foundation filed) · iter-132 (BUT-925 groomed) · iter-131 (BUT-906 In Review) · iter-130 (BUT-901 In Review)
