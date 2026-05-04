# Butlery Forensic Audit — Final Synthesis

**Run:** 2026-05-claude (12-prompt audit, Waves 1–4)
**Date:** 2026-05-02
**Analyst:** Claude (Opus 4.7, 1M context), supported by Tier-2 specialist agents and seven `.claude/agents/*.knowledge.md` files
**Phase:** Phase 1 — investigation only; zero code changes across all 12 reports

---

## Overall Score: 74 / 100 — Acceptable

(One point below the "Good" threshold. Action: prioritized remediation within two sprints.)

### Weighted formula

```
Overall = (01*0.13) + (02*0.13) + (03*0.12) + (04*0.12)
        + (05*0.07) + (06*0.09) + (07*0.09) + (08*0.04)
        + (09*0.06) + (10*0.03) + (11*0.06) + (12*0.06)
```

| # | Dimension                                | Score | Weight | Contribution |
|---|------------------------------------------|------:|-------:|-------------:|
| 01| Code Quality & Architecture              |    71 |   0.13 |         9.23 |
| 02| Security & Compliance                    |    78 |   0.13 |        10.14 |
| 03| Infrastructure & Operations              |    73 |   0.12 |         8.76 |
| 04| Performance & Scalability                |    72 |   0.12 |         8.64 |
| 05| Dependencies & Supply Chain              |    71 |   0.07 |         4.97 |
| 06| User Experience & Platform               |    78 |   0.09 |         7.02 |
| 07| AI / LLM Quality & Reliability           |    78 |   0.09 |         7.02 |
| 08| Product Analytics & Growth               |    78 |   0.04 |         3.12 |
| 09| Trust, Safety & Advanced Privacy         |    80 |   0.06 |         4.80 |
| 10| Monetization & Competitive Positioning   |    70 |   0.03 |         2.10 |
| 11| Legal Review                             |    76 |   0.06 |         4.56 |
| 12| Documentation & Operational Drift        |    62 |   0.06 |         3.72 |
|   | **Total**                                |       | **1.00** | **74.08** |

The lowest-scoring dimension (12, doc drift at 62) sits well below the others. Frame appropriately: most of the drift is in CLAUDE.md system rules, the orchestrator context block, and `ACCEPTED_LARGE_FILES.md` — administrative artefacts, not security or runtime correctness. The user-facing legal docs (privacy policy, ToS, community guidelines) are in much better shape than prompt 11 was originally instructed to expect.

The highest-scoring dimensions (09 at 80, 02/06/07/08 at 78) tell the real story: this is a **mature, well-engineered codebase whose documentation has fallen out of sync with its own progress.** Several "blockers" the orchestrator instructed prompts to flag are already resolved on disk (release keystore, R8/ProGuard, `applicationId = se.butlery.app`, PITR + weekly backups, Mistral→Vertex AI Gemini migration). The drift goes mostly in the right direction.

---

## Top 5 Risks

Ranked by impact × likelihood, weighted toward items hit by multiple prompts.

1. **`ConsentPurpose` undefined in `notification_service.dart:649` — convergence finding (5 prompts).**
   Static-analysis error captured at `_pre-analysis/flutter-analyze.txt:3`. Flagged by 01 (CRITICAL build/compile), 02 (HIGH-2, CVSS 7.4 — privacy/GDPR Art 17 + 7(3)), 06 (CRITICAL C1 — UX consent flow), 09 (LOW race annotation), 11 (initially expected, then verified resolved at code level but cited as historical). Status uncertain: file was edited 3 minutes after analyze captured (19:51 vs 19:48), so the error may be stale on disk. **Re-run `flutter analyze` once.** If the error reproduces, the entire push-consent-revoke → SecureStorage cleanup path (BUT-754) is dead code at runtime, leaving a stale FCM token in Keychain after revoke. One-line import fix; high blast radius.

