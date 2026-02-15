import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Reusable admin badge indicator for groups and collaborative content.
class AdminBadge extends StatelessWidget {
  final String? label;

  const AdminBadge({
    super.key,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.admin_panel_settings,
            size: AppDimensions.iconSizeS,
            color: cs.primary,
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            label ?? context.l10n.adminYouAreAdmin,
            style: AppTextStyles.bodyBold.copyWith(
              color: cs.primary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
