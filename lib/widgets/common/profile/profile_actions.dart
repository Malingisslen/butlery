// lib/widgets/common/profile/profile_actions.dart

import 'package:flutter/material.dart';

// Extracted components
import 'package:butlery/widgets/common/profile/builders/menu_item_builders.dart';
import 'package:butlery/widgets/common/profile/builders/profile_section_builders.dart';

/// Profile action handlers and UI components.
///
/// This facade class delegates to focused modules:
/// - [MenuItemBuilders] - Menu item UI components
/// - [ProfileSectionBuilders] - Section builders (backup, logout, account)
/// - Handlers in /handlers/ subdirectory for business logic
///
/// See CLAUDE.md for architecture guidelines on facade pattern.
class ProfileActions {
  // ===== MENU ITEM BUILDERS =====

  /// Build menu item for basic navigation.
  static Widget buildMenuItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) =>
      MenuItemBuilders.buildMenuItem(
        context,
        title: title,
        subtitle: subtitle,
        icon: icon,
        onTap: onTap,
      );

  /// Build notification menu item with badge.
  static Widget buildNotificationMenuItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    int count = 0,
  }) =>
      MenuItemBuilders.buildNotificationMenuItem(
        context,
        title: title,
        subtitle: subtitle,
        icon: icon,
        onTap: onTap,
        count: count,
      );

  // ===== SECTION BUILDERS =====

  /// Build data backup section.
  static Widget buildDataBackupSection(BuildContext context,
          {BuildContext? rootContext}) =>
      ProfileSectionBuilders.buildDataBackupSection(context,
          rootContext: rootContext);

  /// Build logout section.
  static Widget buildLogoutSection(BuildContext context) =>
      ProfileSectionBuilders.buildLogoutSection(context);

  /// Build account management section (GDPR compliance).
  static Widget buildAccountManagementSection(BuildContext context) =>
      ProfileSectionBuilders.buildAccountManagementSection(context);
}
