# Sprint Backlog

## Sprint: Security spot-fix + privacy paperwork + tech-debt sweep — 2026-05-02

Theme: ship the M-1 security finding from the prior sprint's `firebase-backend-security` review (BUT-749 — menus rule self-scrub branch lets one recipient boot others) plus a small privacy hygiene cluster (BUT-580 Algolia EU + anonymization, BUT-620 GDPR Art 13(1)(f) data-processor inventory) and a 4-ticket mechanical tech-debt sweep wave (BUT-591/597/601/609). **2 agents, 7 tasks.** No Urgent/High in backlog — selected by coherent area clustering.

Prior sprint shipped as `d803ea1f2` ("feat(analytics/import): retention measurement loop + HEIC conversion (BUT-688/691/623/599/662)") plus `9d259b06c` (CI unblock) and `815df8e43` (DateTime baseline). All 5 sprint tickets transition to Done. **No carry-overs.** **BUT-498 / BUT-697** stay In Progress per standing skip-direction.

**Why this shape:** backlog has zero Urgent/High and no due dates, so priority scoring degenerates. Clustering by area gives each agent a coherent context surface (one rules round + one widget-sweep round) and matches the 3-files-per-agent timeout heuristic from `memory/feedback_agent_timeout.md`.

**Verify-before-starting flags:**
- **A1 (BUT-749)** — finding source is the firebase-backend-security M-1 from sprint 2026-05-01. Confirm the exact rule path in `firestore.rules` and pair the rule edit with `functions/src/__tests__/menus-rules.test.ts` allow/deny coverage proving a non-self recipient can no longer be scrubbed by another recipient's update.
- **A2 (BUT-580)** — Algolia client init location TBC. Grep for `Algolia` / `algolia` first; verify EU cluster is set (`-eu` app ID prefix or explicit `hosts` config) and that no userId / displayName / email is bundled in `searchParams.userToken` or analytics tags without a consent gate.
- **B1 (BUT-591)** — confirm the 6 sites first via `grep -r "withOpacity(" lib/`. Ticket body lists `animated_pressable.dart` and `responsive_grid.dart` as known offenders.

### Agent A: firebase-backend-security + firestore-rules-tester — security & privacy hygiene

- [x] **A1. Fix menus rule self-scrub branch — recipient self-scrub allows booting other recipients in same update** — `firestore.rules` (menus update path) + `functions/src/__tests__/menus-rules.test.ts`. The current allow-update branch lets a recipient remove themselves from the recipient list, but the same path also accepts updates that drop OTHER recipients, breaking the integrity invariant. Tighten the diff check so `request.resource.data.recipients` may only differ from `resource.data.recipients` by removing the requester's own UID. Add allow/deny tests proving (a) self-scrub still works, (b) cross-recipient scrub denies, (c) owner-driven recipient management still works. (BUT-749) (M-1 from prior sprint review)
- [x] **A2. Algolia: verify EU cluster + anonymize query context** — Algolia client init site (find first via grep). Confirm app ID resolves to EU (`-eu` suffix) or `hosts` is pinned to EU endpoints. Strip `userToken` / `analyticsTags` / context fields that contain UIDs, display names, or emails unless analytics consent is granted. If the consent gate already exists upstream, this is a verification + assertion-test ticket; if not, add the gate. (BUT-580)
- [x] **A3. Privacy policy: add data-processor inventory (GDPR Art 13(1)(f))** — `lib/views/legal/privacy_policy_view.dart` + the corresponding ARB keys. List each data processor (Firebase, Mistral OCR, Algolia, Crashlytics, Sentry — confirm the actual list from `pubspec.yaml` + Cloud Functions deps), what they receive, where they're hosted, and the legal basis. Swedish + English copy. No code-path changes; documentation/legal copy ticket. (BUT-620)

### Agent B: flutter-developer — tech-debt sweep wave

