# Privacy / Data Protection Officer (GDPR) — scan findings

Role #5. Two passes. NEW (not-yet-ticketed) actionables only — deduped against
`tasks/_scan_dedup_titles.txt`, `.claude/linear-tracker.json`, accepted-deviations,
and the dossier's own watch-items (notification-cascade probe gap, audit-log dual-source
drift, audit-log export 10-page silent truncation are ALREADY in the map — excluded).

---

### Gate UGC and data flows on the unused socialFeatures / dataProcessing consent toggles (or remove the toggles)
- type: security  area: account  priority: high
- pass: 1
- finding: Three of the seven consent purposes have a user-facing toggle but ZERO server/client enforcement. `analytics` (main.dart:203, search_module.dart:154, analytics_service.dart:108), `aiProcessing` (llm_service.dart:58), and `pushNotifications` (fcm_service.dart:204, notification_service.dart:706) are each genuinely gated. But `socialFeatures`, `dataProcessing`, and `marketing` appear ONLY in the model + consent UI — never checked before the corresponding processing runs. `socialFeatures` is the sharpest: the app actively ships friends/sharing/comments/ratings, the toggle defaults to false (user_consent.dart:120,197), the user can revoke it (consent_viewmodel.dart:206), yet no social write path reads it.
- why: Art. 6(1)(a) requires lawful basis per processing purpose. Presenting a consent toggle that does nothing is worse than no toggle — a user who revokes "social features" still has comments/shares/friend data processed, which is a misleading-consent finding (IMY has fined for exactly this). `dataProcessing` ungated is defensible if it overlaps essentialServices; `marketing` ungated is acceptable for now (no marketing channel exists). socialFeatures is the actionable gap.
- fix: Either gate the social write paths (recipe_comments / shared_content / social_requests create) on `ConsentService.checkSafely(_, ConsentPurpose.socialFeatures)` fail-closed, OR remove the socialFeatures/marketing toggles from `consent_management_view.dart:304` until a real gate exists. Evidence: lib/models/account/user_consent.dart:99,111; lib/viewmodels/account/consent_viewmodel.dart:148,206; grep `ConsentPurpose.socialFeatures` in lib/ → only model + UI, no service.

### Verify a Firestore TTL policy backs deletion_audit_logs.expireAt — purgeExpiredAuditLogs never touches that collection
- type: bug  area: backend  priority: medium
- pass: 1
- finding: `request-account-deletion.ts:309-319` writes each deletion record to the `deletion_audit_logs` collection with a hardcoded 180-day `expireAt` timestamp and comments "180-day TTL via expireAt". But the only audit purger, `purgeExpiredAuditLogs` (audit_logs/purge-expired.ts), queries ONLY the `audit_logs` collection (line 64), not `deletion_audit_logs`. The legacy `cleanup-audit-logs.ts` similarly targets `audit_logs`. So `deletion_audit_logs` retention relies entirely on a native Firestore TTL policy on the `expireAt` field — and no TTL policy is declared in `firebase.json` / `firestore.indexes.json` (TTL is GCP-console-configured, not in repo, so it cannot be confirmed from code).
- why: Each row holds `userId`, `emailHash`, free-text deletion `reason`. If the console TTL policy was never created (nothing in the repo proves it was), these PII-linked records of *deleted* users live forever — Art. 5(1)(e) storage-limitation breach, and ironically the residue is the deletion audit of people who exercised erasure. The 180-day comment creates false confidence that a CF or policy enforces it.
- fix: Confirm a Firestore TTL policy exists on `deletion_audit_logs.expireAt` in the prod project; if not, create it (or add `deletion_audit_logs` to `purgeExpiredAuditLogs`). Evidence: functions/src/account/request-account-deletion.ts:72,309-319; functions/src/audit_logs/purge-expired.ts:64 (queries `audit_logs` only).

### Fix general-category audit-log purge starvation behind retained consent rows
- type: bug  area: backend  priority: medium
- pass: 2
- finding: `purgeAuditCategoryWithDb` (purge-expired.ts:77-88) fetches the oldest `timestamp < cutoff limit 10000` docs, THEN filters by category client-side. For the "general" run it keeps only NON-consent docs. Because consent events are retained 730d but general events only 180d, over time the oldest slice of `audit_logs` becomes increasingly dominated by long-lived `consent_*` rows (consent saves + every `consent_age_verification` signup audit). Those consent rows fill the 10k query window, so the post-filter "general" set can be far below 10k even when many general docs past the 180d cutoff remain unpurged. The `truncated` flag (line 149) is computed from `generalDeleted >= MAX_DOCS` (post-filter count), so it under-reports: real truncation is invisible.
- why: General audit logs (Art. 5(1)(c) minimisation, 180d) silently outlive their retention window, never getting purged because consent rows starve the query. Accumulates unbounded → both a minimisation breach and a cost creep.
- fix: Split the query by an indexed category discriminant rather than fetching-then-filtering — e.g. store an `isConsent`/`retentionTier` boolean on write and query `where('retentionTier','==','general').where('timestamp','<',cutoff)`, or run the general purge with a composite filter that excludes consent ops at the query level. Evidence: functions/src/audit_logs/purge-expired.ts:77-88, 149.

