/// Service handling beta feedback submission.

import 'dart:typed_data';

import 'package:get_it/get_it.dart';

import 'package:butlery/core/base/base_service.dart' hide AuthRepository;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/feedback_repository.dart';
import 'package:butlery/services/feedback/interaction_logger.dart';

/// Manages beta feedback submissions including optional screenshot upload.
class FeedbackService extends BaseService {
  @override
  String get serviceName => 'FeedbackService';

  InteractionLogger get _interactionLogger =>
      ServiceLocator.get<InteractionLogger>();

  FeedbackRepository get _feedbackRepository =>
      ServiceLocator.get<FeedbackRepository>();

  /// Submit user feedback with optional screenshot.
  Future<bool> submitFeedback({
    required FeedbackCategory category,
    required String description,
    String? email,
    Uint8List? screenshot,
  }) async {
    try {
      final userId = GetIt.instance.get<AuthRepository>().currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      String? screenshotUrl;

      if (screenshot != null) {
        try {
          screenshotUrl =
              await _feedbackRepository.uploadScreenshot(userId, screenshot);
        } catch (e) {
          AppLogger.warning('Screenshot upload failed, submitting without: $e');
        }
      }

      final entry = FeedbackEntry(
        id: '', // Firestore will generate
        userId: userId,
        category: category,
        description: description,
        email: email,
        screenshotUrl: screenshotUrl,
        recentInteractions: _interactionLogger.toJsonList(),
        createdAt: DateTime.now(),
        deviceInfo: _buildDeviceInfo(),
      );

      await _feedbackRepository.saveFeedback(entry);

      AppLogger.info('Feedback submitted: ${category.name}');
      return true;
    } catch (e) {
      AppLogger.error('Feedback submission failed: $e');
      return false;
    }
  }

  String _buildDeviceInfo() {
    return 'Flutter Web - ${DateTime.now().timeZoneName}';
  }
}
