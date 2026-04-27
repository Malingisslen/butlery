import 'dart:typed_data';

import 'package:butlery/models/feedback_entry.dart';

/// Repository interface for beta feedback persistence.
abstract class FeedbackRepository {
  Future<void> saveFeedback(FeedbackEntry entry);
  Future<String> uploadScreenshot(String userId, Uint8List bytes);

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