2. **No initial GDPR consent prompt during onboarding.**
   Flagged by 09 (HIGH-3.1) and 11 (HIGH, cited). New users complete signup without ever seeing the granular consent UI — `ConsentManagementView` is reachable only post-login from the Profile menu. Default = denied so no data leaks, but Article 7(2) "request for consent ... clearly distinguishable" is not honoured, and Article 13 transparency at the moment data is obtained is dodged. Single sprint fix (~8 h).

3. **Test infrastructure hangs CI for ~10 min/test in `infrastructure_integration_test.dart`.**
   Flagged by 01 (C-2) and 03 (C-1). `TestServiceLocator.reset()` calls `_getIt.reset(dispose: true)` on ~50 mocks with un-cancelled stream subscriptions; one stream blocks the dispose pipeline indefinitely. Local coverage run aborted at 45 min with 200 failures. CI silently times out the unit-tests job at 20 min — **the green-checkmark culture on main is built on a coverage signal that doesn't fully execute.** The "ViewModels 100% / Services 96% / Repos 88%" coverage claim in the orchestrator is therefore unverifiable. ~4 h to triage.

4. **Auto-healer listener fan-out scales catastrophically on conversations.**
   Flagged by 04 (CRITICAL Dim 4). `getUserConversations` opens up to 50 concurrent message listeners (one per conversation row) just to keep `lastMessage` in sync. At 10K active users with messaging that's ~200–500K concurrent listeners — **breaks Firestore's ~100K/project soft cap**. The fix is to replace the client auto-healer with a Cloud Function `onMessageCreate` trigger that writes `lastMessage` to the parent doc; then delete `ConversationAutoHealerModule` entirely. 1–2 sprints. This finding shows the depth of `performance-optimizer.knowledge.md` — a raw-LLM analyst would likely have missed the per-row listener spawn pattern.

5. **iOS `ITSAppUsesNonExemptEncryption=false` is incorrect — provably contradicts the privacy policy.**
   Flagged by 11 (HIGH-5.1). The plist asserts no non-exempt encryption while `assets/legal/privacy_policy_en.md:277` admits "AES-256 encrypted storage (SQLCipher)". US EAR misdeclaration class; Apple App Review increasingly flags this on submission. Fix is small: change to `true` + claim the §740.17(b)(1) consumer-mass-market exemption + file ERN via SNAP-R. ~1 h. Not a runtime correctness issue but a future-state submission blocker the moment the user begins app-store filing.

Honourable mentions (top-10 risks if list were longer): OCR/Vision API keys recoverable from release binary (02 HIGH-1); audit-log retention drift across model/service/CF (02 MEDIUM-1, three different values); `RealtimeSyncService._cachedResources` unbounded memory growth (04 CRITICAL); `sqlcipher_flutter_libs 0.7.0+eol` upstream marker on the encryption substrate (05 HIGH); Firestore restore drill never performed (03 CRITICAL — backup is theoretical until exercised).

---

## Top 5 Strengths

1. **Repository contract & GDPR foundation are genuinely solid.** `BaseFirebaseRepository` → `PermissionValidationMixin` transitive adoption is ≥95% (only 2 known offenders, both documented). GDPR Articles 7/15/17/30 have real implementations with 24-month consent-event retention, 4-tier deletion cascade, BUT-477 presence cleanup, BUT-501 export gateway, BUT-665 retention purger, BUT-753 admin cascade, BUT-754 FCM-token revoke. (02, 09, 11)

2. **Internationalization is exemplary.** 6 347 ARB keys × 2 locales (sv/en) at perfect parity. **Zero hardcoded user-facing English strings in `lib/views/`** (only 5 numeric/lowercase-brand exceptions). 1 769 `context.l10n` callsites in views. 130 a11y-prefixed keys. (06, score 16.5/18)

3. **Operational runbooks are the strongest doc cluster.** `backups.md`, `presence-ttl-runbook.md`, `llm-kill-switch-runbook.md`, `audit-logs-retention.md`, `freerasp-runbook.md`, `moderation-runbook.md` are dated, internally consistent, and accurate to the code they describe — written/updated within the past month. (12)

