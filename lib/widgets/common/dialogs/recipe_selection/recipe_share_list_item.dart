import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';

/// One recipe in the friend and group sharing dialogs: tap or tick to
/// select it; a recipe already shared shows the success badge.
class RecipeShareListItem extends StatelessWidget {
  final Recipe recipe;
  final bool isSelected;
  final bool isAlreadyShared;
  final ValueChanged<bool> onSelectionChanged;

  const RecipeShareListItem({
    super.key,
    required this.recipe,
    required this.isSelected,
    required this.isAlreadyShared,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space12,
      ),
      leading: recipe.imageUrls.isNotEmpty
          ? NetworkImageWidget(
              imageUrl: recipe.imageUrls.first,
              width: AppDimensions.iconSizeXl,
              height: AppDimensions.iconSizeXl,
              fit: BoxFit.contain,
              borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
              errorWidget: _buildPlaceholder(context),
            )
          : _buildPlaceholder(context),
      title: Row(
        children: [
          Expanded(
            child: Text(
              recipe.title,
              style: isAlreadyShared
                  ? AppTextStyles.titleMedium
                  : AppTextStyles.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isAlreadyShared)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space4,
                vertical: AppDimensions.space4,
              ),
              decoration: BoxDecoration(
                color: context.modeColors.surfaceTintSuccess,
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                context.l10n.dialogAlreadyShared,
                style: AppTextStyles.labelSmallSuccess.copyWith(
                  color: context.modeColors.onSuccessContainer,
                ),
              ),
            ),
        ],
      ),
      subtitle: _buildSubtitle(context),
      trailing: ButleryCheckbox(
        value: isSelected,
        onChanged: onSelectionChanged,
      ),
      onTap: () => onSelectionChanged(!isSelected),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final successColor = context.modeColors.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe.mealType,
          style: isAlreadyShared
              ? AppTextStyles.labelMedium.copyWith(
                  color: cs.onSurfaceVariant,
                )
              : AppTextStyles.labelMedium.copyWith(
                  color: cs.onSurface,
                ),
        ),
        if (recipe.description.isNotEmpty)
          Text(
            recipe.description,
            style: isAlreadyShared
                ? AppTextStyles.labelMedium
                : AppTextStyles.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: AppDimensions.space4),
        Row(
          children: [
            if (recipe.timeMinutes != null) ...[
              ButleryIcon(
                ButleryIcons.clock,
                size: AppDimensions.iconSizeM,
                color: isAlreadyShared ? successColor : cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppDimensions.space4),
              Text(
                '${recipe.timeMinutes} min',
                style: isAlreadyShared
                    ? AppTextStyles.bodySmall.copyWith(
                        color: successColor,
                        fontSize: AppTextStyles.labelSmall.fontSize,
                      )
                    : AppTextStyles.bodySmall.copyWith(
                        fontSize: AppTextStyles.labelSmall.fontSize,
                      ),
              ),
            ],
            if (recipe.portions != null) ...[
              if (recipe.timeMinutes != null) ...[
                const SizedBox(width: AppDimensions.space8),
                Text('•', style: AppTextStyles.bodySmall),
                const SizedBox(width: AppDimensions.space8),
              ],
              ButleryIcon(
                ButleryIcons.users,
                size: AppDimensions.iconSizeM,
                color: isAlreadyShared ? successColor : cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppDimensions.space4),
              Text(
                '${recipe.portions} port',
                style: isAlreadyShared
                    ? AppTextStyles.bodySmall.copyWith(
                        color: successColor,
                        fontSize: AppTextStyles.labelSmall.fontSize,
                      )
                    : AppTextStyles.bodySmall.copyWith(
                        fontSize: AppTextStyles.labelSmall.fontSize,
                      ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final successColor = context.modeColors.success;
    return Container(
      width: AppDimensions.iconSizeXl,
      height: AppDimensions.iconSizeXl,
      decoration: BoxDecoration(
        color: isAlreadyShared
            ? context.modeColors.surfaceTintSuccess
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: ButleryIcon(
        ButleryIcons.utensils,
        color: isAlreadyShared ? successColor : cs.onSurface,
        size: AppDimensions.iconSizeM,
      ),
    );
  }
}
