/// Upload Progress Widgets - Upload status and progress UI components.
/// Extracted from editable_image_widget.dart for better organization.

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/services/upload/upload_models.dart';

/// Provides upload progress UI components for image editing.
class UploadProgressWidgets {
  /// Build enhanced upload queue status banner with bulk management controls
  static Widget buildUploadQueueStatusBanner({
    required String? uploadQueueStatus,
    Map<String, dynamic>? uploadManagementSummary,
    VoidCallback? onRetryAllFailed,
    VoidCallback? onCancelAllActive,
    VoidCallback? onClearAllFailed,
  }) {
    if (uploadQueueStatus == null || uploadQueueStatus.isEmpty) {
      return const SizedBox.shrink();
    }

    final managementSummary = uploadManagementSummary;
    final showBulkControls = managementSummary != null &&
        ((managementSummary['canBulkRetry'] as bool? ?? false) ||
            (managementSummary['canBulkCancel'] as bool? ?? false) ||
            (managementSummary['hasRetryableFailures'] as bool? ?? false));

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusIcon(managementSummary),
                  const SizedBox(width: AppDimensions.spacingM),
                  Expanded(
                    child: Text(
                      uploadQueueStatus,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (managementSummary != null) ...[
                const SizedBox(height: AppDimensions.spacingXs),
                _buildProgressDetails(managementSummary),
              ],
            ],
          ),
          if (showBulkControls) ...[
            const SizedBox(height: AppDimensions.spacingM),
            _buildBulkManagementControls(
              summary: managementSummary,
              onRetryAllFailed: onRetryAllFailed,
              onCancelAllActive: onCancelAllActive,
              onClearAllFailed: onClearAllFailed,
            ),
          ],
        ],
      ),
    );
  }

  /// Build status icon - checkmark when complete, spinner when active
  static Widget _buildStatusIcon(Map<String, dynamic>? managementSummary) {
    final hasActiveUploads = managementSummary != null &&
        ((managementSummary['active'] as int? ?? 0) > 0 ||
            (managementSummary['pending'] as int? ?? 0) > 0);

    if (hasActiveUploads) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor:
              const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
          value: (managementSummary['overallProgress'] as double?),
        ),
      );
    } else {
      return const Icon(
        Icons.check_circle,
        size: 16,
        color: AppColors.success,
      );
    }
  }

  /// Build bulk management control buttons
  static Widget _buildBulkManagementControls({
    Map<String, dynamic>? summary,
    VoidCallback? onRetryAllFailed,
    VoidCallback? onCancelAllActive,
    VoidCallback? onClearAllFailed,
  }) {
    if (summary == null) return const SizedBox.shrink();
    final canBulkRetry = summary['canBulkRetry'] as bool? ?? false;
    final canBulkCancel = summary['canBulkCancel'] as bool? ?? false;
    final hasRetryableFailures =
        summary['hasRetryableFailures'] as bool? ?? false;
    final failed = summary['failed'] as int? ?? 0;
    final active = summary['active'] as int? ?? 0;

    final controls = <Widget>[];

    if (canBulkRetry && onRetryAllFailed != null) {
      controls.add(
        buildBulkActionButton(
          icon: Icons.refresh,
          label: 'Försök alla ($failed)',
          onTap: onRetryAllFailed,
          color: AppColors.primaryBlue,
        ),
      );
    }

    if (canBulkCancel && onCancelAllActive != null) {
      controls.add(
        buildBulkActionButton(
          icon: Icons.stop,
          label: 'Stoppa alla ($active)',
          onTap: onCancelAllActive,
          color: AppColors.textMedium,
        ),
      );
    }

    if (hasRetryableFailures && onClearAllFailed != null) {
      controls.add(
        buildBulkActionButton(
          icon: Icons.clear_all,
          label: 'Rensa misslyckade',
          onTap: onClearAllFailed,
          color: AppColors.error,
        ),
      );
    }

    if (controls.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppDimensions.spacingSm,
      runSpacing: AppDimensions.spacingSm,
      children: controls,
    );
  }

  /// Build bulk action button
  static Widget buildBulkActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: color.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: AppDimensions.iconSizeS,
                color: AppColors.cardWhite,
              ),
              const SizedBox(width: AppDimensions.spacingXs),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.cardWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build enhanced progress details with analytics
  static Widget _buildProgressDetails(Map<String, dynamic> summary) {
    final progressText = summary['progressText'] as String?;
    final speedText = summary['speedText'] as String?;
    final summaryText = summary['summaryText'] as String?;

    final details = <String>[];

    if (progressText != null && progressText.isNotEmpty) {
      details.add(progressText);
    }
    if (speedText != null && speedText.isNotEmpty) {
      details.add(speedText);
    }
    if (summaryText != null &&
        summaryText.isNotEmpty &&
        summaryText != progressText) {
      details.add(summaryText);
    }

    if (details.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: details
          .map((detail) => Padding(
                padding: const EdgeInsets.only(top: AppDimensions.spacingXxs),
                child: Text(
                  detail,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryBlue.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ))
          .toList(),
    );
  }

  /// Build upload progress overlay for individual images
  static Widget buildUploadProgressOverlay({
    required ImageUploadStatus status,
    required String imageUrl,
    required BorderRadius borderRadius,
    Function(String)? onRetryUpload,
    Function(String)? onCancelUpload,
  }) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: AppColors.textDark.withValues(alpha: 0.6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildProgressIndicator(status),
            const SizedBox(height: AppDimensions.spacingSm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
              decoration: BoxDecoration(
                color: AppColors.textDark.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(AppDimensions.paddingS),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    status.statusDescription,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.cardWhite,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (status.isActive &&
                      status.formattedTimeRemaining != null) ...[
                    const SizedBox(height: AppDimensions.spacingXxs),
                    Text(
                      '${status.formattedTimeRemaining} kvar',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.cardWhite.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                  if (status.fileSizeMB != null) ...[
                    const SizedBox(height: AppDimensions.spacingXxs),
                    Text(
                      '${status.fileSizeMB!.toStringAsFixed(1)} MB',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.cardWhite.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (status.state == ImageUploadState.failed ||
                status.state == ImageUploadState.cancelled) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (status.canRetry && onRetryUpload != null)
                    buildUploadActionButton(
                      icon: Icons.refresh,
                      label: 'Försök igen',
                      onTap: () => onRetryUpload(imageUrl),
                      color: AppColors.primaryBlue,
                    ),
                  if (status.canRetry &&
                      onRetryUpload != null &&
                      onCancelUpload != null)
                    const SizedBox(width: AppDimensions.spacingSm),
                  if (onCancelUpload != null)
                    buildUploadActionButton(
                      icon: Icons.close,
                      label: 'Ta bort',
                      onTap: () => onCancelUpload(imageUrl),
                      color: AppColors.error,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build progress indicator based on upload state
  static Widget buildProgressIndicator(ImageUploadStatus status) {
    switch (status.state) {
      case ImageUploadState.pending:
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cardWhite.withValues(alpha: 0.2),
          ),
          child: const Icon(
            Icons.schedule,
            color: AppColors.cardWhite,
            size: AppDimensions.iconSizeL,
          ),
        );

      case ImageUploadState.uploading:
      case ImageUploadState.retrying:
        return SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            value: status.progress > 0 ? status.progress : null,
            strokeWidth: 4,
            backgroundColor: AppColors.cardWhite.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              status.state == ImageUploadState.retrying
                  ? AppColors.textMedium
                  : AppColors.primaryBlue,
            ),
          ),
        );

      case ImageUploadState.completed:
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryBlue.withValues(alpha: 0.9),
          ),
          child: const Icon(
            Icons.check,
            color: AppColors.cardWhite,
            size: AppDimensions.iconSizeL,
          ),
        );

      case ImageUploadState.failed:
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.error.withValues(alpha: 0.9),
          ),
          child: const Icon(
            Icons.error,
            color: AppColors.cardWhite,
            size: AppDimensions.iconSizeL,
          ),
        );

      case ImageUploadState.cancelled:
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.textMedium.withValues(alpha: 0.9),
          ),
          child: const Icon(
            Icons.cancel,
            color: AppColors.cardWhite,
            size: AppDimensions.iconSizeL,
          ),
        );
    }
  }

  /// Build action button for upload overlay
  static Widget buildUploadActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.paddingS),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppDimensions.paddingS),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: AppColors.cardWhite,
              size: AppDimensions.iconSizeS,
            ),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.cardWhite,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