### Export Art.15 bundle omits reports, pings, realtime_recipes that the deletion cascade erases
- type: bug  area: account  priority: high
- pass: 2
- finding: The export orchestrator `DataExportService.exportUserData` enumerates exactly 24 sections (data_export_service.dart:141-172). Three PII collections the deletion cascade *does* erase are never exported, so the access bundle is not a superset of erased data: `reports` (user's own moderation reports incl. free-text reason; cascade `deleteUserReports`), `pings` (cascade `deletePingsByUser`), `realtime_recipes` (cascade `deleteRealtimeRecipes`). No `exportReports`/`exportPings`/realtime export method exists anywhere under lib/services/account/.
- why: Art. 15(1) entitles the subject to access ALL personal data processed. The cascade is the de-facto per-user PII inventory; any collection it deletes but the export omits is a provable right-of-access gap.
- fix: Add export sections for `reports` (reporterId==uid), `pings` (fromUserId==uid), and `realtime_recipes` (userId==uid). Evidence: lib/services/account/data_export_service.dart:141-172 (no entries); functions/src/account/account-deletion-cascade.ts deleteUserReports/deletePingsByUser/deleteRealtimeRecipes.

### Wire the implemented-but-dead exportGroupWeeklyMenuPlans into the export orchestrator
- type: bug  area: account  priority: medium
- pass: 2
- finding: `ContentExportManager.exportGroupWeeklyMenuPlans` is fully implemented (content_export_manager.dart:439-470) and the cascade scrubs the user from `group_weekly_menu_plans` participants, but the orchestrator never calls it — only `exportWeeklyMenuPlans` is wired (data_export_service.dart:151). The user's group/shared weekly-menu participation rows are silently excluded from the Art.15 bundle despite the capability existing.
- why: Dead export code = data subject's group-menu participation data not delivered though it is processed and the method to export it already exists.
- fix: Add `exportGroupWeeklyMenuPlans` to the orchestrator futures map. Evidence: lib/services/account/export/content_export_manager.dart:439; lib/services/account/data_export_service.dart:141-172.

### Surface silent truncation for notifications (500-cap) and fix decorative pantry truncation flag
- type: bug  area: account  priority: low
- pass: 2
- finding: Two non-audit-log export truncations escape the metadata aggregation. (a) `PreferencesExportManager.exportNotifications` (preferences_export_manager.dart:42-85) hard-caps at last 500 with a static note (line 66) but sets NO `truncated: true` flag; the orchestrator only aggregates sections where `truncated == true` (data_export_service.dart:201), so notification truncation never appears in `export_metadata.truncated_collections`. The 500 cap is hardcoded, not in the limit registry. (b) `ContentExportManager.exportPantryItems` (content_export_manager.dart:343-368) computes `pantryLimit` and flags `truncated` on `items.length >= pantryLimit` (line 362) but calls `_pantry.exportAllByUser(userId)` with NO maxDocuments (line 350) — unlike every sibling — so the flag is keyed on a limit that is never applied and fires only by coincidence.
- why: Art. 15 completeness — silent, unflagged truncation of received-notification PII means the user has no machine-readable signal their bundle is incomplete; the pantry flag is unreliable.
- fix: Add `truncated: true` to the notifications section when capped (and register the 500 cap), and pass the limit through to `exportAllByUser` for pantry. Evidence: preferences_export_manager.dart:66; data_export_service.dart:201; content_export_manager.dart:350 vs 362.

---
COVERAGE: Pass 1 (erasure cascade / retention / consent / PII scrubber) — found 1 new high consent-enforcement gap (socialFeatures/marketing toggles unenforced) and 1 retention-correctness gap (deletion_audit_logs may have no purger/TTL); the cascade itself is thorough, storage wipe correctly covers users/{uid}/ where cook-snap and comment images actually live, and the client/server PII scrubbers are byte-identical with bidirectional fixture-test enforcement and no LLM-egress bypass (verified clean, no finding). Pass 2 (export completeness / audit-log purge edges / cross-user scrubbing) — found general-category audit purge starvation behind retained consent rows, three erased-but-unexported PII collections, one dead export method, and two unreliable truncation signals.
