// lib/services/messaging_media_service.dart

import 'dart:io';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/constants/upload_constants.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/image_format_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/services/offline/chat_image_queue_metadata.dart';
import 'package:butlery/services/offline/queued_change.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:uuid/uuid.dart';

/// How a chat image left the device.
enum ImageSendOutcome {
  /// Uploaded and sent.
  sent,

  /// Without a connection: the message exists, the picture follows when the
  /// device is online again.
  queued,

  /// Nothing was sent.
  notSent,
}

/// Service for handling media (images) in messaging conversations.
/// Provides comprehensive media upload and messaging integration including:
/// - Image selection from camera/gallery
/// - Upload to Firebase Storage with automatic retry and progress tracking
/// - Automatic message creation with image URLs
/// - Error handling with user-friendly Swedish messages
/// **Core Responsibilities:**
/// - Pick images using ImagePicker
/// - Upload images to Firebase Storage via ImageUploadService (with automatic retry)
/// - Send image messages via MessagingService
/// - Track upload progress for UI feedback
/// - Handle errors gracefully
/// **Usage Example:**
/// ```dart
/// final mediaService = MessagingMediaService(
///   messagingService: messagingService,
///   authRepository: authRepository,
///   offlineService: () => offlineService,
/// );
/// // Pick and send image (now with automatic retry on failure!)
/// await mediaService.pickAndSendImage(
///   conversationId: conversationId,
///   source: ImageSource.gallery,
///   onProgress: (progress) => print('Upload: $progress%'),
/// );
/// ```
class MessagingMediaService extends BaseService {
  @override
  String get serviceName => 'MessagingMediaService';
  final ImageUploadService _uploadService;
  final MessagingService _messagingService;
  final auth_repo.AuthRepository _authRepository;
  final ImagePicker _imagePicker;
  final OfflineService? Function() _offline;

  MessagingMediaService({
    required MessagingService messagingService,
    required auth_repo.AuthRepository authRepository,
    ImageUploadService? uploadService,
    ImagePicker? imagePicker,
    required OfflineService? Function() offlineService,
  }) : _offline = offlineService,
       _uploadService = uploadService ?? ImageUploadService(),
       _messagingService = messagingService,
       _authRepository = authRepository,
       _imagePicker = imagePicker ?? ImagePicker();

