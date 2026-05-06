# MASTER — Final Synthesis — Butlery Forensic Audit

**Date:** 2026-05-05.
**Scope:** All 12 prompts across 4 waves, 3 independent forensic runs.
**Inputs:**
- `2026-05-claude/` — Claude default (12 + SYNTHESIS, complete 2026-05-02)
- `2026-05-claude-deep/` — Claude deep + Pass 2 critic (12 + SYNTHESIS, complete 2026-05-04)
- `2026-05-codex/` — OpenAI Codex CLI (7 of 12 — bucket exhaustion blocked 07/09/10/11/12; weekly cap reset 2026-05-09)
- 4 wave masters: `MASTER-wave1.md`, `MASTER-wave2.md`, `MASTER-wave3.md`, `MASTER-wave4.md`
- 2 sister synthesis: `2026-05-claude/SYNTHESIS.md`, `2026-05-claude-deep/SYNTHESIS.md`

**Methodology:** Three-layer verification — deep run's Pass 2 critic, master synthesis re-verification against live source, and cross-wave consistency checks. Findings stripped of stale claims (`ConsentPurpose`, `327k LOC`, `infrastructure_integration_test.dart` blame, etc.). Severity calibrated to deep run; default's systematically high scores corrected. Codex contributed primarily to Wave 1+2 triangulation; Wave 3+4 lean on deep+default two-way consensus.

---

## 0. The 5-minute version

**Overall codebase health: 62/100 (Acceptable; needs prioritized remediation).**

Butlery is **structurally sound but operationally under-enforced**. The architectural patterns, security helpers, observability infrastructure, and design-system primitives all exist. What's missing across the board is the enforcement layer — nothing in CI catches the regressions, so the documented "100% adoption" claims drift further from reality every sprint.

### What's most urgent (3 things)

1. **Fix the security regression that's silently shipped:** TLS certificate pinning is wired but disabled for all 8 third-party HTTPS hosts. Documentation reads as if BUT-427 is "done." Production traffic to Algolia, OCR.space, Google Vision, and 4 recipe-scrape sites falls through to platform trust. (5–9 hours to populate fingerprints.)

2. **Fix the GDPR exposure that the codebase admits to:** `compliance_export_manager.exportAuditLogs` permission-denies for every non-admin user and silently swallows the error into the export payload. The codebase docstring itself says "Cloud Function exporter is the proper long-term fix; tracked under BUT-424 follow-up." That follow-up doesn't exist as code. (2–3 hours.)

3. **Run a real backup drill in the right region:** `docs/ops/backups.md` says europe-west3; `functions/src/index.ts:20` says europe-west1. Restore drill never performed (`backups.md:31` says so verbatim). DR posture is unverifiable. Either backups don't exist or the entire functions tier is operating cross-region. (1.5 days to decide region, run drill, automate weekly check.)

### Three audit-integrity findings (the meta-story)

Three documented "facts" turned out to be wrong in ways that propagated through multiple reports:

| Stale narrative | Reality | Cause |
|---|---|---|
| Codebase is 327 280 LOC | **76 325 LOC** (4× inflation) | Pre-analysis script walked into `lib/site-packages/` containing 29 MB of Pillow + pip |
| `ConsentPurpose` analyzer error is CRITICAL | RESOLVED on disk for 3 days | Pre-analysis snapshot was 3 minutes pre-fix; never re-verified |
| BaseService 96% / BaseFirebaseRepository 78% / ErrorHandlingMixin 100% / SerializationUtils 100% | ~75% / ~53% / partial / partial | Aspirational targets written when helpers were introduced; never measured since |

**The lesson:** the audit tooling itself needs an integrity pass before the next analysis cycle. ~4 hours of work to fix path filters, mtime-vs-error checks, and adoption-claim sourcing — and every future audit gets cleaner data.

### Three surprises about adoption discipline

The deepest cross-wave finding is that **Butlery has built excellent infrastructure that nobody enforces**:

