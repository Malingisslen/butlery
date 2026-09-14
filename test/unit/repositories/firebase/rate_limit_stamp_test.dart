import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/repositories/firebase/rate_limit_stamp.dart';

// The window `firestore.rules` accepts for `expireAt`, measured from
// request.time: strictly after the minimum lead, at most the maximum lead.
const _ruleMinLead = Duration(seconds: 60);
const _ruleMaxLead = Duration(days: 4);

final _t = DateTime.utc(2026, 9, 14, 12);

class _FixedTimestampProvider implements TimestampProvider {
  const _FixedTimestampProvider(this.value);
  final Timestamp value;

  @override
  Object serverTimestamp() => value;
}

Future<DocumentSnapshot<Map<String, dynamic>>> _stampAt(
  FakeFirebaseFirestore firestore, {
  TimestampProvider timestampProvider = const TestTimestampProvider(),
}) {
  return withClock(Clock.fixed(_t), () async {
    final batch = firestore.batch();
    stampRateLimit(
      batch,
      firestore,
      userId: 'stamper-uid',
      type: 'comments',
      guardedDocId: 'guarded-doc-id',
      timestampProvider: timestampProvider,
    );
    await batch.commit();
    return firestore
        .collection(FirestoreCollections.users)
        .doc('stamper-uid')
        .collection(FirestoreCollections.userRateLimits)
        .doc('comments')
        .get();
  });
}

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  test('expireAt lands inside the window the rules accept', () async {
    final stamp = await _stampAt(firestore);
    expect(stamp.exists, isTrue, reason: 'premise: the stamp was written');

    final expireAt = (stamp.data()!['expireAt'] as Timestamp).toDate().toUtc();
    expect(
      expireAt.isAfter(_t.add(_ruleMinLead)),
      isTrue,
      reason: 'the rule refuses an expireAt within $_ruleMinLead of now',
    );
    expect(
      expireAt.isAfter(_t.add(_ruleMaxLead)),
      isFalse,
      reason: 'the rule refuses an expireAt more than $_ruleMaxLead ahead',
    );
  });

  test('writes exactly the admitted keys and names the guarded doc', () async {
    final stamp = await _stampAt(firestore);
    expect(stamp.exists, isTrue, reason: 'premise: the stamp was written');

    expect(stamp.data()!.keys.toSet(), {'lastWrite', 'expireAt', 'lastDocId'});
    expect(stamp.data()!['lastDocId'], 'guarded-doc-id');
  });

  test('lastWrite is the timestamp provider value', () async {
    final stamp = await _stampAt(firestore);
    expect(stamp.exists, isTrue, reason: 'premise: the stamp was written');
    expect(stamp.data()!['lastWrite'], Timestamp.fromDate(_t));

    final distinct = Timestamp.fromDate(DateTime.utc(2001, 2, 3));
    final second = await _stampAt(
      FakeFirebaseFirestore(),
      timestampProvider: _FixedTimestampProvider(distinct),
    );
    expect(
      second.data()!['lastWrite'],
      distinct,
      reason: 'a value differing from the clock shows the provider is read',
    );
  });
}
