// lib/widgets/common/social/invitation_target_states.dart

import 'package:flutter/material.dart';
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
  static Widget targetCardLoading() {
    return const Card(
      child: ListTile(
        leading: CircularProgressIndicator(),
        title: Text('Laddar...'),
      ),
    );
  }

  /// Build target loading error state
  static Widget targetLoadingError({
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
            message ?? 'Kunde inte ladda mål',
            style: const TextStyle(color: AppColors.error),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppDimensions.spacingL),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Försök igen'),
            ),
          ],
        ],
      ),
    );
  }

  /// Build no targets available state
  static Widget noTargetsAvailable({
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
            message ?? 'Inga mål tillgängliga',
            style: const TextStyle(color: AppColors.textMedium),
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
  static Widget noSearchResults({
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
                ? 'Inga resultat för "$searchQuery"'
                : 'Inga sökresultat',
            style: const TextStyle(color: AppColors.textMedium),
          ),
          if (onClearSearch != null) ...[
            const SizedBox(height: AppDimensions.spacingL),
            TextButton(
              onPressed: onClearSearch,
              child: const Text('Rensa sökning'),
            ),
          ],
        ],
      ),
    );
  }

  /// Build targets selected success state
  static Widget targetsSelectedSuccess({
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
            '$count mål valda',
            style: const TextStyle(color: AppColors.success),
          ),
          if (onContinue != null) ...[
            const SizedBox(height: AppDimensions.spacingL),
            ElevatedButton(
              onPressed: onContinue,
              child: const Text('Fortsätt'),
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
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            title: Container(
              height: 16,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.neutralLight,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            subtitle: Container(
              height: 14,
              width: 100,
              decoration: BoxDecoration(
                color: AppColors.neutralLight,
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build empty selection state
  static Widget emptySelection({
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
            message ?? 'Inga val gjorda',
            style: const TextStyle(color: AppColors.textMedium),
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