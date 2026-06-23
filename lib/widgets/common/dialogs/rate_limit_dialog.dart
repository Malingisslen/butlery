import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
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
        color: context.butleryColors.warning,
        size: AppDimensions.iconSizeXxl,
      ),
      title: Text(_getTitleForLimitType(context, rateLimitResult.limitType)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rateLimitResult.swedishMessage,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          _buildRetryInfo(context),
          const SizedBox(height: AppDimensions.spacingL),
          _buildAlternativeActions(context),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(context.l10n.commonCancel),
        ),
        if (rateLimitResult.suggestedAction == FallbackAction.retryLater)
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(FallbackAction.retryLater),
            child: Text(context.l10n.dialogRetryLater),
          ),
      ],
    );
  }

  Widget _buildRetryInfo(BuildContext context) {
    final retryAfter = rateLimitResult.retryAfter;
    String timeText;

    if (retryAfter.inDays > 0) {
      timeText = context.l10n.dialogRetryTomorrow;
    } else if (retryAfter.inHours > 0) {
      timeText = context.l10n.dialogRetryInHours(retryAfter.inHours);
    } else if (retryAfter.inMinutes > 0) {
      timeText = context.l10n.dialogRetryInMinutes(retryAfter.inMinutes);
    } else {
      timeText = context.l10n.dialogRetryInSeconds(retryAfter.inSeconds);
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
      decoration: BoxDecoration(
        color: context.butleryColors.warning.withValues(
          alpha: AppDimensions.opacityVeryLight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            color: context.butleryColors.warning,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              timeText,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          title: context.l10n.dialogImportWithoutAi,
          subtitle: context.l10n.dialogUsesSimpleExtraction,
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
          title: context.l10n.dialogManualImport,
          subtitle: context.l10n.dialogMarkIngredientsYourself,
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
          context.l10n.dialogAlternatives,
          style: AppTextStyles.metadataEmphasized.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  String _getTitleForLimitType(BuildContext context, LimitType type) {
    switch (type) {
      case LimitType.perMinute:
      case LimitType.perHour:
        return context.l10n.rateLimitSlowDown;
      case LimitType.perDay:
        return context.l10n.rateLimitDailyQuota;
      case LimitType.llmDaily:
      case LimitType.llmMonthly:
        return context.l10n.rateLimitAiLimit;
      case LimitType.costDaily:
      case LimitType.costMonthly:
        return context.l10n.rateLimitAiBudget;
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
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: title,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.spacingM),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: cs.primary,
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
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
