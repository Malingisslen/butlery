# MASTER — Wave 1 — 02 Security & Compliance — Consensus Data

**Purpose:** Consensus / divergence dataset across three forensic runs. Source for the master report (prompt 02). Not the report itself — pure data.

**Inputs:**
- `docs/analysis/runs/2026-05-codex/02-security.md` — Codex (GPT-5), 339 lines.
- `docs/analysis/runs/2026-05-claude/02-security.md` — Claude default, 419 lines.
- `docs/analysis/runs/2026-05-claude-deep/02-security.md` — Claude deep + Pass 2 critic + merger, 607 lines, 96 file:line citations.

**Authoritative baseline:** deep run. Pass-2 critic verified all findings against live source. Other runs override only where they bring unique, source-verifiable evidence.

**Verified facts (treat as ground truth in this dataset):**
- ConsentPurpose analyzer error is stale-cache; runtime path intact (deep verified).
- Total exported callables = **18**, with `enforceAppCheck: true` = **3** (`structureRecipe`, `ocrRecipeImage`, `logWebError`). **15 of 18 missing** App Check (~17% coverage).
- `friend_requests` collection does NOT exist in `firestore.rules`. Actual collection is `social_requests` (`firestore.rules:472`). Functions still reference legacy name in 6 places.

---

## Score Consensus

| Run | Total | OWASP | Auth | Data | Network | Rules | API | CodeProt |
|-----|------:|------:|-----:|-----:|--------:|------:|----:|---------:|
| **deep (auth)** | **62 / 100** | 12/20 | 13/18 | 11/18 | 7/12 | 8/12 | 5/10 | 6/10 |
| codex | 61 / 100 | 12/20 | 13/18 | 13/18 | 7/12 | 5/12 | 6/10 | 5/10 |
| default | 78 / 100 | 15/20 | 14/18 | 14/18 | 11/12 | 10/12 | 6/10 | 8/10 |

