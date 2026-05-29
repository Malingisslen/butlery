import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/notification_analytics_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firestore-backed notification analytics persistence.
///
/// BUT-504: infrastructure-layer repository (like [FirestoreRepository]) over
/// the `notification_delivery` and `notification_engagement` collections.
/// Events are untyped maps, so there is no domain model to type against — the
/// caller (`NotificationAnalyticsManager`) owns event shaping.
class FirebaseNotificationAnalyticsRepository
    implements NotificationAnalyticsRepository {
  final FirebaseFirestore _firestore;

  FirebaseNotificationAnalyticsRepository({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _delivery =>
      _firestore.collection(FirestoreCollections.notificationDelivery);

  CollectionReference<Map<String, dynamic>> get _engagement =>
      _firestore.collection(FirestoreCollections.notificationEngagement);

  @override
  Future<void> addDeliveryEvents(List<Map<String, dynamic>> events) async {
    if (events.isEmpty) return;
    final batch = _firestore.batch();
    for (final event in events) {
      // Key the delivery doc by notificationId so the lifecycle updates from
      // updateDelivery(notificationId, ...) — sent → delivered/failed/opened —
      // target the SAME document. With an auto-generated id the 'sent' doc and
      // the update target diverge: status never transitions off 'sent', so
      // every engagement rate computes against received==0. Fall back to an
      // auto id only if an event somehow lacks a notificationId.
      final notificationId = event['notificationId'] as String?;
      final docRef = notificationId != null
          ? _delivery.doc(notificationId)
          : _delivery.doc();
      batch.set(docRef, event);
    }
    await batch.commit();
  }

  @override
  Future<void> updateDelivery(
    String notificationId,
    Map<String, dynamic> updates,
  ) async {
    await _delivery.doc(notificationId).update(updates);
  }

  @override
  Future<void> addEngagementEvent(Map<String, dynamic> event) async {
    await _engagement.add(event);
  }

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      getDeliveriesForUser(
    String userId,
    DateTime since,
  ) async {
    final snapshot = await _delivery
        .where('targetUserId', isEqualTo: userId)
        .where('sentAt', isGreaterThan: Timestamp.fromDate(since))
        .get();
    return snapshot.docs;
  }

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      getEngagementsForUser(
    String userId,
    DateTime since,
  ) async {
    final snapshot = await _engagement
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
        .get();
    return snapshot.docs;
  }
}
