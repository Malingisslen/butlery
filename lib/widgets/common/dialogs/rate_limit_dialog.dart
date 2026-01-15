import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';

/// Dialog shown when user hits a rate limit during import.
///
/// Provides:
/// - Clear explanation of what limit was hit
/// - Time until limit resets
/// - Alternative actions (manual import, try without AI, etc.)
class RateLimitDialog extends StatelessWidget {
  /// The rate limit denial details
  final RateLimitDenied rateLimitResult;

  /// Callback when user chooses to try without AI
  final VoidCallback? onTryWithoutAi;

  /// Callback when user chooses manual import
  final VoidCallback? onManualImport;

  const RateLimitDialog({
    super.key,
    required this.rateLimitResult,
    this.onTryWithoutAi,
    this.onManualImport,
  });

  /// Show the rate limit dialog and return the chosen action.
  static Future<FallbackAction?> show(
    BuildContext context, {
    required RateLimitDenied rateLimitResult,
    VoidCallback? onTryWithoutAi,
    VoidCallback? onManualImport,
  }) {
    return showDialog<FallbackAction>(
      context: context,
      barrierDismissible: true,
      builder: (context) => RateLimitDialog(
        rateLimitResult: rateLimitResult,
        onTryWithoutAi: onTryWithoutAi,
        onManualImport: onManualImport,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        _getIconForLimitType(rateLimitResult.limitType),
        color: AppColors.warning,
        size: AppDimensions.iconSizeXxl,
      ),
      title: Text(_getTitleForLimitType(rateLimitResult.limitType)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rateLimitResult.swedishMessage,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          _buildRetryInfo(),
          const SizedBox(height: AppDimensions.spacingL),
          _buildAlternativeActions(context),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Avbryt'),
        ),
        if (rateLimitResult.suggestedAction == FallbackAction.retryLater)
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(FallbackAction.retryLater),
            child: const Text('Försök senare'),
          ),
      ],
    );
  }

  Widget _buildRetryInfo() {
    final retryAfter = rateLimitResult.retryAfter;
    String timeText;

    if (retryAfter.inDays > 0) {
      timeText = 'Försök igen imorgon';
    } else if (retryAfter.inHours > 0) {
      timeText = 'Försök igen om ${retryAfter.inHours} timme(ar)';
    } else if (retryAfter.inMinutes > 0) {
      timeText = 'Försök igen om ${retryAfter.inMinutes} minut(er)';
    } else {
      timeText = 'Försök igen om ${retryAfter.inSeconds} sekund(er)';
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.timer_outlined,
            color: AppColors.warning,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              timeText,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativeActions(BuildContext context) {
    final actions = <Widget>[];

    // Show "Try without AI" option for LLM-related limits
    if (_isLlmLimit(rateLimitResult.limitType) && onTryWithoutAi != null) {
      actions.add(
        _ActionTile(
          icon: Icons.auto_fix_off_outlined,
          title: 'Importera utan AI',
          subtitle: 'Använder enklare extrahering',
          onTap: () {
            Navigator.of(context).pop(FallbackAction.skipLlm);
            onTryWithoutAi?.call();
          },
        ),
      );
    }

    // Show manual import option
    if (onManualImport != null) {
      actions.add(
        _ActionTile(
          icon: Icons.edit_outlined,
          title: 'Manuell import',
          subtitle: 'Markera ingredienser själv',
          onTap: () {
            Navigator.of(context).pop(FallbackAction.useUserAssisted);
            onManualImport?.call();
          },
        ),
      );
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alternativ:',
          style: AppTextStyles.metadataEmphasized.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingS),
        ...actions,
      ],
    );
  }

  bool _isLlmLimit(LimitType type) {
    return type == LimitType.llmDaily ||
        type == LimitType.llmMonthly ||
        type == LimitType.costDaily ||
        type == LimitType.costMonthly;
  }

  IconData _getIconForLimitType(LimitType type) {
    switch (type) {
      case LimitType.perMinute:
      case LimitType.perHour:
        return Icons.speed_outlined;
      case LimitType.perDay:
        return Icons.today_outlined;
      case LimitType.llmDaily:
      case LimitType.llmMonthly:
        return Icons.smart_toy_outlined;
      case LimitType.costDaily:
      case LimitType.costMonthly:
        return Icons.attach_money_outlined;
    }
  }

  String _getTitleForLimitType(LimitType type) {
    switch (type) {
      case LimitType.perMinute:
      case LimitType.perHour:
        return 'Sakta ner lite';
      case LimitType.perDay:
        return 'Dagskvot uppnådd';
      case LimitType.llmDaily:
      case LimitType.llmMonthly:
        return 'AI-gräns nådd';
      case LimitType.costDaily:
      case LimitType.costMonthly:
        return 'AI-budget förbrukad';
    }
  }
}

/// A tappable action tile for alternative actions.
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spacingM),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.primaryBlue,
              size: AppDimensions.iconSizeL,
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyBold,
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
