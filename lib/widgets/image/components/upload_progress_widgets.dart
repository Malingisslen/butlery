/// Upload Progress Widgets - Upload status and progress UI components.
/// Extracted from editable_image_widget.dart for better organization.

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

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
    final showBulkControls =
        managementSummary != null &&
        ((managementSummary['canBulkRetry'] as bool? ?? false) ||
            (managementSummary['canBulkCancel'] as bool? ?? false) ||
            (managementSummary['hasRetryableFailures'] as bool? ?? false));

    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          decoration: BoxDecoration(
            color: context.modeColors.surfaceTintWarning,
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
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
                          style: AppTextStyles.metadataEmphasized.copyWith(
                            color: cs.onSurface,
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
      },
    );
  }

  /// Build status icon - checkmark when complete, spinner when active
  static Widget _buildStatusIcon(Map<String, dynamic>? managementSummary) {
    final hasActiveUploads =
        managementSummary != null &&
        ((managementSummary['active'] as int? ?? 0) > 0 ||
            (managementSummary['pending'] as int? ?? 0) > 0);

    if (hasActiveUploads) {
      return Builder(
        builder: (context) {
          // The plate line with the real progress when there is one
          // (Grafisk manual v6:209; PlateLine).
          return SizedBox(
            width: AppDimensions.iconSizeL,
            child: PlateLine(
              value: managementSummary['overallProgress'] as double?,
              semanticLabel: context.l10n.imageUploadingImages,
            ),
          );
        },
      );
    } else {
      return Builder(
        builder: (context) => ButleryIcon(
          ButleryIcons.circleCheck,
          size: AppDimensions.iconSizeS,
          color: context.modeColors.success,
        ),
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

    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final controls = <Widget>[];

        if (canBulkRetry && onRetryAllFailed != null) {
          controls.add(
            buildBulkActionButton(
              icon: ButleryIcons.refreshCw,
              label: context.l10n.uploadRetryAllCount(failed),
              onTap: onRetryAllFailed,
              color: cs.onSurface,
            ),
          );
        }

        if (canBulkCancel && onCancelAllActive != null) {
          controls.add(
            buildBulkActionButton(
              icon: ButleryIcons.x,
              label: context.l10n.uploadStopAllCount(active),
              onTap: onCancelAllActive,
              color: cs.onSurfaceVariant,
            ),
          );
        }

        if (hasRetryableFailures && onClearAllFailed != null) {
          controls.add(
            buildBulkActionButton(
              icon: ButleryIcons.listX,
              label: context.l10n.uploadClearFailed,
              onTap: onClearAllFailed,
              color: cs.error,
            ),
          );
        }

        if (controls.isEmpty) return const SizedBox.shrink();

        return Wrap(
          spacing: AppDimensions.spacingSm,
          runSpacing: AppDimensions.spacingSm,
          children: controls,
        );
      },
    );
  }

  /// Build bulk action button
  static Widget buildBulkActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Material(
          color: cs.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
            side: BorderSide(color: cs.outlineVariant),
          ),
          child: Semantics(
            button: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingM,
                  vertical: AppDimensions.paddingS,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ButleryIcon(
                      icon,
                      size: AppDimensions.iconSizeS,
                      color: color,
                    ),
                    const SizedBox(width: AppDimensions.spacingXs),
                    Text(
                      label,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: details
              .map(
                (detail) => Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.space4),
                  child: Text(
                    detail,
                    style: AppTextStyles.textSm.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
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
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              color: AppColors.overlayBlack60,
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
                    color: AppModeColors.surfacePaperOnPhoto(),
                    borderRadius: BorderRadius.circular(AppDimensions.paddingS),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status.statusDescription,
                        style: AppTextStyles.metadataEmphasized.copyWith(
                          color: cs.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (status.isActive &&
                          status.formattedTimeRemaining != null) ...[
                        const SizedBox(height: AppDimensions.space4),
                        Text(
                          context.l10n.uploadTimeRemaining(
                            status.formattedTimeRemaining!,
                          ),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: cs.primary,
                          ),
                        ),
                      ],
                      if (status.fileSizeMB != null) ...[
                        const SizedBox(height: AppDimensions.space4),
                        Text(
                          '${status.fileSizeMB!.toStringAsFixed(1)} MB',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: cs.primary,
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
                          icon: ButleryIcons.refreshCw,
                          label: context.l10n.commonRetry,
                          onTap: () => onRetryUpload(imageUrl),
                        ),
                      if (status.canRetry &&
                          onRetryUpload != null &&
                          onCancelUpload != null)
                        const SizedBox(width: AppDimensions.spacingSm),
                      if (onCancelUpload != null)
                        buildUploadActionButton(
                          icon: ButleryIcons.x,
                          label: context.l10n.commonDelete,
                          onTap: () => onCancelUpload(imageUrl),
                          isDestructive: true,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build progress indicator based on upload state
  static Widget buildProgressIndicator(ImageUploadStatus status) {
    return Builder(
      builder: (context) {
        switch (status.state) {
          case ImageUploadState.pending:
            return _stateCircle(context, ButleryIcons.clock);

          case ImageUploadState.uploading:
          case ImageUploadState.retrying:
            // An upload shows a line with its progress, never a spinner
            // (P4-U07; Grafisk manual v6:209).
            return SizedBox(
              width: 60,
              child: PlateLine(
                value: status.progress > 0 ? status.progress : null,
                semanticLabel: context.l10n.imageUploadingImages,
              ),
            );

          case ImageUploadState.completed:
            return _stateCircle(context, ButleryIcons.check);

          case ImageUploadState.failed:
            return _stateCircle(context, ButleryIcons.triangleAlert);

          case ImageUploadState.cancelled:
            return _stateCircle(context, ButleryIcons.x);
        }
      },
    );
  }

  /// The state circle over the photo scrim: an opaque paper disc with an ink
  /// glyph (B102), one look for every state so the glyph alone says which state
  /// it is.
  static Widget _stateCircle(BuildContext context, IconData icon) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppModeColors.surfacePaperOnPhoto(),
      ),
      child: ButleryIcon(
        icon,
        color: Theme.of(context).colorScheme.primary,
        size: AppDimensions.iconSizeL,
      ),
    );
  }

  /// Build action button for upload overlay
  static Widget buildUploadActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        // The destructive button keeps its red fill (R8-5 = B, BUT-2232):
        // action.danger, one opaque step darker while pressed.
        final fill = isDestructive
            ? context.modeColors.actionDanger
            : AppModeColors.surfacePaperOnPhoto();
        final ink = isDestructive
            ? context.modeColors.onActionDanger
            : cs.primary;
        return Semantics(
          button: true,
          child: Material(
            color: fill,
            borderRadius: BorderRadius.circular(AppDimensions.paddingS),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppDimensions.paddingS),
              // The paper button's press on a photo is not decided
              // (BUT-2232), so it keeps the unchanged fill it showed before.
              overlayColor: WidgetStatePropertyAll(
                isDestructive ? context.modeColors.actionDangerPressed : fill,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingM,
                  vertical: AppDimensions.paddingS,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ButleryIcon(
                      icon,
                      color: ink,
                      size: AppDimensions.iconSizeS,
                    ),
                    const SizedBox(width: AppDimensions.spacingXs),
                    Text(
                      label,
                      style: AppTextStyles.metadataEmphasized.copyWith(
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
