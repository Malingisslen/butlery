import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_tap_target.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:flutter/material.dart';

class TagCoverageSection extends StatelessWidget {
  final TagResult tagResult;
  final bool compact;
  final VoidCallback? onUnknownIngredientsTap;

  const TagCoverageSection({
    super.key,
    required this.tagResult,
    required this.compact,
    this.onUnknownIngredientsTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final coveragePercent = (tagResult.coverage * 100).round();
    final hasUnknowns = tagResult.hasUnknowns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ButleryIcon(
              ButleryIcons.barChart,
              color: cs.onSurface,
              size: compact ? AppDimensions.iconSizeS : AppDimensions.iconSizeM,
            ),
            const SizedBox(width: AppDimensions.space4),
            Text(
              context.l10n.tagResultCoverage,
              style: compact
                  ? AppTextStyles.titleSmall
                  : AppTextStyles.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space4),
        Row(
          children: [
            Expanded(
              child: ExcludeSemantics(
                child: PlateLine(value: tagResult.coverage),
              ),
            ),
            const SizedBox(width: AppDimensions.space8),
            Text(
              '$coveragePercent%',
              style: AppTextStyles.bodyBold.copyWith(
                color: _getCoverageColor(context),
              ),
            ),
          ],
        ),
        if (hasUnknowns) ...[
          const SizedBox(height: AppDimensions.space4),
          _buildUnknownIngredientsRow(context),
        ],
      ],
    );
  }

  Widget _buildUnknownIngredientsRow(BuildContext context) {
    final onTap = onUnknownIngredientsTap;
    final label = context.l10n.tagResultUnknownIngredientsA11y(
      tagResult.unknownIngredients.length,
    );
    final row = Row(
      children: [
        ButleryIcon(
          ButleryIcons.triangleAlert,
          size: AppDimensions.iconSizeS,
          color: context.modeColors.warning,
        ),
        const SizedBox(width: AppDimensions.space4),
        Expanded(
          child: Text(
            context.l10n.tagResultUnknownIngredients(
              tagResult.unknownIngredients.length,
            ),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppModeColors.textWarning(Theme.of(context).brightness),
            ),
          ),
        ),
        if (onTap != null) ButleryChevron(color: context.modeColors.warning),
      ],
    );
    // The label says what the visible text says; reading both would announce
    // the count twice.
    final quiet = ExcludeSemantics(child: row);
    if (onTap == null) return Semantics(label: label, child: quiet);
    return ButleryTapTarget(semanticLabel: label, onTap: onTap, child: quiet);
  }

  Color _getCoverageColor(BuildContext context) {
    // Mostly-full bar should read as "positive" visually, so we grade
    // generously: 80%+ is green, 40%+ amber, rust-red only for genuinely
    // incomplete coverage. Previously 80–99% showed as amber and anything
    // below 80% rendered rust-red — a nearly-full red bar misleads.
    if (tagResult.coverage >= 0.8) return context.modeColors.success;
    if (tagResult.coverage >= 0.4) {
      return AppModeColors.textWarning(Theme.of(context).brightness);
    }
    return Theme.of(context).colorScheme.error;
  }
}
