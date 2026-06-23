import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/repositories/firebase/firebase_notification_analytics_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Verifies the repository routes analytics writes/reads to the correct
/// Firestore collections — the layer-skipping fix in BUT-504 only pays off if
/// the repository actually persists where the manager used to.
void main() {
  late FakeFirebaseFirestore firestore;
  late FirebaseNotificationAnalyticsRepository repository;

  const userId = 'user-1';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirebaseNotificationAnalyticsRepository(firestore: firestore);
  });

  test(
    'addDeliveryEvents writes one doc per event to notification_delivery',
    () async {
      await repository.addDeliveryEvents([
        {'notificationId': 'n1', 'targetUserId': userId, 'status': 'sent'},
        {'notificationId': 'n2', 'targetUserId': userId, 'status': 'sent'},
      ]);

      final snapshot = await firestore
          .collection(FirestoreCollections.notificationDelivery)
          .get();
      expect(snapshot.docs, hasLength(2));
    },
  );

  test('addDeliveryEvents keys the doc id by notificationId', () async {
    // The doc id MUST be the notificationId, not an auto-generated id —
    // otherwise updateDelivery(notificationId, ...) targets a different doc
    // and the sent→delivered lifecycle never completes.
    await repository.addDeliveryEvents([
      {'notificationId': 'n1', 'targetUserId': userId, 'status': 'sent'},
    ]);

    final doc = await firestore
        .collection(FirestoreCollections.notificationDelivery)
        .doc('n1')
        .get();
    expect(doc.exists, isTrue);
    expect(doc.data()?['status'], equals('sent'));
  });

  test('delivery lifecycle: addDeliveryEvents then updateDelivery hit the SAME '
      'doc (sent → delivered transitions)', () async {
    // The behavioral contract the document-id-mismatch bug broke: the write
    // path and the update path must converge. Before the fix, addDeliveryEvents
    // wrote an auto-id doc while updateDelivery targeted doc(notificationId),
    // so status stayed 'sent' forever and every engagement rate was 0.
    await repository.addDeliveryEvents([
      {'notificationId': 'n1', 'targetUserId': userId, 'status': 'sent'},
    ]);

    await repository.updateDelivery('n1', {'status': 'delivered'});

    final doc = await firestore
        .collection(FirestoreCollections.notificationDelivery)
        .doc('n1')
        .get();
    expect(
      doc.data()?['status'],
      equals('delivered'),
      reason: 'updateDelivery must mutate the doc addDeliveryEvents wrote.',
    );
    // And exactly one delivery doc exists — no orphan auto-id 'sent' doc.
    final all = await firestore
        .collection(FirestoreCollections.notificationDelivery)
        .get();
    expect(all.docs, hasLength(1));
  });

  test('addDeliveryEvents is a no-op on empty list', () async {
    await repository.addDeliveryEvents([]);

    final snapshot = await firestore
        .collection(FirestoreCollections.notificationDelivery)
        .get();
    expect(snapshot.docs, isEmpty);
  });

  test('updateDelivery mutates the matching delivery doc', () async {
    await firestore
        .collection(FirestoreCollections.notificationDelivery)
        .doc('n1')
        .set({'status': 'sent'});

    await repository.updateDelivery('n1', {'status': 'delivered'});

    final doc = await firestore
        .collection(FirestoreCollections.notificationDelivery)
        .doc('n1')
        .get();
    expect(doc.data()?['status'], equals('delivered'));
  });

  test('addEngagementEvent appends to notification_engagement', () async {
    await repository.addEngagementEvent(
      {'userId': userId, 'action': 'opened'},
    );

    final snapshot = await firestore
        .collection(FirestoreCollections.notificationEngagement)
        .get();
    expect(snapshot.docs, hasLength(1));
    expect(snapshot.docs.first.data()['action'], equals('opened'));
  });

  test(
    'getDeliveriesForUser filters by targetUserId and sentAt window',
    () async {
      final since = DateTime(2026, 1, 1);
      await firestore.collection(FirestoreCollections.notificationDelivery).add(
        {
          'targetUserId': userId,
          'sentAt': Timestamp.fromDate(DateTime(2026, 2, 1)),
        },
      );
      await firestore.collection(FirestoreCollections.notificationDelivery).add(
        {
          'targetUserId': 'someone-else',
          'sentAt': Timestamp.fromDate(DateTime(2026, 2, 1)),
        },
      );
      await firestore.collection(FirestoreCollections.notificationDelivery).add(
        {
          'targetUserId': userId,
          'sentAt': Timestamp.fromDate(DateTime(2025, 12, 1)), // before window
        },
      );

      final docs = await repository.getDeliveriesForUser(userId, since);

      expect(docs, hasLength(1));
      expect(docs.first.data()['targetUserId'], equals(userId));
    },
  );

  test(
    'getEngagementsForUser filters by userId and timestamp window',
    () async {
      final since = DateTime(2026, 1, 1);
      await firestore
          .collection(FirestoreCollections.notificationEngagement)
          .add({
            'userId': userId,
            'timestamp': Timestamp.fromDate(DateTime(2026, 3, 1)),
          });
      await firestore
          .collection(FirestoreCollections.notificationEngagement)
          .add({
            'userId': userId,
            'timestamp': Timestamp.fromDate(
              DateTime(2025, 11, 1),
            ), // before window
          });

      final docs = await repository.getEngagementsForUser(userId, since);

      expect(docs, hasLength(1));
    },
  );
}
