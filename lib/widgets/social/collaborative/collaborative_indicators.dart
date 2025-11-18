// lib/widgets/social/collaborative/collaborative_indicators.dart - FACADE PATTERN

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';

// Focused Components
import 'package:butlery/widgets/social/collaborative/components/collaborative_status_widgets.dart';
import 'package:butlery/widgets/social/collaborative/components/collaborative_participants_widgets.dart';
import 'package:butlery/widgets/social/collaborative/components/collaborative_live_widgets.dart';
import 'package:butlery/widgets/social/collaborative/components/collaborative_permissions_widgets.dart';
import 'package:butlery/widgets/social/collaborative/components/collaborative_connection_widgets.dart';

/// Collaborative Indicators API
/// This class provides a unified API for collaborative editing indicators:
/// - Status badges and banners for collaborative content
/// - Participant avatars and lists
/// - Live editing indicators with animations
/// - Permission banners and status
/// - Connection status indicators
/// MIGRATION GUIDE:
/// ```dart
/// // Before: No change needed
/// CollaborativeIndicators.collaborativeStatusBadge(text: 'Delat');
/// CollaborativeIndicators.collaborativeParticipants(context: context, contentId: id);
/// ```
class CollaborativeIndicators {
  /// Compact badge to show that content is shared/collaborative
  static Widget collaborativeStatusBadge({
    String text = 'Delat',
    IconData icon = Icons.people,
    Color? color,
    EdgeInsets? padding,
  }) {
    return CollaborativeStatusWidgets.statusBadge(
      text: text,
      icon: icon,
      color: color,
      padding: padding,
    );
  }

  /// Larger banner for collaborative context - WITH REAL PARTICIPANTS
  static Widget collaborativeBanner({
    required String title,
    required String subtitle,
    String? contentId,
    String contentType = 'recipe',
    Color? backgroundColor,
    VoidCallback? onTap,
    Widget? trailing,
    BuildContext? context, // Needed to fetch real participants
  }) {
    return CollaborativeStatusWidgets.banner(
      title: title,
      subtitle: subtitle,
      contentId: contentId,
      contentType: contentType,
      backgroundColor: backgroundColor,
      onTap: onTap,
      trailing: trailing,
      context: context,
    );
  }

  /// AppBar with collaborative background color and smart status detection
  static PreferredSizeWidget collaborativeAppBar({
    required BuildContext context,
    required String contentId,
    String contentType = 'recipe',
    Recipe? recipe,
    Map<String, List<Recipe>>? menuData,
    String? title,
    List<Widget>? actions,
  }) {
    return CollaborativeStatusWidgets.appBar(
      context: context,
      contentId: contentId,
      contentType: contentType,
      recipe: recipe,
      menuData: menuData,
      title: title,
      actions: actions,
    );
  }

  /// Smart collaborative banner with ViewModel integration
  static Widget smartCollaborativeBanner({
    required BuildContext context,
    required String contentId,
    String contentType = 'recipe',
    Recipe? recipe,
    Map<String, List<Recipe>>? menuData,
    String? title,
    String? subtitle,
  }) {
    return CollaborativeStatusWidgets.smartBanner(
      context: context,
      contentId: contentId,
      contentType: contentType,
      recipe: recipe,
      menuData: menuData,
      title: title,
      subtitle: subtitle,
    );
  }

  /// Force refresh for specific content via ViewModel
  static void refreshCollaborativeStatus(
    BuildContext context,
    String contentId, {
    String contentType = 'recipe',
  }) {
    CollaborativeStatusWidgets.refreshStatus(
      context,
      contentId,
      contentType: contentType,
    );
  }

  /// Fetch real participants for collaborative content
  /// This method fetches actual participants from SharedRecipe/SharedMenu
  /// based on contentId and contentType
  static Widget collaborativeParticipants({
    required BuildContext context,
    required String contentId,
    String contentType = 'recipe',
    int maxVisible = 3,
    double avatarSize = 32,
  }) {
    return CollaborativeParticipantsWidgets.participantsList(
      context: context,
      contentId: contentId,
      contentType: contentType,
      maxVisible: maxVisible,
      avatarSize: avatarSize,
    );
  }

  /// Show real-time "X is editing now" indicator
  static Widget liveEditIndicator({
    required String editorName,
    required String editingWhat,
    Color? color,
    bool isVisible = true,
    Duration animationDuration = const Duration(milliseconds: 300),
  }) {
    return CollaborativeLiveWidgets.editIndicator(
      editorName: editorName,
      editingWhat: editingWhat,
      color: color,
      isVisible: isVisible,
      animationDuration: animationDuration,
    );
  }

  /// Permissions banner for collaborative editing
  static Widget permissionsBanner({
    required BuildContext context,
    required EditMode editMode,
    VoidCallback? onTap,
  }) {
    return CollaborativePermissionsWidgets.permissionsBanner(
      context: context,
      editMode: editMode,
      onTap: onTap,
    );
  }

  /// Smart permissions banner with ViewModel integration
  static Widget smartPermissionsBanner({
    required BuildContext context,
    required RecipeFormViewModel viewModel,
  }) {
    return CollaborativePermissionsWidgets.smartPermissionsBanner(
      context: context,
      viewModel: viewModel,
    );
  }

  /// Show connection status for collaborative content
  static Widget collaborativeConnectionStatus({
    required bool isOnline,
    required String statusText,
    String? statusEmoji,
    bool showRetryButton = false,
    VoidCallback? onRetry,
  }) {
    return CollaborativeConnectionWidgets.connectionStatus(
      isOnline: isOnline,
      statusText: statusText,
      statusEmoji: statusEmoji,
      showRetryButton: showRetryButton,
      onRetry: onRetry,
    );
  }

  /// Show participants as small avatars
  static Widget participantAvatars({
    required List<UserProfile> participants,
    int maxVisible = 4,
    int? totalCount,
    double size = 32,
    EdgeInsets? spacing,
  }) {
    return CollaborativeParticipantsWidgets.avatarRow(
      participants: participants,
      maxVisible: maxVisible,
      totalCount: totalCount,
      size: size,
      spacing: spacing,
    );
  }
}