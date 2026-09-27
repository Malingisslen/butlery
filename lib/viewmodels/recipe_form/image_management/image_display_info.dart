// lib/viewmodels/recipe_form/image_management/image_display_info.dart

import 'package:flutter/material.dart';
import 'package:butlery/services/upload/upload_models.dart';

/// Comprehensive image display information for immediate UI feedback
class ImageDisplayInfo {
  final String displayPath;
  final ImageUploadState state;
  final double progress;
  final bool isPending;
  final bool isUploading;
  final bool isCompleted;
  final bool hasError;
  final String? errorMessage;
  final String progressText;
  final bool canRetry;

  const ImageDisplayInfo({
    required this.displayPath,
    required this.state,
    required this.progress,
    required this.isPending,
    required this.isUploading,
    required this.isCompleted,
    required this.hasError,
    this.errorMessage,
    required this.progressText,
    required this.canRetry,
  });

  /// Get icon for upload state
  IconData getStateIcon() {
    switch (state) {
      case ImageUploadState.pending:
        return Icons.schedule;
      case ImageUploadState.uploading:
        return Icons.cloud_upload;
      case ImageUploadState.retrying:
        return Icons.refresh;
      case ImageUploadState.completed:
        return Icons.cloud_done;
      case ImageUploadState.failed:
        return Icons.error;
      case ImageUploadState.cancelled:
        return Icons.cancel;
    }
  }
}
