// lib/widgets/common/social_components.dart

import 'package:flutter/material.dart';
import '../../models/friend_category.dart';
import '../../models/user_profile.dart';
import '../../models/invitations/invitation_target.dart';
import '../../models/recipe_unified.dart';
import '../../viewmodels/recipe_form_viewmodel.dart';

// Import facade
import 'social/social_facade.dart';

// ✅ Re-export ImageSize for easier imports
export '../user/user_display_widgets.dart' show ImageSize, UserDisplayData;

// Import ImageSize for local usage
import '../user/user_display_widgets.dart' show ImageSize;

/// 🚀 SocialComponents - The ultimate social widget API
///
/// Consolidates all social-related widgets into a unified API through delegation:
/// - ✅ Avatar widgets (delegates to AvatarWidgets)
/// - ✅ Collaborative indicators (delegates to CollaborativeIndicators)
/// - ✅ Friend category management (delegates to FriendCategoryWidgets)
/// - ✅ Group dialogs (delegates to GroupDialogs)
/// - ✅ Invitation target widgets (delegates to InvitationTargetDisplays/Inputs/States)
/// - ✅ Social builders and helpers (delegates to SocialBuilders/Helpers)
/// - ✅ 100% AppTheme compliance and consistent patterns
///
/// MIGRATION GUIDE:
/// ```dart
/// // Before:
/// import '../../widgets/user/user_display_widgets.dart';
/// UserDisplayWidgets.avatar(imageUrl: user.avatarUrl, displayName: user.displayName)
///
/// // After:
/// import '../../widgets/common/social_components.dart';
/// SocialComponents.avatar(user: user)
/// ```
class SocialComponents {
  // ===== USER DISPLAY & AVATARS =====

  /// Build user avatar - MAIN METHOD that replaces UserDisplayWidgets.avatar()
  static Widget avatar({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    ImageSize size = ImageSize.medium,
    VoidCallback? onTap,
    bool showOnlineStatus = false,
    bool isOnline = false,
    EdgeInsets? padding,
    bool showBorder = true,
    Color? borderColor,
    bool showPlaceholder = true,
    String? placeholderText,
    double? customSize,
    bool isClickable = true,
    Widget? overlay,
    AlignmentGeometry overlayAlignment = Alignment.bottomRight,
  }) {
    return SocialFacade.avatar(
      user: user,
      imageUrl: imageUrl,
      displayName: displayName,
      size: size,
      onTap: onTap,
      showOnlineStatus: showOnlineStatus,
      isOnline: isOnline,
      padding: padding,
      showBorder: showBorder,
      borderColor: borderColor,
      showPlaceholder: showPlaceholder,
      placeholderText: placeholderText,
      customSize: customSize,
      isClickable: isClickable,
      overlay: overlay,
      overlayAlignment: overlayAlignment,
    );
  }

  /// Build user card with avatar and info
  static Widget userCard({
    required UserProfile user,
    VoidCallback? onTap,
    Widget? trailing,
    ImageSize avatarSize = ImageSize.medium,
    bool showOnlineStatus = false,
    bool isOnline = false,
    EdgeInsets? padding,
    bool showSubtitle = true,
    String? subtitle,
    Color? backgroundColor,
    bool showBorder = true,
  }) {
    return SocialFacade.userCard(
      user: user,
      onTap: onTap,
      trailing: trailing,
      avatarSize: avatarSize,
      showOnlineStatus: showOnlineStatus,
      isOnline: isOnline,
      padding: padding,
      showSubtitle: showSubtitle,
      subtitle: subtitle,
      backgroundColor: backgroundColor,
      showBorder: showBorder,
    );
  }

  /// Build user list tile
  static Widget userListTile({
    required UserProfile user,
    VoidCallback? onTap,
    Widget? trailing,
    ImageSize avatarSize = ImageSize.small,
    bool showOnlineStatus = false,
    bool isOnline = false,
    String? subtitle,
    bool enabled = true,
    Color? backgroundColor,
  }) {
    return SocialFacade.userListTile(
      user: user,
      onTap: onTap,
      trailing: trailing,
      avatarSize: avatarSize,
      showOnlineStatus: showOnlineStatus,
      isOnline: isOnline,
      subtitle: subtitle,
      enabled: enabled,
      backgroundColor: backgroundColor,
    );
  }

  // ===== COLLABORATIVE INDICATORS =====

