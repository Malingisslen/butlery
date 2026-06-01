import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';

/// Invitation target state widgets.
class InvitationStates {
  /// Build target list loading state.
  static Widget targetListLoading({
    String? text,
  }) {
    return Builder(
      builder: (context) {
        final displayText = text ?? context.l10n.invitationLoadingTargets;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LoadingIndicator(),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(displayText),
            ],
          ),
        );
      },
    );
  }

  /// Build target card loading state
  static Widget targetCardLoading({
    int count = 3,
  }) {
    return Builder(
      builder: (context) => Column(
        children: List.generate(
            count,
            (index) => Card(
                  child: ListTile(
                    leading: const LoadingIndicator(),
                    title: Text(context.l10n.commonLoading),
                  ),
                )),
      ),
    );
  }

  /// Build inline loading state
  static Widget inlineLoading({
    String? text,
    double size = 20.0,
  }) {
    return Builder(
      builder: (context) {
        final displayText = text ?? context.l10n.commonLoading;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LoadingIndicator(size: size, strokeWidth: 2),
            const SizedBox(width: AppDimensions.spacingSm),
            Text(displayText),
          ],
        );
      },
    );
  }

  /// Build target loading error state.
  static Widget targetLoadingError(
    BuildContext context, {
    String? title,
    String? message,
    VoidCallback? onRetry,
    String? retryText,
    IconData errorIcon = Icons.error_outline,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(errorIcon,
              size: AppDimensions.iconSizeXXXl,
              color: Theme.of(context).colorScheme.error),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(title ?? context.l10n.invitationCouldNotLoadTargets,
              style: AppTextStyles.titleBold),
          Text(message ?? context.l10n.invitationCheckConnectionAndRetry,
              textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(retryText ?? context.l10n.commonRetry),
            ),
          ],
        ],
      ),
    );
  }

  /// Build network error state
  static Widget networkError(
    BuildContext context, {
    String? title,
    String? message,
    VoidCallback? onRetry,
    String? retryText,
  }) {
    return targetLoadingError(
      context,
      title: title ?? context.l10n.invitationNetworkError,
      message: message ?? context.l10n.invitationCheckConnection,
      onRetry: onRetry,
      retryText: retryText ?? context.l10n.commonRetry,
      errorIcon: Icons.wifi_off,
    );
  }

  /// Build permission error state
  static Widget permissionError(
    BuildContext context, {
    String? title,
    String? message,
    VoidCallback? onRequestAccess,
    String? requestText,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock,
              size: AppDimensions.iconSizeXXXl,
              color: context.butleryColors.warning),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(title ?? context.l10n.invitationNoAccessTitle,
              style: AppTextStyles.titleBold),
          Text(message ?? context.l10n.invitationNoAccessSubtitle,
              textAlign: TextAlign.center),
          if (onRequestAccess != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            ElevatedButton(
              onPressed: onRequestAccess,
              child: Text(requestText ?? context.l10n.invitationRequestAccess),
            ),
          ],
        ],
      ),
    );
  }

  /// Build no targets available state.
  static Widget noTargetsAvailable(
    BuildContext context, {
    String? title,
    String? message,
    IconData icon = Icons.group_outlined,
    VoidCallback? onAddTargets,
    String? addButtonText,
    bool showAddButton = true,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: AppDimensions.iconSizeXXXl,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(title ?? context.l10n.invitationNoTargetsAvailable,
              style: AppTextStyles.titleBold),
          Text(message ?? context.l10n.invitationNoFriendsOrGroupsYet,
              textAlign: TextAlign.center),
          if (showAddButton && onAddTargets != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            ElevatedButton(
              onPressed: onAddTargets,
              child: Text(addButtonText ?? context.l10n.shareAddFriends),
            ),
          ],
        ],
      ),
    );
  }

  /// Build no search results state
  static Widget noSearchResults(
    BuildContext context, {
    String? query,
    String? title,
    String? message,
    IconData icon = Icons.search_off,
    VoidCallback? onClearSearch,
    String? clearButtonText,
    bool showClearButton = true,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: AppDimensions.iconSizeXXXl,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(title ?? context.l10n.invitationNoSearchResults,
              style: AppTextStyles.titleBold),
          Text(message ?? context.l10n.invitationTryDifferentSearch,
              textAlign: TextAlign.center),
          if (query != null)
            Text(context.l10n.invitationSearchQuery(query),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontStyle: FontStyle.italic)),
          if (showClearButton && onClearSearch != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            TextButton(
              onPressed: onClearSearch,
              child:
                  Text(clearButtonText ?? context.l10n.invitationClearSearch),
            ),
          ],
        ],
      ),
    );
  }

  /// Build empty selection state
  static Widget emptySelection(
    BuildContext context, {
    String? title,
    String? message,
    IconData icon = Icons.checklist_outlined,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: AppDimensions.iconSizeXXXl,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(title ?? context.l10n.invitationNoSelectedTargets,
              style: AppTextStyles.titleBold),
          Text(message ?? context.l10n.invitationSelectTargetsToContinue,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  /// Build targets selected success state.
  static Widget targetsSelectedSuccess(
    BuildContext context, {
    required int selectedCount,
    String? title,
    String? message,
    IconData icon = Icons.check_circle_outline,
    VoidCallback? onContinue,
    String? continueButtonText,
    Color? successColor,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: AppDimensions.iconSizeXXXl,
              color: successColor ?? context.butleryColors.success),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(title ?? context.l10n.invitationTargetsLoaded,
              style: AppTextStyles.titleBold),
          Text(
            (message ??
                    context.l10n
                        .invitationTargetsSelectedForInvitation(selectedCount))
                .replaceAll('{count}', selectedCount.toString()),
            textAlign: TextAlign.center,
          ),
          if (onContinue != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            ElevatedButton(
              onPressed: onContinue,
              child: Text(continueButtonText ?? context.l10n.commonContinue),
            ),
          ],
        ],
      ),
    );
  }

  /// Build invitation sent success state
  static Widget invitationSentSuccess(
    BuildContext context, {
    required int sentCount,
    String? title,
    String? message,
    IconData icon = Icons.send,
    VoidCallback? onDone,
    String? doneButtonText,
    Color? successColor,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: AppDimensions.iconSizeXXXl,
              color: successColor ?? context.butleryColors.success),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(title ?? context.l10n.invitationsSentTitle,
              style: AppTextStyles.titleBold),
          Text(
            (message ?? context.l10n.invitationsSentMessage(sentCount))
                .replaceAll('{count}', sentCount.toString()),
            textAlign: TextAlign.center,
          ),
          if (onDone != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            ElevatedButton(
              onPressed: onDone,
              child: Text(doneButtonText ?? context.l10n.invitationDone),
            ),
          ],
        ],
      ),
    );
  }

  /// Build upload progress state.
  static Widget uploadProgress(
    BuildContext context, {
    required double progress, // 0.0 to 1.0
    String? title,
    String? subtitle,
    bool showPercentage = true,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingIndicator(
            size: 100,
            value: progress,
            strokeWidth: 8,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(title ?? context.l10n.invitationSendingInvitations,
              style: AppTextStyles.titleBold),
          if (showPercentage) Text('${(progress * 100).toInt()}%'),
          if (subtitle != null) Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  /// Build batch operation progress
  static Widget batchOperationProgress(
    BuildContext context, {
    required int completed,
    required int total,
    String? operationName,
    String? currentItem,
  }) {
    final progress = total > 0 ? completed / total : 0.0;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            '${operationName ?? context.l10n.invitationProcessing} $completed/$total',
            style: AppTextStyles.contentTitle,
          ),
          if (currentItem != null) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              context.l10n.invitationCurrentItem(currentItem),
              style: AppTextStyles.bodyMediumMuted,
            ),
          ],
        ],
      ),
    );
  }
}
