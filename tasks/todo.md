# Sprint Backlog

## Sprint: Retention measurement loop + import HEIC fix — 2026-05-01

Theme: now that GDPR tripwires + onboarding follow-ups have shipped (`e52a1ebb4`), ship the **retention measurement half** of the win-back loop (A1, A3, A4, A5 — covers Remote Config copy migration, conversion event, monetization-cohort property, feature-level retention CF) plus a single import-side fix (B2 — explicit HEIC conversion). **Tightened from the original 8-task plan after reconnaissance found 3 from-scratch tasks (A2 email channel, B1 image-quality gate, B3 PII scrubber) that need feature-level brainstorming, not sprint execution.** **2 agents, 5 tasks.**

Prior sprint (`e52a1ebb4`) shipped the GDPR tripwires close-out (BUT-746/747/748 — high priority, all bugs), onboarding follow-ups (BUT-743/744/745), `FirebaseDataExportRepository` simplify pass (BUT-740), and migration parallelization (BUT-741). **No remaining carry-overs.** **BUT-498 / BUT-697** stay In Progress per standing skip-direction.

**Reconnaissance findings (2026-05-01) — 3 tasks deferred from original sprint:**
- **A2 (BUT-686, email channel)** deferred — `functions/package.json` has no email-provider library (Resend / Postmark / SendGrid). Provider choice is a business decision (cost, account, SPF/DKIM); needs brainstorming session before implementation.
- **B1 (BUT-660, image-quality gate)** deferred — grep finds no existing image-quality gate in `lib/services/import/`. Ticket body said "advisory-only" but advisory gate doesn't exist. Build-from-scratch task; needs scope/threshold decisions before implementation.
- **B3 (BUT-694, PII scrubber)** deferred — grep finds no existing scrubber in `lib/services/import/` (regex or otherwise). Ticket body said "regex-based" but no regex scrubber exists. Build-from-scratch task; needs entity-coverage + false-positive tolerance decisions before implementation.

All three reverted to Backlog with comments documenting the recon finding.

**Verify-before-starting flags:**
- **A1 (BUT-688)** — win-back send code is in `functions/src/analytics/{detect-lapsed-users,send-activity-digest}.ts` (NOT `functions/src/winback/` — corrected from initial plan). BUT-657 experiment scaffolding from `b121ed0a2` is in place; A1 proceeds at full scope.
- **A4 (BUT-623)** — file is `lib/services/analytics/user_property_bootstrap.dart` (NOT `analytics_user_properties.dart` — corrected from initial plan).

### Agent A: cloud-functions-specialist — retention measurement loop

- [x] **A1. Move win-back push copy from hardcoded strings → Remote Config template** — `functions/src/analytics/send-activity-digest.ts` (and any sibling lapsed-user notification path). Define `winback_push_{title,body}_<variant>` Remote Config keys with 2-3 variants (e.g. `curiosity`, `value`, `social`). Bucket users via hash-of-uid OR Firebase A/B Testing (whichever BUT-657 scaffolding exposes). Set user property `exp_winback_copy = <variant>` so A3's conversion event can be sliced per variant. **Email-side keys (`winback_email_*`) deferred until A2 is brainstormed.** (BUT-688)
- [x] **A3. Track `winback_converted` event** — `lib/services/analytics/analytics_events.dart` (registry added in BUT-737) + appropriate tracker(s). Emit on first meaningful action (cook complete, recipe import, menu generate) within 7d of `lastWinBackSentAt`. Store `lastWinBackSentAt`/`Channel`/`Variant` on user doc when A1's CF fires; clear after attribution to avoid double-count. Event params: `channel`, `variant`, `hours_since_send`, `action_type`. Closes the measurement loop for A1 + future A2. (BUT-691)
- [x] **A4. Set `subscription_tier` user property** — `lib/services/analytics/user_property_bootstrap.dart`. Default to `"free"` for now (no monetization yet). Wired through the existing user-properties registry. Costless now, blocks retroactive cohort backfill later. (BUT-623)
- [x] **A5. Add feature-level retention CF (DAU/WAU per feature)** — `functions/src/analytics/compute-feature-retention.ts`. Scheduled daily at 04:30 UTC. Per-user per-day flags: `cooked_today`, `imported_today`, `shared_today`, `meal_planned_today`, `shopped_today`. Writes `/analytics/feature_retention/daily/{yyyy-mm-dd}` with DAU + rolling 7-day/28-day WAU/MAU per feature. Respect 500-op Firestore batch limit. Mirrors the user-level retention CF shape from `track-retention.ts`. (BUT-599) (High)

