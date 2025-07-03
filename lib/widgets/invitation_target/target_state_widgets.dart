// lib/widgets/invitation_target/target_state_widgets.dart

import 'package:flutter/material.dart';
import '../../models/invitations/invitation_target.dart';
import '../../theme/app_theme.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Target State Widgets - UI komponenter för olika states av InvitationTarget
/// File: widgets/invitation_target/target_state_widgets.dart
/// Quick Guide: Widget builders för loading, error, empty states - använder BARA AppTheme
/// Dependencies IN: InvitationTarget, AppTheme
/// Dependencies OUT: UI screens, dialogs, lists
/// Data flow: State information → Widget builders → Styled state components
/// State management: Stateless widgets som visar olika tillstånd
/// Purpose: Separation of concerns - state UI komponenter använder centraliserad AppTheme
/// Common issues: Ensure consistent state messaging and styling
/// Test coverage: 0% (UI widgets)
/// Performance: ⚡ Efficient rendering, static widgets
/// Analytics: N/A - UI widgets
/// Code smells: ✅ Single responsibility - bara state visning med AppTheme
/// Connected to: InvitationTarget, AppTheme, various UI screens
/// Used in phases: Fas 1 (Grundinfrastruktur) - UI foundation

/// Widget builders för olika states av InvitationTarget komponenter
///
/// Denna klass innehåller BARA state-relaterade widgets som:
/// - Visar loading states
/// - Visar error states
/// - Visar empty states
/// - Visar success states
/// - Använder AppTheme för ALL styling
class TargetStateWidgets {
  // ===== LOADING STATES =====

  /// Bygg loading state för target lists
  static Widget buildTargetListLoading(BuildContext context) {
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

  /// Bygg loading state för target cards
  static Widget buildTargetCardLoading(BuildContext context) {
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

  /// Bygg loading state för target selection
  static Widget buildTargetSelectionLoading(BuildContext context) {
    return Column(
      children: [
        // Search field loading
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: AppTheme.mediumRadius,
          ),
        ),
        AppTheme.mediumGap,

        // List loading
        ...List.generate(
          3,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacingXs),
            child: buildTargetCardLoading(context),
          ),
        ),
      ],
    );
  }

  // ===== ERROR STATES =====

  /// Bygg error state för target loading
  static Widget buildTargetLoadingError(
    BuildContext context, {
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
                foregroundColor: Colors.white,
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

  /// Bygg error state för target operations
  static Widget buildTargetOperationError(
    BuildContext context, {
    required String operation,
    String? errorMessage,
    VoidCallback? onDismiss,
  }) {
    return Container(
      margin: EdgeInsets.all(AppTheme.spacingMd),
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.errorColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error,
            color: AppTheme.errorColor,
            size: AppTheme.iconSizeAction,
          ),
          AppTheme.smallHorizontalGap,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fel vid $operation',
                  style: AppTheme.errorTextStyle,
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    errorMessage,
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.errorColor.withValues(alpha: 0.8),
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
                color: AppTheme.errorColor,
                size: AppTheme.iconSizeInfo,
              ),
            ),
        ],
      ),
    );
  }

  // ===== EMPTY STATES =====

  /// Bygg empty state för targets (inga tillgängliga)
  static Widget buildNoTargetsAvailable(BuildContext context) {
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

  /// Bygg empty state för search results
  static Widget buildNoSearchResults(
    BuildContext context, {
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

  /// Bygg empty state för selected targets
  static Widget buildNoTargetsSelected(BuildContext context) {
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

  /// Bygg success state för target operations
  static Widget buildTargetOperationSuccess(
    BuildContext context, {
    required String operation,
    String? successMessage,
    VoidCallback? onDismiss,
    Duration? autoDismiss,
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

  /// Bygg success state för target selection
  static Widget buildTargetsSelectedSuccess(
    BuildContext context, {
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
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.mediumRadius,
                ),
              ),
              child: Text(
                'Fortsätt',
                style: AppTheme.buttonTextStyle.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===== WARNING STATES =====

  /// Bygg warning state för target limitations
  static Widget buildTargetLimitationWarning(
    BuildContext context, {
    required String limitation,
    String? description,
    VoidCallback? onUnderstand,
  }) {
    return Container(
      margin: EdgeInsets.all(AppTheme.spacingMd),
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.warningColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning,
                color: AppTheme.warningColor,
                size: AppTheme.iconSizeAction,
              ),
              AppTheme.smallHorizontalGap,
              Expanded(
                child: Text(
                  limitation,
                  style: AppTheme.warningTextStyle,
                ),
              ),
            ],
          ),
          if (description != null) ...[
            AppTheme.smallGap,
            Padding(
              padding: EdgeInsets.only(
                  left: AppTheme.iconSizeAction + AppTheme.spacingSm),
              child: Text(
                description,
                style: AppTheme.captionStyle.copyWith(
                  color: AppTheme.warningColor.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
          if (onUnderstand != null) ...[
            AppTheme.mediumGap,
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onUnderstand,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.warningColor,
                ),
                child: Text(
                  'Förstått',
                  style: AppTheme.buttonTextStyle.copyWith(
                    color: AppTheme.warningColor,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===== PERMISSION STATES =====

  /// Bygg permission required state
  static Widget buildPermissionRequired(
    BuildContext context, {
    required String permission,
    String? description,
    VoidCallback? onRequestPermission,
  }) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingXl),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Icon(
            Icons.lock_outline,
            size: AppTheme.iconSizeEmptyState,
            color: AppTheme.warningColor,
          ),
          AppTheme.mediumGap,
          Text(
            'Behörighet krävs',
            style: AppTheme.sectionTitleStyle.copyWith(
              color: AppTheme.warningColor,
            ),
          ),
          AppTheme.smallGap,
          Text(
            permission,
            style: AppTheme.subtitleStyle,
            textAlign: TextAlign.center,
          ),
          if (description != null) ...[
            AppTheme.smallGap,
            Text(
              description,
              style: AppTheme.captionStyle,
              textAlign: TextAlign.center,
            ),
          ],
          if (onRequestPermission != null) ...[
            AppTheme.mediumGap,
            ElevatedButton.icon(
              onPressed: onRequestPermission,
              icon: Icon(
                Icons.security,
                size: AppTheme.iconSizeAction,
              ),
              label: Text(
                'Begär behörighet',
                style: AppTheme.buttonTextStyle,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningColor,
                foregroundColor: Colors.white,
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

  // ===== UTILITY BUILDERS =====

  /// Bygg allmän information state
  static Widget buildInfoState(
    BuildContext context, {
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
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.mediumRadius,
                ),
              ),
              child: Text(
                actionLabel,
                style: AppTheme.buttonTextStyle.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
