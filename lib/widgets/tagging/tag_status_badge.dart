import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/tappable_wrapper.dart';

/// Shared badge widget used by both AllergenStatusBadge and DietaryStatusBadge.
/// Left-border style with tinted background, icon + label + optional info tap.
class TagStatusBadge extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String? label;
  final String semanticLabel;
  final VoidCallback? onInfoTap;

  const TagStatusBadge({
    super.key,
    required this.color,
    required this.icon,
    required this.semanticLabel,
    this.label,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMs,
          vertical: AppDimensions.spacing6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppDimensions.opacityVeryLight),
          border: Border.all(
            color: color,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppDimensions.iconSize18,
              color: color,
              semanticLabel: null,
            ),
            if (label != null) ...[
              const SizedBox(width: AppDimensions.spacing6),
              ExcludeSemantics(
                child: Text(
                  label!,
                  style: AppTextStyles.metadataEmphasized.copyWith(
                    color: color,
                  ),
                ),
              ),
            ],
            if (onInfoTap != null) ...[
              const SizedBox(width: AppDimensions.spacing6),
              TappableWrapper(
                onTap: onInfoTap,
                semanticLabel: context.l10n.a11yTagStatusInfo(semanticLabel),
                child: Icon(
                  Icons.info_outline,
                  size: AppDimensions.iconSize14,
                  color: color,
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
  final Color color;
  final IconData icon;
  final String? label;
  final String semanticLabel;

  const TagStatusBadgeCompact({
    super.key,
    required this.color,
    required this.icon,
    required this.semanticLabel,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing6,
          vertical: AppDimensions.spacingS,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppDimensions.opacityVeryLight),
          border: Border.all(
            color: color,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppDimensions.iconSize14,
              color: color,
              semanticLabel: null,
            ),
            if (label != null) ...[
              const SizedBox(width: AppDimensions.spacingXs),
              ExcludeSemantics(
                child: Text(
                  label!,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: color,
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
