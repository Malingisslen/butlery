// lib/widgets/social/groups/shared_content_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/services/group_shared_content_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:timeago/timeago.dart' as timeago;

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
        return Icons.restaurant_menu;
      case 'menu':
        return Icons.calendar_today;
      case 'shopping_list':
        return Icons.shopping_cart;
      default:
        return Icons.share;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'recipe':
        return AppColors.primaryBlue;
      case 'menu':
        return AppColors.success;
      case 'shopping_list':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'recipe':
        return 'Recept';
      case 'menu':
        return 'Meny';
      case 'shopping_list':
        return 'Inköpslista';
      default:
        return 'Innehåll';
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _getColorForType(item.type);

    // Configure Swedish locale for timeago
    timeago.setLocaleMessages('sv', timeago.SvMessages());

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with icon and type
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingS),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.borderRadiusS),
                    ),
                    child: Icon(
                      _getIconForType(item.type),
                      color: iconColor,
                      size: AppDimensions.iconSizeM,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingM),
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
                        const SizedBox(height: AppDimensions.spacingXs),
                        Text(
                          _getTypeLabel(item.type),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: iconColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingM),

              // Shared by info
              Row(
                children: [
                  if (item.sharedByAvatarUrl != null)
                    CircleAvatar(
                      radius: 12,
                      backgroundImage: NetworkImage(item.sharedByAvatarUrl!),
                    )
                  else
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                      child: Text(
                        item.sharedByDisplayName.isNotEmpty
                            ? item.sharedByDisplayName[0].toUpperCase()
                            : '?',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 10,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Expanded(
                    child: Text(
                      'Delad av ${item.sharedByDisplayName}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    timeago.format(item.sharedAt, locale: 'sv'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingM),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onImport != null) ...[
                    TextButton.icon(
                      onPressed: onImport,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Importera'),
                    ),
                    const SizedBox(width: AppDimensions.spacingS),
                  ],
                  if (onView != null)
                    Flexible(
                      child: FilledButton.icon(
                        onPressed: onView,
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('Visa'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
