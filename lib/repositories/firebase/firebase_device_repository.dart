import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/device_repository.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firebase implementation for device and FCM token management.
/// Uses only `user_fcm_tokens` collection.
class FirebaseDeviceRepository
    extends BaseFirebaseRepository<Map<String, dynamic>>
    implements DeviceRepository {
  FirebaseDeviceRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
  });

  @override
  String get collectionName => FirestoreCollections.userFcmTokens;

  @override
  Map<String, dynamic> fromFirestore(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      doc.data() ?? {};

  @override
  Map<String, dynamic> toFirestore(Map<String, dynamic> entity) => entity;

  @override
  String getId(Map<String, dynamic> entity) => entity['docId'] as String? ?? '';

  @override
  Future<bool> validateCreatePermission(
          String userId, Map<String, dynamic> entity) async =>
      entity['userId'] == userId;

  @override
  Future<bool> validateReadPermission(String userId, String resourceId,
          Map<String, dynamic>? entity) async =>
      resourceId.startsWith('${userId}_');

  @override
  Future<bool> validateUpdatePermission(String userId, String resourceId,
          Map<String, dynamic> entity) async =>
      resourceId.startsWith('${userId}_');

  @override
  Future<bool> validateDeletePermission(
          String userId, String resourceId) async =>
      resourceId.startsWith('${userId}_');

  @override
  Future<void> saveTokenToFirestore(
      String docId, Map<String, dynamic> tokenData) async {
    await collection.doc(docId).set(tokenData, SetOptions(merge: true));
  }

  @override
  Future<void> updateDeviceInfo(
      String docId, Map<String, dynamic> deviceData) async {
    await collection.doc(docId).set(deviceData, SetOptions(merge: true));
  }

  @override
  Future<void> updateTokenTimestamp(String docId) async {
    await collection.doc(docId).update({
      'lastUpdated': timestampProvider.serverTimestamp(),
    });
  }

  @override
  Future<void> removeOldToken(String userId, String deviceId) async {
    await collection.doc('${userId}_$deviceId').update({
      'isActive': false,
    });
  }

  @override
  Future<List<String>> getAllUserTokens(String userId) async {
    final query = await collection
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    return query.docs
        .map((doc) => doc.data()['token'] as String?)
        .whereType<String>()
        .toList();
  }

  @override
  Future<void> markDeviceInactive(String docId) async {
    await collection.doc(docId).update({'isActive': false});
  }

  @override
  Future<void> cleanupOldDevices(String userId, DateTime olderThan) async {
    final cutoffTimestamp = Timestamp.fromDate(olderThan);
    final query = await collection
        .where('userId', isEqualTo: userId)
        .where('lastSeen', isLessThan: cutoffTimestamp)
        .limit(100)
        .get();

    if (query.docs.isNotEmpty) {
      final batch = firestore.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {'isActive': false});
      }
      await batch.commit();
    }
  }
}