4. **AI cost & quality discipline.** Multi-tier import (Site Config → SchemaOrg → RuleBased → LLM) means the LLM is the *fallback*, not the default — site-config tier means cheap parsing for known sites at zero LLM cost. `ImportRateLimiter` already does per-window cost tracking (per-minute / per-hour / per-day / monthly $) with Firestore-transactional updates — the most expensive piece of any freemium stack already exists. Vertex AI Gemini pinned to europe-west1, ADC-authenticated, structured-output schema-enforced. Prompt versioning via `PROMPT_VERSION` + Firestore overlay; truncation salvage (BUT-577). (07, 10)

5. **Security & privacy posture exceeds the orchestrator's expectations.** iOS Privacy Manifest scored 12/12 (perfect — declared API reasons, NSPrivacyTracking=false, NSPrivacyTrackingDomains empty, 9 collected data types correctly tagged). ATT correctly absent (no IDFA, no advertising SDK). Hosting headers already include HSTS+CSP+X-Frame-Options+Referrer-Policy+Permissions-Policy. Firebase region pin verified at europe-west1 for Functions and Vertex AI. (02, 09, 11 each note this)

---

## Convergence Findings (multi-prompt)

The single most load-bearing risks are the ones flagged independently by 3+ reports. Sprint 1 should target these first.

