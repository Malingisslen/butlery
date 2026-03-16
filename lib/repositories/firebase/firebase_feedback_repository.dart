import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
  final FirebaseStorage _storage;

  FirebaseFeedbackRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    FirebaseStorage? storage,
  }) : _storage = storage ?? FirebaseStorage.instance;

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
      String userId, FeedbackEntry entity) async {
    return entity.userId == userId;
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, FeedbackEntry? entity) async {
    // Users can only read their own feedback
    if (entity == null) return false;
    return entity.userId == userId;
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, FeedbackEntry entity) async {
    return entity.userId == userId;
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
    return false; // Feedback cannot be deleted by users
  }

  @override
  Future<void> saveFeedback(FeedbackEntry entry) async {
    try {
      requireCurrentUserId();
      await collection.add(toFirestore(entry));
      AppLogger.info('Feedback saved: ${entry.category.name}');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save feedback: $e', stackTrace);
      rethrow;
    }
  }

  @override
  Future<String> uploadScreenshot(String userId, Uint8List bytes) async {
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
          'Feedback screenshot uploaded for user ${userId.maskedUserId}');
      return url;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to upload feedback screenshot: $e', stackTrace);
      rethrow;
    }
  }
}
