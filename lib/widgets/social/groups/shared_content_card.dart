// lib/widgets/social/groups/shared_content_card.dart

import 'package:butlery/core/utils/stored_display_name.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/group_shared_content_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/widgets/common/cards/styled_card.dart';

/// Card widget for displaying shared content items (recipes, menus, shopping lists)
class SharedContentCard extends StatelessWidget {
  final SharedContentItem item;
  final VoidCallback? onView;
  final VoidCallback? onImport;

  const SharedContentCard({
    super.key,
    required this.item,
    this.onView,
    this.onImport,
  });

  IconData _getIconForType(String type) {
    switch (type) {
      case 'recipe':
        return ButleryIcons.utensils;
      case 'menu':
        return ButleryIcons.calendar;
      case 'shopping_list':
        return ButleryIcons.shoppingCart;
      default:
        return ButleryIcons.share2;
    }
  }

  Color _getColorForType(BuildContext context, String type) {
    final cs = Theme.of(context).colorScheme;
    switch (type) {
      case 'recipe':
        return cs.onSurface;
      case 'menu':
        return context.modeColors.onSuccessContainer;
      case 'shopping_list':
        return AppModeColors.textWarning(Theme.of(context).brightness);
      default:
        return cs.onSurfaceVariant;
    }
  }

  String _getTypeLabel(BuildContext context, String type) {
    switch (type) {
      case 'recipe':
        return context.l10n.groupContentTypeRecipe;
      case 'menu':
        return context.l10n.groupContentTypeMenu;
      case 'shopping_list':
        return context.l10n.groupContentTypeShoppingList;
      default:
        return context.l10n.groupContentTypeContent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconColor = _getColorForType(context, item.type);
    final sharedBy = storedNameOr(
      item.sharedByDisplayName,
      context.l10n.displayUnknownUser,
    );

    return StyledCard(
      margin: const EdgeInsets.only(bottom: AppDimensions.space8),
      child: Semantics(
        label: '${context.l10n.groupSharedContent}: ${item.title}',
        button: onView != null,
        child: InkWell(
          onTap: onView,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with icon and type
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.space8),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusControl,
                        ),
                      ),
                      child: ButleryIcon(
                        _getIconForType(item.type),
                        color: iconColor,
                        size: AppDimensions.iconSizeM,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: AppTextStyles.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppDimensions.space4),
                          Text(
                            _getTypeLabel(context, item.type),
                            style: AppTextStyles.labelLarge.copyWith(
                              color: iconColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space8),

                // Shared by info
                Row(
                  children: [
                    AvatarCircle(
                      imageUrl: item.sharedByAvatarUrl,
                      displayName: sharedBy,
                      size: AvatarCircleSize.inline,
                      tone: AvatarCircleTone.paper,
                    ),
                    const SizedBox(width: AppDimensions.space4),
                    Expanded(
                      child: Text(
                        context.l10n.groupSharedBy(sharedBy),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      ContextualTimeFormatter.standard(
                        item.sharedAt,
                        localeName: Localizations.localeOf(context).toString(),
                      ),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space8),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onImport != null) ...[
                      ButleryTextButton(
                        label: context.l10n.groupImport,
                        icon: ButleryIcons.download,
                        onPressed: onImport,
                      ),
                      const SizedBox(width: AppDimensions.space4),
                    ],
                    if (onView != null)
                      Flexible(
                        child: ActionButtons.primaryButton(
                          context,
                          label: context.l10n.groupView,
                          icon: ButleryIcons.eye,
                          onPressed: onView,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
