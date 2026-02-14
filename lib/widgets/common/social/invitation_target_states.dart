// lib/widgets/common/social/invitation_target_states.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

class InvitationTargetStates {
  /// Build target list loading state
  static Widget targetListLoading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  /// Build target card loading state
  static Widget targetCardLoading(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircularProgressIndicator(),
        title: Text(context.l10n.commonLoading),
      ),
    );
  }

  /// Build target loading error state
  static Widget targetLoadingError(
    BuildContext context, {
    String? message,
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: AppDimensions.spacingL),
          Text(
            message ?? context.l10n.invitationCouldNotLoadTargets,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.error,
                ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppDimensions.spacingL),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ],
      ),
    );
  }

  /// Build no targets available state
  static Widget noTargetsAvailable(
    BuildContext context, {
    String? message,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.people_outline,
            size: 48,
            color: AppColors.textMedium,
          ),
          const SizedBox(height: AppDimensions.spacingL),
          Text(
            message ?? context.l10n.invitationNoTargetsAvailable,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMedium,
                ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: AppDimensions.spacingL),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  /// Build no search results state
  static Widget noSearchResults(
    BuildContext context, {
    String? searchQuery,
    VoidCallback? onClearSearch,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 48,
            color: AppColors.textMedium,
          ),
          const SizedBox(height: AppDimensions.spacingL),
          Text(
            searchQuery != null
                ? context.l10n.invitationNoResultsFor(searchQuery)
                : context.l10n.invitationNoSearchResults,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMedium,
                ),
          ),
          if (onClearSearch != null) ...[
            const SizedBox(height: AppDimensions.spacingL),
            TextButton(
              onPressed: onClearSearch,
              child: Text(context.l10n.invitationClearSearch),
            ),
          ],
        ],
      ),
    );
  }

  /// Build targets selected success state
  static Widget targetsSelectedSuccess(
    BuildContext context, {
    required int count,
    VoidCallback? onContinue,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            size: 48,
            color: AppColors.success,
          ),
          const SizedBox(height: AppDimensions.spacingL),
          Text(
            context.l10n.invitationTargetsSelectedCount(count),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.success,
                ),
          ),
          if (onContinue != null) ...[
            const SizedBox(height: AppDimensions.spacingL),
            ElevatedButton(
              onPressed: onContinue,
              child: Text(context.l10n.commonContinue),
            ),
          ],
        ],
      ),
    );
  }

  /// Build skeleton loading state
  static Widget targetListSkeleton({int itemCount = 5}) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.neutralLight,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadius20),
              ),
            ),
            title: Container(
              height: 16,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.neutralLight,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadius8),
              ),
            ),
            subtitle: Container(
              height: 14,
              width: 100,
              decoration: BoxDecoration(
                color: AppColors.neutralLight,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadius7),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build empty selection state
  static Widget emptySelection(
    BuildContext context, {
    String? message,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.checklist,
            size: 48,
            color: AppColors.textMedium,
          ),
          const SizedBox(height: AppDimensions.spacingL),
          Text(
            message ?? context.l10n.invitationNoSelectionsMade,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMedium,
                ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: AppDimensions.spacingL),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}
