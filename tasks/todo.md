# Sprint Backlog

## Sprint: dep hygiene + PWA polish + Linear cleanup — 2026-05-05 (J)

Theme: 4 implementations + 3 ticket-state cleanups. Security advisory subscriptions (BUT-519/524), bulk minor-version dep bump (BUT-500), PWA install UX (BUT-718). Plus closing BUT-437 (premise gone), rescoping BUT-431 + BUT-530 (plan-stale).

**In Progress carry-overs (NOT in this sprint):**
- BUT-442 — repo migrations (own focused sprint).
- BUT-760 — App Check enforcement; awaiting Firebase Console flip.

**Step 0 verification — done:**
- **BUT-519** fits — process-only. `pubspec.yaml` confirms `flutter_inappwebview: ^6.1.5` with four importers in `lib/` (web_scraper, recipe_site_content_extractor, instagram_content_extractor, social_platform_content_extractor). Need a tracked memory entry + Malin-action to subscribe via GitHub Watch.
- **BUT-524** fits — process-only. `pubspec.yaml` confirms `freerasp: ^7.5.1`. `device_integrity_service.dart` is the call path. Same shape as BUT-519: memory entry + GitHub Watch instructions.
- **BUT-500** fits — `flutter pub upgrade --tighten` is the entry. Verification pass: `flutter analyze --fatal-infos` + `flutter test` after the lockfile updates.
- **BUT-718 PLAN STALE (most done)** — `web/manifest.json` already has Butlery name/short_name, forestGreen theme_color, maskable 192+512 icons, share_target, shortcuts, Swedish description. Remaining: `screenshots` field (richer install UI) + `beforeinstallprompt` JS hook in `web/index.html` for a custom install banner. Narrow rescope.
- **BUT-437 PREMISE GONE** — `lib/core/observers/consent_aware_analytics_observer.dart` exists, wraps `FirebaseAnalyticsObserver`, and is registered at `lib/main.dart:898` (`if (_analyticsObserver != null) _analyticsObserver!`). Screen-view events fire on every route push when consent is granted. Likely shipped during the BUT-751 multi-listener consent gate work. → close as Done with evidence.
- **BUT-431 PLAN STALE** — three of the four bullets in the ticket are done already. `Future.wait([Crashlytics, AppCheck])` parallel at `main.dart:177-191`; web probe moved into `FirestoreBootstrap.configure()` (commit 1e347b4); pre-cached theme read at `main.dart:215` (BUT-468). Remaining lever: split `_initializeModularSystem` into blocking (auth/consent/routing) vs post-first-frame (analytics/remote config) stages. That's its own focused refactor — not a sprint-slot task. Update ticket body to reflect what's left; leave in Backlog.
- **BUT-530 PLAN STALE** — `lib/main.dart` is 1311 lines vs accepted 954 = +357 drift, not +63 as ticket claims. Bumping the accepted entry alone is sweep-under-rug; real fix is extraction (auth wrapper widget, observer wiring, theme/seasonal logic). Update ticket body to capture true drift + extraction hint; leave in Backlog.

### Agent A: Dependency hygiene (no Tier-2 code agent — pubspec only)