  /// Build collaborative status badge
  static Widget collaborativeStatusBadge({
    String text = 'Delat',
    IconData icon = Icons.people,
    Color? color,
    EdgeInsets? padding,
  }) {
    return SocialFacade.collaborativeStatusBadge(
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
    return SocialFacade.collaborativeBanner(
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
    return SocialFacade.smartPermissionsBanner(
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
    return SocialFacade.collaborativeAppBar(
      context: context,
      contentId: contentId,
      recipe: recipe,
      showParticipants: showParticipants,
      showStatus: showStatus,
      maxParticipants: maxParticipants,
      onTap: onTap,
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
    return SocialFacade.smartCollaborativeBanner(
      context: context,
      contentId: contentId,
      recipe: recipe,
      showIfNotCollaborative: showIfNotCollaborative,
      padding: padding,
      showAnimation: showAnimation,
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
    return SocialFacade.collaborativeStatusIndicator(
      context: context,
      contentId: contentId,
      showLabel: showLabel,
      showAnimation: showAnimation,
      onTap: onTap,
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
    return SocialFacade.participantsList(
      context: context,
      contentId: contentId,
      maxVisible: maxVisible,
      avatarSize: avatarSize,
      showCount: showCount,
      showAnimation: showAnimation,
      onTap: onTap,
    );
  }

  // ===== FRIEND CATEGORY MANAGEMENT =====

  /// Build friend category selector
  static Widget friendCategorySelector({
    required List<FriendCategory> categories,
    required Set<String> selectedCategoryIds,
    required Function(String) onCategoryToggled,
    bool allowMultipleSelection = true,
    String? title,
    EdgeInsets? padding,
    bool showSelectAll = true,
    bool showCreateNew = true,
    VoidCallback? onCreateNew,
  }) {
    return SocialFacade.friendCategorySelector(
      categories: categories,
      selectedCategoryIds: selectedCategoryIds,
      onCategoryToggled: onCategoryToggled,
      allowMultipleSelection: allowMultipleSelection,
      title: title,
      padding: padding,
      showSelectAll: showSelectAll,
      showCreateNew: showCreateNew,
      onCreateNew: onCreateNew,
    );
  }

  /// Build friend category chip
  static Widget friendCategoryChip({
    required FriendCategory category,
    required bool isSelected,
    required VoidCallback onTap,
    bool showCount = true,
    bool enabled = true,
  }) {
    return SocialFacade.friendCategoryChip(
      category: category,
      isSelected: isSelected,
      onTap: onTap,
      showCount: showCount,
      enabled: enabled,
    );
  }

  // ===== GROUP DIALOGS =====

  /// Show create group dialog
  static Future<FriendCategory?> showCreateGroupDialog(
    BuildContext context, {
    List<UserProfile>? preSelectedMembers,
    String? initialName,
    String? initialDescription,
    VoidCallback? onSuccess,
  }) {
    return SocialFacade.showCreateGroupDialog(
      context,
      preSelectedMembers: preSelectedMembers,
      initialName: initialName,
      initialDescription: initialDescription,
      onSuccess: onSuccess,
    );
  }

  /// Show edit group dialog
  static Future<FriendCategory?> showEditGroupDialog(
    BuildContext context, {
    required FriendCategory group,
    String? currentName,
    String? currentDescription,
    VoidCallback? onSuccess,
  }) {
    return SocialFacade.showEditGroupDialog(
      context,
      group: group,
      currentName: currentName,
      currentDescription: currentDescription,
      onSuccess: onSuccess,
    );
  }

  /// Show delete group dialog
  static Future<bool> showDeleteGroupDialog(
    BuildContext context, {
    required FriendCategory group,
    String? groupName,
    VoidCallback? onSuccess,
  }) {
    return SocialFacade.showDeleteGroupDialog(
      context,
      group: group,
      groupName: groupName,
      onSuccess: onSuccess,
    );
  }

  /// Show remove member dialog
  static Future<bool> showRemoveMemberDialog(
    BuildContext context, {
    required FriendCategory group,
    required UserProfile member,
    String? groupName,
    VoidCallback? onSuccess,
  }) {
    return SocialFacade.showRemoveMemberDialog(
      context,
      group: group,
      member: member,
      groupName: groupName,
      onSuccess: onSuccess,
    );
  }

  // ===== INVITATION TARGET WIDGETS =====

  /// Build invitation target display
  static Widget invitationTargetDisplay({
    required InvitationTarget target,
    ImageSize avatarSize = ImageSize.medium,
    bool showStatus = true,
    bool showTypeIcon = true,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return SocialFacade.invitationTargetDisplay(
      target: target,
      avatarSize: avatarSize,
      showStatus: showStatus,
      showTypeIcon: showTypeIcon,
      onTap: onTap,
      trailing: trailing,
    );
  }

  /// Build target card
  static Widget targetCard({
    required InvitationTarget target,
    bool showStatus = true,
    bool showTypeIcon = true,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return SocialFacade.targetCard(
      target: target,
      showStatus: showStatus,
      showTypeIcon: showTypeIcon,
      onTap: onTap,
      trailing: trailing,
    );
  }

  /// Build target chip
  static Widget targetChip({
    required InvitationTarget target,
    bool showTypeIcon = true,
    VoidCallback? onTap,
  }) {
    return SocialFacade.targetChip(
      target: target,
      showTypeIcon: showTypeIcon,
      onTap: onTap,
    );
  }

  /// Build target list tile
  static Widget targetListTile({
    required InvitationTarget target,
    bool showStatus = true,
    bool showTypeIcon = true,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return SocialFacade.targetListTile(
      target: target,
      showStatus: showStatus,
      showTypeIcon: showTypeIcon,
      onTap: onTap,
      trailing: trailing,
    );
  }

  /// Build target badge
  static Widget targetBadge({
    required InvitationTarget target,
    bool showTypeIcon = true,
  }) {
    return SocialFacade.targetBadge(
      target: target,
      showTypeIcon: showTypeIcon,
    );
  }

  /// Build target list
  static Widget targetList({
    required List<InvitationTarget> targets,
    bool showStatus = true,
    bool showTypeIcon = true,
    Function(InvitationTarget)? onTap,
  }) {
    return SocialFacade.targetList(
      targets: targets,
      showStatus: showStatus,
      showTypeIcon: showTypeIcon,
      onTap: onTap,
    );
  }

  /// Build target grid
  static Widget targetGrid({
    required List<InvitationTarget> targets,
    bool showStatus = true,
    bool showTypeIcon = true,
    Function(InvitationTarget)? onTap,
  }) {
    return SocialFacade.targetGrid(
      targets: targets,
      showStatus: showStatus,
      showTypeIcon: showTypeIcon,
      onTap: onTap,
    );
  }

  /// Build target selector
  static Widget targetSelector({
    required List<InvitationTarget> availableTargets,
    required Set<String> selectedTargetIds,
    required Function(InvitationTarget) onTargetToggled,
    bool allowMultipleSelection = true,
    String? title,
    String? emptyMessage,
    EdgeInsets? padding,
    bool showSelectAll = true,
    bool showSearchBar = true,
    String? searchHint,
  }) {
    return SocialFacade.targetSelector(
      availableTargets: availableTargets,
      selectedTargetIds: selectedTargetIds,
      onTargetToggled: onTargetToggled,
      allowMultipleSelection: allowMultipleSelection,
      title: title,
      emptyMessage: emptyMessage,
      padding: padding,
      showSelectAll: showSelectAll,
      showSearchBar: showSearchBar,
      searchHint: searchHint,
    );
  }

  /// Build checkable target list
  static Widget checkableTargetList({
    required List<InvitationTarget> targets,
    required Set<String> selectedTargetIds,
    required Function(InvitationTarget) onTargetToggled,
    bool showTypeIcon = true,
  }) {
    return SocialFacade.targetList(
      targets: targets,
      showStatus: true,
      showTypeIcon: showTypeIcon,
      onTap: onTargetToggled,
    );
  }

  /// Build radio target selector
  static Widget radioTargetSelector({
    required List<InvitationTarget> targets,
    required String? selectedTargetId,
    required Function(InvitationTarget) onTargetSelected,
    bool showTypeIcon = true,
  }) {
    return SocialFacade.targetList(
      targets: targets,
      showStatus: true,
      showTypeIcon: showTypeIcon,
      onTap: onTargetSelected,
    );
  }

  /// Build target search field
  static Widget targetSearchField({
    required ValueChanged<String> onChanged,
    String? hint,
    String? initialValue,
  }) {
    return SocialFacade.targetSelector(
      availableTargets: [],
      selectedTargetIds: {},
      onTargetToggled: (_) {},
      searchHint: hint,
      showSearchBar: true,
    );
  }

  /// Build target type filters
  static Widget targetTypeFilters({
    required List<String> availableTypes,
    required Set<String> selectedTypes,
    required Function(String) onTypeToggled,
  }) {
    return SocialFacade.targetSelector(
      availableTargets: [],
      selectedTargetIds: {},
      onTargetToggled: (_) {},
      showSearchBar: false,
    );
  }

  /// Build quick selection buttons
  static Widget quickSelectionButtons({
    required VoidCallback onSelectAll,
    required VoidCallback onDeselectAll,
    required VoidCallback onInvertSelection,
  }) {
    return SocialFacade.quickSelectionButtons(
      onSelectAll: onSelectAll,
      onDeselectAll: onDeselectAll,
      onInvertSelection: onInvertSelection,
    );
  }

  /// Build invitation target list
  static Widget invitationTargetList({
    required List<InvitationTarget> targets,
    ImageSize avatarSize = ImageSize.small,
    bool showStatus = true,
    bool showTypeIcon = true,
    Function(InvitationTarget)? onTap,
    Widget Function(InvitationTarget)? trailingBuilder,
    EdgeInsets? padding,
    bool shrinkWrap = false,
  }) {
    return SocialFacade.targetList(
      targets: targets,
      showStatus: showStatus,
      showTypeIcon: showTypeIcon,
      onTap: onTap,
    );
  }

  /// Build invitation target selector
  static Widget invitationTargetSelector({
    required List<InvitationTarget> availableTargets,
    required Set<String> selectedTargetIds,
    required Function(InvitationTarget) onTargetToggled,
    bool allowMultipleSelection = true,
    String? title,
    String? emptyMessage,
    EdgeInsets? padding,
    bool showSelectAll = true,
    bool showSearchBar = true,
    String? searchHint,
  }) {
    return SocialFacade.targetSelector(
      availableTargets: availableTargets,
      selectedTargetIds: selectedTargetIds,
      onTargetToggled: onTargetToggled,
      allowMultipleSelection: allowMultipleSelection,
      title: title,
      emptyMessage: emptyMessage,
      padding: padding,
      showSelectAll: showSelectAll,
      showSearchBar: showSearchBar,
      searchHint: searchHint,
    );
  }

  /// Build invitation target chip
  static Widget invitationTargetChip({
    required InvitationTarget target,
    required bool isSelected,
    required VoidCallback onTap,
    bool showTypeIcon = true,
    bool enabled = true,
  }) {
    return SocialFacade.targetChip(
      target: target,
      showTypeIcon: showTypeIcon,
      onTap: onTap,
    );
  }

  // ===== SOCIAL BUILDERS =====

  /// Build social action button
  static Widget socialActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool enabled = true,
    bool isLoading = false,
    Color? backgroundColor,
    Color? foregroundColor,
    EdgeInsets? padding,
    double? iconSize,
  }) {
    return SocialFacade.socialActionButton(
      icon: icon,
      label: label,
      onPressed: onPressed,
      enabled: enabled,
      isLoading: isLoading,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      padding: padding,
      iconSize: iconSize,
    );
  }

  /// Build social stats widget
  static Widget socialStats({
    required Map<String, dynamic> stats,
    bool showLabels = true,
    bool horizontal = true,
    EdgeInsets? padding,
    Color? textColor,
    TextStyle? valueStyle,
    TextStyle? labelStyle,
  }) {
    return SocialFacade.socialStats(
      stats: stats,
      showLabels: showLabels,
      horizontal: horizontal,
      padding: padding,
      textColor: textColor,
      valueStyle: valueStyle,
      labelStyle: labelStyle,
    );
  }

  // ===== SOCIAL HELPERS =====

  /// Format user display name
  static String formatUserDisplayName(UserProfile? user, {String fallback = 'Okänd användare'}) {
    return SocialFacade.formatUserDisplayName(user, fallback: fallback);
  }

  /// Check if user is online
  static bool isUserOnline(UserProfile? user) {
    return SocialFacade.isUserOnline(user);
  }

  /// Get user avatar URL
  static String? getUserAvatarUrl(UserProfile? user) {
    return SocialFacade.getUserAvatarUrl(user);
  }

  /// Format invitation target display name
  static String formatInvitationTargetDisplayName(InvitationTarget target) {
    return SocialFacade.formatInvitationTargetDisplayName(target);
  }

  /// Get invitation target type icon
  static IconData getInvitationTargetTypeIcon(InvitationTarget target) {
    return SocialFacade.getInvitationTargetTypeIcon(target);
  }

  // ===== INVITATION TARGET STATES =====

  /// Build target list loading state
  static Widget targetListLoading() {
    return const Center(child: CircularProgressIndicator());
  }

  /// Build target card loading state
  static Widget targetCardLoading() {
    return const Card(child: Center(child: CircularProgressIndicator()));
  }

  /// Build target loading error state
  static Widget targetLoadingError({
    String? message,
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(message ?? 'Ett fel inträffade'),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Försök igen'),
            ),
          ],
        ],
      ),
    );
  }

  /// Build no targets available state
  static Widget noTargetsAvailable({
    String? message,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message ?? 'Inga mål tillgängliga'),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  /// Build no search results state
  static Widget noSearchResults({
    String? searchQuery,
    VoidCallback? onClearSearch,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Inga resultat för "${searchQuery ?? ''}"'),
          if (onClearSearch != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onClearSearch,
              child: const Text('Rensa sökning'),
            ),
          ],
        ],
      ),
    );
  }

  /// Build targets selected success state
  static Widget targetsSelectedSuccess({
    required int count,
    VoidCallback? onContinue,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 48, color: Colors.green),
          const SizedBox(height: 16),
          Text('$count mål valda'),
          if (onContinue != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onContinue,
              child: const Text('Fortsätt'),
            ),
          ],
        ],
      ),
    );
  }
}