**Score divergence:** default scored +16 vs deep, +17 vs codex. Default missed CRIT-1 (`realtime_menus/votes` rule gap), CRIT-2 (`compliance_export_manager` GDPR break), CRIT-3 (App Check coverage), HIGH-1 (cert pinning empty for ALL hosts), HIGH-2 (`friend_requests` legacy bug), all of which are verified-real per deep + Pass-2 source reads. Codex closer to deep on totals but undercounted callable surface (referenced 5 unprotected callables vs deep's verified 15-of-18) and missed `realtime_menus/votes` and `compliance_export_manager` entirely.

**Recommended master score: 62 / 100** (deep, source-verified).

---

## CRITICAL Findings — Consensus Matrix

| Finding | deep | codex | default | Verification |
|---|:---:|:---:|:---:|---|
| **CRIT-1** `realtime_menus/{menuId}/votes/{voteId}` no rules block; feature live via push deep-link | YES (CRIT-1) | NO | NO | VERIFIED — deep grep `votes` against `firestore.rules` returns 0; widget+VM+service+DI+route confirmed live; default-deny at `firestore.rules:1810-1812` |
| **CRIT-2** `compliance_export_manager.exportAuditLogs` permission-denies for all non-admin; catch swallows; codebase admits broken | YES (CRIT-2) | NO | NO | VERIFIED — `compliance_export_manager.dart:42-91`, error swallow `:84-90`, docstring `:11-20`, `firestore.rules:1358` admin-only read, `functions/src/exports/` does not exist |
| **CRIT-3** 15/18 callables miss `enforceAppCheck` | YES (CRIT-3) | YES (H-3, framed as HIGH not CRIT, said "5 unprotected examples") | NO | VERIFIED — deep table at lines 99-117 enumerates all 18 with line refs; only `structureRecipe` (`structure-recipe.ts:70`), `ocrRecipeImage` (`ocr-recipe-image.ts:94`), `logWebError` (`log-web-error.ts:121`) carry the flag |
| **C-1 (codex only)** Forged friendships via `firestore.rules:282-285` cross-user write branch — rated CVSS 9.1 | partial (covered as MED-16 at CVSS 5.5) | YES (C-1) | NO | VERIFIED rule shape — `firestore.rules:282-285` allows write when `request.auth.uid == friendId`. Severity dispute below. |

### Severity dispute on friends rule (codex C-1 vs deep MED-16)

- Both verified the same rule shape (`firestore.rules:282-285`).
- **Codex** rated CRITICAL (CVSS 9.1): attacker walks readable `public_profiles` and inserts as friend in every user's `friends` subcollection; downstream `sendNotification` checks accept the synthetic friendship.
- **Deep** rated MEDIUM (CVSS 5.5, MED-16): same exploit path, but deep argues reverse-friendship cleanup runs on delete and the cross-user read scope makes this "griefing-class" not "data-exfil-class."
- **Reconciled position for master:** the impact is closer to codex's framing — the synthetic friendship doc IS the gate `sendNotification` reads (`send-notification.ts:114-119`), so the rule allows attacker-controlled bypass of the friend-only notification gate. **Promote to HIGH (CVSS 7.4-8.0)** in master. Not CRITICAL because friend-only notifications already over-permission via legacy `friend_requests` query (HIGH-2 / deep) which fails closed; not MEDIUM because the rule alone enables un-gated cross-user writes.

---

## HIGH Findings — Consensus Matrix

| Finding | deep | codex | default | Verification |
|---|:---:|:---:|:---:|---|
| **HIGH-1** Cert pins empty for all 8 hosts | YES (HIGH-1) | YES (H-2) | NO | VERIFIED — `cert_pin_config.dart:34-71`, all 8 host lists are `<String>[]` with `// TODO(BUT-427-ops)` |
| **HIGH-2** `sendNotification` queries non-existent `friend_requests` collection (legacy rename leak) | YES (HIGH-2) | partial (M10 mention at `send-notification.ts:125`, scoped narrower) | NO | VERIFIED — 6 references to `friend_requests` in `functions/src/`: `send-notification.ts:125,130,539,544`; `shared/collections.ts:20`; `cleanup-expired-friend-requests.ts:32`; `admin/reset-user-data.ts:74`. Real collection: `firestore.rules:472` `social_requests`. Codex flagged as M-10 stale, but did not connect to broken pending-friend-request notification flow. |
| **HIGH-3** Third-party API keys in client binary (OCR.space, Google Vision) | YES (HIGH-3) | partial (M-1 SharedPreferences was its #1 medium; binary key extraction not flagged as separate finding) | YES (HIGH-1) | VERIFIED — `ocr_extraction_service.dart:227,236` use `String.fromEnvironment` |
| **HIGH-4** GDPR cross-user cascade ops bypass `PermissionValidationMixin` audit trail | YES (HIGH-4) | NO | NO | VERIFIED — `social_deletion_operations.dart:64,97,156,208,239`; `profile_deletion_operations.dart:65` direct `_firestore` ops with no audit log entries |
| **HIGH-5** Account-deletion `user.delete()` runs BEFORE Firestore tier deletes | YES (HIGH-5) | NO | NO | VERIFIED — `account_deletion_service.dart:142-159` (comment says "FIRST", `await user.delete()` at `:146`, tier-1 begins at `:163`) |
| **H-1 (codex only)** Friend category non-owner can rewrite full `friendUserIds` array | NO | YES (H-1) | NO | VERIFIED — `firestore.rules:311-317` lacks self-add-only constraint. Repository self-add path (`friend_category_repository.dart:113-116`) uses `arrayUnion`, but rule does not enforce that. Rate-limited (`rateLimitWrite('friend_category_member', 5)`) and size-capped (`<=200`), so abuse is bounded; nonetheless real authz drift. **Add to master at MEDIUM** (CVSS 5.0-6.0). |
| **HIGH-2 (default only)** Push-consent revoke handler likely broken at runtime (analyzer error) | refuted | NO | YES (HIGH-2) | DISPROVED by deep critic — `notification_service.dart:643-663` compiles; analyzer error at `flutter-analyze.txt:3` is stale-cache (deep verified the import + same enum reference at `fcm_service.dart:163` not flagged). Default itself flagged the verification gap in its own writeup but kept finding at HIGH. **Demote to LOW or drop in master.** |

---

## MEDIUM Findings — Consensus Matrix (compact)

| Finding | deep | codex | default | Notes |
|---|:---:|:---:|:---:|---|
| Audit-log retention drift (model 365d / service 180d / CF 730d-180d) | MED-3 | NO | MEDIUM-1 | Both verify same call sites |
| `audit_logs` retains userId post-deletion; cascade does not scrub; privacy-policy doc-drift | MED-4 | NO | NO | Deep-only |
| `recipePresence`/`shoppingPresence` no `expiresAt`/displayName length validation | MED-5 | NO | MEDIUM-4 | Same rules cited |
| `pings` broadcast: any auth user reads + ACKs any group's broadcasts | MED-6 | NO | MEDIUM-6 | Same rule lines (830-833, 855-865) |
| `feedback` collection no length/whitelist/rate-limit | MED-7 | NO | MEDIUM-7 | Same `firestore.rules:1668-1674` |
| `notification_history.data` size cap is field-count not byte-size | MED-8 | NO | MEDIUM-8 | Same `firestore.rules:1731` |
| `parsing_correction_repository` + `site_config_repository` bypass repo contract | MED-9 | NO | MEDIUM-3 | Same files |
| `globalRecipeCache` write rule no URL/title shape validation | MED-10 | NO | LOW-2 | Severity dispute: deep MED, default LOW. Deep adds prompt-injection bridge to LLM tier. |
| `group_weekly_menu_plans` membership-desync (participantUserIds vs memberPermissions) | MED-11 | NO | MEDIUM-2 | Same rule lines 691-701 |
| `firebase_menu_voting_repository` 3 of 4 validators return `true`; `_isMenuParticipant` skips `logPermissionCheck` | MED-12 | NO | NO | Deep-only; rolled into CRIT-1 fix |
| Storage `contentType` client-controlled; magic-byte spoofing | MED-13 | NO | NO | Deep-only — `storage.rules:9`, `firebase_storage_repository.dart:259-264` |
| `image/svg+xml` not excluded from `isValidImage()` (XSS via Storage CDN) | MED-14 | NO | NO | Deep-only — `storage.rules:9` |
| Three admin gates with three sources of truth (token.admin / token.role / `admins/{uid}` doc) | MED-15 | NO | NO | Deep-only |
| Friends cross-user write branch: no rate limit, no field validation, no link to accepted social_request | MED-16 | rated CRITICAL by codex (C-1) | NO | Severity dispute — see CRITICAL section above |
| Recipe comment blocking gate bypassed when client omits `recipeOwnerId` | MED-17 | NO | NO | Deep-only — BUT-459 backwards-compat window has elapsed |
| Crashlytics buffers fatal errors before consent gate | MED-2 | NO | NO | Deep-only — `main.dart:212,228-238,295,330` |
| `category_overrides`, `activity_events` collections written by client repos but no `firestore.rules` block | MED-1 | NO | NO | Deep-only — both fail closed in production today |
| **MEDIUM-3 (default only)** `unified_shared_shopping_lists` view-permission can mutate items | NO | NO | YES (MEDIUM-5) | DISPROVED-AS-FRAMED — `firestore.rules:1125-1131` requires `in ['edit','admin']`, view rejected. Default's own writeup admits "rule shape today is correct" — finding is documentation/drift concern, not active vuln. **Demote to LOW/informational.** |

### Codex unique medium — deep-link broad reads (M-3)

- **Codex M-3:** `firestore.rules:1681-1682` allows any authenticated user to read every `deep_links/{linkId}` document. Adds drift risk + privacy concern (creator UID + longUrl exposed).
- **Verification:** confirmed at `firestore.rules:1680-1684`. `allow read: if isAuthenticated();` on `deep_links/{linkId}`. Deep did not flag.
- **Master treatment:** **Add as LOW-MEDIUM**. The longUrl is shareable by design, but creator-UID exposure across all auth users is over-broad. ~2h to scope read to creator + shared participants.

### Codex unique medium — HTTP recipe import accepts both http and https (M-4)

- **Codex M-4:** `lib/services/import/fetchers/http_content_fetcher.dart:16` — `_allowedSchemes = {'http', 'https'}`. Validation at `:90-93`.
- **Verification:** VERIFIED. Line 16 reads `static const _allowedSchemes = {'http', 'https'};`. Both schemes allowed.
- **Caveat:** mitigated by SSRF guard at `isBlockedHost` (lines 32-79 — blocks RFC1918, localhost, link-local, IPv4-mapped IPv6) and 5MB size cap (`:15`).
- **Master treatment:** **Add as LOW**. Plaintext recipe-page bodies on hostile networks can be tampered (parser poisoning), but no auth tokens cross plaintext and no PII leaks. ~30min fix.

### Codex unique medium — iOS bundle-id mismatch (M-5)

- **Codex M-5:** `ios/Runner.xcodeproj/project.pbxproj:377` vs `lib/firebase_options.dart:58`.
- **Verification:** **DISPROVED.** Both files agree on `se.butlery.app`:
  - `firebase_options.dart:58` — `iosBundleId: 'se.butlery.app'`
  - `pbxproj:377` — `PRODUCT_BUNDLE_IDENTIFIER = se.butlery.app`
  - Test target uses `se.butlery.app.RunnerTests` (`pbxproj:393,410,425`) but that's expected test-target suffix.
- **Master treatment:** **Drop.**

---

## Disproved by Deep Critic

| Claim | Source | Reality |
|---|---|---|
| Push-consent revoke handler is broken at runtime (HIGH severity) | default HIGH-2 | Stale analyzer cache. `notification_service.dart:643-663` compiles. Same enum reference at `fcm_service.dart:163` not flagged by analyzer. Default's own writeup admits the verification gap. |
| App Check coverage is 5/15 callables | Pass-2 sibling that deep merger overrode (referenced in deep's verification summary) | Reality: 3/18. Sibling under-counted callable surface. |
| App Check coverage is 12/15 callables | Pass-1 investigator that deep merger reconciled | Reality: 3/18. Pass-1 closer than sibling but still off — only 3 carry `enforceAppCheck: true`. |
| `unified_shared_shopping_lists` view-permission member can downgrade items | default MEDIUM-5 | Default's own writeup acknowledges "rule shape today is correct"; rule at `firestore.rules:1125-1131` correctly requires `['edit','admin']`. Concern is documentation drift, not active vuln. |
| iOS bundle-id mismatch between firebase_options and Xcode project | codex M-5 | Both `se.butlery.app`. No mismatch. |

---

## Unique to One Run (verified)

### Unique to deep (verified by Pass 2 source reads)

- **CRIT-1** `realtime_menus/{menuId}/votes/{voteId}` rule gap (verified — feature liveness chain: widget → VM → service → DI → push deep-link route at `notification_deep_link_router.dart:49`)
- **CRIT-2** `compliance_export_manager` GDPR Art-15 audit-log break (verified — codebase docstring at `:11-20` admits broken)
- **HIGH-4** GDPR cross-user cascade missing audit logs
- **HIGH-5** account-deletion auth-context race
- **MED-1** `category_overrides` + `activity_events` no rule block
- **MED-2** Crashlytics pre-consent buffer
- **MED-4** audit-logs userId scrub gap on `on-user-deleted`
- **MED-12** menu_voting validators return literal `true`
- **MED-13** Storage MIME spoofing (client-side `contentType`)
- **MED-14** SVG XSS via Storage CDN
- **MED-15** three admin-gate sources of truth
- **MED-17** recipe comment blocking gate bypass via missing `recipeOwnerId`

### Unique to codex (verified)

- **C-1** forged-friendship cross-user write branch reframed as CRITICAL (verified rule; severity dispute reconciled to HIGH in master, see above)
- **H-1** friend category non-owner full-array rewrite (verified — rule at `firestore.rules:311-317` lacks self-add-only constraint; mitigated by rate-limit + 200-cap; **add to master as MEDIUM**)
- **M-3** `deep_links/{linkId}` broad authenticated-user read (verified at `firestore.rules:1680-1684`; **add to master as LOW-MEDIUM**)
- **M-4** HTTP scheme allowed in recipe import fetcher (verified at `http_content_fetcher.dart:16`; **add to master as LOW**)
- **iOS COPY_PHASE_STRIP = NO** (verified at `ios/Runner.xcodeproj/project.pbxproj:341, 462, 519` — three configs all `NO`)
- **iOS CI release omits Dart `--obfuscate` and `--split-debug-info`** (verified at `.github/workflows/build-validation.yml:229` — `flutter build ipa --release --no-codesign --dart-define-from-file=.env --export-options-plist=ios/exportOptions.plist` — no obfuscate; Android counterpart at line 194 DOES use `--obfuscate --split-debug-info=build/debug-info`. **Add to master as MEDIUM** — symbol parity gap between platforms.)

### Unique to default (verified)

- **MEDIUM-2 / MEDIUM-4 / MEDIUM-6 / MEDIUM-7 / MEDIUM-8** — all overlap with deep MEDIUMs (membership-desync, presence size, pings broadcast, feedback no-cap, notification_history field-count cap). No content unique enough to warrant separate listing.
- **Informational — `PermissionValidationMixin` "20% adoption" claim is misleading; real coverage near-complete via `BaseFirebaseRepository`** (verified independently by deep at MED-9 / drift section)
- **Informational — `cleartextTrafficPermitted` config is correct** (verified at `android/app/src/main/res/xml/network_security_config.xml`; deep didn't enumerate but agrees in M1 Pass)
- **Informational — Deep-link `https://butlery.app` has `autoVerify="true"` for App Links** (no contradicting evidence; not contested)
- **GDPR Art. 15 score 9/10** (default rated 9, deep rated 6 — diverged because default did NOT detect `compliance_export_manager` audit-log break; deep is correct, score 6 stands)

---

## Disputed Numbers

| Number | deep | codex | default | Verified truth | Master uses |
|---|:---:|:---:|:---:|---|:---:|
| Total callables | 18 | implicitly ≤6 (only listed examples) | not enumerated | 18 verified by deep file-by-file | **18** |
| Callables with `enforceAppCheck: true` | 3 | not counted | not counted | 3 verified | **3** |
| App Check coverage % | ~17% (3/18) | not stated | implicitly accepts gap | 16.7% | **~17%** |
| Cert-pinning host count | 8 hosts (all empty) | "host pin lists are TODO/empty" (count not stated) | not flagged | 8 verified by reading `cert_pin_config.dart:34-71` | **8 (all empty)** |
| Audit-log retention model | 365d | not stated | 365d | `audit_log.dart:88-89` | **365d** |
| Audit-log retention service | 180d | not stated | 180d | `account_deletion_service.dart:50` | **180d** |
| Audit-log retention CF (consent) | 730d | not stated | 24mo (≈730d) | `purge-expired.ts:26` | **730d** |
| Audit-log retention CF (general) | 180d | not stated | 6mo (≈180d) | `purge-expired.ts:29` | **180d** |
| Firestore rules size | 1813 lines / 90 match blocks | not stated | "1788 lines / 95 match rules" | deep: 1813/90; default: 1788/95 — measurement drift; reconcile to deep | **1813 / 90** |
| `friend_requests` references in `functions/src/` | 6 | 1 (only `send-notification.ts:125`) | 0 | deep enumeration: `send-notification.ts:125,130,539,544` + `shared/collections.ts:20` + `cleanup-expired-friend-requests.ts:32` + `admin/reset-user-data.ts:74` (= 7 occurrences across 4 files; deep's "6" line count + 1 file in admin/reset is consistent with 6 query/constant uses + 1 admin path) | **6+ (across 4 files)** |
| `match` blocks tested by `*-rules.test.ts` files | 14-16 / 90 (~16-18%) | not stated | not stated | deep enumerated 10 test files vs 90 match blocks | **~16-18%** |
| Total file:line citations in run | 96 (deep verified) | ~80 inferred | ~70 inferred | deep highest-density | **96 (deep)** |

---

## Cross-Prompt Boundaries (deep deferred to other prompts)

| Topic | Deferred to | Reason |
|---|---|---|
| Dependency CVEs / supply chain / licenses | **Prompt 05** | Codex stated explicitly `02-codex.md:37`. Deep stated explicitly `02-claude-deep.md:5`. |
| AI output validation / prompt-injection content scanning | **Prompt 07** | Deep MED-10 (cache poisoning bridge) and LOW-9 (LLM regex panel naive) both defer prompt-injection class to 07. |
| AI / Function timeouts and circuit breakers | **Prompt 04** | Deep header `:5`. |
| SDK consent race / Privacy manifest / ATT prompt / UGC moderation | **Prompt 09** | Deep header `:5`. UGC moderation specifically — cook_snaps/messages already enforce, broader UGC moderation is a Prompt 09 concern. |
| iOS encryption export declaration (App Store ITSAppUsesNonExemptEncryption) | **Prompt 11** | Deep header `:5`. Privacy-policy text alignment for MED-4 also defers here. |
| Disaster Recovery / backup posture | **Prompt 03** | Deep header `:5`. Codex test-hang note also `:38`. |
| Test infrastructure hang | **Prompt 03** | Codex `:38` (`flutter-test.txt:31525-31529`). |
| Doc/comment drift (Stockholm references / region docs) | **Prompt 12** | Default informational + deep "Drift / Informational" both name 12. |
| CSP / web headers / `web/index.html` security headers | **Prompt 11** | Deep "What's Missing" #15 explicitly defers if web is out of scope. |

---

## Pre-existing Known Context (resolved on disk per task brief)

- **ConsentPurpose runtime regression:** RESOLVED on disk per task baseline. Default's HIGH-2 was misled by stale `flutter-analyze.txt`. Demote.
- **`friend_requests` collection:** does NOT exist in `firestore.rules`. Actual collection is `social_requests`. Default did not surface this; codex flagged narrowly (1 reference, M-10 medium); deep enumerated all 6 references and promoted to HIGH-2.

---

## Master Severity Allocation (proposed)

Based on the consensus + verification work above, the master report should carry:

- **CRITICAL (3):** CRIT-1 (`realtime_menus/votes` rule gap), CRIT-2 (`compliance_export_manager` GDPR Art-15 break), CRIT-3 (15/18 callables miss App Check).
- **HIGH (6):** HIGH-1 (cert pins empty for 8 hosts), HIGH-2 (`friend_requests` legacy bug), HIGH-3 (binary OCR/Vision keys), HIGH-4 (cross-user GDPR cascade no audit), HIGH-5 (account-deletion auth-context race), **NEW-HIGH** (friends cross-user write branch promoted from deep MED-16 / codex C-1 — synthetic friendship enables notification-gate bypass, CVSS 7.4-8.0).
- **MEDIUM (~17):** all deep MEDs except those promoted; plus codex H-1 (friend category array rewrite, demoted to MEDIUM); plus iOS obfuscation parity gap (codex unique).
- **LOW (~10-12):** deep LOWs + codex M-3 (deep_links broad read) + codex M-4 (HTTP scheme allowed) + default-only Crashlytics-stale claim (informational, not finding).
- **DISPROVED / DROPPED:** default HIGH-2 (consent revoke runtime broken), default MEDIUM-5 (shopping-list view downgrade), codex M-5 (iOS bundle-id mismatch).

---

## Citation density (master targets)

- Deep ran with 96 file:line citations. Master should preserve all 96 + add the codex-verified additions (deep-link rule, http_content_fetcher scheme set, ios pbxproj COPY_PHASE_STRIP and bundle-id confirmation, build-validation.yml iOS line 229 vs Android line 194). Target ≥110 citations in master.

---

End of consensus dataset.
