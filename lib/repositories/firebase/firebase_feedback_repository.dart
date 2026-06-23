import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:butlery/core/constants/upload_constants.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/feedback_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firebase implementation for beta feedback persistence.
/// Uses Firestore for feedback entries and Firebase Storage for screenshots.
class FirebaseFeedbackRepository extends BaseFirebaseRepository<FeedbackEntry>
    implements FeedbackRepository {
  // Lazy resolve so unit tests that only exercise the export read path don't
  // need a real FirebaseStorage instance (uploadScreenshot still uses it).
  final FirebaseStorage? _injectedStorage;
  FirebaseStorage get _storage => _injectedStorage ?? FirebaseStorage.instance;

  FirebaseFeedbackRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    FirebaseStorage? storage,
  }) : _injectedStorage = storage;

  @override
  String get collectionName => FirestoreCollections.feedback;

  @override
  FeedbackEntry fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      FeedbackEntry.fromMap({...doc.data()!, 'id': doc.id});

  @override
  Map<String, dynamic> toFirestore(FeedbackEntry entity) => entity.toMap();

  @override
  String getId(FeedbackEntry entity) => entity.id;

  // Feedback is owned by the submitting user
  @override
  Future<bool> validateCreatePermission(
    String userId,
    FeedbackEntry entity,
  ) async {
    return entity.userId == userId;
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    FeedbackEntry? entity,
  ) async {
    // Users can only read their own feedback
    if (entity == null) return false;
    return entity.userId == userId;
  }

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    FeedbackEntry entity,
  ) async {
    return entity.userId == userId;
  }

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async {
    return false; // Feedback cannot be deleted by users
  }

  @override
  Future<void> saveFeedback(FeedbackEntry entry) async {
    try {
      final userId = requireCurrentUserId();

      // Gate the write behind the create-permission check and record the
      // decision in the audit trail (the auto-id `collection.add` path skipped
      // both — every custom write must validate + log, per repos/CLAUDE.md).
      final canCreate = await validateCreatePermission(userId, entry);
      await logPermissionCheck(
        userId: userId,
        resource: 'FeedbackEntry/${entry.id}',
        operation: 'create',
        granted: canCreate,
        auditRepository: auditRepository,
      );
      if (!canCreate) {
        throw PermissionDeniedException(
          'User does not have permission to submit this feedback',
        );
      }

      await collection.add(toFirestore(entry));
      AppLogger.info('Feedback saved: ${entry.category.name}');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save feedback: $e', stackTrace);
      rethrow;
    }
  }

  @override
  Stream<List<FeedbackEntry>> watchFeedback({
    FeedbackStatus? status,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = collection
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (status != null) {
      query = query.where('status', isEqualTo: status.wireName);
    }
    return query.snapshots().map(
      (snapshot) => snapshot.docs.map(fromFirestore).toList(),
    );
  }

  @override
  Future<void> updateStatus(String id, FeedbackStatus status) async {
    try {
      requireCurrentUserId();
      await collection.doc(id).update({'status': status.wireName});
      AppLogger.info('Feedback $id status set to ${status.wireName}');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update feedback status: $e', stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> exportFeedbackByUser(
    String userId, {
    int maxDocuments = 1000,
  }) async {
    // GDPR Article 20: caller must be exporting their own feedback.
    await validateOwnership(
      currentUserId: requireCurrentUserId(),
      resourceOwnerId: userId,
      resourceType: collectionName,
    );

    final snapshot = await collection
        .where('userId', isEqualTo: userId)
        .limit(maxDocuments)
        .get();
    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }

  @override
  Future<String> uploadScreenshot(String userId, Uint8List bytes) async {
    if (bytes.length > UploadConstants.maxScreenshotBytes) {
      throw ArgumentError('Screenshot exceeds 5MB limit');
    }

    try {
      requireCurrentUserId();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('feedback/$userId/$timestamp.png');

      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/png'),
      );

      final url = await uploadTask.ref.getDownloadURL();
      AppLogger.info(
        'Feedback screenshot uploaded for user ${userId.maskedUserId}',
      );
      return url;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to upload feedback screenshot: $e', stackTrace);
      rethrow;
    }
  }
}
