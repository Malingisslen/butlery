import 'package:cloud_firestore/cloud_firestore.dart';

/// Persistence for notification delivery + engagement analytics.
///
/// BUT-504: extracted from `NotificationAnalyticsManager` so the service-layer
/// module no longer resolves a raw `FirebaseFirestore` instance. Events are
/// untyped maps (one document per delivery / engagement record), so this is an
/// infrastructure-layer repository over the `notification_delivery` and
/// `notification_engagement` collections rather than a model-typed CRUD repo.
abstract class NotificationAnalyticsRepository {
  /// Persist a batch of delivery events (one document each). Used for the
  /// buffered `sent` write path.
  Future<void> addDeliveryEvents(List<Map<String, dynamic>> events);

  /// Update an existing delivery document by [notificationId].
  Future<void> updateDelivery(
    String notificationId,
    Map<String, dynamic> updates,
  );

  /// Append a single engagement event document.
  Future<void> addEngagementEvent(Map<String, dynamic> event);

  /// Fetch delivery docs for [userId] sent since [since].
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      getDeliveriesForUser(
    String userId,
    DateTime since,
  );

  /// Fetch engagement docs for [userId] recorded since [since].
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      getEngagementsForUser(
    String userId,
    DateTime since,
  );
}
