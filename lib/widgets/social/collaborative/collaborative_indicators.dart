// lib/widgets/social/collaborative/collaborative_indicators.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/user_profile.dart';
import '../../../models/recipe.dart';
import '../../../models/permissions/edit_mode.dart';
import '../../../theme/app_theme.dart';
import '../../../core/injection.dart';
import '../../../services/social_recipe_service.dart';
import '../../../viewmodels/recipe_form_viewmodel.dart';
import '../../../viewmodels/collaborative_status_viewmodel.dart';
import '../../permissions/edit_mode_ui_helper.dart';
import '../../user/user_display_widgets.dart';

/// Collaborative editing indicators and status widgets
///
/// This module provides widgets for showing collaborative editing status,
/// participant information, and real-time editing indicators.
class CollaborativeIndicators {
  /// Compact badge to show that content is shared/collaborative
  static Widget collaborativeStatusBadge({
    String text = 'Delat',
    IconData icon = Icons.people,
    Color? color,
    EdgeInsets? padding,
  }) {
    final effectiveColor = color ?? AppTheme.primaryColor;

    return Container(
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: AppTheme.spacingSm,
            vertical: AppTheme.spacingXs,
          ),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.chipRadius,
        border: Border.all(
          color: effectiveColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppTheme.iconSizeInfo,
            color: effectiveColor,
          ),
          SizedBox(width: AppTheme.spacingXs),
          Text(
            text,
            style: AppTheme.captionStyle.copyWith(
              color: effectiveColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
    final bgColor =
        backgroundColor ?? AppTheme.primaryColor.withValues(alpha: 0.1);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.smallRadius,
        child: Row(
          children: [
            Icon(
              Icons.people,
              color: AppTheme.primaryColor,
              size: AppTheme.iconSizeAction,
            ),
            SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyStyle.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            // USE REAL PARTICIPANTS if context and contentId exist
            if (context != null && contentId != null)
              collaborativeParticipants(
                context: context,
                contentId: contentId,
                contentType: contentType,
                maxVisible: 3,
                avatarSize: 24,
              )
            // FALLBACK to trailing widget
            else if (trailing != null)
              trailing
            // LAST FALLBACK - show just an icon
            else
              Icon(
                Icons.people_outline,
                size: 24,
                color: AppTheme.primaryColor,
              ),
          ],
        ),
      ),
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
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Consumer<CollaborativeStatusViewModel>(
        builder: (context, viewModel, child) {
          // Get status object and use .isCollaborative
          final status = contentType == 'recipe'
              ? viewModel.getRecipeCollaborativeStatus(contentId, recipe)
              : viewModel.getMenuCollaborativeStatus(contentId, menuData);

          final isCollaborative = status.isCollaborative;

          return AppBar(
            title: Text(title ?? 'Redigera innehåll'),
            backgroundColor: isCollaborative
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : null,
            actions: [
              // Collaborative badge if relevant
              if (isCollaborative)
                Padding(
                  padding: EdgeInsets.only(right: AppTheme.spacingMd),
                  child: Center(
                    child: collaborativeStatusBadge(
                      text: 'Delat',
                      icon: Icons.people,
                    ),
                  ),
                ),
              // Other actions
              if (actions != null) ...actions,
            ],
          );
        },
      ),
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
    return Consumer<CollaborativeStatusViewModel>(
      builder: (context, viewModel, child) {
        // Get status object and use .isCollaborative
        final status = contentType == 'recipe'
            ? viewModel.getRecipeCollaborativeStatus(contentId, recipe)
            : viewModel.getMenuCollaborativeStatus(contentId, menuData);

        final isCollaborative = status.isCollaborative;

        if (!isCollaborative) return const SizedBox.shrink();

        return collaborativeBanner(
          title: title ?? 'Du redigerar tillsammans med andra',
          subtitle:
              subtitle ?? 'Ändringar synkas automatiskt med andra deltagare',
          contentId: contentId,
          contentType: contentType,
          context: context,
        );
      },
    );
  }

  /// Force refresh for specific content via ViewModel
  static void refreshCollaborativeStatus(
    BuildContext context,
    String contentId, {
    String contentType = 'recipe',
  }) {
    try {
      final viewModel = context.read<CollaborativeStatusViewModel>();
      if (contentType == 'recipe') {
        viewModel.invalidateRecipeStatus(contentId);
      } else {
        viewModel.invalidateMenuStatus(contentId);
      }
    } catch (e) {
      debugPrint('Could not refresh collaborative status: $e');
    }
  }

  /// Fetch real participants for collaborative content
  ///
  /// This method fetches actual participants from SharedRecipe/SharedMenu
  /// based on contentId and contentType
  static Widget collaborativeParticipants({
    required BuildContext context,
    required String contentId,
    String contentType = 'recipe',
    int maxVisible = 3,
    double avatarSize = 32,
  }) {
    return FutureBuilder<List<UserProfile>>(
      future: _getRealParticipants(context, contentId, contentType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Loading state - show skeleton avatars
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
                2,
                (index) => Container(
                      width: avatarSize,
                      height: avatarSize,
                      margin: EdgeInsets.only(left: index > 0 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                    )),
          );
        }

        if (snapshot.hasError) {
          // Error state - show placeholder
          return Icon(
            Icons.people_outline,
            size: avatarSize,
            color: AppTheme.textSecondary,
          );
        }

        final participants = snapshot.data ?? [];
        if (participants.isEmpty) {
          // No participants - show placeholder
          return Icon(
            Icons.person_outline,
            size: avatarSize,
            color: AppTheme.textSecondary,
          );
        }

        // Show real participants
        return participantAvatars(
          participants: participants,
          maxVisible: maxVisible,
          totalCount: participants.length,
          size: avatarSize,
        );
      },
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
    if (!isVisible) return const SizedBox.shrink();

    final indicatorColor = color ?? AppTheme.warningColor;

    return TweenAnimationBuilder<double>(
      duration: animationDuration,
      tween: Tween<double>(begin: 0.0, end: isVisible ? 1.0 : 0.0),
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSm,
              vertical: AppTheme.spacingXs,
            ),
            decoration: BoxDecoration(
              color: indicatorColor.withValues(alpha: 0.1),
              borderRadius: AppTheme.chipRadius,
              border: Border.all(
                color: indicatorColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPulsingDot(indicatorColor),
                SizedBox(width: AppTheme.spacingXs),
                Text(
                  '$editorName redigerar $editingWhat',
                  style: AppTheme.captionStyle.copyWith(
                    color: indicatorColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Permissions banner for collaborative editing
  static Widget permissionsBanner({
    required BuildContext context,
    required EditMode editMode,
    VoidCallback? onTap,
  }) {
    final color = EditModeUIHelper.getColor(editMode, context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppTheme.spacingMd),
      margin: EdgeInsets.all(AppTheme.spacingSm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppTheme.cardBorderRadius,
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.cardBorderRadius,
        child: Row(
          children: [
            Icon(
              EditModeUIHelper.getIcon(editMode),
              color: color,
              size: AppTheme.iconSizeAction,
            ),
            SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: Text(
                editMode.description,
                style: AppTheme.bodyStyle.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Smart permissions banner with ViewModel integration
  static Widget smartPermissionsBanner({
    required BuildContext context,
    required RecipeFormViewModel viewModel,
  }) {
    if (viewModel.editMode == null) return const SizedBox.shrink();

    return permissionsBanner(
      context: context,
      editMode: viewModel.editMode!,
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
    if (isOnline) {
      // Minimal indicator when everything works
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSm,
          vertical: AppTheme.spacingXs,
        ),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withValues(alpha: 0.1),
          borderRadius: AppTheme.chipRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: AppTheme.spacingXs),
            Text(
              'Online',
              style: AppTheme.captionStyle.copyWith(
                color: AppTheme.successColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Offline banner
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          if (statusEmoji != null) ...[
            Text(statusEmoji, style: TextStyle(fontSize: AppTheme.iconSizeInfo.toDouble())),
            SizedBox(width: AppTheme.spacingSm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Offline',
                  style: AppTheme.bodyStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorColor,
                  ),
                ),
                Text(
                  statusText,
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.errorColor,
                  ),
                ),
              ],
            ),
          ),
          if (showRetryButton && onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Försök igen',
                style: AppTheme.buttonTextStyle.copyWith(
                  color: AppTheme.errorColor,
                ),
              ),
            ),
        ],
      ),
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
    final visibleParticipants = participants.take(maxVisible).toList();
    final effectiveTotalCount = totalCount ?? participants.length;
    final remaining = effectiveTotalCount - maxVisible;
    final gap = spacing?.horizontal ?? AppTheme.spacingXs;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show visible participants - DELEGATE to UserDisplayWidgets
        for (int i = 0; i < visibleParticipants.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          UserDisplayWidgets.avatar(
            imageUrl: visibleParticipants[i].avatarUrl,
            displayName: visibleParticipants[i].displayName,
            size: _sizeToImageSize(size),
          ),
        ],

        // Show "+X" if there are more
        if (remaining > 0) ...[
          SizedBox(width: gap),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryColor,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                '+$remaining',
                style: TextStyle(
                  fontSize: size * 0.35,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // PRIVATE HELPERS

  /// Fetch real participants from Firebase - ENHANCED VERSION
  static Future<List<UserProfile>> _getRealParticipants(
    BuildContext context,
    String contentId,
    String contentType,
  ) async {
    try {
      // Use SocialRecipeService for optimized participant loading
      final socialRecipeService = sl<SocialRecipeService>();

      debugPrint('🔍 Loading participants for $contentType: $contentId');

      List<UserProfile> participants = [];

      switch (contentType) {
        case 'recipe':
          participants =
              await socialRecipeService.getRecipeParticipants(contentId);
          break;

        case 'menu':
          participants =
              await socialRecipeService.getMenuParticipants(contentId);
          break;

        case 'shopping_list':
          participants =
              await socialRecipeService.getShoppingListParticipants(contentId);
          break;

        default:
          debugPrint('🔍 Unknown content type: $contentType');
          return [];
      }

      debugPrint(
          '🔍 Found ${participants.length} participants for $contentType $contentId');
      for (final participant in participants) {
        debugPrint(
            '🔍 Participant: ${participant.displayName} (${participant.uid})');
      }

      return participants;
    } catch (e) {
      debugPrint('❌ Error loading participants for $contentId: $e');
      return [];
    }
  }

  /// Build a pulsing dot animation
  static Widget _buildPulsingDot(Color color) {
    return SizedBox(
      width: 8,
      height: 8,
      child: _PulsingDot(color: color),
    );
  }

  /// Convert size to ImageSize enum
  static ImageSize _sizeToImageSize(double size) {
    if (size <= 24) return ImageSize.small;
    if (size <= 32) return ImageSize.medium;
    if (size <= 48) return ImageSize.large;
    return ImageSize.extraLarge;
  }
}

/// Pulsing dot animation widget
class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}