Specialists: `code-reviewer` if pub upgrade lands code-relevant changes (it shouldn't for a clean minor-only bump).

- [x] **A1. BUT-519 — Document flutter_inappwebview advisory-watch subscription** —
  - **New file** `C:\Users\malla\.claude\projects\C--Butlery-butlery\memory\security_advisory_subscriptions.md`:
    - Section "flutter_inappwebview" with: package version pin, importing files (4), GitHub repo URL (`pichillilorenzo/flutter_inappwebview`), Watch path ("Watch → Custom → Security alerts + Releases"), triage rule ("controlled outbound scraping only — no user-supplied URLs at present").
  - Add `MEMORY.md` index entry: `- [Security Advisory Subscriptions](security_advisory_subscriptions.md) — flutter_inappwebview, freerasp watch list`.
  - Per-Linear-comment: "Memory entry created at `security_advisory_subscriptions.md`. Manual GitHub Watch action documented for Malin." Then close as Done. (BUT-519)

- [x] **A2. BUT-524 — Document freerasp release-watch subscription** —
  - Append "freerasp" section to `memory/security_advisory_subscriptions.md` (created in A1) with: pin (`^7.5.1`), call site (`device_integrity_service.dart`), GitHub repo URL (`talsec/Free-RASP-Community`), Watch path (Releases + Security), pub.dev notification toggle URL pattern, regression test ("re-test `device_integrity_service` on Android + iOS after each minor").
  - Per-Linear-comment + close as Done. (BUT-524)

- [x] **A3. BUT-500 — Bulk minor-version dependency bump via `pub upgrade --tighten`** —
  - Run `flutter pub upgrade --tighten` from repo root.
  - Diff `pubspec.lock` and `pubspec.yaml`; capture summary in commit message body (top 10 bumps).
  - Run `flutter analyze --fatal-infos`. If any deprecation warnings surface, fix them inline.
  - Run `flutter test test/unit/` (sample) and one integration test. If anything regresses → bisect by reverting `firebase_*` family first, then platform plugins, then app deps.
  - **If a dep refuses to tighten** (e.g. caret floor blocks a minor): leave it on the older minor and note in commit message ("could not tighten X — Y constraint").
  - **Out of scope**: major-version bumps (those need their own ADR per dep). (BUT-500)

### Agent B: Web/PWA polish

Specialists: `code-reviewer` if `web/index.html` JS changes; `firebase-backend-security` not needed (no Firebase touch).

- [x] **B1. BUT-718 (rescoped) — PWA install prompt + manifest screenshots** —
  - `web/manifest.json`:
    - Add a `screenshots` array with at least 1 entry per form factor:
      ```json
      "screenshots": [
        {
          "src": "icons/screenshot-narrow-540x720.png",
          "sizes": "540x720",
          "type": "image/png",
          "form_factor": "narrow",
          "label": "Receptlistan i Butlery"
        },
        {
          "src": "icons/screenshot-wide-1024x600.png",
          "sizes": "1024x600",
          "type": "image/png",
          "form_factor": "wide",
          "label": "Veckomeny i Butlery"
        }
      ]
      ```
    - **Note**: actual screenshot PNGs may not exist yet. If `web/icons/` lacks them, leave the field referencing the files but flag in commit message that screenshot assets are TODO (icons live separately; this PR only updates manifest). PWA installability is unblocked the moment the assets land.
  - `web/index.html`:
    - Add a `<script>` block before `</body>` that listens for `beforeinstallprompt`, stashes the deferred event on `window`, and shows a Swedish-localized "Installera Butlery" button (hidden by default, revealed on event). Click handler triggers `event.prompt()` then awaits `userChoice`.
    - Keep the script defensively guarded (`if ('BeforeInstallPromptEvent' in window || ...)`); Safari ignores this event entirely, which is fine.
    - Use a single inline `<script>` rather than an external file — no build pipeline for `web/` JS today.
  - **Verification**: `flutter build web --release` produces a valid manifest; Chrome DevTools "Application → Manifest" panel shows green check on installability (modulo the screenshot-asset TODO).
  - No Flutter test (HTML/manifest are static). (BUT-718)

### Agent C: Linear ticket cleanups (no code, ticket-state only)

- [x] **C1. BUT-437 — close as Done (premise gone)** — comment with evidence:
  - `lib/core/observers/consent_aware_analytics_observer.dart` (full file) wraps `FirebaseAnalyticsObserver`.
  - Registered at `lib/main.dart:898` inside the `observers` list passed to `MaterialApp.navigatorObservers`.
  - `FirebaseAnalyticsObserver` natively emits `screen_view` on every route push; the wrapper only gates by consent. So screen-view instrumentation IS in place — the analysis report's "G2 finding" predates the observer.
  - Transition state to **Done**.

- [x] **C2. BUT-431 — rescope ticket body** — update Linear ticket description to reflect what remains. Keep in Backlog. New body:
  ```
  Original four-bullet plan partially shipped:
  - ✅ Crashlytics + AppCheck parallel via Future.wait (main.dart:177-191).
  - ✅ Web health probe gated behind kIsWeb + 5s timeout, moved into FirestoreBootstrap (commit 1e347b424).
  - ✅ Pre-cached theme read avoids first-frame flash (main.dart:215, BUT-468).
  - ❌ DI bootstrap split into blocking vs post-first-frame stages — NOT DONE.

  Remaining work: refactor `_initializeModularSystem` (main.dart) into two phases:
    Phase A (pre-runApp, blocking): platform_stage + core_stage + content_stage + ui_stage minimum subset (auth, consent, routing, theme).
    Phase B (post-first-frame): social_stage + tagging_module + search_module + pantry_module + analytics + remote-config sync.
  Use a `WidgetsBinding.instance.addPostFrameCallback` to kick Phase B once the first frame paints.

  Effort: ~1 day for the split + tests. Risk: medium — race conditions if a Phase-B service is read before Phase B completes; need an `await container.ready()` in any view that touches a Phase-B service.
  ```

- [x] **C3. BUT-530 — rescope ticket body** — actual drift is +357 lines (1311 vs accepted 954), not +63. Update Linear ticket description:
  ```
  Real drift: lib/main.dart is 1311 lines vs accepted 954 (+357, +37%). Original ticket undercounted by 5x.

  This is no longer a 30-min "bump the accepted entry" task. Recommended split:
  1. Extract `lib/widgets/app/butlery_app.dart` — the `ButleryApp` StatefulWidget + `_ButleryAppState` (currently lines ~245-1100, the bulk of the file).
  2. Extract `lib/core/observers/observer_registry.dart` — the navigator-observer construction logic from `_ButleryAppState` (~50 lines).
  3. Move bootstrap orchestration (`_initializeModularSystem`) into a top-level helper in `lib/core/bootstrap/`.
  4. Target: main.dart back to <300 lines (entry-point only).

  Connects to BUT-431 (DI bootstrap split) — both touch main.dart; bundle into one focused refactor sprint.
  ```

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` — 0 issues
- [ ] `flutter test test/unit/` (sample to verify pub-upgrade didn't regress unit tests)
- [ ] Tier-2 specialist gates: `code-reviewer` only if A3 produces .dart code changes (deprecation fixes); skip otherwise (manifest + memory file aren't .dart)
- [ ] Commit, push to main
- [ ] CI watcher monitors green
- [ ] Update Linear: BUT-519/524/500/718/437 → Done; BUT-431 + BUT-530 stay in Backlog with rescoped descriptions

### Continued blockers (NOT in scope per memory)
- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred (Apple Dev enrollment gated)
- BUT-549 — post-beta (Sign in with Apple lands when social login does)
- BUT-579 — held for button-system sprint
- BUT-444 / BUT-445 — own product-design sprints
- BUT-686 / BUT-660 / BUT-694 — feature-level brainstorming first
- BUT-674 / BUT-721 — own scoped sprints
- BUT-626 — bucket-based A/B infra; own sprint
- BUT-420 / BUT-451 / BUT-452 / BUT-486 — deploy-pipeline / staging cluster; focused infra sprint
- BUT-550 / BUT-536 / BUT-441 — ACCEPTED_LARGE_FILES drift sprint
- BUT-558 — DCM install (own sprint)
- BUT-554 — tracking ticket (blocked on drift_dev upstream)
- BUT-594 — macOS sandbox audit needs hardware-exercise step
- BUT-701 — focus traversal (2-day a11y sprint)
- BUT-479 — cursor-pagination half is non-trivial; needs design ticket
- BUT-435 + BUT-502/503/507/509 — Dart SDK 3.10 bump cluster (one focused sprint)
- BUT-472 — realtime_session_manager stream/timer migration (next perf sprint)
- BUT-455 / BUT-440 / BUT-504 — repository discipline cluster (paired with BUT-442)
- BUT-453 / BUT-454 — auth/session security (own sprint with product-design input)
- BUT-488 — pubspec auto-bump CI workflow (3h, intricate; standalone)
- BUT-704 — i18n @key ARB descriptions (2-day sweep)
- BUT-520 — VM-migration sweep (rescoped sprint I; runs as own multi-sprint effort)
- BUT-431 / BUT-530 — main.dart bootstrap split + extraction (rescoped this sprint; runs as own focused refactor)
- All `idea`-labeled monetization scaffolding — post-beta

### What this means in plain language
- **Two tiny "process" tickets**: we add a memory note so we don't forget to subscribe to security alerts for two libraries that touch sensitive parts of the app (the in-app browser used for recipe scraping, and the integrity check that runs on phones). The actual GitHub-subscribe step is something Malin clicks once in a browser; the memory file records what to subscribe to and why.
- **Bulk dependency refresh**: `flutter pub upgrade --tighten` pulls the latest *minor* versions of ~40 libraries (no breaking changes, by semver). One command. We then run the test suite to make sure nothing broke. If something does break, we revert the offending family and ship the rest. Low risk — minor bumps are routine.
- **PWA install button**: today the web version of Butlery doesn't show the "Install" prompt cleanly because the app's manifest is missing screenshots and the page has no listener for the install event. After this sprint, Chrome/Edge users on the web get a proper install button in Swedish ("Installera Butlery"). Low risk — purely additive.
- **Three ticket-state cleanups in Linear**:
  - One ticket (analytics screen-views) was actually already done — closing it.
  - Two tickets (cold-start refactor + main.dart size) had outdated descriptions — updating their bodies to reflect the real remaining work, so the next sprint that picks them up doesn't waste time on already-shipped pieces or undersized estimates. They stay in the backlog.
- **Risk**: low overall. Memory entries and ticket cleanups are cost-free. PWA changes touch only static `web/` files (no Flutter code). The dep bump is the only piece that *could* surface a regression — backed by tests and easy to revert per family.

---

## Archived prior sprint (completed in commit 1e347b424)

Backend hygiene + auth security micro-hardening — 2026-05-04 (I) — shipped BUT-446/506/465/490 + closed BUT-716 (premise gone) + rescoped BUT-520. See git log for full task breakdown.

## Archived sprint before (completed in commit 44b6f4792)

GDPR cascade + rules tightening + stream lifecycle — 2026-05-04 (H) — shipped BUT-466/464/463/462/461/613/471. See git log for full task breakdown.

## Archived sprint before (completed in commit b33653c47)

Backend perf + observability hardening — 2026-05-04 (G) — shipped BUT-482/483/473/480/592/627. See git log for full task breakdown.

## Archived sprint before (completed in commit 4fc17758e + d9cb88acf)

Parsing/social tech-debt + dependency hygiene — 2026-05-04 (F) — shipped BUT-700/682/676/631/630/513/529 + BUT-698 closed as Duplicate. See git log for full task breakdown.

## Archived sprint before (completed in commit 75873d1e1)

Pre-beta moderation + anti-spam + UGC compliance — 2026-05-04 (E) — shipped BUT-537/544/649/651/654/659. See git log for full task breakdown.