- **`architecture_test.dart` (the meta-gate)** checks ONE rule (Firestore singleton outside repos), uses substring path matching, and exempts `main.dart` whole-file. Broadening it (1-day PR) would prevent regression on at least 8 verified findings across waves.
- **`displayName`/`avatarUrl`** denormalization at 24+ sites reads from auth profile instead of UserService. CLAUDE.md "Critical Conventions" was written specifically to prevent this. The convention is broken at scale across the social hot path.
- **`ConversationAutoHealerModule`** opens 52 Firestore listeners per active user. At 1k DAU this fits under Firestore's 100k project cap. At 10k DAU it breaks. No alarm rings until then — and Codex's 10/12 audit run didn't even spot it.

### What's NOT urgent

- App Store submission and monetization scaffolding (per MEMORY.md "no submission yet" / "no monetization decisions yet"). Several findings here are deferred-by-design.
- Most performance findings — code is 60fps-clean, cold start is 1.8-2.5s, offline performance is healthy. Codex's pessimistic 47/100 perf score was wrong; deep's 66/100 is the real picture.
- Most i18n / localization concerns. The Swedish-first localization is the codebase's strongest dimension (16/18 in deep's UX score). RTL-readiness is the real gap.

### What we'd do differently next time

The triangulation between Codex / Claude default / Claude deep was the most valuable methodological choice — **no single run caught all 27 verified CRITICALs**:
- Codex caught the empty cert-pin fingerprints (Wave 1) but missed scale-time risks like `ConversationAutoHealerModule` (Wave 2)
- Default caught test-infra issues quickly but systematically over-scored every prompt (78 vs deep's 60 on Trust/Safety)
- Deep caught the most CRITICALs but missed `firebase.json` security headers (Wave 4 disproved deep)

The Pass 2 critic methodology in deep was load-bearing — Pass 1 propagated the same 327k LOC bug as Codex+default. Pass 2 caught it.

---

## 1. Combined verified findings — 27 CRITICAL, ~100 HIGH

### CRITICAL findings by area (all verified across 3 layers)

#### Security & GDPR (5)
| ID | Title | Owner | Days |
|---|---|---|---|
| W1 CRIT-SEC1 | `realtime_menus/votes` rule gap — push-driven feature silently broken | 02 Security | 0.5 |
| W1 CRIT-SEC2 | GDPR Article 15 audit-log export broken | 02 Security | 0.3 |
| W1 CRIT-SEC3 | 15/18 Cloud Function callables miss App Check (~17% coverage) | 02 Security | 0.2 |
| W3 CRIT-TS1 | Brigade-amplifier on `reports` collection | 09 Trust/Safety | 1.0 |
| W3 CRIT-TS2 | No image moderation on `cook_snaps`/`shared/recipes`/`feedback` UGC paths | 09 Trust/Safety | 1.5 |

#### Code Quality & Architecture (6)
| ID | Title | Owner | Days |
|---|---|---|---|
| W1 CRIT-CQ1 | TLS cert-pin wired but deactivated for 8 hosts | 01 Code Quality | 0.7 |
| W1 CRIT-CQ2 | `FCMService` is all-static singleton with 11 mutable static fields | 01 Code Quality | 1.5 |
| W1 CRIT-CQ3 | `BaseViewModel` documented standard but ~18% adoption | 01 Code Quality | 3.0 (sprint 1 of multi-sprint) |
| W1 CRIT-CQ4 | `lib/site-packages/` audit-integrity (cause of 4× LOC inflation) | 01 Code Quality | 0.05 |
| W1 CRIT-CQ5 | `architecture_test.dart` too narrow (the meta-gate) | 01 Code Quality | 1.0 |
| W1 CRIT-CQ6 | `displayName`/`avatarUrl` denormalization at 24+ sites | 01 Code Quality | 2.0 |

#### Performance & Scalability (3)
| ID | Title | Owner | Days |
|---|---|---|---|
| W2 CRIT-PERF1 | `ConversationAutoHealerModule` 52 listeners/user (breaks at 10k users) | 04 Performance | 2.5 |
| W2 CRIT-PERF2 | `RealtimeSyncService._cachedResources` unbounded | 04 Performance | 1.5 |
| W2 CRIT-PERF3 | `FriendsStateManager.dispose()` leaks `_blockedUsersSubscription` | 04 Performance | 0.01 |

#### Infrastructure & DR (3)
| ID | Title | Owner | Days |
|---|---|---|---|
| W2 CRIT-INFRA1 | Backup region mismatch (europe-west1 vs europe-west3) — DR unverifiable | 03 Infra | 1.5 |
| W2 CRIT-INFRA2 | `--coverage` excludes integration + e2e — coverage claim unverifiable | 03 Infra | 1.0 |
| W2 CRIT-INFRA3 | Per-test timeout invariant missing (`pumpAndSettle()` no-arg burns 10 min) | 03 Infra | 0.05 |

#### Dependencies & Supply Chain (2)
| ID | Title | Owner | Days |
|---|---|---|---|
| W1 CRIT-DEP1 | `sqlcipher_flutter_libs` confirmed end-of-life | 05 Deps | 3.0 |
| W1 CRIT-DEP2 | CI Node-version mismatch (npm-audit auditing wrong package graph) | 05 Deps | 0.05 |

#### AI/LLM Quality (2)
| ID | Title | Owner | Days |
|---|---|---|---|
| W3 CRIT-AI1 | No closed-loop LLM quality measurement (no golden set, no drift telemetry) | 07 AI/LLM | 1.5 |
| W3 CRIT-AI2 | `gemini-2.0-flash` alias unpinned + no `modelId` in analytics | 07 AI/LLM | 0.5 |

#### Doc-vs-Code Drift (4)
| ID | Title | Owner | Days |
|---|---|---|---|
| W4 CRIT-DOC1 | `code-style.md` "33 files" wrong (real 131); `ACCEPTED_LARGE_FILES.md` self-contradicts | 12 Doc | 0.1 |
| W4 CRIT-DOC2 | Audit-log retention triple-source drift (365/180/730d) | 12 Doc | 0.3 |
| W4 CRIT-DOC3 | Mistral→Vertex AI orchestrator drift (8 files) | 12 Doc | 0.05 |
| W4 CRIT-DOC4 | BaseService/BaseFirebaseRepository/ErrorHandlingMixin/SerializationUtils adoption % all wrong | 12 Doc | 0.1 |

#### User Experience (0 verified CRITICAL — Wave 3 disproved both candidates)

**Total CRITICALs: 27.** Total raw remediation: **~22 days at traditional estimates, ~7 days vibecoding-realistic** (most are mechanical/documentation fixes).

### HIGH summary by area
- 01 Code Quality: ~10 HIGH (architecture, code style, model-boundary parsing)
- 02 Security: ~6 HIGH (cert-pin, friend_requests, OCR keys, GDPR cascade audit, account-deletion race, friends rule)
- 03 Infrastructure: ~16 HIGH (deployment automation, observability, supply chain hardening, secret-scan, monitoring scope)
- 04 Performance: ~10 HIGH (image cache, dispose-leaks, isolate offload, view models)
- 05 Dependencies: ~9 HIGH (build_runner discontinued, Firebase 12-deep lag, push-trigger, caret pins, ONNX integrity, action mutability, license-trail)
- 06 UX: ~8 HIGH (text-scaling adoption, touch targets, RTL readiness, loading-state component, desktop branding, locale switcher, MediaQuery patterns)
- 07 AI/LLM: ~8 HIGH (OCR retry, privacy logging, retry stacking, adversarial fixtures, prefix caching, splitter coupling, Unicode fractions, prompt-changelog gate)
- 08 Analytics: ~11 HIGH (sessionId, win-back set, notification-source skew, cooking dark, setUserId, kDebugMode, social graph dark, milestones, feature flags, favorite event)
- 09 Trust/Safety: ~4 HIGH (onboarding consent, erasure cascade, ContentType enum, reCAPTCHA disclosure)
- 10 Monetization: ~7 HIGH (subtitle, screenshots, subscription tier, OCR usage cap, IAP scaffolding, EU cooling-off, deletion-sub interaction)
- 11 Legal: ~10 HIGH (audit-log retention, encryption export, privacy policy completeness, LICENSE/NOTICE, ToS deletion cascade, Mistral drift, iOS Privacy Manifest, ONNX disclosure, subprocessor list, store data-safety alignment)
- 12 Doc Drift: ~12 HIGH (audit-log region, pre-analysis labeling, doc claims stale, Flutter version)

**Total HIGH: ~100** after dedup. Many are mechanical fixes (~15-20 days) but several are multi-week projects (BaseViewModel migration, IAP scaffolding).

---

## 2. Combined remediation roadmap (~67 traditional days, ~20-30 vibecoding-realistic)

### Phase 1 — Stop the bleeding (Sprint 1 — ~3 days)
The smallest possible set of changes that closes the loudest exposures and unblocks all subsequent audit cycles.

| # | Action | Source | Days |
|---|---|---|---|
| P1.1 | Delete `lib/site-packages/` + add path filter to pre-analysis | W1 CRIT-CQ4 + W4 CC-1 | 0.05 |
| P1.2 | Populate 8 cert-pin fingerprints + release-mode assertion | W1 CRIT-CQ1 | 0.7 |
| P1.3 | Build `exportAuditLogs` Cloud Function (admin SDK + uid filter) | W1 CRIT-SEC2 | 0.3 |
| P1.4 | Add `enforceAppCheck: true` to 15 unprotected callables | W1 CRIT-SEC3 | 0.2 |
| P1.5 | Fix Node version mismatch in `dep-audit.yml`/`e2e_tests.yml` | W1 CRIT-DEP2 | 0.05 |
| P1.6 | Rename `friend_requests`→`social_requests` in 6 functions/src refs | W1 HIGH-SEC2 | 0.5 |
| P1.7 | Decide canonical region (recommend europe-west1) + run real backup drill | W2 CRIT-INFRA1 | 1.0 |
| P1.8 | Create `dart_test.yaml` 30s per-test timeout | W2 CRIT-INFRA3 | 0.05 |
| P1.9 | Cancel `_blockedUsersSubscription` in `FriendsStateManager.dispose()` | W2 CRIT-PERF3 | 0.01 |
| P1.10 | Audit-tooling fixes (mtime check, snapshot timestamp, adoption-status doc) | W4 CC-1 | 0.2 |

**Phase 1 total: ~3 days.** Closes top 5 most-cited regulatory/security exposures + unblocks audit tooling for next cycle.

### Phase 2 — Architectural locks (Sprint 2 — ~3 days)
The single highest-leverage architectural changes.

| # | Action | Source | Days |
|---|---|---|---|
| P2.1 | Broaden `architecture_test.dart` (5 Firebase singletons + view→firebase-repo + VM→cloud_firestore + VM-extends + service-extends + .collection-literal ban) | W1 CRIT-CQ5 | 1.0 |
| P2.2 | Replace `ConversationAutoHealerModule` per-conversation healers with single `participantUserIds`-array-contains listener | W2 CRIT-PERF1 | 2.5 |
| P2.3 | Add `LruMap` wrapper to `RealtimeSyncService._cachedResources` + `firebase_user_ingredient_repository._userCache` | W2 CRIT-PERF2 | 1.5 |
| P2.4 | Add Cloud Storage `onObjectFinalized` trigger (magic-byte verify + SafeSearch + format whitelist) | W3 CRIT-TS1+TS2 + W1 MED-13/14 | 1.5 |
| P2.5 | Tighten `reports` collection rule + add cascade in account deletion | W3 CRIT-TS1 | 1.0 |

**Phase 2 total: ~7.5 days.** Closes the meta-gate + scale-time tripwires + UGC moderation gap.

### Phase 3 — Adoption + observability (Sprint 3-4 — ~11 days)

| # | Action | Source | Days |
|---|---|---|---|
| P3.1 | Refactor `FCMService` static-singleton → instance + DI | W1 CRIT-CQ2 | 1.5 |
| P3.2 | Migrate top 6 viewmodels to `BaseViewModel` (recipe_list, recipe_form, recipe_detail, unified_shopping, friends, menu) | W1 CRIT-CQ3 | 3.0 |
| P3.3 | Migrate `displayName`/`avatarUrl` 14 repository write paths to `DisplayIdentityProvider` | W1 CRIT-CQ6 | 2.0 |
| P3.4 | Add `--coverage` to integration+e2e jobs; merge via lcov | W2 CRIT-INFRA2 | 1.0 |
| P3.5 | Recompute orchestrator adoption percentages from real coverage | W2 CC-Wave2-3 | 1.0 |
| P3.6 | Build LLM golden-set corpus + CI golden tests | W3 CRIT-AI1 | 1.5 |
| P3.7 | Pin `gemini-2.0-flash` versioned alias + log `modelId` in analytics | W3 CRIT-AI2 | 0.5 |
| P3.8 | Implement BUT-588 `sessionId` plumb-through across analytics | W3 HIGH-PA1 | 1.0 |

**Phase 3 total: ~11 days.** Closes the architectural debt + LLM observability + analytics dark areas.

### Phase 4 — Migrations + dependencies (Sprint 5-6 — ~7 days)

| # | Action | Source | Days |
|---|---|---|---|
| P4.1 | Migrate `sqlcipher_flutter_libs` → `sqlite3 ^3.x` substrate | W1 CRIT-DEP1 | 3.0 |
| P4.2 | SHA-pin top-blast-radius GitHub Actions | W1 HIGH-DEP8 | 1.0 |
| P4.3 | Add `push: branches: [main]` trigger to `dep-audit.yml` | W1 HIGH-DEP5 | 0.05 |
| P4.4 | Add SHA-256 verification to ONNX model downloads | W1 HIGH-DEP7 | 0.5 |
| P4.5 | Pin 3 most security-critical packages exact (`firebase_app_check`, `freerasp`, `http_certificate_pinning`) | W1 HIGH-DEP6 | 0.05 |
| P4.6 | Move account-deletion entirely server-side (single CF callable) | W1 HIGH-SEC5 | 1.5 |
| P4.7 | Add audit-log entries to GDPR cross-user cascade ops | W1 HIGH-SEC4 | 0.5 |
| P4.8 | Mass-migrate raw `data['x'] as Type` casts to SerializationUtils | W1 HIGH-CQ3 | 1.0 |

**Phase 4 total: ~7.5 days.**

### Phase 5 — UX consistency + UI cleanup (Sprint 7 — ~5 days)

| # | Action | Source | Days |
|---|---|---|---|
| P5.1 | Mass-migrate 34 raw `CircularProgressIndicator` → shared `LoadingIndicator` | W2 HIGH-UX4 | 1.0 |
| P5.2 | Mass-migrate 39 `EdgeInsets.only((left\|right):` → `EdgeInsetsDirectional.only` | W2 HIGH-UX3 | 1.0 |
| P5.3 | Roll out `clampTextScaling` to all top-level scaffolds | W2 HIGH-UX1 | 1.0 |
| P5.4 | Adopt `MediaQuery.viewInsets` in keyboard-aware scrollables | W2 HIGH-UX5 | 0.5 |
| P5.5 | Add locale switcher to settings hub | W2 HIGH-UX6 | 0.5 |
| P5.6 | Fix desktop branding (macOS APP_NAME, Windows lowercase) | W2 HIGH-UX7 | 0.5 |
| P5.7 | Add cooking-mode analytics events (start, step-advance, complete, abandon) | W3 HIGH-PA4 | 1.0 |
| P5.8 | Wire 9 dark social-graph methods + DM events | W3 HIGH-PA10 | 1.5 |
| P5.9 | Add `setUserId` for FirebaseAnalytics + `kDebugMode` guard | W3 HIGH-PA5+6 | 0.05 |
| P5.10 | Various small analytics fixes (cooksLast14Days, recipeFavorited, firstCook, feature_flag_evaluated) | W3 HIGH-PA7+9+11+8 | 0.3 |

**Phase 5 total: ~7 days.**

### Phase 6 — Doc + legal cleanup (Sprint 8 — ~4 days)

| # | Action | Source | Days |
|---|---|---|---|
| P6.1 | Update `code-style.md` 33→131 + auto-update via CI | W4 CRIT-DOC1 | 0.1 |
| P6.2 | Reconcile audit-log retention to single source | W4 CRIT-DOC2 | 0.3 |
| P6.3 | Find-replace Mistral→Vertex in 8 code files | W4 CRIT-DOC3 | 0.05 |
| P6.4 | Update privacy policy: reCAPTCHA, Vision API, on-device ONNX disclosure | W4 HIGH-LEGAL3+7+8 | 1.0 |
| P6.5 | iOS Privacy Manifest health-data type | W4 HIGH-LEGAL7 | 0.05 |
| P6.6 | Add `LICENSE`/`NOTICE`/`SECURITY.md` files | W4 HIGH-LEGAL4 | 0.2 |
| P6.7 | Document encryption export declaration in iOS Info.plist | W4 HIGH-LEGAL2 | 0.05 |
| P6.8 | ToS data-deletion cascade timeline | W4 HIGH-LEGAL5 | 0.1 |
| P6.9 | Privacy review pass (tabulate processors / manifest / models / match) | W4 CC-3 | 1.5 |
| P6.10 | Update setup.sh / setup.ps1 to Flutter 3.35.1 | W4 HIGH-DOC12 | 0.05 |
| P6.11 | Add concurrency block + mutex various dep-audit hardening | W2 HIGH-INFRA9 etc | 0.5 |
| P6.12 | Add 2-3 GCP alert policies + secondary notification channel | W2 HIGH-INFRA8 | 1.0 |

**Phase 6 total: ~5 days.**

### Phase 7 — Pre-monetization scaffolding (deferred until product decides — estimate-only)

When MEMORY.md "no submission yet" lifts:
- Fix iOS subtitle to 30 chars (5 min)
- Capture screenshots (1d)
- Build IAP scaffolding (5–10d)
- Add EU 14-day cooling-off (0.5d)
- Define account-deletion ↔ subscription interaction (0.5d)

**Estimate: 7-12 days when triggered.**

### Total active remediation
- **Phases 1–6: ~41 days traditional.**
- **Vibecoding-realistic: ~13–20 days** (huge mechanical/find-replace/grep share).
- **Phase 7 (deferred): ~10 days** when monetization unlocks.

---

## 3. Strategic context (per MEMORY.md)

The roadmap above respects MEMORY.md decisions:
- **No app-store submission yet** — Phase 7 is deferred. iOS subtitle, screenshots, IAP, EU cooling-off all wait. (Phase 1 P1.4 App Check is still a security fix even pre-submission — keep.)
- **No monetization decisions yet** — Phase 7 IAP + entitlements deferred. Don't build `Family Plan`, `RecipeScalingPro`, etc. before product locks the model.
- **Solo dev workflow: push to main** — solo-dev push amplifies dependency-audit gaps (`dep-audit.yml` no `push:` trigger). Phase 4 P4.3 fixes this.
- **Smart Cooking Mode first, AI Companion post-monetization** — auto-extract step timer + cooking-mode analytics (Phase 5 P5.7) align with this prioritization.

---

## 4. The two synthesis writeups (default vs deep) — reconciliation

Both `2026-05-claude/SYNTHESIS.md` (22 KB) and `2026-05-claude-deep/SYNTHESIS.md` (36 KB) were produced as final consolidated reports per their respective runs. They diverge on key points:

| Topic | Default SYNTHESIS | Deep SYNTHESIS | Master verdict |
|---|---|---|---|
| Overall score | implied 73-78 (default scored every prompt high) | 60 (consistent with sub-prompt scores) | **62** — between default's optimism and deep's slight pessimism on monetization |
| Top CRITICAL count | "10-12" | "23" | **27** (more catches with combined approach) |
| Strongest finding | Cert-pin + GDPR Art-15 (W1 CRIT-SEC2) | Architecture-test brittleness (W1 CRIT-CQ5) | **Cert-pin** for immediate exposure; **arch-test** for highest-leverage fix |
| Weakest dimension | Trust/Safety (default: 80, deep: 60) | Trust/Safety (deep correct) | **Trust/Safety** is real concern — image moderation + brigade-amplifier |
| Adoption-percentage drift | not flagged | flagged at multiple prompts | **Flagged** — propagates aspirational targets across all audits |
| Audit-tooling integrity | not flagged | flagged in Pass 2 | **Flagged + Phase 1 P1.10** |

**The deep synthesis is the better starting point but missed `firebase.json` security headers** (default caught it). The combined master here corrects both.

---

## 5. What this audit can't tell you

Honesty about gaps:

1. **Production telemetry.** This audit reads code statically. Actual user impact (how many users hit the brigade vector? how many recipes fail to parse?) requires production data I don't have.
2. **Performance under load.** Deep flagged `ConversationAutoHealerModule` as a 10k-DAU tripwire based on listener math. Actual breakage point depends on Firestore project plan, regional capacity, and whether you're on Spark/Blaze. Validate with load test before relying on the math.
3. **Legal jurisdiction specifics.** Sweden/EU privacy compliance is the primary legal frame, but specific enforcement priorities of Datainspektionen vary. The privacy policy work in Phase 6 should be reviewed by counsel before publication.
4. **Strategic findings (prompt 10).** Most of monetization analysis is hypothesis territory (deep tagged this well). Don't take "Family Plan opportunity exists because HouseholdService substrate exists" as more than a starting point.
5. **iOS / Android store-submission specifics.** Apple Guideline 1.2 and Play UGC rules shift; per-quarter re-check before submission.

---

## 6. Recommended sequencing for solo dev

Given solo-dev capacity + vibecoding leverage:

**Week 1 (Phase 1):** Stop the bleeding — 3 days at most. Cert-pin, audit-export, App Check, region decision, audit-tooling, friend_requests rename.

**Week 2 (Phase 2):** Architectural locks — broaden architecture-test, fix `ConversationAutoHealerModule`, LRU-wrap caches, image moderation. ~7 days.

**Week 3 (Phase 4):** Sqlcipher migration + dependency hardening. ~7 days.

**Weeks 4-5 (Phases 3+5):** Adoption + observability + UX consistency. ~12 days. Most can run as background-AI work while you focus on product.

**Week 6 (Phase 6):** Doc/legal cleanup pass. ~5 days. Mostly mechanical.

**Weeks 7+:** Phase 7 when monetization product decision lands.

**Total estimated wall-clock for solo founder + AI: ~6 weeks active** (vs 13 weeks at traditional estimates).

---

## 7. The audit-tooling fix (highest-leverage 4 hours)

These changes don't fix code — they fix the audit. **Run these BEFORE the next forensic cycle:**

1. Pre-analysis script path filter: `-not -path "*/site-packages/*" -not -path "*/node_modules/*" -not -path "*/__pycache__/*"`
2. For each `flutter analyze` error, re-verify against current source mtime before propagating
3. Move adoption percentages out of orchestrator-prompt baseline; create `docs/architecture/adoption-status.md`
4. Add `dart_test.yaml` 30s per-test timeout
5. Pre-analysis SUMMARY metadata: include capture-timestamp + file-mtime delta
6. `.claude/hooks/pre-tool-use.sh` snippet: detect `site-packages`/`node_modules`/`__pycache__` resurfacing in `lib/`

Total effort: ~4 hours. Every future audit gets cleaner data. **This should be Sprint 0.**

---

## 8. Final disposition

This synthesis represents the verified, deduplicated, sequenced view of all forensic findings across 12 prompts × 3 runs × 4 waves. Findings here have:
- Three verification layers (deep Pass 2 critic + master re-check + cross-wave consistency)
- Stale claims explicitly stripped (327k LOC, ConsentPurpose, infra_integration_test blame, iOS bundle-id mismatch, etc.)
- Severity calibrated to deep run (default's systematic overscoring corrected)
- Cross-prompt deferrals explicitly resolved
- Sized for vibecoding-realistic effort (parenthetical in each phase)

**Status:**
- ✅ Wave 1 master (10 CRITICALs)
- ✅ Wave 2 master (9 CRITICALs)
- ✅ Wave 3 master (4 CRITICALs)
- ✅ Wave 4 master (4 CRITICALs)
- ✅ **MASTER-SYNTHESIS (this doc) — 27 verified CRITICALs across 4 waves**

**Files in `docs/analysis/runs/`:**
- `MASTER-SYNTHESIS.md` (this doc — final consolidated synthesis)
- `MASTER-wave1.md`, `MASTER-wave2.md`, `MASTER-wave3.md`, `MASTER-wave4.md` — wave-level masters
- `MASTER-wave{1,2,3,4}-NN-*-data.md` — per-prompt verification data files
- `2026-05-claude/`, `2026-05-claude-deep/`, `2026-05-codex/` — original run outputs

**Next step:** decide Phase 1 cutover. Recommend the 4-hour audit-tooling fix first, then start Phase 1 (~3 days). Both can ship in week 1.
