import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

class ParsedExtractionChips extends StatelessWidget {
  final ParsedMenuRequest? parsed;
  final VoidCallback? onRefinePrompt;

  const ParsedExtractionChips({
    super.key,
    required this.parsed,
    this.onRefinePrompt,
  });

  @override
  Widget build(BuildContext context) {
    if (parsed == null) return const SizedBox.shrink();
    final trace = parsed!.trace;
    if (trace.understood.isEmpty && trace.notUnderstood.isEmpty) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final colors = context.modeColors;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingM,
        vertical: AppDimensions.spacingXs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trace.understood.isNotEmpty) ...[
            Text(
              l10n.weeklyMenuChipsHeading,
              style: AppTextStyles.metadataEmphasized.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.space4),
            Wrap(
              spacing: AppDimensions.spacingXs,
              runSpacing: AppDimensions.space4,
              children: trace.understood
                  .map((e) => _UnderstoodChip(entry: e))
                  .toList(),
            ),
          ],
          if (trace.notUnderstood.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.space4),
            Text(
              l10n.weeklyMenuChipsNotUnderstood,
              style: AppTextStyles.metadataEmphasized.copyWith(
                color: AppModeColors.textWarning(scheme.brightness),
              ),
            ),
            const SizedBox(height: AppDimensions.space4),
            Wrap(
              spacing: AppDimensions.spacingXs,
              runSpacing: AppDimensions.space4,
              children: trace.notUnderstood
                  .map((t) => _NotUnderstoodChip(label: t))
                  .toList(),
            ),
          ],
          if (trace.hasGaps && onRefinePrompt != null) ...[
            const SizedBox(height: AppDimensions.space4),
            Semantics(
              label: l10n.a11yRefineMenuPrompt,
              button: true,
              child: GestureDetector(
                onTap: onRefinePrompt,
                child: ExcludeSemantics(
                  child: Text(
                    l10n.weeklyMenuChipsRefinePrompt,
                    style: AppTextStyles.linkSmall.copyWith(
                      color: colors.textLink,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnderstoodChip extends StatelessWidget {
  final TraceEntry entry;

  const _UnderstoodChip({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = context.modeColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space4,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: colors.successContainer,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Text(
        entry.label,
        style: AppTextStyles.captionText.copyWith(
          color: colors.onSuccessContainer,
        ),
      ),
    );
  }
}

class _NotUnderstoodChip extends StatelessWidget {
  final String label;

  const _NotUnderstoodChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.modeColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space4,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: colors.warningContainer,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ButleryIcon(
            ButleryIcons.circleHelp,
            size: AppDimensions.iconSizeS,
            color: colors.warning,
          ),
          const SizedBox(width: AppDimensions.space4),
          Text(
            label,
            style: AppTextStyles.captionText.copyWith(
              color: colors.onWarningContainer,
            ),
          ),
        ],
      ),
    );
  }
}
