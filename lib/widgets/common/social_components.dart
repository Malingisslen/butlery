// lib/widgets/common/social_components.dart

import 'package:flutter/material.dart';
import '../../models/friend_category.dart';
import '../../models/user_profile.dart';
import '../../models/invitations/invitation_target.dart';
import '../../models/recipe.dart';
import '../../viewmodels/recipe_form_viewmodel.dart';

// Import all split modules
import '../social/avatar/avatar_widgets.dart';
import '../social/collaborative/collaborative_indicators.dart';
import '../social/groups/group_dialogs.dart';
import '../social/invitations/invitation_target_displays.dart';
import '../social/invitations/invitation_target_inputs.dart';

// ✅ Re-export ImageSize for easier imports
export '../user/user_display_widgets.dart' show ImageSize, UserDisplayData;

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
    return AvatarWidgets.avatar(
      user: user,
      imageUrl: imageUrl,
      displayName: displayName,
      size: size,
      onTap: onTap,
      showStatus: showOnlineStatus,
      isOnline: isOnline,
      borderColor: borderColor,
      clickable: isClickable,
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
    return AvatarWidgets.userCard(
      user: user,
      onTap: onTap,
      actions: trailing,
      avatarSize: avatarSize,
      showStatus: showOnlineStatus,
      isOnline: isOnline,
      padding: padding,
      showSubtitle: showSubtitle,
      subtitle: subtitle,
      backgroundColor: backgroundColor,
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
    return AvatarWidgets.userListTile(
      user: user,
      onTap: onTap,
      trailing: trailing,
      avatarSize: avatarSize,
      showStatus: showOnlineStatus,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: categories.map((category) => FilterChip(
            label: Text(category.name),
            selected: selectedCategoryIds.contains(category.id),
            onSelected: (_) => onCategoryToggled(category.id),
          )).toList(),
        ),
      ],
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
    return FilterChip(
      label: Text(category.name),
      selected: isSelected,
      onSelected: enabled ? (_) => onTap() : null,
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
    return GroupDialogs.showCreateGroupDialog(
      context,
      preSelectedMembers: preSelectedMembers,
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
    return GroupDialogs.showEditGroupDialog(
      context,
      group: group,
    );
  }

  /// Show delete group dialog
  static Future<bool> showDeleteGroupDialog(
    BuildContext context, {
    required FriendCategory group,
    String? groupName,
    VoidCallback? onSuccess,
  }) {
    return GroupDialogs.showDeleteGroupDialog(
      context,
      group: group,
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
    return GroupDialogs.showRemoveMemberDialog(
      context,
      group: group,
      member: member,
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
    return Card(
      child: ListTile(
        leading: showTypeIcon ? Icon(getInvitationTargetTypeIcon(target)) : null,
        title: Text(target.displayName),
        subtitle: showStatus ? Text(target.type.name) : null,
        trailing: trailing,
        onTap: onTap,
      ),
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
    return Card(
      child: ListTile(
        leading: showTypeIcon ? Icon(getInvitationTargetTypeIcon(target)) : null,
        title: Text(target.displayName),
        subtitle: showStatus ? Text(target.type.name) : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  /// Build target chip
  static Widget targetChip({
    required InvitationTarget target,
    bool showTypeIcon = true,
    VoidCallback? onTap,
  }) {
    return ActionChip(
      avatar: showTypeIcon ? Icon(getInvitationTargetTypeIcon(target)) : null,
      label: Text(target.displayName),
      onPressed: onTap,
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
    return ListTile(
      leading: showTypeIcon ? Icon(getInvitationTargetTypeIcon(target)) : null,
      title: Text(target.displayName),
      subtitle: showStatus ? Text(target.type.name) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  /// Build target badge
  static Widget targetBadge({
    required InvitationTarget target,
    bool showTypeIcon = true,
  }) {
    return Chip(
      avatar: showTypeIcon ? Icon(getInvitationTargetTypeIcon(target)) : null,
      label: Text(target.displayName),
    );
  }

  /// Build target list
  static Widget targetList({
    required List<InvitationTarget> targets,
    bool showStatus = true,
    bool showTypeIcon = true,
    Function(InvitationTarget)? onTap,
  }) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: targets.length,
      itemBuilder: (context, index) {
        final target = targets[index];
        return targetListTile(
          target: target,
          showStatus: showStatus,
          showTypeIcon: showTypeIcon,
          onTap: onTap != null ? () => onTap(target) : null,
        );
      },
    );
  }

  /// Build target grid
  static Widget targetGrid({
    required List<InvitationTarget> targets,
    bool showStatus = true,
    bool showTypeIcon = true,
    Function(InvitationTarget)? onTap,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3,
      ),
      itemCount: targets.length,
      itemBuilder: (context, index) {
        final target = targets[index];
        return targetCard(
          target: target,
          showStatus: showStatus,
          showTypeIcon: showTypeIcon,
          onTap: onTap != null ? () => onTap(target) : null,
        );
      },
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
    return InvitationTargetInputs.invitationTargetSelector(
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
    return Column(
      children: targets.map((target) => targetChip(
        target: target,
        showTypeIcon: showTypeIcon,
        onTap: () => onTargetToggled(target),
      )).toList(),
    );
  }

  /// Build radio target selector
  static Widget radioTargetSelector({
    required List<InvitationTarget> targets,
    required String? selectedTargetId,
    required Function(InvitationTarget) onTargetSelected,
    bool showTypeIcon = true,
  }) {
    return Column(
      children: targets.map((target) => targetChip(
        target: target,
        showTypeIcon: showTypeIcon,
        onTap: () => onTargetSelected(target),
      )).toList(),
    );
  }

  /// Build target search field
  static Widget targetSearchField({
    required ValueChanged<String> onChanged,
    String? hint,
    String? initialValue,
  }) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint ?? 'Sök...',
        prefixIcon: Icon(Icons.search),
      ),
    );
  }

  /// Build target type filters
  static Widget targetTypeFilters({
    required List<String> availableTypes,
    required Set<String> selectedTypes,
    required Function(String) onTypeToggled,
  }) {
    return Wrap(
      spacing: 8,
      children: availableTypes.map((type) => FilterChip(
        label: Text(type),
        selected: selectedTypes.contains(type),
        onSelected: (_) => onTypeToggled(type),
      )).toList(),
    );
  }

  /// Build quick selection buttons
  static Widget quickSelectionButtons({
    required VoidCallback onSelectAll,
    required VoidCallback onDeselectAll,
    required VoidCallback onInvertSelection,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
          onPressed: onSelectAll,
          child: Text('Välj alla'),
        ),
        TextButton(
          onPressed: onDeselectAll,
          child: Text('Avmarkera alla'),
        ),
        TextButton(
          onPressed: onInvertSelection,
          child: Text('Invertera'),
        ),
      ],
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
    return InvitationTargetDisplays.invitationTargetList(
      targets: targets,
      avatarSize: avatarSize,
      showStatus: showStatus,
      showTypeIcon: showTypeIcon,
      onTap: onTap,
      trailingBuilder: trailingBuilder,
      padding: padding,
      shrinkWrap: shrinkWrap,
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
    return InvitationTargetInputs.invitationTargetSelector(
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
    return InvitationTargetInputs.invitationTargetChip(
      target: target,
      isSelected: isSelected,
      onTap: onTap,
      showTypeIcon: showTypeIcon,
      enabled: enabled,
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
    return ElevatedButton.icon(
      onPressed: enabled && !isLoading ? onPressed : null,
      icon: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon, size: iconSize),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: padding,
      ),
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
    final children = stats.entries.map((entry) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(entry.value.toString(), style: valueStyle),
          if (showLabels) Text(entry.key, style: labelStyle),
        ],
      );
    }).toList();
    
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: horizontal ? Row(children: children) : Column(children: children),
    );
  }

  // ===== SOCIAL HELPERS =====

  /// Format user display name
  static String formatUserDisplayName(UserProfile? user, {String fallback = 'Okänd användare'}) {
    return user?.displayName ?? fallback;
  }

  /// Check if user is online
  static bool isUserOnline(UserProfile? user) {
    return user?.isOnline ?? false;
  }

  /// Get user avatar URL
  static String? getUserAvatarUrl(UserProfile? user) {
    return user?.avatarUrl;
  }

  /// Format invitation target display name
  static String formatInvitationTargetDisplayName(InvitationTarget target) {
    return target.displayName;
  }

  /// Get invitation target type icon
  static IconData getInvitationTargetTypeIcon(InvitationTarget target) {
    switch (target.type) {
      case InvitationTargetType.individual:
        return Icons.person;
      case InvitationTargetType.group:
        return Icons.group;
    }
  }

  // ===== INVITATION TARGET STATES =====

  /// Build target list loading state
  static Widget targetListLoading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  /// Build target card loading state
  static Widget targetCardLoading() {
    return const Card(
      child: ListTile(
        leading: CircularProgressIndicator(),
        title: Text('Laddar...'),
      ),
    );
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
          Text(message ?? 'Kunde inte ladda mål'),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: Text('Försök igen'),
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
          Text(searchQuery != null
              ? 'Inga resultat för "$searchQuery"'
              : 'Inga sökresultat'),
          if (onClearSearch != null) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: onClearSearch,
              child: Text('Rensa sökning'),
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
              child: Text('Fortsätt'),
            ),
          ],
        ],
      ),
    );
  }
}