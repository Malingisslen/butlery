// lib/widgets/common/social/social_collaborative_api.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/widgets/social/collaborative/collaborative_indicators.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart' show ImageSize;

/// Collaborative API delegation for SocialComponents
class SocialCollaborativeApi {
  /// Build collaborative status badge
  static Widget collaborativeStatusBadge({
    String text = 'Delat',
    IconData icon = Icons.people,
    Color? color,
    EdgeInsets? padding,
  }) {
    return CollaborativeIndicators.collaborativeStatusBadge(
      text: text,
      icon: icon,
      color: color,
      padding: padding,
    );
  }

  /// Build collaborative banner
  static Widget collaborativeBanner({
    required String title,
    required String subtitle,
    String? contentId,
    String contentType = 'recipe',
    Color? backgroundColor,
    VoidCallback? onTap,
    Widget? trailing,
    BuildContext? context,
  }) {
    return CollaborativeIndicators.collaborativeBanner(
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

  /// Build smart permissions banner
  static Widget smartPermissionsBanner({
    required BuildContext context,
    required RecipeFormViewModel viewModel,
  }) {
    return CollaborativeIndicators.smartPermissionsBanner(
      context: context,
      viewModel: viewModel,
    );
  }

  /// Build collaborative app bar widget
  static Widget collaborativeAppBar({
    required BuildContext context,
    required String contentId,
    Recipe? recipe,
    bool showParticipants = true,
    bool showStatus = true,
    int maxParticipants = 3,
    VoidCallback? onTap,
  }) {
    return CollaborativeIndicators.collaborativeAppBar(
      context: context,
      contentId: contentId,
      recipe: recipe,
      title: 'Redigera recept',
    );
  }

  /// Build smart collaborative banner
  static Widget smartCollaborativeBanner({
    required BuildContext context,
    required String contentId,
    Recipe? recipe,
    bool showIfNotCollaborative = false,
    EdgeInsets? padding,
    bool showAnimation = true,
  }) {
    return CollaborativeIndicators.smartCollaborativeBanner(
      context: context,
      contentId: contentId,
      recipe: recipe,
      title: 'Du redigerar tillsammans med andra',
      subtitle: 'Ändringar synkas automatiskt med andra deltagare',
    );
  }

  /// Build collaborative status indicator
  static Widget collaborativeStatusIndicator({
    required BuildContext context,
    required String contentId,
    bool showLabel = true,
    bool showAnimation = true,
    VoidCallback? onTap,
  }) {
    return CollaborativeIndicators.smartCollaborativeBanner(
      context: context,
      contentId: contentId,
      title: 'Du redigerar tillsammans med andra',
      subtitle: 'Ändringar synkas automatiskt med andra deltagare',
    );
  }

  /// Build participants list
  static Widget participantsList({
    required BuildContext context,
    required String contentId,
    int maxVisible = 3,
    ImageSize avatarSize = ImageSize.small,
    bool showCount = true,
    bool showAnimation = true,
    VoidCallback? onTap,
  }) {
    return CollaborativeIndicators.collaborativeParticipants(
      context: context,
      contentId: contentId,
      maxVisible: maxVisible,
      avatarSize: avatarSize == ImageSize.small ? 24 : 32,
    );
  }
}
