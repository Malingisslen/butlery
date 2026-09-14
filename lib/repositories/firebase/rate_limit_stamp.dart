import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';

/// Adds the per-user burst stamp that `rateLimitStamped` in `firestore.rules`
/// requires in the SAME request as the write it guards.
///
/// The rule accepts the guarded write only when this stamp's `lastWrite` is the
/// request's server time and its `lastDocId` equals the key the rule's call
/// site names — the guarded document's id, or for pings `<groupId>/<pingId>` —
/// so [guardedDocId] must be that key and [batch] must be the batch that
/// carries the guarded write.
void stampRateLimit(
  WriteBatch batch,
  FirebaseFirestore firestore, {
  required String userId,
  required String type,
  required String guardedDocId,
  TimestampProvider timestampProvider = const ServerTimestampProvider(),
}) {
  batch.set(
    firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userRateLimits)
        .doc(type),
    {
      'lastWrite': timestampProvider.serverTimestamp(),
      'expireAt': Timestamp.fromDate(clock.now().add(const Duration(days: 2))),
      'lastDocId': guardedDocId,
    },
    SetOptions(merge: true),
  );
}