  /// Pick image and send in conversation.
  /// Complete workflow: pick → upload → send message.
  /// [conversationId] Target conversation ID
  /// [source] Image source (camera or gallery)
  /// [onProgress] Optional progress callback (0.0 to 1.0)
  Future<ImageSendOutcome> pickAndSendImage({
    required String conversationId,
    required ImageSource source,
    Function(double progress)? onProgress,
  }) async {
    try {
      AppLogger.info(
        '🖼️ Picking image from ${source == ImageSource.camera ? "camera" : "gallery"}',
      );

      // Pick image
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        AppLogger.info('No image selected');
        return ImageSendOutcome.notSent;
      }

      AppLogger.info('✅ Image picked: ${pickedFile.path}');

      // Upload and send
      return await uploadAndSendImage(
        conversationId: conversationId,
        imagePath: pickedFile.path,
        onProgress: onProgress,
      );
    } catch (e) {
      AppLogger.error('❌ Failed to pick and send image', e);
      return ImageSendOutcome.notSent;
    }
  }

  /// Upload image and send as message.
  /// Uploads image to Firebase Storage and creates image message.
  /// [conversationId] Target conversation ID
  /// [imagePath] Local file path of image
  /// [onProgress] Optional progress callback (0.0 to 1.0)
  Future<ImageSendOutcome> uploadAndSendImage({
    required String conversationId,
    required String imagePath,
    Function(double progress)? onProgress,
  }) async {
    final currentUserId = _authRepository.currentUserId;
    if (currentUserId == null) {
      AppLogger.error('❌ No authenticated user for image upload');
      return ImageSendOutcome.notSent;
    }

    try {
      AppLogger.info('🔄 Uploading image: $imagePath');

      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        AppLogger.error('❌ Image file does not exist: $imagePath');
        return ImageSendOutcome.notSent;
      }

      final fileSize = await imageFile.length();
      if (fileSize > UploadConstants.maxMessagingImageBytes) {
        AppLogger.error('❌ Image too large: ${fileSize ~/ 1024}KB');
        return ImageSendOutcome.notSent;
      }

      // Validate image format via magic bytes
      final headerBytes = await imageFile
          .openRead(0, 12)
          .fold<List<int>>(
            [],
            (prev, chunk) => prev..addAll(chunk),
          );
      if (!ImageFormatUtils.isSupportedImage(headerBytes)) {
        AppLogger.error(
          '❌ Unsupported image format: ${path.extension(imagePath)}',
        );
        return ImageSendOutcome.notSent;
      }

      if (_mustQueue) {
        return await _queueImage(conversationId, currentUserId, imagePath);
      }

      // Upload to Firebase Storage with automatic retry
      final result = await _uploadService.uploadImage(
        file: imageFile,
        userId: currentUserId,
        onProgress: onProgress != null
            ? (status) => onProgress(status.progress)
            : null,
      );

      if (!result.success || result.url == null || result.url!.isEmpty) {
        if (_mustQueue) {
          return await _queueImage(conversationId, currentUserId, imagePath);
        }
        AppLogger.error(
          '❌ Failed to upload image: ${result.error ?? "no URL returned"}',
        );
        return ImageSendOutcome.notSent;
      }

      final imageUrl = result.url!;
      AppLogger.success('✅ Image uploaded with automatic retry: $imageUrl');

      // Send image message
      await _messagingService.sendImageMessage(
        conversationId: conversationId,
        imageUrl: imageUrl,
      );

      AppLogger.success('✅ Image message sent');
      return ImageSendOutcome.sent;
    } catch (e) {
      AppLogger.error('❌ Failed to upload and send image', e);
      return ImageSendOutcome.notSent;
    }
  }

  /// BUT-2294: without a connection a photo cannot go up.
  bool get _mustQueue {
    final offline = _offline();
    return offline != null && !offline.isOnline && offline.isQueueReady;
  }

  /// The message is created first, through Firestore's own queue, so the
  /// picture keeps its place among the texts sent after it; the queue row that
  /// follows fills in the picture. Creating the row first could let the queue
  /// find no message and take the picture back.
  Future<ImageSendOutcome> _queueImage(
    String conversationId,
    String userId,
    String imagePath,
  ) async {
    final offline = _offline()!;
    final messageId = const Uuid().v4();
    await _messagingService.sendPendingImageMessage(
      conversationId: conversationId,
      messageId: messageId,
    );
    try {
      await offline.userStorage.queueImageGroupForUser(
        imagePaths: [imagePath],
        entityType: chatImageEntityType,
        entityId: messageId,
        userId: userId,
        targetPath: 'users/$userId/chat_images',
        metadata: chatImageQueueMetadata(conversationId: conversationId),
      );
    } catch (e) {
      await _messagingService.deleteMessage(messageId);
      rethrow;
    }
    await offline.refreshSyncState();
    AppLogger.info('Chat image queued offline');
    return ImageSendOutcome.queued;
  }

  /// Pick multiple images and send in conversation.
  /// [conversationId] Target conversation ID
  /// [onProgress] Optional progress callback with (completed, total)
  /// Returns number of successfully sent images
  Future<int> pickAndSendMultipleImages({
    required String conversationId,
    Function(int completed, int total)? onProgress,
  }) async {
    try {
      AppLogger.info('🖼️ Picking multiple images');

      // Pick multiple images
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFiles.isEmpty) {
        AppLogger.info('No images selected');
        return 0;
      }

      AppLogger.info('✅ ${pickedFiles.length} images picked');

      // Upload and send each image
      int successCount = 0;
      for (int i = 0; i < pickedFiles.length; i++) {
        final outcome = await uploadAndSendImage(
          conversationId: conversationId,
          imagePath: pickedFiles[i].path,
        );

        if (outcome != ImageSendOutcome.notSent) {
          successCount++;
        }

        // Update progress
        onProgress?.call(i + 1, pickedFiles.length);
      }

      AppLogger.success(
        '✅ Successfully sent $successCount/${pickedFiles.length} images',
      );
      return successCount;
    } catch (e) {
      AppLogger.error('❌ Failed to pick and send multiple images', e);
      return 0;
    }
  }

  /// Get estimated file size in MB.
  /// Useful for showing file size before upload.
  /// [imagePath] Local file path
  /// Returns size in MB or null if file doesn't exist
  Future<double?> getImageSizeMB(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final bytes = await file.length();
      return bytes / (1024 * 1024); // Convert to MB
    } catch (e) {
      AppLogger.error('Failed to get image size', e);
      return null;
    }
  }

  /// Validate image before upload.
  /// Checks file existence and size limits.
  /// [imagePath] Local file path
  /// [maxSizeMB] Maximum allowed size in MB (default 10MB)
  /// Returns null if valid, error message if invalid
  Future<String?> validateImage(
    String imagePath, {
    double maxSizeMB = 10.0,
  }) async {
    try {
      final l = AppLocale.current;
      final file = File(imagePath);

      if (!await file.exists()) {
        return l.validationImageDoesNotExist;
      }

      final sizeMB = await getImageSizeMB(imagePath);
      if (sizeMB == null) {
        return l.validationCouldNotReadImageSize;
      }

      if (sizeMB > maxSizeMB) {
        return l.validationImageTooLargeWithSize(maxSizeMB.toInt());
      }

      return null; // Valid
    } catch (e) {
      AppLogger.error('Failed to validate image', e);
      return AppLocale.current.validationCouldNotValidateImage;
    }
  }
}
