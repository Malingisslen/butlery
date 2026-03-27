import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/notifications/notification_types.dart';

/// Display configuration for a single notification category toggle.
class NotificationCategoryItem {
  final NotificationCategory category;
  final String label;
  final IconData icon;

  const NotificationCategoryItem({
    required this.category,
    required this.label,
    required this.icon,
  });
}

List<NotificationCategoryItem> buildNotificationCategoryItems(
        BuildContext context) =>
    [
      NotificationCategoryItem(
        category: NotificationCategory.friends,
        label: context.l10n.notificationCategoryFriends,
        icon: Icons.people_outline,
      ),
      NotificationCategoryItem(
        category: NotificationCategory.recipes,
        label: context.l10n.notificationCategoryRecipes,
        icon: Icons.restaurant_outlined,
      ),
      NotificationCategoryItem(
        category: NotificationCategory.collaboration,
        label: context.l10n.notificationCategoryCollaboration,
        icon: Icons.group_work_outlined,
      ),
      NotificationCategoryItem(
        category: NotificationCategory.shopping,
        label: context.l10n.notificationCategoryShopping,
        icon: Icons.shopping_cart_outlined,
      ),
      NotificationCategoryItem(
        category: NotificationCategory.messaging,
        label: context.l10n.notificationCategoryMessaging,
        icon: Icons.chat_outlined,
      ),
      NotificationCategoryItem(
        category: NotificationCategory.social,
        label: context.l10n.notificationCategorySocial,
        icon: Icons.forum_outlined,
      ),
      NotificationCategoryItem(
        category: NotificationCategory.system,
        label: context.l10n.notificationCategorySystem,
        icon: Icons.settings_outlined,
      ),
    ];
