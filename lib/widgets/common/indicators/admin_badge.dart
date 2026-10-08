import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Reusable admin badge indicator for groups and collaborative content.
class AdminBadge extends StatelessWidget {
  final String? label;
  final IconData icon;

  const AdminBadge({
    super.key,
    this.label,
    this.icon = ButleryIcons.crown,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      // A neutral info chip with no border (B83-2).
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ButleryIcon(
            icon,
            size: AppDimensions.iconSizeS,
            color: cs.onSurface,
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            label ?? context.l10n.adminYouAreAdmin,
            style: AppTextStyles.labelMedium.copyWith(
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
