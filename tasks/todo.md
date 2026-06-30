# Sprint Backlog

## Plan: BUT-1450 — export notification-analytics collections (Art.15 ⊇ Art.17) — 2026-06-30 (rev. 2)

Sensitive domain (GDPR / user data, data-export). Router tier: **full-panel**. Panel convened
(Privacy/DPO, Legal, Security Architect, Performance Engineer) — all approve-with-conditions, no blocks.

**Malin's decision on the one interpretive point:** the panel's Privacy/DPO + Legal advice to
**anonymise the notification counterparty** is **consciously overridden**. Real-world exports
(Facebook, Google) include the counterparty; Art.15(4) is a *balancing test*, not a blanket
redaction rule; and the export should reflect what the user already saw in the app. So the
counterparty is **included as seen**, not anonymised. This deviation gets an entry in
`.claude/rules/accepted-deviations.md` so future Privacy/security reviews don't re-flag it.

### Problem
The account-deletion cascade `deleteNotificationAnalytics` (functions/src/account/account-deletion-cascade.ts:634)
erases four collections, but DataExportService never exports them — a right-of-access gap
(export must ⊇ erased):
- `notification_history`     WHERE userId == uid
- `notification_batches`     WHERE userId == uid
- `notification_engagement`  WHERE userId == uid
- `notification_delivery`    WHERE senderId == uid  (notifications the user triggered)
- `notification_delivery`    WHERE targetUserId == uid (notifications delivered to the user)

### Approach (mirror the just-shipped BUT-1396 pattern)
Read-only export reads through `FirebaseDataExportRepository` (`_guardSelfExport` →
`validateOwnership`), surfaced via `PreferencesExportManager`, wired into
`DataExportService.exportUserData()`. No deletion change, no firestore.rules change.

### Pre-implementation verification (Step 0 — drives the counterparty representation)
- Read where `notification_delivery` + `notification_history` are written (send-notification.ts
  and friends) to confirm each record's real fields.
- Decide the counterparty representation **from reality**: prefer the human-readable name /
  notification content the user already saw; include a bare internal Firebase UID only if no
  friendlier field exists. Do NOT add expensive bulk UID→name profile lookups for a rare export.
- Confirm these notifications are user-facing (things the user actually saw). If any category
  involves a counterparty the user never saw (hidden third-party telemetry), flag it before
  including — that narrow case is the only place the panel's caution could still apply.

### Files
1. `lib/repositories/firebase/firebase_data_export_repository.dart`
   - +4 `ExportResourceType` enum values (notificationHistory, notificationBatches, notificationEngagement, notificationDelivery).
   - +5 methods via `_queryList`: history/batches/engagement (userId==uid); delivery **sent** (senderId==uid) and **received** (targetUserId==uid) as TWO separate queries (Firestore has no cross-field OR). History sorted `descending` on sentAt/createdAt; explicit `maxDocuments` per collection.
2. `lib/services/account/export/export_pagination_helper.dart`
   - Add `exportLimits` entries: notification_history 2000, notification_delivery 1000, notification_batches 500, notification_engagement 1000. Passed as `maxDocuments` (NOT the 10k default).
3. `lib/services/account/export/preferences_export_manager.dart`
   - +manager methods returning `{data, total_count, truncated, note}`. The delivery method merges sent+received and **includes the counterparty as the user saw it** (human-readable where stored; no anonymisation). In-code comment recording the Art.15(4) balancing call (include, per Malin's decision + industry norm).
4. `lib/services/account/data_export_service.dart`
   - +4 futures keys (notification_history, notification_batches, notification_engagement, notification_delivery).
5. `functions/src/account/account-deletion-cascade.ts`
   - Add the 4 collections to the GDPR probe/coverage array (~line 85) so the export⊇erased invariant stays self-checking.
6. `.claude/rules/accepted-deviations.md` — entry: notification counterparty is exported (not anonymised) — Malin's call, Art.15(4) balancing + industry norm; don't re-flag.
7. `docs/security/` — Art.30 record entry for notification analytics (lawful basis, retention, export treatment = included-as-seen), following the family-data-retention.md pattern.
8. `assets/legal/privacy_policy_en.md` + `_sv.md` — add "notification delivery and engagement records" as a disclosed data category in the Art.15/30 section.
9. `test/unit/services/account/data_export_service_test.dart` — new tests.

### Acceptance criteria (binding)
- AC1. Export output contains keys `notification_history`, `notification_batches`, `notification_engagement`, `notification_delivery`, each scoped to the calling user.
- AC2. `notification_delivery` is two queries (senderId + targetUserId), merged and de-duplicated.
- AC3. The counterparty is **included as the user already saw it** (name / notification content), not anonymised — matching how mainstream exports format interaction data. Bare internal Firebase UIDs are not dumped where a human-readable field exists. (Malin's decision, overriding the Privacy/Legal redaction recommendation.)
- AC4. Each section paginated with its explicit per-collection limit and emits `truncated: true` + a note when capped; `DataExportService` surfaces it in `export_metadata.truncated_collections`.
- AC5. `notification_history` returns most-recent-first.
- AC6. The four collections are added to the deletion-cascade GDPR probe array.
- AC7. The override (include, not anonymise) is recorded in `.claude/rules/accepted-deviations.md`.
- AC8. Art.30 record updated; privacy policy (EN+SV) lists the new data category.
- AC9. Tests prove: each section present; an OTHER user's first-party rows excluded (ownership-negative on userId-scoped collections); empty-safe (keys present, no error, for a user with none); truncation flag when over the cap.
- AC10. No firestore.rules change; `dart analyze --fatal-infos` clean; CF `tsc` clean.

### Negative constraints
- Don't dump bare internal Firebase UIDs where a human-readable counterparty field exists.
- Don't include any counterparty data the user never saw in-app (the narrow hidden-telemetry case).
- Don't change any deletion behavior or any existing export section's shape.

### Verification + gates
- dart analyze; the new unit tests; firebase-backend-security + code-reviewer + testing-specialist; cloud-functions-specialist for the cascade-probe edit.

### Rollback
Purely additive (new export sections + doc edits). Revert the single commit — no migration, no
change to existing export/deletion flows.

## What this means in plain language
- This is about your "download all my data" feature, which the law requires to be complete.
- Right now it leaves out four behind-the-scenes notification record types (history of what was sent to you, delivery records, engagement stats). This adds them, so the download is honest and complete.
- **On the "other person" question you caught:** you were right — your export will show the other people the way you already see them in the app (e.g. "Anna shared a recipe with you"), exactly like Facebook/Google do. We're *not* blanking them out. The only thing we avoid dumping is the meaningless internal database ID — you get the name/notification you actually saw, not a 28-character code.
- Big notification lists get capped (a few thousand most-recent) so the download doesn't balloon, and it'll clearly say if anything was trimmed.
- I'll list these records in your privacy policy and the internal compliance record, and note our decision (show the counterparty, don't anonymise) so a future automated review doesn't "correct" it back.
- **Risk:** very low. It only *adds* to the data export; nothing about how the app works changes; one-commit undo.

---

## Sprint: compliance quick wins (need-malin, interactive) — 2026-06-30

(archived — BUT-1395/1396/1399/1400 all Done + pushed; CF deletion leak fixed; Swedish email
migration done; acquisition-rules CI red fixed. Follow-up BUT-1450 planned above.)