- [x] **B1. Replace remaining 6 `withOpacity()` calls with `withValues(alpha:)`** — **NO-OP.** Reconnaissance found zero `.withOpacity(` calls in `lib/`; ticket premise stale (already migrated in a prior sweep, likely commit `89c9f03a7`). Closing as already-resolved. (BUT-591)
- [x] **B2. EdgeInsets.all(N) magic-number audit → `app_dimensions` tokens** — **1 actual violation.** Reconnaissance found only `lib/widgets/menu/calendar_weekly_menu_widget.dart:389` (`EdgeInsets.all(6)` → `EdgeInsets.all(AppDimensions.spacing6)`). Other matches were the token definition itself (`app_dimensions.dart:348`) and a doc comment (`responsive_builder.dart:368`). (BUT-597)
- [x] **B3. Mixed border-radius audit — enforce SQUARE design-language rule** — **NO-OP.** Reconnaissance found only 2 `BorderRadius.circular([1-9])` sites in `lib/`, and BOTH are documented intentional exceptions: `shopping_list_content.dart:416` (LinearProgressIndicator end-cap softening — progress indicators are not in the square-design list) and `layout_scaffolds.dart:129` (Material drag handle — explicitly commented "rounded exception to square design"). Closing as already-clean. (BUT-601)
- [x] **B4. i18n tidy-up — extract 3 hardcoded Swedish `Text()` literals to ARB** — **Resolved by deleting dead code.** Reconnaissance found `cooking_mode_view.dart` clean (no Text literals). The 2 hardcoded literals in `comment_debug_panel.dart` were in a class with ZERO call sites — entirely dead code. Deleted `lib/widgets/recipe/comment_debug_panel.dart` outright. (BUT-609)

### Post-Sprint Steps

- [ ] `dart analyze --fatal-infos`
- [ ] `flutter test test/` (sweep ripples; broad-but-fast)
- [ ] `cd functions && npm run test:menus-rules` (A1 — add the script if missing)
- [ ] Commit, push to main
- [ ] Update Linear: BUT-749/580/620/591/597/601/609 → Done

### Follow-ups surfaced this sprint (file as new tickets)

- **Consent-gate dedup** — `core_module.dart:395`, `main.dart:310`, and `search_module.dart:174` all run the same `isRegistered<ConsentService>` + `hasConsent(ConsentPurpose.analytics)` pattern with deny-by-default. Three drifting copies of a security-critical gate is the classic GDPR foot-gun. Extract to a shared `Future<bool> hasAnalyticsConsent(GetIt c)` helper (likely on `ConsentService` itself). Surfaced by simplify-pass reuse review on sprint 2026-05-02.
- **Algolia consent re-evaluation** — Consent granted *after* app startup currently requires a restart to flip Algolia on. Wire `ConsentService.onConsentChanged` to a module-level re-init hook. Acceptable for beta; surfaced by A2 implementation report.

### Continued blockers (NOT in scope per memory)

- BUT-415 / BUT-714 / BUT-646 — store/play submission deferred (Apple Dev enrollment + Universal Links + listing copy)
- BUT-731 — blocked on Apple Developer Program enrollment ($99/year business decision); same gate as BUT-415/714
- BUT-498 / BUT-697 — explicitly skipped per standing direction
- BUT-686 / BUT-660 / BUT-694 — deferred from sprint 2026-05-01 reconnaissance; need feature-level brainstorming before implementation
- BUT-674 / BUT-721 — privacy/legal-adjacent but too big for this sweep; need their own scoped sprints
- All `idea`-labeled monetization scaffolding (BUT-443/571/642/643/644/648/650/653/656/658/661/664/668/672/673/677/680/683/685) — post-beta per memory

---

## What this means in plain language

- **One real security fix ships.** A bug in the meal-share rules currently lets one person on a shared menu kick another off. A1 plugs that.
- **Two privacy paperwork items ship.** The privacy policy gets the GDPR-required vendor list (A3), and the search backend gets locked to EU servers + stops sending personal context with queries (A2).
- **Visual cleanup wave.** Four mechanical sweeps clean up deprecated Flutter calls (B1), replace magic-number spacing with theme tokens (B2), finish the SQUARE-corners design rule (B3), and pull the last 3 hardcoded Swedish strings into the translation file (B4).
- **Risk: low.** Security fix is rule-only and covered by automated rules tests. Sweeps are mechanical and reviewed by `code-reviewer`. No new external services, no schema changes, no UI redesigns. Easy to revert any single sweep ticket on its own.

---

## ARCHIVED — Sprint: Retention measurement loop + import HEIC fix — 2026-05-01

Shipped as `d803ea1f2` ("feat(analytics/import): retention measurement loop + HEIC conversion (BUT-688/691/623/599/662)") plus `9d259b06c` (CI unblock) and `815df8e43` (DateTime baseline). All 5 implementation tasks complete. BUT-688/691/623/599/662 → Done in Linear.

## ARCHIVED — Sprint: GDPR tripwires red→green + onboarding follow-ups + simplify-pass cleanup — 2026-05-01

Shipped as `e52a1ebb4` ("fix(gdpr): close BUT-746/747/748 + onboarding follow-ups + migration perf"). All 8 tasks complete. BUT-740/741/743/744/745/746/747/748 → Done in Linear.
