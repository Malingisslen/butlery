// lib/widgets/social/invitations/invitation_target_states.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Invitation target state widgets
///
/// This module provides widgets for different states of invitation target components
/// including loading, error, empty, and success states.
class InvitationTargetStates {
  // ===== LOADING STATES =====

  /// Build loading state for target lists
  static Widget buildTargetListLoading() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: AppDimensions.spacingXl),
          Text(
            'Laddar mål...',
            style: AppTextStyles.titleMedium,
          ),
        ],
      ),
    );
  }

  /// Build loading state for target cards
  static Widget buildTargetCardLoading() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: AppDimensions.spacingXs,
      ),
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          // Loading emoji container
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            ),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingM),

          // Loading text placeholders
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 12,
                  width: 120,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                  ),
                ),
              ],
            ),
          ),

          // Loading icon
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            ),
          ),
        ],
      ),
    );
  }

  // ===== ERROR STATES =====

  /// Build error state for target loading
  static Widget buildTargetLoadingError({
    String? errorMessage,
    VoidCallback? onRetry,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            size: AppDimensions.iconSizeEmptyState,
            color: AppColors.error,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            'Kunde inte ladda mål',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.error,
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              errorMessage,
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: AppDimensions.spacingXl),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh,
                size: AppDimensions.iconSizeAction,
              ),
              label: const Text(
                'Försök igen',
                style: AppTextStyles.labelLarge,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.neutralLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===== EMPTY STATES =====

  /// Build empty state for targets (no available targets)
  static Widget buildNoTargetsAvailable() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.people_outline,
            size: AppDimensions.iconSizeEmptyState,
            color: AppColors.textMedium,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            'Inga mål tillgängliga',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          const Text(
            'Lägg till vänner eller skapa grupper för att börja dela',
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build empty state for search results
  static Widget buildNoSearchResults({
    required String searchQuery,
    VoidCallback? onClearSearch,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off,
            size: AppDimensions.iconSizeEmptyState,
            color: AppColors.textMedium,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            'Inga träffar',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTextStyles.titleMedium,
              children: [
                const TextSpan(text: 'Ingen träff för '),
                TextSpan(
                  text: '"$searchQuery"',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: '\nPröva ett annat sökord'),
              ],
            ),
          ),
          if (onClearSearch != null) ...[
            const SizedBox(height: AppDimensions.spacingXl),
            TextButton.icon(
              onPressed: onClearSearch,
              icon: const Icon(
                Icons.clear,
                size: AppDimensions.iconSizeAction,
              ),
              label: const Text(
                'Rensa sökning',
                style: AppTextStyles.labelLarge,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build empty state for selected targets
  static Widget buildNoTargetsSelected() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
          color: AppColors.divider,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.touch_app,
            size: AppDimensions.iconSizeDisplay,
            color: AppColors.textMedium,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            'Inga mål valda',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tryck på mål nedan för att välja',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ===== SUCCESS STATES =====

  /// Build success state for target operations
  static Widget buildTargetOperationSuccess({
    required String operation,
    String? successMessage,
    VoidCallback? onDismiss,
  }) {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.spacingL),
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.success),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: AppDimensions.iconSizeAction,
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  operation,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.success,
                  ),
                ),
                if (successMessage != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    successMessage,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.success.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(
                Icons.close,
                color: AppColors.success,
                size: AppDimensions.iconSizeM,
              ),
            ),
        ],
      ),
    );
  }

  /// Build success state for target selection
  static Widget buildTargetsSelectedSuccess({
    required List<InvitationTarget> targets,
    VoidCallback? onContinue,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.success),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle,
            size: AppDimensions.iconSizeDisplay,
            color: AppColors.success,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            '${targets.length} mål valda',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Du kan nu fortsätta med delningen',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.success.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
          if (onContinue != null) ...[
            const SizedBox(height: AppDimensions.spacingXl),
            ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.neutralLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                ),
              ),
              child: Text(
                'Fortsätt',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.neutralLight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===== UTILITY BUILDERS =====

  /// Build general information state
  static Widget buildInfoState({
    required IconData icon,
    required String title,
    required String message,
    VoidCallback? onAction,
    String? actionLabel,
    Color? color,
  }) {
    final stateColor = color ?? AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: AppDimensions.iconSizeEmptyState,
            color: stateColor,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            title,
            style: AppTextStyles.titleLarge.copyWith(
              color: stateColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            message,
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: AppDimensions.spacingXl),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: stateColor,
                foregroundColor: AppColors.neutralLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                ),
              ),
              child: Text(
                actionLabel,
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.neutralLight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}