import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/models/notification_batch.dart';

/// Repository interface for notification batch aggregation.
abstract class NotificationBatchRepository {
  Future<void> addToBatch({
    required String batchKey,
    required NotificationTemplate notification,
    required Duration batchWindow,
  });

  Future<List<NotificationBatch>> getPendingBatches();

  Future<NotificationBatch?> getBatchByKey(String batchKey);

  Future<void> removeBatch(String batchKey);
}