| Finding | Hit by | Severity | Fix size |
|---|---|---|---|
| **`ConsentPurpose` undefined at `notification_service.dart:649`** (compile-error class; runtime path = GDPR Art 17 + 7(3) FCM-token revoke) | 01, 02, 06, 09, 11 | CRITICAL if real, LOW if stale | 0.5 h verify, 2 h if real |
| **No initial GDPR consent prompt** (Art 7(2) + Art 13 transparency) | 09, 11 | HIGH | ~8 h |
| **Mistral → Vertex AI Gemini doc drift** (orchestrator + 6 prompt files + 2 service-layer doc-comments + cloud-functions agent knowledge file) | 07, 11, 12 | LOW–CRITICAL depending on surface (CRITICAL only because it would propagate to user-facing legal docs if not caught) | ~1 h grep+replace |
| **Audit-log retention values drift across model + service + CF (365d / 180d / 24mo+6mo)** | 02, 11, 12 | MEDIUM (Art 5(1)(e) consistency) | 2 h doc + ~4 h code (retire legacy CF) |
| **Test infrastructure hang masks CI coverage signal** | 01, 03 | CRITICAL | ~4 h |
| **`ACCEPTED_LARGE_FILES.md` register inconsistent (133/132/121 numbers; 99 over-limit files unaccounted)** | 01, 12 | HIGH (norm erosion — file-size discipline can no longer be enforced) | 2–3 h triage |
| **Functions in europe-west1 but Firestore in europe-west3** (audit-logs runbook claims they match — they don't; cross-region cost on every CF invocation) | 03, 11, 12 | MEDIUM | 30 min doc; architectural decision needed for code |

---

## Items Requiring Immediate Attention

Things that are broken (or arguably broken) in production today, ordered by urgency:

1. **Re-run `flutter analyze`.** If `notification_service.dart:649` reproduces, the FCM-token-revoke path is dead — privacy violation on every user who revokes push consent. Single command, 2-minute test.
2. **Triage the `infrastructure_integration_test.dart` hang.** CI coverage is unreliable until this is either fixed or the file is excluded from the unit-tests run. Currently the green check on main builds is a partial truth.
3. **Schedule a Firestore restore drill.** PITR + weekly export are configured but never exercised. RTO/RPO claims are aspirational. Per `docs/ops/backups.md:32` literally: "Restore drill — NEVER PERFORMED." 2–3 h cost; converts unknown into measured.
4. **Investigate the `sqlcipher_flutter_libs 0.7.0+eol` upstream marker.** Encrypted-database substrate — defence in depth depends on it. 30-minute pub.dev investigation will tell you whether it's "the 0.6 line is EOL" (do migration), "the whole library is EOL" (replace substrate, 2–4 days), or something benign.

---

## Unified Remediation Roadmap

Sized for a solo developer. Sprint 1 is ~5 working days; Sprint 2 ~2 weeks; Sprint 3 ~2 weeks; backlog is unsized.

### Sprint 1 — CRITICAL + quick-win HIGH (~1 week)

**Verification block (first 2 hours):**
- Re-run `flutter analyze` after `flutter clean`. Fix `ConsentPurpose` import if the error reproduces. Add a regression test in `fcm_token_manager_test.dart` for the consent-revoke path.
- Verify CI: confirm whether `test.yml`'s 20-min unit-tests timeout is silently triggering on `infrastructure_integration_test.dart`.

**Compliance + privacy (≤1 day):**
- Add initial GDPR consent prompt to onboarding (between welcome and age gate). 8 h. (09 HIGH-3.1, 11 HIGH cited)
- Change `ITSAppUsesNonExemptEncryption=true` + claim TSU mass-market exemption + file ERN. 1 h. (11 HIGH-5.1)
- Add rate limit + description size cap to `reports` Firestore rule. Pair with `firestore-rules-tester` agent. 1 h. (09 MEDIUM-1.1)
- Add Privacy Policy + Community Guidelines tiles to Settings hub. 45 min. (09 MEDIUM-2.1, 2.2)

**Doc drift quick wins (2 hours total):**
- Repo-wide Mistral→Vertex AI grep+replace in code-side doc-comments (8 files). 30 min. (07 D7-CRIT-1, 12 Cluster B)
- Update `MASTER_ANALYSIS_ORCHESTRATOR.md` Known-Project-Context block from `_pre-analysis/` outputs. 30 min. (12 Cluster A)
- Add Google Cloud Vision row to privacy-policy processor table. 15 min. (11 MEDIUM-1.1)
- Lift `'veckans\nmeny'` and `'dina\nrecept'` titles into ARB. 30 min. (06 HIGH-4.1)
- Update `MASTER_ANALYSIS_ORCHESTRATOR.md` "Mistral AI integration" → "Vertex AI Gemini 2.0 Flash, europe-west1". (12 H-4)

**Infrastructure (4 hours):**
- Fix `TestServiceLocator.reset()` dispose-leak (or skip the test pending fix). 4 h. (01 C-2, 03 C-1)
- Schedule first Firestore restore drill on a sibling database; document procedure in `backups.md`. 3 h. (03 C-3)

**Stretch goals if time allows:**
- Pin `gemini-2.0-flash-001` (date-stamped revision instead of floating alias). 30 min. (07 D4-HIGH-1)
- Add `safetySettings` to Vertex client. 15 min. (07 D4-MED-1)
- Move OCR.space + Google Vision API keys from `String.fromEnvironment` to a Cloud Functions callable. 6–10 h. (02 HIGH-1, 11 LOW-6.1)

### Sprint 2 — Remaining HIGH + systemic MEDIUM (~2 weeks)

**Architecture & testability:**
- Move `FirebaseAuth.instance` out of `onboarding_age_gate_blocked_view` into `AccountDeletionService`. (01 H-1)
- Remove `cloud_firestore` SDK import from `viewmodels/menu/menu_storage.dart`. (01 H-2)
- Audit and fix the 5–6 service-layer files that still hit `FirebaseFirestore.instance` directly. 1–2 days. (01 H-3, 12 H-8)
- Reconcile `ACCEPTED_LARGE_FILES.md` against `files-over-500-lines.txt`. Walk the 99 unaccounted files; either add them with rationale or schedule decomposition. 2–3 h triage + ongoing. (01 H-4, 12 C-3, D4.1)
- Decompose `main.dart` (954 → 1250 LOC, +31%) and `mina_recept_view.dart` (687 → 996, +45%). 2–3 days each.

**Performance:**
- Replace `ConversationAutoHealerModule` with a Cloud Function `onMessageCreate` trigger. 1–2 sprints — single largest scale unblock. (04 CRITICAL Dim 4)
- Bound `RealtimeSyncService._cachedResources` with an LRU. 1 day. (04 CRITICAL Dim 2)
- Swap 7 `Image.network` calls for `CachedNetworkImage`. 30 min. (04 HIGH Dim 2)
- Defer the web `_health/_` Firestore probe to after first frame. 30 min. (04 HIGH Dim 1)
- Add `.limit(N)` to the 7 unbounded user-scoped streams. 1 h. (04 HIGH/MED Dim 3)

**Security & data integrity:**
- Resolve audit-log retention drift: pick one retention horizon per category, retire `cleanup-audit-logs.ts`, align the 365d model write. 4–6 h. (02 MEDIUM-1, 11 MEDIUM-1.2, 12 D5.1)
- Fix `group_weekly_menu_plans` membership-desync (admin can downgrade `participantUserIds` without `memberPermissions`). 2 h. (02 MEDIUM-2)
- Tighten `pings` broadcast read rule (currently any auth user can read+ack any group's broadcast pings). 3 h. (02 MEDIUM-6, 09 #3 cited)
- Decide between europe-west1 vs europe-west3 for Firestore (or document the split-region intent + cost). 30 min doc; architectural decision for code. (03 MEDIUM-8, 12 D3.1)

**Infrastructure:**
- Add AAB/IPA artifact retention on main builds (90-day). 30 min. (03 H-1)
- Add `permissions:` block to 4 workflows missing it. 30 min. (03 M-14)
- Add `flutter analyze` step to `test.yml`. 30 min. (03 M-2)
- Add wait-for-emulator readiness loop to test.yml integration job. 1 h. (03 H-5)
- Stand up SLO doc + alert routing doc in `docs/ops/`. 2 h. (03 H-10, M-10)

**Dependencies & supply chain:**
- Investigate `sqlcipher_flutter_libs 0.7.0+eol` semantics. 0.5 day. If migration needed, 2–4 days. (05 HIGH-3)
- Group Firebase suite minor upgrades. 1 day. (05 HIGH-2)
- Migrate `http_certificate_pinning` to in-house pinning interceptor (single-maintainer unverified-publisher package on the security-critical path). 2–3 days. (05 MEDIUM)

### Sprint 3 — Remaining MEDIUM + worthwhile LOW (~2 weeks)

**Trust, safety, privacy hardening:**
- New-account rate-limit grace period (sock-puppet defence). 4 h. (09 MEDIUM-8.1)
- Under-13 disclaimer screen in age gate. 1 h. (09 MEDIUM-7.1)
- Document App Store age-rating questionnaire answers. 30 min. (09 MEDIUM-7.2)
- Split `marketing` consent purpose: either remove or wire up. 1 h (remove path). (11 MEDIUM-6.1)
- Tighten PII-scrubber claim in privacy policy to enumerate exact categories. 15 min. (11 MEDIUM-4.1 path a)
- Add ToS section 5.4 "When you delete your account". 15 min. (11 MEDIUM-2.1)
- Add `assets/illustrations/LICENSE.md`. 30 min. (11 MEDIUM-3.1)
- Add `NSPrivacyCollectedDataTypeHealth` to PrivacyInfo.xcprivacy for allergen prefs. 15 min. (11 MEDIUM-5.1)

**Analytics coverage debt:**
- Wire `inAppReviewRequested/Dismissed` events. 15 min. (08 HIGH)
- Wire `logMessageSent`, friend-rejected/cancelled/removed/blocked, group-left/deleted. ~2 h. (08 HIGH)
- Add `first_cook` milestone alongside `first_share`/`first_friend`. 1 h. (08 HIGH)
- Reconcile `notification_history` vs `notification_send_events` data sources. 1 h. (08 HIGH)

**Tagging robustness:**
- Per-phase try/catch in tagging pipeline (Phase 3 crash currently silently nukes Phases 4-5). 4 h. (07 D2-MED-3, D8-MED-2)

**Doc reconciliation:**
- Re-validate `FIREBASE_PERFORMANCE_GUIDE.md` line citations. 1 h. (12 M-6)
- Update `ACCEPTED_LARGE_FILES.md` line counts. 2–3 h. (12 D4.1)
- Add `docs/ops/SLOs.md`, `crash-spike-runbook.md`. 2 h. (03 H-10, H-11)

### Backlog (post-launch / nice-to-haves)

- LRU + memory pressure handling for 7 unbounded streams (defensive caps already in Sprint 2)
- Read-side block enforcement (currently write-side only)
- Server-side profanity filter (CF mirror of client list)
- Structured appeal flow (replaces mailto)
- Email re-engagement channel (BUT-686)
- Behavioral notification segmentation beyond "X days inactive"
- Schema.org JSON-LD on shared recipe links (organic discovery)
- Referral / invite-loop infrastructure
- Family-plan / shared-subscription support (post-monetization)
- Inline cooking timers + live recipe scaling (table-stakes gaps for monetization)
- Voice / hands-free cooking mode (Swedish STT)
- Manual nutrition entry + Livsmedelsverket integration
- A/B prompt-variant infrastructure (foundation for ongoing AI quality work)
- Scheduled golden-set regression test against live LLM
- SLSA provenance / supply-chain attestation
- Pin GitHub Actions by SHA instead of tag
- `release-please` automation for version bumps
- RTL readiness (39 directional-blind `EdgeInsets`; not blocker for Swedish-first)

---

## Methodology Note

This run was deliberately framed as "Claude with Tier-2 specialist subagents and accumulated knowledge files" vs the parallel Codex run of the same 12 prompts. Three concrete examples where that framing produced depth that a raw-LLM analyst would plausibly miss:

1. **Prompt 04 — `ConversationAutoHealer` listener fan-out.** Required reading both the query module (`conversation_query_module.dart:36-46`) and the auto-healer module (`conversation_auto_healer_module.dart:28-79`) and recognizing that **a list listener spawns a per-row listener** on every snapshot. Pattern matches `performance-optimizer.knowledge.md` patterns around stream lifecycle. Without that knowledge anchor, this scales as "a slow query" rather than "Firestore project-ceiling break at 10K users."

2. **Prompt 02 — PermissionValidationMixin transitive adoption ≥95%.** The orchestrator's "20% adoption" claim is wrong; the mixin is applied transitively via `BaseFirebaseRepository`. `firebase-backend-security.knowledge.md` (88 KB, the heaviest knowledge file in the project) explicitly documents this as the canonical pattern. A raw-LLM analyst seeing "20%" in the prompt would have over-flagged it; this run downgraded it to a 2-repo cleanup task.

3. **Prompt 11 — `ITSAppUsesNonExemptEncryption=false` is provably wrong from the bundle alone.** Required the cross-prompt context that 06 + 10 each *mentioned* the plist field but did not *flag* it, plus knowledge of Apple's §740.17(b)(1) consumer-mass-market exemption framework, plus the privacy policy's own AES-256/SQLCipher admission. The convergence is what made this a HIGH finding rather than a footnote.

Across all 12 reports, multiple drift items the prompts instructed analysts to flag turned out to be **already fixed in code** (Mistral→Vertex AI Gemini in the privacy policy, `applicationId = se.butlery.app`, R8 enabled, PITR live, security headers in `firebase.json`). The orchestrator and prompt context blocks lag the codebase. This is the single largest signal in the audit: the team is shipping faster than the audit infrastructure tracks. Sprint 1's doc-drift quick wins exist exactly to close that gap so the next forensic run can start from a clean baseline.

The convergence-finding pattern (5 prompts hitting `ConsentPurpose`, 3 prompts hitting Mistral→Vertex docs, 3 prompts hitting audit-log retention) is itself a methodological win: for a solo developer, multi-prompt convergence is the strongest possible signal that an issue is real and worth Sprint-1 spot. Prioritize accordingly.

---

*End of synthesis. Detailed evidence lives in the 12 underlying reports under `docs/analysis/runs/2026-05-claude/`. No code or doc changes were made in this run.*
