/// Header card for the tag detail view showing tag name and usage stats.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Displays the tag icon, name, recipe count, and active rules count.
class TagDetailHeader extends StatelessWidget {
  final PersonalTag tag;
  final int usageCount;

  const TagDetailHeader({
    super.key,
    required this.tag,
    required this.usageCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: colorScheme.primary
                  .withValues(alpha: AppDimensions.opacityLight),
              child: Icon(
                Icons.label,
                color: colorScheme.primary,
                size: 32,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tag.name, style: AppTextStyles.titleLarge),
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    context.l10n.tagDetailRecipeCount(usageCount),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (tag.rules.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      context.l10n.tagDetailRulesActive(
                        tag.rules.where((r) => r.isEnabled).length,
                        tag.rules.length,
                      ),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
