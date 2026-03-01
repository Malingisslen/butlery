import 'dart:typed_data';

import 'package:butlery/models/feedback_entry.dart';

/// Repository interface for beta feedback persistence.
abstract class FeedbackRepository {
  Future<void> saveFeedback(FeedbackEntry entry);
  Future<String> uploadScreenshot(String userId, Uint8List bytes);
}
