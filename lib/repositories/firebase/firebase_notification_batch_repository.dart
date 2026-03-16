import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/notification_batch_repository.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/models/notification_batch.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';

/// Firebase implementation for notification batch aggregation.
/// Uses `notification_batches` collection.
class FirebaseNotificationBatchRepository
    implements NotificationBatchRepository {
  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;
  final TimestampProvider _timestampProvider;

  FirebaseNotificationBatchRepository({
    FirebaseFirestore? firestore,
    required AuthRepository authRepository,
    TimestampProvider? timestampProvider,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authRepository = authRepository,
        _timestampProvider =
            timestampProvider ?? const ServerTimestampProvider();

  String get _userId {
    final id = _authRepository.currentUserId;
    if (id == null) {
      throw StateError('NotificationBatchRepository: No authenticated user');
    }
    return id;
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.notificationBatches);

  @override
  Future<void> addToBatch({
    required String batchKey,
    required NotificationTemplate notification,
    required Duration batchWindow,
  }) async {
    try {
      final batchDoc = _collection.doc(batchKey);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(batchDoc);

        if (doc.exists && doc.data() != null) {
          final data = doc.data();
          final notifications = List<Map<String, dynamic>>.from(
              (data?['notifications'] as List?).orEmpty());
          notifications.add(notification.toMap());

          transaction.update(batchDoc, {
            'notifications': notifications,
            'count': notifications.length,
            'lastUpdated': _timestampProvider.serverTimestamp(),
          });
        } else {
          transaction.set(batchDoc, {
            'userId': _userId,
            'batchKey': batchKey,
            'notifications': [notification.toMap()],
            'count': 1,
            'createdAt': _timestampProvider.serverTimestamp(),
            'lastUpdated': _timestampProvider.serverTimestamp(),
            'scheduledFor': Timestamp.fromDate(DateTime.now().add(batchWindow)),
          });
        }
      });
    } catch (e) {
      AppLogger.error('Failed to add notification to batch', e);
      rethrow;
    }
  }

  @override
  Future<List<NotificationBatch>> getPendingBatches() async {
    try {
      final now = Timestamp.now();
      final query = await _collection
          .where('userId', isEqualTo: _userId)
          .where('scheduledFor', isLessThanOrEqualTo: now)
          .get();

      return query.docs
          .map((doc) => NotificationBatch.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to get pending batches', e);
      return [];
    }
  }

  @override
  Future<NotificationBatch?> getBatchByKey(String batchKey) async {
    try {
      final doc = await _collection.doc(batchKey).get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return NotificationBatch.fromMap(doc.id, doc.data()!);
    } catch (e) {
      AppLogger.error('Failed to get batch by key: $batchKey', e);
      return null;
    }
  }

  @override
  Future<void> removeBatch(String batchKey) async {
    try {
      await _collection.doc(batchKey).delete();
    } catch (e) {
      AppLogger.error('Failed to remove batch', e);
    }
  }
}
