# firebase-backend-security — archived patterns (relocated 2026-07-24, BUT knowledge-diet pass). Append-only historical record: every dated incident entry that used to live in the main knowledge file, verbatim, in original order. The main file now carries only a distilled Principles section (Step 0 read); consult this file for exact code excerpts, full narrative, and BUT ticket IDs behind any principle.

### 2026-06-11 — ONNX model-integrity gate is fail-close; cache path is trusted by design (BUT-792/876/877)
`RemoteModelLoader.verifyModelDownload` returns true ONLY on registry hash match — empty registry and missing-version entry both refuse (BUT-877 superseded the BUT-876 transitional soft-allow). **Ordering invariant to re-check on any edit:** in `ner_model_manager.dart`/`line_classifier_model_manager.dart` the verify call sits BEFORE `getCacheDir()`/any `.tmp` write/`_cachedModelPath` assignment — refused bytes never touch disk or the ONNX runtime. **Cache path (`_tryLoadCached`) does NOT re-hash** — deliberate: threat model is Storage-side substitution/MITM, not local-disk tamper (= device compromise, out of scope); zero released users means no installed base carries unverified caches from the BUT-876 soft-allow window. If a soft-allow window ever overlaps real users, a one-time cache re-verify becomes required. **Publish-order footgun:** the registry entry must ship in the client release BEFORE bumping Storage `latest_version.txt`, or all clients refuse the new version (now documented in `_expected_model_hashes.dart`). `ModelIntegrityResult.ok` is true even when `unverified=true` — pure-data result carries no policy; callers must check `unverified` first. `RemoteWeightLoader` (CRF JSON weights) has NO integrity check — accepted: pure-Dart Viterbi decode of JSON, no native deserialization of attacker-controlled bytes; revisit if weights gain code-like power.

### 2026-04-25 — initial seed
Seeded from CLAUDE.md (rules #3, data-source, cost), the agent description, and MEMORY.md (batch limit). Record genuinely new permission/GDPR/query patterns or surprising Firebase behavior — not re-derivations of the reference sections above.

### 2026-04-25 — iOS PrivacyInfo.xcprivacy required-reason codes (BUT-587/596/603)
Apple required-reason API codes mapped to SDK usage: **FileTimestamp** `C617.1` (display timestamps — image_picker EXIF) / `3B52.1` (cache eviction mtimes). **UserDefaults** `CA92.1` (freerasp + flutter_inappwebview cookie store). **DiskSpace** `E174.1` (optimise user-file size — Firestore LRU, Crashlytics); `85F4.1` (display) not used. **SystemBootTime** `35F9.1` (telemetry timing — Firebase Performance/Analytics). Decision rule: declare reasons at app level **defensively** even when a pod ships its own manifest (Apple auto-merges; explicit is clearer) — but NEVER declare a reason with no genuine usage (false declaration is itself a review risk). `NSPrivacyCollectedDataTypeUserID` for Auth UID: `Linked=true`, `Tracking=false`, purpose `AppFunctionality` only (never `Analytics`, even though analytics carry the UID — Apple separates "collected" from "purpose"). CocoaPods on Windows: `ios/Pods/`+`Podfile.lock` are macOS-only; audit from `pubspec.yaml` versions, mark unverifiable pods UNVERIFIED_LOCAL with app-level fallback, verify on macOS CI.

### 2026-04-25 — store-submission rating defense triad (BUT-624/590/416)
The **UGC + messaging + 24-h moderation SLA** triad keeps Butlery at Apple 12+ / Play Teen (not 17+/Mature). Critical findings when reviewing moderation/UGC changes: removing a report entry-point; opening DM to non-friends; lowering/silencing the report→admin path; removing the age gate (`birthYear ≤ 2013`); adding location/geo to user-to-user surfaces (presence is online/offline only). Every UGC surface (recipes/comments/ratings/group messages/friend pings) needs a report entry-point landing in `reports/` + admin review. Messaging confined to friend-graph + group membership. See `docs/ops/age-rating-runbook.md` §5.11/§6 (re-submission triggers) and `moderation-runbook.md` (the 24-h SLA is the written Apple G1.2 / Play UGC defense). Reviewer-demo seeding: Apple/Play reject empty social apps (G2.1) — seed contract in `docs/ops/app-review-demo.md` (2 reviewer accts, 2 pre-accepted friends, 1 Demo Family group, 3 comments, 1 rating, 1 benign report). Script `functions/src/admin/seed-reviewer-data.ts` not yet built; **temporary admin grant must be revoked within 7 days** (leaked admin = data-loss vector).

### 2026-04-26 — Report/moderation: contentType is a STRING; admin-delete needs resolver+rule together (BUT-511/728)
`ReportContentDialog.show(contentType: String)` — NOT an enum. The two `enum ContentType` in the codebase are unrelated to reports; don't wire them through. Allowed values documented on `ContentReport.contentType` comment: `recipe|comment|message|profile|shopping_list|cook_snap|rating|group`. Firestore `match /reports/{id}` create rule whitelists no contentType (any string passes); the **content-side delete rule** is what matters. **Admin-delete works only when BOTH hold: (1) `ReportService._resolveContentRef` has a case for the contentType, AND (2) the target collection's rule has `allow read, delete: if isAdmin();`.** A rule without resolver = dead code; resolver without rule = permission-denied crash for the moderator — they MUST land together. UI rule: never show "Report" to the content owner (hide if `currentUserId == ownerId`/`member.uid == currentUserId`). For `group`, content lives at `users/{ownerId}/friend_categories/{categoryId}` (needs both `report.contentOwnerId` and `report.contentId`). Test `isAdmin()` rules by seeding `/admins/{uid}` via `withSecurityRulesDisabled` in setUpAll (the collection is rules-locked); admin context is just `env.authenticatedContext(adminUid)`.

### 2026-04-26 — BUT-728 closed the moderation coverage matrix; cook_snaps prod gap (Critical)
Added: `profile`→`public_profiles/{uid}` (NOT private `users/{uid}` — that holds settings/consent/rate_limit; moderation must not nuke private GDPR data); `shopping_list`→`unified_shared_shopping_lists` only (private `users/{uid}/unified_shopping_lists` are never visible so cannot be reported); `cook_snaps` got a **brand-new full rule block** — it had NONE, so default-deny `match /{document=**}` was silently catching every write (`firebase_cook_snap_repository.dart` writes directly via `BaseFirebaseRepository.create()` → no CF intermediary), meaning cook-snap creation was likely silently failing in prod. **Rules pattern for collections written via `BaseFirebaseRepository` (full-doc `set()`):** create checks `request.auth.uid == request.resource.data.userId` + `hasRequiredFields([...non-nullable toFirestore fields only...])`; update pins BOTH `resource.data.userId` AND `request.resource.data.userId` to auth.uid (blocks userId-switch even on full rewrite); delete checks `resource.data.userId`. Mirror model-level caps server-side (e.g. CookSnap caption ≤200 via `get('caption','').size() <= 200` null-tolerant) as defense in depth.

### 2026-04-26 — Presence: Firestore needs TTL, RTDB self-clears (BUT-477)
Recipe presence (`recipePresence/{recipeId}/activeUsers/{userId}`) and shopping presence (`shoppingPresence/{listId}/activeUsers/{userId}`) are **Firestore** with per-doc `expiresAt` + TTL policy; cooking session (`cooking_sessions/{groupId}/{userId}`) is **RTDB** with `onDisconnect().remove()` (self-clears, no cascade needed — device disconnected by deletion time). Collection-name constants are camelCase in `firestore_collections.dart` despite snake_case in docs. **Client-side TTL pattern:** write `expiresAt = Timestamp.fromDate(now+60s)` on every write/heartbeat (NOT `serverTimestamp()` — avoids a compare-read); refresh at half-TTL (30s) so one miss doesn't flicker; on inactive set `expiresAt=now`; filter `expiresAt<now` in-memory (small row count); legacy rows (no field) optimistically pass and rely on the server sweeper. **TTL policy is NOT in `firestore.indexes.json`** — separate admin API: `gcloud firestore fields ttls update <field> --collection-group=<col> --enable-ttl` (documented in `docs/ops/presence-ttl-runbook.md`). TTL deletes are read-quota-free but count against delete quota; first sweep can take 24h. **GDPR cascade:** presence rows carry `userId/displayName/avatarUrl` (linked PII) — Art-17 can't wait for TTL; `on-user-deleted.ts` does `collectionGroup('activeUsers').where('userId','==',uid)` batched delete (one query covers both surfaces, shared subcollection name) — requires the collection-group index on `activeUsers.userId`. **Test-seam pattern (reused widely):** `cleanupPresenceRows(uid)` → `cleanupPresenceRowsWithDb(db,uid)` (exported With-Db variant; tests inject a stub db; prod uses module-level `admin.firestore()`). For pure data-manipulation logic prefer a narrow in-memory FakeFirestore stub (no emulator) over `@firebase/rules-unit-testing`; emulator is reserved for actual rule enforcement. Module-level `admin.firestore()` requires `admin.initializeApp({projectId})` early or import-time `no-app` errors fire.

### 2026-04-26 — firebase_crashlytics has NO web SDK (BUT-449)
`firebase_crashlytics ^5.x` ships only android/ios/macos — no `web/`. `kIsWeb` branches calling `recordError` silently no-op. Web error-tracking pattern instead: callable CF `logWebError` (AppCheck + rate-limited) re-emits as structured Cloud Logging; client `WebErrorReporter` installed only when `kIsWeb && hasConsent && !kDebugMode` (mirrors native consent gate); chain both `FlutterError.onError` and `PlatformDispatcher.instance.onError`, preserving prior handlers; scrub every text field via `pii_scrubber.dart` client-side, re-scrub server-side and DROP when redaction ratio >50% (mirrors `log-parse-correction.ts`). Chose callable over Sentry to reuse existing infra (no new heavy dep/secrets/cost line).

### 2026-04-26 — LLM kill-switch dual-control + system/config fail-modes (BUT-439)
Two layered gates, both fail-open on missing config (resilience > strict-deny): **server-authoritative** `system/config.aiEnabled` (master — kills every Vertex call) + `system/config.llmParserEnabled` (per-feature — kills only `structureRecipe`/OCR-text-retry, leaves OCR vision live), latency <1min; **client UX shortcut** Remote Config `ai_enabled`/`llm_parser_enabled`, up to 12h. Gates live at `runStructureRecipe` entry (checks both) and `runOcrRecipeImage` (`aiEnabled` only). **Test-seam pattern:** `runStructureRecipe(req, authUidHash, deps?)` with `deps?.loadKillSwitch` injectable — DON'T stub `admin.firestore` directly (it's a getter, `Object.defineProperty` workarounds are racy across tests). Per-user cap already covered by `rate_limiter.ts` token bucket (daily ceiling implicit). **Fail-open trade-off:** Firestore doc missing → AI on (first-day deploy shouldn't block); Firestore unreachable mid-call → outer catch → `internal` HttpsError so the USER sees an error (fail-closed for the user, not silent bypass). Runbook: `docs/ops/llm-kill-switch-runbook.md`.

### 2026-04-27 — Live watchers must stay bounded; cursor-paginate older pages (BUT-484)
`watchRecipes`/`subscribeToUserRecipes` previously `.limit(500)` silently dropped recipes #501+. New default-100 live page + `loadMoreRecipes(userId, afterUpdatedAt, afterRecipeId, pageSize)` cursor. **Use a doc-cursor (`startAfterDocument`), not value-cursor:** bulk imports write the same `serverTimestamp()` to many docs, so value `startAfter([Timestamp])` would miss/double-emit tied siblings; `startAfterDocument` is the only race-safe disambiguator when order-by ties are possible (keep value-cursor fallback for when the boundary doc was deleted between pages — caller dedupes by id). Don't remove the live limit "since pagination exists": live listener cost scales with pageSize per snapshot delta; an unbounded watch on 5000 recipes costs 5000 reads on attach. Pattern: watcher `.orderBy(f,desc).limit(pageSize).snapshots()`; pager `.orderBy(f,desc).startAfterDocument(b).limit(pageSize).get()`. Named-optional param with default = non-breaking interface change.

### 2026-05-04 — every `.snapshots()` in repositories must end in `.limit(N)` (BUT-478, ext of BUT-484)
**Rule: every `.snapshots()` chain in `lib/repositories/` must end in `.limit(N)` as defence-in-depth, even for "obviously small" collections** — nothing in code/rules caps how many docs a writer with rule access (e.g. shared-group members) can produce; a snapshots() listener pays full cost on every change. Sizing: per-user surface `.limit(100)` (real <20); per-group `.limit(200)` (real <30 members); cross-user collection-group `.limit(200-500)`; per-thread (chat) → cursor-paginate, don't constant-limit. NOT a substitute for pagination (if the cap is reachable in normal use, paginate) and NOT a permission check (rules still own who-can-read). Review heuristic: find `.snapshots()`, walk backwards; no `.limit()` = finding (High if any non-current-user writer, else Medium). Don't gate on "is it small now" — bound the worst case.

### 2026-07-18 — New user-data collection `tag_overrides_log` (BUT-1473) ships without a rule OR a deletion cascade
`TagOverridesLogRepository` writes a top-level `tag_overrides_log` collection (fields: `userId`, `recipeId`, `type`, `tag`, `direction`, `triggeringIngredients`, `timestamp`) fire-and-forget, deliberately bypassing `BaseFirebaseRepository`/`PermissionValidationMixin` (same accepted pattern as `ParsingCorrectionRepository`, BUT-886 — every write is the caller's own data, `userId==auth.uid`). Two gaps found at review: (1) **No `firestore.rules` branch exists for `tag_overrides_log`** — so every write currently default-denies and is swallowed; the whole learning-loop capture is INERT in prod until the rule lands. The repo doc-comment acknowledges this as a "follow-up." Because repo permissions and rules must land in lockstep, this is a real ship-incomplete condition, not just cleanup. (2) **`account-deletion-cascade.ts` does NOT delete `tag_overrides_log`** — it is a top-level userId-keyed collection (linked PII), analogous to `recipe_ratings`/`notification_history`/`family_ratings` which ARE in the cascade. Add `db.collection("tag_overrides_log").where("userId","==",uid)` batched delete. No TTL policy exists either (unlike the accepted `parse_events` 30-day residual, BUT-1570), so once the rule ships these docs would persist forever = Art. 17 gap. The rule + the cascade entry must ship together with the first real write. Also: the log's `userId` is sourced from the service's `editedBy` param (not `permissionService.currentUserId` directly) — realtime callers pass the uid to `editedBy`, so it holds today, but any future caller passing a display name would produce rule-denied writes. `applyAllergenOverride` currently has NO production caller (only tests), so the capture path is unreachable from the app as shipped.

### 2026-07-18 — `tag_overrides_log` (BUT-1473): both prior gaps CLOSED — COMMIT-READY (supersedes the earlier same-day entry)
The salvage-batch diff resolves both gaps flagged above. (1) The `firestore.rules` branch now exists (just above `parse_corrections_v2`), an EXACT structural mirror of `parsing_corrections` (line 2022): read = own (`request.auth.uid == resource.data.userId`) or `isAdmin()`; create = `request.auth.uid == request.resource.data.userId` + `hasRequiredFields(['id','userId','recipeId','type','tag','direction','timestamp'])`; update = `if false` (immutable append-only); delete = own only (Art. 17). Cross-user poisoning is blocked at create (forged userId ≠ auth.uid → deny). Cross-user clobber is blocked too: a `set()` on an existing foreign `entryId` maps to `update` in rules → `if false`; a `set()` with a foreign userId is a create → userId mismatch deny. Read/delete are own-only. Doc-ID is arbitrary (`entry.id`) but ownership keys on the `userId` FIELD, not the doc ID, so an attacker-chosen ID grants nothing. (2) `account-deletion-cascade.ts` now has `deleteTagOverridesLog` (`.collection("tag_overrides_log").where("userId","==",uid)` batched delete) wired into `request-account-deletion.ts` L193 — not orphaned PII, no TTL needed. Model `toFirestore` emits all 7 required fields plus `triggeringIngredients` (correctly NOT required — may be empty). Repo is the accepted BUT-886 own-data bypass (do not flag). Verdict was COMMIT-READY.

### 2026-07-18 — Minor group-safety CF (BUT-1626/674): the create-trigger removal is INCOMPLETE vs the app's own `removeParticipant`
`enforceGroupMinorMembership` (`functions/src/messaging/enforce-group-minor-membership.ts`) fires on `conversations/{id}` create, and for a group (>2) removes any minor added by a non-friend creator (checked against `users/{minor}/friends/{creatorId}`, same directional doc the 1:1 `passesMinorDmGate` rule uses — verified bidirectional friendship makes this correct). Core `computeMinorsToRemove` is pure + unit-tested and fail-safe (unknown `metadata.creatorId` ⇒ remove all minors; but new group creates always carry it via `Conversation.group`, so that branch only fires for tampered clients). **The safety goal (cut message access) IS met** — message reads key off the top-level `conversations/{id}.participantIds`, which the CF rewrites; the update rule makes participantIds immutable so a create-trigger suffices. **But the removal is not a full mirror of the app's `removeParticipant` (`conversation_participant_module.dart:152`), which deletes BOTH the membership mirror AND `conversations/{id}/participants/{uid}`.** The CF deletes only the membership mirror + inline `participant*` maps, leaving the `participants/{minorUid}` subcollection doc stale (`enable_subcollection_participants` defaults TRUE) → group member-list UI still shows the removed minor. And the collapse-to-<2 path (`snap.ref.delete()`) orphans the REMAINING member's `conversation_memberships/{convId}` mirror + participants subcollection + top-level `messages` → a ghost conversation in their list. Both are Medium data-consistency gaps, NOT access holes. Pattern lesson: a server-side participant-removal CF must delete every mirror the client's own removal path touches (grep the repo's `removeParticipant`), plus clean up the remaining side on a collapse-delete.

### 2026-07-18 — Minor `public_profiles.isSearchable` is NOW rules-enforced (BUT-1626) — supersedes the "client-side-only" note below
The immediately-following entry's KNOW-point (1) — "`firestore.rules` deliberately still ALLOWS a minor to write `isSearchable:true`" — is SUPERSEDED. `firestore.rules` now hard-denies it: helper `accountIsMinor(userId)` (`exists`+`get('isMinor',false)==true` on `users/{uid}`) gates both the `public_profiles` create and update. Cost is minimized by short-circuit ordering — the `get()` fires ONLY when a write actually SETS `isSearchable:true` (create with false, or an update whose diff doesn't touch `isSearchable`, or sets it false, all skip the read). Accepted residual still noted in the rule comment: a minor with a LEGACY `isSearchable:true` can still edit other fields (the update gate keys on the diff, not the stored value) so a pre-existing true value isn't force-corrected by the rule — client `toFirestore` derivation is what flips it back on the next full save. The legitimate minor opt-in path writes via a trusted CF (admin SDK bypasses rules). Rule-behavior proof belongs to `firestore-rules-tester`; `age-gate-rules.test.ts` added 5 client-level assertions (PP1–PP5).

### 2026-07-18 — Minor search-suppression (BUT-1454/674): the `toFirestore` derivation is a real single chokepoint, but enforcement is client-side-only by design
`UserProfile.toFirestore` (public_profiles serializer) derives `'isSearchable': isMinor ? false : isSearchable`. Verified this IS the only path that writes `isSearchable` to `public_profiles`: every other public_profiles write is a field-scoped `.update()` touching only `friendsCount`/`publicRecipeCount`/`isOnline`/`lastActiveAt` (`firebase_user_repository` updateProfileStats/updateOnlineStatus/increment*, `friend_relationship_repository` friendsCount transactions) — none touch `isSearchable`; the friend/user repos delegate their `toFirestore(entity)` to `UserProfile.toFirestore`, and `toFirestoreEditable` is `toFirestore` minus friendsCount/isHidden/hiddenAt/birthYear (still derives isSearchable). **`isMinor` is never emitted to a client-writable Firestore doc:** `toFirestore` (public) and `toPrivateSettings` (settings sub-doc) both OMIT it; only `toJson` carries `'isMinor'` (line 490) and `toJson` has NO Firestore write consumer (offline cache / export only). The CF mirrors `isMinor` into `users/{uid}/settings/preferences`; `firebase_user_repository` re-hydrates it on profile load (`s['isMinor'] ?? false`) so post-onboarding saves in a fresh session keep deriving false — no permanent-searchable regression. **Two things to KNOW (neither blocks this diff):** (1) `firestore.rules` deliberately still ALLOWS a minor to write `isSearchable:true` (the `age-gate-rules.test.ts` note: "a minor may still flip isSearchable ... Q1 discovery opt-in" while isMinor unchanged) — so suppression is CLIENT-side defense only; a tampered client bypasses it. Owned by firestore.rules/firestore-rules-tester, not the model. (2) Accepted residual (BUT-674 phasing) is initial profile creation (`user_service.dart` ~L206, `isSearchable: isSearchable ?? true`, isMinor defaulting false) → discoverable until onboarding completion stamps isMinor; an ABANDONED onboarding leaves the public doc stale-searchable even though the CF already set isMinor server-side (public isSearchable only re-derives on the next profile SAVE). That is the outer edge of the stated residual, deliberately deferred — do not block on it. The `completeOnboardingWithPreferences(isMinor:)` OR-with-current-profile never downgrades a server-set flag.

### 2026-07-14 — Ingredient property vocabulary is a THREE-way lockstep; dup detection belongs at sync-time (BUT-1498)
The ingredient-property vocabulary is hand-maintained in three places that must agree: `docs/tagging/data/Butlery_Ingredients_PROPERTIES.csv` (Sheet mirror, doc-only — no code reads it; `IngredientRow` has no such columns), `functions/src/admin/sync-ingredients-core.ts` `VALID_PROPERTIES` (data-sync gate, unions `ALLERGEN_BLOCK_PROPERTIES`), and `lib/services/tagging/config/property_registry.dart` `validProperties` (Dart config gate). The lockstep test `test/unit/services/tagging/phases/tag_phase1_seafood_safety_test.dart` (group "property-vocabulary lockstep") pins the allowed divergence exactly via `knownDartOnly`/`knownTsOnly` — it compares ONLY Dart vs TS (not the CSV), so a CSV edit alone can't fail it. BUT-1498 retired phantom `wheat` (rejected by the TS gate, so no ingredient could carry it; cereal-gluten is `contains-gluten`) and added `shellfish` (meat-detail umbrella the Sheet+TS accept). After this change the only pinned diffs are Dart-only `raw-safe` and TS-only `processed`. When touching any property name, edit all three copies AND update the two known-sets, or the lockstep test fails.
**Placement note (cost):** the new `_indexIngredientKey` collision logger in `firebase_ingredient_repository.dart` detects duplicate name/alias→id mappings, but it fires **client-side on every cache load** (hourly TTL refresh × every device). The TS sync gate (`sync-ingredients-core.ts`) does NO duplicate-name detection today — the natural once/server-side place to catch a Sheet duplicate. The client log is a fine interim diagnostic (bounded to actual duplicates, last-writer-wins unchanged), but the durable fix is a dup gate at sync time. `FirebaseIngredientRepository` deliberately does NOT follow the `repositories/CLAUDE.md` `BaseFirebaseRepository`+4-permission-methods contract: it's read-only global admin-managed reference data (no user data, no permission decisions), one-shot `.get()` with a TTL cache; the `PermissionValidationMixin` requirement is N/A here. Don't file a "missing permission mixin" Critical against it.

### 2026-07-18 — Minor search-suppression chokepoint + two BUT-1454/674 age-gate integrity gaps
BUT-1454 wires default-private search-suppression for compliant 15–17-year-olds. Confirmed-correct wiring (do NOT re-flag): `verifySignupAge` CF now returns `isMinor` in its response → `AgeVerificationService.verifyAge` surfaces it as `AgeVerificationResult` → `OnboardingViewModel` captures `_isMinor` on both the gate path and the belt path → `completeOnboardingWithPreferences(isMinor:)` ORs it with the persisted value (monotonic, never downgrades) → `UserProfile.copyWith(isMinor:true)` → `saveProfile`. The single enforcement chokepoint is **`UserProfile.toFirestore()` line 375: `'isSearchable': isMinor ? false : isSearchable`** — public_profiles is the only doc user-search reads (`where('isSearchable',==,true)`), and every profile write (rename/avatar/toggle) goes through this derivation, so a minor can't re-enable discovery. Rule-safe: `toFirestore()`/`toFirestoreEditable()` never emit the `isMinor` key, so the merge-writes to public_profiles and the `toPrivateSettings()` merge to `settings/preferences` both preserve the CF-set `isMinor` and don't trip the "isMinor unchanged" clauses (firestore.rules ~331-335 users root, ~545-549 settings). `_currentUserProfile` is reassigned to `updated` (user_service.dart:833) so in-session re-saves keep isSearchable:false. isMinor round-trips on resumed sessions via `fetchProfile` merging `s['isMinor']` from settings (firebase_user_repository.dart:247).

Two genuine gaps found (both partly pre-existing, surfaced/made-consequential by BUT-1454):
1. **Onboarding-window discoverability gap (Medium).** `toFirestore` only suppresses once `isMinor` is on the in-memory profile, which is stamped at onboarding COMPLETION. But `UserService.createOrUpdateProfile` (user_service.dart ~200-230) creates the public_profiles doc earlier in signup with `isSearchable: isSearchable ?? true` and isMinor default-false. Between initial profile creation and completion a minor is discoverable. The VM already HAS `result.isMinor` at `verifyAgeGate` time but doesn't act on it until completion — the fix is to force isSearchable:false immediately after the gate returns isMinor:true, not wait for completion.
2. **Idempotent-retry recomputes isMinor/birthYear from the CLIENT-supplied arg (Medium, pre-existing BUT-1435).** `runVerifySignupAgeWithDeps` computes `isMinor = compliant && age < AGE_OF_MAJORITY_YEARS` from the REQUEST `birthYear` on every call, and the `ageCompliant`-already-set retry branch re-runs `writeComplianceArtifacts(...birthYear, isMinor)` with no check that the retry birthYear matches the stored one. So an authed minor can re-call the CF with an adult birthYear to overwrite `birthYear`+`isMinor:false`, clearing minor protections (DM gate + search suppression). ADR-0002 claims birthYear is "set once by a single trusted writer" — the retry path breaks that. Fix: in the retry branch, ignore the request birthYear when a value is already stored (or reject a mismatch).

Design note (Low, not a bug): the toFirestore hard-force contradicts the aspirational firestore.rules comment (~325-327) that a minor "may later opt into discovery by toggling isSearchable." Current behavior is intentionally more-private; when the tracked searchable-opt-in follow-up ships it must change this derivation or the toggle will be inert for minors.

### 2026-04-27 — Cloud Storage versioning + lifecycle (BUT-419)
Hardened `infrastructure/storage/setup-storage-versioning.sh` + `docs/ops/storage-lifecycle-runbook.md`. **Lifecycle rule shape that matters:** `{age:30, isLive:false}` — `isLive:false` is the critical guard; without it the rule auto-deletes LIVE objects (opposite of recoverability). Verify via `gcloud storage buckets describe --format=json` grepping `"enabled": true` (versioning) + `"type": "Delete"` (lifecycle) so the script fails non-zero on silent no-op. **GDPR nuance:** with versioning on, `on-user-deleted.ts` `gsutil rm` deletes only LIVE generations — noncurrent versions linger ≤30d (accepted posture, same tier as Firestore PITR; strict-immediate would need a generation-aware `#GENERATION` cascade). `STORAGE_BUCKET` is the Firebase Storage bucket (`butlery-app-1.appspot.com`), NOT the project ID.

### 2026-04-27 — GDPR repo migration is partial-by-design; cross-user scrubs stay in the deletion/export layer (BUT-498/501)
Account-deletion and data-export services keep direct-Firestore for **cross-user scrub/read paths that legitimately cross ownership boundaries** (Art-17 cascade / Art-15 "your participation in others' docs"): `_scrubCollaborativeListReferences`, `_scrubGroupWeeklyMenuPlans`, `removeFromSharedContent` (collectionGroup `members` + `arrayRemove` on parents), recipe-comment anonymization (`authorId='deleted'`, preserves thread), all of social_export (friends/requests/conversations+messages/shared_content/blocks/categories/memberships). **Don't push these into per-resource repos** — they'd lose the audit trail and bury cross-ownership intent. The right follow-up is adding `deleteAllByUser(userId)`/`exportXxxByUser(userId, {maxDocuments})` (each calling `validateOwnership` FIRST) to per-user-subcollection typed repos (recipes, menus, shopping lists, personal_tags, pantry, weekly_menu_plans). Export methods return raw `{id, data}` maps NOT typed entities — the pipeline's `sanitizeForJson` needs raw `Timestamp`/`GeoPoint`/`DocumentReference`; round-tripping loses precision. **FeedbackRepository gotcha:** eager `FirebaseStorage.instance` in ctor breaks read-only tests with `[core/no-app]`; lazy-init the storage getter (apply preemptively to any repo pulling in a heavyweight Firebase service the read path doesn't need).

### 2026-07-03 — Hand-rolled realtime deserializer must mirror EVERY toFirestore key or shared data silently drops (ingredient sections; BUT-1216 collab path)
`RecipeSerialization.deserializeRecipe` (lib/models/realtime/) is a SEPARATE, hand-written map→Recipe builder for the collaborative/realtime recipe path — it does NOT reuse `Recipe.fromFirestore`. Serialize side is `serializeRecipe == recipe.toFirestore()`, so any field toFirestore persists but this deserializer forgets to read is a **silent write/read asymmetry**: it round-trips out to Firestore and is dropped on load for every collaborator. Here `structuredIngredients` (the ingredient section-header carrier) was written by toFirestore but never read back → shared recipes lost all "Deg"/"Fyllning" grouping. Fix: `structuredIngredients: RecipeIngredient.listFromJson(coreData['structuredIngredients'])`, byte-for-byte the canonical `fromFirestore` line. **Rule: when reviewing a change to a bespoke realtime/collab (de)serializer, diff its read keys against `toFirestore()`'s write keys — a missing key is a data-integrity finding, not cosmetic.** This fix reviewed CLEAN on all three collab-correctness axes: (1) `listFromJson` is total — `if (value is! List) return null` handles absent-key (old-client docs) and malformed payloads, per-entry skips non-maps, `fromJson` uses `safeString`/`safeNullableString`, returns null when empty → never throws on a peer's differently-versioned write. (2) NO allergen risk: the flat `ingredients` list (what tagging reads) is set independently from `coreData['ingredients']`; heading text lives ONLY in `RecipeIngredient.section` (a per-entry attribute, never its own list slot — so structured.length stays == ingredients.length), and the `Recipe.structuredIngredients` getter's alignment guard (`_structuredAligned`: length + raw[i]==ingredients[i]) discards a stale/mismatched structured list wholesale, falling back to raw-only. A peer editing the flat list on an old client can therefore never inject a phantom heading into a tagged line. (3) Round-trip is now correct for new clients; the old-client "flatten and drop sections" degradation is benign (headings are never in the flat list, so no corruption — worst case is a dropped heading) and needs no accepted-deviations entry.

### 2026-07-04 — Adding a field to recipe `core` is rules-safe (no hasOnly allowlist on recipes); pooled-ratings client poolKey is display-only (slice 6a)
Two reusable facts confirmed reviewing pooled-ratings Increment 6 slice 6a (client `ratingPoolKey` stamp + `getPooledStats` read). (1) **`match /users/{uid}/recipes/{recipeId}` has NO field allowlist** — create/update validate only `core.tagResult` (`isValidTagResult`) and `core.cookCount` monotonicity; there is no `keys().hasOnly([...])`. So adding a NEW field to the recipe doc (here `recipe.core.ratingPoolKey`, a nullable String set in-place in `PersonalRecipeModule._saveToCache` before both the cache write and the shared-object Firebase sync) does NOT get rejected by rules — unlike the many collections that DO pin a `hasOnly` allowlist (feedback, conversation_memberships, deep-link clicks, notification_*). When a new recipe field is proposed, check the recipes rule for an allowlist first; there isn't one today, so recipe fields are additive without a rules change. (2) **The client-computed poolKey is a pure display/index hint, never trusted server-side.** `canonical_recipe_stats/{poolKey}` is `allow read: if isAuthenticated()` (anonymous {count,average} aggregate, same contract as `recipe_social_stats`) and `create/update/delete: if false` (Stage-B aggregator CF, Admin SDK only); `users/{uid}/canonical_rating_events/{poolKey}` is owner-read + all-client-writes-denied. The aggregation CF recomputes the key from its own TS twin (`functions/src/ratings/canonical-pool-key.ts`, byte-identical golden fixture) and never reads the client's stored key for routing — so a tampered `recipe.core.ratingPoolKey` cannot poison a pool or forge a vote; worst case the tamperer's own device reads a different pool's already-public aggregate (no confidentiality boundary, all authed users read all stats docs). `getPooledStats` is a single guarded doc read (empty-poolKey → null, absent doc → null), no cross-user leak. `CanonicalPoolKey.compute` is pure + fail-closed (returns null on empty ingredients / no dish anchor / generic anchor). One Low nit noted for the record: the compute call sits OUTSIDE `_saveToCache`'s try/catch, so a hypothetical throw would fail the save — acceptable because compute is total/defensive, but if it ever grows I/O or asset loads, move it inside the guard.

### 2026-06-28 — Overriding create()/update() for an invariant does NOT cover createBatch (it's on the BASE class, not the mixin)
`FirebaseDinerProfileRepository` enforces a GDPR consent invariant by overriding `create()`/`update()` to call `_assertConsentCompliant()` before `super`. **This is bypassable:** `createBatch(List<T>)` lives on `BaseFirebaseRepository` itself (base lines 267-301) — every subclass inherits it unconditionally, it is NOT gated behind `BatchOperationsFirebaseRepository`. `createBatch` validates create-permission per entity then `batch.set(ref.doc(...), toFirestore(entity))` directly — it never routes through the overridden `create()`, so the consent assertion is skipped entirely. A household member could persist a minor profile with no guardian consent (or allergen data with no allergen consent) via `createBatch`. **Rule: when you enforce a data-boundary invariant by overriding single-entity CRUD, you MUST also override `createBatch` (and `updateBatch` if the BatchOperations mixin is applied) to run the same assertion — or hoist the invariant into a private `_assertX` that BOTH paths call.** Clean fix: override `createBatch` to loop `_assertConsentCompliant` before `super.createBatch`. `updateBatch`/`deleteBatch` are on the mixin and this repo does NOT mix it in, so those two are currently unreachable — but they go live the moment someone adds the mixin, so the obligation stands.

### 2026-07-03 — merge-write omit-key + unset-vs-null sentinel to stop a degraded read wiping a private setting (BUT-1322)
Data-loss pattern and its safe fix, on the `saveProfile` path. `fetchProfile` swallows a failed settings sub-doc fetch into an in-memory `null` for `householdSize`; a later UNRELATED profile save then wrote that `null` back over the persisted value (`SetOptions(merge:true)` clears a key set to explicit null). **Fix has three cooperating parts, all worth reusing:** (1) `saveProfile(profile, {bool writeHouseholdSize = true})` — when false it `settings.remove('householdSize')` on the map from `toPrivateSettings()` BEFORE the merge `set`; merge only skips ABSENT keys, so omitting preserves the stored value while an explicit null would clear it. Safe because `toPrivateSettings()` returns a fresh map literal each call (`return {...}`), so `.remove` mutates a local copy, never shared state. (2) `UserService.createOrUpdateProfile` threads an `Object? householdSize = _unset` sentinel (NOT plain null — null is a meaningful "clear to default"), then `writeHouseholdSize: !identical(householdSize, _unset)`; callers that never touch the field (auto-creation, onboarding, social handler) can't wipe it. (3) The editing VM tracks a per-session `_householdSizeEdited` bool and only forwards the value when the user actually changed it this session — an untouched save sends the public sentinel alias. **Security invariants confirmed intact by this review, so future edits must preserve them:** the new param does NOT bypass any guard — `saveProfile` still runs `requireCurrentUserId()` → `validateSelfOperation(targetUserId: profile.uid)` → `validateRequiredFields` → write → `logPermissionCheck`; the settings write stays scoped to `_settingsDoc(profile.uid)` (== the validated self uid); the omit only touches the caller's OWN doc so it can never strand another user's data; the `fetchProfile` merge-back sits inside the existing `currentUserId == userId` guard (no read-scope broadening); and `householdSize` is private-only — it is in `toPrivateSettings()`/`toJson()` but deliberately NOT in `toFirestore()`, so the public `toFirestoreEditable()` write can't leak it to `public_profiles`. **Rule: any nullable field where null is a legitimate value must NOT reuse null as "not provided" on a merge-write path — use an explicit sentinel and an omit-the-key branch, or a degraded/partial read will silently clear it.**

### 2026-07-02 — Client-writable private preference on UserProfile: the settings-sub-doc slot inherits GDPR coverage for free (BUT-1322)
Reviewed `householdSize` clean. Reusable checklist for adding a CLIENT-writable private preference (the peer pattern to the server-authoritative birthYear/isMinor entry): (1) field goes in `toPrivateSettings()` ONLY — `toFirestore()` (public_profiles) is a hand-built allowlist, so absence = excluded, and `toFirestoreEditable()` derives from it; `toJson()` (local round-trip) carries it like every other field. (2) Merge-back in `fetchProfile`'s settings-merge `copyWith` (the single hydration seam per the BUT-674 entries) or it reads as default forever. (3) **GDPR needs NO new code:** `users/{uid}/settings/preferences` is raw-exported whole-doc by `FirebaseDataExportRepository.exportSettingsPreferences` (Art-15/20) and whole-doc-deleted by `account-deletion-cascade.ts deleteUserPreferences` (Art-17) — any field added to `toPrivateSettings` automatically inherits both. Rectification = the Settings UI write path. (4) **Rules need NO change:** the `users/{uid}/settings/{settingId}` update rule is owner + pin-birthYear/isMinor equality, no `hasOnly` whitelist — new fields merge through. No `firestore.rules` diff ⇒ no rules-tester handoff. (5) Range-invariant fields get the birthYear parse pattern: constructor throws on out-of-range (write boundary), a public static `parseX` drops wrong-type/out-of-range → null (read boundary), and the repo merge-back MUST use `parseX`, not a raw cast — a tampered/legacy settings doc must never crash hydration. (6) Nullable-with-meaningful-null service params use an `Object? x = _unset` sentinel default + `identical()` check so non-passing callers (auto-creation, social handler) can't wipe the saved value — the fail mode of the sentinel is "keep existing", which is the safe direction.

### 2026-07-01 — TWO user docs: `users/{uid}` (private, CF-authoritative) vs `public_profiles/{uid}` (client-written, world-readable) — a flag on the wrong one is inert (BUT-674 cross-cutting)
Butlery splits a user across TWO Firestore docs and it is the single most important thing to get right when adding a "server sets it, client reacts to it" field:
- **`users/{uid}`** (root doc) — read rule is `isOwner || isAdmin` (firestore.rules ~L310). The `verifySignupAge` CF (Admin SDK) writes `birthYear`, `isMinor`, and (for minors) `isSearchable:false` HERE. NOT world-readable.
- **`public_profiles/{uid}`** — read rule `isAuthenticated()` (world-readable). Written by `FirebaseUserRepository.saveProfile` via `toFirestoreEditable()` (the repo's `collectionName` = `public_profiles`). This is what **user search** filters (`firebase_search_repository.dart` / `firebase_user_repository.dart`: `.where('isSearchable', isEqualTo: true)`), and what the client's `UserProfile` is hydrated from (`fetchProfile`→`readCacheFirst`→`getCollectionRef()`=public_profiles, merged with `settings/preferences`).
**The trap BUT-674 fell into:** the CF wrote `isMinor` + `isSearchable:false` to `users/{uid}`, but (a) SEARCH reads `public_profiles.isSearchable` — where the client's `saveProfile` later writes the model default `true` — so the minor stays discoverable (default-private defeated); and (b) the client `UserProfile.isMinor` is hydrated from `public_profiles`, which the CF never touched, so `isMinor` is ALWAYS false client-side → the `emitLifecycle` analytics-minimization gate (`profile?.isMinor == true`) never fires. The Firestore rules DM-gate still works (it `get()`s `users/{other}.isMinor` server-side, the correct doc), but the two client-side protections are inert. **Rule: a server-authoritative user flag that must drive (i) a client-visible query like search, or (ii) client behavior, must live on — or be mirrored to — `public_profiles`, because that is the only user doc the client and cross-user queries read. Writing it only to `users/{uid}` protects nothing the client or another user can see.** When reviewing any "CF writes flag X, client/search reacts to X" design, always confirm WHICH of the two docs each end reads/writes — they diverge silently and both tests pass in isolation.

### 2026-07-01 — BUT-674 Critical-2 confirmed CLOSED: the settings-merge is the ONLY isMinor client-hydration seam, and copyWith/in-memory-cache preserve it
Follow-up confirmation of the two 2026-07-01 entries below. The fix landed at `firebase_user_repository.dart:222` — `isMinor: s['isMinor'] as bool? ?? false` added to the SAME settings-merge `copyWith` in `fetchProfile` that merges `hasSeenActivityFeedHint`. Full trace now closes and there is **no silent-revert path**, verified end to end:
- **CF write:** `verifySignupAge` writes `isMinor` to BOTH `users/{uid}` and `users/{uid}/settings/preferences` (verify-signup-age.ts:274/277).
- **Client hydration is single-seam:** the ONLY place a current-user `UserProfile` is re-built from Firestore is `fetchProfile` → `readCacheFirst` (reads `public_profiles`, which has NO `isMinor`) → then the settings-merge `copyWith` overlays `isMinor` from `settings/preferences`. The Firestore-SDK cache in `readCacheFirst`/`getDocCacheFirst` caches only the *public_profiles* doc, so a cache-vs-network hit there can never carry a stale `isMinor` — the field simply isn't in that doc; the merge always re-applies on top.
- **No competing hydration path resets it:** `fromFirestore`/`fromMap` (public doc) yields `isMinor:false`, but that raw path is used only for `fetchProfiles` (OTHER users, line 318) — never for the current user's `currentUserProfile`, and other users' settings sub-docs aren't client-readable anyway. `emitLifecycle`'s only two callers both pass `userService.currentUserProfile` (butlery_app.dart:615 session-start; recipe_detail_viewmodel.dart:401 cook re-emit) — the merged handle, not a `fetchProfiles` result.
- **copyWith preserves it:** `UserProfile.copyWith` is plain `isMinor: isMinor ?? this.isMinor` (model line 241). `createOrUpdateProfile` (user_service.dart:148) starts from the merged `existingProfile` and copyWith-chains — `isMinor` rides through every settings save; it is NOT clobbered back to false. The `else`/fresh-construct branch defaults false, but only fires when no profile exists yet (new signup), where the CF has already stamped `isMinor:true` before onboarding profile creation.
- **In-memory cache is object-identity, not a re-serialize:** `UserService._profileCache` is a `Map<String,UserProfile>` holding the built object — no toFirestore/fromMap round-trip that would drop `isMinor`.
**Verdict: Critical 2 genuinely closed.** Residual note (NOT a BUT-674 regression, pre-existing): `fetchProfiles` never merges settings, so ANY server-authoritative-private field is false for non-self profiles read via that batch path — fine today because no cross-user consumer reads `isMinor` client-side (the DM-gate does it server-side in rules). Flag it only if a future feature tries to read another user's `isMinor` from a `fetchProfiles` result.

### 2026-07-01 — Adding a server-authoritative field to UserProfile: mirror birthYear's EXACT read/write split (BUT-674)
`UserProfile` (`lib/models/user_profile.dart`) has an established pattern for CF-only fields the client may READ but must NEVER write — `birthYear` (BUT-1386/ADR-0002), now joined by `isMinor` (BUT-674, verifySignupAge sets it). **Method to add such a field safely: `grep birthYear` and replicate site-for-site.** The write/read surfaces and where each field belongs:
- **`toFirestore()`** (public_profiles write) — does NOT list `birthYear`/`isMinor`. It's a hand-built allowlist map, so *absence = excluded*. Add nothing here.
- **`toFirestoreEditable()`** — starts from `toFirestore()` then `.remove()`s a few server-owned fields. Because `toFirestore()` never emitted `birthYear`/`isMinor` in the first place, **no explicit `.remove('isMinor')` is needed** (there'd be nothing to remove). The explicit `data.remove('birthYear')` there is belt-and-suspenders documentation, not load-bearing — don't feel obliged to add a matching `.remove('isMinor')`. What actually protects the field is (a) it never being in a client write map + (b) firestore.rules denying it.
- **`toPrivateSettings()`** (settings/preferences subcollection write) — birthYear absent (only a comment marks it); keep isMinor absent too.
- **`toJson()`** (LOCAL persistence round-trip, not a Firestore write) — this one DOES include `birthYear`, so it must include `isMinor`. This is the one write-shaped map where a server-authoritative field legitimately appears, because it's the app persisting its own read-back copy locally, never uploaded.
- **Read sites** — `fromMap` + `fromJson` (no separate `fromFirestore` factory here; both route their birthYear read through `_readBirthYear`). `birthYear` needs a custom `_readBirthYear` only because of its 15-year-floor range invariant; a plain bool like `isMinor` has no invariant, so `SerializationUtils.safeBool(data, 'isMinor')` (default false) is the correct, simpler mirror — don't over-build a `_readIsMinor`.
- **Constructor default** `= false`, **copyWith** plain `bool? isMinor` param (like `isHidden`, NOT the `Object? = _sentinel` sentinel dance birthYear uses — that sentinel is only for *nullable* fields where null is a meaningful set-to-null value).
- **`==`/`hashCode`** are uid-ONLY in this model — they include neither birthYear nor isSearchable, so a new scalar field goes nowhere near them. The task hint "if props include birthYear/isSearchable add it too" is a guard, not an instruction: here they don't, so you don't.
The security property that makes this safe: the field is protected by *never appearing in any Firestore-upload map* PLUS firestore.rules rejecting it — the model layer's job is only the first half. Verify by grepping that every write-map lacking `birthYear` also lacks the new field, and the sole map carrying `birthYear` (`toJson`, local-only) carries it too.

### 2026-06-30 — OR-scoped collections need a TWO-FIELD probe, and a cross-field-OR query must be split per-branch to satisfy rules (BUT-1450)
`notification_delivery` is owned by EITHER `senderId==uid` OR `targetUserId==uid` (no single `userId` field). Two structural consequences that recur for any OR-owned collection:
1. **Deletion-cascade residual probe:** a single `where('userId','==',uid)` `.count()` probe silently matches ZERO (the `realtime_recipes` wrong-field trap, where a no-op `userId` filter once let a deleted user's docs survive). An OR-owned collection MUST get its own loop probing each ownership field (`senderId`, then `targetUserId`) separately — never folded into the `userId`-array probe. BUT-1450 does this correctly: `notification_delivery` is excluded from the userId probe array and handled by a dedicated `for (field of ['senderId','targetUserId'])` loop.
2. **Client export under firestore.rules:** the read rule is a per-doc OR (`senderId==uid || targetUserId==uid`). Firestore's query-rule engine requires every returned doc to provably satisfy the rule, so you CANNOT issue one query that returns the union — you split into two single-equality queries (`where senderId==uid`, `where targetUserId==uid`), each of which pins one OR branch so all its rows pass, then de-dupe by doc id in code (a self-targeted row matches both). This is the correct pattern; a cross-field OR has no native Firestore query.
**export ⊇ erased invariant for OR-owned data:** confirm the union of the export's per-branch queries covers exactly the set the cascade deletes. Here both sides match: export = `senderId∪targetUserId`, delete = `senderId + targetUserId`, probe = `senderId + targetUserId`. All three agree.
**Index note:** `where(eq).orderBy(other)` still needs a composite even on a single equality field — `notification_history` (userId eq + sentAt desc) has its composite in `firestore.indexes.json`; the pure-equality delivery/batches/engagement export queries need none (accepted-deviations equality rule). Caps for all four live in `ExportPaginationHelper.exportLimits`; high-volume analytics that fall through to the 10k default would be a slow/expensive export, so explicit caps + a `truncated` flag are the right call.

### 2026-06-28 — Diner-profile (children's data): submitted-householdId write-auth is safe via isMember, but UPDATE can re-parent across households
`FirebaseDinerProfileRepository.validateCreate/UpdatePermission` delegate to `_householdRepository.isMember(entity.householdId, userId)` using the **submitted** entity's `householdId`. SAFE for create **because** `isMember(hid,uid)` is true only if `uid` genuinely belongs to `hid` — a member of A cannot write a profile tagged `householdId=B` unless also a member of B. Composition holds: `isMember` has its own caller-guard (`requireCurrentUserId() != userId → false`); base always passes `userId = requireCurrentUserId()`, so `userId == caller` always and the guard always permits the legitimate self-query — no path where `userId != caller`. **Residual on UPDATE** (the Household repo's load-current-doc pattern would catch it): update-auth reads `entity.householdId` from the payload, not the stored doc. A member of both A and B could take a profile currently in A and submit an update with `householdId=B`, re-parenting a child's profile across households. Medium at repo layer (both households legitimately contain the caller). Fix options: load stored doc and check membership of the STORED householdId (match the Household self-elevation pattern), and/or rules pin `householdId` immutable on update. Delete already does the right thing (loads stored doc → stored householdId). `getByHousehold` is clean: `isMember` gate before an equality query, returns `[]` for non-members; equality-only `where('householdId', isEqualTo:)` needs no composite index (accepted-deviations). Note `getByHousehold` has no `.limit()` — `.get()` not `.snapshots()`, so the snapshots-limit rule doesn't strictly apply, but a household-member-writable collection should still bound it.

### 2026-06-28 — firestore.rules obligations for diner_profiles (deferred commit — checklist, not findings now)
Repo consent guard + membership gate are advisory; rules are authoritative. `match /diner_profiles/{id}` MUST: (1) confine read+write to current members of `resource.data.householdId` / `request.resource.data.householdId` via a `get(/households/$(hid)).data.memberUserIds` membership lookup; (2) pin `householdId` immutable on update (blocks the cross-household re-parent above); (3) **enforce the consent invariant server-side** since `createBatch` bypasses the Dart guard — on create/update: if `ageBand != 'adult'` require `guardianConsent` present, and if `allergenPreferences` present require `guardianConsent.includesAllergenConsent == true`. This is the REAL backstop for the createBatch hole; do not rely on the Dart override alone. (4) pin `createdBy`/`createdAt` on update. Hand to `firestore-rules-tester` once written.

### 2026-06-30 — GDPR "export ⊇ erased": prove the field PAIR (deletion-filter vs export-filter), not just collection coverage (BUT-1396)
When closing a right-of-access gap by adding export reads for collections the deletion cascade already erases, the invariant that matters is that the **export query filter equals the deletion query filter** per collection — same field, same value. Both filters target the *same physical docs* only if they agree on the owning field. BUT-1396 added exports for `reports` (filter `reporterId==uid`), `pings` (collectionGroup `fromUserId==uid`), `realtime_recipes` (`ownerId==uid`). Reports/pings: export filter byte-for-byte matches the cascade (`deleteUserReports`/`deletePingsByUser`) → clean. **realtime_recipes is the trap:** the model persists `ownerId` (verified: `realtime_recipe_utils` write map line 21 `'ownerId': ...`; rules `match /realtime_recipes` gate on `resource.data.ownerId`; `RealtimeRecipe.ownerId` required ctor field). The EXPORT correctly queries `ownerId==uid`. But the DELETION CF `deleteRealtimeRecipes` queries `where("userId","==",uid)` — a field the doc never carries → matches zero docs → **collaborative recipes are exported but NEVER erased** (Art.17 leak, the mirror-image of the gap BUT-1396 set out to fix). The export's own code comment flags the cascade `userId` filter as "a known no-op" — believe it; it's a live High-severity deletion bug in `account-deletion-cascade.ts:666-668`, fix = `where("ownerId","==",uid)` + a cascade test asserting a seeded owned realtime_recipe is gone. **Lesson: when a ticket says "the deletion cascade already erases X", open the cascade and read the actual `.where()` field — don't trust that an existing delete function works just because it exists. A no-op delete is worse than a missing one (false confidence).** Also: the three new export reads are single-field equality (no orderBy/range) → no composite index needed (accepted-deviations); the collectionGroup `pings.fromUserId` read is rules-permitted (owner clause) and was already exercised Admin-SDK-side by the cascade. Residual unrelated gap noticed: `deleteNotificationAnalytics` erases `notification_history/_batches/_engagement/_delivery` (linked-by-userId) but no export manager reads them — pre-existing, out of BUT-1396 scope, Medium.

### 2026-06-30 — Terms-acceptance merge-write on users/{uid}: validateSelfOperation + merge:true is the correct, clobber-safe pattern (BUT-1400)
`recordTermsAcceptance(uid, version)` does `validateSelfOperation(caller, uid)` → `users/{uid}.set({termsAcceptedAt: serverTimestamp, termsVersion}, merge:true)` → `logPermissionCheck`. Correct on all axes: (a) **merge:true** touches only the two terms fields, never clobbers `friendsCount`/`isHidden`/`birthYear` owned by other writers — same clobber-safety class as `markActivityFeedHintSeen` (BUT-1220). (b) **validateSelfOperation** (not validateOwnership) is right for a write to one's own user doc. (c) **Rules permit it:** `match /users/{userId}` `allow update: if isOwner(userId) && request.resource.data.get('birthYear',null) == resource.data.get('birthYear',null)` — on a merge-write `request.resource.data` is the *merged* doc so `birthYear` retains its stored value and the immutability clause passes; no rules change needed. (d) **Best-effort swallow at the signup call site is acceptable** — UserService wraps the call in try/catch and only logs on failure, so an accountability-record write never blocks onboarding. Accepted trade-off, but note it: a swallowed failure means a user can be onboarded with NO stored ToS-acceptance record (the very accountability artifact the ticket adds). For a stronger guarantee, persist a "pending terms record" flag and retry on next launch, or fold the write into the same batch as profile creation so it's atomic. Low-severity as-is given the record is supplementary to the UI checkbox. Trigger fires only on the no-profile-existed (signup) branch — re-acceptance on ToS version bump is NOT handled (each user records the version current at *their* signup only); fine for launch, revisit if ToS changes post-launch and you need re-consent capture.

### 2026-06-28 — Household repo: self-elevation defense = read CURRENT doc in update/delete permission check
`FirebaseHouseholdRepository` (top-level `households/{id}`, modelled on `GroupWeeklyMenuPlan`) gets self-elevation immunity by checking the **stored** doc, not the submitted entity: `validateUpdate/DeletePermission` call a private `_loadRaw(id)` (a `.get()` that deliberately skips read-permission validation — correct and safe: you MUST read who-is-admin to authorize, and the value never leaves the method) then `current.canAdmin(userId)`. Missing doc → `false` (stricter than the GroupWeeklyMenuPlan reference, which returns `true` and delegates delete-auth to rules). `create` checks `entity.isMember(userId)` (submitted entity is correct here — the doc doesn't exist yet, so there's nothing to elevate against). Verified the self-elevation test actually exercises this: Johan-as-editor submits an entity making himself admin, check loads stored doc and denies. **Reusable pattern for any symmetric multi-user top-level entity:** never trust the payload's permission projection for write-auth; load current state. **Rules MUST still enforce (deferred to a later commit, NOT a finding now):** (1) only-admin write, evaluated against `resource.data` (the client check is advisory — rules are authoritative); (2) `memberUserIds`/`memberPermissions` projections must stay consistent with `members` on write (client builds them from `members` in `toFirestore`, but a hand-crafted write could desync — rules should pin them or membership/permission lookups lie); (3) read confined to `request.auth.uid in resource.data.memberUserIds`. `getForUser` = `where('memberUserIds', arrayContains: userId).limit(50)` — arrayContains with a limit, no orderBy/range → **no composite index** (per accepted-deviations). `ensureForUser` get-or-create has a benign TOCTOU duplicate-household race (two concurrent first-logins → two single-member docs); low-risk pre-launch, idempotent-ish since callers take `.first`, rules-gated — note it, don't block. A transaction or deterministic `households/{uid}` doc-id would remove it if it ever bites. Diner-profile/family-rating repos will gate on `isMember(householdId, uid)` — that cross-entity check is the household's reason to exist.

### 2026-06-29 — Consent-withdrawal GDPR breach: use set() not update() when toFirestore omits null fields
`BaseFirebaseRepository.update()` calls `doc.update(toFirestore(entity))` — a MERGE. Any field absent from `toFirestore`'s output (e.g. `allergenPreferences` when null) is left untouched in Firestore. This means a consent withdrawal that nulls those fields silently FAILS to erase the old special-category data — a GDPR Art. 17 / Art. 9 breach. **Fix: override `update()` and call `collection.doc(entity.id).set(toFirestore(entity))` (no SetOptions → full replace).** Omitted-when-null fields are genuinely erased. The override must replicate the base permission flow (`requireCurrentUserId()` → `validateUpdatePermission()` → `logPermissionCheck()` → guard throw) before the `set()` — do not short-circuit permissions. Critical invariant: `set()` without `SetOptions(merge: true)` is a full replace; passing `merge: true` reintroduces the breach. The Firestore rules `cannotModify` guards on `createdBy`/`createdAt` remain the authoritative tamper backstop — switching from merge to full-replace does not change the repo-level posture because both paths call `toFirestore` which includes those fields. Pattern applies to any model where `toFirestore` deliberately omits null-consent or null-sensitive-data fields and where consent can be withdrawn post-creation.

### 2026-04-30 — BUT-501 closed: read-only export gateway pattern
`FirebaseDataExportRepository` (extends `BaseFirebaseRepository<Object>`, read-only — CRUD methods throw/false) funnels every export-only direct read for typeless collections through one `_guardSelfExport(userId, resourceType)` → `validateOwnership(...)` choke point before any network call (cheaper than a rules-deny round-trip + clean log line on cross-user attempt). Beats "16 new typed repos" because those collections (settings, notification prefs, FCM tokens, blocks, requests, conversations+messages, shared_content slice, public/private profile, etc.) have no natural typed model. Methods return raw `{id,data}`. Gateway and typed-repo `exportXxxByUser` are complementary — prefer adding to the typed repo and retiring the gateway counterpart when a natural home exists. Note: `exportConversationsAndMessages` returns all messages in conversations the user participates in (correct for Art-15); `social_export_manager` then filters `senderId==uid || recipientIds contains uid` as belt-and-braces. Residual direct call: `compliance_export_manager` reading `audit_logs` (admin-only at rules — needs the CF exporter, see BUT-424/BUT-770).

### 2026-05-01 — Read-only gateway shape-grouping refactor (BUT-740)
`FirebaseDataExportRepository` had 23 near-identical `_guardSelfExport → query.limit(n).get() → map` methods (3 shapes: `[{id,data}]`, `[data]`, `data?`). Collapsed to two private helpers (`_queryList(query,userId,resource,{limit,includeIds})`, `_readDoc(ref,userId,resource)`) + an `ExportResourceType` enum retiring stringly-typed literals. Bespoke shapes (nested shopping-list items, conversations+messages join) kept as-is. ~150 lines saved, behaviour-identical, tests unchanged. Keep `includeIds` binary — fork the helper if a 4th shape appears.

### 2026-04-27 — audit_logs: user read is admin-only; Art-15 export needs a CF (BUT-424/BUT-770)
`audit_logs/{logId}` read is now `if isAdmin();` (was `auth.uid == resource.data.userId`). **Invariant: a compromised account must not be able to enumerate its own audit trail and craft attacks around the gaps.** Create stays self-uid-pinned (2s rate limit), update+delete denied (immutable trail). This breaks the client-side Art-15 audit-log export (`compliance_export_manager.exportAuditLogs` returns permission-denied → empty section; the broader export continues via catch). **Fix (BUT-770, shipped):** Admin-SDK callable `exportAuditLogs` (`functions/src/exports/audit-logs.ts`) reads on behalf of `request.auth.uid` only — no user-side direct read path added, invariant preserved. No App Check (auth session already passed it at sign-in; revisit if board-wide App Check becomes mandatory). Cursor pagination is server-timestamp `startAfter` desc — tie risk is negligible (ms-fine append timestamps); switch to `startAfterDocument(snapshot)` if high-throughput admin audit appears.

### 2026-04-30 — audit-log retention windows (BUT-665)
`audit_logs/{id}` retention: **consent events** (`operation` startsWith `consent_`) = **24 months** (Art 7(1) demonstrate-consent horizon); **general** = **6 months** (Art 5(1)(c) minimisation, ~180-day incident floor). Enforced by `functions/src/audit_logs/purge-expired.ts` (Sun 05:00 UTC, europe-west1). Firestore can't NOT-IN a prefix in a query, so it queries `timestamp < cutoff` once and filters consent-vs-general client-side (`MAX_DOCS_PER_RUN_PER_CATEGORY=10000`). **General bucket runs FIRST** and excludes `consent_*` so consent events 6–24mo old aren't purged (pinned by `generalBucketIgnoresFreshConsent` test). Co-exists with legacy `cleanupOldAuditLogs` (flat 90-day, 03:00 UTC) — retire after one full retention cycle. Future refactor: `where('operation','not-in',[...consentOps])` for the general bucket (≤10 values; needs composite `(operation asc, timestamp asc)`). Privacy: no prod call site passes `ip`/`userAgent` (repo-wide grep) — the doc example is aspirational; truncation contract (IPv4→/24, UA family+major) is in `docs/security/audit-logs-retention.md`.

### 2026-05-04 — admin-only collections need EXPLICIT deny + retention coverage (Sprint G, BUT-482/483/627)
New server-side admin-only collections (`audit/ping_rate_limit/entries/{auto}`, `_internal/rating_debounce/markers/{recipeId}`) were only *implicitly* admin-only via default-deny. **Convention: write an EXPLICIT `allow read, write: if false;`** (see `deletion_audit_logs` rules:434, `audit_logs` rules:1378) so intent is grep-auditable AND a future wildcard/collection-group rule can't accidentally widen access. **Naming distinction:** `audit_logs/` (single underscore) is the canonical user-action trail with documented retention; `audit/` (Sprint G) is a different top-level collection with per-category subcollections — don't conflate when writing purgers/rules. **Retention gap:** `audit/ping_rate_limit/entries` stores violator `userId` but had no purge job — every new audit-style collection with user identifiers must be in the BUT-665 sweeper or carry its own `expiresAt`+sweeper or Art-15/17 become incomplete and rows grow unbounded.

### 2026-06-27 — Age gate (BUT-1386/ADR-0002): custom-claim gate + birthYear single-writer; clean review
Server-authoritative age enforcement reviewed clean. Reusable patterns:
- **Custom-claim gate fails closed correctly.** `isAgeCompliant()` = `request.auth.token.ageCompliant == true`. A missing field, `false`, or a stale token (issued before `setCustomUserClaims`) all evaluate falsy → deny. Claims are bound to the Firebase-issued token, so a client can NOT forge `ageCompliant` (unlike a Firestore-doc gate). Chosen over a `get()`-the-doc gate to avoid billing one read per UGC write forever. Client MUST `getIdToken(forceRefresh:true)` after a compliant result or the first UGC write denies on the stale token — this is fail-SAFE (deny), best-effort refresh is acceptable.
- **birthYear single-writer immutability — the merge-semantics check.** Create rule `request.resource.data.get('birthYear', null) == null` and update rule `request.resource.data.get('birthYear', null) == resource.data.get('birthYear', null)` on BOTH `users/{uid}` and `users/{uid}/settings/{settingId}`. Why this is bypass-proof: on `set(merge:true)` Firestore evaluates the rule against the POST-merge document, so a merge that omits birthYear still presents the existing value → equality holds → allowed; a merge can't DELETE a field; a non-merge `set` omitting birthYear makes the post-value null ≠ existing → denied. So no create/update/merge path lets a client add, change, or null birthYear. The Admin SDK CF write bypasses rules and is the sole writer. **Review heuristic for "client must never write field X":** verify the rule compares `request.resource.data.get('X',null)` to `resource.data.get('X',null)` on update AND to `null` on create — one without the other leaks (create-time injection or update-time mutation).
- **Rejection-path data minimisation is genuinely non-identifying.** Under-15 → `auth.deleteUser(uid)` synchronously (triggers existing onUserDeleted cascade) + a rejection audit row carrying ONLY `operation/reason/basis/timestamp` — no uid, email, or birthYear. Correct: never create a record linking a real identity to "is under 15". The compliant audit stores `userIdHash` (sha256 prefix) + coarse `birthDecade` (not raw year) — data-minimised but still correlatable for Art 7(1) consent demonstration.
- **Retention prefix wiring.** Compliant event `operation: 'consent_age_verification'` → `startsWith('consent_')` → 730-day retention; rejection `operation: 'age_verification_rejected'` (no prefix) → 180-day. Both carry `timestamp`, so the `purgeExpiredAuditLogs` `where('timestamp','<',cutoff)` sweep reaps them. Verified against `purge-expired.ts`.
- **Fail-closed pair on the callable.** `enforceRateLimit(uid,'verifySignupAge')` (dedicated 5-token config, NOT `withRateLimit` — deliberately decoupled from the LLM global limiter / `aiEnabled` kill-switch so disabling AI can't break signups) + `enforceIpAuditCap` (atomic per-hashed-IP+hour transaction, `IP_AUDIT_CAP_PER_HOUR=5`). Both fail CLOSED on Firestore error (`checkRateLimit` catch → deny; `enforceIpAuditCap` catch → throw resource-exhausted). `system_ip_audit_caps` is on Firestore default-deny (no client rule) — correct, Admin-SDK-only.
- **Pre-existing (NOT introduced here) forgery surface, noted for context:** `audit_logs` create rule allows any authed user to write a row with their own `userId` + arbitrary `operation` (incl. `consent_*`) if they supply `['userId','operation','resourceType','timestamp']`. The CF's genuine rows are distinguishable (they carry `userIdHash`, no `userId`/`resourceType`), so a forged `consent_age_verification` row can't impersonate a real verification, but it WOULD get 730-day retention. This predates BUT-1386 and these two files don't widen it — don't file against this change; if ever tightened, gate client `operation` to a non-`consent_` whitelist.

### 2026-06-28 — Algolia search failure-flag + Firestore fallback on SSL-pin mismatch is sound (BUT-1416)
The `SearchResult.failure(failed: true)` pattern lets the router distinguish a real 0-hit search from a provider outage or SSL-pin mismatch, falling back to Firestore instead of showing empty. Security assessment:
- **Pin mismatch → Firestore fallback does NOT expand the attack surface.** `PinningDioInterceptor` runs in `onRequest` before the body is sent, so the rejected Algolia request never transmits the query body to the suspect host. The Firestore fallback makes no outbound call to the suspect network. Posture is unchanged versus the pre-fix silent-empty behavior.
- **`ssl_pin_mismatch` analytics telemetry fires independently** of whether the result is used — the detection signal is preserved.
- **The pin check is defense-in-depth over TLS, not the primary trust anchor.** Platform TLS is the real validator; pinning catches compromised-CA scenarios only. Soft-fail (reject request, surface failure flag) is the correct posture here.
- **AppLogger.error logs no query payload or PII.** The error object on Algolia/DioException carries HTTP status + Algolia error code only; the `reason` passed to Crashlytics goes through `_sanitizeForCrashlytics` (masks 20–28-char alphanum tokens). Clean.
- **Write paths (indexRecipe, removeRecipe, indexUser, removeUser, batchIndexRecipes) all still rethrow** — unchanged by this diff. Only the read paths (`searchRecipes`, `searchUsers`) swallow and flag; `getSuggestions` returns `[]` (pre-existing, cosmetic path, acceptable).
- **Review heuristic:** when a pinning interceptor is layered over TLS, "fall back to a different backend on pin mismatch" is safe AS LONG AS the rejected request never reached the wire (reject in `onRequest`, not `onResponse`). If the interceptor fires in `onResponse` (i.e., the request already completed), a fallback after a mismatch would mean the attacker already saw the query — that's a different posture.

### 2026-06-27 — documentId prefix-range erasure: `endAt(prefix)` under-matches and deletes NOTHING (BUT-1390, Critical)
For collections keyed by `${uid}_${suffix}` (e.g. `system_rate_limits` doc id `${uid}_${operation}`), the per-user erasure idiom is a documentId range query. The trap: `startAt(`${uid}_`).endAt(`${uid}_`)` is a CLOSED range `[uid_, uid_]` (both bounds inclusive, identical) so it selects ONLY a doc literally named `"uid_"` — which never exists. Real ids like `uid_structureRecipe` sort lexicographically AFTER `"uid_"` and fall outside the `endAt("uid_")` upper bound, so the query returns empty and `batchDeleteAll` deletes nothing → silent GDPR Art-17 erasure gap, buckets survive deletion. The `_` separator does NOT "bound the match" on its own; you need a high sentinel on the upper bound. **Correct forms:** `.startAt(`${uid}_`).endAt(`${uid}_`)` (consistent with the project's `` prefix idiom used in cleanup/rules) OR half-open `.startAt(`${uid}_`).endBefore(`${uid}` + nextCharAfterUnderscore)`. **Cross-user safety is fine either way** — Firebase Auth UIDs are 28-char `[A-Za-z0-9]` (no underscores), so the `uid_` prefix can't bleed into a neighbour's id space; the only defect class here is UNDER-matching (deletes nothing), not over-matching. **Review heuristic:** any time you see `.startAt(X).endAt(X)` with identical bounds on a prefix erasure/scan, it's almost certainly meant to be a prefix range and is silently matching ~nothing — flag Critical if it's a deletion path. Always demand a regression test that seeds the target uid's buckets AND a second user's bucket, then asserts only the target's are gone (proves both completeness and the cross-user boundary). Same prefix idiom appears in `cleanup/cleanup-rate-limits.ts` — verify its bound too.

### 2026-06-14 — public_profiles stores `email` and serves it to ANY authed read (allowEmailSearch only gates the query path)
`UserProfile.toFirestore()` writes `email` unconditionally to `public_profiles/{uid}`, and the rule is `allow read: if isAuthenticated();`. So `allowEmailSearch` (default false) only restricts the *search query* (`where('allowEmailSearch',==,true).where('email',==,X)`) — it does NOT restrict field exposure on a direct `fetchProfile(uid)`. Any authenticated user who knows/enumerates a uid (uids leak through friends lists, group membership, comment authorIds) reads the email regardless of the flag. The flag's name implies it gates email discoverability; it does not gate email *visibility*. Fix options: move `email` to the private settings sub-doc (`users/{uid}/settings/preferences`) like fcmToken, OR add a Firestore field-level read masking via a separate `public_profiles_public` projection, OR (cheapest, behaviour-preserving for search) keep email only when `allowEmailSearch==true` and null it otherwise in `toFirestore`. This is the recurring "denormalised-to-a-world-readable-doc" leak — when reviewing any model whose `toFirestore` targets a collection with `allow read: if isAuthenticated()`, audit EVERY field for whether it's safe to be world-readable, not just whether a flag gates a query.

### 2026-06-14 — `validateReadPermission`/`fetchProfile` do NOT filter `isHidden`; only the search path does
`searchProfiles` server-filters `isHidden==false` (and client-filters in fallback), but `fetchProfile`/`fetchProfiles` and the rule (`allow read: if isAuthenticated()`) return a moderation-hidden profile in full. Direct-fetch surfaces (friend lists, group rosters, comment author hydration) will still render a hidden user's data. The hide is a search-suppression + UI-placeholder convention, not a read-permission boundary — the placeholder rendering must be enforced at every consumer, or hidden users leak through any non-search read. When `isHidden` semantics matter for a surface, the consumer (not the repo) owns the placeholder.

### 2026-06-14 — owner-update rule does not pin denormalised counters (`publicRecipeCount`/`friendsCount` self-write)
`public_profiles` owner-update branch blocks the sensitive keys + `isHidden`/`hiddenAt` but lets the owner write ANY other field, including `publicRecipeCount` and (via the owner branch) `friendsCount`. `toFirestoreEditable()` correctly drops `friendsCount` so `saveProfile` won't clobber it, but nothing stops a hand-crafted client write from self-inflating `publicRecipeCount`/`friendsCount`. These are denormalised display counters (cosmetic, drive social ranking) — Medium, not a data-loss/privacy hole — but note: counters that influence search ranking or trust signals should be CF-maintained or rule-pinned to ±1 deltas (friendsCount already has the ±1 guard on the non-owner branch; the owner branch has no such guard).

### 2026-04-27 — recipe_comments: denormalise ownership onto the child for read scoping (BUT-458)
Pre-BUT-458 read rule `allow read: if isAuthenticated();` let **any logged-in user read every comment globally** (recipe_comments is top-level; the rule had no efficient owner lookup from `recipeId`). Fix: denormalise `recipeOwnerId: string` + `sharedWithUserIds: string[]` onto each new comment at write time; read rule allows author OR recipeOwnerId OR `in sharedWithUserIds` (plus `isAdmin()`). Legacy comments (no denorm fields) fall through to author-only read via `'recipeOwnerId' in resource.data` guards — deliberate one-time degradation, restored by a backfill. Repo takes an optional `RecipeOwnershipResolver` typedef → `RecipeOwnershipSnapshot{recipeOwnerId, sharedWithUserIds}`, invoked in `addComment` (failures non-blocking → comment writes without fields, rule degrades to author-only).

### 2026-04-30 — BUT-458 closed: resolver wiring + backfill CF + lazy-DI gating for user-scoped services
`FirebaseRecipeOwnershipResolver` resolves: collaborative → `socialData.ownerId` + `memberPermissions.keys` (excluding owner); personal → `createdBy` + empty. **`isCollaborative` is keyed off `RecipeType.collaborative`, NOT `socialData != null`** (legacy recipes carry stale socialData) — always use `recipe.isCollaborative`, never `socialData != null`, when deciding ownership. Wiring problem: resolver depends on **user-scoped** `UnifiedRecipeService` (post-login) but comments repo is **app-scoped** (pre-login). **Pattern (three layers of fail-soft):** `if (!container.isRegistered<UnifiedRecipeService>()) return null;` + outer try/catch + resolver's own try/catch — comment-write must NEVER fail on an ownership-resolution failure. Used `getRecipeById` (sync cache + Firestore fallback) not the coordinator's private `getRecipe`. **Backfill CF** (`functions/src/migrations/backfill-recipe-comments-denorm.ts`): admin-only callable (`requireAdmin`), europe-west1, `__name__`-cursor paginated, uses `collectionGroup('recipes').where(documentId,==,recipeId)` to find owner; orphan comments (recipe gone) stamped `recipeOwnerId=authorId, sharedWithUserIds=[]` (stay author-readable forever); idempotent (skips non-empty `recipeOwnerId`); `MAX_BATCHES=50 × BATCH_SIZE=200 = 10k/invocation` with `hasMore` re-invoke flag.

### 2026-04-27 — blocking-gate placement: target-uid field is the discriminator (BUT-459)
`isNotBlockedBy(targetUserId)` extended from `social_requests create` to comment/rating/notification creates. Target-uid field per collection: `social_requests`→`toUserId`, `user_notifications`→`userId`, `recipe_comments`/`recipe_ratings`→`recipeOwnerId` (requires BUT-458 denorm). **Self-notify must stay unblocked** — `user_notifications` has an OR-branch for `userId == auth.uid` (system events) bypassing both friendship and block gates. **Block-doc id is `${blockerUid}_${blockedUid}`** — `isNotBlockedBy(t)` checks `exists(/blocks/$(t + '_' + auth.uid))` (actor's uid AFTER target's); tests must seed in this exact order or the gate no-ops. **Backwards-compatible-by-field-presence pattern** for deployed collections: `!('recipeOwnerId' in request.resource.data) || isNotBlockedBy(...)` so legacy clients without the field skip the gate (auth-pin + rate-limit still hold), new clients populate it and the gate fires — avoids a coordinated client-rules deploy. **Test seeding:** seed friendship (both directions) AND the block doc, so the test discriminates on the block, not the friendship.

### 2026-04-27 — FCM token store hardening (BUT-457)
`fcm_token_manager.dart` already used `FlutterSecureStorage` (the SharedPreferences "fallback" was a misleading key name). Added a one-time `_migrateFromSharedPreferencesIfNeeded()` running on every `initialize()`: copies a legacy `fcm_token` to SecureStorage **only if SecureStorage lacks one** (never clobber canonical) then `prefs.remove()`s both legacy keys unconditionally (so pre-BUT-457 installs never leave plaintext past first launch); a SecureStorage sentinel `fcm_token_sp_migration_done` gates re-runs. **Contract: on secure-storage write failure, log and move on — MUST NOT mirror to SharedPreferences** (regression guard against a future "fallback for resilience"). Test gotcha: replace the flat method-channel handler with a per-key `Map<String,String?>` keyed off `args['key']` (matches the real plugin); `SharedPreferences.setMockInitialValues({...})` resets the in-memory store in setUp.

### 2026-05-02 — FCM consent-revoke residual-token gap closed (BUT-573/754)
`FCMService._revokePushAccess()` cleared SDK token + Firestore profile + FCMService static `_currentToken`, but missed the SecureStorage copy written by `FCMTokenManager` (BUT-457). **Fix (option B):** NotificationService owns its own ConsentService listener (parallel to FCMService's) and calls `_tokenManager.clearLocalToken()` on revoke — B beat "call from FCMService" because FCMTokenManager is a per-user instance NotificationService owns (FCMService is static), so lifecycle ownership is correct. **Residual-store map (exhaustive, 3 stores):** SecureStorage `fcm_token`+`fcm_token_timestamp`; SharedPreferences legacy keys (scrubbed unconditionally on every init); in-memory FCMService static + FCMTokenManager instance. **Order:** SDK `deleteToken()` BEFORE Firestore clear minimizes the "sent a push AFTER consent revoked" window (the GDPR-relevant failure mode). Two async listeners touch disjoint state → order-independent; both re-read consent via `checkSafely` so no spurious clear. Topic subscriptions post-revoke are NOT a separate Art-17 gap (memberships bind to the token, not the user; `deleteToken()` orphans them). SecureStorage-on-device tokens in encrypted Keychain/Keystore are arguably not "data held by the controller" but delete anyway (defence in depth).

### 2026-04-27 — third-party HTTPS cert pinning (BUT-427/735/736/769)
`http_certificate_pinning ^3.0.1`. The package's `SecureHttpClient.send()` and the Dio `CertificatePinningInterceptor` are each insufficient alone: `send()` falls through unconditionally (only non-streaming helpers pin) and our hot paths (HttpContentFetcher, OCRExtractionService) use `client.send()` directly → roll our own `BaseClient` overriding `send()`; the Dio interceptor takes one static fingerprint list but Algolia uses 4-5 hosts → per-host config map. Files: `cert_pin_config.dart` (host→pin map, **empty list = wired-but-inactive no-op fall-through** so a misconfigured map can't break unrelated requests), `pinned_http_client.dart`, `pinned_http_client_factory.dart`, `algolia/algolia_pinning_interceptor.dart` (lives next to algolia repo because `dio` is transitive of `algoliasearch` only). `pinsForHost(host)` returns `List<String>` — empty NOT null for unknown hosts (callers crash on null; unit-pinned). Telemetry `ssl_pin_mismatch` logs `host`+`error_kind`; the request still throws (soft-fail = no crash, NOT accept-unverified). **Fail-loud needs `throw`/`StateError`, not `assert` (stripped in release):** `CertPinConfig.assertReleaseModeSafety()` gated on `kReleaseMode`, called before `Firebase.initializeApp` in main.dart (debug/profile skipped — devs run empty pin maps). **DI singleton pattern (BUT-735):** register one pinned `http.Client` in `core_module.dart` with `dispose: (c)=>c.close()` (GetIt owns lifecycle); consumers inject with `_httpClient ?? PinnedHttpClientFactory.create()` fallback and `shouldCloseClient = _httpClient == null` (NEVER close the injected DI client). Pinning is no-op-safe at this layer (short-circuits for unpinned hosts). **Concurrency guard (BUT-736):** a single nullable `Future<X>? _inflight` "wait for previous" guard collapses under concurrent callers (B clobbers A's ref; A's `finally{_inflight=null}` nulls B's slot → C bypasses). Fix: `Map<Key, Future<X>>` keyed by the discriminator the serialization needs (host — Alamofire is per-host on iOS, not global), clearing the entry only `if (identical(_inflightByKey[key], future))`. Race test: inject stub returning `Completer().future`, fire N concurrently, complete in reverse order.

### 2026-06-28 — cook_event attendeeMemberIds: opaque ids in owner-scoped log require no household validation at repo layer
`CookEvent.attendeeMemberIds` stores account-userIds and DinerProfile ids (opaque strings) inside `recipe_cook_events/{userId}/events/{eventId}` — owner-only path-scoped by both rules and `eventsCollectionForUser(requireCurrentUserId())`. **No household-membership validation is required at this layer because:** (1) the field is in the cooking user's own private log — no other user can read it; (2) a rogue client supplying arbitrary ids causes noise only in the submitter's own record, with no cross-user data exposure; (3) the who's-eating UI (Phase 3) is the right enforcement point; wiring household-membership reads into the cook-event repo would create unnecessary coupling. **GDPR coverage is complete without new code:** `exportCookEventsByUser` returns raw `{id,data}` maps that include `attendeeMemberIds` when present; GDPR cascade that deletes `recipe_cook_events/{userId}/events` subcollection removes attendee ids wholesale (no fan-out into household collections needed). **Backward-compat write pattern:** `if (attendeeMemberIds.isNotEmpty) 'attendeeMemberIds': attendeeMemberIds` in `toFirestore()` keeps historical docs at their original two-field `{recipeId, cookedAt}` shape — clean sparse-field approach, `safeStringList` default-`[]` on read handles both shapes. Server-side size guard (50-element cap) lives in rules; no Dart-layer cap is needed (rules are the authoritative gate; server rejects oversized writes).

### 2026-04-27 — push notification deep-link routing (BUT-641)
Replaced an inline main.dart lambda (legacy payloads without `route` crashed; no analytics) with a `NotificationDeepLinkRouter` + `NotificationRoutes.{recipe,friendRequest,commentThread,cookingSession,menuVoting,winback}` constants (the canonical strings CF senders must align against). Three-state model: `route` null/empty (legacy) → home + `notification_payload_missing_route`; unknown route (client-server drift early-warning) → home + `notification_payload_unknown_route`; known route → navigate + `notification_opened`. Router (not the wrapper) owns the missing-route default. **Test gotcha:** `Mock implements NavigatorState` needs an explicit `toString({DiagnosticLevel minLevel})` override (NavigatorState mixes in Diagnosticable; mocktail's default toString doesn't satisfy the signature — compile error; same wall for `Fake implements NavigatorState`).

### 2026-04-30 — server-side notification gate review patterns (BUT-647/645/638)
Recurring CF failure modes: **(1) Producer-consumer drift** — when a CF header says "client writes here", grep `lib/` for the producer in the same commit; no producer = the consumer ships dead (and default-deny blocks it anyway). For analytics already in BigQuery via Analytics export, read from BigQuery; if Firestore is required, ship a callable `recordX` (AppCheck + rate-limited) and wire the client same sprint. **(2) PII-bearing queue collections need `expireAt` AND a GDPR cascade — neither is automatic.** Checklist for any new server-written collection with userId/PII: (a) `expireAt` field, (b) gcloud TTL policy in a runbook, (c) `on-user-deleted.ts` cascade (collectionGroup + batched delete, BATCH_LIMIT=500 chunking), (d) single-field index on `userId` for the cascade. **(3) Compound `==` + range queries need composite indexes** — grep `firestore.indexes.json` for the collection in the same review; missing = first invocation throws `FAILED_PRECONDITION` forever. **Drainer poison-pill rule:** a scheduled drainer that claims `pending→delivered`, sends, rolls back to `pending` on failure loops forever on permanent failures — always add a max-attempts cutoff flipping to `status:"failed"` with `failedAt`/`lastError` (`attempts >= MAX ? "failed" : "pending"`). **Region pinning:** `setGlobalOptions({region:"europe-west1"})` in `index.ts` covers every export; removing it silently flips unconverted exports to us-central1 (EU privacy regression) — treat removal without per-function migration as Critical. **Fail-open vs closed is per-domain:** notification RC flags fail open (over-sending a few during an outage beats muting all pushes); LLM kill-switch fails closed for the user (LLM over-send is expensive). **Region-pinned callable footgun:** clients must use `FirebaseFunctions.instanceFor(region:'europe-west1')` — grep for `FirebaseFunctions.instance` (without `For`); the default 404s against us-central1 in prod. **Deterministic doc id** `<userId>_<notificationId>` (slash-sanitized) with read-then-set honestly reports `recorded=false` on dedup. Round-2 follow-ups (Medium): cap unbounded `route` field length; add rate-limit/AppCheck parity to new callables; carry the gcloud TTL command in each new producer's docstring. Producer-consumer regression-guard test wires the REAL writer + REAL aggregator against a shared fake DB (neither mocked) so removing the writer flips CTR=0 → red.

### 2026-05-04 — system/config consumers have asymmetric fail-modes + module-scope cache lifetime
Two independent CF paths read `system/config`: kill switch (`structure-recipe.ts`) lets a Firestore error propagate → outer catch → `internal` HttpsError → **fail closed for the user** (operator override not silently bypassable); global rate limits (`rate_limiter.ts loadGlobalLimits`) catch inside the loader → defaults (1000/10000) → **fail open against operator overrides** (cold-start instances revert during a Firestore blip). Acceptable because `aiEnabled=false` is the primary lever and lives in the fail-closed path. When reviewing either loader, preserve the asymmetry intentionally. **Module-scope cache:** `rate_limiter.ts cachedGlobalLimits` is never invalidated — lifetime = warm-instance lifetime (~15min idle but HOURS under sustained traffic, not the runbook's optimistic "~30 min"). Operators flipping caps mid-incident should expect some warm instances to serve the old value for an hour; the kill switch bypasses this (gates upstream of `checkGlobalLimit`). For module-scope caches in functions/, prefer sub-minute TTL or explicit "redeploy to refresh" docs — not silent indefinite caching.

### 2026-04-30 — deterministic doc id is the idempotency primitive for daily aggregators (BUT-605)
Scheduled CF emitting one row per (entity, bucket) per UTC day: use `<entityId>_<bucketKey>` doc id + `set()` (full overwrite), not `add()` — re-running on the same UTC day becomes a no-op overwrite, not duplicate rows (e.g. `track-retention.ts` `<userId>_d<N>`). **Single-writer invariant:** a second writer to the same path silently last-write-wins; add a comment at the first writer documenting the assumption.

### 2026-05-01 — prefer explicit list rewrites over FieldValue.arrayRemove in cascade scrubs (BUT-747)
`batch.update(ref, {field: FieldValue.arrayRemove([uid])})` is silently dropped by `fake_cloud_firestore` (the doc still contains the UID after commit → residual tripwire fails). For any cross-user array scrub in cascade code, prefer read-modify-write `raw.where((id)=>id!=uid).toList()` then `batch.update` with the plain list — same single-update cost on real Firestore, but the test fake exercises the same branch. (Same lesson as the dotted-field `_scrubGroupWeeklyMenuPlans` note.)

### 2026-05-01 — field-name canonicalisation between writer + read-only gateway (BUT-748)
Root cause: `FirebaseBlockRepository` writes `blockedId`; `exportIncomingBlocks` queried `blockedUserId` → every GDPR Art-15 export silently returned zero incoming blocks. **No migration needed** because the wrong field was only ever READ. **Diagnostic for similar cases:** grep the literal quoted field-name across `lib/` + `functions/src/`. If the only hit outside the broken reader IS the broken reader, the fix is read-side only; if a writer uses the alternate name, plan a migration.

### 2026-05-01 — recipient self-scrub rule pattern + the simultaneous-removal residual (BUT-747)
For shared docs with a `recipients` array (`menus.sharedToUserIds`), Art-17 requires recipients to remove their own UID from foreign-owned docs. Recipient branch needs three guards: `in` BEFORE (currently on the share), `!in` AFTER (not on it after), `affectedKeys().hasOnly([field])` (no other field changes). **Known residual (Medium, not Critical):** the rule does NOT enforce that OTHER UIDs are preserved — a malicious recipient can submit `[]`, booting everyone (griefing, not data loss; owner can re-add). Tightening = symmetric-difference CEL (`request...toSet() == resource...toSet().difference([auth.uid].toSet())`) at extra rule cost. The production cascade (`_scrubInboundSharedMenus`) always writes `raw.where((id)=>id!=userId).toList()`, preserving others — the gap only matters against a malicious client. Test pins "recipient cannot ADD" + "cannot remove OTHER while keeping self"; add the simultaneous-self+other case before tightening.

### 2026-05-04 — symmetric-difference CEL idiom for self-only set edits (BUT-464)
For non-owner-member updates to a member array (`users/{uid}/friend_categories/{cat}` `friendUserIds`): `before.toSet().difference(after).union(after.toSet().difference(before)).hasOnly([request.auth.uid])` — "only the requester's UID may move in/out." Matrix: self-add/self-remove/no-op pass; foreign-add/foreign-remove/self+foreign/self-swap fail. Always combine with `affectedKeys().hasOnly([...])` so a member can't piggyback arbitrary field writes onto a legal self-edit. Limitation: gated on `resource.data` (BEFORE), so a non-member can't self-add — if "accept invite without owner write" is ever needed, add an invite-token branch. Hand non-trivial set-edit rules to `firestore-rules-tester` for emulator tests of every matrix cell — reasoning passes aren't a substitute.

### 2026-05-01 — member-gated collectionGroup queries must run BEFORE membership deletion; or use an admin CF (BUT-732)
In `removeFromSharedContent`, deleting the user's `members/{uid}` docs (step 3) drops their `isSharedMember` access, so a later `collectionGroup('engagements').where('userId',==,uid)` (step 4) permission-denies on non-owned content — and Firestore ABORTS a collectionGroup query on the FIRST per-doc rule failure → engagement scrub silently fails. **Rule of thumb for GDPR cascades:** query every membership-dependent collection BEFORE deleting membership rows, or move the cascade to an admin-SDK CF. **BUT this case is actually safe** because `firestore.rules:1552-1554` declares a top-level wildcard `match /{path=**}/engagements/{userId} { allow read: if auth.uid == userId; }` INDEPENDENT of the inner `hasSharedAccess`-gated block — Firestore's permissive-OR across matching templates authorizes the self-scoped collectionGroup query even after membership deletion, so order doesn't matter here. **Use this wildcard pattern for any self-scoped scrub where doc-id == the user's UID.** Required collectionGroup index `engagements.userId` (matches `members.userId`/`activeUsers.userId` precedent: both `COLLECTION` and `COLLECTION_GROUP` ASCENDING scopes) — without it the cascade errors `failed-precondition`. **Legacy flat `sharedWith` array** on `shared_content` CANNOT be scrubbed user-side (`update` rule permits only the `sharedByUserId` owner or a member-subcollection participant; a recipient-only-in-array has neither) — the user-side op must silently no-op (documented) and report success (failing the whole deletion strands the user mid-erasure); cleanup runs in an admin-context CF (see BUT-753). **`firestore.rules` untouched ⇒ no rules-tester handoff** — a new collectionGroup query relying on an EXISTING rule changes no branch; required-marker triggers key on the `firestore.rules` file diff.

### 2026-07-03 — pooled-ratings Incr 5: whole-subcollection GDPR pair + pseudonymous-not-anonymous labelling [reviewed CLEAN]
`canonical_rating_events` (`users/{uid}/canonical_rating_events`, doc-id = poolKey, CF/Admin-SDK-only writes) added to BOTH the deletion cascade and the Art-15 export in one increment. Reviewed clean on all five GDPR/security axes; reusable notes:
- **Whole-subcollection erase ⊇ export is the cheapest correct pair.** Because it is a pure `users/{uid}/*` subcollection (not a top-level userId-scoped collection), erase = one string appended to the `subs` array in `deleteUserSubcollections` (loop is `userDoc.collection(name).get()` + `batchDeleteAll`, inherently uid-scoped, retry-safe no-op on empty) and export = one `_queryList` read over the same subcollection returning every doc's every field (`sanitizeForJson(e['data'])`). No per-field filter to keep in sync (unlike the BUT-1396 `ownerId`-vs-`userId` field-pair trap or the BUT-1450 OR-owned split) — the whole doc is both erased and exported, so the pair is trivially in agreement. Verify future edits don't add a projecting `.select()` to either side, which would break the ⊇.
- **Residual probe is correctly subcollection-shaped, NOT `where('userId'==)`.** `db.collection('users').doc(uid).collection('canonical_rating_events').count().get()` — avoids the `realtime_recipes` wrong-field trap where a no-op `userId` filter matches zero and hides survivors. The probe's own catch does `residual += 1` → `residual_data_detected` in `failedCollections`, so a probe FAILURE is fail-closed (treated as leftover), not silently swallowed. Correct.
- **Art-15 section is ALWAYS present, even at zero events.** The future is unconditionally added to the export fan-out map (`'pooled_rating_events': ...`); `exportPooledRatingEvents` returns `{pooled_rating_events:[], total_count:0, note}` for a user with none and a `{'error':...}` map (not a throw) on failure — the section never vanishes, so right-of-access holds for a user who never rated.
- **Ownership guard intact:** `exportCanonicalRatingEvents` → `_queryList` → `_guardSelfExport` → `validateOwnership` (the BUT-501 gateway choke point) before any network read; no cross-user path. `getLimitForType('canonical_rating_events')` → explicit 1000, and falls back to `defaultBatchSize` safely for any unmapped type.
- **GDPR-settled: this store is PSEUDONYMOUS, not anonymous (decision 12 / Breyer C-582/14).** Every new comment, docstring, the export `note`, and the collection-constant comment consistently say "pseudonymous, not anonymous" — none mislabels the events store anonymous. Only the uid-free aggregate (`canonical_recipe_stats`) is anonymous. The poolKey is a reproducible content hash tied to the uid, so the event is personal data → correctly carries full Art-15/17 coverage. Keep this labelling discipline on any future edit; calling the events store "anonymous" would be the failure mode that justifies stripping GDPR coverage.
- **Deletion recomputes pools via the existing onWrite trigger, no explicit call, no loop.** Each batched delete fires `onPooledRatingEventWritten` (onWrite fires on delete), which recomputes `canonical_recipe_stats` — the trigger writes the aggregate doc, never `canonical_rating_events`, so there is no re-trigger loop and no double-delete. (Cross-checked against accepted-deviations: the frozen-only / no-edit-detachment design and the mirror-CF rare-edge accepts are unrelated to this cascade path — nothing here re-flags them.)

### 2026-05-02 — admin-context cascade pattern + legacy sharedWith admin CF (BUT-753)
Canonical admin cascade shape: `cleanup<Thing>WithDb(db, userId)` test seam + thin `cleanup<Thing>(userId)` wrapper closing over module-level `db = admin.firestore()`, running inside the existing `onUserDeleted` v1 auth trigger (region inherited, no separate hook), using `admin.firestore()` (rules bypassed — the whole point, since the owner-or-member gate blocks the recipient's own client from scrubbing their flat-array entry), chunked at BATCH_LIMIT=500 with `FieldValue.arrayRemove(userId)` (idempotent — no-op when absent), best-effort per-chunk try/catch that logs+resets+continues (idempotency makes partial-failure-then-retry safe). **Use top-level `where("sharedWith","array-contains",userId)` NOT a collectionGroup sweep** — only `shared_content` used the flat array; a CG sweep burns reads on irrelevant collections (document this in the seam doc-comment so a future agent doesn't "improve" it to a CG sweep). **Best-effort + idempotency is the correct GDPR-cascade trade-off** — Art-17 "without undue delay" is better served by partial-then-retry than total-failure-then-retry.

### 2026-05-21 — cross-user cascade audit pattern (BUT-455/886)
A CF triggered by `auth.user().onDelete` that cascades writes onto OTHER users' docs (Art-17) needs a paired `audit_logs` row per cross-user mutation (`functions/src/cleanup/cascade-audit-log.ts`). **In-batch staging** (`stageCascadeAuditEntry`) is the correct transactionality — the auditable claim is "we made this write"; if it rolled back there's nothing to audit (a separate best-effort write would create false positives). Schema matches existing writers: top-level `userId/operation/resourceType/resourceId/granted/timestamp/metadata`; existing compound indexes cover it (no new index). `granted: true` (system-authorized, not a denial), `metadata.actor='system'`, `reason='gdpr_article_17'`, `targetUid`=the OTHER user; `userId` top-level = the user being deleted. **Admin SDK bypasses rules** — no `firestore.rules` change for system cascade writes (the rule only gates client-initiated `audit_logs.create`). `on-user-deleted.ts` is the single cascade entry point (the ticket-cited social/profile deletion-ops paths don't exist server-side). **Batch-limit accounting:** each audited write doubles per-item op count → cap iteration at `BATCH_LIMIT/2 = 250`. **`commitInChunks` counts ITEMS not OPS** — a `mutate` callback staging two ops/item (delete + audit) hits 1000 staged ops before the first commit, blowing the 500 cap. Affected strict-mode `cleanupNotificationQueuesWithDb` is highest-impact (501st item → whole cascade throws → onUserDeleted retry-loops forever). Fix shape: `opts.opsPerItem?: number` (default 1), gate on `batchCount * opsPerItem >= BATCH_LIMIT`. **Detection rule:** any `commitInChunks(... (batch,item) => {...})` whose body has >1 `batch.*` call MUST pass matching `opsPerItem`. Hand-rolled loops already use `X_PER_BATCH = floor(BATCH_LIMIT/2)`; `cascadeArrayRemove` already computes `perChunkCap` correctly.

### 2026-05-08 — commitInChunks helper: best-effort vs strict semantics (BUT-816)
`functions/src/shared/batch-update.ts` `commitInChunks(db, items, mutate, {label, strict?})`. Semantics to preserve at call sites: PII-tombstone/anonymize cascades (BUT-466 sharedByDisplayName, BUT-781 report anonymize) = best-effort (monotonically idempotent, retry next run); notification-queue purge (BUT-647) = `strict:true` (a partial purge leaves PII rows; abort+retry is correct). `opts.label` is mandatory (self-identifies every chunked op in logs — keep required). Returns `queued` (enqueued), NOT commits-succeeded — at least the GDPR cascade-result reporter uses this count; don't change without auditing callers. Helper doesn't select/scope refs — mis-use only via a cross-tenant `items` list (same risk as raw `db.batch()`).

### 2026-05-04 — denormalised PII pairs travel together (BUT-466)
`shared_content` carries BOTH `sharedByDisplayName` AND `sharedByAvatarUrl`; BUT-466's tombstone cascade cleared the name but missed the avatar (recipient UIs render the deleted user's face next to "[Raderad användare]" after Art-17). Avatar URLs are themselves linked PII. **Pattern: when tombstoning denormalised author/sharer metadata, audit the writer for ALL fields sharing the noun prefix (`sharedBy*`, `authorName*`, `createdBy*`) — they're written together and must be cleared together.** Use `FieldValue.delete()` for the avatar (no neutral string fits), locale-aware tombstone for the name; the idempotency check must verify ALL fields. **Tripwire:** add a positive assertion in `account_deletion_residual_test.dart` iterating the full denormalised-field set, so it fails the day someone adds a 4th `sharedBy*` field without extending the cascade.

### 2026-05-06 — anonymize (don't delete) rows that are also someone else's GDPR evidence (BUT-781)
BUT-781 step 13 anonymizes `/reports` rows where `deletedUid == contentOwnerId` (`contentOwnerId → null` + `contentOwnerAnonymizedAt` tombstone) rather than deleting — the report is the *reporter's* Art-15 evidence; deleting it erases the reporter's record to satisfy the deletee's Art-17 (net negative for the reporter). **Generalize: any document with cross-subject GDPR claims (jointly authored, evidence) anonymizes the deletee's identifiers, not deletes the row.**

### 2026-04-30 — production-ServiceLocator bridge for cascade unit tests + BUT-671 residual tripwires
Unit tests constructing the real `AccountDeletionService` against `FakeFirebaseFirestore` MUST bridge the production ServiceLocator: `production.ServiceLocator.initialize(DIContainer())` in setUpAll (after `BaseUnitTest.setupUnit()`), then register typed repos the cascade resolves via ServiceLocator (BlockRepository especially) against the SAME fake firestore. Without it, `ServiceLocator.get<...>()` inside the cascade throws "not initialized" → caught → step lands silently in `failedCollections` → a green test that proves nothing. **BUT-671 residual test asserts production GDPR gaps POSITIVELY as tripwires** (a future fix flips the assert red and forces a doc update): pattern `_expectMatchingExists` (TRIPWIRE) → `_expectNoMatching` once fixed; keep the file-header comment style (link ticket, name the cascade method, explain why the assert flipped) so the test reads as a history of the bug. Gaps surfaced & later fixed: top-level `menus where sharedByUserId==uid` not wiped (BUT-746); `menus.sharedToUserIds` arrays not scrubbed (BUT-747); `blocks` field-name mismatch `blockedId` vs `blockedUserId` (BUT-748). Don't fix in the same commit as the tripwire test (scope guard).

### 2026-05-01 — production residuals invisible to FakeFirestore; permission-denied must be distinguished in cascades (BUT-746/747)
**(1)** Production residuals written against a production-side collection (top-level `menus`) aren't visible to `FakeFirebaseFirestore` (it doesn't run rules) — the BUT-671 tripwire is exactly the design for this. **(2)** Cascade code writing to top-level (cross-user) collections MUST handle `permission-denied` separately from transient errors (the rules engine is the only line of defense against cross-user write bypass): `on FirebaseException catch (e) { log(e.code); if (e.code == 'permission-denied') rethrow; } catch (e) { log; }` — permission-denied bubbles up → parent returns false → `failedCollections` → user-visible failure → operator pages a human; network/quota gets the best-effort swallow. The split is "audit log shows we tried" vs "audit log shows we silently failed Art-17."

### 2026-05-01 — analytics image_format is not new fingerprinting; AnalyticsRepository is not mixin-subject (BUT-662)
Tagging `image_format` (`jpeg|png|heic|webp|gif|unknown`) on import/extraction events adds no fingerprinting beyond the existing `platform` property (HEIC ≈ iOS, already covered; a 6-way bucket inside a 3-way one). Format strings come from magic-byte detection, not user-typed — no PII; `_piiHashKeys`/`_piiDropKeys` don't grow for closed-set enums. Consent: `logImportStarted`/`logImportSuccess` are gated via `hasAnalyticsConsent()`; `logExtractionError` is intentionally UN-gated (error tracking, same exemption as auth events — a standing GDPR Art-6(1)(f)-vs-consent question; current posture: errors exempt, values bounded — URL host only, error ≤100 chars, bucketed). **`AnalyticsRepository` wraps the Firebase Analytics SDK, NOT a `BaseFirebaseRepository<Model>` — it has no validate*Permission and is NOT subject to PermissionValidationMixin; don't flag the mixin's absence as Critical.** (Same non-adopter category as the infrastructure repos in BUT-504 and `permission_cache_invalidator.dart`.)

### 2026-05-01 — Algolia EU cluster + analytics-consent gate (BUT-580)
**(1) EU-cluster invariant (GDPR Ch.V):** `AlgoliaSearchRepository` runs a runtime check at construction (NOT `assert` — no-ops in release): app id must end `-eu`, else `ArgumentError` and `SearchModule.initialize()` stays on Firestore. Escape hatch `assertEuCluster:false` for out-of-band-verified shared clusters. **Never trust `assert` for cross-border guards.** **(2) PII in queries:** audited `searchRecipes/searchUsers/getSuggestions` — none pass `userToken`/`clickAnalytics`/`analyticsTags` (grep-confirmed); queries reach the cluster anonymously (re-grep on any Algolia change). **(3) Consent gate:** Algolia personalisation is in the `analytics` bucket — gate in `SearchModule.initialize()` via `_hasAnalyticsConsent(GetIt)` returning false pre-sign-in OR on denial; default delegate is `FirestoreSearchRepository` so denial silently falls back. Trade-off: consent granted post-startup needs an app restart (acceptable in beta; hook `onConsentChanged` for live-flip later). Test the constructor's EU check directly, not `initialize()` end-to-end (it reads compile-time `String.fromEnvironment` + instantiates Firebase).

### 2026-05-01 — multi-listener pattern for cross-module mid-session signals (BUT-752/754)
`ConsentService.add/removeConsentChangeListener` is the canonical broadcast pattern. Three invariants: iterate a COPY (`List.of(_listeners)` — listeners may self-unregister during dispatch); try/catch each listener individually (one bad listener can't abort siblings); cache state BEFORE notifying (`_cachedConsent = consent` before the loop so a callback reading `hasConsent` sees the new value). **Listener-leak rule:** long-lived DI singletons (SearchModule) may register without removing (leak bounded by container lifetime, intentional); shorter-lifecycle services MUST remove in dispose. Guard double-subscribe with a `_subscribed*` field and remove before nulling; re-entry during dispose is safe if the handler short-circuits on the nulled field. Two async consent listeners (FCMService + NotificationService) dispatch in registration order but run interleaved on the microtask queue — fine when they touch disjoint state.

### 2026-05-01 — `:redacted` token in path scrubbing is collision-safe (BUT-692)
`scrubUrlParams` writing literal `:redacted` to opaque path segments is safe: redaction threshold is segment length ≥20 so a real `:redacted` (9 chars) never re-triggers; output goes to LLM text input (no URL parser downstream); first-segment `:` is unambiguous given a verified scheme precondition. No action.

### 2026-05-04 — scrubUrlParams fragment-token leak: trace URL-as-data-field, not just URL-as-target (BUT-534/765)
BUT-534 preserved URL fragments justified by "fragments aren't transmitted to servers" (RFC 3986 §3.5) — **correct ONLY for HTTP fetches, FALSE for the actual call paths** where scrubbed URLs travel as JSON string fields to `httpsCallable` → Cloud Logging → Gemini prompts. **Rule: when reviewing scrubber changes, trace BOTH the URL-as-target AND URL-as-data-field paths; the "fragments don't transmit" axiom applies only to the former.** Fixed by BUT-765 `_scrubFragment`/`scrubFragment`: length <16 → keep (`#ingredienser`); UUID-shaped whole fragment → `:redacted`; else replace each `[A-Za-z0-9]{16,}` run → `:redacted`. Acceptable residual: JWT tail after a `_` shorter than 16 chars survives (not the secret material; signing-input segments redact wholesale). **Defence-in-depth Dart↔TS parity rule: verify the regex SOURCE STRING is byte-identical** — Dart raw strings (`r'...'`) and TS literals diverge on backslash handling; `caseSensitive:false` (Dart) and `i` (TS) must be on the same instances.

### 2026-05-04 — bound rawValue length in LLM enum-drift logging (BUT-546)
`logger.warn` for closed-domain enum drift (`validateDifficulty` in `gemini-client.ts`) uses `JSON.stringify(value)` for non-string fallback — **unbounded** (a regressed Gemini response could nest an object and inflate Cloud Logging cost). PII risk is nil (closed-domain slot, model vocabulary not user text, schema-enforced output). **Fix: cap at ~200 chars** (`(typeof value==="string"?value:JSON.stringify(value)).slice(0,200)`, same as the 100-char error truncation). **Pattern: enum-drift telemetry is fine; always bound the raw payload length even when the field is "supposed to be" small.**

### 2026-05-04 — removing client-emitted timestamp params from Firebase Analytics is GDPR-neutral; ADDING them is the smell (BUT-518)
Removed 9 redundant `'timestamp': clock.now()...` emissions — Firebase Analytics auto-stamps `event_timestamp_micros` server-side; grep confirmed no consumer reads `params.timestamp`; the param never landed in Firestore/audit-logs/user-storage. `recipeDeleted` correctly keeps `created_at` (data about the deleted entity) and drops only the redundant now-time. **Rule: removing them is always safe; adding them duplicates the platform auto-stamp and creates joinable identifiers if combined with high-cardinality fields.**

### 2026-06-13 — schemaVersion is a benign additive int; no security/GDPR action required (BUT-648)
Six core models (`UserProfile`, `RecipeCore`, `WeeklyMenuPlan`, `UnifiedShoppingList`, `PersonalTag`, `SharedMenu`) gained `final int schemaVersion` (default 1). Security review verdict: no Critical/High findings. Pattern notes: (1) `?? 1` default on every `fromMap`/`fromFirestore`/`fromJson` path — old docs never throw on missing field, lazy-compat is correct. (2) `toFirestore()` always emits the field — fine, it's non-PII metadata. (3) `UserProfile` export via `FirebaseDataExportRepository` now silently includes the field in Art-15 exports — benign (schema metadata is correctly exportable), but note as a silent payload addition. (4) Art-17 cascade deletes entire docs; no field-selective change to cascades needed. (5) Rules tests (M20/M21) scope correctly to owner-write paths only — no insecure assertion. **General rule: a `final int schemaVersion = 1` / `?? 1` default field in a Firestore model is a no-op from a security standpoint; review focus should be on whether OTHER fields changed in the same serialization path (drop/alter risk) and whether `toFirestore` widened the payload with real PII.**

### 2026-06-17 — admin-only direct-query methods: rules-only authorization is acceptable; logPermissionCheck not required
For methods that are admin-only by construction (the Firestore rule enforces `isAdmin()` on both read and update), bypassing the per-doc `validateReadPermission`/`validateUpdatePermission` helpers is correct and intentional — those helpers enforce owner-only access and would break admin-reads. The established precedent is `ReportService.watchOpenReports` (direct `.collection.snapshots()`, no client validator). Pattern confirmed for `FirebaseFeedbackRepository.watchFeedback` + `updateStatus`. `logPermissionCheck` is not required for admin-inbox ops: the admin custom claim is the trust boundary; `requireCurrentUserId()` confirms authentication; the rule enforces the claim server-side. Gap worth a follow-up ticket: admin triage mutations (status changes) are not written to `audit_logs` — for beta this is Low, but as admin tooling matures a `audit_logs` entry per `updateStatus` call ("admin X triaged feedback Y to Z") aligns with the security-critical operation guidance.

### 2026-05-04 — auth-state reads go through PermissionService, not FirebaseAuth.instance (BUT-510)
`di_container.dart` Step 2.5 (cold-boot user-scope restoration) now reads `PermissionService.currentUserId` (with `isRegistered<PermissionService>()` guard, defaulting `hasPersistedUser=false` for minimal test setups) instead of `FirebaseAuth.instance.currentUser`. Security-neutral, correctness-positive: same auth state, enforces the convention that **only PermissionService is the canonical auth surface for app code** (direct `FirebaseAuth.instance` reads bypass the test/mock seam). Two legitimate exceptions: PermissionService's own impl and the FirebaseAuthRepository wrapper. **Review heuristic:** grep `FirebaseAuth.instance.currentUser` outside those two files — each hit is Medium (testability), upgrade to High if in a security-critical decision path (permission gate, audit identity, export ownership).

### 2026-05-04 — sprint-I: static test seams, FirestoreBootstrap parity, consent-renewal data source (BUT-446/506/465)
**Static-class test seams (FCMService):** `static FirebaseMessaging? _messagingOverride` + `_getMessaging()` fallback + `@visibleForTesting setMessagingForTest` is acceptable for all-static services. Risks: `@visibleForTesting` is analyzer-advisory only (solo-dev, warning suffices); the override is process-global so each `tearDown` MUST reset to null — document the contract in the test file. **FirestoreBootstrap parity (BUT-506):** the extracted helper preserves the original error-string filter exactly (`INTERNAL ASSERTION` || `Unexpected state`) and the hot-restart "settings already applied" swallow; the `kIsWeb` guard around `_recoverWebPersistenceIfCorrupted` is correct (`clearPersistence()` differs on native — needs SDK terminated first). **Consent-renewal data source (BUT-465):** the renewal *gate* check at startup correctly reads `userService.currentUserId` — the version comparison needs only auth identity (consent doc keys off uid), not the profile payload; the `permissionService.currentUserId` rule applies to permission/ownership checks. The post-frame consent-dialog auth race (sign-out between reading uid and `needsConsentRenewal()`) worst case = a dialog flash for a logged-out user (re-reads consent before saving) — no leak, document as a known minor race.

### 2026-05-05 — recipe repo facade extraction is permission-safe (BUT-536)
`RecipeTagOperations`/`RecipeQueryOperations`/`RecipeGdprExportOperations` carved out of `firebase_recipe_repository.dart`. Safe because: modules take `String? userId` as a parameter (don't read auth state), early-returning empty on null (preserves "unauthenticated → empty list" rather than throwing PERMISSION_DENIED); all collection access goes through the injected `getCollectionForUser` callback (no module can construct another user's path); the GDPR module receives `requireCurrentUserId` + `validateOwnership` as injected callbacks and both export methods call `validateOwnership` BEFORE any read (cross-user export structurally impossible); modules are private `late final` (reachable only via the repo). Note: **`validateOwnership` does NOT itself emit `logPermissionCheck`** — it only warns on mismatch; the "every custom permission check must call logPermissionCheck" CLAUDE.md rule applies to the four base `validate*Permission` hooks (unchanged here).

### 2026-05-04 — comment line-number drift in cascade code
`on-user-deleted.ts:143` referenced `firestore.rules:515-518` for the `shared_content` update gate; post-BUT-659 it moved to 554-557 (515-518 is now the friend-request create rule). **Prefer referencing rules by collection path + rule type ("the `shared_content` update gate") not line number;** when a line number is genuinely needed for a breadcrumb, add a trailing grep-able comment (`// see firestore.rules match /shared_content/{contentId} allow update`).

### 2026-07-03 — pooled-rating events → GDPR paths (decision 12): clean; recompute-via-trigger + subcollection probe pattern
Increment 5 wires `users/{uid}/canonical_rating_events` (server-only-written per-user subcollection, doc-id = poolKey) into the Art-17 cascade + Art-15 export. Reviewed clean, no findings. Reusable patterns confirmed:
- **Subcollection residual probe, NOT a `where('userId'==)` probe.** The new probe in `probeResidualData` is `db.collection('users').doc(uid).collection('canonical_rating_events').count().get()` — subcollection-shaped. This is correct precisely because the collection has NO `userId` field (identity is the path + doc-id), so the `realtime_recipes`/`notification_delivery` `where('userId'==)`-matches-zero trap (2026-06-30) does not apply. Probe runs AFTER `deleteUserSubcollections` and AFTER `deleteUserProfile`. **Key Firestore fact that makes the ordering safe: deleting the parent doc `users/{uid}` does NOT delete its subcollections** — so if the cascade's subcoll delete missed anything, the post-root-delete probe still reads the orphaned subcollection docs and pushes `residual_data_detected`. Correct.
- **export ⊇ erased holds on the same physical docs.** Deletion erases the whole subcollection (`userDoc.collection('canonical_rating_events').get()` → `batchDeleteAll`, chunks 500); export reads the same subcollection via the `_guardSelfExport`→`_queryList` gateway returning `{id: poolKey, data: full doc}`. Same path, same docs, all fields (`poolKey/ratingValue/recipeId/createdAt`) covered. Section is **always present even when empty** because `data_export_service` unconditionally adds `'pooled_rating_events'` to the fan-out and `exportPooledRatingEvents` catches internally (returns a map, never throws) — so `Future.wait(..., eagerError:true)` can't drop it and a zero-event user still gets `{pooled_rating_events:[], total_count:0}`. Art-15-for-a-user-with-none satisfied.
- **Deletion recompute is delegated to the existing Stage-B `onDocumentWritten` trigger — no explicit recompute call, and that is CORRECT.** `onPooledRatingEventWritten` (document `users/{uid}/canonical_rating_events/{poolKey}`, `retry:true`, NOT feature-flag gated) fires on delete too; it recovers `poolKey` from `event.params` (after-snapshot is gone on delete) and schedules a debounced recompute. `updatePooledRatingStats` recomputes from a collectionGroup aggregate over REMAINING events, so an erased rater shrinks the public average; empty pool → count 0/average null written (reader gates n≥5 → pill disappears, never stale). Sound separation: cascade only deletes, trigger only recomputes — no double-delete, no missed recompute. **Review heuristic: when a cascade erases a subcollection that backs a server-maintained aggregate, confirm the aggregate's write-trigger is (a) `onDocumentWritten`/`onDocumentDeleted` not `onCreated/onUpdated`, (b) NOT flag-gated (a retraction must always reconcile even when new-event creation is off), and (c) recovers its key from `event.params` not the after-snapshot.**
- **Pseudonymous-not-anonymous labeling is present and correct (decision 12 / Breyer).** Comments in all five files and the export's user-facing `note` say pseudonymous; nothing labels the events store "anonymous" (only the uid-free aggregate is). The doc-id poolKey is a reproducible content hash tied to the uid — exporting it in the user's OWN export is fine (it's their data).
- **Accepted, NOT a finding: the 1000-doc export cap (`ExportPaginationHelper`) vs the uncapped deletion.** A hypothetical >1000-distinct-pool user's export truncates (`truncated:true`) while the cascade erases all — the same explicit-cap-plus-truncated-flag pattern already blessed for every capped export section (2026-06-30 entry); disclosed and Art-15-reasonable, do not re-flag. Pure-equality/no-orderBy subcollection read → no composite index (accepted-deviations).

### 2026-05-06 — BUT-781/770/773/769 sprint patterns
**Rate-limit sentinel collections charge an extra read per create:** `/reports` create uses `exists()`+`get()` against `/users/{reporter}/report_throttle/{ownerId}` — `!exists() || ...get()...` still costs 1 read (exists) + 1 (get when present) = 2 reads/create steady-state; document on any future high-frequency collection. **`request.time - duration.value(24,'h')` is the canonical "now − X"** (server-time, no client skew); pair with `lastReportAt == request.time` on the throttle write so the next-create reads a trustworthy timestamp. **Deny orphan self-throttle even if the parent rule already covers it** (`ownerId == auth.uid` blocked on the throttle write — keeps the collection structurally clean). **Subcollection rules must be explicit (no parent inheritance):** `realtime_menus/{menuId}/votes` had no rule block before BUT-773; default-deny silently masked it. **Whenever a new subcollection is added, grep its path in firestore.rules — a missing match block is THE most common rules bug (failure mode is "feature silently broken", not "crash").**

### 2026-05-06 — Storage moderation CFs: edit-refresh `>=`, fail-open when rules are the gate, no AppCheck on triggers (BUT-778/780)
**`shouldReplaceLastMessage` uses `candidate.sentAt >= current.sentAt`** so an edit (same sentAt as original) overwrites the stored snapshot — strict `>` silently drops edit-refresh when the original is still lastMessage; idempotent because the projection of same id+sentAt+content is identical. Close TOCTOU on delete-recompute by reading the replacement query inside the same `runTransaction`; required index `messages(conversationId ASC, sentAt DESC)` present. **`moderate-upload.ts` returning silently on `download()` throw (fail-open) is acceptable because `storage.rules isValidImage()` is the explicit allow-list** (jpeg/png/webp/heic/heif) — the CF only catches MIME spoofing past the rule, never the rule's own invariants; worst case = spoofed-bytes-but-allowed-MIME survives + no audit row; ops should monitor `[moderateUpload] failed to read head bytes` warn rate. Keep the rule+CF MIME allow-list in sync (mirrored comments in both files). **`enforceAppCheck` is meaningful only on callables/HTTPS (where a client token exists), NOT on `onObjectFinalized`/`onDocumentWritten` triggers** (invocation source is GCP itself, no token) — App Check belongs on the write-path callable that produces the trigger event, not the handler. **`storage_upload_rejected` audit shape:** `userId`=uploader uid (or `"unknown"`), `operation:'storage_upload_rejected'`, `granted:false`, `metadata:{bucket,contentType,reason}` (reason codes `unsupported_content_type`/`magic_byte_unrecognized`/`magic_byte_mismatch_declared_X_actual_Y`); NO filename body, NO byte previews; `resourceId` is the object path (already contains uid by convention). `userId='unknown'` is the right tombstone for an unreachable anonymous-upload path (refusing to write the row would be worse) — treat any occurrence as a signal of rule drift or admin-SDK upload.

### 2026-05-06 — SDK-state mirror flags: symmetric fail-closed + replay-on-enable (BUT-786/803)
Repositories mirroring an SDK's internal consent/state flag locally (Firebase Analytics collection-enabled — `FirebaseAnalyticsRepository._collectionEnabled`) must handle the two paths asymmetrically: **enable (deny→allow):** flip the local mirror ONLY after the SDK call succeeds (fail-closed on enable failure — caller denied until next try); **disable (allow→deny):** flip the local mirror BEFORE the SDK call (fail-closed on disable failure — withdrawal is Art-7(3); a silent SDK-throw must not leave the channel open). **Companion: replay on enable** — any value dropped during the deny window (a `setUserId(uid)` suppressed pre-consent) must be replayed when the mirror flips to allow, else the cold-start race (auth listener fires before consent flip) produces a permanent silent drop until re-login. Anti-pattern: flag mutation outside `try` on enable, or inside `try` on disable. Applies to any future telemetry/Crashlytics/Performance/RemoteConfig repo gating user-tied calls on a locally-mirrored flag.

### 2026-05-08 — timestampProvider as test seam in repos is an established pattern, not a bypass (BUT-816)
`firebase_report_repository.dart` adding `super.timestampProvider` and routing `lastReportAt` through `timestampProvider.serverTimestamp()` mirrors `firebase_comments_repository`/`deeplink`/`device` etc. Default `ServerTimestampProvider()` → `FieldValue.serverTimestamp()` in prod; `BaseFirebaseRepository`'s validate*/audit hooks unchanged. Safe by construction when seen added to a repo for tests.

### 2026-05-02 — misc verified-clean reviews (BUT-577/566/733)
**JSON salvage parser DoS (BUT-577):** quote-aware `extractTopLevelObjects` in `gemini-client.ts` is bounded by input length (single O(n) forward pass over a Vertex response capped ~4KB by token limit), monotonic `i` advance (no backtracking/recursion), string-state machine handles `\\`-escape and `"`-toggle — runs only on `JSON.parse` failure (cold path), input already schema-constrained. Not a DoS vector; ReDoS-clean (the one regex is anchored+bounded). Treat Gemini output as adversarial anyway (no eval/Function ctor/backtracking-regex). **ADR-001 cross-reference (BUT-566):** the `structure-recipe.ts` catch comment correctly names the ADR + points to the Dart-side single retry layer and explicitly forbids server retry ("stacking server+client retries multiplies Gemini load under the same rate-limit window") — states contract AND failure mode. **Test infra (BUT-733):** migrate integration tests from mocktail `then(...)` side-effect Firestore stubs to REAL repository against `FakeFirebaseFirestore` + `MockAuthRepository.setAuthState` for ownership (the side-effect pattern "mocks the boundary while replicating the boundary" proves nothing). Caveat: FakeFirebaseFirestore does NOT enforce `firestore.rules` — this is an SDK-level permission-mixin test, not a rules test; rules behaviour is the rules-tester agent against the emulator. **PROMPT_CHANGELOG.md scan:** a new `functions/src/llm/*.md` is in security-review scope despite no executable code — verify no embedded API keys, no internal endpoint URLs (public Linear ticket URLs fine), no PII/sample user text; commit SHAs are not secrets.

### 2026-05-19 — GDPR export: FirebaseFunctionsException code triage (BUT-842)
When a CF backs an Art-15 export and the call site bundles collections via `Future.wait(..., eagerError: true)`, split CF errors: **transient** (return recoverable stub with `error_code` marker, user keeps the other 30+ collections) = `unavailable`/`deadline-exceeded`/`cancelled`/`aborted`/`resource-exhausted`; **fatal-by-design** (abort the whole bundle) = `permission-denied`/`unauthenticated` (masking hides an authz bug), `failed-precondition`/`invalid-argument`/`not-found` (contract violations), `internal` (SDK catch-all; broken deploys would ship empty sections to every user). Defensible only if the partial nature is explicitly surfaced in the bundle (silent partial exports were the BUT-842 root cause). When the data source is the REPOSITORY (not a CF callable) there's no transience dimension — all errors are fatal (a stub `{error:...}` in the bundle is worse than a clean abort+retry). `ComplianceExportException.toString()` omits userId — PII belongs in the structured logger (AppLogger→Crashlytics non-fatal), not in stack-trace surfaces that may reach user-visible error UI.

### 2026-05-22 — BUT-788 server-side account deletion: composition with onUserDeleted
Callable `requestAccountDeletion` plus existing v1 `onUserDeleted` trigger. **Boundary (explicit in code comments):** the callable owns OWN-data (cascade + Storage `users/{uid}/`); the trigger owns CROSS-USER cleanup (reverse friendships, public_profile, feedback storage `feedback/{uid}/`, friend counts, presence). Re-auth gate: 5-minute `auth_time` window for destructive callables (TOCTOU-safe — `admin.auth().deleteUser` is one-shot, idempotent under retry). Audit log written BEFORE auth.deleteUser-triggered cross-user cleanup completes is acceptable for Art-17 (records the synchronously-controlled cascade outcome; cross-user is the trigger's own audit surface). App Check deferral acceptable when re-auth gate + CORS allowlist are present, as a temporary bridge to mobile attestation. **Cascade idempotency rule: every step must be delete / `arrayRemove` / `set-merge` so retries on partial failure converge — avoid `arrayUnion`/counter-increment shapes here.**

### 2026-05-22 — storage/auth error CODE is not PII; bypassing executeServiceOperation is safe IF auth is downstream; no auth-stream race (BUT-971)
**Error codes are safe to log** to analytics — `StorageUploadException.code` (`quota-exceeded`/`unauthorized`/`canceled`), `FirebaseAuthException.code` (`user-token-expired`/`user-disabled`) are bounded enum tokens with no identifier content. **The `message` field IS a leak surface** (Firebase storage SDK occasionally embeds the bucket-relative `users/{uid}/...` path) — log `message` to AppLogger only, NEVER to `logEvent` params (Wave-13 correctly puts only `error_code` in analytics). **Bypassing `executeServiceOperation`** (so `StorageUploadException` survives instead of being swallowed to null) is safe because the repository `_validateUploadPermission` is the authoritative auth gate (audits + throws `PermissionDeniedException`); the dropped pre-flight `requiresAuth`/`requiresNetwork` were UX niceties — only regression is a generic "upload failed" toast instead of a localized message (Medium UX, NOT security). **AuthService stream-error path has no concurrent-sign-in race** — actual auth state (`_currentUser`/`isAuthenticated`) is driven by the auth-state STREAM not by `error`; a stale error string on a successful session is cosmetic. The real risk (setError wiped by forceSignOut's `finally`) is avoided by ordering `await forceSignOut(); setError(...)` (forceSignOut awaits its full body including finally before returning).

### 2026-05-28 — BUT-1132 idempotent shared_content create
Pre-create lookup `.where(sharedByUserId==uid).where(originalRecipeId==X).limit(1)` is SAFE under `shared_content` rules — `allow list: auth.uid == resource.data.sharedByUserId` already restricts the result-set to the caller's own docs, and the repo-layer guard (`sharedRecipe.sharedByUserId != uid → PermissionDeniedException`) runs BEFORE the query. Composite index `(sharedByUserId ASC, originalRecipeId ASC)` leaks no PII (both fields already stored + access-gated; **indexes don't bypass rules**). Legacy `shared_recipes` index is inert (no rule block, never written — Firestore charges nothing for indexes on unwritten collections); safe to defer cleanup. Idempotent re-share preserves original `sharedAt` + snapshot (treated as "add recipients to existing share"); `addMember` `.set()` overwrites `addedAt` for already-present members (minor audit-fidelity loss, acceptable — `sharedToUserIds` retention is the GDPR-controlling state, join-time isn't legally relevant). `addMember` re-reads the doc and throws unless caller is creator — idempotent path inherits this (non-owners can't piggyback).

### 2026-05-29 — BUT-504 service→repository extraction surfaced 4 latent shared_content/notification rule+index bugs
Extracting raw Firestore out of `GroupSharedContentService`/`NotificationAnalyticsManager` into infrastructure repos was behavior-faithful but exposed pre-existing latent bugs: **(Critical/latent) `shared_content` group query blocked by the `list` rule** — the group view queries `where('sharedToUserIds', arrayContainsAny: memberIds)...` but `firestore.rules:543` is `allow list: auth.uid == resource.data.sharedByUserId` (listing restricted to the SHARER). The `get` rule allows `auth.uid in sharedToUserIds` but **`get` ≠ `list`** — Firestore evaluates query/list rules WITHOUT honoring the membership branch, so a recipient-member's whole query permission-denies and `getSharedRecipes` returns `[]` silently (service swallows). The new repo's docstring claiming the array clause makes the rules engine reject widening is WRONG (the engine keys `list` off `sharedByUserId`). Fix needs a `list` branch allowing `auth.uid in resource.data.sharedToUserIds` + the composite index `(contentType ASC, sharedToUserIds ARRAY_CONTAINS, sharedAt DESC)`. **(High/latent) `notification_delivery`/`notification_engagement` writes rejected by `keys().hasOnly`** — every event includes `expireAt: Timestamp` (90-day TTL) but the create rules' exhaustive `keys().hasOnly([...])` don't list it → all writes permission-denied, caught+logged, analytics fails silently. Fix: add `expireAt` to both `hasOnly` lists (+ gcloud TTL policy). **(High/latent) missing composite indexes** for `getDeliveriesForUser` (`targetUserId == + sentAt >`) and `getEngagementsForUser` (`userId == + timestamp >`) — `==` on one field + range on a DIFFERENT field needs a composite. **`fake_cloud_firestore` evaluates NEITHER rules NOR index requirements** — both new tests pass green while real-Firestore is broken; a passing fake test proves query SHAPE only, never rule-ALLOWED or index presence (recurring false-confidence trap — prove via firestore-rules-tester against the emulator). **Infrastructure repos without PermissionValidationMixin are acceptable** when they return raw snapshot maps and delegate authz entirely to rules (mirrors `FirestoreRepository`, a documented non-`BaseFirebaseRepository`) — PROVIDED the rules actually enforce the boundary (here they don't for the group query; the mixin wouldn't have caught it, only rule/repo lockstep does). Data-source convention respected: the managers use auth uid only for permission pinning / null gate, never as profile data.

### 2026-05-31 — standalone admin backfill scripts are safe to delete; the deployed-surface test
Checklist proving a `functions/src/admin/*.ts` script is NOT part of the deployed/operational surface (reusable for future admin-script deletions): **(1)** no `export` anywhere → nothing can import a symbol from it (pure consumer of shared modules, not a provider — shared deps stay, `tsc` still compiles); **(2)** not exported from `functions/src/index.ts` → not a deployed Cloud Function ("backfill" in a filename does NOT imply deployed — discriminate by the index.ts export, not the name; contrast `migrations/backfill-recipe-comments-denorm.ts` which IS exported as `onCall` at index.ts:92 and is KEPT); **(3)** no `package.json` script entry (every OTHER admin script is wired — `sync-ingredients`, `seed-tag-configs`, `reset-user-data` — these were run ad-hoc via `npx ts-node`); **(4)** no dedicated `__tests__/` test, not in `test`/`test:rules:all` aggregates, not in the `app-check-enforcement.test.ts` deployed-function whitelist; **(5)** `firebase.json` `predeploy` is generic (`npm ci`/`audit`/`build`) — compiles the tree but invokes no specific admin script; no `.github` CI reference. All five clean ⇒ deletion removes only `tsc` inputs nothing references; build/deploy/rules/GDPR paths untouched.

### 2026-06-03 — Vertex AI EU single-region → `eu` multi-region is residency-EQUIVALENT for GDPR Chapter V (BUT-1187)
Prod-down incident fix: Google retired `gemini-2.0-flash-001` on 2026-06-01 (Vertex returns 404), so `gemini-client.ts` moved `VERTEX_LOCATION` `europe-west1` → `eu` and `TEXT_MODEL` → `gemini-2.5-flash-lite`. **Residency ruling (reusable):** moving from a *single* EU region to an EU *multi*-region is NOT a Chapter V regression and needs no re-ratification of the transfer story. Chapter V governs transfers to THIRD COUNTRIES (outside the EEA); a multi-region wholly contained in the EU (`eu`) is not a third-country transfer — data-at-rest + ML processing stay within EU geography, identical Chapter V analysis. What broadens is only WHICH EU regions may process (redundancy/latency posture), not residency posture. The Vertex AI DPA / Cloud Data Processing Addendum applies to ALL regional & multi-region endpoints identically; Vertex does NOT train on customer prompts/responses by default (contractual, model-agnostic, unchanged by 2.0→2.5). **The ONE thing to flag hard:** `global` is the residency-breaking value (can egress outside EU) — `eu`/`europe-west1`/any `europe-*` are all EU-resident and fine; treat any diff flipping a Vertex `location` to `global` as Critical. **Singleton cache keyed by project-id only stays correct** when region is a module CONSTANT (fixed per-deploy) — no runtime path can construct a client with a divergent region, so adding region to the cache key is dead complexity. **Model×region availability is project-allowlist-dependent and changes often** — a model present in `europe-west1` single-region may not be, and a 2.5-series model may only be served on `eu` multi-region; deploy-time verification (Cloud Logging `jsonPayload.modelId` non-zero count on the configured region) is a REAL gate, not a formality — the incident isn't closed until prod shows the model serving. Documented fallback `gemini-2.5-flash` (one-constant flip) is also EU-resident. Stale-comment trap: grep the literal `europe-west1` across `functions/src/llm/` after such a move — the BUT-614 endpoint-host note (`europe-west1-aiplatform...`) and inline `structure-recipe.ts` comments lag the constant (Low, non-load-bearing — SDK derives host from `location`).

### 2026-06-03 — tag-merge batch helper (BUT-1042); single-cascade-batch paths inherit the 450/500 uncapped gap
`addReplaceTagInRecipesToBatch(userId, batch, fromTagId, toTagId, toRichEntry)` in `recipe_tag_operations.dart` mirrors `addRemovePersonalTagFromRecipesToBatch` and is clean on user-scoping (queries+mutates ONLY `getCollectionForUser(userId)` → `/users/{uid}/recipes`; facade passes `currentUserId` from auth repo) and atomicity (intentionally no try/catch — query/build failure propagates so the caller never commits a half-built batch). `mergeTags(fromId,toId)` in `personal_tag_crud_service.dart`: `requiresAuth:true` guard, `fromId==toId`/empty guards both layers, missing-dest throws `ArgumentError` before any batch op, rich `personalTags` rebuild filters `tagId != fromTagId` + appends `toRichEntry` only when no surviving `toId` entry (preserves other tags, no dup). **The rich-array SET (not arrayRemove+arrayUnion) is forced** — Firestore rejects two FieldValue transforms on the same field in one update (same constraint as `_buildTagRemovalUpdate`). **The latent gap: `mergeTags` and the single-tag `deleteTag` both commit ONE UNCAPPED batch** (one `batch.update` per matched recipe + the tag-delete op) — a user with >500 recipes carrying the tag throws `INVALID_ARGUMENT` at commit and the WHOLE op (incl. tag delete) is rejected. This is fail-atomic (loud throw, no partial write / no corruption), NOT silent data loss — so it's a **follow-up, not a commit blocker** (currently unreachable per the `<500 recipes/tag` assumption documented on `renamePersonalTagInRecipes`). **Pattern to flag (HIGH, ticket it):** any cascade that funnels a per-recipe-doc helper (`addReplace*`/`addRemove*ToBatch`) into a single `batch.commit()` WITHOUT chunking — contrast `bulkDeleteTags` (chunks 100 tags/batch), `removePersonalTagFromRecipes`/`renamePersonalTagInRecipes` (chunk 450/500 with explicit limit comments), `firestore_batch_utils`/`friends_firebase_sync` (`kFirestoreBatchSafeChunkSize = 450`). Fix shape: chunk retag commits at 450 + delete source tag in a final batch (loses cross-chunk atomicity but the retag is idempotent → re-running completes stragglers, matching the documented `renamePersonalTagInRecipes` partial-retry posture), or move large tags to the BUT-480 deferred CF path. **GDPR:** self-scoped rectification of the user's own tagging data — no new collection, no cross-user PII, no cascade concern.

### 2026-06-03 — BUT-1049 comment-image upload: author-scoped path is auth-derived (clean); per-comment-delete orphans Storage images (follow-up, not blocker)
Comment images attach to recipe comments at Storage path `users/{uid}/comment_images/{imageId}`. **Upload-side is clean and double-pinned:** `StorageService.uploadCommentImage(File)` takes NO authorId param — it resolves `userId = PermissionService.currentUserId` and builds the path from THAT, then calls `_repository.uploadImage(userId, path)` which re-validates in `_validateUploadPermission`: (1) `userId == currentUserId`, (2) `path.startsWith('users/$userId/')`. So even a malicious caller can't target another user's prefix — the path is auth-derived twice. Mirrors `uploadImageFile`'s `users/{uid}/recipes/` pattern exactly. **Firestore write-side is clean:** `FirebaseCommentsRepository.addComment` adds `List<String> imageUrls = const []`, enforces a server-side defence-in-depth cap `imageUrls.length > RecipeComment.maxImageUrls (3) → SecurityViolationException` (mirrors the Firestore rule + the model's construction-time assertion), and only emits the field when non-empty (legacy text-only docs stay byte-identical). `authorId` is still pinned to `requireCurrentUserId()` / `currentUserId` at every layer — the `imageUrls` param is a **pure pass-through** through the full chain (`SocialRecipeViewModel.postComment → SocialCommentsManager → SocialRecipeOperations → RecipeCommentsManager (sets authorId=currentUserId, NOT caller-supplied) → CommentCrudOperations → repo`), opening NO path to author-spoofing or cross-user image attachment. **GDPR account-deletion erasure IS covered** — `request-account-deletion.ts` step `deleteUserStorageFiles` does `storage.bucket().deleteFiles({prefix: 'users/${uid}/'})`, a recursive wipe of the whole user prefix, so `comment_images/*` go with everything else. No new cascade needed (same blanket-prefix coverage the `firebase_storage_repository.dart:228` comment relies on). **The ONE finding (Medium follow-up):** `FirebaseCommentsRepository.deleteComment` deletes ONLY the Firestore doc (+ parent replyCount decrement) — it never reads `imageUrls` to delete the backing Storage objects. So deleting a single comment ORPHANS its images in Storage until the account is deleted. Not a security hole (images stay author-scoped, rule-protected, auth-read-only) and not an Art-17 gap at account level (prefix wipe covers it), but it's retained-PII-longer-than-needed + storage-cost drift at the per-comment granularity (Art 5(1)(c) minimisation, soft). **Follow-up shape:** in `deleteComment`, before the batch, read `commentData['imageUrls']` and `StorageService.deleteImage` each URL best-effort (failures non-blocking, like the recipe-photo delete path). Same fix applies to the account-deletion-cascade.ts anonymize-recipe-comments branch IF it should hard-purge images on anonymization (it currently leaves them — but the account-prefix wipe only fires for the comment AUTHOR's own deletion; a commenter anonymized by THEIR OWN account deletion still gets the prefix wipe, so no extra gap there).

### 2026-06-03 — BUT-1186 chunked tag merge/delete: ordering safe, but swallow-and-return-0 cascade + unconditional delete = silent orphan path (CRITICAL)
BUT-1186 split the BUT-1042 single-atomic-batch merge/delete into chunked-cascade-THEN-delete. `replaceTagInRecipes` (new) and the reused `removePersonalTagFromRecipes` both self-chunk at `kFirestoreBatchSafeChunkSize` and **wrap the whole cascade in `try { ... } catch (e) { AppLogger.warning(...); return 0; }`**. The callers (`mergeTags`, `deleteTag` in `personal_tag_crud_service.dart`) **unconditionally proceed to delete the source/tag doc** in a separate batch regardless of the returned count. **Ordering invariant IS honored** (retag/remove first, delete second — verified in both callers; no delete-before or interleave). BUT the swallow-and-return-0 defeats the very partial-retry safety the doc-comments claim: when a cascade chunk throws a REAL error (network drop, permission, INVALID_ARGUMENT on a malformed doc) the catch swallows it → returns 0 → caller's delete commits anyway → **recipes that still carry `fromTagId`/`tagId` in their denormalized `core.personalTagIds`/`core.personalTags` arrays now point at a tag document that no longer exists (orphan).** Re-run does NOT self-heal a merge: `replaceTagInRecipes` early-returns 0 on `fromTagId==toTagId` and there's no surviving source-tag doc to re-drive from; the orphaned references are stranded silently (no throw, `executeServiceOperation` reports success). The return-0-means-"no recipes matched" and return-0-means-"cascade threw" cases are **indistinguishable to the caller** — that ambiguity is the bug. **Contrast the OLD batch-additive helpers** (`addRemovePersonalTagFromRecipesToBatch`, the removed `addReplaceTagInRecipesToBatch`): intentionally NO try/catch precisely so a cascade failure propagates and the caller never commits the delete — BUT-1186 inverted that safety when it moved the commit inside the now-swallowing helper. **Fix shape:** the cascade must distinguish "0 matched" from "threw". Either (a) rethrow from the cascade catch (let `executeServiceOperation` surface it; the delete never runs; re-run completes idempotently — matches the doc-comment's stated posture), or (b) return a sentinel/`bool succeeded` and gate the delete on it. Logging-and-returning-0 then deleting is the one path the ticket flagged as dangerous, and it is live in both `mergeTags` and `deleteTag`. **Reusable rule:** a cascade-then-delete (or cascade-then-anything-destructive) where the cascade swallows errors and returns a count MUST NOT let the destructive step key off that count — swallow-and-continue is only safe when the swallowed step is idempotent AND independently retried, never when a later step depends on it having succeeded. User-scoping/idempotency-of-the-SET-rewrite/GDPR surface are all unchanged and clean (still `getCollectionForUser(userId)`, facade resolves `currentUserId`, SET-not-FieldValue rebuild from doc data, self-scoped rectification — no cross-user PII).

### 2026-06-04 — online-status opt-out (BUT-912): write-side enforced, but `lastActiveText` is a parallel presence leak (HIGH)
Presence is stored on `public_profiles/{uid}` (NOT `/users/{uid}`): `FirebaseUserRepository.collectionName = publicProfiles`, and BOTH `isOnline` + `lastActiveAt` write paths target it — `updateOnlineStatus` (presence beat, `serverTimestamp()`) and `saveProfile` (full `set()` of `toFirestore()`). `public_profiles` read rule is `allow read: if isAuthenticated()` → every friend reads it. Friends list (`friends_list_cards.dart`) builds `friend` from `FriendRelationshipRepository.fetchFriendProfiles` → `UserProfile.fromMap(public_profiles doc)`, so it sees the live `isOnline` AND `lastActiveAt`. **The opt-out gate (`effective = isOnline && showOnlineStatus` in `UserService.updateOnlineStatus`) only zeroes `isOnline`; it leaves `lastActiveAt` advancing on every beat.** `UserProfile.lastActiveText` returns "online" ONLY when `isOnline`; otherwise it renders "active X ago" from `lastActiveAt` regardless of `isOnline` — so a hidden user whose dot is gone STILL shows a continuously-fresh "active just now / N min ago" on the friends list. That's an incomplete data-minimization opt-out (last-seen still leaks the very presence signal the user opted out of). **Reusable rule: a presence opt-out must gate EVERY surface derived from the presence timestamps, not just the boolean dot.** Two clean fixes: (a) gate the render — `lastActiveText` (or the card) returns empty/"" when `!isOnline && !showOnlineStatus`; needs `showOnlineStatus` carried on `public_profiles` (it's in `toFirestore()` so it already lands there — confirm it's in `fromMap`) so other users can see the flag; OR (b) freeze the source — when hidden, ALSO stop advancing `lastActiveAt` (write the gate into the repo or skip the `lastActiveAt` write when `!effective`). (b) is stronger (no stale timestamp to leak even via export/other future view) and keeps the privacy decision server-adjacent; (a) is a one-line view fix but leaves the fresh timestamp readable by anyone doing a raw `public_profiles` read. Recommend (b) primary + (a) as belt-and-braces. **Backward-compat default `true` is correct** (no pre-existing hidden users; default-true preserves status quo, no silent regression). **Rules: no change needed** — `public_profiles` update denylist (rules:474-481) blocks only `fcmToken/notificationsEnabled/allergenPreferences/.../isHidden/hiddenAt`; `showOnlineStatus`/`isOnline`/`lastActiveAt` are owner-writable, and `/users/{uid}` write is `isOwner` (no field whitelist) — owner can persist the flag either place. No rule rejects the new field.

### 2026-06-09 — Gemini usageMetadata telemetry review checklist (BUT-1032)
`usageMetadata` token COUNTS (`promptTokenCount`/`candidatesTokenCount`/`cachedContentTokenCount`) + `MODEL_ID` are bounded numerics/constants — safe to log, no PII (same category as error CODES in BUT-971; the leak surfaces remain prompt/response TEXT and `message` fields). **When reviewing cost-formula changes in `calculateGeminiCost`, verify no consumer keys decisions off the cost before calling it "telemetry-only":** as of BUT-1032 the only consumers are logs + the `estimatedCost` response field; the OCR-retry budget is TIME-based (`MIN_REMAINING_BUDGET_MS`) and `rate_limiter.ts` is request-COUNT token-bucket — neither reads cost, so a pricing change cannot loosen any enforcement. If a future cost-based budget cap appears, re-run this check (a discount would then under-count toward the cap). Vertex semantics pin: `promptTokenCount` INCLUDES the cached slice, so discounting = `fresh = prompt − clamp(cached, 0, prompt)` — the [0, prompt] clamp is the right defensive shape (negative/oversized API values can't produce negative input cost; `Math.max(..., minCost)` floor preserved). Pre-existing (not BUT-1032): `structure-recipe.ts` `logger.error("Failed to parse response:", content)` logs the FULL Gemini response (derived from user recipe text) on parse failure — cold path, recipe-content not credentials, but it predates and survives every telemetry review; ticket if log-volume/PII posture tightens.

### 2026-06-10 — per-doc visibility override: split-query pattern + backfill ordering (BUT-1214)
When a doc gains an owner-settable privacy field (`cook_snaps.visibility: sameAsRecipe|onlyMe`) and reads are rules-gated per-doc, the ONLY query-provable client shape is a **split query**: (a) viewer's own docs `where(userId == auth.uid)` with NO visibility filter (owner branch provable, sees own `onlyMe`), plus (b) friend chunks `where(userId whereIn ...).where(visibility == 'sameAsRecipe')` — the rule's friend branch must be STRICT equality (`resource.data.visibility == 'sameAsRecipe'`, no `!('visibility' in data)` back-compat clause), because at query time an unconstrained field evaluates as satisfiable-absent and re-opens the old unfiltered query shape to `onlyMe` docs (rules are not filters). Strict equality consequences to verify together: (1) legacy field-missing docs go friend-INVISIBLE (fails private — availability, not security) until backfilled; (2) **deploy ordering: backfill BEFORE rules deploy**, and **re-run after old-client traffic dies** (stale clients keep writing field-less docs that stay friend-invisible — and the create rule's `!('visibility' in ...)` allowance is what lets them write at all); (3) old deployed clients' unfiltered queries get wholesale-denied the moment strict rules land (empty gallery, service swallows — fails closed, acceptable); (4) composite index gains the equality field BEFORE the orderBy field (`(recipeId, visibility, userId, createdAt DESC)`); (5) GDPR export/deletion/`getByUser` paths filter on `userId ==` only — owner branch covers `onlyMe`, so Art-15/17/20 see ALL snaps regardless of visibility (verified). Also pair the create/update rules with an enum allow-list (`isValidSnapVisibility`) so a forged value can't create a get-readable-but-query-invisible doc. **Backfill-script blast-radius rule:** an add-missing-field-only backfill (`filter !('field' in data)` → set the pre-feature-equivalent default) is intrinsically safe to re-run and near-harmless against the wrong project — it never touches docs that carry the field (can't downgrade an `onlyMe`), and the written value reproduces pre-feature semantics. Residual hardening (Low): echo `admin.app().options.projectId` before writing; unpaginated `collection().get()` is fine one-time at beta scale only.

### 2026-06-03 — best-effort Storage cleanup on comment delete: two-layer owner-only delete (BUT-1189)
`FirebaseCommentsRepository.deleteComment` now best-effort deletes backing comment images via a new private `_deleteCommentImages(commentData['imageUrls'])` AFTER `batch.commit()`. **Posture is correct:** runs post-commit (comment already deleted), `tryGet<StorageService>` (unregistered→no-op), per-image try/catch swallows to a warning — no Storage error path can fail or roll back the comment deletion. **No arbitrary-path-deletion vector (the key #3 question):** `StorageService.deleteImage`→`FirebaseStorageRepository.deleteImage` calls `_validateDeletePermission(url)` BEFORE `refFromURL(url).delete()`; that guard runs `_extractUserIdFromPath` (Uri.decodeFull + `users[/\]([^/\]+)` regex, handles %2F-encoded download URLs) and requires `userIdFromPath == currentUserId`, else `PermissionDeniedException` (caught→false). Server-side Storage rules (BUT-1049, owner-only write/delete at `users/{authorId}/comment_images/*`) enforce the same independently. So a tampered `imageUrls` entry pointing outside the caller's own `users/{uid}/` scope is rejected at BOTH layers — confirmed safe. **Moderation orphan (expected, NOT a hole):** when a NON-author (recipe owner/admin) deletes a comment, the author-owned images fail BOTH the client guard (uid mismatch) AND Storage rules → swallowed → image orphans. Fails SAFE: no crash, no cross-user deletion (a moderator canNOT delete a path they don't own — correct). End state identical to pre-BUT-1189 (images always orphaned on delete); account-deletion cascade (`on-user-deleted` gsutil rm of `users/{uid}`) still sweeps eventually. Acceptable; the only clean fix for moderator-triggered author-image cleanup is an Admin-SDK CF (privileged delete) — note as optional follow-up, not a blocker.

### 2026-06-10 — injection-seam audit heuristic + npm-runner trust boundary (BUT-1223)
**Seam audit (2 greps, conclusive):** when a security gate gains a `Deps` injection seam, verify (1) default binds the real impl via `deps.X ?? realX` with `deps: Partial<Deps> = {}`, and (2) grep the seam name across `functions/src` — every stub injection must be in `__tests__/`; every prod caller must omit `deps`. "A caller could pass a no-op" is NOT a finding by itself: it requires committing repo code, the same trust boundary as the pre-existing seams on the same interface (`send`, `getPreferences` could already bypass everything). New seam = no new attack-surface class if the two greps pass. (`checkRateCap` on preference-aware-push.ts: clean — sole prod caller send-activity-digest.ts passes no deps.)
**npm run-all runner:** `spawnSync(\`npm run ${name}\`, {shell:true})` over `Object.keys(pkg.scripts)` is NOT command injection — controlling script NAMES implies controlling script BODIES, which npm shells out anyway. Optional Low hardening: `/^test:[\w:-]+$/` name filter. Patterns worth keeping from `functions/scripts/run-all-tests.js`: vacuous-pass guard (0 suites discovered → exit 1), prefix-filter excludes emulator suites (`test:rules`, `test:integration:`), no self-recursion (`test` ≠ `test:` prefix), run-all-collect-exit beats `&&` chains (first red no longer masks later suites).

### 2026-06-11 — BUT-694 PII heuristic review: ASCII-\b-before-åäö bites lookaheads too; unbounded leading letter-class is the regex-DoS shape to flag
Reviewing the Swedish address/name heuristics (`pii-scrubber.ts` ⇄ `pii_scrubber.dart`) surfaced three reusable rules. **(1) The ASCII `\b` quirk the code already documents for match BOUNDARIES also bites inside the shared `UNIT_SUFFIX_LOOKAHEAD`:** `l\b`/`g\b` match before å/ä/ö (non-word in ASCII \b), so "Storgatan 14 lägenhet 1203" is read as "14 l" (litres) → NOT redacted (verified live); same for "Solbacken 9 går...". When auditing any unit/suffix lookahead with single-letter alternatives, probe a following word whose 2nd char is å/ä/ö. Fix shape: replace `\b` in the lookahead with `(?![A-Za-zÅÄÖåäö0-9_])` — note it's shared with the phone regex, so change is cross-rule. **(2) Regex-DoS shape to flag in scrubbers: unbounded leading letter-class before a literal suffix** (`[letters]+(?:gatan|...)`) is O(n²) on a long unbroken letter run — measured 4.0s for the address regex alone at the 50k-char structureRecipe input cap (full scrubPii 7.2s; the pre-existing email regex contributes ~1.8s of that, so the class predates BUT-694). Bounding the quantifier (`{1,60}` — longer than any real street name) drops it to 18ms with zero vector changes. Always check scrubPii call sites cap length BEFORE scrubbing (they do: 50k structure-recipe, 500 log-parse-correction, 2k/8k/1k log-web-error) and remember the Dart client runs the same regex on the UI isolate. **(3) Case-sensitive heuristics silently no-op on ALL-CAPS OCR text** ("STORGATAN 14", "MORMOR ASTRID" pass through) — for OCR-fed scrubbers, suffix/trigger sets should either be case-insensitive where the design allows (RULE A suffixes) or the gap documented as accepted. **Good cross-port pattern worth reusing:** byte-identical shared JSON vector file (TS side = source of truth, Dart side a verbatim copy) + full-string-equality tests in BOTH suites + a vector-count pin (27) — `cmp` the two fixture files during review; extending `PII_TOKENS` feeds `redactionRatio` in the privacy-conservative direction only (more likely to trip the >50% heavy-redaction DROP, never less redaction), so token additions are telemetry-safe by construction.

### 2026-06-13 — BUT-626 prompt A/B bucket: analytics-only variant strings, no injection surface (iter-143)
`prompt-ab-bucket.ts` uses SHA-256(`${authUidHash}:prompt_experiment`) mod bucketCount — the input is already the HASH of the UID (never the raw UID), so the key is double-pseudonymised. Analytics log fields `experimentBucket` (integer) + `promptVariant` (short string from operator-controlled Firestore doc) + `promptVersion` are telemetry-safe: no user-identifiable field anywhere. **Injection surface analysis: zero.** `promptVariant` is emitted ONLY to `logger.info` in `emitTiming`; it never flows into a prompt string, a query filter, or any code path that could change LLM behavior — confirmed by grepping both callers (`structure-recipe.ts`, `ocr-recipe-image.ts`). **`promptVariants` validation in `validateRemoteDoc` is all-or-nothing:** `Array.isArray + length>0 + every(typeof v === 'string' && v.trim().length > 0)` — a single bad element makes the whole field absent; only valid string arrays pass through. **Gap worth noting (Low):** variant strings are non-empty-string checked but have no max-length cap. A Firestore operator who writes a 10k-char variant name would emit an oversized log entry; not exploitable (operator-level trust, Cloud Logging just truncates), but a `v.length <= 64` cap would make the defense explicit. **No new Firestore reads:** `promptVariants` comes from the already-cached `system/prompts` RC doc (5-min TTL); cost-neutral. **No Math.random:** deterministic, safe no-op when `promptVariants` absent. Idempotency/region/secret-leakage: none changed.

### 2026-06-13 — BUT-1053 user-locale prompt injection: clamp-10 is effective but punctuation gap exists (Medium)
`buildLocaleInstruction(locale)` in `functions/src/llm/structure-recipe.ts` clamps to 10 chars after trim. The clamp stops sentence-level injection, but a value like `"en. IGNORE"` (exactly 10 chars, all passing `trim().substring(0,10)`) embeds a period+space+word into `"Respond in en. IGNORE. Preserve..."`. This is NOT exploitable as a prompt-override (no role escape, no prior-instruction directive), so it is Medium at most. **Recommended fix:** strip non-alphanumeric-non-hyphen chars before clamping: `locale.trim().replace(/[^a-zA-Z0-9\-]/g, "").substring(0, 10)`. **Test gap:** the test suite covers clamping by length but not a locale containing punctuation mid-string — add a case for `"sv. DROP"` if the regex fix lands. **Pattern for future LLM prompt seams:** any user-supplied string interpolated into a prompt must be (1) type-checked, (2) whitespace-trimmed, (3) stripped of sentence-forming chars OR whitelisted against `^[a-zA-Z0-9\-]{2,10}$`, (4) guarded by a fail-return-undefined on empty/absent. The fail-open (absent locale → no instruction → original behavior) is correct. All three call sites (structure-recipe, ocr-recipe-image, ocr-retry) thread locale correctly via `RetryDeps.locale`; no existing guard was dropped. PII clean: locale is never logged.

### 2026-06-11 — BUT-838 cook-event log: virtual-doc tree pattern + the export-side gap reviewers must grep for
`recipe_cook_events/{userId}/events/{eventId}` introduces the **virtual-parent-doc tree**: the `{userId}` doc is never written, exists only as a path segment. Implications verified clean: (1) rules key owner access off the path segment (`request.auth.uid == userId`) so the owner's `count()` aggregate is query-provable with no per-doc data access; (2) `userId` is deliberately NOT a document field — `toFirestore()` emits only `{recipeId, cookedAt}` and the create rule's `keys().hasOnly(['recipeId','cookedAt'])` matches byte-for-byte (**lockstep check: any rules `hasOnly` must equal the model's `toFirestore()` key set — a drift silently denies every create**); model recovers `userId` via `doc.reference.parent.parent.id`; (3) GDPR cascade uses `listCollections()` on the ghost root (Admin SDK sees subcollections under non-existent parents) + conditional root-doc delete only `if (rootSnap.exists)` — works whether or not the root ever materializes, idempotent on re-run; (4) audit rows staged in-batch with `opsPerItem: 2` (BUT-886 pattern applied correctly first time). Deliberate `UserScopedFirebaseRepository` non-adoption is OK when a ticket pins a top-level tree — but the repo MUST then doc why (this one does). **The recurring review gap: deletion shipped, Art-15/20 export didn't.** New per-user collection of timestamped behavioral data (cook history = linked PII) was wired into `on-user-deleted.ts` but NOT into `data_export_service.dart`/`content_export_manager.dart` (which exports `cook_snaps` two lines away). **Checklist addition: for every new user-data collection, grep `lib/services/account/export/` for the collection name in the same review — deletion-without-export is the asymmetry to catch** (Art-17 done, Art-15/20 forgotten).

### 2026-06-14 — BUT-1220 activity-feed per-type gating: auto-fire full-profile set() clobbers concurrent friendsCount; privacy prefs land in world-readable public_profiles
Sprint added `UserProfile.activityFeedEventTypes` (Map<String,bool>, opt-out: absent key = enabled) + `hasSeenActivityFeedHint` and a one-time hint that fires on first activity broadcast. **Three reviewer takeaways:**
(1) **Auto-fire full-doc overwrite race (High).** `UserService.markActivityFeedHintSeen()` calls `_repository.saveProfile(updated)` which does a **non-merge `collection.doc(uid).set(toFirestore())`** on `public_profiles`, sourced from the in-memory `_currentUserProfile`. This now fires AUTOMATICALLY + invisibly on the first `emitEvent` (cook/share/ping), not just on explicit profile-save. `friendsCount` is in `toFirestore()` and is mutated by OTHER users via a ±1 transaction (rules let any authenticated user change only `friendsCount`). A stale in-memory profile → the hint write reverts a concurrent friend's count increment. `isHidden`/`hiddenAt` are moderator-only-write so a stale set() including them is rejected wholesale (the whole hint write fails, caught+logged). **Fix: targeted field update — `collection.doc(uid).update({'hasSeenActivityFeedHint': true})`, never a full-profile set for a single-flag side effect.** General rule: any *automatic/background* profile mutation must be a single-field `update()`, never `saveProfile()` (full set), because full-set clobbers fields owned by other writers (friendsCount) or moderators (isHidden).
(2) **Privacy prefs in world-readable doc (Medium, data minimization).** `public_profiles` is `allow read: if isAuthenticated()` (any user, incl. non-friends). `toFirestore()` now writes `activityFeedEventTypes` + `hasSeenActivityFeedHint` there. This exposes which event types a user muted to everyone. Follows the existing (debatable) precedent of `showOnlineStatus`/`shareActivityToFeed` booleans already living there, so Medium not Critical — but the correct home is the private `user_settings` subcollection (where `notificationsEnabled`/`preferredLocale` live and the public-profile create rule explicitly REJECTS those keys). The public create/update rules do NOT reject the two new keys, so rules permit the leak.
### 2026-06-14 — firebase_user_repository review: saveProfile full-set still clobbers friendsCount; BUT-1220 hint path now correctly uses merge sub-doc
Re-review of `firebase_user_repository.dart` + `user_root_deletion_mixin.dart`. **markActivityFeedHintSeen is now FIXED** vs the 2026-06-14 BUT-1220 finding (1): it writes a single-field `_settingsDoc(uid).set({'hasSeenActivityFeedHint': true}, merge:true)` to the PRIVATE settings sub-doc — no full-profile set, no friendsCount/isHidden clobber. Good. **But `saveProfile` itself still does `collection.doc(uid).set(toFirestore())` (non-merge) on `public_profiles`** and `toFirestore()` includes `friendsCount` (maintained by OTHER users' ±1 friend transactions) and `isHidden`/`hiddenAt` (moderator-only-write). Server-side the rule (rules:474-481) saves us partially: `diff().affectedKeys()` only trips on a *value change*, so a save that happens to match the stored isHidden/friendsCount passes; a stale in-memory `friendsCount` silently reverts a concurrent friend's increment (owner branch does NOT block friendsCount), and a stale isHidden on a moderated user makes the WHOLE saveProfile rejected (user can't edit display name while hidden). Remediation: keep saveProfile for genuine full-profile saves but read-merge friendsCount/isHidden from server before set, OR move those server-owned fields out of toFirestore() and let only friend-transactions/moderation touch them. **Data-source convention:** correctly honored — `requireCurrentUserId()`/`authRepository.currentUser?.uid` for auth/permission gating only; full profile data reconstructed via readCacheFirst + private settings merge. No userService/permissionService mixing in this layer. **validateReadPermission returns `true`** for public_profiles — matches rule `allow read: if isAuthenticated()` (intentional: profiles are the social-search surface; privacy via isSearchable/isHidden filtering). **GDPR delete paths both rule-matched:** deletePublicProfile→`public_profiles` `allow delete: if isOwner` (rules:492); deleteUserRootDoc→`users/{uid}` `allow write: if isOwner` (rules:223). Both validateOwnership-gated before the network call. **Sensitive-field separation holds:** create rule (rules:459-465) hard-rejects fcmToken/notificationsEnabled/allergenPreferences/etc on public_profiles; saveProfile routes those to `_settingsDoc` (private). **Email-search privacy:** searchProfiles email branch gated on `allowEmailSearch==true` server-side — correct opt-in.

### 2026-06-14 — activity_events has NO firestore.rules block at all (continued from BUT-1220)
(restated for grep) **activity_events has NO firestore.rules block at all** — falls through to default-deny `match /{document=**}{ allow read,write: if false; }`. Out of this diff's scope (rules + repo untouched) but means the whole activity-feed feature cannot write in prod; `validateCreatePermission` (actorId==userId) is client-only and never mirrored server-side. Pre-existing; flag for the rules owner. Data-source convention itself is honored: `UserService.currentUserId` delegates to `PermissionService.currentUserId` (auth), profile data from `_currentUserProfile` — no mixing. Note: `app_localizations_en.dart` got Swedish strings for the new keys (sv is primary UI lang, cosmetic, out of security scope).

### 2026-06-14 — BUT-1279/1281 staple-pantry → shopping-list exclusion is security-clean (BUT-1292 re-review)
Re-reviewed the actual staple diff across `lib/models/pantry/pantry_item.dart`, `lib/services/shopping/menu_shopping_list_generator.dart`, and (touched-but-clean) `lib/services/menu/weekly_menu_plan_service.dart`. **Staple-read user-scoping: PASS — no cross-user reach.** The only staple read path is `MenuShoppingListGenerator._stapleNames()` → `ServiceLocator.get<AuthRepository>().currentUserId` (correct: auth handle for a permission-scoped read, NOT `userService.currentUserProfile` — this is the read-scope key, not user-data) → `PantryService.getAll(userId)` → `FirebasePantryRepository.getAll(userId)` → `_col(userId)` = `users/{userId}/pantry`. No collectionGroup, no cross-user query; a null userId short-circuits to `const {}` (exclude nothing). Firestore owner-only rule on `users/{uid}/pantry` is the second layer. **`isStaple` round-trip: PASS.** `toFirestore()` emits `'isStaple': true` ONLY when true (false → field omitted, keeps docs lean); `fromMap` reads `SerializationUtils.safeBool(data,'isStaple')` which defaults false on a missing field → omitted-when-false round-trips back to false correctly. `safeBool` is type-coercion-hardened (bool/String/num, defaults false on garbage) so a legacy/tampered value can't throw or smuggle an unexpected staple flag — worst case a benign exclusion miss. **Fail-open posture is correct, not a hole:** `_stapleNames` wraps the whole read in try/catch → degrades to "exclude nothing" + `AppLogger.warning`. Staple exclusion is a best-effort list-quality enhancement, not a security boundary, so no decision rides on the fail-open. `weekly_menu_plan_service.dart` carries no staple logic and keeps its existing `_currentUserId` guards (StateError on null user before any repo write) — untouched by the security review. No Critical/High/Medium findings. **Review pattern for "exclude-by-name" enrichment reads:** confirm (1) the userId feeding the scoped collection comes from the auth handle, (2) a null/failed read degrades to the SAFE default (here: exclude nothing, never exclude-everything which would empty a legitimate list), (3) the round-trip default of the new bool field matches the write-omission convention.

### 2026-06-14 — settings sub-doc single-field merge pattern confirmed safe (BUT-1050)
`_settingsDoc(userId).set({field: value}, SetOptions(merge:true))` with a single-key map is the correct pattern for per-user preference writes. It is safe because: (a) `requireCurrentUserId()` + `validateSelfOperation()` run before any write; (b) merge:true on a single-key map cannot clobber sibling fields (`friendsCount`, `isHidden`, `hiddenAt`) that live on the same doc; (c) `logPermissionCheck` is called after the write. Confirmed by `setAutoAddBoughtToPantry` / `markPantryAutoAddPrompted` implementations, which are now the canonical reference for this pattern alongside `markActivityFeedHintSeen`. Service layer contract: settings-toggle style methods rethrow (user-facing); best-effort one-shot flags (prompt-seen) swallow the error — both update the in-memory cache + call `notifyListeners()` only AFTER the Firestore write succeeds.

### 2026-06-14 — activity_events rules block now EXISTS (supersedes the 06-14 "NO block" entry); rate-limit guard is inert + type/extraData unbounded (BUT-1294)
**Supersedes the earlier same-day "activity_events has NO firestore.rules block at all" note** — the current working tree has `match /activity_events/{eventId}` (rules:1177-1211) plus a dedicated emulator test `functions/src/__tests__/activity-events-rules.test.ts`. Read rule is correct: actor OR per-doc `exists(users/{actorId}/friends/{auth.uid})` friendship gate, matching the `whereIn([self+friendIds])` feed query in `FirebaseActivityEventRepository.fetchFriendActivity` (rules-are-not-filters: a stranger doc in a result set fails the whole query — the standard cook_snaps pattern). Create/update/delete are actor-pinned with actorId/recipeId/createdAt immutable. **Two findings:** (1) **Rate-limit guard is inert (Medium).** `rateLimitWrite('activity_events', 2)` reads `users/{uid}/rate_limits/activity_events.lastWrite`, but `FirebaseActivityEventRepository` creates via plain `BaseFirebaseRepository.create` and NEVER writes that rate_limits doc — so `!exists(limitsPath)` is permanently true and the burst guard never fires. **General rule: a `rateLimitWrite(coll,n)` clause is only live if some client path also sets `users/{uid}/rate_limits/{coll}.lastWrite = serverTimestamp()` in the same op (cook_snaps/comments/messages do).** Either wire the lastWrite update into the create path or drop the clause so it's not mistaken for protection. (2) **type/actorDisplayName/extraData unbounded (Medium).** Create rule checks `type is string` with no enum/length cap and does NOT bound `actorDisplayName` or the `extraData` map (`hasRequiredFields` ≠ `hasOnly`), on a friend-readable collection — arbitrary-payload / storage-abuse vector. Contrast cook_snaps (caption ≤200 + `isValidSnapVisibility` enum). **Test gaps to hand to firestore-rules-tester:** no test exercises the rate-limit branch (unique-id creates always pass first-write), none documents the unbounded type/extraData, and the friend-read is only proven via single-doc `.get()` not the `whereIn` query shape the rule's comment relies on. The test harness is a hand-rolled runner (not jest), run via `npx ts-node`.

### 2026-06-17 — admin custom-claim sync: claim-spread pattern is safe; screenshotUrl unvalidated in email link (feedback trigger)
`sync-admin-claim.ts` correctly spreads `user.customClaims ?? {}` before mutating the `admin` key, so other claims are preserved and neither grant nor revoke clobbers them. The `admins/{uid}` collection is `allow write: if false` in firestore.rules (confirmed line 1931), so no client path can trigger the Firestore-create that would fire `onAdminGranted`. The triggers are therefore safe from client-initiated privilege escalation. **One Medium finding in `on-feedback-created.ts`:** `screenshotUrl` is embedded as an `<a href>` in the HTML email body without validation that it is a Firebase Storage URL — a malicious user can store an arbitrary URL in Firestore and have it sent to the admin inbox. This is not XSS (the URL is in an `href` attribute, which `escapeHtml` does NOT sanitise — it only covers `&<>"` in text nodes, not attribute values containing `javascript:` or data URIs). The risk is limited to admin phishing (the email goes only to the team), not to end users, and the app-side upload path in `FeedbackService` always sets `screenshotUrl` from `uploadScreenshot` return value (a real Storage URL). But rules do not constrain the field, so a crafted Firestore write via any other path can inject an arbitrary value. **General rule for email HTML: validate URL scheme before embedding as href, or render as escaped plain text.** The `dashboardBase` env-var link is operator-controlled (non-secret env var), so it is trusted. `res.text()` in the error log cannot leak the API key (the key is in the request header, not the response body; Resend's error responses are JSON error objects with no credential echo). `hashUid` usage in the log line is correct — raw `userId` is not logged anywhere in these three files.

### 2026-06-19 — EngagementRepository: PermissionValidationMixin bypass is legitimate for admin-only aggregate reads
`EngagementRepository` (`lib/repositories/engagement_repository.dart`) intentionally omits `BaseFirebaseRepository` / `PermissionValidationMixin`. Reviewed and confirmed clean: (1) **Bypass appropriateness:** the repo is read-only (no CRUD, no writes), reads are on `users` count() aggregate and `analytics/feature_retention/daily` rollups — both gated `if isAdmin()` in firestore.rules. No per-user permission surface exists (no userId scope, no ownership check meaningful for an aggregate). This is the same standing exception as `SiteConfigRepository` (BUT-886). **Pattern name: admin-only aggregate read bypass** — document bypass rationale in a class-level doc comment (the file does this correctly). (2) **Fail-safe behaviour: PASS.** Both methods catch all errors, log via `AppLogger.warning`, and return 0 / [] — the admin tab degrades gracefully, no exception propagates, no sensitive data leaks from the error path. (3) **GDPR: PASS.** `getUserCount()` is a Firestore `count()` aggregate — returns an integer, zero individual user records read. `getDailyFeatureRetention()` reads server-side rollup docs (aggregated stats, no PII fields) — no individual user data surfaced by this repo. **DI registration note:** registered as a concrete class (not behind an interface) in `content_module.dart:464` — acceptable for an admin-dashboard-only singleton with no testability requirement beyond constructor injection, but adding an interface would enable clean unit testing if analytics logic ever grows. No Critical / High / Medium / Low findings.

### 2026-06-19 — admin-only aggregate repo: PermissionValidationMixin bypass is safe when (a) read-only, (b) rule-gated by isAdmin(), (c) no PII extracted, (d) fail-safe catch returns empty value (RecipeStatsRepository)
`RecipeStatsRepository` omits `BaseFirebaseRepository`/`PermissionValidationMixin` by design — confirmed clean. **Bypass checklist:** (1) read-only: only `.collectionGroup(...).limit(5000).get()`, no writes; (2) rule-gated: `match /{path=**}/recipes/{recipeId} { allow read: if isAdmin(); }` proven by `admin-dashboard-rules.test.ts`; (3) PII-free: `_classify` extracts only `core.sourceArtefact.type` (fixed-vocabulary string), nothing user-identifying is retained or logged; (4) fail-safe: `catch (e)` returns `const RecipeStats(total: 0, byMethod: {})`, no rethrow. **Truncation transparency pattern:** `.limit(_maxScan)` cap applied at query time + `AppLogger.warning` when hit — truncation is never silent. **Cost upgrade path:** at launch scale full-doc reads are fine; upgrade to `count()` aggregates per type (requires collection-group composite index on `core.sourceArtefact.type`) or a maintained counter doc when user base grows. **General rule: admin-only aggregate bypass is the established project pattern (SiteConfigRepository, EngagementRepository); must be documented in class-level doc comment + satisfy the four-point checklist above.**

### 2026-06-19 — OpsLogRepository: admin-only ops-log bypass confirmed clean (system_events)
`OpsLogRepository` intentionally omits `PermissionValidationMixin`. Confirmed clean against the four-point admin-bypass checklist: (1) **read-only** — no write methods exist; (2) **rule-gated** — `allow read: if isAdmin()` on `system_events`, proven by `admin-dashboard-rules.test.ts`; (3) **PII-free** — collection holds job-run metadata only (job type, timestamp, deleted counts); GDPR does not apply; (4) **fail-safe** — `getRecentEvents` catches all errors, logs via `AppLogger.warning`, returns `[]`. Written exclusively by server-side Cloud Functions; no client write path. Pattern is identical to `SiteConfigRepository` and `EngagementRepository` (see prior entries). No findings.

### 2026-06-20 — inequality-filter + different-field orderBy fix: client-side sort removes server-side .limit(); .limit(N) must be re-added before .snapshots()
`collaborativeListsStream` (shopping_repository_query_module.dart) removed `.orderBy('updatedAt').limit(20)` to fix the Firestore inequality-field mismatch (isNotEqualTo on a dynamic member-key cannot be combined with orderBy on a different field). Sorting moved client-side; `.take(20)` cap applied after sort. **Finding:** removing the server-side `.limit()` means the `.snapshots()` listener now streams every matching doc unbounded, violating the 2026-05-04 rule ("every .snapshots() chain must end in .limit(N)"). The fix comment correctly notes that `.limit(N)` without `orderBy` truncates arbitrary docs — but a generous cap (e.g. `.limit(200)`) is still better than no cap: it bounds the worst-case read cost without breaking the UI (the realistic ceiling for collaborative lists per user is very low). **Pattern for inequality-filter + client-side sort:** always add a generous server-side `.limit()` even when you can't orderBy, and document the known ceiling in a comment. The post-sort `.take(N)` UI cap is separate from the server-side cost cap and does not substitute for it.

### 2026-06-20 — ParseEventsRepository: admin-only bypass confirmed clean; where+limit without orderBy causes insertion-order truncation (Medium)
`ParseEventsRepository` omits `PermissionValidationMixin` — confirmed clean against the four-point admin-bypass checklist: (1) read-only: `.collection('parse_events').where('domain',...).limit(200).get()`, no writes; (2) rule-gated: `allow read: if isAdmin()` at firestore.rules:2156, proven 18/18 emulator tests; (3) PII-free: model carries domain/success/timestamp/url/successfulTier — no userId, no hashed uid, no display name. `url` is the full import URL (may carry site-level query params but no Butlery user data); admin-only visibility puts this at the same posture as server access logs; (4) fail-safe: `catch(e)` returns `ParseEventsPage.empty`, logs only domain + exception, no doc content. **One Medium finding:** `.where('domain',...).limit(200)` without `.orderBy('timestamp', descending: true)` returns docs in Firestore insertion order, so the Dart sort reorders within an arbitrary 200-doc window — not necessarily the 200 most recent events. When a domain has >200 events the `truncated` flag is correct but the visible set is misleading. **Fix:** add `.orderBy('timestamp', descending: true)` before `.limit(200)` and add a composite index `(domain ASC, timestamp DESC)` in `firestore.indexes.json`. At pre-beta scale this is cosmetic (no security or data-loss impact); document the caveat in the method comment if deferring the index. **DI pattern:** registered as concrete class (not interface) in content_module.dart — identical to EngagementRepository/OpsLogRepository; acceptable for admin-singleton with no testability requirement beyond constructor injection. **Fifth admin-only aggregate repo** following the established pattern (SiteConfigRepository, EngagementRepository, RecipeStatsRepository, OpsLogRepository).

### 2026-06-15 — swallowing global-reference-collection read errors is SAFE because the allergen fail-safe is coverage-gated, not lookup-gated (BUT-1331)
`FirebaseIngredientRepository._doLoadCache()` now logs+swallows a failed `_collection.get()` (offline `unavailable`) instead of rethrowing, degrading the global `ingredients` cache to empty/stale. **This does NOT create a false-safe allergen verdict — verified end to end.** The fail-safe lives in `IngredientLookupResult.getPropertyStatus/getCombinedPropertyStatus/getDietaryStatus`: they return `TriState.free` (the only "proven safe" verdict) ONLY when `coverage >= 1.0`; any `coverage < 1.0` returns `TriState.unknown`. An empty cache makes every real ingredient land in `unmatched`, so coverage collapses to 0.0 for any non-empty recipe → every allergen resolves to `unknown`, never `free`. The verdict can only move toward "we don't know", never toward a false "safe". **General principle for this codebase: allergen safety is gated on *coverage*, not on the lookup succeeding** — so degrading the ingredient source to empty is fail-safe by construction, the same reason a missing-ingredient recipe is. The CONTAINS path also can't be falsely cleared (CONTAINS requires a *matched* ingredient with the trigger property; empty cache produces no CONTAINS either, but absence-of-CONTAINS is rendered as `unknown` not `free` because coverage<1.0). **Security/GDPR surface: none.** `ingredients` is admin-managed, read-only, global reference data (not user-scoped, no PII); swallowing the read bypasses no permission check and leaks nothing. **Log line is clean:** `AppLogger.error('Failed to load ingredient cache: $e', stack)` logs only the Firestore exception (`unavailable`) + stack — no ingredient/user data, no PII. Comment correctly documents that `_cacheLoadedAt` stays null on failure (later online call retries via `_ensureCacheLoaded`) and stale cache is preserved because `_cache.clear()` runs only after `.get()` succeeds. **Review heuristic for "is swallowing this read safe?": trace whether any SAFETY verdict downstream defaults to the permissive value on empty input. Here it defaults to `unknown` (restrictive), so safe. If a downstream path instead treated "no data" as "free/allowed", swallowing would be Critical.**

### 2026-06-20 — detect-anomalies.ts: aggregate-of-aggregates, fully PII-free, PermissionValidationMixin omission justified (sixth admin-only aggregate repo)
Reviewed `functions/src/analytics/detect-anomalies.ts` + `lib/repositories/anomaly_repository.dart` + sibling model/widget. **Security/PII: clean.** Output doc `analytics/anomalies/daily/{date}` stores only: `date` (string), `computedAt` (Timestamp), `anomalies[]` where each entry is `{metric: string, today: number, mean: number, z: number, direction: "up"|"down"}`. Metric strings are fixed constant tokens (`recipes_total`, etc.) — no userId, no hashed uid, no email, no free-text at any stage. **Function scope: read analytics aggregates only, write analytics only.** No access to user collections, no deletes, no side-effects. `readNumericField` coercion guard (`typeof raw === "number" && isFinite(raw)`) prevents NaN/Infinity entering z-score arithmetic. Read budget ≤145 reads/day (5 series × ≤29 docs). **PermissionValidationMixin omission: justified.** `AnomalyRepository` omits mixin, consistent with the five sibling admin repos (SiteConfigRepository, EngagementRepository, RecipeStatsRepository, OpsLogRepository, ParseEventsRepository). The `analytics/**` rule (`allow read: if isAdmin()`) at firestore.rules:2144–2146 is the enforcement layer; the mixin exists for user-scoped ownership checks, inapplicable here. **Sixth admin-only aggregate repo** following the established pattern. **Admin-bypass justification checklist (reusable):** (1) read-only or write-to-analytics-only? (2) gated by `isAdmin()` in rules? (3) PII-free output? (4) fail-safe error handling? All four must hold; if any fails, mixin is mandatory.

### 2026-06-20 — WS3 validate-limit + on-suggestion-created: two new patterns confirmed clean; two Medium findings

**`clampLimit()` (validate-limit.ts):** Correctly closes the unbounded-read vector on admin callables. Rejecting non-integer/non-positive with `HttpsError("invalid-argument")` is RIGHT — silent coercion of `limit=0` via `|| 50` would produce 50 (wrong, not the fallback semantics). Both `getCorrectionStats` and `getUnmatchedIngredientStats` apply it. **Confirmed pattern:** admin callables that accept a `limit` param MUST use `clampLimit()` (not inline `|| fallback`) to make the validation explicit and auditable.

**`on-suggestion-created.ts` log stub:** `hashUid(suggestion.userId)` is correct; `suggestion.originalName` is an ingredient name, not PII per the existing classification (same posture as `track-unmatched-ingredients.ts` ingredient strings). Log gated on `process.env.MODERATOR_EMAIL` — no unconditional PII emission. Clean.

**Medium — `exampleRecipes` trim is racy (track-unmatched-ingredients.ts:125-150):** Post-batch `docRef.get()` returns pre-`arrayUnion` snapshot; trim comparison `data.exampleRecipes.length > 5` fires against stale state and the subsequent `update({exampleRecipes: data.exampleRecipes.slice(0,5)})` trims the old array, not the newly extended one. Fix: transaction-based cap, or restrict `arrayUnion` behind a pre-read length check before the batch.

**Medium — `cleanUserFromLearnedAliases` single-batch, no chunk guard (analyze-corrections.ts:381-389):** Uses `db.batch()` with unbounded `snapshot.forEach`. A prolific user with >500 alias docs exceeds the Firestore 500-op ceiling and throws mid-GDPR-cascade. Fix: `commitInChunks(..., { label: 'gdpr-learned-aliases', strict: true })` — `strict:true` because partial purge leaves userId in the alias trail.

**Reusable checklist for new admin analytics callables:** (1) `clampLimit()` on every client-supplied `limit`; (2) no raw UID in any log line — always `hashUid`; (3) GDPR cascade functions that loop-and-batch MUST use `commitInChunks` with appropriate `strict` flag; (4) post-batch reads against Firestore may not reflect the just-written `FieldValue` operations — never use a post-batch read to enforce a size cap.

### 2026-06-21 — WS10 UID-masking sweep: interpolation guard complete; structured-arg gap and false-positive surface noted
Reviewed 4 representative files (`firebase_user_repository.dart`, `data_export_service.dart`, `user_root_deletion_mixin.dart`, `presence_service.dart`) post-transform. **All three questions: clean.** (1) Every `AppLogger.*` call that previously interpolated `$userId`/`$uid` now uses `${userId.maskedUserId}` or `${uid.maskedUserId}` — confirmed by regex sweep (0 raw matches remaining across all 44 lib/ files). (2) Transform touched only `AppLogger.` statement strings; no non-log code changed, no false-positive masking of non-uid variables named `userId`/`uid`. (3) Structured-arg pattern `{'userId': userId}` does not appear in any AppLogger call — the export service's `export_metadata` block writes `'user_id': userId` to the returned JSON payload (not to a logger), so it is intentional and out of scope. **Architectural note:** the guard in `architecture_test.dart` catches interpolation-style raw UIDs but cannot catch structured-map or positional-arg leaks — a secondary rule checking `AppLogger.*({.*'uid.*': \w+})` could close that gap if the surface grows. No action needed now (0 instances found).

### 2026-06-21 — recipe shared-read widening (memberPermissions key-check): APPROVED; `in` on a Firestore map checks keys, not values
`allow read: if isOwner(userId) || (isAuthenticated() && request.auth.uid in resource.data.get('socialData',{}).get('memberPermissions',{}))` — the Firestore Security Rules `in` operator on a **map** checks KEY membership (not values). `resource.data.get('socialData',{}).get('memberPermissions',{})` safely returns `{}` when either level is absent, so the second branch evaluates to `false` for non-collaborative (social-data-less) recipes with no extra read cost. The integer `enumIndex` values are irrelevant; only key presence gates the read. **No subcollections exist under `/users/{uid}/recipes/{recipeId}`** (grep confirmed: single `match` block, no nested `match` blocks), so member read-access carries no hidden escalation surface via subcollection inheritance. Write paths (create/update/delete) stay owner-only + admin moderation; the allergen-critical `isValidTagResult` validation on create/update is completely untouched. GDPR: read-only widening to explicitly-shared UIDs is acceptable under Art-6(1)(b) (performance of a sharing contract the owner initiated); no new collection, no new PII field, no new logging of raw UIDs. Test suite covers all four matrix cells (owner-read ✓, member-read ✓, stranger-read ✗, member-write ✗). **Pattern to re-apply:** whenever a permission map `{uid: someValue}` is written to Firestore and the rule must admit exactly those UIDs, `request.auth.uid in resource.data.someMap` is the correct CEL idiom — it checks keys, which is what you want; value-based checks would require `resource.data.someMap[request.auth.uid] != null` (different shape).

### 2026-06-21 — saveFeedback permission gate: correct; audit-log resource ID is client-generated not Firestore auto-ID (Low)
`FirebaseFeedbackRepository.saveFeedback` now correctly sequences: `requireCurrentUserId()` → `validateCreatePermission()` → `logPermissionCheck()` (captures both grant and deny) → throw on deny → `collection.add()`. No bypass path exists. `auditRepository` nullable no-ops gracefully per base-mixin contract. **One Low cosmetic gap:** the audit log records `'FeedbackEntry/${entry.id}'` (the client-pre-generated UUID) but `collection.add()` generates its own Firestore document ID, so the two will diverge if `entry.id` differs from the stored doc ID. Remediation if cross-referencing audit logs to Firestore docs matters: switch to `collection.doc(entry.id).set(toFirestore(entry))` so the IDs agree. No security or GDPR impact.

### 2026-06-21 — readSharedRecipe: rules-only authorization is correct for cross-user point-read; null-on-denied is an acceptable UX contract; no logging = gap vs project pattern (Medium)

`FirebaseRecipeRepository.readSharedRecipe({ownerId, recipeId})` reads `/users/{ownerId}/recipes/{recipeId}` across ownership boundaries. Four questions assessed:

**1. Rules-only authorization is correct here.** The Firestore rule (widened in the prior commit: `isOwner(userId) || request.auth.uid in resource.data.get('socialData',{}).get('memberPermissions',{})`) is the ONLY gate needed. Rationale: the method is a *point-read* of another user's doc, so no client-side permission cache can be authoritative — the source of truth is whether the rule allows the read. This is consistent with `fetchUserRecipes` and `fetchPublicUserRecipes`, which also cross ownership and also rely solely on rules (rule: `isOwner || isPublic`). Client-side pre-check on a cross-user read would require fetching the doc first to inspect `memberPermissions`, which IS the read itself — so a pre-check adds a redundant round-trip and is not the project pattern for this surface.

**2. Returning null on permission-denied is acceptable but requires caller awareness.** The contract returns null on both "doc not found" and "permission-denied" — the caller cannot distinguish them. This is intentional per the doc comment ("callers can fall back gracefully"). This is the right UX contract for a shared-recipe feed: showing "not shared with you" vs "deleted" is not useful. However, callers must NOT treat null as a safe retry signal or use it to log a diagnostic that reveals the ownerId/recipeId pair to an unauthorized user. Risk is LOW if callers follow the intent; no finding if the call sites are well-behaved.

**3. No raw-uid logging introduced — but also no logging at all.** The method emits zero log lines (no `AppLogger.*` call). This is not a PII violation (no masking needed) but IS a gap versus the project pattern: other cross-user reads (`fetchUserRecipes`, `fetchPublicUserRecipes`) emit `trace.putAttribute('user_id', userId)` via `FirebasePerformanceService.traceFirebaseQuery`. More importantly, the base `read()` path calls `logPermissionCheck(...)` for every read. `readSharedRecipe` bypasses the base `read()` method (by calling `getCollectionForUser(ownerId).doc(recipeId).get()` directly) so it also bypasses the audit-log call. For a cross-user read this is a genuine gap — if an unexpected permission-denied fires, there is no log to distinguish "legitimately not a member" from "rules not deployed yet". **Medium finding: add `logPermissionCheck(...)` on both success and permission-denied branches**, consistent with base class pattern. Use `${ownerId.maskedUserId}` if ownerId is ever interpolated into a log message.

**4. PermissionValidationMixin convention: no explicit client-side hook needed; logPermissionCheck call IS the hook.** The mixin's contract on cross-user reads is NOT "call `validateReadPermission` before every read" — that method checks an already-fetched entity against the current user's id, which is circular for a cross-user point-read gated by rules. The correct application of the mixin here is `logPermissionCheck(...)` (the audit arm), not `validateReadPermission(...)` (the ownership-check arm). The base class `read()` does both, but it reads from the *current user's* collection where it can pre-assert ownership. `readSharedRecipe` deliberately reads another user's collection — the rules ARE `validateReadPermission` in this context.

**Reusable decision rule for cross-user point-reads:** (1) Rules-only gate is correct — client pre-check is a redundant round-trip. (2) null-on-denied is an acceptable UX contract when the caller cannot act on the distinction. (3) `logPermissionCheck(...)` is still required on both branches for audit. (4) `validateReadPermission(...)` is NOT required (it would be circular). (5) Any log interpolating the ownerId must use `.maskedUserId`.

### 2026-06-21 — recipe-share-request flow: accept-boundary guard + index required; idempotency race pattern
Reviewed `lib/repositories/firebase/firebase_social_request_repository.dart` (new `recipeShareRequestExists`) + `lib/services/social/modules/recipe_share_request_module.dart` (new `RecipeShareRequestModule`).

**Rules coverage:** The existing `social_requests` create rule (`auth.uid == fromUserId + status == 'pending' + isNotBlockedBy(toUserId) + isAccountMatured() + rateLimitWrite(10)`) covers `recipeShareRequest` writes without change — the rule is type-agnostic by design. No new rule block needed; no forge-identity risk at the rule layer.

**High — Accept boundary unguarded.** `acceptRecipeShareRequest` never verifies that the caller is `request.toUserId`. Denial is caught two layers down inside `shareRecipeWithUsers` via `recipe.createdBy != currentUserId && socialData?.ownerId != currentUserId` — which blocks non-owners but does not confirm the caller is specifically the intended acceptor of this request. The guard must be explicit at the accept boundary: `if (me == null || me != request.toUserId) return false;`. General rule: acceptance of a social request must verify the caller is `request.toUserId` before touching any downstream service — don't rely on the sharing service's ownership check as the authorization boundary.

**High — Missing composite index.** `recipeShareRequestExists` runs a 5-field equality query (`fromUserId + toUserId + recipeId + type + status`). Existing indexes only cover 3-field `(fromUserId, type, sentAt)` and `(toUserId, type, sentAt)` — first production call throws `FAILED_PRECONDITION`, falls into the outer catch, returns `false`, and the idempotency guard silently fails (double request + double notification). Required index: `(fromUserId ASC, toUserId ASC, recipeId ASC, type ASC, status ASC)` in `firestore.indexes.json`. **Pattern: every new idempotency-check query must be verified against `firestore.indexes.json` in the same review.**

**Medium — Write-write race on idempotency check.** Two near-simultaneous taps both pass the `recipeShareRequestExists → false` check before either write lands, producing duplicate docs and duplicate FCM notifications. Fix: use a deterministic doc ID (`${fromUserId}_${toUserId}_${recipeId}_rsr`) in `SocialRequest.recipeShareRequest()` so a second write is a Firestore-level no-op on the same key. This is the established pattern (`shared_content` idempotency, 2026-05-28 entry). `rateLimitWrite(10)` reduces blast radius but doesn't close the race.

**PII logging: clean.** No raw uid is interpolated in any `AppLogger.*` call introduced by either file. The FCM `additionalData` field `fromUserId` is a legitimate recipient-facing payload (owner needs to know who sent the request), not a log line.

**Data-source convention: correct.** `permissionService.currentUserId` used for auth gating only; `userService.currentDisplayName` used for display data. No mixing.

### 2026-06-21 — CI-only tooling review pattern: scope limited to command-injection + secrets + workflow permissions
When a diff is explicitly scoped to CI tooling with no user data / no Firestore / no auth surfaces, the review scope narrows to three questions: (1) does the CLI use `execFileSync("git", args_array)` (safe) or shell-string interpolation (unsafe)? (2) does the workflow expose secrets or write to any artifact? (3) are workflow permissions minimal (`contents: read` only, or nothing extra)? The GDPR/Firebase/ONNX/presence sections of this knowledge file are irrelevant for such a diff and should be skipped to avoid false positives. **Safe pattern confirmed for `prompt-changelog-guard-cli.ts`:** `execFileSync("git", ["diff", "--name-only", base, "HEAD"])` — array form, no shell interpolation, even though `base` is user-controlled input from `process.argv[2]` (the SHA/ref string). The `execFileSync` array API passes args directly to the OS without a shell, so a malicious `base` value (e.g. `; rm -rf /`) is passed literally as a git argument and rejected by git as an unknown ref — no command injection. **Workflow permissions confirmed minimal:** `permissions: contents: read` at job level, no `id-token:`, no `packages:`, no `secrets:` beyond implicitly available `GITHUB_TOKEN` which is scoped by that same `contents: read`. **No GitHub Actions expression injection risk** in the `run:` block: `$PR_BASE_SHA` and `$PUSH_BEFORE_SHA` are expanded via `env:` (not `${{ }}` interpolation inside the shell script body), which is the safe pattern that prevents shell-metacharacter injection from attacker-controlled PR base refs. Equivalent safe check: env-var expansion in `run:` body = safe; `${{ github.event.pull_request... }}` directly inside a shell command string = injection risk.

### 2026-06-22 — FirestoreSearchRepository.searchUsers (BUT-840): PermissionValidationMixin absence is documented-exempt; `isSearchable` + `isHidden` client-filter combination is privacy-correct; single-field equality needs no composite index; `isPublic` (Algolia) and `isSearchable` (Firestore) are semantically equivalent discoverability flags on different data planes
`FirestoreSearchRepository` does not extend `BaseFirebaseRepository` or use `PermissionValidationMixin`. This is the same established exempt category as `AlgoliaSearchRepository` (BUT-886 note in its doc comment): neither repo touches Firestore for auth gating — `AlgoliaSearchRepository` doesn't touch Firestore at all, and `FirestoreSearchRepository` hits a world-readable (authenticated) collection where ownership validation is meaningless (a search result is not a per-user resource). Treat `SearchRepository` implementations as infrastructure, not user-scoped CRUD repos — absent mixin is not a Critical finding here. **Discoverability field parity:** Algolia path filters `isPublic:true` against its own index; Firestore path filters `.where('isSearchable', isEqualTo: true)`. `isSearchable` is the canonical Firestore field on `public_profiles` controlling user discoverability (confirmed in rules line 478: `request.resource.data.isSearchable is bool`). `isPublic` in the Algolia index is a separate copy built by the CF indexer — functionally equivalent but denormalized. No semantic mismatch; this is by design. **`isHidden` client-filter:** documented in knowledge 2026-06-14 — `fetchProfile`/`fetchProfiles` do NOT filter `isHidden`; only the search path does. The BUT-840 change correctly preserves this pattern: `.where('isSearchable', isEqualTo: true).limit(hitsPerPage)` server-side, then `if (data['isHidden'] == true) return null;` client-side. Since Firestore returns at most `hitsPerPage` docs before the client-side filter, a large cohort of moderation-hidden users with `isSearchable:true` could consume all slots and return zero results. This is a Medium UX issue (empty search), not a security issue — hidden users' data is not leaked (they're simply skipped). If ever a concern, move `isHidden:false` to the server filter and add the composite `(isSearchable, isHidden, displayNameLower)` index already present in `firestore.indexes.json`. **Index:** `.where('isSearchable', isEqualTo: true)` single-field equality is auto-indexed by Firestore; no composite needed for this exact query shape. The compound `(isSearchable ASC, displayNameLower ASC)` and `(isSearchable ASC, isHidden ASC, displayNameLower ASC)` indexes in `firestore.indexes.json` would serve a richer server-side query but are not REQUIRED for the current single-field query. **Field exposure:** `displayName/avatarUrl/publicRecipeCount/friendsCount` are all fields `public_profiles` is designed to expose to authenticated readers (`allow read: if isAuthenticated()`). No sensitive field leaks. **`email` residual (from 2026-06-14):** `public_profiles` does carry `email` and the read rule exposes it to all authenticated users regardless of `allowEmailSearch`. BUT-840 change doesn't write or read `email` in the search hit — the mapper reads only `displayName/avatarUrl/publicRecipeCount/friendsCount`. The existing `email` exposure is a pre-existing documented issue, not introduced by this change. **Blocked-by relationship:** neither the Algolia nor Firestore search path filters by block relationships (only `isSearchable`+`isHidden`). Consistent by design — search is a discovery surface, block enforcement belongs to the social action layer (friend request create already has `isNotBlockedBy` in rules). No gap introduced here.

### 2026-06-24 — BUT-1354: scheduled/trigger handler extraction to testable core — safe pattern confirmed
When extracting a Cloud Functions handler body into a separately-exported `async function` for integration-test purposes, the security review must confirm three things: (1) **no new network surface** — the exported core is an ordinary async function, not a new `onSchedule`/`onCall`/`onRequest` registration, so it is unreachable from the network regardless of being exported; (2) **byte-for-byte behavior preservation** — the only structural change is that `const db = admin.firestore()` either becomes a parameter (`cleanupOldRateLimitsCore(db)`, `cleanupSharedContentMetadataCore(db)`) or is left as a module-level close-over (`cleanupUserSocialData`) with the test pointing the emulator at module init time; (3) **GDPR cascade completeness** — for user-deletion functions, verify no cascade step was removed, reordered, or made conditional. The `return results` addition to a void function that previously accumulated counters internally is additive and safe — the trigger discards the return value, tests assert on it. **Module-level `db` pattern for user-deletion:** when `db = admin.firestore()` is at module scope (not inside the function), tests must set `FIRESTORE_EMULATOR_HOST` BEFORE `admin.initializeApp` and BEFORE `require`-ing the module — the emulator binding happens at module-load time. This is the established project pattern (see 2026-04-26 presence entry). Injected `db` parameter is also acceptable (used for the two scheduler functions) and arguably easier to test in isolation — pick the injected form when the module scope is not already committed. Neither form introduces a permission bypass.

### 2026-06-25 — rate_limiter.ts GDPR log-masking fix (BUT-1377): PASS; field-rename has no consumers; docKey raw-UID exemption confirmed
Three-point review of the BUT-1377 diff on `functions/src/middleware/rate_limiter.ts`. **1. No raw UID reaching a log sink.** Both `logger.warn` call sites (~line 488, ~line 507) now interpolate `hashUid(userId)`, confirmed by grep: zero `logger.*userId` matches remain in the file. The only remaining raw-UID usage in the file is `.doc(\`${userId}_${operationType}\`)` — this is a Firestore document KEY under the user's own subcollection (`/users/{userId}/rateLimits/`), not a log sink and not broadly-readable (gated by `isOwner`). Exemption confirmed — document keys under a user-scoped path are not a PII log-exposure vector. **2. Field rename `userId` → `userIdHash` in `system_events` has no broken consumers.** `rate_limit_violation` event type is written ONLY in `rate_limiter.ts` and is the sole writer of that event type (grep confirms). `system_events` is `allow read: if isAdmin()` in `firestore.rules` line 2170 — admin-only, not broadly-readable. No other `functions/src` file reads or references `rate_limit_violation`'s field shape. `daily-snapshots.ts` reads `system_events` for `byType` counts only (the `type` field, not `userId`/`userIdHash`) — unaffected. **3. `system_events` access scope: admin-only.** Even before this fix the collection was not readable by regular users, so the pre-fix raw `userId` field was not a publicly-accessible PII exposure — this is a defense-in-depth hardening, not a critical breach fix. **Reusable pattern:** when a Firestore collection is admin-SDK-write + `isAdmin()`-read-only, a field-rename is zero-risk to consumers unless admin tooling reads that specific field by name (always grep for the event type string, not just the collection name, to confirm isolation).

### 2026-06-25 — BUT-1376: batchUpdateQueryPaginated cursor-pagination pattern — confirmed correct; stateless cursor is acceptable for at-least-once retry
`batchUpdateQueryPaginated` in `functions/src/shared/batch-update.ts` uses `orderBy(FieldPath.documentId())` + `startAfter(lastDoc)` (document snapshot cursor, not a value cursor). Correctness depends on the invariant that the update never mutates the field(s) in the base query's `where` clause — both ingredient cascade call sites update only `core.tagResult.generatorVersion` while filtering on `core.ingredientsNormalized`, so docs cannot fall out of or back into the result set mid-run. No skips or duplicates possible. **Stateless cursor (medium operational note):** if `withTimeout` fires mid-pagination, the in-flight `batch.commit()` completes on the network stack, the outer catch re-throws, and Cloud Functions retries from page 1. Already-updated docs receive an idempotent overwrite (same fixed string value). This is correct at-least-once behavior but means a very large fan-out that consistently hits the timeout will re-process from the beginning on every retry. Not a bug — document it and monitor `totalUpdated` logs if fan-out grows large. **Early-exit guard:** `if (snapshot.size < limit) break` on line 89 is correct — a partial page is always the last page; no extra round-trip wasted. **Zero-result path:** both call sites check `totalUpdated === 0` after the paginated call and log an explicit info line — confirmed.

### 2026-06-25 — BUT-1376 part 2: cursor-paginated aggregator review — one Medium finding (db.getAll without .select on users); three files otherwise clean
`north-star-weekly.ts` `fetchWindowAgg`, `suppress-low-performers.ts` `aggregateByType`, and `correlate-notifications.ts` are all correctly structured. Cursor correctness: all three use `orderBy` on the same field as the `where` range clause (createdAt/sentAt/openedAt), keep the cursor field in `.select()`, set `lastDoc` to the last doc of each page before the `size < PAGE_SIZE` break, and break on `snap.empty` for the zero-result path. No skips or duplicates possible. Aggregation correctness: Set-based distinct-user logic in fetchWindowAgg is equivalent to the old single-.get() (union across pages = same set); fold pattern in aggregateByType is correct (same Record<> across calls, bump closes over the right entry). **One Medium finding:** `correlate-notifications.ts` line 81: `db.getAll(...chunk)` fetches full `users/{uid}` documents with no `.select()` projection, but only `lastActiveAt` is consumed. The `users` document contains `email`, `fcmToken`, `fcmTokenUpdatedAt`, allergen prefs, and other private fields that flow into Cloud Functions memory unnecessarily. Fix: `db.getAll(...chunk, { fieldMask: ["lastActiveAt"] })` (Admin SDK `getAll` accepts `ReadOptions` as the last argument: `{fieldMask: string[]}`). **GDPR logging: clean.** All three files log only counts, notification types, and aggregate metrics — no raw UID appears in any `logger.*` call.

### 2026-06-26 — BUT-1372/1373/1374: GDPR/idempotency fixes — three patterns confirmed

**onDocumentCreated at-least-once idempotency via transactional claim (BUT-1374).** The correct pattern is: (1) keep an early `logger.info` before the transaction for monitoring purposes (acceptable — retries produce a duplicate log entry, not a duplicate action); (2) inside `runTransaction`, re-read the doc (`tx.get(ref)`) — never rely on the creation-time event snapshot, which has stale pre-retry state; (3) bail if `!current || current.markerField`; (4) `tx.update` sets the marker; (5) any side-effecting code (email send, downstream write) sits OUTSIDE the transaction, gated on the returned boolean. This mirrors the `onReportCreated` pattern and is race-safe because only the first concurrent execution wins the transaction and the rest see the marker set.

**TTL-cleanup drain loop without startAfter (BUT-1372).** For a filter-based delete loop, startAfter is neither needed nor safe: the same `where("field","<",cutoff).limit(BATCH_LIMIT)` query returns fresh matching rows after each deletion round because deleted docs no longer satisfy the filter. Short-page break (`snapshot.size < BATCH_LIMIT`) correctly identifies the last page without an extra empty round-trip. The loop is termination-safe: each pass shrinks the matching set, which is finite and non-replenishing during a cleanup run. A wall-clock timeout guard is good defence-in-depth for runaway cases; the cleanup resumes from the beginning on the next scheduled run (TTL filter ensures idempotency). Contrast with `batchUpdateQueryPaginated` (BUT-1376 pattern) which DOES need startAfter because it does NOT delete the docs it touches — without a cursor it would revisit the same page forever.

**commitInChunks opsPerItem accounting (BUT-1373).** One `batch.update()` call = 1 op regardless of how many `FieldValue.*` modifiers are inside the update map (they are merged into a single Firestore write, not separate ops). A callback that stages `batch.update(ref, { arrayField: FieldValue.arrayRemove(x), counter: FieldValue.increment(-1) })` is `opsPerItem=1` (default). Only an additional `batch.delete()`/`batch.set()`/second `batch.update()` in the SAME callback body pushes opsPerItem to 2+. The helper's `itemsPerChunk = floor(500 / opsPerItem)` ensures batch cap compliance. Returns items QUEUED (not commits succeeded) — using the return value as "docs matched and attempted" is correct; "commits succeeded" would require catching per-chunk errors, which the best-effort mode intentionally swallows.

**count field inaccuracy after GDPR erasure in learned_aliases (BUT-1373, Low).** The `count` field in `analytics/ingredients/learned_aliases/{docId}` is decremented by exactly 1 per GDPR erasure call, but a single user can have incremented it multiple times (one per correction event, before arrayUnion deduplication). After erasure, `count` may be inflated by `(user's contribution count - 1)`. This does NOT affect the auto-approval logic, which gates on `uniqueUsers = new Set([...docData.userIds, params.userId]).size >= THRESHOLD` (the `userIds` array, not `count`). `count` is a display/diagnostic counter only. Accepted Low finding; no code change warranted unless count starts driving approval decisions.

### 2026-06-20 — daily-snapshots.ts aggregation jobs: PII-free + idempotent confirmed; ISO-string day window has a local-vs-UTC boundary mismatch (Medium)
Reviewed `functions/src/analytics/daily-snapshots.ts` (5 nightly `onSchedule` jobs writing `analytics/<group>/daily/{date}`, admin-SDK, mirrors `compute-feature-retention.ts`). **Security/data-integrity: clean.** Every job is read-only on its source (`parse_events`, collection-group `recipes`, `parsing_corrections`, `system_events`, `feedback`) and write-only to `analytics/**` via `dailyDocRef(...).set(result)` — exactly one deterministic doc per UTC day. No source mutation, no destructive op, no cross-collection write. `analytics/**` is admin-read in rules and admin-SDK bypasses rules legitimately (server context). **GDPR/PII: clean.** Aggregate docs store ONLY counts and low-cardinality non-personal dimensions: `byDomain` (site hostnames), `byMethod` (url/photo/textPaste/social/manual), `byType` (system-event type strings), `byCategory` (feedback category enum), and integer totals. No `userId`, no email, no hashed uid, no free-text feedback `description`, no `recentInteractions`, no `deviceInfo` — the PII-bearing fields on the source `feedback`/`recipes` docs are read but never projected into the snapshot. Domain strings are the same posture as ParseEventsRepository (admin-only, treated like server access logs). **Idempotency: confirmed.** Deterministic id = UTC `yyyy-mm-dd` via `formatUtcDate(startOfUtcDay(now))`; `set()` not `create()` → same-day retry overwrites cleanly. **Cost: bounded.** Four jobs are single one-day range scans; the only unbounded source (`collectionGroup('recipes')`) is hard-capped `.limit(RECIPE_SCAN_CAP=5000)` with a `logger.warn` on cap-hit (counts become a floor — documented to switch to a `core.createdAt`-windowed incremental query when it fires). **One Medium finding — feedback ISO-string window:** the comment's claim that string range-compare is correct *because ISO-8601 sorts lexicographically = chronologically* is true ONLY when both sides are the same zone+format. The snapshot builds boundaries with `new Date(ms).toISOString()` → always UTC with a `Z` suffix (e.g. `2026-06-20T00:00:00.000Z`). But the writer (`feedback_service.dart` → `FeedbackEntry.toMap`) stores `clock.now().toIso8601String()`, and `clock.now()` (package:clock) defaults to `DateTime.now()` = **LOCAL** time, so stored values are local wall-clock with NO `Z` (e.g. `2026-06-20T02:00:00.000` at UTC+2). Lexicographic compare of a no-offset local string against a `Z`-suffixed UTC boundary mis-buckets events near midnight by the local offset (and the differing string length/suffix makes the comparison semantically wrong, not just shifted). Impact is LOW today (≤1 beta user, feedback is rare, only edge-of-day rows misclassify, and it only skews the dashboard delta series — no data loss, no security/PII effect). **Fix options:** (a) normalize the writer to UTC — `clock.now().toUtc().toIso8601String()` — so all stored values carry `Z` and match the boundaries (also fixes any future Timestamp migration); or (b) build boundaries WITHOUT the `Z`/millis to match the stored local format (fragile — breaks if writer ever changes). Prefer (a). Recommend also a one-line comment on `FeedbackEntry.toMap` documenting that `createdAt` is queried as an ISO string server-side so the format/zone is a contract, not an implementation detail. **General lesson: when a CF range-queries a STRING timestamp, verify the WRITER's exact format+zone (open the Dart `toMap`), not just that "ISO sorts lexicographically" — the invariant holds only if writer and query agree on offset and suffix.**

### 2026-06-27 — Age-floor rule pattern: create vs update asymmetry is intentional (BUT-1384)
When Firestore rules enforce an age floor on a settings doc, the **create** branch should be stricter than **update** by design: create must require `birthYear` to be present AND valid (non-null int in range), while update should allow `birthYear` to be absent from the write keys OR explicitly null — that is the legacy/backfill escape hatch for pre-gate accounts. This asymmetry is not a loophole: a new signup cannot sneak through create with a null or missing birthYear (rejected), and an existing user who already passed create cannot regress below the floor on update (int-valid branch enforces the same floor). CEL evaluation note: in CEL `null is int` is `false`, so the `is int` type-check on create is sufficient to reject both null and missing-key cases — no separate null check is needed on the create branch. The null-on-update path is accepted and must be explicitly preserved until the signup Cloud Function (ADR-0002) becomes the authoritative writer and closes the bypass. Do NOT flag the create/update asymmetry as a security gap — it is the documented pattern. For SECURITY.md age-gate runbooks under Swedish law: the floor is 15 (Dataskyddslag 2 kap. 4 §, information-society services with a social component), NOT 13 (GDPR Art. 8). Art. 33 72-hour window anchors to "becoming aware", assessment documentation is required even when no notification is sent, and IMY is the correct Swedish supervisory authority.

### 2026-06-28 — BUT-1413 PII-scrubber: adversarial review of three-part fix

**Gap 1 (list-branch `_scrubStringLeaf`):** Verified clean. Both Dart and TS list branches correctly pass the parent `key` to `scrubStringLeaf(key, v)`, so list items under a URL-keyed field inherit URL treatment. A URL-shaped string under a generic-keyed list also gets URL treatment because `_scrubStringLeaf` checks the value prefix (`startsWith("http")`) independently of the key. The scalar path is unchanged in behavior — `_scrubStringLeaf` is used for both, so they cannot drift.

**Gap 2 (`slugContainsPii`):** Verified correct for the happy-path cases. Replaces `-`/`_` with spaces, runs `scrubPii`, returns true if changed. Street address slugs (`storgatan-14`) and honorific-name slugs (`mormor-Anna`) correctly redact. Ordinary food slugs (`gulasch-med-svamp-russin`) correctly pass through because none of the heuristic regexes fire on all-lowercase dictionary words. **One Medium divergence** (filed below): Dart's `Uri.pathSegments` auto-decodes percent-encoded segments before `_slugContainsPii` sees them; TS's `pathname.split("/")` does not decode. A `mormor%20Anna`-shaped URL segment would be caught on the Dart side but missed on the TS side.

**Gap 3 (`looksLikeBase64Blob`):** The 128-char floor with all-base64url-alphabet heuristic is sound. Real PII categories all fail: emails contain `@`/`.` (not in alphabet for `@`); personnummer is at most 13 chars; phone numbers contain spaces (not in alphabet); Swedish street/name strings contain å/ä/ö/é (not in alphabet). A plain 128+ char slug of `[a-z-]` would formally pass the alphabet test, but natural-language text of 128+ chars is never purely `[A-Za-z0-9+/\-_=]` (spaces, commas, periods are absent). URL values themselves always contain `://` (`:` not in alphabet) and thus always fail the blob check, so URL scrubbing is never bypassed. No exploitable false-positive leak path found at the 128-char floor.

**TS `/g` regex footgun documented in the code itself:** `LONG_ALPHANUMERIC_RUN` (no `/g`) is used for `.test()` inside `looksOpaquePathSegment`; a separate `LONG_ALPHANUMERIC_RUN_GLOBAL` (with `/g`) is used for `.replace()` inside `scrubFragment`. This is correct — sharing a `/g` instance between `.test()` and `.replace()` would cause `lastIndex` drift on the `.test()` side. Dart has no such issue (no `/g` flag on Dart `RegExp`). The TS code correctly handles this.

**Percent-encoded URL path segments (Medium divergence):** Dart `Uri.pathSegments` decodes `%20` → space before `_slugContainsPii` runs; TS `pathname.split("/")` does not decode. A URL segment like `mormor%20Anna` is caught by Dart's `scrubPii("mormor Anna")` (RELATION_NAME_REGEX matches) but passes through TS's `scrubPii("mormor%20Anna")` (no match — `%` breaks the trigger's `\s+`). In practice URLs with literal space-as-`%20` in the path are unusual (clients sending path segments to an LLM callable would normally have clean ASCII slugs), so impact is low. But the divergence is real and untested.

**No `_opaqueKeys` or public API changes:** `_opaqueKeys = {'imageBase64'}` / `OPAQUE_KEYS = {'imageBase64'}` unchanged. `scrubPayload` and `scrubPii` are the only exported symbols; `scrubUrlParams`, `looksLikeBase64Blob` also exported from TS for testing. No write/throw paths changed.

### 2026-06-28 — BUT-1404 audit-log purge: `not-in` missing-field exclusion is a real hole (writeRejectionAudit)
`purgeAuditCategoryWithDb` ("general" branch) uses `where('operation','not-in',CONSENT_OPERATIONS)`. Firestore `not-in` EXCLUDES docs where the `operation` field is absent or null — those docs are invisible to BOTH the `not-in` query (general purge, skips them) AND the `in` query (consent purge, also skips them). Any doc without `operation` is therefore never purged — an Art-5(1)(c) minimisation gap.

`writeRejectionAudit` in `functions/src/account/verify-signup-age.ts:306-311` writes to `audit_logs` without an `operation` field (shape: `{reason, basis, timestamp}` only). These docs are emitted on every under-15 rejection. Under the BUT-1404 fix they escape both purge buckets forever.

All other CF write paths set `operation` unconditionally:
- `cascade-audit-log.ts` `stageCascadeAuditEntry` / `writeCascadeAuditEntry` — always set
- `ping_onCreate.ts:100-104` — always set  
- `moderate-upload.ts:173-175` — always set
- `verify-signup-age.ts:287` (the compliant-row writer `writeComplianceAudit`) — always set
- Client-side `AuditLog.toFirestore()` — always set; the Firestore create rule also requires `operation` via `hasRequiredFields(['userId','operation','resourceType','timestamp'])` so client writes without `operation` are denied

The hole is confined to `writeRejectionAudit`. Fix: add `operation: "age_verification_rejected"` to that `.add({...})` call (matching the comment at line 307 which already names that value but omits it from the document). After fixing, add a test asserting the rejection-audit doc has an `operation` field.

`CONSENT_OPERATIONS` array is exhaustive for all other known consent ops (`consent_age_verification`, `consent_granted`, `consent_updated`, `consent_revoked`). The `consentOperationsArrayIsExhaustive` test in the test file pins these four but does NOT include `age_verification_rejected` (correctly; it's not a consent op).

**Query validity / index:** `not-in` on `operation` + range `<` on `timestamp` is a multi-inequality query. Per Firebase docs (Admin SDK 9.13+) this is allowed across different fields without a required `orderBy`. The result ordering is by `operation` (the inequality field) then by document ID, NOT by `timestamp`. The `.limit(maxDocs)` therefore does NOT select the oldest-first docs — it selects docs sorted by operation string collation first. This means repeated weekly runs could page through the same operation-name cluster repeatedly before advancing to the next. In practice this is a scheduling/completeness concern, not a correctness hole: each run still deletes valid candidates, and the next run finds whatever remains. The purge is eventually consistent across runs. No `orderBy` omission error will occur; the index `(operation ASC, timestamp ASC)` satisfies the query (inequality field must match the first orderBy when one is present, or match the implicit operation ordering when not).

**`truncated` flag:** computed as `deleted >= MAX_DOCS_PER_RUN_PER_CATEGORY` at the caller in the scheduled CF. This is correct — `purgeAuditCategoryWithDb` returns exactly `matching.length` (the post-filter count), not the original window size. If the server-side-filtered result hit the `maxDocs` limit then `deleted == maxDocs`, flag is true. If less than maxDocs were found, `deleted < maxDocs`, flag is false. Semantics are accurate.

**Index correctness:** the `(operation ASC, timestamp ASC)` composite on `audit_logs` (COLLECTION scope) is required (both `not-in`/`in` on operation and range `<` on timestamp are inequality operators; per the accepted-deviations rule, multi-inequality across fields needs a composite). The index is present and correct. No spurious flag.

**CONSENT_OPERATIONS exhaustiveness test** (`consentOperationsArrayIsExhaustive`) is structurally real: it asserts a hardcoded `knownConsentOps` list against the exported `CONSENT_OPERATIONS` array. However the hardcoded list is maintained by the test author, not derived from the codebase — a new `consent_*` op added without updating both the list and the array would still pass. This is the acknowledged limitation of the pattern; the comment in `purge-expired.ts:49` asks contributors to update the list manually. Acceptable as a speed bump with a pointed comment; not a critical gap given the list is short and the diff is visually obvious.

### 2026-06-27 — BUT-1386 (ADR-0002) age gate: full dual-layer enforcement reviewed clean
The complete `verifySignupAge` implementation (CF `functions/src/account/verify-signup-age.ts` + `firestore.rules` `isAgeCompliant()` + client `age_verification_service.dart` + `onboarding_viewmodel.dart`/`onboarding_view.dart`) closes the BUT-1384 self-declaration bypass and is the **authoritative-writer-plus-custom-claim** pattern worth reusing. Key invariants confirmed:
- **Custom claim, not a Firestore `get()`, as the gate.** `isAgeCompliant()` reads `request.auth.token.ageCompliant == true` — token-bound (unspoofable, only Admin SDK can set it) AND zero Firestore reads on every hot UGC write. A rules `get()` would bill one read per comment/message/request/rating forever. All four UGC create paths (`recipe_comments`, `messages`, `social_requests`, `recipe_ratings`) gate on it unconditionally; `birthYear` writes are denied on both the profile doc and `settings/preferences` (create: must be absent/null; update: must equal existing) so the CF (Admin SDK, bypasses rules) is the sole writer.
- **Two-collection audit split for data minimisation.** COMPLIANCE row (`audit_logs` op `consent_age_verification`, 730-day retention via `consent_` prefix) stores only `userIdHash`, `isAgeCompliant`, `birthDecade` ("1990s") — no raw birthYear, no email. REJECTION row (op `age_verification_rejected`, no `consent_` prefix → 180-day) carries NO identifier and NO birthYear at all — by design it must be impossible to derive that a specific person is <15 (Legal). When reviewing any "we blocked a minor" record, the absence of uid/birthYear is the requirement, not an omission to flag.
- **Fail-closed everywhere confirmed:** per-user `enforceRateLimit` throws on `!allowed` and its `checkRateLimit` catch denies; per-IP `enforceIpAuditCap` denies on both cap-hit and transaction error (hashed-IP + hour-bucket counter); under-15 `auth.deleteUser` failure throws `internal` so the client never proceeds as admitted.
- **Auth-first under-15 sequencing:** account deleted synchronously server-side (triggers existing `onUserDeleted` cascade); client `completeOnboarding` returns `false` BEFORE any onboarding write, view's `_handleAgeRejection` does `signOut()` + `pushNamedAndRemoveUntil(auth)` — no residual writes possible.
- **Token-refresh contract:** `setCustomUserClaims` doesn't mutate a token already in hand; client `verifyAge` force-refreshes (`refreshSession()`) on `compliant:true` BEFORE any UGC screen, else first write denies on the stale token. Refresh is best-effort (Firebase auto-refreshes hourly) so a transient hiccup doesn't block onboarding — acceptable because the rule fails closed, worst case is a one-shot retry.
- **Idempotency:** claim-already-set → no-op success (no duplicate birthYear write / audit row); ordering is claim → birthYear → audit so a mid-failure never leaves a user able-to-post without a recorded age.
- **Minor PII-in-logs note (Low, accepted):** the two error catches spread the raw `err` object (`logger.error(..., { err })`) alongside `hashUid(uid)`. An `auth.deleteUser`/Firestore transaction error message can embed the raw uid. Low severity — it's the operating account's own uid on an error path in Cloud Logging (not the audit collection, not cross-user), and uid is already known in that execution context. If tightening later, log `err.message`/`err.code` rather than the whole object. Not a release blocker.

### 2026-07-07 — Swedish decimal-comma tension in the ingredient Sheet: comma is BOTH a list typo and a decimal separator (BUT-1495 review)
`sync-ingredients-core.ts` `csvToFirestore` now splits `aliases_sv` on `/[;,]/` (humans type ',' instead of the ';' convention, and an unsplit blob alias poisons `normalizedNames`, the diacritics-stripped allergen-lookup surface). Reusable quirk: in a Swedish-locale Sheet, a comma inside a cell can be a *decimal separator* ("mellanmjölk 1,5%") — the same file already normalizes `avg_price_sek` decimal commas two lines up. A blanket `[;,]` split fragments such an alias into junk entries ("mellanmjölk 1" + "5%") that (a) enter `normalizedNames` and (b) stop the intact alias from matching → allergen verdict degrades to hidden-UNKNOWN, silently. When reviewing any future Sheet-parsing change: check every comma-split against the decimal-comma case; the digit-safe split is `/;|,(?!\d)/`. Mitigation that exists today: the sync report's `updated` entries show aliasesSv before/after, so the fragmentation is human-reviewable before it ships. Filed Medium 2026-07-07.

### 2026-07-07 — lookupFromRaw fan-out: compound "och" split × variation generation multiplies Firestore reads (BUT-1496 review)
`IngredientLookupService.lookupFromRaw` now expands each raw line via `IngredientParser.parseCompoundIngredient`, which splits on every `" och "` with NO cap (`ingredient_parser.dart:181`). Each unique unmatched part then walks the full lookup ladder: user-repo findByName + global findByName + findByAlias + (per generated variation) findByName + findByAlias — roughly `3 + 2×variations` reads, and `lookupIngredients` runs all names concurrently via `Future.wait`. Read cost per line went from ~one ladder to parts×ladder; a pathological "a och b och c …" line is an unbounded read amplifier (mirrors the 2026-05-04 "bound the worst case, not the typical case" rule for `.snapshots()` limits). Mitigations in place: dedupe set, LRU null-caching (500 entries), variations filtered to length>2. Pattern to apply next time: any parser that can turn 1 input into N lookups needs a cap at the split site (e.g. take the first ~8 parts). Filed Medium 2026-07-07.

### 2026-07-07 — BUT-1477/1478/1479 review: TTL-field three-point checklist; daily-cap pattern confirmed; system_rate_limits location supersedes the 2026-06-25 path note
**TTL-field checklist (reusable — apply whenever a CF starts writing `expireAt`):** adding the field is only 1 of 3 required steps. (1) **Policy enablement** — `gcloud firestore fields ttls update expireAt --collection-group=<name> --enable-ttl` is a per-collection-group admin action, NOT deployed with functions or `firestore.indexes.json`; without it the field is inert. There is NO central runbook tracking which collection groups have the policy enabled (presence-ttl-runbook.md covers only `expiresAt` on presence collections; `record-notification-opened.ts`/`notification-send-events.ts`/`llm-sample-capture.ts` each document the command inline). (2) **Backfill** — TTL only reaps docs that HAVE the field; docs written before the change linger forever unless backfilled or bulk-deleted. (3) **Deletion-cascade cross-check** — if the collection carries raw `userId`, verify `on-user-deleted.ts`/`account-deletion-cascade.ts` covers it or that the TTL window is an explicitly accepted residual (like the storage noncurrent-version 30d posture, 2026-04-27). BUT-1478 (parse_events) shipped step 1-of-3: no runbook/deploy note, no backfill, and the deletion cascade does NOT touch parse_events (only admin `reset-user-data.ts` lists it).
**Daily-cap pattern (BUT-1477) confirmed correct:** `evaluateDailyCap` runs BEFORE the minute-bucket check inside the same transaction/doc (denied request consumes neither bucket tokens nor daily count; counter increments only on allow); day key is `getUTCMonth()` 0-based, equality-only — matches `checkGlobalLimit`, never parsed back, so 0-basing is safe; legacy docs without `dayKey` read as fresh day. Counter is tracked for ALL ops but enforced only when config declares `dailyLimit`.
**Supersedes part of 2026-06-25 (BUT-1377):** rate-limit buckets live at top-level `system_rate_limits/{userId}_{operation}` (no rule block → caught by the final default-deny match, so clients cannot read or reset them), NOT under `/users/{userId}/rateLimits/`. Raw UID in the doc ID is fine (admin-SDK-only surface, not a log sink).
**Pre-existing ordering weakness in `withRateLimit`:** `checkGlobalLimit()` increments the shared `system/llmLimits` counters BEFORE the per-user check, so per-user-denied spam still burns the global budget (default 1000/h — one hostile client can starve everyone) and every request transacts on one hot doc. Known, pre-existing, Medium.

### 2026-07-11 — Boundary-move review (BUT-1551): the mapped-exception must PROPAGATE raw from the repo, not be pre-caught
Routing the underage age-gate cleanup from a direct `FirebaseAuth.instance.currentUser?.delete()` in the view through a new `AuthService.deleteCurrentAuthUser()` → `AuthRepository.deleteCurrentUser()`. Review clean. The load-bearing invariant when a service maps a `FirebaseAuthException` to a result enum: the repository method (`firebase_auth_repository.dart:128` `deleteCurrentUser`) must let the exception propagate RAW — it does NOT try/catch — so the service's `on FirebaseAuthException catch (e)` can read `e.code` (`requires-recent-login` → `needsReauth`). If a future refactor makes the repo swallow/wrap the error, the service's mapping becomes dead code and every failure silently returns `deleted`. Always trace the throw path repo→service before trusting an enum-mapping service method. Best-effort semantics preserved: `currentUser?.delete()` no-ops on null user in both old and new code; view awaits the never-throwing service call then signs out regardless (orphan reaped by session-expiry). Quiet error handling (no `errorMessage` set, unlike `deleteAccount()`) is correct HERE because it's a non-user-initiated block flow, not a user delete — do not flag "swallows the error" on age-gate/forced-cleanup paths. PII-in-logs clean: typed catch logs only `e.code`; the generic `catch (e)` logs `$e` but only catches non-FirebaseAuth errors (identical to the prior view code — no regression), and `.delete()`'s generic errors carry no user identifier.

### 2026-07-11 — GDPR export truncation signal: fetch `limit+1`, trim back to `limit` (BUT-1562)
Reusable idiom for any capped GDPR/portability export that must honestly report completeness: to distinguish "exactly `limit` records exist (complete)" from "more than `limit` exist (truncated)", fetch `maxDocuments: limit + 1`, set `truncated = fetched.length > limit`, and export `included = truncated ? fetched.take(limit) : fetched`. Keying `truncated` off `length >= limit` is an off-by-one that falsely stamps a COMPLETE export of exactly `limit` items as truncated — a wrong completeness claim on an Art. 15/20 export. Verified in `preferences_export_manager.dart` `exportNotifications` (`user_notifications`, cap 500). Three invariants to confirm on such a fix: (1) records the subject RECEIVES stay ≤`limit` (the `+1` doc is trimmed by `take(limit)` and never serialized — no extra PII, no completeness regression); (2) `truncated` is accurate at all three boundaries (`<`, `==`, `>` limit); (3) the `+1` costs one extra read only at the boundary and is the subject's own data (query unchanged: `where('userId','==',uid)`), so no permission/PII/cost concern. Also made the cap an explicit `exportLimits['user_notifications']=500` entry rather than the `defaultBatchSize` fallback — the manager now depends on that value, so it should be a defined contract, not a coincidence.

### 2026-07-14 — Roster-diff deletion of children's ratings must fail CLOSED on an untrusted keep-set (BUT-1600 post-hoc review)
`purge-dormant-family-data.ts` `reconcileDepartedMemberRatings` deletes every `family_ratings` doc whose `memberId` is NOT in a "roster" keep-set, then nulls the denormalised `core.familyAverage/familyRatingCount` pills. **Two structural lessons for any roster-diff / orphan-sweep over user data:**
1. **id-space union (this one is CORRECT — reusable positive pattern):** `family_ratings.memberId` is polymorphic — an account `userId` for `memberType.user`, a `DinerProfile.id` for `memberType.profile` (see `household_roster_member.dart` doc + `family_rating.dart`). The keep-set MUST union BOTH spaces: `rosterMemberIds = households/{hid}.memberUserIds ∪ (diner_profiles where householdId==hid).docs.map(d=>d.id)`. `diner_profiles` doc.id == `DinerProfile.id` because `BaseFirebaseRepository.create` writes at `getId(entity)` and the diner repo's `getId` returns `entity.id`. Verified both spaces covered — no over-deletion from id confusion **provided the keep-set sources are populated.** When reviewing a memberId-keyed sweep, always confirm which id-space each source contributes and that a polymorphic id has all its spaces represented.
2. **fail-OPEN gap (finding, Critical):** the keep-set is trusted UNCONDITIONALLY. A THROWN roster read fails closed (Promise.all rejects → processHousehold throws → sweep aborts before any delete — good; and Firestore `.get()` returns the full set or throws, never a transient partial). BUT there is NO plausibility guard: if the denormalised `memberUserIds` array is empty/missing (schema drift, a non-atomic member-management write, an admin-console edit, a migration gap) AND the household has no diner profiles, the keep-set is ∅ and EVERY family rating is deleted as an "orphan" — with `strict:false` (best-effort, silent), no warn, no grace, running every sweep regardless of dormancy, cascading `onFamilyRatingDeleted` → public-aggregation recompute, all irreversible. The existence of a family rating PROVES a member existed, so an empty keep-set is a self-contradiction that must be treated as "abort, delete nothing," not "everyone left." Contrast the dormancy purge in the same file, which is strict:true + warn + 30-day grace. **Rule: a roster/keep-set diff that DELETES user data must refuse to run when the keep-set is empty or smaller than trivially plausible, and should derive account ids from the authoritative `members` list (or cross-check it), not solely from a denormalised projection built for rules queries.** Remediation: guard `if (roster.size === 0) return ratings.docs;` at minimum, plus a members-vs-memberUserIds agreement check before deleting user-type ratings.

### 2026-07-17 — Surfacing a reported owner's minor status in moderation is fail-closed + rules-permitted (BUT-1609, clean review)
Reviewed `ReportService.isMinorAccount(userId)` + its `ModeratorReviewViewModel` cache. **Clean — reusable positive patterns:**
1. **Read authority is correct and the admin gate holds.** `users/{userId}` rule (firestore.rules:312) is `allow read: if isOwner(userId) || isAdmin()`; the moderation dashboard runs in an admin context, so the `.get()` is rules-permitted. No new rule needed — moderators already read the full user doc for report handling; surfacing one derived bool is data-minimising (no birthYear/exact age exposed).
2. **`isMinor` stays server-authoritative and client-READ-only.** verifySignupAge (Admin SDK) is the sole writer; rules block client writes (create requires `isMinor==null` at 328-330, update pins it immutable at 331-335). The new code only calls `.get()` — no write path introduced. Confirmed.
3. **Fail-closed direction is correct at BOTH layers.** (a) `snap.data()?['isMinor'] == true` — missing doc (`?.` → null), absent field (null), and literal `false` all yield `false`; only literal `true` flags minor. (b) `getCachedOrExecute(...) ?? false` — on a read error `safeExecute` returns the null defaultValue → `executeServiceOperation` null → `getCachedOrExecute` null → `?? false`. A read failure renders NON-minor, never a false flag. The VM mirrors it: `_minorOwners[id] ?? false`, missing entries render non-minor until the async lookup resolves, and it only `notifyListeners()` when `anyMinor` became true (a false resolution needs no re-render since default is already false).
4. **No PII leak in the VM cache.** `_minorOwners` is an in-memory `Map<String,bool>` (uid→bool) plus an in-flight `Set<String>`; nothing persisted, uid is already in the report the moderator legitimately holds, bool is the only derived datum.
5. **Index is required, not a false positive.** `watchOpenReports` is `.where('status', whereIn: ['new','in_review','actioned']).orderBy('createdAt', descending: true)` — a `whereIn` (multi-value) + `orderBy` on a DIFFERENT field DOES need a composite (the accepted-deviations equality-index waiver covers only pure-equality with no orderBy/range). The added index `reports (status ASC, createdAt DESC)` matches: createdAt direction pinned to the orderBy DESC, `queryScope: COLLECTION` correct for a top-level `.collection(reports)` query.
6. **GDPR/child-safety: protective, not a concern.** Moderation runs on the legal-obligation/legitimate-interest basis of the Apple/Play UGC safety triad (see 2026-04-25 rating-defense entry), not consent; showing a minor flag is extra-care-on-a-child's-content by design. No new consent surface, no over-collection.
Also note the `watchIsAdmin` refactor in the same file: swapped `handleError` (whose callback cannot emit, so a permission-denied would end the stream with no event and strand the UI on a spinner) for a `StreamTransformer.fromHandlers` that `sink.add(false)` on error — correct fail-closed-to-non-admin that actually emits.

### 2026-07-18 — Single-field range query needs no composite index (delta-refresh)
BUT-1475 added an hourly delta refresh to `firebase_ingredient_repository.dart`:
`_collection.where('updatedAt', isGreaterThan: baseline).get()` — one range filter,
no other `where`, no explicit `orderBy`. This uses Firestore's **automatic
single-field index** (ascending/descending are auto-created per field); a composite
index is required only when a range/`orderBy` is combined with another field
(equality or a second sort). Do NOT flag a lone single-field range as "missing
composite index" — it's the same false-positive class as the equality-only
deviation in accepted-deviations.md. Empty delta = 1 charged read (Firestore's
zero-result minimum), served off the index — it does NOT scan the collection, so
the read-cost reduction claim holds.

### 2026-07-18 — `_inFlightIsFull` coalescing: forceReload-after-delta is safe
Pattern for guaranteeing a full re-fetch never settles for an in-flight partial:
a bool flag paired with `_inFlightLoad` (set/cleared with no await between assign
and use, so consistent). `loadCache(forceReload:true)` awaits an in-flight delta,
then unconditionally runs its own `_doLoadCache()`. Worst case is two concurrent
full reloads (double reads) — NOT corruption: `_doLoadCache` clears `_cache`+indexes
only AFTER `.get()` succeeds, and clear+repopulate is synchronous (no await gap for
a reader to interleave), so the end state is always a complete cache. Redundant-load
window is rare (concurrent forceReloads, or the baseline==null legacy path where a
full load runs with `_inFlightIsFull=false`). Acceptable, not a blocker.

### 2026-07-18 — `setLifecycleStage` isMinor gate (BUT-1626/674): defense-in-depth, three impls consistent, no prod caller — COMMIT-READY
`AnalyticsRepository.setLifecycleStage` gained a REQUIRED `{bool isMinor}` and the Firebase impl early-returns before `setUserProperty` when `isMinor` is true; NoOp already emits nothing (consistent, cannot bypass); interface makes the flag required so no future direct caller can omit the gate. Verified the raw setter has NO production caller (only `user_property_setters_test.dart`) — the real runtime suppression is `UserPropertyBootstrap.emitLifecycle`, which has its own inline `if (profile?.isMinor == true) return` and is the only path that actually writes the `lifecycle_stage` user property in prod (session-start via `emitAtSessionStart` + cook re-emit via `recipe_detail_viewmodel`). Both of the two paths that can set the `lifecycle_stage` property are now gated; grep confirms no third writer of `AnalyticsUserProperties.lifecycleStage`. Suppression is genuinely enforced (not doc-only): `verifyNever` test at `user_property_setters_test.dart:220` proves a minor emits nothing. The gate's live efficacy depends on `profile.isMinor` being hydrated client-side, which the settings-merge seam already provides (Critical-2 CLOSED, 2026-07-01 entry). No GDPR regression — this strengthens minimization for compliant 15–17-year-olds. Out-of-scope note (NOT this diff): server-side `functions/src/analytics/track-retention.ts` computes a `lifecycleStage`-sliced cohort row independently and is not affected by this client gate — separate mechanism, cloud-functions territory, already noted there.

### 2026-07-19 — Firebase Storage download URLs are percent-encoded — string-matching the object path against them silently fails
`FirebaseStorageRepository.deleteThumbnail` guards on `imageUrl.contains('/recipes/')` and derives the thumbnail path via `.replaceAll('/recipes/', '/recipes/thumbnails/')`. It is called from `deleteImage` with the stored **download URL** (`taskSnapshot.ref.getDownloadURL()`), whose path segment is percent-encoded (`users%2F{uid}%2Frecipes%2F…`). So `contains('/recipes/')` is always false on a real download URL → the guard short-circuits and **thumbnails are never deleted** (orphaned Storage objects on every image delete; account-deletion GDPR is still covered because the cascade walks the whole `users/{uid}/` tree per the comment in `uploadImage`). General rule for this repo: any Storage helper that reasons about the object path must operate on the **decoded** path (mirror `_extractUserIdFromPath`, which correctly does `Uri.decodeFull` first) — never string-match a raw download URL against unencoded `/segment/` literals. Related asymmetry: `createAndUploadThumbnail` builds the thumb path from the **raw** storage path (real slashes, so replace works) while delete uses the encoded URL — the two halves disagree by construction. Also noted in the same sprint: (a) `OptimizedImageLoader._buildFullImage` records a cache-MISS in `progressIndicatorBuilder` AND a cache-HIT in `imageBuilder` for the same fresh network load, inflating the hit-rate metric (both `_hasRecorded*` guards are independent, so a miss-then-load counts as one of each); (b) `IntelligentCacheManager.dispose()` calls the async fire-and-forget `_saveBehaviorPattern()` then synchronously `_behaviorCache.dispose()`, so the final behavior-pattern save races a disposed cache and can be dropped; (c) `_preloadTimeBasedContent` filters candidates by `_recipeCache[e.key]?.data.mealType`, i.e. only recipes ALREADY cached — which `_preloadRecipes` then skips as already-present, making the method an effective no-op; (d) `generateFileName` uses `DateTime.now()` while the file imports `clock` — trips the real-time-guard and diverges from the file's own `clock.now()` usage.

### 2026-07-20 — Storage upload authz funnels through `uploadImageData`; negative upload tests must assert the MECHANISM, not the null return (BUT-1558)
`FirebaseStorageRepository` has exactly ONE storage write (`storageRef.putData`, in `uploadImageData`, immediately after `_validateUploadPermission`). `uploadImage` (File), `uploadMultipleImages`, and `createAndUploadThumbnail` all delegate to it, so removing `uploadImage`'s own duplicate `_validateUploadPermission` call is safe — no branch reaches storage unvalidated (the compression-failure branch throws before delegating; the `StorageUploadException` rethrow is post-validation). **Invariant to re-check on any edit here: `putData` must remain unreachable except downstream of `_validateUploadPermission` in the same function.** Two residual effects of the dedup, both accepted-Low: compression now runs BEFORE authorization (local CPU on the user's own file — but it inverts check-before-work), and a foreign-path attempt whose compression fails now produces ZERO audit entries where it previously logged a DENIED check.
**Test-design lesson (general, not storage-specific):** every failure mode of these repositories collapses to `return null`, so `expect(result, isNull)` in a negative-permission test proves nothing — it passes identically for compression failure, storage error, or a deleted check. The only mutation-killing assertion is the side-effect one (`mockStorage.storedDataMap.get(foreignPath)` is null). Two further traps: (a) such a test silently depends on the fixture bytes surviving compression (3-byte payloads pass only because they're under `UploadConstants.skipCompressionThreshold`) — if that changes, the method short-circuits before validation and the test goes green while proving nothing, so pair every negative case with a positive control (same fixture, OWN path → bytes DO land); (b) `auditRepository` is an OPTIONAL constructor param and the existing suite omits it, making `logPermissionCheck` a console-only no-op — so no test in this file can currently prove the GDPR Art.30 audit entry is written. Any diff justified by "the other call site is audit-logged" must inject a fake audit repository and assert the `granted:false` entry, or the audit half of the claim is unpinned.

### 2026-07-20 — Minor-searchability reassert (BUT-1637/1629): server-authoritative pre-save read is correct; two edges to know
`UserProfile.toFirestore` forces `isSearchable:false` for a minor at the single public_profiles serialization chokepoint, so EVERY full-document save (`saveProfile` via `toFirestoreEditable`, which keeps the derived `isSearchable`) silently revokes an opted-in minor's discoverability. `UserService.createOrUpdateProfile` compensates: it reads the authoritative value with `FirebaseUserRepository.fetchPersistedSearchable` (a `Source.server` `.get()`, deliberately NOT cache-first — a stale cached `true` would let an unrelated edit re-grant an opt-out made on another device) BEFORE the save, then restores via the `setProfileSearchability` Admin-SDK callable AFTER. Core safety invariant HOLDS: `actuallySearchable = minorReassertSearchable(server pre-save) && callable==true`, so a save can never make a minor MORE discoverable than the server already says — no privacy escalation, callable is itself rules-guarded (BUT-1626). `getCollectionRef()` == `collection` getter (both public_profiles) — not a wrong-collection read. No audit/permission concern on the read: it targets the caller's own world-readable public_profiles doc.
Two accepted-but-worth-knowing edges:
1. **Offline / failed-read save silently and PERMANENTLY drops an opted-in minor's discoverability with NO user feedback.** On a `fetchPersistedSearchable` throw the catch sets `minorReassertSearchable=false`; the queued `saveProfile` still lands `isSearchable:false`, the restore callable never runs (short-circuited), and the error branch (`if (minorReassertSearchable && !actuallySearchable)`) does NOT fire because the flag is false — so the minor must manually re-opt-in later with no indication why. This is the documented fail-closed (safer = less discoverable) direction for a child-safety feature, so it's intended — but the silent permanence is a real UX edge, not obvious from the code.
2. **Cost:** every minor profile save now issues an extra forced `Source.server` read, plus (for opted-in minors) an extra CF write to restore. Bounded to minors + infrequent saves; acceptable.
**Test gap (in-scope file):** `setMinorSearchable` — the actual opt-in WRITER — has no direct behavioral test in `user_service_test.dart`; only the reassert path inside `createOrUpdateProfile` is covered. The viewmodel test mocks `setMinorSearchable` away, so the service method's own branches (stored==null → setError + no cache update; stored → cache update + notify) are unpinned. For a child-safety writer, pin the contract at the service layer.

### 2026-07-25 — BUT-1665 shopping-list transaction: the fix landed on a facade with ZERO production callers (shopping sprint review)
`ShoppingRepositoryRoutingModule.mutateCollaborativeList` (new) wraps a read-modify-write of `unified_shared_shopping_lists/{listId}` in `firestore.runTransaction`, and `ListItemOperations.addItem/toggleItemBought/removeItem` were rewired from `updateList(cachedList)` to that transactional seam. The stated defect — "one member ticking mjölk erases the other member's tick on bröd" — is real, but **the rewired methods are dead in production**. Grep of `lib/` for `collaborative.addItem` / `collaborative.toggleItemBought` / `collaborative.removeItem` / `\.items\.addItem` returns nothing outside the `CollaborativeShoppingOperations` facade's own delegation. The live path is: `lib/views/social/collaborative_shopping_view.dart:112` and `lib/views/unified_shopping_view.dart:229` → `UnifiedShoppingViewModel` / `viewmodels/collaborative_shopping/shopping_item_operations_manager.dart:70,114` → `UnifiedShoppingService.addItemToActiveList` / `toggleItemBought` → `ShoppingItemManagementModule` (`repository.addItem` / `repository.updateItem`) → `ShoppingItemOperationsModule.addItem/updateItem/removeItem` → `updateCollaborativeList(entity)` — a non-transactional `readList()` + whole-`items`-array `set(merge:true)`. So the lost-update window survives the ticket, and the new tests (`collaborative_shopping_operations_test.dart`) prove only that a mock seam receives a mutator. Remediation: route `ShoppingItemOperationsModule`'s collaborative branches (addItem, addItemsBatch, updateItem, removeItem, removeItemsBatch) through `mutateCollaborativeList`, or wire the UI to the `collaborative.*` facade — and delete whichever path loses.
Four secondary observations from the same diff:
1. **`runTransaction` has no offline path.** `lib/core/bootstrap/firestore_bootstrap.dart:10` sets `persistenceEnabled: true`; a `set()` applies to the local cache immediately (snapshot listeners fire, sync later), a transaction does not exist offline and fails with `unavailable`. A grocery app used in-store converts "tick works, syncs later" into "tick fails". Any transaction conversion on a user-facing write path needs an explicit offline fallback or a written accepted-deviation.
2. **`transaction.set(docRef, mutated.toFirestore(), merge:true)` writes the full document**, including `ownerId`/`memberPermissions`/`createdAt`. The rule at `firestore.rules` `match /unified_shared_shopping_lists/{listId}` (allow update) lets a non-owner member write only when `diff().affectedKeys()` excludes those three, so the write passes ONLY because they round-trip byte-identically through `Timestamp.fromDate(createdAt)`. A targeted `transaction.update({items, updatedAt, lastActivity*})` is smaller, cheaper and immune to a future serialization change.
3. **No permission check, but an unconditional `granted: true` audit row.** `mutateCollaborativeList` calls `requireCurrentUserId()` then `logPermissionCheck(granted: true)` with no membership/`validateUpdatePermission` gate — unlike `FirebaseShoppingRepository.delete`, which validates and logs the real verdict in the same file. Rules are the real backstop (not an access hole), but the audit trail records a check that never happened. `updateCollaborativeList` has the same shape; fix both together.
4. **No-op mutations still bill a write and still report success.** `toggleItemBought`'s mutator returns `live` untouched when another member deleted the item; the transaction writes it back anyway and the caller returns `true`, so the ViewModel's `logShoppingListItemChecked` + `onItemCheckedOff` pantry seam fire for a toggle that did nothing. `if (identical(mutated, live)) return live;` before `transaction.set` fixes both. The new test at `collaborative_shopping_operations_test.dart` ("toggling an item another member deleted is a no-op, not an error") currently codifies the `true` return.
Also in the same sprint diff: `MenuShoppingListGenerator._logGenerationAnalytics` (BUT-1670) fires one `shopping_list_item_added` per line in an unbounded loop, and because `items` is the full REPLACEMENT set on a regenerated week (the `existing.isNotEmpty` branch reuses the list), every regeneration re-counts every pre-existing line as a fresh `menu_generated` add — inflating exactly the funnel the ticket exists to make readable. Its `try/catch` also cannot catch anything: the tracker calls are un-awaited `Future`s (harmless only because `FirebaseAnalyticsRepository.logEvent` swallows internally). `IngredientCategorizer` (BUT-1666) lookarounds are correct for the cited cases; residual misfiles are `ostron`→dairy and leading-`nöt` NUT compounds (`nötsmör`, `nötmix`, `nötkräm`)→meat/dairy, both pre-existing and uncovered by the golden set.

### 2026-07-25 (re-review) — BUT-1665/1666/1670 shopping sprint: fixes verified on the LIVE path, three prior findings still open
Re-review of the same sprint diff after automated fixes. **Confirmed fixed and correct:**
(a) the dead-twin problem — `ShoppingItemOperationsModule` (the module the UI actually reaches) now routes all five collaborative branches through `mutateCollaborativeList`, so the transaction covers the real path, not just the `ListItemOperations` facade; (b) the missing permission gate — `mutateCollaborativeList` now runs `_requireEditRights` (owner OR `edit`/`admin`) against the LIVE doc *inside* the transaction and `updateCollaborativeList` validates the STORED doc, so the audit rows record real verdicts; `_requireEditRights` mirrors `firestore.rules:1620-1626` and `ShoppingPermissionModule.canEditShoppingList` exactly; (c) the offline hole — `_mutateFromCache` falls back to a cached-base merge write on `unavailable`, matching pre-BUT-1665 in-store behaviour. `validateUpdatePermission` is pure in-memory (no reads), so awaiting it inside the transaction handler is safe, and every mutator passed in is retry-idempotent (the `UnifiedShoppingItem` is constructed outside the closure). `flutter analyze` clean on all 8 in-scope files; routing-module, collaborative-ops, unified-service, VM, generator and golden suites all green (`ci-011`..`ci-017` verified by hand against the rule order).
**Still open from the 2026-07-25 first pass:** (1) no `identical(mutated, live)` short-circuit before `transaction.set` — a no-op still bills a write and returns success; (2) `transaction.set(..., merge:true)` still writes the full doc including `ownerId`/`memberPermissions`/`createdAt` (survives the rule only because `createdAt` is always `Timestamp.fromDate(clock.now())`, i.e. microsecond-aligned, so the round trip is byte-exact — verified, but a serialization change would deny every member write); (3) `MenuShoppingListGenerator._logGenerationAnalytics` still fires one event per line over the full REPLACEMENT set, so a regenerated week re-counts every pre-existing line.
**New this pass:** `createCollaborativeList` (routing module, lines 55-105) is the untouched sibling — `requireCurrentUserId()` → `set()` → `logPermissionCheck(granted:true)` with no check at all, and it never verifies `entity.ownerId == uid` (rules block the forged-owner create, so audit defect only). `updateCollaborativeList` uses the LOOSE `validateUpdatePermission` (any `memberPermissions` key) while the rule demands `edit`/`admin`, so a view-only member's rename passes the client gate, logs `granted:true`, and is rejected server-side. `_mutateFromCache` keys the offline fallback on `unavailable` alone — a flaky in-store connection also surfaces `deadline-exceeded`/`aborted` after the transaction's internal retries, which fall through as hard failures; and `docRef.get(Source.cache)` on a doc never cached throws `unavailable` from inside the catch block (correctly propagates, but is indistinguishable from a real error to the caller). No test covers the offline branch at all. The whole BUT-1670 analytics change (VM `source` parameter, the `wasBought == false` gating of `logShoppingListItemChecked`/`logShoppingListCompleted`, and the generator's events) has ZERO test coverage — `menu_shopping_list_generator_test.dart` and `unified_shopping_viewmodel_test.dart` contain no analytics assertions. `ListItemOperations`/`CollaborativeShoppingOperations` remain unreachable from any view or viewmodel (re-grepped) — now harmless for correctness since both paths share the transactional seam, but still maintained and tested at cost. Categorizer residuals, all pre-existing and uncovered by the golden set: `ostron`→dairy, leading-`nöt` NUT compounds (`nötmix`, `nötströssel`)→meat, `nötsmör`→dairy (via `smör`), `kokosgrädde`→dairy.

### 2026-07-25 (third pass) — BUT-1665/1666/1670 shopping sprint: transaction seam verified against the PLUGIN source; one sibling still unguarded
Third review of the same working tree. Everything the second pass listed as fixed is still correct, and I re-verified the two claims that were previously taken on faith by reading the plugin, not the app:
- **The 8-second budget is not dead code.** `cloud_firestore-6.6.0/android/.../streamhandler/TransactionStreamHandler.java:81-88` implements the `timeout:` argument as `semaphore.tryAcquire(timeout, MILLISECONDS)` and, on expiry, returns `FlutterFirebaseFirestoreTransactionResult.failed(new FirebaseFirestoreException("timed out", Code.DEADLINE_EXCEEDED))`. So `_offlineCodes = {'unavailable','deadline-exceeded'}` in `ShoppingRepositoryRoutingModule:47` really does catch the budget expiry, and the timeout fires BEFORE any command is shipped to native, i.e. no commit happened. Keying only on `unavailable` (the pass-2 finding) would have left the commonest in-store case falling through as a hard error.
- **Domain exceptions survive the transaction boundary.** `cloud_firestore_platform_interface-8.0.3/lib/src/method_channel/method_channel_firestore.dart:271-287` catches the handler's error, signals native `InternalTransactionResult.failure`, then `completer.completeError(error, stack)` with the ORIGINAL object. So `_requireEditRights`'s `PermissionDeniedException` and the `ResourceNotFoundException` are not rewrapped as `FirebaseException`, and the `on FirebaseException` catch in `mutateCollaborativeList:253` correctly does not swallow them. Native errors arrive as `FirebaseException(code: event['error']['code'])` (same file, lines 249-255).
- `FirebaseShoppingRepository.validateUpdatePermission:181-195` is pure in-memory (ownerId compare + `memberPermissions.containsKey`), so `await`ing it between `transaction.get` and `transaction.set` cannot violate reads-before-writes.
Verification run this pass: `dart analyze` clean on all 8 in-scope lib files; `collaborative_shopping_operations_test.dart` + `categorize_ingredient_test.dart` (17/17) + `shopping_repository_routing_module_test.dart` (25 tests incl. 5 NEW offline-fallback tests that pass-2 reported as missing) all green; `unified_shopping_service_test.dart`, `shopping_item_management_module_test.dart`, `firebase_shopping_repository_mock_test.dart`, `unified_shopping_viewmodel_test.dart` and all of `test/unit/services/shopping/` green.
**Still open (unchanged across three passes):** (1) `createCollaborativeList` (routing module 92-142) — `requireCurrentUserId()` → `docRef.set()` → `logPermissionCheck(granted:true)` with no check and no `entity.ownerId == uid` assertion; the test `createCollaborativeList logs successful permission check on create` codifies the forged row. (2) No `identical(mutated, live)` short-circuit before `transaction.set` (line 236) — the `toggling an item another member deleted is a no-op` test asserts `result == true`. (3) `transaction.set(..., merge:true)` still writes the whole doc incl. `ownerId`/`memberPermissions`/`createdAt`. (4) `MenuShoppingListGenerator._logGenerationAnalytics:272-277` still loops one `shopping_list_item_added` per line over the full REPLACEMENT set, so every regeneration re-counts pre-existing lines; each call awaits `BaseTracker.hasAnalyticsConsent` (base_tracker.dart:37) → `ConsentService.getUserConsent`, which sets `_cachePopulated` only after the first future RESOLVES (consent_service.dart:79-91, no in-flight dedupe), so N un-awaited events on a cold cache issue N concurrent consent reads; the sync `try/catch` at line 278 cannot catch anything thrown inside those futures.
**New this pass:** `mutateCollaborativeList` is now the *softer* of the two siblings — `updateCollaborativeList` gained `_requireNoPrivilegeEscalation` (329-359) but `mutateCollaborativeList` did not, and `mutateCollaborativeList` was simultaneously promoted onto the public `ShoppingRepository` interface (`shopping_repository.dart:28`), so any future caller's mutator may rewrite `ownerId`/`memberPermissions` and still log `granted:true`. Rules block the write, so audit defect, not access hole. `_requireNoPrivilegeEscalation` also omits `createdAt`, which the rule's `hasAny(['ownerId','memberPermissions','createdAt'])` (firestore.rules:1624-1625) does protect. `IngredientCategorizer:159` (`kokosmjölk` inside the canned rule) is now unreachable — the new head-noun check at line 51 claims it first; harmless dead code. Categorizer residuals re-confirmed unchanged and uncovered by the golden set: `ostron`→dairy, leading-`nöt` nut compounds (`nötmix`, `nötströssel`)→meat, `nötsmör`/`kokosgrädde`→dairy. BUT-1670's analytics changes still have ZERO tests (grep of `test/` for `logShoppingListItemChecked`, `source: 'recipe'`, `'menu_generated'` on these paths returns nothing). `ListItemOperations`/`CollaborativeShoppingOperations` re-grepped: still unreachable from any view or viewmodel.

### 2026-07-25 (fourth pass) — BUT-1665 commit gate on `shopping_repository_routing_module.dart` + `interfaces/shopping_repository.dart`: routing is clean, the offline fallback is the new soft spot
Scoped commit-gate review of exactly the two files. **Routing crossover: verified clean in both directions, no finding.** `mutateCollaborativeList` is hard-bound to `sharedListsRef.doc(listId)`, so a personal id fails closed (`ResourceNotFoundException`, swallowed to `false` by `UnifiedShoppingService.mutateSharedList:417`) and never writes personal data into `unified_shared_shopping_lists`. All five `ShoppingItemOperationsModule` methods branch on `list.type == ListType.collaborative` (lines 110/179/258/310/370) with `validateOwnership` on every personal else-branch (128/215/273/332/380), so **both** branches are permission-gated. `ListItemOperations.getListById` resolves only from `_getCollaborativeLists()`. Same-id collision across the two collections is not reachable: `read()` probes shared-then-personal and `convertCollaborativeToPersonal` mints a NEW personal id then deletes the shared doc. No cost regression per tap (before: `read` + `docRef.get` + `set`; after: `read` + `transaction.get` + `set`). No GDPR impact — the account-deletion scrub of this collection is admin-SDK (`functions/src/account/account-deletion-cascade.ts:247`), so the new client guards cannot block it; no client path writes another user's `memberPermissions` on a shopping list, so `_requireNoPrivilegeEscalation` introduces no functional regression.
**New findings this pass:**
1. **Interface promotion changed the threat model and the guard sets diverged.** `updateCollaborativeList` gained `_requireNoPrivilegeEscalation` (routing module 329-359); `mutateCollaborativeList` did not — and the same diff added `mutateCollaborativeList` to the public `ShoppingRepository` interface (`shopping_repository.dart:28`). The escalation guard now protects the module-internal method and NOT the publicly advertised one, whose caller-supplied mutator may return a list with a rewritten `ownerId`/`memberPermissions` and still log `granted:true`. `firestore.rules:1620-1626` denies the write, so audit defect, not access hole. In-repo mutators (`_withItems`, `ListItemOperations`) only touch `items` + activity fields, so nothing is currently exploitable.
2. **The offline fallback re-bases on a stale cache while possibly ONLINE.** `_offlineCodes = {'unavailable','deadline-exceeded'}` (line 47) is documented as "no server round-trip happened", which is false for `deadline-exceeded`: an 8-second client budget also expires on a slow-but-working link. `_mutateFromCache` then rebuilds the whole `items` array from `Source.cache` and queues a merge write, reintroducing exactly the lost update BUT-1665 exists to prevent, and can double-apply an `addItem` whose transaction actually committed late (duplicate row, same item id). Gate the fallback on real connectivity, or restrict `deadline-exceeded` to the case where connectivity is known-down.
3. **Stale-base merge can resurrect removed members — owner-only, and rules cannot stop it.** `_mutateFromCache` writes `mutated.toFirestore()` with `SetOptions(merge:true)`, i.e. the FULL doc including `ownerId`/`memberPermissions`/`createdAt`, from a cache that may predate a membership change. A non-owner's replay is denied by `firestore.rules:1624-1625` (fail-safe, logged by the `catchError`); the OWNER's is allowed by `resource.data.ownerId` on line 1621, so an owner who removes a member on phone A and ticks an item offline on tablet B restores that member's `edit` permission on reconnect. Fix is the long-open targeted `update({items, updatedAt, lastActivity*})`.
4. `_requireNoPrivilegeEscalation` omits `createdAt`, which the rule's `hasAny(['ownerId','memberPermissions','createdAt'])` does protect — a client-side `granted:true` for a write the server denies.
5. `_mutateFromCache` logs `granted:true` from `_requireEditRights` evaluated against the CACHED `memberPermissions` — a real check, but on data that may predate a downgrade. Better than a forged row; still an audit row that can disagree with the server verdict.
**Still open, now for the FOURTH consecutive pass:** (a) `createCollaborativeList` (routing module 92-142) has no permission check at all and logs `granted:true`; note additionally that `FirebaseShoppingRepository.create:219-224` routes the collaborative branch straight to it, bypassing the base class's `validateCreatePermission` (which is exactly `entity.ownerId == userId`), and its `validateRequiredFields(['name','ownerId','memberPermissions'])` is looser than the rule's `hasRequiredFields(['ownerId','memberPermissions','items','createdAt'])` plus `uid in request.resource.data.memberPermissions` (firestore.rules:1612-1615). (b) No `identical(mutated, live)` short-circuit before `transaction.set` (line 236) — a no-op bills a write, returns success, and fires the VM's `logShoppingListItemChecked` + pantry seam. (c) full-doc `merge:true` instead of a targeted update (now escalated by finding 3).

### 2026-07-26 (fifth pass) — BUT-1665/BUT-1683 authz-gate review: the two new gates are correct and fail closed; the misattributed actor name and the unscrubbed `lastActivityBy*` group are new
Scoped review of the four uncommitted files (`shopping_repository_routing_module.dart`, `shopping_item_operations_module.dart`, `firebase_shopping_repository.dart`, `interfaces/shopping_repository.dart`) with the explicit brief of reviewing the two authz gates the fourth pass flagged as unreviewed.
**Verified correct, no finding:**
- `_requireEditRights` (routing 366-393) **fails closed on every path**. `validateUpdatePermission` (`firebase_shopping_repository.dart:181-195`) is a pure in-memory predicate that cannot throw and returns `false`, not null; `&&` short-circuits; `live.memberPermissions[uid] == null` fails the admin/edit test; a throw from anywhere inside propagates out of `runTransaction` verbatim (verified against the plugin in the third pass) and is NOT caught by the `on FirebaseException` handler, so an error can never reach the offline fallback and can never become a grant. It mirrors `firestore.rules:1620-1626` and `ShoppingPermissionModule.canEditShoppingList:76-118` exactly.
- `_requireNoPrivilegeEscalation`'s `rewritesMembers` predicate (routing 337-341) is **complete** — `|stored| == |entity|` plus "every stored key present in entity with the same value" implies map equality for non-null enum values, so neither removing a member (length changes) nor adding an unseen key (length changes, or the paired removal trips the entry loop) escapes it. No escalation vector via removal or a new key.
- **Cost is neutral, quantified.** Real toggle path is view → VM → `UnifiedShoppingService.toggleItemBought` → `ShoppingItemManagementModule:328` → `repository.updateItem` → `ShoppingItemOperationsModule.updateItem:246`. Before: `readList` (1 read) + `updateCollaborativeList`'s `docRef.get()` (1 read) + `set` (1 write). After: `readList` (1 read, still needed for the `type` routing branch) + `transaction.get` (1 read) + `transaction.set` (1 write). 2 reads + 1 write both ways; the only new cost is one extra read per transaction retry under genuine contention, capped by the SDK's 5 attempts — i.e. paid only in the scenario the change exists to fix. Doc-id gets, no index implications.
**New this pass:**
1. **Misattributed actor name on a shared doc.** `_withItems` (`shopping_item_operations_module.dart:71-85`) stamps `lastActivityByUserId: uid` unconditionally but `lastActivityByDisplayName: authRepository.currentUser?.displayName`, and `UnifiedShoppingList.copyWith:441-442` is `?? this.lastActivityByDisplayName` — so when the Auth displayName is null (any account that never set one) the write advances the id to the caller while KEEPING the previous editor's name. On the transaction path the base is now the live server doc, so the retained name is another household member's. Compounding it, the canonical writer of that field is `functions/src/social/on-profile-updated.ts:159-167`, which propagates the PROFILE display name keyed on `lastActivityByUserId` — the repo writes the Auth name, a different string until the user next edits their profile.
2. **`lastActivityBy*` is propagated on rename but never scrubbed on erasure.** `account-deletion-cascade.ts:234-276` (`deleteShoppingLists`) scrubs only item-level `assignedTo*`/`purchasedBy*`; the list-level `lastActivityByUserId`/`lastActivityByDisplayName` and `ownerDisplayName` keep a deleted user's raw uid and name on a retained multi-user doc. Pre-existing, not introduced here — but this diff makes every item tick a writer of that field group.
3. **A non-owner can no longer leave a shared list, and now fails client-side.** `leaveList` → `removeMember` → `_updateList` → `repository.update` → `updateCollaborativeList` → `_requireNoPrivilegeEscalation` throws, because removing self shrinks `memberPermissions`. `firestore.rules:1624-1625` already denied it, so no behavioural regression (both end in `return false`), but the capability is now provably dead, and `canManageShoppingList` (which grants a non-owner `admin`) still gates `shopping_member_management_dialog.dart` — add/remove/permission UI that can never succeed. GDPR-adjacent: a member cannot detach themselves from another user's shared doc.
4. **The offline lost-update deviation is not recorded where the contract requires.** It lives in a code comment, `tasks/todo.md:279` and BUT-1683 — not in `.claude/rules/accepted-deviations.md` nor `docs/architecture/ACCEPTED_DEVIATIONS.md`, which the rules file says must be appended in the same edit.
5. `_mutateFromCache`'s `!cached.exists` branch (routing 275-281) is effectively unreachable on real Firestore — `get(Source.cache)` on an uncached doc throws `unavailable`, which propagates raw rather than as `ResourceNotFoundException`; the test at `shopping_repository_routing_module_test.dart:649` passes only because the fake returns a non-existent snapshot.
**Test coverage is genuinely good this pass** — `shopping_repository_routing_module_test.dart` (664 lines) pins both gates on both paths: intruder denied, view-only denied on `update`/`mutate`/offline, self-promotion to admin denied, owner-rename-of-`memberPermissions` allowed, edit-member rename allowed, `aborted` rethrown, `unavailable`/`deadline-exceeded` falling back. The one gate with no test is the one with no code: no test asserts a mutator that escalates through `mutateCollaborativeList` is refused.
**Verdict: BLOCKED on one item** — for the FIFTH consecutive pass, `mutateCollaborativeList` (routing 208-257 and 268-317) still lacks `_requireNoPrivilegeEscalation(uid, mutated, live)` while its sibling on the same collection and the same public interface has it. `createCollaborativeList` (92-142) remains the third unguarded sibling (no check at all, `granted:true` logged, no `entity.ownerId == uid`).
### 2026-07-26 — BUT-1690: the "degenerate prefix range" that was never degenerate (weekly_menu_plans)

**Verdict: APPROVED, no blocking finding.** Diff: `firebase_weekly_menu_plan_repository.dart` (2 range bounds + class doc), `architecture_test.dart` (new guard), `tasks/lessons.md`, `.claude/rules/lessons-digest.md`. Marker: `.claude/state/firebase-security-done.marker`, sha-pinned via `git hash-object` (verified equal to `git rev-parse :<path>` on an unmodified control file, so the pins survive the parent's `git add`).

**The premise BUT-1690 was filed on was wrong, and the failure mode is worth remembering.** The ticket claimed `exportAllByUser` (Art. 15/20) and `removeRecipeFromAllPlans` used `>= '${userId}_' AND < '${userId}_'` — a closed range matching zero docs, i.e. an empty GDPR export and a no-op recipe cascade. The upper bound in fact carried a trailing LITERAL U+F8FF, a private-use codepoint that renders as nothing in every editor, diff viewer and agent Read output. Proof used here: `git show HEAD:<file> | grep -n isLessThan | cat -A` -> `M-oM-#M-?` = `EF A3 BF` = U+F8FF at both sites. The third range method in the same file (`deleteAllByUser`) already used the escape spelling, so the file was internally inconsistent rather than broken — which is itself the tell to look for.

**Why the conversion is provably behaviour-neutral.** The escape and the literal are the same single UTF-16 code unit, so the string, the range and the row set are identical. Corroborated behaviourally, not just textually: `firebase_weekly_menu_plan_repository_test.dart` covers inclusion AND other-user exclusion for both `removeRecipeFromAllPlans` and `exportAllByUser`, and `weekly_menu_plan_repository_test.dart` (16 tests) covers "delete only the target user's plans when multiple users" plus the >500-doc `batchDeleteDocs` chunking path. All green after the change; `architecture_test.dart` 20/20 including the new guard.

**Permission surface confirmed untouched.** All three range methods still run `requireCurrentUserId()` -> `validateOwnership(currentUserId:, resourceOwnerId: userId, resourceType: collectionName)` BEFORE the query, so a caller-supplied `userId` cannot diverge from the authed uid; `removeRecipeFromAllPlans` keeps its user-level `logPermissionCheck` (BUT-893) after a real `validateOwnership` that throws on mismatch — not the forged-grant pattern. Making an upper bound explicit cannot widen a range. No `firestore.rules` change, so no `firestore-rules-tester` handoff.

**GDPR checks.** The `'weekly_menu_plans': 260` cap in `export_pagination_helper.dart:195` and the `fetchCapped`/`truncated` N+1 probe in `content_export_manager.dart:407-423` are untouched (`git diff --stat` on `lib/services/account/export/` is empty), and `exportAllByUser` still ends `.limit(maxDocuments)`. The new architecture guard walks source files only and prints `path:line` with no line text — zero data surface. Account deletion never used this range: `request-account-deletion.ts:196` -> `account-deletion-cascade.ts` erases weekly plans server-side with `where("userId","==",uid)`.

**Residual, non-blocking:** the guard's scope is `lib/**.dart`, so literal U+F8FF still lives in `functions/src/account/account-deletion-cascade.ts:819,828` (the load-bearing `endAt` of the `system_rate_limits` purge, plus its own comment), `functions/src/__tests__/request-account-deletion.integration.test.ts:729`, and the compiled `functions/lib/account/account-deletion-cascade.js:704`. Correct today and guarded by a "do not tidy it away" comment; a `functions/src` twin of the lint would close it. Already flagged to Malin in the lesson entry.

**Reviewer trap, hit twice while writing this up:** typing the six-character escape into prose silently produces the literal character. Byte-check your OWN review artifacts (grep -P for the codepoint on the marker and this file) before considering the write-up done.

### 2026-07-26 — Shopping sprint (BUT-1681/1683/1696/1697): the offline arrayUnion repair is sound; the Art-15/17 hole is in a collection NAME

**Verdict: BLOCKED on one Critical, unrelated to the four tickets' own logic.** Diff reviewed: `shopping_repository_routing_module.dart` (+235), `shopping_item_operations_module.dart`, `firebase_shopping_repository.dart`, `shopping_repository.dart` (interface), `unified_shopping_list.dart`, `unified_shopping_service.dart`, `shopping_item_management_module.dart`, `unified_shopping_view.dart`, `unified_shopping_viewmodel.dart`, `recipe_shopping_handler.dart`, `menu_shopping_list_generator.dart`, `shopping_events_tracker.dart`, `analytics_service.dart`, `account-deletion-cascade.ts`, both accepted-deviations files, and 7 test files. `flutter analyze` on the 7 production Dart files: clean, 50.1s. No `firestore.rules` change, so no `firestore-rules-tester` handoff.

**CRITICAL — personal shopping lists have never been erased or exported, because of a duplicated constant.** `FirestoreCollections` carries BOTH `unifiedShoppingLists = 'unified_shopping_lists'` (line 40) and `userShoppingLists = 'shopping_lists'` (line 79). The repository writes the first: `FirebaseShoppingRepository.collectionName => FirestoreCollections.unifiedShoppingLists` (line 147) fed to `base_firebase_repository.dart:86-92` `getUserCollection` -> `users/{uid}/unified_shopping_lists`. Both GDPR paths read the second: `account-deletion-cascade.ts:238-247 deleteShoppingLists` deletes `users/{uid}/shopping_lists`, and `firebase_data_export_repository.dart:222 exportPersonalShoppingLists` reads `users/{uid}/shopping_lists`. So Art. 17 erasure and Art. 15/20 export are BOTH silent no-ops on every personal shopping list and every item under it. Three independent corroborations: `firestore.rules` has only `match /unified_shopping_lists/{listId}` (line 394) and no `shopping_lists` block, so the path the cascade targets is default-denied and therefore unwritten; `unified_shopping_lists` appears in neither `deleteUserSubcollections`' Tier-2 list (`account-deletion-cascade.ts:815-832`) nor `probeResidualData`'s canary list (85-95), so the safety net cannot see it either; `grep -rn userShoppingLists lib/ functions/` returns exactly three hits, none of them a writer. Long-standing (`git log -S` dates the constant to the Phase-4 architecture commit and the cascade to BUT-788), not excused anywhere in `ACCEPTED_DEVIATIONS.md`. Second half of the same fix: even with the right name, `batchDeleteAll(db, sub.docs)` does not delete each list's `items` subcollection — Firestore doc deletes never cascade. Fix = point both sides at `unified_shopping_lists`, sweep `{listId}/items` per doc, add the collection to `probeResidualData`. This is the fourth independent instance of the "wrong probe shape" class and the first where the *name* rather than the field was wrong.

**The BUT-1683 offline repair is the right shape and I would approve it on its own.** `_mutateFromCache` now classifies the mutation: `_appendedItems` compares `live.items[i].toFirestore()` against `mutated.items[i].toFirestore()` under `DeepCollectionEquality` for the whole prefix (identity is the serialized ROW, not the id — a tick rewrites `bought` under an unchanged id and correctly fails to qualify), and a pure append is queued as `docRef.update({items: FieldValue.arrayUnion(rows), ...activity})` instead of a whole-array `set(merge:true)`. Verified `UnifiedShoppingItem.toFirestore()` (lines 749-777) is fully deterministic — no `DateTime.now()`, all timestamps derived from stored fields — so the prefix comparison is stable and the optimisation actually fires in production rather than degrading to the fallback. `_activityFieldKeys` deliberately excludes `ownerId`/`memberPermissions`/`createdAt`, which is exactly the `hasAny([...])` set the non-owner update rule forbids (`firestore.rules:1624-1625`), so the narrowed write cannot itself cause the replay denial. Bonus property the diff does not claim: because `arrayUnion` merges server-side, the append path is also safe on the `deadline-exceeded`-but-actually-online case that the previous cached-base write silently corrupted. `_readCachedDoc` closes the unreachable-branch defect I filed last pass (real Firestore throws `unavailable` on a `Source.cache` miss; the fake returns `exists == false`) and the new test mocks the sealed `DocumentReference` to pin the production shape. `_onReplayRejected` branches on `permission-denied` and writes a corrective `granted:false` audit row — the fix for the queued-replay item from the previous pass. The residual is now recorded in BOTH `.claude/rules/accepted-deviations.md` and `docs/architecture/ACCEPTED_DEVIATIONS.md` with the same 2026-07-26 date, closing finding #4 from the last pass.

**`createCollaborativeList` finally gets its guard, on the fifth-plus pass — but only half the rule.** `_requireSelfOwnedCreate` mirrors `auth.uid == request.resource.data.ownerId`. The create rule (`firestore.rules:1612-1615`) is a triple: that, AND `auth.uid in request.resource.data.memberPermissions`, AND `hasRequiredFields(['ownerId','memberPermissions','items','createdAt'])` — while `validateRequiredFields` asks only for `['name','ownerId','memberPermissions']`. A create where the owner is absent from `memberPermissions` still logs `granted:true` and is still refused by the server, i.e. the forged-grant shape survives in a narrower form. `_requireNoPrivilegeEscalation` gaining `createdAt` is correct and matches the rule's third forbidden key. Confirmed the new guard breaks nothing live: the only production create path (`shopping_list_management_module.dart:66-120`) sets `ownerId: currentUserId` and puts the uid in `memberPermissions` as `admin`; `createCollaborativeListFromInvitation` (137+) writes a foreign `ownerId` and has zero callers in `lib/` outside the service facade, so the comment's "always been dead against the same rule" claim is accurate.

**BUT-1697's display-name fix is right in the model and one seam short in the wiring.** `_withItems` now stamps `resolveDisplayName() ?? ''` alongside `lastActivityByUserId`, and `activitySummary` (`unified_shopping_list.dart:386-390`) treats empty as unknown, so `copyWith`'s `name ?? this.name` can no longer keep the previous editor's name while the id advances — the Art. 5(1)(d) misattribution from the last pass. But the injected resolver is `ServiceLocator.tryGet<UserService>()?.currentDisplayName`, and `user_service.dart:88-93` falls back to `_authRepository.currentUser?.displayName` when the profile name is empty, so the Auth handle still reaches the field on exactly the accounts where the two diverge. The new test "the stamped name is the profile name, not the auth handle" passes only because the harness injects `profileName` directly — it pins the seam, not the wiring. The list-level cascade addition is correct and clears the `lastActivityByUserId`/`lastActivityByDisplayName` PAIR plus `ownerDisplayName`, closing the open item I filed against `unified_shared_shopping_lists` last pass, and `ownerId` is correctly left in place (the rules read it). Remaining: the scrub query `where('memberPermissions.{uid}','!=',null)` is a single probe on an OR-owned collection — a legacy list whose owner was never written into `memberPermissions` keeps its `ownerDisplayName`; and the deleted user's raw uid survives as both `ownerId` and a `memberPermissions` key on a doc other members read, which is defensible but is not written down as a deviation the way the `parse_events` TTL residual is.

**BUT-1697's `updateItemsBatch` is a genuine cost/correctness win with an unhonoured contract on the personal leg.** Replacing `Future.wait` over N `updateItem` calls (N transactions against ONE document since BUT-1665 — they contend and roll each other back, which is the reported "avmarkera alla leaves the list half unchecked") with one `mutateCollaborativeList` is exactly right, and the interface doc says items no longer on the list are ignored rather than resurrected. True on the collaborative leg (it maps over `live.items`); false on the personal leg, which `batch.update`s every submitted id, so ONE stale row makes the whole chunk fail `NOT_FOUND` and the user gets `errorNetwork`. Note `read()` returns a personal list with an empty `items` array (items live in a subcollection), so filtering there needs an id read, not a local check.

**BUT-1696's "say why" reaches the user through a shared error field, which can print the wrong reason.** `unified_shopping_view.dart:231-241` reads `_viewModel.error` after a failed toggle, and that proxies `UnifiedShoppingService._error` — the same field set by list-load failures (`shoppingCouldNotLoadLists`, lines 299/319/334). The most likely denial for a view-only member never sets it at all: `UnifiedShoppingViewModel.toggleItemBought:366-369` returns `false` on `!canEditActiveList` with only a log line, as do the three early guards in `ShoppingItemManagementModule.toggleItemBought`. So the view either falls back to the generic `shoppingCouldNotUpdateItem` or, worse, shows a stale "couldn't load lists" as the reason a tick failed. Also `_report(e)` runs BEFORE the rollback in `toggleItemBought` (and `_report` -> `_failMutation` -> `notifyListeners()`), giving listeners one frame of "still ticked, error already set"; `uncheckAllItems` does it in the correct order.

**BUT-1681 analytics: correct on cost, one stale comment.** One `shopping_list_item_added` per bulk add carrying `source` + `item_count` (not N events), and one `shopping_list_created` per genuine generation gated on `wasCreated` so weekly regeneration stays silent — both pinned by tests that assert the COUNT as well as the parameters, using a real `ShoppingEventsTracker` over a mock repository rather than a mocked service method. The comment at `unified_shopping_viewmodel.dart:286-289` still says the menu-generated path "stays analytically silent", which this same diff falsifies.

**Project-standards residual:** `shopping_repository_routing_module.dart` is now 574 lines and `shopping_item_management_module.dart` 520 — both over the 500-line limit and neither in `docs/architecture/ACCEPTED_LARGE_FILES.md`. The recorded counts for the four allowlisted files this diff touches are also stale (`unified_shopping_service.dart` 592 -> 678, `unified_shopping_viewmodel.dart` 686 -> 713, `unified_shopping_view.dart` 625 -> 639, `unified_shopping_list.dart` 837 -> 843).

### 2026-07-26 (post-fix re-review) — Shopping sprint BUT-1681/1683/1696/1697 verified in the working tree: the Art-15/17 collection-name hole is CLOSED; the residual is a membership MAP KEY

Same diff as the entry above, re-read after the automated fixes landed. Verified green: `flutter test` on the six shopping Dart suites (121 tests) and `npm run test:integration:account-deletion` (50/50), plus `dart analyze` clean on the seven changed `lib/` files.

**Closed since the previous pass.** (a) The two-constant Art-15/17 hole: `deleteShoppingLists` now sweeps `users/{uid}/unified_shopping_lists` (legacy `shopping_lists` kept as a safety net), deletes each list's `items` subcollection BEFORE its parent, `probeResidualData` gained the same path, and `FirebaseDataExportRepository.exportPersonalShoppingLists` moved to `FirestoreCollections.unifiedShoppingLists` — export and erasure now target the identical path, with tests on both sides. TS `Collections.unifiedShoppingLists` == Dart `FirestoreCollections.unifiedShoppingLists` == `FirebaseShoppingRepository.collectionName` == `'unified_shopping_lists'`, checked by value. (b) `createCollaborativeList` gained `_requireSelfOwnedCreate`, tested, and no doc is written on the deny path. (c) The `createdAt` conjunct is now in `_requireNoPrivilegeEscalation`, so the client guard mirrors all three forbidden keys of `firestore.rules:1620-1626`. (d) The list-level `lastActivityBy{UserId,DisplayName}` + `ownerDisplayName` scrub and the per-item `addedBy*`/`lastModifiedBy*` anonymization landed, with `ownerId` deliberately retained (rules read it) and `addedByUserId` anonymized rather than nulled (`isCollaborative => addedByUserId != null`). (e) `_readCachedDoc` handles the real-Firestore `unavailable`-throw shape of a `Source.cache` miss, pinned with a mocktail-mocked `DocumentReference` because `fake_cloud_firestore` ignores `GetOptions`. (f) The offline `arrayUnion` append path is real: the test seeds a divergence the fake cannot produce (`fromFirestore` override) and proves the row another member added survives the replay; `_appendPayload`'s whitelist is the exact complement of the rule's forbidden-key triple.

**New finding — the deleted user's uid survives as a `memberPermissions` MAP KEY.** `account-deletion-cascade.ts:292-355` finds shared lists by `where('memberPermissions.{uid}','!=',null)`, scrubs items and the list-level identity pair, and never removes the key it queried on. So after an Art-17 erasure the raw uid remains on every `unified_shared_shopping_lists` doc the user was a member of — a doc the remaining members keep indefinitely — and `firestore.rules:1620-1626` still reads that key as write authorization. The same file already does the right thing twice: `FieldValue.delete()` on `memberPermissions.{uid}` for group weekly-menu plans (line 463) and for the household doc (line 610, deliberately last so a transient earlier failure leaves the re-entry query intact). Fix: add `[`memberPermissions.${uid}`]: FieldValue.delete()` to the SAME per-doc `update(update)` — atomic per doc, so a retry either finds the key still present or finds nothing left to do. None of the 50 cascade tests asserts it, which is why it reads as complete. `ownerId` stays for owner-owned lists (documented, orphan-avoidance) — that is the only justified uid residual here.

**Still open, second pass — the append whitelist is documented, not enforced.** `_appendPayload` (routing module 421-433) carries `items` + four activity keys; `_appendedItems` (404-419) only checks that the items PREFIX is byte-identical. `mutateCollaborativeList` is on the public `ShoppingRepository` interface and `UnifiedShoppingService.mutateSharedList` forwards an arbitrary caller mutator, so a future mutator that appends a row and also changes `name`/`description`/`settings`/`categoryIds`/`autoRemoveCompleted` silently loses that change on the offline path while returning the full mutated object. Enforcement is a serialized-doc diff, not a comment. `syncStatus` is a false alarm: `UnifiedShoppingList.addItem` sets it, but `toFirestore()` never emits it.

**Still open — the sibling display-name writer.** BUT-1697 routed the repository-level stamp through `resolveDisplayName` -> `UserService.currentDisplayName` (profile-first, Auth-fallback) and taught `activitySummary` to read empty as unknown. `UnifiedShoppingService.currentUserDisplayName:270-271` is still `authRepository.getCurrentUser()?.displayName ?? 'Du'`, and it feeds `ownerDisplayName` + `lastActivityBy*` at collaborative-create time (`ShoppingListManagementModule.createCollaborativeList`) and the whole `ListItemOperations` facade — so another household member can read a member's name as the literal `'Du'`. `ListItemOperations` still has no production caller outside the unified service, so the facade half is latent; the create half is live.

**Repeat verdicts, unchanged after the fixes:** the stale shared `_error` read (early-return `false`s set no message and `_error` is never cleared before the mutation; `_report` also fires before the rollback in `toggleItemBought`); `updateItemsBatch`'s personal leg `batch.update`s every submitted id so one stale row fails the whole chunk `NOT_FOUND`, contradicting the interface doc; no `identical(mutated, live)` short-circuit before `transaction.set` (sixth pass — now bounded to one billed write per bulk call instead of N, and every live mutator bumps `updatedAt` so the short-circuit only fires for the dead facade's deleted-item no-op); the 500-line limit is exceeded by `shopping_repository_routing_module.dart` (574) and `shopping_item_management_module.dart` (520), neither allowlisted, and four allowlisted counts remain stale.

**Non-findings worth not re-filing:** `validateUpdatePermission` is pure in-memory (owner check + `memberPermissions.containsKey`), so awaiting `_requireEditRights` between `transaction.get` and `transaction.set` issues no read and is safe. The new analytics emits are fire-and-forget but cannot raise an unhandled async error — `ConsentService.checkSafely` and `FirebaseAnalyticsRepository.logEvent` both catch internally — and consent still gates every event inside `BaseTracker.logEvent`. `unawaited_futures`/`discarded_futures` are both disabled in `analysis_options.yaml`, so the un-awaited emit is not a lint violation here.

### 2026-07-26 (third pass, same working tree) — Shopping BUT-1681/1683/1696/1697: no Critical/High left; the map-key residual is CLOSED, three repeats stay open

Third read of the same tree (post-fix), scoped to the 23 files named by the sprint driver. Verified green myself before writing anything: `flutter test` on the six shopping Dart suites + the model suite = **258 tests, all passed**; `dart analyze` on the nine changed `lib/` files = "No issues found"; `npx tsc --noEmit` in `functions/` = clean; `npm run test:request-account-deletion` = 4/4. The emulator-backed `test:integration:account-deletion` was not re-run this pass (the previous entry recorded 50/50 on it).

**CLOSED since the second pass.** The `memberPermissions.{uid}` ACL-key residual I filed last time has landed exactly in the recommended shape: `account-deletion-cascade.ts` now stages `update[`memberPermissions.${uid}`] = FieldValue.delete()` inside the SAME per-doc `update(update)` as the item + list-level scrub, with a comment explaining that the key is the step's own re-entry query handle (so a split write would make the retry skip an unscrubbed doc). A sole-member owned list is DELETED rather than scrubbed, which is the right call — a scrubbed list with no readable member is retention without a purpose. `probeResidualData` gained both new legs (`memberPermissions.{uid}` count, and a doc-reading `ownerId == uid` sole-member leg that deliberately does not count a list other members still share). Also closed: the report-before-rollback frame hazard — `_failMutation` sets a field and does NOT notify, so ordering no longer matters; and the shared-`_error` read — the view now consumes a dedicated read-once `consumeMutationError()` that `hasError`/`_emitState` never touch, so a failed tick can no longer replace the shopping tab with a full-screen error.

**No Critical and no High introduced.** Re-verified the load-bearing claims rather than trusting the comments: `_activityFieldKeys` (`updatedAt`, `lastActivityAt`, `lastActivityBy{UserId,DisplayName}`) is the exact complement of the non-owner update rule's forbidden `hasAny(['ownerId','memberPermissions','createdAt'])` at `firestore.rules:1620-1626`, so the narrowed `update()` cannot itself cause a replay denial; `UnifiedShoppingList.toFirestore()` emits a fixed 19-key map with all four activity keys unconditionally, so `_appendPayload`'s `containsKey` guard never silently drops one; `_requireSelfOwnedCreate` fires before `docRef.set` and the test asserts the collection stays empty on the deny path; `Collections.unifiedShoppingLists === "unified_shopping_lists"` matches the Dart constant by value; `deleteUserSubcollections`' Tier-2 list does NOT include `unified_shopping_lists`, so the new strict items sweep in Tier-1 `deleteShoppingLists` cannot be raced into deleting parents ahead of their children.

**Still open — three repeats, all Medium, none new.** (1) `updateItemsBatch`'s personal leg `batch.update`s every submitted id, so one stale row fails the whole chunk `NOT_FOUND` and the user sees `errorNetwork` after a full visual rollback — contradicting the interface doc's "Items not present on the list are ignored rather than resurrected", which only the collaborative leg honours. Filtering needs an id read (`read()` returns a personal list with an empty `items` array — items live in a subcollection). (2) The append whitelist is documented, not enforced: `_appendedItems` only checks the items prefix, so a future mutator that appends a row and also moves `name`/`description`/`settings`/`categoryIds`/`autoRemoveCompleted` loses that field silently on the offline path while returning the full mutated object. The fixed `toFirestore()` key set makes the serialized-doc diff a five-line fix. (3) `UnifiedShoppingService.currentUserDisplayName` is still `authRepository.getCurrentUser()?.displayName ?? 'Du'`, feeding `ownerDisplayName` + `lastActivityBy*` through `ShoppingListManagementModule.createCollaborativeList` — a household member can read another member's name as the literal `'Du'`, while the repository-level writer now takes the profile name. Half a fix, third pass.

**New this pass, all Low.** (a) A fully-stale `updateItemsBatch` (no submitted id on the live list) still bills a transactional write, logs `granted: true` and returns success, because `_withItems` bumps `updatedAt` — the missing `identical(mutated, live)`/content short-circuit now has a LIVE reachable no-op path, where the previous pass could only reach it through the dead facade. The module's own test proves the write happens. (b) The legacy `shopping_lists` sweep deletes parents bare while the live path now sweeps `{listId}/items` first — the same asymmetry the fix existed to remove; harmless only as long as the "nothing ever wrote that path" claim in the comment holds, in which case the sweep itself is dead code. (c) The canary's sole-member `ownerId == uid` leg is reachable by a query the cascade never runs (the cascade only visits shared lists via `memberPermissions.{uid}`), so an owned list missing the owner's own key is reported forever and forces `success:false`/`gdprCompliant:false` with no fix path. (d) The comment "the retry re-discovers everything" overstates: `auth.deleteUser` runs unconditionally after the probe, so no client retry is possible — the only recovery is a human running `functions/src/admin/reset-user-data.ts`, and nothing alerts on `gdprCompliant:false`. (e) `_lastMutationError` is never cleared at the start of a mutation and the early-return `false`s still set nothing, so an unconsumed message can be shown as the reason for a later, different failure. (f) `unified_shopping_viewmodel.dart:285-288` still says the menu-generated path "stays analytically silent"; this same diff makes it emit `shopping_list_created` with `source: 'menu_generated'` — a future session reading the comment would re-add the event. (g) 500-line limit: `shopping_repository_routing_module.dart` 574 and `shopping_item_management_module.dart` 525, neither allowlisted; the allowlist's recorded counts for the four files this diff touches are stale (service 592->703, VM 686->722, view 625->657, model 837->843).

**Working-tree hygiene, not code.** A stray 0-byte file literally named `addedByUserId` sits untracked at the repo root (mtime 16:40 today, almost certainly a `>` redirect typo while working the cascade scrub) — it must not be swept into the commit, which is another reason the pathspec-only staging rule exists. `docs/onboarding/workflow-map.stale` is still present although `workflow-map.html`'s `flow-menu-5` description WAS updated for BUT-1696/1697; per CLAUDE.md the marker is deleted and committed with the map.

**Non-findings, confirmed a second time so they stop costing review budget.** The fire-and-forget analytics emits in `unified_shopping_service.addItemsBatch` and `menu_shopping_list_generator` cannot raise an unhandled async error (`ConsentService.checkSafely` and the analytics repository both catch internally), consent still gates every event inside `BaseTracker.logEvent`, and `unawaited_futures`/`discarded_futures` are disabled in `analysis_options.yaml`. `ServiceLocator.tryGet` inside `FirebaseShoppingRepository` is consistent with 9 other repositories and is lazy, so no DI cycle. `AppLocale.current` inside a service module has precedent in the repository modules. No `firestore.rules` change in the diff, so no `firestore-rules-tester` handoff is owed.

### 2026-07-26 (fourth pass, same working tree) — BUT-1697 two-file gate: the rename IS complete, but the same bug class is live in two more places

Commit-gate review scoped to `lib/repositories/firebase/firebase_data_export_repository.dart` and
`lib/repositories/interfaces/shopping_repository.dart`, plus the staged
`lib/core/constants/firestore_collections.dart` as the root of the bug. Read-only pass (another
process owned the analyzer; no `flutter test`/`dart analyze`/`dart format` run) — evidence is greps
and reads, every claim quoted to file:line.

**The assigned fix is correct, verified end to end rather than trusted.**
`exportPersonalShoppingLists` reads `FirestoreCollections.unifiedShoppingLists`
(`firebase_data_export_repository.dart:228`), the same constant as
`FirebaseShoppingRepository.collectionName` (`firebase_shopping_repository.dart:147`), which is what
`shopping_item_operations_module.dart:164-168,246-249` actually writes personal items under, and the
only personal path `firestore.rules:394-400` grants (`unified_shopping_lists` + nested `items`, both
`isOwner(userId)`). The nested `items` subcollection IS read (`:236-239`), so Art. 15/20 reaches live
data. `_guardSelfExport` still runs BEFORE the query (`:224`), so the ownership check survived the
edit, and `requireCurrentUserId()` is the auth-only handle — correct data-source use. The
list-level cap flags truncation correctly via `ExportPaginationHelper.fetchCapped`
(`export_pagination_helper.dart:237-248`, the `limit+1` idiom, not the `>=` trap) with a declared
`'shopping_lists': 500` (`:185`) surfaced as `if (results.truncated) 'truncated': true`
(`content_export_manager.dart:216-219`).

**Grep proof for focus 1.** `unifiedShoppingLists` is used by the repository, the export,
`shopping_social_share_module.dart:46` and TS `Collections.unifiedShoppingLists`;
`userShoppingLists` survives only at its definition (`firestore_collections.dart:86`), at
`friends_utility_operations.dart:146`, and in the new negative-control test. The literal string,
however, survives at two live server sites a constant-grep misses (F2/F3). Positive non-finding: the
cascade's bare bulk-delete of legacy `shopping_lists` parents with no items sweep
(`account-deletion-cascade.ts:312-313`) is NOT a finding — `firestore.rules` grants no
`users/{uid}/shopping_lists` match, so the path cannot hold docs; the comment's reasoning checks out.

**F1 (Medium, assigned file) — a nested cap plus a swallowed child read make a partial shopping
export indistinguishable from a complete one.** `firebase_data_export_repository.dart:235-252`:
`maxItemsPerList` (500) is a bare `.limit()` with no flag, and the `catch` logs at debug and returns
`items: []`. A 600-item list exports 500 silently; a transient items-read failure exports the list as
itemless. The sibling method does it right (`'messages_truncated'`, `:353`). Fix: fetch
`maxItemsPerList+1`, emit `'items_truncated'`, and set `'items_error': true` in the catch. The
catch's comment ("items may be embedded in the list doc itself") now describes a REAL production
duality, not a defensive guess — see F6.

**F2 (Medium, assigned file) — the new doc comment on the legacy constant under-counts its
readers.** `firestore_collections.dart:79-85` claims it is "kept only because
`friends_utility_operations` still queries it (a separately-tracked dead read)". Two more readers
exist via the string literal (`compute-feature-retention.ts:212`, `reset-user-data.ts:30`), and
"separately-tracked" has no ticket anywhere in `tasks/` or `docs/` (grep for
`getRecentShoppingCollaborators`/`friends_utility` returns nothing).

**F3 (High) — third site on the dead name: the `shopped` retention metric has always been zero.**
`functions/src/analytics/compute-feature-retention.ts:206-216` probes
`users/{uid}/shopping_lists` with an `updatedAt` day range, so the flag is permanently false for
every user and every day and the retention dashboard reports no shopping engagement. One-line fix to
`Collections.unifiedShoppingLists`; no composite index needed (single-field range).

**F4 (High, GDPR Art. 17 + 15 — the same bug class, one nesting level over).**
`account-deletion-cascade.ts:975-977` sweeps `users/{uid}/user_shared_menus` and
`users/{uid}/user_shared_shopping_lists` as user SUBcollections. The app writes both as TOP-LEVEL
trees: `user_shared_shopping_lists/{friendId}/received_lists/{id}`
(`shopping_social_share_module.dart:85-89`, reads/updates at `:219,373,399`) and
`user_shared_menus/{friendId}/received_menus/{id}` (`social_menu_operations.dart:105-109`) — also the
only shape the rules grant (`firestore.rules:1663`, `:1676`). The `users/{uid}/...` variant has no
rule block, so default-deny means it can never hold a doc and the sweep deletes nothing. Reachable
and live: `social_sharing_viewmodel.dart:277` into `shopping_social_share_module`. Each row carries
`sharedListId`, `sharedByUserId`, `sharedByDisplayName`, `listTitle`. Consequences: (a) the erased
user's own inbox subtree survives, holding other members' names; (b) rows he created in OTHER users'
inboxes keep his raw uid and display name forever — the `shared_content` tombstone
(`on-user-deleted.ts:236-239`) covers only `shared_content`; (c) neither collection is in the export,
so export is not a superset of erasure for a second collection pair; (d) neither is in
`probeResidualData`'s `subProbes` (`:149-151`), so the canary reads clean. Fix:
`db.collection("user_shared_shopping_lists").doc(uid).collection("received_lists")` (+ the menus
equivalent) in the cascade, a cross-user `sharedByUserId == uid` scrub or tombstone, both paths added
to `subProbes`, and an `exportReceivedShares*` method. No rules change, so no rules-tester handoff.

**F5 (Medium, assigned file — REPEAT, fourth pass) — the new interface contract is false for the
personal leg.** `shopping_repository.dart:22-27` documents "Items not present on the list are ignored
rather than resurrected". True for the collaborative leg
(`shopping_item_operations_module.dart:332-334`, `replacements[existing.id] ?? existing` maps over
live items only). The personal leg (`:350-356`) `batch.update`s every submitted id, and `update()` on
a missing doc throws `not-found` and aborts the whole chunk — a stale local row makes "avmarkera
alla" fail entirely after a full visual rollback. Filter against the live item ids, or say in the doc
that the personal leg throws. Filed identically in passes two and three; it is now written into a
PUBLIC interface, which raises it from a comment to a contract.

**F6 (Critical severity, pre-existing, outside the assigned files — traced from code, not executed)
— convert-collaborative-to-personal loses every item on the next load.**
`shopping_list_management_module.dart:37-54` builds a personal `UnifiedShoppingList` with `items:`
populated; `firebase_shopping_repository.dart:233-238` routes personal creates to `super.create()`,
which writes ONE doc whose `items` array comes from `toFirestore()`
(`unified_shopping_list.dart:600`) and fans nothing out to the `items` subcollection;
`shopping_repository_query_module.dart:43-57` then OVERWRITES `items` with the (empty) subcollection
on every `readAll()`. The live caller that passes items is `list_lifecycle_operations.dart:158-164`
— it copies `collaborativeList.items` into the new personal list and then DELETES the source list —
reachable from `views/unified_shopping/widgets/dialogs/shopping_list_operations.dart:269`, a file
staged in this very diff. `lists.add(savedList)` keeps the items in memory, so the loss only appears
after a reload, with the original already gone. Fix: fan the items out to the subcollection in the
personal create branch, or have `createPersonalList` call `addItemsBatch` after create. The same
duality is why the export is a superset of what the app itself can read (it dumps the parent array
inside `list_info` AND the subcollection).

**F7 (Low) — `PermissionService.currentUser` is the auth handle wearing the profile type.**
`permission_service.dart:125-137` synthesizes a `UserProfile` from `_authRepository.currentUser` with
`displayName ?? 'User'`. `shopping_social_share_module.dart:39,67,94` (and the menu twin) stamp
`sharedByDisplayName`/`sharedByAvatarUrl` from it into other users' inboxes, and `sharedBy*` is not
among `on-profile-updated.ts:141-165`'s propagation pairs, so a recipient can see the literal
`'User'` permanently.

**F8 (Low) — the rename-propagation CF's personal-list leg is a permanent no-op.**
`on-profile-updated.ts:160-165` loops `db.collection(Collections.unifiedShoppingLists)` as a
TOP-LEVEL collection, but personal lists live at `users/{uid}/unified_shopping_lists`; it needs
`collectionGroup`, or should be dropped (a personal list's `ownerDisplayName` is owner-visible only).
It also bills a query per rename. Same wrong-shape family as F3/F4.

**F9 (Low) — the dead read cited as the reason to keep the constant is doubly dead.**
`friends_utility_operations.dart:145-150` queries top-level `shopping_lists` with
`where('collaborators', arrayContains: uid)` + `orderBy('lastModified')`; the live model has
`memberPermissions` and `lastActivityAt`, not `collaborators`/`lastModified`, so
`getRecentShoppingCollaborators()` always returns `[]`. Kill it or port it to
`unified_shared_shopping_lists`, and delete the constant with it.

**Verdict: BLOCKING** on F4 (an Art. 17/15 hole of the class this sprint set out to close, in a
staged file) and F3, with F1/F2/F5 to fix in the assigned files. F6 routed to the parent as
pre-existing.

### 2026-07-27 (fifth pass, same working tree) — BUT-1697/BUT-1724 two-file gate: the pre-write existence read is correctly scoped; the defects are honesty, cost and leg asymmetry

Files: `lib/repositories/firebase/modules/shopping_item_operations_module.dart`,
`lib/core/constants/firestore_collections.dart`. HEAD 543e0f7a3, nothing committed.
Verdict **CLEAN** (no Critical/High).

**Verified clean — the new read.** `updateItemsBatch`'s personal leg reads
`getUserCollection(uid).doc(listId).collection('items').get()` at :362 with
`uid = requireCurrentUserId()`, i.e. the caller's OWN subtree, and `validateOwnership` at
:341-346 precedes it. `firestore.rules:398-400` is
`match /items/{itemId} { allow read, write: if isOwner(userId); }` — `allow read` covers both
`get` and `list`, so the collection query is rule-allowed for exactly the one uid that can
also write it. No filter/orderBy ⇒ no index. Nothing about the read is loggable PII (doc ids
only; `logPermissionCheck` details carry counts + listId). **There is no authorization TOCTOU
here at all** — the path is derived from the caller's own uid on both the read and the write,
so no window can re-point either at another user's data; the only exposure of the read-then-write
window is staleness (a row deleted inside the window still makes `batch.update` raise `not-found`
and fail the chunk, i.e. the mitigation is best-effort by construction). `liveIds` is the FULL
set: no `limit()`, no cursor, and a Firestore collection query returns the complete result
(the SDK pages internally); a rules denial would throw rather than silently truncate.

**F1 (Medium) — the new throw inherits a sibling's message and lies about the cause.**
`ResourceNotFoundException` at :370-374 maps through
`shopping_failure_message.dart:25` to `AppLocale.shoppingListNotFound` = "Lista hittades inte",
shown by `unified_shopping_view.dart:540` while the list is on screen. That is the exact
substitution `shopping_item_management_module.dart:388-392` documents REFUSING for the single
checkbox ("the list is right there on screen, so 'Lista hittades inte' would be a fresh lie").
The exception already carries `resourceType: 'shopping_item'`, so the fix needs no signature
change: add an arm keyed on that in `shoppingFailureMessage`. Aggravating: the caller
(`shopping_bulk_item_module.dart:141-146`) rolls the rows back to `bought: true` though they no
longer exist server-side, and only the COLLABORATIVE stream is live
(`unified_shopping_service.dart:333`; personal lists come from `readAll()` only), so nothing
corrects that local state until a manual reload.

**F2 (Medium, HYPOTHESIS — not reproduced) — a cache-sourced snapshot makes "every row is gone"
unfalsifiable.** Offline, a Firestore *query* resolves from the local cache and returns an
possibly-empty snapshot WITHOUT error (unlike an explicit `Source.cache` doc miss, which throws
`unavailable`). If the items subcollection is not in cache, `liveIds` is empty or a subset and
:366 throws "None of the N item(s) exist any more" for rows that do exist — converting a write
that used to be queued and replayed into an abandoned write plus a rollback plus F1's wrong
message. Cheap fix: read `snapshot.metadata.isFromCache` and only treat an empty survivor set as
fatal when the snapshot came from the server. Note the personal leg has no offline path at all,
unlike the collaborative leg's new `ShoppingOfflineWriteModule`.

**F3 (Medium) — cost: the whole subcollection is read to check M ids.** :362 bills one read per
item on the list; "avmarkera alla" on a 100-row list with 12 ticked pays 100 reads to validate 12.
The idiomatic cheaper shape is already in the repo: `whereIn(FieldPath.documentId, chunk)` with
`kFirestoreWhereInLimit = 30` (`iterable_extensions.dart:6`) — bills only the submitted ids that
exist, never worse than the current shape. Don't confuse the two chunk constants (30 for `whereIn`,
`kFirestoreBatchSafeChunkSize = 450` for the write loop at :377). Mitigating: `readAll()`
(`shopping_repository_query_module.dart:47-49`) already does the same unbounded per-list read, so
this is consistent with the established shape rather than new.

**F4 (Medium) — the "cannot report success for a write that touched nothing" guarantee exists on
ONE leg, and the method's own doc comment claims both.** :315-318 says stale ids are "dropped on
BOTH legs", but only the personal leg refuses to return normally. On the collaborative leg
(:330-339) a submission where every id is gone still passes through `_withItems`, which stamps
`updatedAt`/`lastActivityAt`/`lastActivityBy{UserId,DisplayName}` — so the transaction commits a
no-op write (billed, and it misattributes the last activity to a member who changed nothing) and
the caller reports success. This is the `identical(mutated, live)` principle in a new dress: the
stamp is what defeats the identity check, so the guard has to be "no submitted id matched a live
row", not object identity.

**F5 (Low) — the audit row counts what was SUBMITTED.** :386-392 logs
`Items: ${items.length}` after the personal leg may have written `present.length`. Log the written
count (and the dropped count) or the trail overstates the write.

**F6 (Low) — "`read()` does not hydrate" invites the wrong optimisation.** :359-361 is right that
`list.items` must not be the source of `liveIds`, but the reason is not that it is empty:
`UnifiedShoppingList.toFirestore()`/`fromFirestore` write and parse an `items` ARRAY on the parent
doc (`unified_shopping_list.dart:600,677`), so `read()` returns a POPULATED-BUT-STALE array (only
whole-list writes refresh it; `addItem`/`updateItem` write the subcollection). A future reader who
prints `list.items`, sees rows, and deletes the `.get()` reintroduces the bug. Say "stale", not
"absent".

**`firestore_collections.dart` — every claim in the rewritten comment is TRUE.** Grepped:
`match /` on any shopping path yields only `unified_shopping_lists` (394), `shoppingPresence`
(1210), `unified_shared_shopping_lists` (1602), `shopping_list_templates` (1637),
`user_shared_shopping_lists/{userId}/received_lists` (1663) — no `shopping_lists` match at root or
under `users/{uid}`, so the catch-all `match /{document=**} { allow read, write: if false; }` at
`firestore.rules:2526-2528` is what a client read hits, and a denied QUERY surfaces as
`permission-denied`, not empty — the comment's "broken rather than merely empty" is mechanically
right. `friends_utility_operations.dart:146` is indeed a ROOT
`firestore.collection(FirestoreCollections.userShoppingLists)` query (swallowed at :123-126 →
always `[]`). `compute-feature-retention.ts:212` probes
`users/{uid}/shopping_lists where updatedAt in day` under the Admin SDK (rules-exempt, so it is
empty rather than denied ⇒ `shopped` false for every user every day). The export reads only
`unifiedShoppingLists` (`firebase_data_export_repository.dart:228`).
**F7 (Low)**: "The remaining readers are all broken" is an over-claim — the Admin-SDK legacy sweeps
`account-deletion-cascade.ts:408` and `admin/reset-user-data.ts:30` also read the path, are neither
broken nor tracked in BUT-1724, and are invisible to a grep of the CONSTANT because they hard-code
the string. The comment this one replaced named the cascade; the rewrite dropped it.

**GDPR: no consequence on either file.** The read touches only the caller's own doc ids and adds no
field, no export/erasure surface and no new PII in logs; the constant's comment is documentation
only, and a permanently-empty analytics probe collects nothing.

### 2026-07-27 — BUT-1723/1725/1705 shopping+account review: conversion data-loss gate, the erasure trail, and the profile-name split

Reviewed: `firebase_shopping_repository.dart`, `shopping_repository_query_module.dart`,
`shopping_repository_routing_module.dart`, `shopping_offline_write_module.dart`,
`shopping_list_permission_guards.dart` (new), `shopping_repository.dart` (interface),
`list_lifecycle_operations.dart`, `unified_shopping_service.dart`, `user_service.dart`,
`shopping_sharing_status_dialog.dart`, `account-deletion-cascade.ts`, `index.ts`,
`backfill-shared-list-contributors.ts` (new), + 5 test files.

**What landed and is correct.** (1) The three rule mirrors moved out of the routing module into
`ShoppingListPermissionGuards` verbatim — `requireSelfOwnedCreate` (both conjuncts),
`requireNoPrivilegeEscalation` (the ownerId/memberPermissions/createdAt triple),
`requireEditRights` — and all four write paths still call them; the module is 418 lines, the
guards 158. Pure extraction, no predicate changed. (2) `deleteShoppingLists` now unions FOUR
queries (`memberPermissions.<uid>`, `ownerId`, `contributorUserIds array-contains`,
`lastActivityByUserId ==`) and `probeResidualData` counts the same two new handles, so
deleter ⊇ probe still holds; `lastActivityBy{UserId,DisplayName}` is finally scrubbed
(`account-deletion-cascade.ts:619-622`), closing the open BUT-1665 finding in the principles file.
The `contributorUserIds` removal is `arrayRemove` inside the SAME per-doc transaction as the scrub
— the arrayRemove-in-a-fake hazard does not apply because the coverage is emulator-backed
(`request-account-deletion.integration.test.ts`, two new fixtures: a left list and a
last-activity-only list). No index work needed: both new filters are single-field, and
`firestore.indexes.json` has no `unified_shared_shopping_lists` fieldOverride.
(3) `UserService.profileDisplayName` (no Auth fallback) is now the source for the repository's
`resolveDisplayName` and `UnifiedShoppingService.currentUserDisplayName` — the last two persisted
shopping attribution writers named in the principles file. The dialog treats empty and absent
alike.

**F1 (High) — `confirmPersistedItemCount` is permanently inconclusive for personal lists.**
`shopping_repository_query_module.dart:151-156`: the `catch` around the shared-collection probe
does `return null` instead of falling through to the personal-list probe. `firestore.rules:1606-1609`
dereferences `resource.data.ownerId`, so a `get()` on a listId that does not exist in
`unified_shared_shopping_lists` is denied, not empty — which is EVERY personal list. So
`_copyIsSafeToTrust` sees null, and `convertCollaborativeToPersonal` never deletes the source:
convert silently degrades to copy. `FakeFirebaseFirestore` returns `exists == false` without
consulting rules, so all four new unit tests pass. Fix: fall through (keep the warning); the second
`catch` still returns null for a genuine failure. Needs an emulator/rules-lane test.

**F2 (Medium) — the erasure trail has a hole on `updateCollaborativeList`.** `_withContributor` is
applied in `_mutateFromCache` (:375) and inline in the transaction (:297-305) but not on the
whole-list path (:218-226), whose `narrowUpdatePayload` DOES emit `items` when they differ.
`ShoppingRepository.update()` / `ShoppingListManagementModule.updateList` are public and route a
collaborative list there. Today's live item writers all go through `mutateCollaborativeList`
(`personal_shopping_operations` self-scopes to `isPersonal`), so it is latent, not live. Best fix
also closes a pre-existing lost-update: drop `items` from the whole-list path entirely.

**F3 (Medium) — rules not changed in lockstep.** `firestore.rules:1620-1626` lets any edit/admin
member write `contributorUserIds` freely; a modified client can strip a departed member's uid and
make their `addedByDisplayName` unreachable to the cascade. Wants an append-only conjunct + size
bound; hand to `firestore-rules-tester`.

**F4 (Medium) — the BUT-1723 fan-out activated a cross-user PII copy.** Now that
`create()` really persists items, `convertCollaborativeToPersonal`
(`list_lifecycle_operations.dart:188-191`) writes other members' `addedBy*`/`purchasedBy*`/
`lastModifiedBy*` into `users/{me}/unified_shopping_lists/{id}/items` — a tree no other user's
cascade scans. Also flips `UnifiedShoppingItem.isCollaborative` true inside a personal list.

**F5 (Medium) — export/erasure pair.** Erasure now claims four handles on shared lists; the Art-15
export (`content_export_manager.dart:187-193`) still covers personal lists only and has no
shared-list section at all. Pre-existing, widened.

**F6 (Medium) — the backfill has no test.** `backfill-shared-list-contributors.ts` exports
`reconstructContributors`/`runBackfill` "for unit testing" and its header (:12) tells the reader to
delete a `test:backfill-shared-list-contributors` script that does not exist in
`functions/package.json`; both sibling backfills have one. `check-test-registration.js` guards
test→script, not source→test, so nothing reddens. Logic itself read clean (admin-gated, idempotent,
arrayUnion not set, documentId cursor, 450×23 ≥ default 10000 cap, `hasMore` correct).

**F7 (Medium, cost) — reads.** The personal leg of `confirmPersistedItemCount` reads every item doc
to count one number (use `count()`); `create()`'s new `addItemsBatch` call re-enters
`_requireList` → `read()`, which always spends a doomed shared-collection read first.

**F8 (Low) — unchunked batch.** `addItemsBatch` commits one `WriteBatch` with no chunking, and
`create()` now feeds it `saved.items` unbounded; >500 items throws and, by the new deliberate
propagation, fails the whole create. `kFirestoreBatchSafeChunkSize = 450` exists.

**F9/F10 (Low/Info).** The offline `arrayUnion` contributor union is untested. Remaining
Auth-fallback attribution writers outside this fileset:
`social/modules/recipe_share_request_module.dart:59` and
`realtime/realtime_recipe_service.dart:49` — same class as the BUT-1705 fix.

### 2026-07-27 (post-fix re-review, same working tree) — BUT-1723/1725/1705: the fall-through is FIXED; three of the prior findings are still open and the backfill cannot finish at scale

Same fileset as the entry above, re-read after the automated fixes. Ran the four changed Dart test
files (102 pass), `firebase_shopping_repository_test.dart` + `user_service_test.dart` (57 pass),
`unified_shopping_service_test.dart` + `shopping_item_management_module_test.dart` (75 pass), and
`npx tsc --noEmit` in `functions/` (clean). No new Critical/High introduced by the fixes.

**Closed since the last pass.** F1 (High) is genuinely fixed: `confirmPersistedItemCount`
(`shopping_repository_query_module.dart:154-167`) now logs and FALLS THROUGH to the personal leg
instead of `return null`, with a comment naming the `resource`-is-null rules mechanic, and the
unit test mocks the sealed `CollectionReference`/`DocumentReference` to stage a real
`permission-denied` — the one shape `fake_cloud_firestore` cannot produce. Both `isFromCache`
guards are pinned by their own mocked-metadata tests, which is the only way to reach them (the fake
answers `isFromCache == false` for everything). F6 is fixed:
`functions/src/__tests__/backfill-shared-list-contributors.test.ts` exists and
`functions/package.json:81` carries the `test:backfill-shared-list-contributors` script the header
tells the operator to delete.

**Still open, unchanged, re-verified line by line:** F2 (`updateCollaborativeList:218-226` writes
`items` via `narrowUpdatePayload` without `_withContributor`), F3 (`contributorUserIds` appears
NOWHERE in `firestore.rules`; the non-owner update branch at :1620-1626 forbids only
`ownerId`/`memberPermissions`/`createdAt`, so any edit-level member can blank the erasure trail),
F4 (`list_lifecycle_operations.dart:204-207` still passes `collaborativeList.items` verbatim),
F5 (no shared-list section in the Art-15 export), F7/F8 (whole-subcollection read to count; one
unchunked `WriteBatch` now fed unbounded `saved.items`).

**NEW F11 (Medium) — the backfill has no RESUME cursor, so `hasMore: false` is unreachable past
~10k docs.** The prior pass cleared this as "documentId cursor, 450×23 ≥ default 10000 cap,
`hasMore` correct" — that reads the loop, not the invocation boundary. `lastDocId`
(`backfill-shared-list-contributors.ts:123`) is loop-LOCAL and `BackfillRequest` exposes only
`dryRun`/`maxLists`; every invocation therefore restarts at the top of the collection. Already-done
docs are skipped but still SCANNED and still counted toward `maxLists`, so past
`MAX_BATCHES_PER_INVOCATION × BATCH_SIZE` the callable can never reach the end — and
`hasMore: false` is the documented condition for deleting the file. The sibling
`backfill-canonical-ratings.ts:97-101,121` already has the right shape (`startAfter` in the
request, `nextCursor` in the response); `backfill-recipe-comments-denorm.ts` has the same gap, so
copying the wrong sibling is how this recurs. Secondary: `hasMore` is forced true whenever
`batchesProcessed` hits the cap (:179), including the case where the final batch was also the end
of the collection (`snapshot.size < BATCH_SIZE` breaks AFTER the increment) — safe direction, one
wasted run.

**NEW F12 (Medium) — the conversion gate confirms the COPY server-side and the SOURCE from local
state.** `_copyIsSafeToTrust(copyId, personalList.items.length)`
(`list_lifecycle_operations.dart:157,213`): the expected count comes from
`_getPersonalLists()`/`getListById`, i.e. whatever `readAll()` last loaded on THIS device. Personal
lists have no snapshot stream, so a row added from another device is absent from that count, the
copy matches the short number, and the source is deleted with those rows. Same bug class the
ticket fixed, one level up. Either confirm the source with the same server-only probe or state in
the doc comment that the source count is trusted.

**Notes that are NOT findings.** `narrowUpdatePayload` is safe against the sentinel trap —
`UnifiedShoppingList.toFirestore()` (model :595-624) emits `Timestamp.fromDate`, never
`FieldValue.serverTimestamp()`, and a fixed key set, so the `DeepCollectionEquality` diff is
stable and no key can be silently dropped. `_memberDiff`'s per-key field paths are written through
`docRef.update()`, where a dotted key IS a field path — correct, and the routing-module test proves
a removal now actually lands (`merge: true` could never delete a key). Two accidental improvements
worth knowing: the narrowing also stops `fromFirestore` writing a normalised unknown enum value
back over the server's (the CF fixtures carry `'owner'`/`'editor'`, which the Dart enum does not
have), and the privileged-key refusal on a cached base surfaces through `updateList`'s
`catch → return false`, so no misleading "permission denied" copy reaches the user. Removing the
Auth fallback from `currentUserDisplayName` means a collaborative list created before the profile
loads stamps `ownerDisplayName: ''` permanently — `on-profile-updated.ts` only fires on a profile
CHANGE, so it never self-heals; deliberate under BUT-1705, worth knowing.

### 2026-07-28 (third post-fix pass, same working tree) — BUT-1723/1725/1705: F3 and F4 closed; the rules half is now the untested half

Same fileset as the two entries above. Verified green before writing: `flutter analyze` on the ten
reviewed Dart files (no issues), `flutter test` on the four changed test files plus
`firebase_shopping_repository_test.dart` and `user_service_test.dart` (162 pass), `npx tsc --noEmit`
in `functions/` (clean), `npm run test:backfill-shared-list-contributors` (10/10). No new
Critical/High from the fixes themselves.

**Closed since the last pass.**
- **F3 (rules lockstep).** `firestore.rules:1613-1617` now defines `keepsContributorTrail()` —
  `request.resource.data.get('contributorUserIds', []).hasAll(resource.data.get(...))` plus
  `size() <= 200` — and it is a conjunct of `allow update` (:1642, applied to the OWNER too, which
  is right: the owner can strip a departed member's uid as easily as anyone) and, in bound-only
  form, of `allow create` (:1634). The `.get(field, [])` default makes a pre-backfill doc with no
  array pass `[].hasAll([])`. Model check that makes the narrow-update path safe by construction:
  `UnifiedShoppingList` has NO `contributorUserIds` field, so `toFirestore()` never emits it and
  `narrowUpdatePayload`'s diff can never put it in the payload — the value survives on
  `docRef.update()` by merge semantics.
- **F4 (cross-user PII in the personal copy).** `list_lifecycle_operations.dart:204-281`:
  `_withoutForeignAttribution` / `_stripForeignIdentities` drop `addedBy*`, `purchasedBy*`,
  `lastModifiedBy*` and `assignedTo*` (plus `assignedAt`, since a claim without a claimer is noise)
  unless the uid equals `PermissionService.currentUserId`, keeping name/amount/`bought`/timestamps.
  Checked the rebuild is lossless: the constructor's 21 parameters
  (`unified_shopping_item.dart:292-314`) are exactly the fields the helper passes — no silent reset.
  A null `currentUserId` strips everything, which is the fail-safe direction. `isCollaborative` is a
  derived getter (`addedByUserId != null`) with zero production consumers on the ITEM type, so the
  owner's own retained attribution flipping it true inside a personal list is inert.
- **F9.** The offline `arrayUnion` contributor union is now tested both ways —
  `shopping_repository_routing_module_test.dart:466-560` covers create-seats-`[uid]`, the online
  transaction union by a non-owner, the offline TICK (cached-base payload) and the offline APPEND
  (arrayUnion payload), the last two behind an injected `transactionRunner` that throws
  `unavailable`.
- **Conversion UI.** `ListConversionResult` is consumed correctly at both call sites
  (`shopping_list_operations.dart:238-245, 280-288`): `newListId == null` → error,
  `originalKept` → `shoppingConvertedOriginalKept` (an error toast, not a success).
- **`arrayRemove`-in-a-fake risk retired for this cascade.** The contributor removal is asserted in
  `request-account-deletion.integration.test.ts` against the real emulator (`ussl-departed-<RUN>`
  fixture: the target has no member key, is not the owner, is not the activity stamp — only the
  trail can find it), plus a `ussl-lastactivity-<RUN>` fixture and an untouched-foreign-list scope
  proof. Deleter superset-of-probe re-verified leg by leg: probe counts `contributorUserIds
  array-contains` and `lastActivityByUserId ==`; the deleter queries both and clears both in the
  same per-doc `update()`. No `firestore.indexes.json` entry needed (single-field equality + the
  automatic array index; the file has no `unified_shared_shopping_lists` field overrides).

**NEW F13 (High) — the new rule conjunct is completely untested.** `unified_shared_shopping_lists`
has no `*-rules.test.ts` anywhere in `functions/src/__tests__/` (grep: only the backfill unit test
and the deletion integration test mention the collection), and `keepsContributorTrail()` now gates
EVERY client write to it. The specific unproven mechanic is the offline path: `_mutateFromCache`
queues the handle as `FieldValue.arrayUnion([uid])`, so `hasAll` passes only if
`request.resource.data` reflects field transforms. If it does not, every queued shop-aisle tick is
denied on replay and silently rolled back, and the only trace is `onReplayRejected`'s log line. Four
cases to prove on the emulator: arrayUnion-append allowed; explicit-array-superset allowed;
dropping another uid denied for an edit-member AND for the owner; a 201-entry array denied. Owner
of that work is `firestore-rules-tester`.

**Still open, unchanged, re-verified.** F2 (`shopping_repository_routing_module.dart:220-226` —
`updateCollaborativeList` writes a narrowed payload that DOES include `items` when they differ, with
no `_withContributor`; reachable from `ShoppingRepository.update` and the deprecated
`saveCollaborativeList`, latent only because every live item writer goes through
`mutateCollaborativeList`). F5 (no shared-list section in the Art-15 export while erasure now claims
four handles). F7 (the personal leg of `confirmPersistedItemCount` reads every item doc to produce
one number — `count()` bills 1; and `create()`'s `addItemsBatch` re-enters `_requireList` → `read()`,
which spends a doomed shared-collection read plus a warning log on every personal create). F8
(`addItemsBatch` commits one unchunked `WriteBatch`, now fed `saved.items` unbounded by `create()`;
`kFirestoreBatchSafeChunkSize = 450` exists). F11 (`backfill-shared-list-contributors.ts:123,192-201`
— `lastDocId` is still loop-local, `BackfillRequest` still exposes only `dryRun`/`maxLists`, response
still has no `nextCursor`; `MAX_BATCHES_PER_INVOCATION x BATCH_SIZE = 10350` hard-caps a scan that
always restarts at the top, so the documented `hasMore: false` file-deletion gate is unreachable past
that many docs. `backfill-canonical-ratings.ts:97-101,121` is the sibling with the right shape).
F12, now narrowed to ONE leg: `convertCollaborativeToPersonal`'s source count comes from
`_getCollaborativeLists()`, which IS backed by `collaborativeListsStream()`, so that leg is fine;
`convertPersonalToCollaborative` still takes `personalList.items.length` from `_getPersonalLists()`,
i.e. whatever `readAll()` last loaded on this device, and personal lists have no stream.

**NEW F14 (Low) — a partial `create()` leaves an orphan list doc.** `create()` deliberately
propagates an `addItemsBatch` failure so it cannot report success over a half-written list, but the
parent document is already written by then and nothing removes it.
`ShoppingListManagementModule.createPersonalList:64-66` swallows to `null`, so the conversion reports
`shoppingConvertError` while an empty list appears in the user's list on the next `readAll()`. Safe
direction (no data loss), but say so in the doc comment or delete the parent on the failure path.

**Notes that are NOT findings.** `UnifiedShoppingService.currentUserDisplayName` and
`FirebaseShoppingRepository`'s `resolveDisplayName` both now read `UserService.profileDisplayName`
(no Auth fallback), and `UserService.currentDisplayName` keeps its fallback with a doc comment
scoping it to DISPLAY — the BUT-1705 split is clean and pinned by
`user_service_test.dart:873-937`. `shopping_sharing_status_dialog.dart:272-279` treats absent and
empty alike, which is the right pairing for the "stamp empty, never a placeholder" convention.
`ShoppingListPermissionGuards` is a clean extraction — the routing module is back to 418 lines and
the guards carry both create conjuncts, the three-key escalation bar and the edit-rights bar.
`appendPayload` and `_withContributor` transform DIFFERENT fields (`items` vs
`contributorUserIds`), so Firestore's one-transform-per-field rule is not violated.
`shopping_sharing_status_dialog.dart` is 521 lines against a 505 allowlist entry — allowlisted file,
not filed.

### 2026-07-28 — BUT-1705/BUT-1719/BUT-1723/BUT-1725 shopping-account re-review (post-fix round)

Re-reviewed 18 files in the working tree after the automated fix round. Verified clean, with the
evidence that made each one clean rather than merely plausible:

- **Guard extraction is faithful.** `ShoppingListPermissionGuards` is a byte-for-byte move of
  `_requireNoPrivilegeEscalation` / `_requireSelfOwnedCreate` / `_requireEditRights` out of
  `ShoppingRepositoryRoutingModule` (418 lines now, under the 500 limit; guards 158, offline-write
  302, query 232, lifecycle 282, repo 490). All three call sites now go through `_guards`, including
  the offline `_mutateFromCache` leg.
- **`set(merge:true)` → `update(narrowUpdatePayload(...))` on `updateCollaborativeList` is sound.**
  Prerequisite verified directly: `UnifiedShoppingList.toFirestore()` is sentinel-free (every
  timestamp is `Timestamp.fromDate`, no `FieldValue.serverTimestamp()`), so the `DeepCollectionEquality`
  diff does not report every key as changed on every call. `contributorUserIds` is absent from
  `toFirestore()`/`fromFirestore`, so the narrowing can never drop it.
- **`_stripForeignIdentities` constructor is exhaustive.** Counted the `UnifiedShoppingItem`
  constructor's parameter list (21 params) against the rebuild — all 21 present, so no field
  silently resets to its default. `isCollaborative => addedByUserId != null` has NO production
  consumer (grep: only the class's own doc example), so nulling it on the personal copy is safe;
  the CF cascade still anonymizes to `"deleted"` because on a SHARED doc other members read it.
- **Erasure deleter ⊇ probe holds.** Probe legs are now member-key / `contributorUserIds`
  array-contains / `lastActivityByUserId` == / sole-member-owned; the deleter runs the same four
  queries and clears each handle in the SAME per-doc transaction as the item scrub. The owned leg
  still filters to orphans only, so a scrubbed list other members keep does not report residual
  forever. Indexes: both new queries are single-field; `firestore.indexes.json` has no
  `unified_shared_shopping_lists` entry and no fieldOverride disabling `contributorUserIds`, so the
  automatic index covers them.
- **Ran the gates rather than asserting them.** 166 Dart unit tests green across the six shopping/
  user-service test files (Windows native-PATH `.bat` wrapper); `dart analyze` clean over
  `lib/repositories/firebase`, `lib/services/unified/operations/collaborative_shopping`,
  `user_service.dart`, `unified_shopping_service.dart` and the shopping dialogs; `tsc --noEmit`
  clean on `functions/`; `npm run test:backfill-shared-list-contributors` 10/10.

Findings filed (all Medium or below — no new Critical/High introduced by the fix round):

1. `backfill-shared-list-contributors.ts` has NO request-level resume cursor — `lastDocId` is
   loop-local and seeded to `null`, `BackfillRequest` has no `startAfter`, `BackfillResponse` no
   `nextCursor`. Ceiling `MAX_BATCHES_PER_INVOCATION(23) × BATCH_SIZE(450) = 10,350`, default
   `maxLists` 10,000. Past that the file-header removal gate (`hasMore: false`) is unreachable and
   the tail of the collection never gets the trail. The idempotent skip does not rescue it — skipped
   docs still consume the `maxLists` budget. `backfill-canonical-ratings.ts` has the shape to copy
   (`startAfter?: string` in, `nextCursor: string | null` out). This is the SECOND backfill to ship
   with it, so the principles file now says to open the request/response interfaces first.
2. `updateCollaborativeList` is the one shared-list write path that can emit `items` without
   unioning `contributorUserIds`. `_withContributor` is wired only to `_mutateFromCache`; the
   transaction computes the union inline; create seeds `[uid]`. Reachable through the public
   `ShoppingRepository.update()` interface. Traced the live caller chain to
   `ShoppingListManagementModule.updateList` ← `menu_shopping_list_generator.dart:216`, whose
   generated rows carry no `addedByUserId` — so nothing leaks TODAY, which is why it is Medium and
   not High. Fix: union when the narrowed payload `containsKey('items')`.
3. The BUT-1705 doc claim in `unified_shopping_service.dart` ("a real name from the user's
   Google/Apple account can no longer be stamped onto a document other people read") is repo-wide
   and false: `shopping_social_share_module.dart:66-68,93-94` still writes `sharedByDisplayName` +
   `sharedByAvatarUrl` from `PermissionService.currentUser`, which synthesizes a `UserProfile` from
   the Auth user (`permission_service.dart:130-134`: `displayName ?? 'User'`,
   `avatarUrl: firebaseUser.photoURL`). Lands in the recipient's
   `user_shared_shopping_lists/{uid}/received_lists/{id}` tree; `sharedBy*` is not in
   `on-profile-updated.ts`'s pairs, so it is never corrected. The DI-wired social coordinators
   (`social_module.dart:192/211/253`) are profile-first but fall back to the localized placeholder
   `AppLocale.current.displayUnknownUser` and PERSIST it — same "store a fact nobody asserted"
   defect the shopping writers just stopped doing.
4. `convertPersonalToCollaborative` confirms the COPY server-side but takes `expectedItems` from
   local state of the source (`_getPersonalLists()`), and personal lists have no snapshot stream —
   they come from `readAll()`. A source that gained rows on another device is deleted on the
   strength of a copy complete only against this device's view. The collaborative→personal leg is
   fine (stream-backed source). Fix or say "the source count is trusted" in the doc comment.
5. `FirebaseShoppingRepository.create` leaves an orphan parent document when the new
   `addItemsBatch` fan-out throws — `createPersonalList` swallows the exception and returns null, so
   the conversion correctly keeps the source, but `readAll()` rebuilds the orphan from an empty
   `items` subcollection and shows the user an empty duplicate list.
6. `confirmPersistedItemCount`'s personal leg downloads every item doc to count them.
   `.count().get()` bills ~1 read per 1000 index entries AND has no offline path (it fails rather
   than serving cache), which is exactly the "server-confirmed" semantics the method needs —
   cheaper and stronger than the current `metadata.isFromCache` check. Low: conversion-only path.
7. Handed to `firestore-rules-tester`: the new `keepsContributorTrail()` conjunct gates EVERY client
   update of a live collection with zero rules-test coverage. Grepped all ~28
   `functions/src/__tests__/*rules*.test.ts` for `unified_shared_shopping_lists` — zero hits. The
   load-bearing unproven assumption is that `request.resource.data` reflects an `arrayUnion` field
   transform (the offline replay queues exactly that); if it does not, every queued shop-aisle tick
   is denied on replay and rolled back with only a log line as evidence.

### 2026-07-28 — BUT-1723/1719/1705/1725 fix-round review (staged, HEAD e5fec5883)

Scope: `firebase_shopping_repository.dart`, new `shopping_list_permission_guards.dart`,
`shopping_offline_write_module.dart`, `shopping_repository_query_module.dart`,
`shopping_repository_routing_module.dart`, `interfaces/shopping_repository.dart`,
`user_service.dart`, `social/modules/recipe_share_request_module.dart`.

Commands actually run (counts as observed):
- `flutter test` on the four staged shopping repository/module test files → **75/75 passed**
  (incl. `contributorUserIds seats the creator on create`, `… unions an item-writing member who is
  not the owner`, `… an offline edit still extends the trail`, `… an offline append still extends
  the trail`, `createCollaborativeList authorization refuses a list that does not seat the creator
  as a member`, `privilege-escalation parity … a non-owner may not move createdAt`).
- `flutter test` on `user_service_test.dart` + `request_recipe_share_test.dart` +
  `collaborative_shopping_operations_test.dart` → **101/101 passed**.
- `npx ts-node functions/src/__tests__/backfill-shared-list-contributors.test.ts` → **10/10 passed**.
- `flutter analyze` on the 8 scoped files → **No issues found (47.1s)**.

CONFIRMED FIXED / CLEAN this round:
- All four collaborative write paths call the extracted guards (create → `requireSelfOwnedCreate`;
  whole-list update, transactional mutate and cached-base offline mutate → `requireEditRights` +
  `requireNoPrivilegeEscalation`). Verified against the STAGED `firestore.rules` block for
  `/unified_shared_shopping_lists`, conjunct by conjunct. `requireSelfOwnedCreate` now mirrors BOTH
  create conjuncts, closing the audit-only residual carried since BUT-1696.
- `keepsContributorTrail()` (`hasAll` + `size() <= 200`) is a conjunct of BOTH create and update,
  owner included; `contributorUserIds` is deliberately absent from the update rule's non-owner
  forbidden-key set, so an edit member can union but not drop.
- Deleter ⊇ probe holds for the shared-list legs: probe counts member-key, `contributorUserIds`,
  `lastActivityByUserId` and sole-member `ownerId`; the deleter's four queries cover all of them and
  every probed field is cleared inside the SAME per-doc transaction (sole-owner list deleted
  outright). No composite index needed — no `fieldOverrides` for the collection, so automatic
  single-field indexes cover `array-contains` and `==`.
- Fail-safe shapes verified rather than assumed: `confirmPersistedItemCount` returns null (⇒ KEEP
  BOTH) on `isFromCache` and on failure; the shared-leg `catch` FALLS THROUGH instead of returning,
  which is the only reason the personal leg is reachable in production;
  `narrowUpdatePayload` THROWS on a privileged key against a cached base; `requireEditRights` lets a
  `validateUpdatePermission` throw propagate (fail-closed).
- Data-source rule respected throughout: `permissionService.currentUserId` for auth only,
  `userService.profileDisplayName` (profile-only, NO Auth fallback) for anything persisted as
  attribution.

FINDINGS FILED:
1. HIGH — `functions/src/__tests__/shared-shopping-lists-rules.test.ts` is `??` UNTRACKED while the
   `keepsContributorTrail()` rule change is STAGED; its `package.json` script and
   `firestore-rules.yml` path triggers are unstaged (`MM`). The proof exists (528 lines, SSL11
   asserts the `arrayUnion` shape) but ships nothing, and the CI new-block gate stays green because
   the match block is not new — only the function inside.
2. MEDIUM — `updateCollaborativeList` (routing module :220-226) still does not extend
   `contributorUserIds`; `_withContributor` (:329) is wired to `_mutateFromCache` only. Structural
   cause: the payload is diffed from `entity.toFirestore()`, whose key set never contains the
   handle. Full caller trace showed no live leak today (`personal_shopping_operations` preserves
   attribution, `list_member_operations` is owner-only, `menu_shopping_list_generator` writes
   attribution-free rows), so the invariant rests on caller discipline.
3. MEDIUM — the third `PermissionService.currentUser` writer is still live
   (`permission_service.dart:125-141` synthesizes a `UserProfile` from Auth with
   `displayName ?? 'User'` and `photoURL`; `social_menu_operations.dart:87-88,113-114` stamps
   `sharedByDisplayName`/`sharedByAvatarUrl` from it into `shared_content` and other users'
   `user_shared_menus/{friendId}/received_menus`), while the new comment at
   `unified_shopping_service.dart:293-300` reads as a repo-wide "can no longer be stamped" claim.
4. MEDIUM — the BUT-1723 fan-out routes through `read()`, which probes the shared collection first,
   so every personal create with items bills a guaranteed `permission-denied` round trip plus a
   warning log on the happy path.
5. LOW — the personal `delete()` still leaves the `items` subcollection orphaned, now always
   populated because of the fan-out; covered by the CF cascade + `listDocuments()` probe, so storage
   waste rather than a GDPR hole.
6. LOW — `recipe_share_request_module.dart:67-69` persists `?? AppLocale.current.displayUnknownUser`
   into `SocialRequest.fromUserName` (a cross-user doc + push payload), freezing the SENDER's locale
   — the opposite of the stamp-empty rule this same round established for shopping.
7. LOW — `deleteCollaborativeList` (`firebase_shopping_repository.dart:412-415`) is a bare
   `doc().delete()` with no `validateDeletePermission` and no audit row, next to a guarded
   `delete()`; grepped to zero production callers (integration test only).
8. LOW (outside declared scope) — `backfill-shared-list-contributors.ts:65-77` has no
   `startAfter`/`nextCursor` on its request/response interfaces (loop-local `lastDocId` only), so
   the documented `hasMore: false` removal gate is unreachable past 23×450 = 10,350 docs. Third time
   this shape has shipped.

New mechanic learned: modules receiving `logPermissionCheck` as a `void Function({...})` callback
silently drop the `Future<void>` the mixin returns (Dart return-type covariance to `void`), so every
audit row written from the shopping modules — including the new guards class — is fire-and-forget.

### 2026-07-30 — BUT-1726/1732/1733/1741 shopping + account review: an intent parameter with no callers, and an under-enumerated export field group

Scope: `shopping_repository_routing_module.dart`, `shopping_list_permission_guards.dart`,
`shopping_offline_write_module.dart`, `shopping_item_operations_module.dart`,
`permission_validation_mixin.dart`, `shared_shopping_list_export.dart`,
`content_export_manager.dart`, `data_export_service.dart`,
`firebase_data_export_repository.dart`, the two deviation files, and the five touched test files.
Verdict: FAIL.

1. CRITICAL — BUT-1726 added an OPT-IN parameter (`updateCollaborativeList({UnifiedShoppingList?
   accessControlBase})`) and made the default branch STRIP `ownerId`/`memberPermissions`/`createdAt`
   from the payload. `grep -rn accessControlBase --include=*.dart .` returns three hits, all in
   `shopping_repository_routing_module_test.dart`. The production chain that manages membership —
   `shopping_member_management_dialog.dart` / `social_shopping_coordinator.joinSharedShoppingList`
   → `ListMemberOperations.addMember|removeMember|updateMemberPermission|leaveList` →
   `UnifiedShoppingService.updateList` → `ShoppingListManagementModule.updateList` (line 211,
   `repository.update(list)`) → `FirebaseShoppingRepository.update` (line 253) — passes nothing.
   Proved with a scratch test driving the real module against `FakeFirebaseFirestore`: after an
   addMember-shaped call the persisted map is still `{alice: admin, bob: edit}` (no `cecilia`), and
   after a removeMember-shaped call `bob` is still there. So joining a shared list, adding,
   demoting, removing a member and leaving a list all silently no-op; the owner believes access was
   revoked and the removed member keeps rules-granted read+write. The caller is told it worked:
   `updateCollaborativeList` logs `granted:true` "Updated list …" and returns the entity, and
   `updateList` writes the caller's copy into `lists[i]` and returns `true`.
2. HIGH — `SharedShoppingListExport.nameKeysByOwnerIdKey` enumerates four name/id pairs
   (`ownerDisplayName`, `lastActivityByDisplayName`, `addedByDisplayName`,
   `assignedToDisplayName`) but `UnifiedShoppingItem.toFirestore()` (lines 749-777) persists SIX:
   `purchasedByDisplayName`/`purchasedByUserId` and
   `lastModifiedByDisplayName`/`lastModifiedByUserId` are missing. Both are stamped on every tick
   of a shared list (`list_item_operations.toggleItemBought` → `UnifiedShoppingItem.markAsBought`,
   `userDisplayName: _getCurrentUserDisplayName().orEmpty()`), so they are the most common
   attribution fields on the collection. The bundle therefore ships other household members' names
   while its own `data_minimisation` string and the new `ACCEPTED_DEVIATIONS.md` entry both state
   the opposite — a false self-description in an Art. 15 bundle, and outside the deviation's
   protection because the deviation decides names are dropped. The new test fixture
   (`content_export_manager_test.dart` `sharedDoc`) contains neither field, so the gap is unpinned.
3. MEDIUM — the strip branch's audit is self-contradictory: `restrictAccessControlToDeclaredBase`
   writes a `granted:false` "dropped memberPermissions" row and then `updateCollaborativeList`
   writes a `granted:true` "Updated list" row for the SAME operation. Same forged-grant family as
   BUT-1696: report the partial refusal to the caller (or refuse), don't audit it both ways.
4. MEDIUM — the strip runs AFTER `requireNoPrivilegeEscalation`, so it only ever helps the OWNER.
   A non-owner edit member whose cached `memberPermissions` is stale still throws
   `PermissionDeniedException` on a plain rename — the exact scenario the new doc comment describes
   as the bug being fixed. Order the strip first, or run the escalation check on the narrowed
   payload.
5. LOW — `shared_shopping_lists` has no `exportLimits` entry (falls back to `defaultBatchSize` 500),
   against the BUT-1662/BUT-1698 convention of pinning the cap explicitly; and
   `contributed.truncated` is discarded while `owned`/`member` are ORed into the section flag.

Verified clean: BUT-1741's `void` → `Future<void>` callback retyping across all four shopping
modules with every call site awaited (analyze clean on `lib/repositories/**`,
`lib/services/account`), the `unawaited(...)` in the mixin, BUT-1733's `_withContributorTrail`
gating the erasure trail on `payload.containsKey('items')` (`toFirestore()` always emits `items`,
so create still seeds `[uid]`; the trail is now extended on the whole-list path, closing the
BUT-1725 (1) gap), the three export probes matching the cascade's own query shapes on
`unified_shared_shopping_lists`, and the contributor probe's refusal degrading to a note rather
than an error. `firestore.rules` unchanged, so no new rules proof was owed.

New mechanic learned: a security fix delivered as an OPT-IN named parameter defaults every existing
caller into the restricted branch. `git grep` the parameter name across `lib/` before approving —
zero production hits means the feature the parameter guards is now dead, not protected.

### 2026-07-30 — BUT-1741/1726/1733/1732 re-review after automated fixes: all four land, one ordering residual

Re-review of the shopping + account (trust & safety, GDPR) working tree after the fix round.
Ran `flutter analyze` on all 16 changed lib files (clean) and four test files
(`shopping_repository_routing_module_test`, `shopping_offline_write_module_test`,
`shopping_item_operations_module_test`, `content_export_manager_test` → 124 passed;
`collaborative_shopping_operations_test` → 42 passed; `data_export_service_test` +
`unified_shopping_service_test` + `shopping_item_management_module_test` → 108 passed).

**BUT-1741 (async audit callback).** All four shopping seams now declare
`Future<void> Function({...})` and await every call; `PermissionValidationMixin` wraps its
fire-and-forget persist in `unawaited(...)`. The four new tests are per WRITE PATH (create,
whole-list update, transactional mutate, guard denial), which is right — the `void` covariance
opt-out was per call site, so one sampled path would not have proved the family. The cost the fix
takes on is that the audit sink is now on the operation's failure path: a throwing sink aborts a
write that already landed. Verified safe here because the mixin's implementation cannot throw
(console log, then the persist inside `unawaited(...).catchError` inside a `try`) — that check is
the price of this pattern, not an optional extra. Awaiting inside the `runTransaction` handler is
also fine: the guards only await the sink on the DENIAL arm, which throws and aborts anyway, and
the sink issues no Firestore read.

**BUT-1726 (declared access-control base).** The dead opt-in is gone. Chain verified by grep end to
end: `shopping_member_management_dialog` → `ListMemberOperations._updateMembership` →
`UnifiedShoppingService.updateSharedListMembership` → `ShoppingListManagementModule.updateListMembership`
→ `ShoppingRepository.updateCollaborativeListMembership` (now on the INTERFACE) →
`ShoppingRepositoryRoutingModule`. The generic `updateList` seam was REPLACED in
`ListMemberOperations`, so the compiler now enforces the split rather than discipline; the callers
honour the returned bool; the dialog reads `consumeMutationError()`; and
`StaleAccessControlBaseException` (a `PermissionDeniedException` subtype) is matched BEFORE the
parent arm in `shoppingFailureMessage`'s switch, with `shoppingListChangedElsewhere` present in
both arb files and both generated localizations. The routing-module tests now drive the entry
point rather than hand-passing the argument, which is the check that would have caught the dead
opt-in.

Residual, filed as Medium: `requireNoPrivilegeEscalation` still runs BEFORE
`restrictAccessControlToDeclaredBase` (routing module lines 240 vs 255-264). For the OWNER the
escalation guard returns early, so the strip does its job. For a NON-OWNER edit-level member whose
in-memory member map has drifted, a plain rename still throws `PermissionDeniedException` — a
false denial of a write the rule would have accepted (`{name, updatedAt}` affects none of
`ownerId`/`memberPermissions`/`createdAt`). Window is narrow because shared lists are
snapshot-stream-backed. Correct fix: evaluate escalation against the payload that will actually be
written, not the raw entity.

Adjacent product gap this round EXPOSED rather than caused (Medium, ticket not code):
`ShoppingPermissionModule.canManageShoppingList` grants a non-owner `admin` member management, and
`ListMemberOperations.leaveList` is offered to any member — but the `unified_shared_shopping_lists`
update rule lets NO non-owner touch `memberPermissions` at all, and the client guard now mirrors
that. So member management for a non-owner admin, and leave-a-list for everyone, are dead UI. They
were dead before too; the difference is that `ListMemberOperations` used to ignore the write's
verdict and return `true`, so the user was told it worked. Failing loudly is the improvement; the
UI still needs to stop offering it (or the rule needs a self-removal branch, the
`removeAll()`-both-directions shape already used for `user_shared_menus`).

**BUT-1733 (erasure trail on the fourth write path).** `_withContributorTrail` now decides the
obligation from the payload — `if (!payload.containsKey('items')) return payload;` — so create,
whole-list update, transactional mutate and the offline cached-base replay all extend
`contributorUserIds` by construction, and a rename correctly stamps nothing. Verified
`UnifiedShoppingList.toFirestore()` emits a FIXED key set always containing `items`, which is what
makes the `containsKey` invariant sound; verified the helper offers both spellings (sentinel
`arrayUnion` for ordinary/offline writes, explicit union inside the transaction, where a merge-set
will not honour a sentinel). Two tests pin the discriminator from both sides (items-carrying update
extends the trail; rename alone does not). `firestore.rules` is unchanged in this working tree, and
`functions/src/__tests__/shared-shopping-lists-rules.test.ts` is now TRACKED and committed — the
2026-07-28 "untracked proof file" gap is closed.

**BUT-1732 (Art. 15 shared-list export).** `SharedShoppingListExport` runs the same three probes as
the cascade (`ownerId ==`, `memberPermissions.<uid> isNull:false`, `contributorUserIds
array-contains`), merges by doc id with a role set, and ORs the truncation flag across all three —
correct per BUT-1662. `isNull: false` rather than `isNotEqualTo: null` is the right spelling and
the doc comment explains why (a literal `null` adds no condition and degrades to an unfiltered
collection read). The contributor probe's refusal degrades to a plain-language `note`, not an
error, which is right: the read rule cannot see a list the user has LEFT. `shared_shopping_lists`
is declared in `exportLimits` (500) so `fetchCapped`'s N+1 probe keys off a contract.
The redaction map now covers all SIX persisted `*DisplayName` keys, and — the durable part — a test
DERIVES the key set from the two models' `toFirestore()` and asserts the map covers every
`endsWith('DisplayName')` key plus that each paired `*UserId` is itself persisted. Verified both
serializers emit nulls rather than omitting keys, which is what makes that derivation meaningful
rather than vacuously green. Both deviation files carry the entry, naming the UID-retention balance
(BUT-1450 precedent) and the left-lists gap.

Two smaller notes, filed Low/Info: the section's outer `catch` returns `{'error': e.toString()}`,
putting a raw Firestore error string inside a GDPR bundle (consistent with every other section of
`ContentExportManager`, so a sweep not a one-off); and
`updateCollaborativeListMembership` does not assert `base.id == updated.id` — harmless today
because the drift check then refuses, and the write is still gated on `stored` by
`requireEditRights`.

### 2026-07-30 — BUT-1732 fix round: GDPR export error tokens, branch logging, item-id fallback

Re-review of the fixes applied on top of the BUT-1732 shared-list export review. Files:
`lib/services/account/export/shared_shopping_list_export.dart` (all code changes),
`lib/repositories/firebase/firebase_data_export_repository.dart` (comment only — diff confirms no
code change; the three probes are byte-identical to the reviewed version).

**Verified good.** (a) The outer catch's `{'error': <stable token>, 'error_code':
'shared-shopping-lists-export-failed'}` DOES reach `export_metadata.warnings`:
`data_export_service.dart:255` tests `value is Map && value['error_code'] != null` and
`shared_shopping_lists` is a TOP-LEVEL key in the `futures` map (line 166), so it is scanned by the
top-level loop; the warning `message` falls back through `error` ?? `note`. Key name and shape
match, and it follows `family_export_manager.dart`'s convention. (b) No map-literal collision:
`'note'` (null-aware element `?contributorNote`), `contributor_probe_failed` and `truncated` are
three distinct keys, and conditional entries in a Dart map literal do not shadow. `directives_ordering`
is off in `analysis_options.yaml`, so the interleaved import is not a lint. (c) `FirebaseException`
is the right type — `cloud_firestore` throws firebase_core's `FirebaseException` with
`code == 'permission-denied'` on a rules refusal, and `firebase_core: ^4.7.0` is a direct dependency,
so importing the symbol from `firebase_core` (rather than pulling all of `cloud_firestore` into a
service file) resolves to the same class; the repo has no architecture guard on it (only ViewModels
are barred from `cloud_firestore`). (d) `AppLogger.error`'s signature is
`(String, [Object?, String?, StackTrace?])` — the two-arg call is correct. (e) Item ids are
`Uuid().v4()` (`unified_shopping_item.dart:314`), so `row_$index` cannot collide with a real id.

**New durable facts, folded into the principles file.** The `error_code` roll-up is TOP-LEVEL-only
and keys off that exact string — a bespoke completeness flag next to a `note` never reaches
`export_metadata`. And `AppLogger.error` is not device-local: it forwards the raw error object to
Crashlytics `recordError` and to the analytics callback; `_sanitizeForCrashlytics` masks uids in the
MESSAGE only. Consent-gated in `main.dart`, so acceptable here, but the premise "logging stays on
the device" is false in this repo.

**Findings filed.** Medium: `contributor_probe_failed: true` carries no `error_code`, so a
transient failure of the contributor probe leaves `export_metadata` claiming a complete bundle —
the same defect one branch over from the one fix (1) closed; remedy is one added key, whose warning
message then resolves via the existing `note`. Medium: the new non-`permission-denied` branch has no
test, and the existing `'a refused contributor probe degrades to a note'` test asserts
`contains('left')` — a substring present in BOTH branch messages, so deleting the
`e is FirebaseException && e.code == 'permission-denied'` predicate leaves the suite green
(repo lesson: a test pinning a fix is a hypothesis until the fix is reverted and it reddens).
Low: the `.limit(1)` cost note on `exportSharedShoppingListsAsContributor` is accurate on cost and
on the read rule, but its claim that `.limit(1)` "would prove the refusal just as well" is wrong —
rules are evaluated over the documents the query actually returns, so with `limit(1)` a user whose
first index-ordered contributor row is still readable gets a SUCCESS where the uncapped query is
refused, silently converting the documented gap into a false completeness claim. Low: the id
fallback covers a missing/null `id` but not an empty-string one (`'' ?? x` is `''`), so several
legacy rows would export as the same blank `item_id`.

Nothing in the round weakens scoping: the three probes, the redaction map and the merge are
unchanged; fix (3) only drops the internal ticket reference from the user-facing
`data_minimisation` string, which still describes the shipped behaviour accurately (names dropped,
uids retained — the latter now a recorded founder call, 2026-07-30).

### 2026-07-30 — BUT-1706/1721/1746 review: offline whitelist enforced, export completeness metadata, null-filter guard

**Scope reviewed** (11 files, sprint area "shopping/account — GDPR export + rules coverage"):
`tools/check_null_filter.sh` (new), `lefthook.yml`, `lib/services/account/data_export_service.dart`,
`lib/services/account/export/{social,activity}_export_manager.dart`,
`lib/repositories/firebase/modules/{shopping_repository_routing_module,shopping_offline_write_module}.dart`,
plus four test files (`shopping_repository_{query,routing}_module_test.dart`,
`data_export_service_test.dart`, `functions/src/__tests__/shared-shopping-lists-rules.test.ts`).
`firestore.rules` itself is UNCHANGED this round — the rules-test diff is pure added coverage, so the
"a new gating conjunct with no proof file" hazard does not apply.

**Verified by running, not reading.** `flutter test` on the three Dart suites → 111 passed.
`dart analyze --fatal-infos` on all six lib files → clean. `bash tools/check_null_filter.sh` with no
args → exit 0 repo-wide; single-file and multi-file modes exit 0 on the three files whose
WHY-comments name the banned spelling; a synthetic `.where("a", isEqualTo: null)` exits 1 (positive
control). Three mutation tests, each restored and stat-verified afterwards:
(1) `value['error'] != null ||` removed → the new "codeless section warns" test reddens;
(2) `_declaresTruncation`'s List branch stubbed to `return false` → the new nested-list truncation
test reddens; (3) `_offline.requireOfflineWritableMutation(live, mutated);` commented out → the new
"offline rename is REFUSED" test reddens (see the anomaly below);
(4) `isNull: false` → `isNotEqualTo: null` in `shopping_repository_query_module.dart` → 3 of the 4
new membership-filter tests redden, matching the diff's own honest note that `readAll`'s negative
test cannot discriminate (its `catch`-all returns `[]`).

**Anomaly worth remembering (now a principle).** Mutation (3) run as
`flutter test <file> --plain-name "REFUSED"` reported `+1: All tests passed!` WITH the guard
commented out. Re-running the same mutated tree over the whole file gave the correct red with
`Expected: throws <Instance of 'ArgumentError'> ... Actual: <Instance of 'Future<...>>`. So a
`--plain-name`-scoped run is not a trustworthy mutation harness for an async-throw assertion here;
always mutation-test with the full file.

**Findings filed.** High: `social_export_manager._failed(e, code)` (8 sites) and
`activity_export_manager` (2 sites) add `error_code` while keeping `'error': e.toString()`, and the
same commit's aggregator change makes `export_metadata.warnings[].message` = `value['error']` — so
raw Firestore/permission text (foreign uids in composite doc ids, `memberPermissions.<uid>` index
URLs, project paths) is promoted from a buried section field to the bundle ROOT of an Art. 15
artifact. The repo already ships the right shape 20 lines away in
`shared_shopping_list_export.dart` and `family_export_manager.dart` (stable sentence + stable
`error_code`, with a comment saying exactly why). `preferences_export_manager.dart` (2 sites, out of
scope) is now amplified too. Medium: `tools/check_null_filter.sh` is UNTRACKED while its `lefthook.yml`
gate is modified — committing the gate without the script fails every commit on a fresh clone; stage
both in one call. Low: the guard's comment filter is anchored `^[^:]*:[0-9]+:`, which cannot span a
Windows drive colon — verified that `bash tools/check_null_filter.sh C:/Butlery/butlery/x.dart`
flags a pure `// isEqualTo: null` comment line; lefthook passes repo-relative paths so it is dormant,
fix is to drop the `^[^:]*` anchor. Low: `_declaresTruncation` walks whole exported Firestore
documents to depth 4 keying on `key.endsWith('_truncated')`, so a future user-data field with that
suffix would mislabel a section as clipped (no such field today; the only real nested flag is
`messages.conversations[i].messages_truncated`, at depth 2). Low: `createCollaborativeList`'s
`listToSave` rebuild is still non-exhaustive against the model — `collaborativeOrigin`,
`generatedForWeek` and `schemaVersion` are dropped; pre-existing, and the only writer of
`collaborativeOrigin` (`shopping_list_management_module.createCollaborativeListFromInvitation`) is a
path already dead against the create rule, and the menu generator only ever writes PERSONAL lists,
so no live loss.

**Cleared, so don't re-file.** `contributor_probe_failed` DOES pair an `error_code` now
(`shared_shopping_list_export.dart:176-179`) — the Medium filed on 2026-07-28 is closed.
`validateRequiredFields` is `containsKey`-only, so adding `items` to the mirror cannot reject a
legitimately empty shared list. The rules-test additions match `firestore.rules:1622-1652`
conjunct-for-conjunct (read = owner OR `memberPermissions` key; create = the triple + the 200 bound;
delete = owner only), each deny differs from the SSL1 allow baseline in exactly one way, and
`validListBody` seats OWNER/EDITOR/VIEWER while `contributorUserIds` alone carries DEPARTED, which is
what makes SSL29's revoked-member deny non-vacuous. Not run: the emulator suite itself (no emulator
in this session) — handed to `firestore-rules-tester`.

### 2026-07-30 — BUT-1746 null-filter guard, BUT-1721/1732 export-warning chokepoint, BUT-1706 offline-mutation refusal (re-review, working tree)

Re-review of the automated-fix pass on: `tools/check_null_filter.sh`, `lefthook.yml`,
`lib/services/account/data_export_service.dart`,
`lib/services/account/export/{social,activity}_export_manager.dart`,
`lib/repositories/firebase/modules/{shopping_repository_routing_module,shopping_offline_write_module}.dart`,
plus four test files and `functions/src/__tests__/shared-shopping-lists-rules.test.ts`. Also read
`shopping_list_permission_guards.dart` (staged, needed to judge the routing diff),
`permission_validation_mixin.validateRequiredFields`, `unified_shopping_list.toFirestore()` and the
five live mutators. **Verdict: pass.**

**BUT-1746 — the new grep guard.** `tools/check_null_filter.sh` bans literal
`isNotEqualTo: null` / `isEqualTo: null` in `*.dart`. Verified the premise rather than trusting the
header comment: the four previously-broken sites now all spell `isNull: false`
(`shopping_repository_query_module.dart:72,229`, `firebase_data_export_repository.dart:661`,
`firebase_group_weekly_menu_plan_repository.dart:174`) — that fix landed in c17c4068e; today's diff is
the guard plus tests. Ran the script three ways: whole repo → exit 0; a scratch fixture with three
comment lines naming the banned spelling plus one construction line → flagged only line 4, exit 1;
each of the three real files carrying a WHY-comment, passed individually as the lefthook shape does →
exit 0 each. So the load-bearing `-H` (single-file grep otherwise omits the path prefix the comment
filter anchors past) genuinely works. Two residual notes: the comment filter's `^[^:]*:[0-9]+:`
anchor would break on a Windows drive-letter path, which is safe only because lefthook's
`{staged_files}` are repo-relative; and the regex is line-based, so an `isNotEqualTo:` / `null` split
across two lines is missed. Wiring: lefthook `null-filter-guard`, `glob: "*.dart"`, priority 8. NOT
in any `.github/workflows/` job, so the script's own documented no-arg "CI / manual shape" has no
caller — same precedent as `check_swedish_boundary.sh` (also lefthook-only), which is why this is
filed Low rather than High. Priority 8 sits textually above the priority-7 job; cosmetic only.

**Rules suite ran for real.** The emulator happened to be up on 127.0.0.1:8080, so
`npx ts-node src/__tests__/shared-shopping-lists-rules.test.ts` → **39/39 passed**, including the 14
new assertions (SSL26-SSL31 read gate, SSL32-SSL34 create conjuncts, SSL35-SSL36 owner-only delete,
SSL37-SSL39 the query path). SSL37 settles a claim that was previously unproven: a
`where('memberPermissions.<uid>', '!=', null)` filter IS accepted by the rules engine for a rule
gated on `uid in resource.data.memberPermissions`, and SSL38 shows the unfiltered query on the same
collection is refused outright — i.e. the BUT-1746 symptom was "the shopping screen will not load",
never an over-share. SSL37/SSL39 both carry an emptiness premise so neither can pass vacuously. CI
wiring confirmed present: `functions/package.json` `test:rules:shared-shopping-lists` +
`test:rules:all`, and both `paths:` blocks of `.github/workflows/firestore-rules.yml` (lines 47 and
99) — the exact gap this archive recorded as untracked on 2026-07-28 is closed.
`npx tsc --noEmit` on `functions/` clean.

**BUT-1721/1732 — the export aggregator.** `data_export_service.dart` replaces the section-root
`value['truncated']` check plus the one-level `messages_truncated` special case with one
depth-bounded (`depth > 4`) walk over Maps AND Lists, and widens the warning lift from `error_code`
to `error || error_code` with a derived code `<section>-export-failed`. The important half is that
`message` is now DERIVED (`The "<section>" section could not be exported (error_code: ...).`) instead
of copying `value['error']`: that closes the amplification this archive flagged on 2026-07-28, where
widening the lift promoted 10+ sites' raw `e.toString()` to the bundle ROOT. Checked the walk cannot
false-positive: every `truncated` / `*_truncated` key in `lib/` is export-manager-generated (grep,
26 hits, all in `lib/services/account/export/` + `firebase_data_export_repository.dart:356`), none
comes from user data. `social_export_manager.dart:170` already propagated `messages_truncated` into
the conversations LIST, which is exactly the shape the old walk could not see. Also note the old code
would have THROWN on a section whose value is a List (`value['truncated']` on a List); the new
`is Map` / `is List` dispatch removes that.
Mutation-tested rather than trusting the comment: replaced the List branch with
`if (node is List) return false;` → exactly 1 red (the nested-flag test), restored, diffstat verified
back to 70+/15-. `flutter test data_export_service_test.dart` → 36 pass;
`activity_export_manager_test.dart` + `social_export_manager_test.dart` → 36 pass;
`flutter analyze lib/services/account lib/repositories/firebase/modules` → no issues.
Two things I liked in the test diff: the two legacy warning tests stopped asserting
`warnings.hasLength(1)` and now filter by `section` (a partially-wired fixture legitimately fails a
dozen sections once the lift widens), and the fully-wired happy path still asserts NO `warnings` key,
which is the over-warning guard. The `_LeakyPreferencesExportRepository` fixture is a real leak path,
not a contrived one — `preferences_export_manager` still returns `e.toString()`.
Residual carried forward (Medium, pre-existing, NOT introduced here): 21 sites across
`content_export_manager.dart` (12) and `preferences_export_manager.dart` (9) still put raw exception
text in the section BODY of the downloaded bundle. The chokepoint keeps it off the root; the body is
still an Art. 15 artifact the data subject may forward.
Fixture lesson worth its own principle: `MockUser` stubs `uid`/`email`/`displayName` only, mocktail
throws on any other non-nullable getter, and `_exportUserProfile` reads `emailVerified` and
`metadata.creationTime` — so the `profile` section of EVERY test in that file had been failing
silently, and only widening the lift surfaced it. The fix stubs the fixture (`_FakeUserMetadata`)
rather than relaxing the contract, which is the right call.

**BUT-1706 — `requireOfflineWritableMutation`.** New guard in `shopping_offline_write_module.dart`,
called from `_mutateFromCache` after `requireEditRights`/`requireNoPrivilegeEscalation`. Diffs
`mutated.toFirestore()` against `live.toFirestore()` and THROWS on any differing key outside
`items` + the activity whitelist, with `privilegedKeys` deliberately excluded from the refusal
(dropping those is the design). Checked the three things the principle demands. (a) The refusal, not
a fall-back-to-full-write — confirmed, it throws. (b) Offline leg only — confirmed, the transactional
path merge-sets the whole document. (c) Unreachable by today's mutators — verified by caller trace,
not by grep: `ShoppingItemOperationsModule._withItems` and the model's
`addItem`/`removeItem`/`updateItem`/`toggleItemBought`/`clearBoughtItems` all touch only
`items` + `updatedAt`/`lastActivityAt`/`lastActivityBy{UserId,DisplayName}` + `syncStatus` (which
`toFirestore()` never emits), and `list_item_operations.dart` passes those model methods straight
through. `UnifiedShoppingList.toFirestore()` emits a FIXED, count-free key set (no derived
`itemCount`), so the diff cannot fire spuriously — this was the Critical I went looking for and it
is not there. Where the throw LANDS matters and is fine: a bare `ArgumentError` is absorbed by
`UnifiedShoppingService.mutateSharedList`'s generic `catch` -> `_failMutation(...)` + `false`, not a
crash. `_writableActivityKeys` filtering `privilegedKeys` out of the whitelist literal is a no-op
today by construction and is the right kind of no-op (the literal can no longer express an ACL
field).
Mutation-tested per the standing warning about `--plain-name` scoped runs: commented out the guard
call, ran the WHOLE file → exactly 1 red (the new refusal test), restored, diffstat verified back to
13+/15-. Full file green: 76 tests across the routing + query module suites.

**BUT-1706 create mirror.** `validateRequiredFields` moved from the routing module into
`ShoppingListPermissionGuards.requireSelfOwnedCreate` and widened to
`['name','ownerId','memberPermissions','items','createdAt']`. Read the mixin: it checks
`containsKey` only, so `items: []` and a null `name` both pass — no risk of refusing a legitimate
empty new list, and (as the principles already say) the new keys can never fire because
`toFirestore()` emits them unconditionally. Parity with the rule holds for the same reason
(`hasRequiredFields` is also key-presence, and Firestore stores explicit nulls). Documentation value
only; harmless. The guard correctly runs the field check BEFORE any audit row, since a missing-field
refusal is not a permission decision.

**Also verified in passing:** `_beginMutation()` really does null `_lastMutationError` at the start
of every mutation entry point, which closes the "nothing clears the field at the START" residual this
archive recorded on 2026-07-26 — corrected in the principles file. File sizes all under the 500-line
limit (routing module 498, tight).

**Not verified:** the four out-of-scope staged files (`firestore_collections.dart`,
`friends_utility_operations.dart`, the two realtime services, `recipe_collaborative_manager.dart`)
and the whole `functions/src` half of the working tree; whether `content_export_manager` /
`preferences_export_manager` will get the sentence+token treatment; SSL39's actor `list-nobody-uid`
staying a member of nothing on a long-lived shared emulator (true today, only convention protects
it).

### 2026-07-30 — Sprint 2026-07-30b rescue pass: the five staged repository/export files (first review, no marker covered them)

Scope: `firebase_data_export_repository.dart` (truncation probe), `shopping_list_permission_guards.dart`
(`validateRequiredFields` folded into `requireSelfOwnedCreate`), `shopping_offline_write_module.dart`
(`requireOfflineWritableMutation` + `_writableActivityKeys`), `shopping_repository_routing_module.dart`
(guard wiring + the new offline refusal call), `shopping_repository.dart` (doc comment only).
**Verdict: PASS on all five.** Pre-ticketed and deliberately not re-filed: BUT-1767, BUT-1766,
BUT-1768, BUT-1769, BUT-1760.

**Verified clean, with the evidence, so a later pass need not redo it.**

*Truncation probe (Q4 — can the probe doc leak?).* No. `limit(cap + 1)`, `truncated =
docs.length > cap`, `kept = truncated ? docs.sublist(0, cap) : docs`, and `kept` is the ONLY thing
read into `messages`. `messagesSnapshot.docs` appears exactly twice in the method (the length test
and the sublist) — read the whole method, not the hunk, to establish that. Cost: +1 document read
per conversation, <=100 per bundle. `sublist` cannot throw because `truncated` guards it, and
`cap == 0` degrades safely to `limit(1)` / `sublist(0,0)`.

*Create mirror (Q3).* All five conjuncts of the create rule (`firestore.rules`, match
`/unified_shared_shopping_lists`) are now mirrored in one place: `isAuthenticated()` becomes
`requireCurrentUserId()`; `ownerId == uid`; `uid in memberPermissions` (CEL `in` on a map is a KEY
test, and `containsKey` matches); `hasRequiredFields([...])` becomes `validateRequiredFields` with a
superset (`name` extra); `contributorUserIds.size() <= 200` holds because the client seats exactly
`[uid]`. The field check is still structurally unfirable (`UnifiedShoppingList.toFirestore()` emits a
fixed 20-key set including all five), so it documents the rule rather than gating anything —
harmless, already in the principles. Also confirmed the doc-comment claim is checkable: the payload
actually written is `listToSave.toFirestore()`, a field-for-field copy of `entity` for every
required key.

*Update mirror (Q3).* Owner branch: rule grants with no field constraints; client `requireEditRights`
adds `validateUpdatePermission`, which returns `true` immediately for the owner
(`firebase_shopping_repository.dart:179`), so the `isCollaborative` trap is non-owner-only
(pre-existing, fail-closed). Non-owner branch: `perm in ['edit','admin']` mirrored exactly, and the
`affectedKeys().hasAny([ownerId, memberPermissions, createdAt])` conjunct mirrored VALUE-wise by
`requireNoPrivilegeEscalation` — correct, because `diff()` is value-based too, so re-sending an
identical value is not "affected" on either side. `keepsContributorTrail()` has no client mirror and
needs none: `_withContributorTrail` only ever unions. Its `size() <= 200` bound has no client mirror
on UPDATE (unlike create) — a list that ever reached 200 contributors would be denied server-side
forever while the client logged `granted: true`. Left unfiled: 200 distinct writers on one household
shopping list is not a real state, and filing it would be noise.

*The new offline refusal is inert — caller trace, not a grep (Q3, "does it refuse what the server
grants").* `requireOfflineWritableMutation` throws when a non-carriable, non-privileged key differs.
Eight live mutators reach `mutateCollaborativeList`: six in `shopping_item_operations_module`
(`addItem`, `addItemsBatch`, `updateItem`, `updateItemsBatch`, `removeItem`, `removeItemsBatch`) all
via `_withItems` (items + `updatedAt` + `lastActivityAt` + `lastActivityBy{UserId,DisplayName}`), and
`list_item_operations` add/toggle/remove via the model mutators, which additionally set `syncStatus`
— NOT emitted by `toFirestore()`, which is exactly why they do not trip the guard. So nothing
legitimate regresses. The refusal test in `shopping_repository_routing_module_test.dart` is
falsifiable on the right half (it asserts `items` is EMPTY; the `name` assertion holds with or
without the guard, and the test says so).

*Audit honesty in both directions (Q1), shopping paths.* Every changed path ends with exactly one
row and no forged grant. `requireSelfOwnedCreate` logs only `granted:false` and only after a real
check; the `granted:true` row in `createCollaborativeList` follows an awaited `set()`, so a rules
denial throws first. The two new no-audit throws are correctly audit-free: a missing-field refusal
and `requireOfflineWritableMutation`'s `ArgumentError` are payload-shape refusals, not permission
decisions, and both sit AFTER the audited guards on the offline leg, so no `granted:true` can
precede them.

**Filed (all outside the five staged files, all in the same commit's fileset).**

1. *HIGH — a mutation-test mutant was live in the working tree during the review.*
`git status --porcelain` showed `MM` on `lib/services/account/export/social_export_manager.dart`;
the unstaged half replaced the `_failed()` body with `'error': 'MUTANT raw exception:
PERMISSION_DENIED blocks/me_uid-of-another-person'` and DELETED `error_code`. The staged bytes are
correct, so the commit as staged is clean — but this is what `flutter analyze` and every test run
executes, it would red the manager's own `error_code` assertions on unrelated grounds, and `git add
-A` ships a foreign uid into the section body of an Art. 15 bundle. Note the BUT-1732 chokepoint
holds even under the mutant (`data_export_service` DERIVES `warnings[].message`), which is a real
defence-in-depth datapoint: the root stayed clean, only the downloadable section body was poisoned.
Generalised into the principles as "`git diff --cached` is not the tree".

2. *HIGH — dead OR-arm in the message export filter, a fourth fault on BUT-1767's path.*
`social_export_manager.dart:154-156` keeps a message when `senderId == uid ||
messageData['recipientIds'].contains(uid)`. `Message` has no `recipientIds` field (model:
`id/conversationId/senderId/senderDisplayName/senderAvatarUrl/content/type/status/sentAt/...`; the
rules' create requires only `senderId`, `conversationId`, `content`, `sentAt`). The OR-arm is
therefore always false and the filter is "sent only" — so BUT-1767's fix, which only repoints the
query, would land an Art. 15 bundle silently missing every RECEIVED message, with no truncation or
error flag to say so. Masked today because the query reads a phantom subcollection. Generalised into
the wrong-field-shape principle.

3. *MEDIUM (pre-existing, outside the hunk) — the conversations section diverges from the
shared-shopping-list Art. 15(4) verdict with no deviation entry.* `exportConversationsAndMessages`
returns `convoDoc.data()` verbatim as `conversation_info`, carrying every other participant's uid,
`participantDisplayNames`, `participantAvatarUrls`, `lastReadTimestamps` and the embedded
`lastMessage` (sender id, sender display name, content). The 2026-07-30 shared-list entry in
`ACCEPTED_DEVIATIONS.md` decided the opposite shape for the sibling case — keep uids and permission
levels, DROP display names — and conversations has no matching entry. This ships today regardless of
BUT-1767, and BUT-1767's fix adds the counterparty's message content plus `senderDisplayName` and
`senderAvatarUrl` on top. Needs Malin's call recorded, not a reviewer's.

4. *LOW (pre-existing, gateway-wide) — the Art. 15 export writes no audit row at all.*
`_guardSelfExport` (`firebase_data_export_repository.dart:139-148`) delegates to the mixin's
`validateOwnership`, which emits `AppLogger.warning` on denial and NOTHING on grant, and never calls
`logPermissionCheck`. So a bulk read of a user's entire dataset leaves no trail in either direction.
Nothing is forged; the record is simply absent. Cheapest fix is ONE row at the service level per
export rather than ~30 per bundle at the gateway.

**Deliberately not filed.** `createCollaborativeList` rebuilds `listToSave` field-by-field and drops
`collaborativeOrigin`, `generatedForWeek` and `schemaVersion` — traced all three to no live
consumer (`collaborativeOrigin` is set only by `createCollaborativeListFromInvitation`, a path the
create rule has always refused; `generatedForWeek` is stamped by a later `updateList` on a PERSONAL
list; `schemaVersion` defaults to 1). Non-security, no live impact, so it stays out rather than pad
the report.

**Not verified:** `functions/src` (rules tests belong to `firestore-rules-tester`, and
`shared-shopping-lists-rules.test.ts` is staged with 310 changed lines); whether the queued
`FieldValue.arrayUnion` on `contributorUserIds` satisfies `keepsContributorTrail()` under a real
`update()` transform (emulator question, same owner); the second `MM` file
(`functions/src/analytics/compute-feature-retention.ts` — the unstaged half is a doc-comment
addition only, read and harmless, but it should be staged with the rest).

### 2026-07-30 — BUT-1772 conversations-export avatar redaction: PASS, and the two things the review turned up

Staged fileset: `lib/services/account/export/social_export_manager.dart` (+`_dropOtherPeoplesAvatars`,
applied at the `conversation_info` construction), its test, `ACCEPTED_DEVIATIONS.md`,
`.claude/rules/accepted-deviations.md`, `tasks/todo.md`. Malin's recorded call: keep other
participants' display names and uids, strip their avatar URLs, keep the requester's own.

**Verified clean.** Mutation-reproduced independently, whole test file each time (never
`--plain-name`): early-return before the redaction → 2 reds; `if (false && …)` on the `lastMessage`
leg ALONE → the same 2 reds (so the embedded copy is independently covered, not only the map);
`copy.remove('participantDisplayNames')` → 1 red. `flutter analyze` clean on both files; the whole
file's 22 tests green. `git status --porcelain` shows no `MM` on either code file (only
`docs/onboarding/workflow-map.html` unstaged + an untracked `workflow-map.stale` naming this exact
file as its trigger — the map text for BUT-1772 is written but NOT staged, so the commit as staged
leaves the marker unresolved).

**Aliasing: none, and the reason generalises.** `sanitizeForJson`
(`export_pagination_helper.dart:9-24`) DEEP-rebuilds every Map (`value.map((k,v) =>
MapEntry(k.toString(), sanitizeForJson(v)))`) and List, so the map handed to the redactor is owned by
nobody else and `convoDoc.data()` is never touched. Independently, both mutations REPLACE a key on
the shallow copy with a NEW map instead of mutating a nested one in place — the shape that stays
correct even if the source were shared. Residual, informational: `Map<String,dynamic>.from(lastMessage)`
is itself shallow, so the new `lastMessage`'s `metadata`/`reactions` sub-maps are shared with the
throwaway; a future extension that reaches INTO them (`copy['lastMessage']['metadata'].remove(...)`)
would break the invariant. Also note the `as Map<String, dynamic>` cast at the call site is safe only
because `sanitizeForJson` rebuilds with `MapEntry(k.toString(), <dynamic>)`; a "don't copy when there
are no Timestamps" optimisation there would make it throw on a `Map<String, Object>` and, because the
cast sits inside the section's single try/catch, would fail the WHOLE messages section.

**Finding 1 (Medium, the one the fileset missed): `perUserSettings`.** The conversation document's
key set is NOT `ConversationDto.toFirestore()`. `ConversationMutationModule.updateConversationUserSettings`
(`conversation_mutation_module.dart:416-441`) writes `perUserSettings.<uid>.<key>` by dot-path
`set(mergeFields:)`, and `ConversationDto.fromFirestore:69-73` reads back only the CURRENT user's
sub-map. The export dumps the raw doc, so every OTHER participant's `isMuted`/`isPinned`/`isArchived`
+ `pinnedAt`/`archivedAt` ship. It is not a media pointer, so the decision's avatar test does not
reach it — but the decision's load-bearing justification for keeping names/uids ("the requester has
already seen it on screen") does not hold either: the client never renders another user's sub-map.
Neither the code nor the deviation entry accounts for it. **Rule this generalises:** enumerate a
whole-doc export's third-party surface from EVERY WRITER, not from the DTO — a field written only by
dot-path `set(mergeFields:)`/`update()` is invisible in `toFirestore()` and therefore invisible to
the derived-key test BUT-1732 shipped. Same sweep found `lastMessage.reactions` (emoji → other
participants' uids) and poll `metadata.options[].voterIds` also unenumerated; both are uids, so
covered by the decision, but the record lists neither.

**Finding 2 (High, against the RECORD): the scope note's failure mode is wrong.** Both the entry and
BUT-1767 say the `messages` array "ships EMPTY for every user today". It does not: the export reads
`conversations/{id}/messages` (`firebase_data_export_repository.dart:346-350`), that subcollection has
NO rule block (`firestore.rules:1494-1546` matches only `/userSettings/{uid}` under conversations;
production writes the TOP-LEVEL `messages` collection — `firebase_messaging_repository.dart:147-148`,
and the rules say so in a comment at `:1550`), so the catch-all `match /{document=**} { allow read,
write: if false }` (`:2548-2550`) DENIES the query. A denied query is `permission-denied`, not empty,
the `.get()` has no local catch, and `exportMessages`'s outer catch converts it to
`_failed('Messages','messages-export-failed')`. So for any user with ≥1 conversation the ENTIRE
messages section is absent from the Art. 15 bundle — the requester's own conversation metadata as well
as the messages — surfacing only as an `export_metadata.warnings[]` line, and this redaction has no
production effect until BUT-1767 lands. Rules-derived, not emulator-run; hand the proof to
`firestore-rules-tester`. The forward-looking half of the note is otherwise right —
`MessageDto.toFirestore:116` really does persist `senderAvatarUrl` per message and
`on-profile-updated.ts:95-96` keeps both it and `participantAvatarUrls.<uid>` fresh — but it should
name the TOP-LEVEL `messages` collection as the destination, and note that the per-message redaction
lands in the same loop as the dead `recipientIds` OR-arm.

**Finding 3 (Low/Medium): the `data_minimisation` sentence.** Its DROP claim is exhaustive and true
(avatars, both sites). Its positive clause — "Their names, user ids and messages are kept" — is an
incomplete enumeration of what is kept (also: read timestamps, reactions, poll votes, `creatorId`,
`perUserSettings`), and "messages are kept" sits next to a `messages` array that is structurally
empty/failed today. A positive enumeration in a self-description invites exactly the BUT-1732 defect;
prefer "everything else is kept as stored" over a list.

**Also confirmed, adjacent (Medium, pre-existing, different ticket):** the SAME bundle still ships
another person's avatar URL from a sibling section of the SAME manager — `shared_content` docs carry
`sharedByAvatarUrl` (`recipe_sharing_manager.dart:586`, `social_menu_operations.dart:88`, both via the
`permissionService.currentUser` footgun) and `exportSharedContent` exports them verbatim
(`firebase_data_export_repository.dart:377-388`). Friend docs are clean (`addedAt` +
`displayNameLower` only), `ConversationMembership` is clean, and no message-attached image/voice URL
exists (`MessageType.image`/`voice` have no production writer that stores one).

### 2026-07-30 — BUT-1770 rename propagation reaches shopping ITEM attribution, but only two of four pairs

`functions/src/social/on-profile-updated.ts` gained three legs inside the `nameChanged` block: two
`db.collectionGroup("items").where(<queryField>,"==",userId)` sweeps via `batchUpdateQueryPaginated`
(covering `users/{uid}/unified_shopping_lists/{listId}/items` and `shared_content/{id}/items`), plus
`renameEmbeddedShoppingItems`, which pages `unified_shared_shopping_lists` by
`contributorUserIds array-contains uid` ordered by `documentId()` and runs one `runTransaction` per
list to rewrite the embedded `items` array row by row. Matching COLLECTION + COLLECTION_GROUP
ASCENDING field overrides for `items.addedByUserId` and `items.lastModifiedByUserId` were added to
`firestore.indexes.json`, and the CF suite asserts them straight out of the JSON (the fake models
data, never the index layer). 10/10 green via `npm run test:on-profile-updated`.

Verified clean: cursor fields are never written (`contributorUserIds` and the two query fields are
excluded, asserted by the tests); the per-row guard `item.addedByUserId === userId` prevents putting
the acting user's name on someone else's row; the array-contains + `orderBy(__name__ ASC)` outer
query is served by the automatic array index (no fieldOverride exists for `contributorUserIds`); no
production query orders either overridden field DESCENDING, so replacing the automatic config with
ASC-only is safe; `renameItemsOnList` returning `false` on `!snap.exists` avoids the NOT_FOUND abort.

**The defect: the inventory is short by two pairs.** `UnifiedShoppingItem.toFirestore()` persists
`assignedTo{UserId,DisplayName}`, `purchasedBy{UserId,DisplayName}`, `addedBy{…}` and
`lastModifiedBy{…}`, and `account-deletion-cascade.ts:634-676` scrubs all four. The new leg covers
two, while its doc comment states "The deletion cascade has covered both pairs since BUT-1697",
which misdescribes a cascade that covers four. Worse, the two propagated fields have NO view
reader anywhere in `lib/views` or `lib/widgets`; the only item name field a household member
actually sees is `assignedToDisplayName` (the BUT-238 claim chip —
`collaborative_shopping_items.dart:136` and `:509`), written by
`UnifiedShoppingItem.assign(displayName:)` from `PermissionService.currentUser.displayName`. So the
user-visible stale-name symptom the ticket describes survives the fix.
`purchasedByDisplayName` additionally ships in the Art. 15 bundle
(`shared_shopping_list_export.dart:69`), so its staleness is an accuracy issue on an exported
artifact, not only on screen.

Cost residual (Medium): the outer page snapshot already carries every list's full `items` array,
yet `renameItemsOnList` re-reads the same document inside its transaction unconditionally —
two reads per contributed list per rename, where pre-filtering the page on "does any row match this
uid" would open a transaction only for the lists that need one.

### 2026-07-30 — BUT-1755 stable `createdAt` sentinel, and BUT-1722 the refusal sentence that still has no set-side

BUT-1755 (clean). `UnifiedShoppingList.unknownCreatedAt = DateTime.utc(1970)` is now
`fromMap`'s `defaultValue` for `createdAt`, replacing `SerializationUtils.safeRequiredDateTime`'s
`clock.now()` fallback. That makes `ShoppingListPermissionGuards.requireNoPrivilegeEscalation`'s
exact `proposed.createdAt != stored.createdAt` comparison meaningful for a legacy/imported document
— two parses of the same doc now agree, where before every non-owner edit of such a list was
refused forever with advice ("reload") that could not clear it. The new
`test/unit/repositories/firebase/modules/shopping_list_permission_guards_test.dart` (165 lines,
5/5 green) drives the guard THROUGH `fromMap` under a clock that advances a minute per reading —
deliberately non-vacuous, since building both lists with an explicit `createdAt` would pass on the
broken code, and two back-to-back `clock.now()` calls are a same-tick coin flip. The
`_accessControlDrift` exclusion of `createdAt` and the unconditional `createdAt` strip in
`restrictAccessControlToDeclaredBase` both correctly STAY, re-justified on intent rather than on
the seam. Residual (Low): `fromJson` (`unified_shopping_list.dart:697`) still takes the `clock.now()`
fallback; the model's doc comment scopes the sentinel to `fromMap` honestly, and the JSON cache
seam always round-trips a written `createdAt`, so nothing reads it today.

BUT-1722 (incomplete). `CollaborativeShoppingViewModel.consumeItemOperationError()` finally gives
`ShoppingItemOperationsManager.error` a reader, and `collaborative_shopping_view._showFailureReason()`
prefers it over the VM's load-scoped `error` (which would have been routed into
`LoadingStateBuilder` and replaced the whole list — the BUT-1696 regression). Three widget tests
green. But the manager's SET side is unchanged: `toggleItemCompletion` returns `false` from
`if (!canEdit)` and from `item == null` without calling `setError`, and `addItem` does the same for
`!canEdit`. Meanwhile the checkbox and the row `onTap` are gated on `viewModel.canView`
(`collaborative_shopping_items.dart:425,469`), so a view-only member CAN tap and still gets an
empty snackbar path — precisely the scenario the new doc comment and the new test group narrative
name as the bug being fixed. The tests stub `toggleItemBought → false` with `canEdit` true, i.e.
the offline/list-gone path only. Locale keys for the missing sentence already exist
(`shoppingNoEditPermissionShared`, `shoppingNoEditPermission`). Also, the manager never clears
`_error` at the start of an operation, so the doc comment's claim that self-clearing-on-read
prevents a stranded reason is wrong in principle (a caller bailing on `if (!mounted) return;`
never performs the read); the BUT-1696 `_beginMutation()` clear-at-entry shape is the one that
holds.

### 2026-07-30 — BUT-1766/1767/1768/1773 review: the phantom-subcollection round closes chat erasure and Art. 15, and opens two residual field groups

Reviewed fileset (account sprint): `functions/src/account/account-deletion-cascade.ts`,
`functions/src/account/request-account-deletion.ts`, `functions/src/__tests__/account-deletion-cascade.test.ts`,
`functions/package.json`, `lib/repositories/firebase/firebase_messaging_repository.dart`,
`lib/repositories/firebase/modules/message_deletion_module.dart`,
`lib/repositories/firebase/firebase_data_export_repository.dart`,
`lib/services/account/export/social_export_manager.dart`, `lib/services/account/data_export_service.dart`,
`lib/services/realtime/realtime_{menu,recipe}_service.dart`,
`lib/viewmodels/recipe_form/recipe_collaborative_manager.dart`, `firestore.indexes.json`, + 4 test files.

**What the round genuinely fixes.** The `conversations/{id}/messages` phantom subcollection — the
exact bug class the principles file already carried — is repointed to the top-level `messages`
collection keyed by a `conversationId` FIELD, on BOTH the erasure side (`deleteMessages` now
anonymizes `senderId == uid` anywhere, including conversations the user has LEFT, then deletes 1:1
threads whole) and the Art. 15 side (`exportConversationsAndMessages` had THREE independent faults:
wrong collection, `orderBy('timestamp')` on a field `MessageDto.toFirestore` never writes, and an
in-memory filter on `recipientIds`, a field no message doc has ever carried, which silently dropped
every RECEIVED message). `realtime_menus` gained a cascade tier for the first time; `scrubLastEditor`
anonymizes the `lastEditedBy`/`lastEditedByDisplayName` pair on docs the user edited but does not own
(non-nullable `String` in `RealtimeResource`, hence anonymize-not-null). `probeResidualData` grew four
owner-keyed probes, deleter ⊇ probe verified per leg. Verified green: `npx ts-node
src/__tests__/account-deletion-cascade.test.ts` → 12/12; `flutter test` over the three Dart suites →
55 passing; `data_export_service_test.dart` → 40 passing; `flutter analyze` on 8 lib files clean;
`npx tsc --noEmit` clean. The new CF suite is auto-discovered by `functions/scripts/run-all-tests.js`
(any `test:*` script except `test:rules*`/`test:integration:*`), so no hand-typed CI list to drift.

**Residual 1 (High, open).** `deleteMessages`' group branch does `arrayRemove` on `participantIds`
and nothing else. `on-profile-updated.ts:96-97` — the propagation inventory — writes
`participantDisplayNames.${uid}` and `participantAvatarUrls.${uid}` on the same collection, and the
conversation doc also holds `lastReadTimestamps.${uid}`, `perUserSettings.${uid}`
(`conversation_mutation_module.dart:416-441`) and an embedded `lastMessage` map carrying the
sender's name, avatar and content — none of which anonymizing the top-level `messages` row touches.
`functions/src/cleanup/on-user-deleted.ts` does not cover conversations either (grepped: zero
matches). The correct removal shape is three lines away in the same repo:
`functions/src/messaging/enforce-group-minor-membership.ts:247-252`. Cheap probe addition:
`conversations where participantIds array-contains uid` must be 0 after the cascade.

**Residual 2 (High, open).** `deleteRealtimeMenus`/`deleteRealtimeRecipes` `batchDeleteAll` parent
docs bare. `firestore.rules:1052-1076` declares `realtime_menus/{id}/presence/{userId}` and
`/votes/{voteId}`; `collaborative_recipe_repository.setPresence` (called from
`realtime_editor_tracker.dart:28-32`) writes `realtime_recipes/{id}/presence/{uid}` with
`{displayName, isActive, lastSeen}`. So the parent delete orphans a uid-keyed doc carrying a display
name, and on docs the user does NOT own that presence doc plus their `participants` map key and
`participantIds` entry are never removed at all.

**Residual 3 (Medium, decided-calls drift).** `.claude/rules/accepted-deviations.md`'s BUT-1772 entry
still reads "has NO production effect yet — the section currently FAILS (`messages-export-failed`)".
This diff makes it live, and with it the `perUserSettings` question the same entry explicitly defers
to BUT-1774: `firebase_data_export_repository.dart:392` ships `convoDoc.data()` whole, so every other
participant's mute/pin/archive state now reaches a real bundle. Undecided third-party data going live
needs the entry updated in the same commit, in both files.

**Residual 4 (Medium, false factual claim).** BUT-1773's one-row-per-export decision is argued in
`firebase_data_export_repository.dart:139-145`, `data_export_service.dart` (`_logExportAudit` doc) and
a test `reason:` string from "`firestore.rules` caps `audit_logs` creates at
`rateLimitWrite('audit_logs', 2)` — rows 3..30 would be rejected". Grepped: nothing anywhere writes
`users/{uid}/rate_limits/{collection}.lastWrite`, so the conjunct is inert and the claim is false.
The Art. 30 argument alone is correct and sufficient. (Promoted to a principle bullet.)

**Cost note.** With the message query finally returning rows, `exportConversationsAndMessages` runs
`ExportPaginationHelper` caps of 500 conversations × (1000+1) messages as 500 SEQUENTIAL client
queries — up to ~500k document reads and minutes of wall time per export. Previously the inner query
was denied and returned instantly. Not a defect, but the nested cap product is now real.

**Smaller.** `commitInChunks(..., strict:false)` on `anonymizeOwnMessages` can silently leave a
450-doc chunk carrying live name/avatar/content, with no retry (`auth.deleteUser` runs
unconditionally) — mitigated only by the new probe, and consistent with `deleteCommentsAndRatings`.
Leg ordering double-writes every 1:1 message (anonymize, then delete) — deliberate, because a
`batch.update` on an already-deleted doc would fail the whole chunk under `strict:false`. The new
`messages` composite `(conversationId ASC, sentAt ASC)` is very likely redundant with the existing
`(conversationId ASC, sentAt DESC)` — an equality-filtered composite serves both scan directions —
so it may be pure write amplification on the app's highest-volume collection. `bundle_bytes` is
`String.length`, i.e. UTF-16 code units. `ACCEPTED_LARGE_FILES.md:75` still records
`firebase_data_export_repository.dart` at 783 lines; it is 831. `MessageDeletionModule` has zero
production callers (interface + tests only) — the CF is the live erasure path, and the module's own
test correctly pins that a client can never delete the counterparty half of a 1:1
(`firestore.rules:1578` grants delete on own `senderId` only).

### 2026-07-31 — BUT-1762 personal-list activity-day stamp: PASS, with one inert-guard risk and one downstream GDPR residual

Reviewed `lib/repositories/firebase/modules/shopping_item_operations_module.dart` (new private
`_touchPersonalListDay`), its test file, and the comment-only
`functions/src/analytics/compute-feature-retention.ts`. Verdict: PASS, no blocker.

**Rules (concern 1) — permitted, no rules change, no rules-tester handoff.**
`firestore.rules:393-401`: `match /users/{userId}/unified_shopping_lists/{listId} { allow read,
write: if isOwner(userId); }` — unconditional owner read/write, no `affectedKeys`, no field-shape
conjunct, no `hasRequiredFields`. The helper writes `getUserCollection(uid).doc(listId).update({
'updatedAt': Timestamp.fromDate(now) })`, and `base_firebase_repository.dart:86-92` builds that as
`users/{uid}/unified_shopping_lists` from `requireCurrentUserId()`. Note the stamp is STRICTLY
narrower than the item write it follows: the six personal branches call `validateOwnership(uid,
list.ownerId, ...)`, but the stamp's path is derived from `uid` on both ends, so it cannot reach
another user's tree even if `ownerId` disagreed. `firestore.rules` and `firestore.indexes.json` are
unmodified vs HEAD (`git status --porcelain -- firestore.rules` empty).

**Swallowed catch (concern 2) — not hiding a denial.** With an unconditional owner-write rule the
only realistic errors are `not-found` (the documented conversion orphan: items subcollection alive,
parent deleted) and transient/offline. The sink is `AppLogger.warning`, which is
`developer.log` ONLY (logger.dart:157-163) — no Crashlytics, no analytics forward, unlike
`AppLogger.error(msg, e)` — so the interpolated `$e` (which can carry the raw uid inside a Firestore
doc path, even though the message masks `uid.maskedUserId` separately) never leaves the device.
Low recommendation only: branch on `permission-denied` so a future tightening of the rule cannot
fail silently forever.

**The real inertness path (Medium, new principle).** `UnifiedShoppingList.fromMap:778-780` resolves
`updatedAt` via `SerializationUtils.safeRequiredDateTime(data,'updatedAt')`, which is
`parseDateTimeValue(map[key]) ?? defaultValue ?? clock.now()` (serialization_utils.dart:142-148) —
and the BUT-1755 comment at :767-770 says the deterministic sentinel was DELIBERATELY not applied to
`updatedAt`. So a parent doc missing/unparseable `updatedAt` reads as "touched today", the same-day
guard short-circuits, and that list is never stamped again. Today's corpus should be clean
(`toFirestore():617` always emits it), but the guard fails toward NEVER WRITING, which is the exact
failure the ticket exists to remove. Cheap fix: pass the raw stored value / a nullable, treat
unknown as stamp-worthy.

**GDPR (concern 3).** The field itself is fully covered and needs nothing: `updatedAt` already
existed on the user's own private doc; the Art. 15/20 export dumps the whole parent doc
(`firebase_data_export_repository.dart:231-272`, `'data': listDoc.data()` + the items
subcollection); Art. 17 erasure is the BUT-1697 `unified_shopping_lists` sweep (parent + items). Day
granularity, no new field, no new key — data minimisation fine.
The NEW surface is downstream, and it is PRE-EXISTING but AMPLIFIED:
`compute-feature-retention.ts` writes `analytics/feature_retention/users/${userId}_${dateStr}` with
`{ userId, date, cooked, imported, shared, mealPlanned, shopped }` — raw uid in the doc id AND in a
field, one doc per user per day. Greps: no `analytics`/`feature_retention` step in
`account-deletion-cascade.ts` (its only "analytics" hit is BUT-1450 notification analytics at :86),
no entry in `probeResidualData`, no TTL/purge job anywhere in `functions/src` (only the compute file
and two test files mention the path), no entry in `ACCEPTED_DEVIATIONS.md`. Before this ticket the
`shopped` bit was a structural false for personal-only users; after it, it is a truthful per-day
record that this person shopped. Follow-up ticket, not a blocker: sweep it in the cascade (doc ids
are uid-prefixed, so a `documentId()` prefix range works — remember the `_` separator AND the
U+F8FF upper bound, spelled as an escape) + add it to the residual probe, or ship a TTL plus a dated
deviation entry in the shape of the `parse_events` one.

**Collaborative path (concern 4) — unreachable, confirmed by reading all six call sites.** Lines
228, 317, 364, 466, 518, 571 are each inside the `else` (non-collaborative) branch; the
collaborative branches all go through `mutateCollaborativeList` + `_withItems`, which stamps
`updatedAt`/`lastActivityAt`/`lastActivityBy*` inside the transaction. The helper never touches
`unified_shared_shopping_lists`, never touches `contributorUserIds`, never writes a
`lastActivityBy*` pair. Even in the known `type`-missing degenerate case (enum `orElse` ⇒ parses as
`personal`), the helper still writes only in the caller's own tree and 404s harmlessly.

**Other notes.** (a) Product-visible side effect, Low: personal lists are ordered `updatedAt desc`
in both `readAll()` (`shopping_repository_query_module.dart:118`) and `personalListsStream()`
(:200, `.limit(20)`), so a list shopped today jumps to the top once per day and can push the 20th
list out of the stream window — consistent with what `updatedAt` means, but a visible reorder.
(b) Offline, Low, metric-only: the personal legs already await real writes, so nothing regresses;
but a shop done offline reaches the stamp only when the item write's future resolves, and an app
killed before that replays the item write from the queue while the day is never stamped.
(c) No forged audit grant — the helper logs nothing, and the branch's `validateOwnership` already
ran (contrast the `logPermissionCheck(granted:true)`-with-no-check anti-pattern).
(d) Cost: +1 write per personal list per user per day, bounded; the day guard reads no extra doc
because `known` comes from the `_requireList` read the branch already performs.

### 2026-08-01 — BUT-1788: leave-group / remove-member moved to a Cloud Function (`leaveGroupConversation`)

**Reviewed fileset:** `functions/src/messaging/leave-group-conversation.ts` (new),
`functions/src/__tests__/leave-group-conversation.test.ts` (new),
`functions/src/__tests__/app-check-enforcement.test.ts`, `functions/src/index.ts`,
`functions/package.json`, `lib/repositories/firebase/modules/conversation_mutation_module.dart`,
`lib/repositories/firebase/firebase_messaging_repository.dart`,
`test/unit/repositories/firebase/modules/conversation_mutation_module_test.dart`.

**Verified good.** The ticket's premise checks out at the rules layer: `firestore.rules:1533-1535`
denies any client update whose diff touches `participantIds`, and `:1561-1568` denies a create with
`senderId != auth.uid`, so both the old membership write and its "X har lämnat gruppen" system
message were dead. `authorizeDeparture` fails closed on a missing `metadata.creatorId` (and that
field is bound to the creating client by the create rule, BUT-1626), the client's `isAdmin`
(`group_detail_viewmodel.dart:99-103`) uses the same `creatorId == currentUserId` predicate so no
legitimate UI path regresses, `buildDepartureUpdate` mirrors `buildGroupDepartureUpdate` in
`account-deletion-cascade.ts` (all four uid-keyed maps + `arrayRemove`), the uid is
`isValidDocId`-checked BEFORE being spliced into dot-paths, `enforceAppCheck: true` matches the
sibling user-facing callables, the client resolves `FirebaseFunctions` lazily exactly like
`friend_relationship_repository.dart`, and the Swedish string matches `chatParticipantLeft` in
`app_sv.arb:9415`. Ran: `npx tsc --noEmit` (clean), `npm run test:leave-group-conversation` (13/13),
`npm run test:app-check-enforcement` (16/16), `dart analyze` on the three Dart files (clean),
`flutter test .../conversation_mutation_module_test.dart` (15 pass, 1 pre-existing skip).

**Finding 1 (High, GDPR).** `writeDepartureSystemMessage` is the first system message in this app
that actually LANDS (the client-side ones were always rules-denied), and it embeds the departing
member's display name in `content` under `senderId: "system"`. `deleteMessages`
(`account-deletion-cascade.ts:1133-1155`) anonymizes only `where senderId == uid`, and
`buildGroupDepartureUpdate` tombstones `lastMessage` only when `lastMessage.senderId == uid` — so
after that person deletes their account the name survives both in the `messages` row and in the
`conversations/{id}.lastMessage.content` copy that `syncConversationLastMessage` writes, readable
by every remaining member, unreachable by the cascade and absent from `probeResidualData`. Fix
shape: stamp `metadata: {systemEvent:"participant_left", subjectUserId: targetUid}` on the row and
add a cascade step querying it (equality on a nested field needs no declared index) that rewrites
`content` and the matching `lastMessage.content`, plus a probe entry — or drop the name from the
text. Also note the cascade never visits the conversation at all once the person has left
(`participantIds array-contains uid` no longer matches), so the message row is the only handle.

**Finding 2 (Medium, information disclosure).** `authorizeDeparture` evaluates
`targetUid === callerUid` before the membership test, so a non-member self-leave returns
`{success:true, removed:false, remainingParticipants:N}` while a missing doc throws `not-found` and
a 1:1 doc throws `failed-precondition`. Since direct-conversation ids are deterministic
(`direct_${sorted uids}`, `conversation_mutation_module.dart:57`), any authenticated user who knows
two uids can test whether those two have a DM, and can read the member count of any group id they
hold. Suggested: return `remainingParticipants: 0` on the no-op branch, and collapse "caller is not
a participant" into `not-found` (costs a benign error on a genuine retry after a dropped response).

**Finding 3 (Medium, pre-existing but it may make the fix inert).**
`FirebaseMessagingRepository` mixes in `UserScopedFirebaseRepository`, so `createFn`/`readFn`/
`updateFn` resolve to `users/{uid}/conversations/{id}` (`base_firebase_repository.dart:86-92,
428-432`), while `createDirectConversation` (:105), `deleteConversation` (:372),
`updateConversationUserSettings` (:399), the `arrayContains` stream
(`conversation_query_module.dart:33`) and the new CF all use TOP-LEVEL `conversations/{id}`.
Consequences: a group created by `createGroupConversation` lands only in the creator's private
subtree (so it can never appear in anyone's conversation stream, and the CF answers `not-found` for
it); `addParticipants` reads null from the subtree and throws `ResourceNotFoundException`, i.e. the
add-member counterpart of this ticket is still dead. Could not verify against production data
whether existing groups also exist top-level (created before the mixin, or by a path not in the
repo). Recommended as a follow-up ticket covering the whole module, not a patch here.

**Notes, no action.** No audit-log row is written for an admin removing another member, but no
sibling messaging CF writes one either (`enforce-group-minor-membership.ts`,
`accept-friend-request.ts` are both silent), so this is a repo-wide convention rather than a gap in
this diff. `removeGroupParticipantWithDeps` is documented as "exposed for tests with a fake
Firestore" but no test drives it — only the two pure cores are covered. The Dart integration test
`messaging_repository_integration_test.dart:150-184` still asserts the old client-side write, but
the whole file is `@Skip`ped (BUT-369), so nothing reds.

### 2026-08-01 — BUT-1788 re-review: the no-oracle gate landed; the admin identity it trusts did not

Re-reviewed the working tree after automated fixes: `functions/src/messaging/leave-group-conversation.ts`,
its unit test, `functions/src/index.ts`, `functions/package.json`,
`functions/src/__tests__/app-check-enforcement.test.ts`,
`lib/repositories/firebase/modules/conversation_mutation_module.dart`,
`lib/repositories/firebase/firebase_messaging_repository.dart` and the Dart module test.

**What the fixes closed, verified by running the suites.** (a) The response-oracle flagged in the
previous round is gone: `removeGroupParticipantWithDeps` now runs
`if (!snap.exists || !participantIds.includes(callerUid)) return {removed:false, remaining:0, …}`
BEFORE the group-ness test and before `authorizeDeparture`, so a missing conversation, a group the
caller is not in and a DM the caller is not in are byte-identical replies carrying no count — and a
paired positive case ("a real participant still gets the real remaining count") keeps that test from
passing on a function that always returns 0. (b) `removeGroupParticipantWithDeps` is now driven by
tests (the previous round's "documented for tests but no test drives it"): 8 orchestration cases over
a hand-rolled fake db cover the single write, both mirrors, the idempotent no-write retry, the padded
participant list, a failing mirror cleanup, the denial, the oracle set, and the Art. 17 handle.
`npm run test:leave-group-conversation` → 22/22. `app-check-enforcement.test.ts` → 16/16 with the new
`leaveGroupConversation` entry. `flutter test .../conversation_mutation_module_test.dart` → 15 pass,
1 pre-existing skip. `dart analyze` on the three Dart files → clean.

**The open High.** `authorizeDeparture` treats `metadata.creatorId` as the group admin, and the file
comment argues it is "bound to the creating client by the conversation create rule (BUT-1626), so it
is a trustworthy admin identity". The binding at `firestore.rules:1525-1529` is on CREATE only. The
UPDATE rule (`:1532-1535`) is `isAuthenticated() && uid in resource.data.participantIds &&
!diff.affectedKeys().hasAny(['participantIds','createdAt'])` — `metadata` is not in that list and
`affectedKeys()` is top-level, so ANY participant may `update({metadata:{creatorId: myUid}})` and
then call the callable to remove the real creator and everyone else. That is the group-takeover
primitive the file's own header says it refused to trade the broken feature for. `metadata.creatorId`
is unreachable from the shipped client (the mutation module's `updateConversation` goes through
`updateFn` → `UserScopedFirebaseRepository` → `users/{uid}/conversations`), but a tampered client is
the stated threat model of the whole function. Fix: add a `metadata.creatorId` immutability conjunct
to the conversations update rule and hand it to `firestore-rules-tester`; or resolve the admin
identity from a path clients cannot write. Note `enforceGroupMinorMembership` is NOT affected — it is
an onDocumentCreated trigger, so it reads the field while the create binding still holds.

**Verified sound, so future rounds need not re-derive.** The client chain reaches the callable for
real (`group_detail_viewmodel.leaveGroup`/`removeMember` and `conversations_viewmodel.leaveGroup` →
`MessagingService.removeParticipantFromGroup` → `MessageManagementOperations` →
`FirebaseMessagingRepository.removeParticipant` → mutation module → `httpsCallable`), i.e. not a dead
twin. The Art. 17 handle is wired end to end: `metadata.subjectUserId` is written here, queried by
`anonymizeSystemMessagesAboutUser` (`account-deletion-cascade.ts:1229`), which also rewrites the
`conversations/{id}.lastMessage` copy and clears the handle, and the field is in `probeResidualData`
(`:156`); `messages` has no field override in `firestore.indexes.json`, so the automatic single-field
index on the nested path exists. A departed user's own messages stay erasable because `deleteMessages`
queries `messages where senderId == uid` globally, not per-conversation. Module-level
`const db = admin.firestore()` matches 12 existing production CF files. The system-message payload
matches `MessageDto.toFirestore` field-for-field.

**Lesser, left as notes.** When the LAST participant leaves, the doc is left with
`participantIds: []` — unreadable and undeletable by everyone (the read/delete rules both require
membership) and invisible to the cascade's `array-contains` query; PII is still covered by the two
senderId/subjectUserId legs, so it is orphaned storage rather than a GDPR hole. The client discards
the `removed` flag, so the deliberate non-member no-op reports success and fires `logGroupLeft`. The
callable has no rate limit: each probe costs one document read (no information, but billable).

### 2026-08-01 — BUT-1788 re-review: the leave callable reads a path client-created groups do not occupy

Re-review of the fixed working tree (`functions/src/messaging/leave-group-conversation.ts`, its unit
suite, `index.ts`, `functions/package.json`, `app-check-enforcement.test.ts`,
`conversation_mutation_module.dart` + test, `firebase_messaging_repository.dart`). The two fixes from
the previous round are correct and proven: the no-oracle gate sits before every shape-revealing
branch and has its paired positive test ("a real participant still gets the real remaining count",
22/22 green), and the `metadata.creatorId` immutability conjunct is now in the conversations update
rule. `npx tsc --noEmit` clean, `dart analyze` clean on the three Dart files, the module's Dart suite
15 passed / 1 pre-existing skip, `check-test-registration` OK (124 files), `CI_EXCLUDE` is now empty
so both the new unit suite and `app-check-enforcement` actually run on the CF unit lane, and the
integration suite is in `test:rules:all` + both `paths:` blocks of `firestore-rules.yml`.

**What the round missed, and it is the headline claim of the ticket.** The callable reads top-level
`conversations/{conversationId}` (`Collections.conversations`). `FirebaseMessagingRepository` mixes in
`UserScopedFirebaseRepository`, so `createGroupConversation`'s `createFn` writes the group doc to
`users/{creatorUid}/conversations/{id}`; nothing in `lib/` writes a top-level group doc except
`MessageMutationModule.sendMessage`, which merge-sets the conversation it read (again the private
subtree copy) alongside the message. And `createGroupConversation` never reaches that: it ends with
`sendMessageFn(Message.system(...))`, whose `senderId:'system'` fails `sendMessage`'s own
`conversation.isParticipant(senderId)` check and throws `PermissionDeniedException` — the same
"KNOWN BROKEN" note this diff adds to `addParticipants`. So for a group where the creator has not yet
sent a normal chat message there is no top-level doc at all, only the creator's subtree copy and the
`conversations/{id}/participants/{uid}` + `users/{uid}/conversation_memberships/{id}` mirrors.

Combined with the new no-oracle gate, `!snap.exists` returns `{success:true, removed:false,
remaining:0}`; `ConversationMutationModule.removeParticipant` discards the response,
`ConversationsViewModel.leaveGroup` returns `true` and fires `logGroupLeft`. Before this change the
same call threw (`readFn` → subtree → null → `ResourceNotFoundException`). Net: a loud failure became
a silent false success plus a false analytics event, on what looks like the common production shape.
Filed High. Suggested remedies, in order: (a) unify the conversation path (own ticket — the mixed
nesting is the root cause and also strands `enforceGroupMinorMembership`); (b) meanwhile, on the
no-op branch of a SELF-leave, still delete the caller's OWN two mirror docs — it discloses nothing
new (the caller learns only about their own membership), it is the only part a wrong-path call can
still get right, and it makes leave effective in the mirror-only world.

Also noted this round: an admin removing ANOTHER member is a cross-user privileged mutation with no
`audit_logs` row — only `logger.info`. The repository leg used to have no genuine check either (so
nothing was forged), but the trail is now console-only. Medium.

### 2026-08-01 — BUT-1781 fileset review: `shared_content` two-spelling repair, the leave-group client half, and the notification-cache residual

Reviewed uncommitted: `firebase_data_export_repository.dart`, `firebase_messaging_repository.dart`,
`modules/conversation_mutation_module.dart`, `services/offline/offline_user_storage.dart`.

**1. `shared_content` membership spellings — export/rules now agree, erasure does not.**
Verified: `firestore.rules:720-728` grants `list`/`get` on `sharedByUserId` or
`request.auth.uid in resource.data.sharedToUserIds` and knows nothing of `sharedWithUserIds`; the
three direct writers (`recipe_sharing_manager._writeToSharedRecipesCollection`,
`social_menu_operations`, `shopping_social_share_module`) now emit both arrays; the new
`_sharedContentReceivedQuery` filters `contentType == X` + `sharedToUserIds arrayContains uid`.
So the recipe leg (previously filtered on `sharedWithUserIds`) had been `permission-denied` — the
whole `shared_content` section failed, not merely returned empty — and the menu leg read top-level
`menus`, which `SharedMenu.toFirestore()` (→ `base_shared_content_model.getCommonFirestoreFields`)
never stamps with `sharedToUserIds` or `sharedByAvatarUrl`. Both claims in the new doc comments
check out.

What does NOT hold: `account-deletion-cascade.ts:1369-1392` (`removeFromSharedContent`) discovers
its docs with `collectionGroup("members").where("userId","==",uid)` and only `arrayRemove`s
`sharedToUserIds`. The three direct writers write the parent doc alone — no `members/{uid}` — so
the deleted user's uid survives in BOTH arrays on every doc they were shared into, and
`probeResidualData` (cascade lines 82-190) has no `shared_content` entry in any of its three probe
loops. The compatibility duplicate doubled the residual instead of retiring it.

Also open in the same collection: `contentType: 'shopping_list'` docs (written by
`shopping_social_share_module`, carrying `listData` — a whole list snapshot — plus
`sharedByAvatarUrl`) are read by no export leg. `SharedShoppingListExport` looks like coverage but
queries `unified_shared_shopping_lists`.

Index: `firestore.indexes.json` declares `shared_content(contentType ASC, sharedToUserIds CONTAINS,
sharedAt DESC)` for `FirebaseGroupSharedContentRepository`'s ordered query. The export's two-filter
query has no `orderBy`, so it relies on Firestore prefix index selection — NOT verified against a
live backend here. Adding `.orderBy('sharedAt', descending: true)` would match the declared index
exactly and make the 1000/500 cap take the newest rows rather than an arbitrary set (today the cap
is applied with no ordering at all).

**2. leave-group: the CF is careful, the client throws the answer away.**
`conversation_mutation_module.removeParticipant` now calls `leaveGroupConversation` and is still
`Future<void>`: it `await`s `callable.call<Map<String,dynamic>>` and never reads `removed`. The CF's
no-oracle gate (`leave-group-conversation.ts:271`) returns `{removed:false, remaining:0}` +
`success:true` for missing doc / non-member / already-left, so all of those surface as
`AppLogger.success('✅ Removed participant …')`, `MessageManagementOperations` logs success,
`ConversationsViewModel.leaveGroup` returns `true` and fires `logGroupLeft`. And the missing-doc
branch is reachable by construction: `createGroupConversation` writes through `createFn`
(`UserScopedFirebaseRepository` → `users/{uid}/conversations`) while the CF reads top-level
`conversations/{id}`, which is only born in `MessageMutationModule.sendMessage`
(`batch.set(firestore.collection(collectionName).doc(conversationId), …)`, module line 191) — and
that module's own `isParticipant` check (line 69) rejects `senderId: 'system'`, so the creation
system message never creates it either. A group nobody has chatted in reports a successful leave
and stays.

Rules half is right: the new `conversations` update conjunct pins
`metadata.creatorId` (`firestore.rules:1546-1548`), which is what makes `authorizeDeparture`'s
admin check trustworthy — `affectedKeys()` is top-level, so `metadata` was previously rewritable
wholesale by any participant.

**3. `offline_user_storage.dart` is not the BUT-1799 file.** Its only change adds
`'stale-properties'` to `_needsRetagging`'s marker set — allergen-freshness correctness, no
Firestore, no PII, fine. The notification-settings hole lives in
`notification_preference_manager.getPreferences` (fixed: read error no longer seeds + persists
defaults, and no longer clobbers the local cache before reading it) and
`NotificationPreferences.fromJson`/`toJson` (previously `'{}'` and `defaults()` stubs). Residual:
`fromJson` returns `defaults()` for an unusable payload, `_loadPreferencesLocally` returns that as
a non-null cache hit, and the legacy `'{}'` the old stub wrote is in every existing user's
`SharedPreferences` — so the first failed read after upgrade serves and caches factory settings,
and `notification_preferences_view._savePreferences` writes the whole object back on the next
toggle. Fail toward null.

**4. Mixin coverage.** `BaseFirebaseRepository` carries `PermissionValidationMixin`
(base_firebase_repository.dart:17-19), so both repositories in the fileset inherit it;
`FirebaseDataExportRepository` funnels every read through `_guardSelfExport → validateOwnership`
and throws from all four CRUD hooks. `removeParticipant` has no `logPermissionCheck` on either
branch — the admin-removes-another-member path is a cross-user privileged mutation whose only trail
is the CF's `logger.info` (same Medium as the previous round's note).

### 2026-08-10 — BUT-1819 second-pass review: the serializer chokepoint, and two comments that outran the code

Fileset: `firebase_recipe_repository.dart`, `offline_sync_manager.dart`,
`recipe_sharing_manager.dart`, `recipe_sanitizer.dart` (new), `external_link.dart` (new),
`firebase_shared_recipe_repository.dart`, plus render-guard adoption in the recipe detail views.
**Verdict: pass, 0 blocking.** First pass had returned 2 blocking (binary blob, unstaged half);
both verified repaired — `file` reports text on all new files, `git diff --cached --numstat` has no
`-\t-` rows, `git status --porcelain` shows no `MM`/`AM` in the fileset, and the corrected
`@sealed` comment (`offline_sync_sanitize_test.dart:40-43`) now names package:meta and the
`subtype_of_sealed_class` diagnostic rather than claiming the Dart keyword.

**The good shape, worth copying.** The sanitizer moved from a private `_sanitizeRecipe` (which
`create` called into a local and then rebuilt from the UNSANITIZED entity — dead for five months)
to the `toFirestore(Recipe)` override. `BaseFirebaseRepository` serializes through that override at
`:118` (create `set`), `:228` (update `update`), `:292` (createBatch), `:464` (updateBatch), so one
line covers the whole base-class write surface. The second writer — `OfflineSyncManager`, which
`setDocument`s straight at `users/{uid}/recipes` and never touches the repository — calls the
shared function itself. Enumeration re-derived independently: `FirestoreCollections.recipes` +
the literal has three further writers (`rating_statistics` denormalize `.update()`,
`family_rating_service` `txn.update`, `addIncrementCookCountToBatch`, plus the tag-operations
batches), all field-scoped and text-free, so the coverage claim holds for TEXT. The code comment
says "the complete set for this collection", which is broader than what was verified — filed Low.

**Q1, `shared_content` writer enumeration.** Complete for recipe-derived text: exactly two —
`FirebaseSharedRecipeRepository.toFirestore` (`recipeTitle`/`recipeDescription`, applied on the MAP
because `SharedRecipe.copyWith` exposes neither) and
`recipe_sharing_manager._writeToSharedRecipesCollection` (`title`/`description`, different key
spellings, predates the ticket). `recipe_service_adapter.dart:174` looks like a third and is a
DELETE sweep on `originalRecipeId`. The collection's MENU and SHOPPING-LIST legs
(`social_menu_operations`, `shopping_social_share_module`, `firebase_shared_menu_repository`,
`firebase_shared_shopping_repository`) write denormalized user text into the same collection
unsanitized — pre-existing, out of BUT-1819's scope, named rather than fixed.

**Q2, does sanitize-before-validate change which writes are ACCEPTED? No, and the comment says it
does.** `validateRequiredFields` (`permission_validation_mixin.dart:290-292`) tests `containsKey`
only, and `RecipeCore.toFirestore()` (`recipe_unified.dart:694`) emits `'title'` unconditionally —
so a title of pure control characters passes identically before and after and still stores as `''`.
The reorder is harmless and defensible on "validate what you write" grounds; the comment's stated
defect-and-remedy is not real. Medium, non-blocking. This is the third instance in the repo of the
lessons-digest class "a comment is an UNTESTED ASSERTION", and the second where the assertion was
about a validator the author had not opened.

**Q3, `_enforceShareCap` / `validateSelfOperation` on the RAW entity, before the sanitize.** Right
order, and provably immaterial: `sanitizeRecipeText` touches `title`/`description`/`sourceUrl`/
`updatedAt`; `Recipe.copyWith` preserves `socialData`, `type`, `realtimeData`, `offlineData` via
`_sentinel` and `createdBy` likewise, and `RecipeCore.copyWith` passes `createdAt` straight through.
So the guarded fields cannot move. Raw-first is also the better default — an authorization decision
should not be taken on a transform's output. Note this is the MIRROR of the shopping-list rule
(escalation guard must run on the payload actually written): that rule bites when the transform CAN
change the guarded fields; here it provably cannot. Nothing pins the coupling, so a future
`sanitizeRecipeText` that touched `socialData` would silently invalidate the cap guard — recommended
a one-line assertion. Low.

**Q4, weakenings: none.** Every render/launch change narrows (`isSafeExternalUrl` is a positive
allowlist gating both the DRAW and the LAUNCH; the overflow menu entry is hidden, the source row
degrades to plain text, `linkified_text` routes through the shared helper as defence in depth). The
three near-misses: (a) `update()` no longer restamps `updatedAt` — the old `_sanitizeRecipe` used a
bare `copyWith` so every update advanced it; the new explicit pass-through means callers that build
`Recipe(core: recipe.core, …)` by CONSTRUCTOR — `recipe_member_manager.addMember/removeMember`,
`recipe_sharing_manager._grantAccessOnReshare` — no longer advance it, and `watchRecipes`/
`loadMoreRecipes` sort and page on `core.updatedAt`; unremarked and untested either way (Medium).
(b) `sanitizeUrl` also runs `normalizeHomoglyphs`, so activating the sanitizer means a `sourceUrl`
containing Cyrillic is silently rewritten to a DIFFERENT URL — not covered by the deviation, which
covers only the `data:` blanking (Low). (c) `imageUrls` is unsanitized and rides into
`shared_content` as `imageUrl`/`recipeImageUrl` from imported data; rendered as an image, not a
link, so no launch vector today (Low, noted so it is a known gap rather than an assumed-covered one).

**The `data:` blanking is an ACCEPTED DEVIATION as of this commit** (`BUT-1819`, both files), and
the first pass's counter-argument is recorded verbatim inside it: `isSafeExternalUrl` is a positive
allowlist that strictly dominates the `sanitizeUrl` blocklist for the threat it was aimed at, so
the blocklist's only remaining NET effect is destroying Swedish provenance sentences, and anchoring
to `^\s*(javascript|data|vbscript):` would keep 100 % of the scheme protection at zero cost. That
needs its own ticket, its own sweep of `sanitizeUrl`'s other callers, and Malin's call. Do not file
it as a bug again — the argument is already written down where the next reviewer will find it.

---

### 2026-08-12 — BUT-1693 household allergen sharing: the data layer, reviewed before it has a caller

Fileset: `lib/models/household_allergen_share.dart`, `lib/repositories/interfaces/
household_allergen_share_repository.dart`, `lib/repositories/firebase/
firebase_household_allergen_share_repository.dart`, its unit test,
`FirestoreCollections.householdAllergenShares`, and the `SocialModule` registration.
Controller sign-off the same day in `docs/legal/dpia-household-allergen-sharing.md`.
Top-level `household_allergen_shares`, one doc per member per household, id
`{householdId}_{userId}`, scoped to the SYMMETRIC `households/{id}` roster. The
`firestore.rules` block is deliberately in the NEXT commit (another session holds that file
for BUT-1482's `configRevision` allowlist fix — verified in `git diff`, it is unrelated).

**Sequencing verdict: agreed, and the reason is mechanical.** No rule block ⇒ catch-all
default-deny ⇒ the collection cannot be written or read by any client, so nothing can land in
the gap. The cost is that every fake-backed test in this commit describes behaviour that
production cannot yet perform, and two of them describe behaviour production will REFUSE once
the obvious rule shape lands (below).

**The three findings that were local to this commit (blocking):**

1. `HouseholdAllergenShare.fromMap(String id, Map data)` accepts the doc id and never uses it;
   `householdId`/`userId` come from the body, and `id` is recomputed from them. `getByHousehold`
   attributes each share to its BODY `userId`. The rule most likely to be written pins the PATH
   (the model's own comment says "the rules can derive ownership from the path"), which leaves
   the body unconstrained — so a legitimate household member can write their own doc carrying a
   peer's `userId` and the aggregate reads a forged declaration for that peer, retiring their
   BUT-1663 four-allergen floor. That is an allergen-safety failure reachable by a member, not
   an outsider. Compounding: `isValidConsent` requires only `consentGranted && consentVersion
   .isNotEmpty && consentGrantedAt != null`, and `SerializationUtils.safeString` defaults to
   `''`, so a doc with NO `userId` is a "valid declaration" belonging to nobody.
2. `update()` full-`set()`s `toFirestore(entity)`, consent triple included, from a
   caller-supplied entity. `copyWith` deliberately refuses to change the consent fields, but the
   public `update(entity)` takes any object — the test's own `_share()` helper builds a fresh one
   — so an ordinary "I edited my allergies" write re-dates `consentGrantedAt` and can rewrite
   `consentVersion`. `validateUpdatePermission` has ALREADY read the stored doc two lines
   earlier; carrying its consent triple forward is free.
3. `SocialModule` registers the repository without `auditRepository:` (every other audited
   repository in `core_module`/`content_module` passes `container<FirebaseAuditRepository>()`),
   so every `logPermissionCheck` here is console-only — while the interface doc comment says
   "The grant/withdrawal events live in the audit log, which is what Art. 7(1) needs retained"
   and the DPIA's R5 mitigation rests on exactly that sentence. Second, independent hole: the
   730-day consent bucket in `purgeExpiredAuditLogs` is selected by the `operation` string
   starting with `consent_`, and these rows are spelled `create`/`update`/`delete`, i.e. the
   180-day general bucket. Both halves of R5 are unimplemented, asserted as implemented.

**What must be true of the rules commit (handed to `firestore-rules-tester`):**

- The `diner_profiles` precedent the DPIA §1.6 names (`allow read: if isHouseholdMember(
  resource.data.householdId)`) dereferences `resource.data`, so a `get()` on a NONEXISTENT doc
  is `permission-denied`, not `exists == false`. Copying it verbatim kills `getOwn()`'s
  "has not shared yet" path — the commonest call in the feature — plus `validateUpdatePermission`'s
  `if (!doc.exists) return false` and `validateDeletePermission`'s idempotent-withdrawal branch.
  All four read green on `fake_cloud_firestore`. The own-doc read must be decided from the PATH
  (`shareId == householdId + '_' + request.auth.uid`), not from `resource.data`.
- `diner_profiles` also gates DELETE on membership. Copied here, a member removed from the
  household could never erase their own Art. 9 data, and no one else may (the repository's
  `validateDeletePermission` is ownership-only, correctly — but the class doc comment says
  "write — ownership AND membership", which is the wrong summary of the one case that matters).
  DPIA §2 and R7 both promise erasure on removal. Delete must be OWNER-ONLY, membership-free.
- Consent immutability + `is bool` on `consentGranted` (`safeBool` accepts the STRING `'true'`)
  + a `consentVersion` allowlist. Note `consentGrantedAt` ships as an ISO8601 STRING
  (`toIso8601String()`), so the rule cannot type-check it or pin it to `request.time` at all.

**Forward obligations, none of which exist yet and all of which the DPIA already promises:**
`deleteFamilyData` in `account-deletion-cascade.ts` handles `households`/`diner_profiles`/
`family_ratings` and not this collection (sole-member teardown deletes the household doc and
orphans the shares permanently; the remaining-members branch leaves a deleted user's health data
readable by the household). The collection carries a `userId` field, so it is one line in
`probeResidualData`'s simple loop. Export: DPIA decision 5 says the requester's OWN share and
consent record only — `FamilyExportManager` is the place. Leaving/being removed from a household
needs a server-side sweep; `purge-dormant-family-data.ts` already does exactly this shape for
`family_ratings` whose rater left the roster (BUT-1600). And DPIA R4's "the settings document and
the share move in ONE atomic write" has no seam in this data layer — `createBatch` is
single-collection, and the model's `updatedAt` comment asserts the atomic batch as existing fact.

**One vacuous test, worth the note.** `'an edit REPLACES the stored list rather than merging it'`
cannot fail: `toFirestore()` emits a FIXED key set, so `update()` would write the same nine keys
and replace the array wholesale just as `set()` does. Swapping the implementation back to `update()`
leaves it green. The override's stated justification ("a merge would leave the old value in place
and keep filtering on a preference they have retracted") is therefore wrong for this serializer —
the real (small) difference is that a no-merge `set()` also strips foreign/legacy keys, and that
`update()` throws on a missing doc.

### 2026-08-12 — BUT-1693 re-review: the three blocking items close, and what a per-row skip costs

Re-review of the same fileset after the fix round (`household_allergen_share.dart`, its repository +
interface, both test suites, the one-line DI change). **All three blocking items are closed**, and
each closure is non-vacuous — reverting the guard reddens the named test.

**B1 (body-over-path forgery).** The binding sits in the REPOSITORY's `fromFirestore`, not in
`fromMap`: `HouseholdAllergenShare.fromMap` still ignores its `id` argument (deliberately — the
model test builds documents by hand), and the repository compares the DERIVED id
(`'{householdId}_{userId}'`) against `doc.id` and throws `FormatException`. That is the right seam:
`fromFirestore` is the only path a stored document takes into the app. `isValidConsent` now also
demands non-empty `householdId`/`userId`, closing the `safeString`-defaults-to-`''` hole. The
forged-row test seeds `hh-1_forged` carrying Johan's body while Johan is a real member, so removing
the check re-admits him and the test reddens. Worth recording: **every `SerializationUtils` helper
this model uses is total** (`parseDateTimeValue` returns null on garbage, `safeList` swallows
per-item converter throws), so `on FormatException` is an exhaustive catch here, not a partial one —
verify that before copying the pattern to a model that uses `requiredString`/`requiredDateTime`.

**B2 (consent rewritten by an ordinary edit).** `update()` reads the stored doc once, checks
ownership/household/membership against it, and writes `entity.withStoredConsent(stored)`. The class
declaration line does NOT mix in `BatchOperationsFirebaseRepository`, so `updateBatch`/`deleteBatch`
do not exist on it and the usual "the override does not cover the batch path" finding does not
apply — `createBatch` (which DOES live on the base class) is overridden. **The open door is
`create()`**: `super.create()` is an unconditional `set()`, and the interface comment names create as
the re-grant path. Two consequences. (a) A stale client can re-grant under an OLDER
`consentVersion` and re-date `consentGrantedAt`; the cheap client guard is
`entity.consentVersion == currentConsentVersion` on create. (b) **Firestore evaluates a `set()` on an
EXISTING document as an UPDATE**, so the rules condition already recorded in the plan
("`consentGrantedAt` immutable across an update") would deny every re-grant. The rules commit has to
decide this explicitly — a `consentGranted` false→true transition exemption, a delete-then-create, or
a distinct `grant()` method — or the feature ships with a revoke that cannot be undone.

**B3 (the audit claim).** DI now passes `auditRepository: container<FirebaseAuditRepository>()`;
`FirebaseAuditRepository` is registered in `CoreModule` (app scope) and get_it resolves it through
the user scope, the same way the sibling registrations reach `AuthRepository`. The interface comment
no longer claims a complete Art. 7(1) trail. **New defect the wiring exposes:**
`PermissionValidationMixin.logPermissionCheck` derives `resourceType` from the FIRST SEGMENT of the
`resource` string, and the base class spells that `'${T.toString()}/$docId'`
(`HouseholdAllergenShare`) while this subclass's `update()` spells it `'$collectionName/${entity.id}'`
(`household_allergen_shares`). So create/read/delete and update land under two different
`resourceType` values, and any query that reconstructs "what happened to this consent" finds half of
it. Whenever a subclass hand-rolls a `logPermissionCheck` call, copy the base class's resource
spelling verbatim.

**The read path's skip-and-continue: which way each field fails.** `getByHousehold` now parses per
document and drops an unusable row, a consent-less row, and a row whose member has left the roster.
For the ALLERGEN union that fails SAFE — a dropped member has no share, and BUT-1663's floor covers
them — but only if the aggregate that consumes this iterates the ROSTER and treats "no share" as
floor, rather than iterating the returned list. `includeUnknownInMenu` is the field that fails the
other way: the aggregate AND-folds it, so dropping a member who shared `false` LOOSENS the result.
Both are conditions on the aggregate commit, not defects here (no consumer exists yet — grep finds
the type in nine files, none of them a service or viewmodel). The sharper hole is the roster source
itself: `currentMembers` comes from `_householdRepository.read(householdId)` and degrades to
`const <String>{}` when that returns null, which silently discards EVERY share and returns `[]` —
indistinguishable from "nobody shared", and flatly contradicting the plan's own acceptance criterion
("a failed query is not 'nobody shares'"). An empty roster is also self-contradictory, since
`isMember` just returned true for the caller. Same shape as the keep-set principle: **a roster used to
FILTER user data must refuse to run on an empty/absent roster**, not silently drop everything.

Cost note: `getByHousehold` reads `households/{id}` TWICE — once inside `isMember` (`_loadRaw`) and
again via `read()` for the roster. One read serves both; `read()` already denies a non-member through
`validateReadPermission`.

Smaller items, all non-blocking. `getOwn` calls `fromFirestore` WITHOUT the skip, so a forged own
document throws out of the commonest call in the feature (the one whose null answer keeps the floor
on) — fail-loud is defensible but has to be a decision, not an asymmetry. The
"cannot re-point an existing share at another household" test drives `validateUpdatePermission`,
which production's `update()` override never calls; and inside `update()` the
`entity.householdId == stored.householdId` conjunct is UNREACHABLE, because `entity.id` is derived
from the payload's `householdId`, so the doc read is always at the payload's household and
`fromFirestore` has already pinned stored-to-path. The real protection against re-pointing is
create-time `isMember(entity.householdId)`, which is tested. Warning logs interpolate `doc.id`
(a raw uid) — device-local only, since `AppLogger.warning` writes to `developer.log` and never
reaches Crashlytics, but the file already imports `maskedUserId`. And the collection still has NO
`firestore.rules` block, so it is default-denied in production and every test here is
`fake_cloud_firestore` — proving query shape, never access.

### 2026-08-12 — BUT-1693 gate RE-READ of the household-allergen-share data layer (final bytes)

Second pass over `lib/models/household_allergen_share.dart`,
`lib/repositories/firebase/firebase_household_allergen_share_repository.dart`,
`lib/repositories/interfaces/household_allergen_share_repository.dart`,
`lib/core/di/modules/social_module.dart` and the two suites. Verdict: pass, 0 blocking.
`flutter analyze` on the four production files clean (85s); the two suites 35/35 green, run
by me, not taken on report.

**Process note that decided the review.** The repository impl and its test file were rewritten
by a parallel formatter/session at 16:31:18 and 16:31:52 — mid-review. The tell was the TEST
RUN listing four test names that were not in the bytes I had read (`getOwn returns the member
their own share`, `the query is scoped to the household it was asked for`, `an absent share can
only be deleted at your OWN id`, `a member removed from the household can no longer EDIT their
share into it`). Re-read both, then `stat`-ed every file in the fileset before and after the
analysis. Generalisable: when a file may be written under you, a test/lint run's own OUTPUT is
a cheap freshness oracle — compare what it enumerates against what you read — and `stat -c %y`
before writing the report is cheaper than re-reading six files.

**What the previous round's fixes actually look like in the final bytes (all verified, all
sound):** create refuses an existing id via a DIRECT `collection.doc(id).get()` (not the base
`exists()`, which swallows); the grant path requires `consentVersion == currentConsentVersion`;
`createBatch` re-applies both; `update()` carries the stored consent triple forward via
`withStoredConsent(stored)` and full-`set()`s; the hand-rolled audit row is spelled
`'HouseholdAllergenShare/$id'`, matching the base class's `'${T}/$docId'`; a body/path mismatch
in `getByHousehold` now writes a denied `logPermissionCheck` row and skips the ROW rather than
the collection; `readAll`/`watchAll` throw `UnsupportedError`; `read`/`readCacheFirst` are
consent-filtered. `SocialModule` passes a non-optional `auditRepository`
(`FirebaseAuditRepository` is registered in `CoreModule.configure`, app scope, so the user-scope
resolve falls through — checked, not assumed).

**Non-blocking findings filed (all Medium or below, none reachable today because no production
code calls this class and the collection has no rules block):**
1. `validateDeletePermission` parses the BODY on the exists-branch, so `fromFirestore`'s
   path/body identity check throws before the ownership test — a corrupt or forged row at the
   user's own path cannot be deleted by `revoke()`. Art. 17 fails in the wrong direction. Fix:
   decide from the path (`resourceId.endsWith('_$userId')`) or catch `FormatException` and fall
   back to it. Promoted to a principle under the deterministic-doc-id bullet.
2. Production/fake divergence in the read contract. `firestore.rules:965-968` gates
   `households` read on `request.auth.uid in resource.data.memberUserIds`, which dereferences
   `resource.data` — so for a NON-member, and for a household doc that does not exist,
   `FirebaseHouseholdRepository.isMember` → `_loadRaw` → `get()` is DENIED and throws. Both
   `if (!isMember) return []` and the `RepositoryException('household-roster-unavailable')`
   branch below it are therefore fake-only, and the interface's "Returns empty when the caller
   is not a member" is a promise production does not keep. Safe direction (loud), but the
   consumer commit will be written against it. Promoted to a principle under the
   fake-vs-`permission-denied` testing bullet.
3. Cost: `getByHousehold` reads `households/{hid}` TWICE (`isMember`, then `read`) per call, and
   once the planned `list` rule lands, `isHouseholdMember(resource.data.householdId)` adds one
   rules `get()` per returned document. The query also carries no `.limit()` — bounded only by
   the (future) rule's id pinning. One read can serve both ends if the code branches on the
   thrown denial instead of on a bool.
4. Two parallel implementations of the update rule: `update()` inlines
   stored-owner + same-household + `isMember`, and `validateUpdatePermission` implements the
   same triple; only tests reach the latter now (no `BatchOperationsFirebaseRepository` mixin,
   so no `updateBatch`). Equivalent today; the inline copy exists to reuse the single stored
   read. Drift risk only.
5. `update()` writes the payload's `updatedAt` verbatim, and `toFirestore()` OMITS it when null,
   so a caller that forgets it silently erases the staleness field DPIA R4 rests on. Right place
   to fix is the atomic-write seam (plan condition 5), which does not exist yet.
6. Inherited `exists()`/`count()` stay unfenced (no consent filter, no household scope);
   `count()` would aggregate every household's Art. 9 rows. No callers; rules will deny.

**Cross-file claims in comments, checked rather than trusted:** `household_service.dart:85-91`
does catch `StateError` from `firstWhere` (so the "not a StateError" reasoning holds); the
catch-all `match /{document=**} { allow read, write: if false; }` is at `firestore.rules:2618`;
`Household.memberUserIds` is a getter derived from the same `members` list `isMember` reads, so
the roster filter and the membership probe cannot diverge; household ids are `Uuid().v4()` and
Firebase uids are alphanumeric, so the `endsWith('_$userId')` comment's "neither contains '_'"
is true; every serializer `HouseholdAllergenShare.fromMap` uses is TOTAL (`safe*` only, no
`requiredString`/`requiredDateTime`), so `on FormatException` catches exactly the deliberate
identity throw and nothing else.

**Conditions still riding on the rules/service/cascade commits (unchanged, H1–H5 in
`tasks/butlery-1693-household-share-plan.md`):** own-document `get` and `delete` must be decided
from the PATH, or `_assertNotAlreadyShared`, `update`'s existence read and an idempotent
`revoke` all hit `permission-denied` on a non-existent doc; the consent-immutability pin is now
free (see the create-side closure); erasure/export/probe/reset wiring; the consumer must iterate
the ROSTER, not the returned list.

### 2026-08-12 — BUT-1693 household allergen shares: third pass, final bytes (index held the defect)

Gate re-read of the eight-file data-layer commit on tree bytes
`10006e19e48c28d8f1157bb72bdfdc73` (repository impl). All eight opened with `Read`; base class,
`permission_validation_mixin`, `serialization_utils`, `firebase_household_repository`,
`firebase_diner_profile_repository`, `firestore.rules` and the plan file opened as corroboration.

**Verdict: pass, 0 blocking, SCOPED TO THAT MD5** — because the index did not hold it. `git show
:lib/repositories/firebase/firebase_household_allergen_share_repository.dart | md5sum` =
`d4f405851cc4bc36f88df0c6c1baf524`, whose `validateDeletePermission` is the previous round's
body-reading version (`final doc = await collection.doc(resourceId).get(); if (!doc.exists)
return resourceId.endsWith('_$userId');` — i.e. `fromFirestore`'s identity check throws before the
ownership test on exactly the corrupt/forged row a member most needs to erase, Art. 17). Model and
repository test were `AM` too, so the erasability test would not have shipped either. Committing the
staged set would have shipped the reviewed round's defect under a pass. Also present in the tree and
NOT part of this commit: `?? test/unit/security/rules_allowlist_drift_test.dart` (the
`hasOnly` allowlist-drift guard, a different initiative) and 175 unstaged lines in `firestore.rules`
— so the re-stage has to be by explicit pathspec, never `git add -A`.

**Confirmed on the final bytes, each against the source rather than the diff.**
- Erasure from the PATH: `validateDeletePermission => resourceId.endsWith('_$userId')`, and
  `BaseFirebaseRepository.delete` (`:238-258`) never calls `fromFirestore`, so the erasure path
  genuinely cannot reach the identity check. Cross-user delete is impossible even if a
  `householdId` DID contain `_`: `H_victimUid` ends with `_attackerUid` only when
  `victimUid == attackerUid`, since auth uids carry no underscore — the shipped comment's
  justification is sound and in fact stronger than it claims.
- `updateBatch` does not exist on this class (it is on `mixin BatchOperationsFirebaseRepository`,
  `base_firebase_repository.dart:442`, not mixed in); `createBatch` (`:267`, `batch.set`) is the
  only `create()`-bypassing sibling and carries both guards.
- `_assertNotAlreadyShared` reads the doc DIRECTLY, not base `exists()` (`:320-331`, swallows and
  answers false).
- The `on FormatException` per-row skip is exhaustive for the identity check because every
  serializer the model uses is total (`safeString`/`safeStringList`/`safeBool`/`safeDateTime`) —
  ONE exception found: `parseDateTimeValue` (`serialization_utils.dart:117`) casts
  `value['seconds'] as int?`, so `consentGrantedAt: {seconds: 'x'}` throws `TypeError` past the
  catch and takes the whole household read down. Fail-LOUD, so safe; it just falsifies the
  "one bad row cannot take the household down" comment.
- Audit resource spelled `'HouseholdAllergenShare/${entity.id}'`, matching the base's
  `'${T.toString()}/$docId'`, so the resourceType split does not fork one document's history.
  The skip-path audit row cannot throw: `logPermissionCheck` persists via
  `unawaited(...).catchError` inside a `try` (`permission_validation_mixin.dart:417-458`).
- DI now passes `auditRepository` (`social_module.dart:167-173`; `FirebaseAuditRepository`
  registered `core_module.dart:190`, resolved exactly like the sibling's `container<AuthRepository>()`),
  which closes the long-standing "SocialModule passes none" gap for this repository only.
- `firestore.rules` really has no block for `household_allergen_shares` in the working tree, so
  the class's "inert until the rules commit" comment is true today; and the class doc's claim about
  `diner_profiles` is accurate (`firebase_diner_profile_repository.dart:156-164` gates delete on
  membership after a body read).

**Findings (none blocking).** (1) MEDIUM — the two conditions the handoff said were "recorded
against the rules/service commits in the plan" are NOT in
`tasks/butlery-1693-household-share-plan.md`: `grep getByHousehold tasks/ docs/` is empty, and the
five carried conditions cover `getOwn`'s rules mechanism only. So the interface's
"Returns empty when the caller is not a member" (`household_allergen_share_repository.dart:13`)
is still a promise no production path keeps — `isMember` → `FirebaseHouseholdRepository._loadRaw`
issues an unguarded `.get()` on `households/{id}`, which denies for a non-member — and the double
household read (`:273` then `:285`) is recorded nowhere. (2) MEDIUM — `getOwn` throws a bare
`FormatException` out of a repository by design, with no mapping arm anywhere yet. (3) LOW — the
`where('householdId')` query has no `.limit()`; bounded only once the rules pin the body's
`householdId` to membership. (4) LOW — raw uid inside `doc.id` in two log lines (`:316`, `:331`)
while the same file masks it at `:90`/`:275`. (5) LOW — `readCacheFirst` has no test of its own.
For the rules commit, one demand is missing from the plan's item 3: pin `consentGrantedAt` to
`request.time` on CREATE (item 3 only makes it immutable across update), or a client can backdate
the Art. 7(1) evidence it is trusted to write.

### 2026-08-12 — BUT-1693 test-round re-review: the intentional-asymmetry guard, proven by mutation

Fileset (index md5 == tree md5 for all five, checked before reading, so the verdict is scoped to
the bytes reviewed): `lib/models/household_allergen_share.dart` abe20d46…,
`lib/repositories/firebase/firebase_household_allergen_share_repository.dart`
10006e19e48c28d8f1157bb72bdfdc73, `lib/repositories/interfaces/household_allergen_share_repository
.dart` ae4b0418…, and the two new test files. Only the tests moved since the previous pass; the
staging inversion that round found (index holding the body-reading `validateDeletePermission`,
tree holding the path-only repair) is resolved — both now hold the path-only version.

Two additions judged:

(1) `withdrawal > a member removed from the household can still erase their own share`. This is
the guard for a deliberate asymmetry — delete is ownership-only, create/update also require
membership — which the previous round argued for and which nothing but a comment defended.
MUTATION-PROBED: `validateDeletePermission` changed to
`resourceId.endsWith('_$userId') && await _householdRepository.isMember(resourceId.substring(0,
resourceId.lastIndexOf('_')), userId)` (the exact "harmonise it with its siblings" edit). Result:
exactly ONE red, the new test; the three sibling withdrawal tests stayed green because their
actor is still on the roster, i.e. the new test is the only thing standing between a future
tidy-up and an un-erasable Art. 9 document. File restored from backup and md5-verified
(`md5sum -c` OK). Full suite 39/39 green, re-run here, not taken from the handoff.

(2) `toPreferences carries the three filtering fields through unchanged`. Allergens vs dietary are
seeded with distinct values, so a swapped-set mutant dies. `includeUnknownInMenu` is asserted at
`false` — which is ALSO `fromMap`'s fail-safe default for an absent key, so the fixture's explicit
`false` adds nothing: a `toPreferences` that hardcodes `false`, or a `fromMap` that drops the
field, survives the whole 39-test suite (no test anywhere asserts a `true` survives parse; the
repository fixture sets it to `true` and never asserts it). The mutant that IS caught is the
dangerous one (hardcoded `true` would discard a member's "exclude unverified recipes" caution and
loosen an AND-fold), and the surviving mutants all fail toward over-filtering, so this is a LOW
test-strength note, not a blocker. Remedy: assert the non-default value at least once.

Carried conditions verified LITERALLY IN the plan this time, not asserted: `tasks/butlery-1693-
household-share-plan.md` items 6 (the interface's "returns empty for a non-member" is a promise
production will not keep, plus `getOwn`'s escaping `FormatException`) and 7 (double `households/
{id}` read + missing `.limit()`), and `consentGrantedAt == request.time` on CREATE for the rules
commit at :281. Still true and still not-yet-code: the interface sentence at
`household_allergen_share_repository.dart:13` is wrong in production terms until the service
commit maps the denial — recorded, so not re-filed.
