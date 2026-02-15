/// Service handling beta feedback submission to Firestore and Firebase Storage.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/services/feedback/interaction_logger.dart';

/// Manages beta feedback submissions including optional screenshot upload.
class FeedbackService extends BaseService {
  @override
  String get serviceName => 'FeedbackService';

  InteractionLogger get _interactionLogger =>
      ServiceLocator.get<InteractionLogger>();

  AuthRepository get _authRepository => ServiceLocator.get<AuthRepository>();

  /// Submit user feedback with optional screenshot.
  ///
  /// Uploads screenshot to Firebase Storage if provided, then saves
  /// the feedback entry (with recent interactions) to Firestore.
  Future<bool> submitFeedback({
    required FeedbackCategory category,
    required String description,
    String? email,
    Uint8List? screenshot,
  }) async {
    final result = await executeServiceOperation<bool>(
      () async {
        final userId = _authRepository.currentUserId;
        if (userId == null) throw Exception('User not authenticated');

        String? screenshotUrl;

        // Upload screenshot if provided
        if (screenshot != null) {
          screenshotUrl = await _uploadScreenshot(userId, screenshot);
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

        await FirebaseFirestore.instance
            .collection('feedback')
            .add(entry.toMap());

        AppLogger.info('Feedback submitted: ${category.name}');
        return true;
      },
      operationName: 'Submit feedback',
      defaultValue: false,
    );

    return result ?? false;
  }

  /// Upload screenshot bytes to Firebase Storage.
  Future<String> _uploadScreenshot(String userId, Uint8List bytes) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref =
        FirebaseStorage.instance.ref().child('feedback/$userId/$timestamp.png');

    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/png'),
    );

    return await uploadTask.ref.getDownloadURL();
  }

  /// Gather basic device info for debugging context.
  String _buildDeviceInfo() {
    // Platform info is limited on web, but capture what we can
    return 'Flutter Web - ${DateTime.now().timeZoneName}';
  }
}