### Agent B: flutter-developer — import HEIC fix

- [x] **B2. Convert HEIC → JPEG explicitly on iOS import path + tag analytics** — entry at `lib/services/image_picker_service.dart` (or `lib/services/import/photo_import_strategy.dart` — verify which is the import boundary first). Magic-byte detect HEIC (don't rely on file extension). Convert via `flutter_image_compress` (verify it's a dep first; if not, add it). Document supported formats in the OCR import doc comment. Add `image_format` field to existing OCR analytics events (in `import_events_tracker.dart`) to measure prevalence. Mistral's vision endpoint accepts HEIC inconsistently across SDK versions — explicit conversion removes the silent-failure class entirely. (BUT-662)

### Post-Sprint Steps

- [ ] `dart analyze --fatal-infos`
- [ ] `flutter test test/unit/services/analytics/` (A3, A4)
- [ ] `flutter test test/unit/services/import/` or relevant photo-import test path (B2)
- [ ] `cd functions && npm run test:lapsed-users && npm run test:track-retention` (A1, A5 — plus add a `test:compute-feature-retention` script)
- [ ] Commit, push to main
- [ ] Update Linear: BUT-599/623/662/688/691 → Done

### Deferred — re-plan as standalone feature work (NOT in this sprint)

- **BUT-686** — Email win-back channel. Needs brainstorming: provider choice (Resend / Postmark / SendGrid), cost approval, SPF/DKIM domain setup, opt-in/opt-out flow, abuse-prevention. Estimated 1-2 days after decision unblocks.
- **BUT-660** — Image-quality gate. Needs brainstorming: detection algorithm (Laplacian variance? on-device ML?), threshold values (UX-tested or arbitrary?), middle-tier UX (warn vs block), Remote Config flag.
- **BUT-694** — PII scrubber. Needs brainstorming: Swedish entity coverage scope, false-positive tolerance (recipes mention real-sounding place names like "Skånsk äggakaka"), placement in the import pipeline.

### Continued blockers (NOT in scope per memory)

- BUT-415 / BUT-714 / BUT-646 — store/play submission deferred (Apple Dev enrollment + Universal Links + listing copy)
- BUT-498 / BUT-697 — explicitly skipped per standing direction
- BUT-731 — blocked on Apple Developer Program enrollment ($99/year business decision); same gate as BUT-415/714
- BUT-620 / BUT-674 / BUT-721 — GDPR backlog items, excluded pending verification that `b121ed0a2`'s GDPR-hardening half didn't already close them

---

## What this means in plain language

- **The win-back loop becomes measurable.** We can now A/B-test the wording of "we miss you" push notifications from a Firebase dashboard instead of redeploying code, and we'll have a counter that tells us when those notifications actually bring someone back to the app. Without the counter we're just guessing whether any of this works.
- **One useful piece of data starts being collected.** Even though monetization is post-beta, a tiny user-property tag (`subscription_tier = "free"`) goes in now so that the day we add paid plans, we can answer "do paid users stick around longer than free users?" without waiting another six months for fresh data.
- **Per-feature usage stats start being measured.** A scheduled job runs every night at 04:30 UTC and writes daily counts of "people who cooked something" / "people who imported a recipe" / etc. — so we can see which features lose users fastest and prioritize accordingly.
- **iPhone photo import gets more reliable.** iPhones default to HEIC format (Apple's image format) — currently the OCR pipeline doesn't explicitly convert them, so some iPhone imports may silently fail. This sprint adds an explicit convert-to-JPEG step.
- **Three originally-planned tasks were deferred.** A 30-minute reconnaissance pass before implementation found that the email-channel + image-quality-gate + PII-scrubber tasks all assumed code that doesn't exist. They're now standalone feature work to be brainstormed properly before implementation.
- **Risk: low.** All five remaining tasks extend code that already exists — no new external services, no new schemas, no UI changes.

---

## ARCHIVED — Sprint: GDPR tripwires red→green + onboarding follow-ups + simplify-pass cleanup — 2026-05-01

Shipped as `e52a1ebb4` ("fix(gdpr): close BUT-746/747/748 + onboarding follow-ups + migration perf"). All 8 tasks complete. BUT-740/741/743/744/745/746/747/748 → Done in Linear.
