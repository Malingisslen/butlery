import 'dart:typed_data';

import 'package:butlery/models/feedback_entry.dart';

/// Repository interface for beta feedback persistence.
abstract class FeedbackRepository {
  Future<void> saveFeedback(FeedbackEntry entry);
  Future<String> uploadScreenshot(String userId, Uint8List bytes);

  /// Admin-only: stream feedback entries newest-first for the admin dashboard.
  ///
  /// Optionally filtered to a single [status]. [limit] bounds the result so
  /// the inbox stays paginated as beta feedback accumulates. Access is
  /// enforced by Firestore rules (`allow read: if isAdmin()`); non-admins
  /// receive a permission-denied on the underlying query.
  Stream<List<FeedbackEntry>> watchFeedback({
    FeedbackStatus? status,
    int limit = 50,
  });

  /// Admin-only: update the triage [status] of a feedback entry. Enforced by
  /// Firestore rules (`allow update: if isAdmin()`).
  Future<void> updateStatus(String id, FeedbackStatus status);

  /// Export all feedback submissions by [userId] for GDPR Article 20.
  ///
  /// Returns raw `{id, data}` shapes so the data-export pipeline can
  /// sanitize timestamps without round-tripping through the model.
  /// Implementations MUST validate that the caller owns [userId].
  Future<List<Map<String, dynamic>>> exportFeedbackByUser(
    String userId, {
    int maxDocuments = 1000,
  });
}
