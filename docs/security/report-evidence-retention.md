# `report_evidence/{reportId}` — Art. 30 Record

GDPR Article 30 record for the server's text copy of reported content (BUT-1842) and its
frozen form (BUT-2329). Companion to `account-subcollections-retention.md`.

| | |
|---|---|
| **Purpose** | Let the moderator see what was reported after its author edits or deletes it; for a frozen copy, keep it so it can be disclosed in a serious case (police or another authority, a threat to someone's safety, a legal dispute). |
| **Lawful basis** | Legitimate interest, Art. 6(1)(f). A frozen copy: Art. 6(1)(f) (user safety; establishing, exercising or defending legal claims), or Art. 6(1)(c) where an authority has asked for preservation. Privacy policy §8 rows, 1.35. |
| **Data** | Written by `captureReportEvidence` (`functions/src/moderation/report-evidence.ts`): `reportId`, `contentType`, `contentId`, `contentOwnerId` (the reported person's uid), `capturedAt`, `expireAt`, `outcome`, and when captured `text`, `truncated` and for a menu dish `claimedCreatorIsReporter`. A frozen copy adds `frozen` (`freeze-report-evidence.ts`): `reason`, `frozenAt`, `frozenBy` (moderator uid), `firstFrozenAt`, `until`, `extensions`. |
| **Access** | Admin read only; no client write (`firestore.rules`). Freezing only through the `freezeReportEvidence` callable. |
| **Deleted** | Unfrozen: when its report is deleted, closed or loses `contentOwnerId` (`onReportEvidenceLifecycle`), on reopen, or by the TTL on `expireAt` (capture + 180 days). Frozen: by the TTL on `expireAt` (= `frozen.until`, at most three years after `firstFrozenAt`), by `release`, or by the reset script. |
| **Art. 15** | Not in the reported person's bundle (Art. 15(4), BUT-1842; register row 21). |
| **Not reachable** | A frozen copy keeps the reported person's uid after their erasure; the cascade reports it as a `RetainedRecord` rather than deleting it. |
