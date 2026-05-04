# Batch Partial-Write Notes (BUT-592)

Multi-batch Firestore sequences in `lib/` and what happens when batch N succeeds but N+1 fails (network drop, transient backend error, etc.).

## Constants

- `kFirestoreBatchOpLimit = 500` — SDK hard limit. Use for boundary checks.
- `kFirestoreBatchSafeChunkSize = 450` — recommended chunk size (50-op safety margin).

All chunk-callers should use the *safe* size. The hard limit stays for any explicit boundary assertion.

## Multi-batch consumers (audited)

| Site | Failure mode | Recovery path |
|---|---|---|
| `services/account/account_deletion/content_deletion_operations.dart` (`deleteRecipes`, `deletePersonalTags`, etc.) | First N batches persisted; method returns `false`. | Re-run account deletion. Deletes of already-gone docs are no-ops; retry completes remaining work. |
| `services/account/account_deletion/social_deletion_operations.dart` (`removeFriendConnections`, `removeFromSharedContent`, `deleteCommentsAndRatings`, `deletePingsByUser`) | Same as above. Comment anonymisation is idempotent (sentinel overwrite). | Same — re-run cascade. |
| `repositories/firebase/firebase_recipe_repository.dart` `renamePersonalTagInRecipes` (BUT-480) | Some recipes renamed, some not. Method returns recipe-count and logs warning. | Idempotent: re-running with same `(tagId, newName)` no-ops already-renamed entries (the inner map rebuild only writes the matching `entry['tagId'] == tagId` slot). The next `updateTag` call re-fires the cascade. |
| `repositories/firebase/firestore_batch_utils.dart` `batchDeleteDocs` | Rethrows on commit failure. With `operationLabel`, logs structured `(chunk i+1 / N, X already deleted)` context. | Caller decides — most callers re-run the parent flow which is idempotent. |

## Single-batch ops (no partial-write risk)

- `firebase_notifications_repository.markAllAsRead` — chunks updates, but each chunk is independently atomic; partial failure leaves some unread, which is the safe default.
- `shopping_item_operations_module.deleteItems` — same shape; deleting some shopping items mid-sequence and retrying is benign.
- All single-batch repositories using `firestore.batch()` for ≤450-op writes are atomic by construction.

## When partial-write matters more

If the orchestrator does **not** retry (e.g. user closes app mid-deletion and never returns), residual data could survive past the GDPR Art. 17 24-hour deadline. The `gdpr_residual_data_probe` (BUT-498 commit 5/5) is the existing safety net — it scans for stragglers and emits an alert. No further work needed in this audit.

## Out of scope

- 30+ single-batch sites in repositories — atomic by construction.
- Cloud Functions batch ops (`functions/src/`) — TS-side, server-controlled retry semantics; tracked separately.
