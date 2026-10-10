import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/tappable_wrapper.dart';

/// What a status badge reports. It picks the notice tint and the one
/// on-colour that reads on it, so a badge never mixes a status colour with a
/// fill it was not measured on.
enum TagStatusTone {
  /// A free or confirmed status: the success tint.
  success,

  /// A health risk: the danger tint.
  danger,

  /// A factual or unknown status that is neither: the raised surface.
  neutral,
}

({Color fill, Color onColor}) _toneColors(
  BuildContext context,
  TagStatusTone tone,
) {
  final cs = Theme.of(context).colorScheme;
  final modeColors = context.modeColors;
  switch (tone) {
    case TagStatusTone.success:
      return (
        fill: modeColors.surfaceTintSuccess,
        onColor: modeColors.onSuccessContainer,
      );
    case TagStatusTone.danger:
      return (
        fill: modeColors.surfaceTintDanger,
        onColor: cs.onErrorContainer,
      );
    case TagStatusTone.neutral:
      return (
        fill: cs.surfaceContainerHighest,
        onColor: cs.onSurfaceVariant,
      );
  }
}

/// Shared badge widget used by both AllergenStatusBadge and DietaryStatusBadge.
/// A notice-style chip (B83-2): the tint with no border, icon + label +
/// optional info tap in the matching on-colour.
class TagStatusBadge extends StatelessWidget {
  final TagStatusTone tone;
  final IconData icon;
  final String? label;
  final String semanticLabel;
  final VoidCallback? onInfoTap;

  const TagStatusBadge({
    super.key,
    required this.tone,
    required this.icon,
    required this.semanticLabel,
    this.label,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final (:fill, :onColor) = _toneColors(context, tone);
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space8,
          vertical: AppDimensions.space4,
        ),
        decoration: BoxDecoration(color: fill),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ButleryIcon(
              icon,
              size: AppDimensions.iconSize18,
              color: onColor,
              semanticLabel: null,
            ),
            if (label != null) ...[
              const SizedBox(width: AppDimensions.space4),
              ExcludeSemantics(
                child: Text(
                  label!,
                  style: AppTextStyles.metadataEmphasized.copyWith(
                    color: onColor,
                  ),
                ),
              ),
            ],
            if (onInfoTap != null) ...[
              const SizedBox(width: AppDimensions.space4),
              TappableWrapper(
                onTap: onInfoTap,
                semanticLabel: context.l10n.a11yTagStatusInfo,
                child: ButleryIcon(
                  ButleryIcons.info,
                  size: AppDimensions.iconSize14,
                  color: onColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact variant of TagStatusBadge for recipe cards.
class TagStatusBadgeCompact extends StatelessWidget {
  final TagStatusTone tone;
  final IconData icon;
  final String? label;
  final String semanticLabel;

  const TagStatusBadgeCompact({
    super.key,
    required this.tone,
    required this.icon,
    required this.semanticLabel,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final (:fill, :onColor) = _toneColors(context, tone);
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space4,
          vertical: AppDimensions.space4,
        ),
        decoration: BoxDecoration(color: fill),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ButleryIcon(
              icon,
              size: AppDimensions.iconSize14,
              color: onColor,
              semanticLabel: null,
            ),
            if (label != null) ...[
              const SizedBox(width: AppDimensions.spacingXs),
              ExcludeSemantics(
                child: Text(
                  label!,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: onColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
