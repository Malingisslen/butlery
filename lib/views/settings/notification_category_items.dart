import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/notifications/notification_types.dart';

/// A notification category and the label of its toggle.
class NotificationCategoryItem {
  final NotificationCategory category;
  final String label;

  const NotificationCategoryItem({
    required this.category,
    required this.label,
  });
}

List<NotificationCategoryItem> buildNotificationCategoryItems(
  BuildContext context,
) => [
  NotificationCategoryItem(
    category: NotificationCategory.friends,
    label: context.l10n.notificationCategoryFriends,
  ),
  NotificationCategoryItem(
    category: NotificationCategory.recipes,
    label: context.l10n.notificationCategoryRecipes,
  ),
  NotificationCategoryItem(
    category: NotificationCategory.collaboration,
    label: context.l10n.notificationCategoryCollaboration,
  ),
  NotificationCategoryItem(
    category: NotificationCategory.shopping,
    label: context.l10n.notificationCategoryShopping,
  ),
  NotificationCategoryItem(
    category: NotificationCategory.messaging,
    label: context.l10n.notificationCategoryMessaging,
  ),
  NotificationCategoryItem(
    category: NotificationCategory.social,
    label: context.l10n.notificationCategorySocial,
  ),
  NotificationCategoryItem(
    category: NotificationCategory.system,
    label: context.l10n.notificationCategorySystem,
  ),
];
