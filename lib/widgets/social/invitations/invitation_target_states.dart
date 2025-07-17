// lib/widgets/social/invitations/invitation_target_states.dart

import 'package:flutter/material.dart';
import '../../../models/invitations/invitation_target.dart';
import '../../../theme/app_theme.dart';

/// Invitation target state widgets
///
/// This module provides widgets for different states of invitation target components
/// including loading, error, empty, and success states.
class InvitationTargetStates {
  // ===== LOADING STATES =====

  /// Build loading state for target lists
  static Widget buildTargetListLoading() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingXl),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          AppTheme.mediumLoadingIndicator(),
          AppTheme.mediumGap,
          Text(
            'Laddar mål...',
            style: AppTheme.subtitleStyle,
          ),
        ],
      ),
    );
  }

  /// Build loading state for target cards
  static Widget buildTargetCardLoading() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      padding: AppTheme.cardPadding,
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          // Loading emoji container
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: AppTheme.smallRadius,
            ),
            child: Center(
              child: AppTheme.smallLoadingIndicator(),
            ),
          ),
          AppTheme.smallHorizontalGap,

          // Loading text placeholders
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: AppTheme.smallRadius,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 12,
                  width: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: AppTheme.smallRadius,
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
              color: AppTheme.backgroundColor,
              borderRadius: AppTheme.smallRadius,
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
      padding: EdgeInsets.all(AppTheme.spacingXl),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: AppTheme.iconSizeEmptyState,
            color: AppTheme.errorColor,
          ),
          AppTheme.mediumGap,
          Text(
            'Kunde inte ladda mål',
            style: AppTheme.sectionTitleStyle.copyWith(
              color: AppTheme.errorColor,
            ),
          ),
          if (errorMessage != null) ...[
            AppTheme.smallGap,
            Text(
              errorMessage,
              style: AppTheme.subtitleStyle,
              textAlign: TextAlign.center,
            ),
          ],
          if (onRetry != null) ...[
            AppTheme.mediumGap,
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(
                Icons.refresh,
                size: AppTheme.iconSizeAction,
              ),
              label: Text(
                'Försök igen',
                style: AppTheme.buttonTextStyle,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: AppTheme.neutralLight,
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.mediumRadius,
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
      padding: EdgeInsets.all(AppTheme.spacingXl),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: AppTheme.iconSizeEmptyState,
            color: AppTheme.textTertiary,
          ),
          AppTheme.mediumGap,
          Text(
            'Inga mål tillgängliga',
            style: AppTheme.sectionTitleStyle.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
          AppTheme.smallGap,
          Text(
            'Lägg till vänner eller skapa grupper för att börja dela',
            style: AppTheme.subtitleStyle,
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
      padding: EdgeInsets.all(AppTheme.spacingXl),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: AppTheme.iconSizeEmptyState,
            color: AppTheme.textTertiary,
          ),
          AppTheme.mediumGap,
          Text(
            'Inga träffar',
            style: AppTheme.sectionTitleStyle.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
          AppTheme.smallGap,
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTheme.subtitleStyle,
              children: [
                const TextSpan(text: 'Ingen träff för '),
                TextSpan(
                  text: '"$searchQuery"',
                  style: AppTheme.subtitleStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: '\nPröva ett annat sökord'),
              ],
            ),
          ),
          if (onClearSearch != null) ...[
            AppTheme.mediumGap,
            TextButton.icon(
              onPressed: onClearSearch,
              icon: Icon(
                Icons.clear,
                size: AppTheme.iconSizeAction,
              ),
              label: Text(
                'Rensa sökning',
                style: AppTheme.buttonTextStyle,
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
      padding: EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
          color: AppTheme.dividerColor,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.touch_app,
            size: AppTheme.iconSizeDisplay,
            color: AppTheme.textTertiary,
          ),
          AppTheme.smallGap,
          Text(
            'Inga mål valda',
            style: AppTheme.cardTitleStyle.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tryck på mål nedan för att välja',
            style: AppTheme.captionStyle,
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
      margin: EdgeInsets.all(AppTheme.spacingMd),
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.successColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: AppTheme.successColor,
            size: AppTheme.iconSizeAction,
          ),
          AppTheme.smallHorizontalGap,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  operation,
                  style: AppTheme.successTextStyle,
                ),
                if (successMessage != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    successMessage,
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.successColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: Icon(
                Icons.close,
                color: AppTheme.successColor,
                size: AppTheme.iconSizeInfo,
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
      padding: EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.successColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle,
            size: AppTheme.iconSizeDisplay,
            color: AppTheme.successColor,
          ),
          AppTheme.smallGap,
          Text(
            '${targets.length} mål valda',
            style: AppTheme.cardTitleStyle.copyWith(
              color: AppTheme.successColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Du kan nu fortsätta med delningen',
            style: AppTheme.captionStyle.copyWith(
              color: AppTheme.successColor.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
          if (onContinue != null) ...[
            AppTheme.mediumGap,
            ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: AppTheme.neutralLight,
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.mediumRadius,
                ),
              ),
              child: Text(
                'Fortsätt',
                style: AppTheme.buttonTextStyle.copyWith(
                  color: AppTheme.neutralLight,
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
    final stateColor = color ?? AppTheme.textSecondary;

    return Container(
      padding: EdgeInsets.all(AppTheme.spacingXl),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Icon(
            icon,
            size: AppTheme.iconSizeEmptyState,
            color: stateColor,
          ),
          AppTheme.mediumGap,
          Text(
            title,
            style: AppTheme.sectionTitleStyle.copyWith(
              color: stateColor,
            ),
          ),
          AppTheme.smallGap,
          Text(
            message,
            style: AppTheme.subtitleStyle,
            textAlign: TextAlign.center,
          ),
          if (onAction != null && actionLabel != null) ...[
            AppTheme.mediumGap,
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: stateColor,
                foregroundColor: AppTheme.neutralLight,
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.mediumRadius,
                ),
              ),
              child: Text(
                actionLabel,
                style: AppTheme.buttonTextStyle.copyWith(
                  color: AppTheme.neutralLight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}