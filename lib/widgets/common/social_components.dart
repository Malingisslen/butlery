// lib/widgets/common/social_components.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';

// Import focused modules
import 'package:butlery/widgets/common/social_components/social_avatar_components.dart';
import 'package:butlery/widgets/common/social_components/social_collaborative_components.dart';
import 'package:butlery/widgets/common/social_components/social_group_components.dart';
import 'package:butlery/widgets/common/social_components/social_invitation_components.dart';
import 'package:butlery/widgets/common/social_components/social_builder_components.dart';

// ✅ Re-export ImageSize for easier imports
export '../user/user_display_widgets.dart' show ImageSize, UserDisplayData;
export 'social_components/social_avatar_components.dart';
export 'social_components/social_collaborative_components.dart';
export 'social_components/social_group_components.dart';
export 'social_components/social_invitation_components.dart';
export 'social_components/social_builder_components.dart';

// Import ImageSize for local usage
import 'package:butlery/widgets/user/user_display_widgets.dart' show ImageSize;

/// 🚀 SocialComponents - The ultimate social widget API
///
/// Clean barrel export that consolidates all social-related widgets into a unified API 
/// through delegation to focused single-responsibility modules:
/// - ✅ Avatar widgets (delegates to SocialAvatarComponents)
/// - ✅ Collaborative indicators (delegates to SocialCollaborativeComponents)
/// - ✅ Friend category management (delegates to SocialGroupComponents)
/// - ✅ Invitation target widgets (delegates to SocialInvitationComponents)
/// - ✅ Social builders and helpers (delegates to SocialBuilderComponents)
/// - ✅ 100% backward compatibility maintained
/// - ✅ Clean modular architecture for maintainability
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
///
/// ARCHITECTURE:
/// This file now serves as a clean facade that delegates to focused modules:
/// - Each module has a single responsibility
/// - Backward compatibility maintained through delegation
/// - Better maintainability with focused concerns
/// - Easier testing with isolated modules
class SocialComponents {
  
  // ===== USER DISPLAY & AVATARS (Delegated to SocialAvatarComponents) =====

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
    Color? backgroundColor,
    bool showBorder = false,
  }) {
    return SocialAvatarComponents.avatar(
      user: user,
      imageUrl: imageUrl,
      displayName: displayName,
      size: size,
      onTap: onTap,
      showOnlineStatus: showOnlineStatus,
      isOnline: isOnline,
      padding: padding,
      backgroundColor: backgroundColor,
      showBorder: showBorder,
    );
  }

  /// Build user card with avatar and information
  static Widget userCard({
    required UserProfile user,
    VoidCallback? onTap,
    ImageSize avatarSize = ImageSize.medium,
    bool showOnlineStatus = false,
    bool isOnline = false,
    EdgeInsets? padding,
    bool showSubtitle = true,
    String? subtitle,
    Color? backgroundColor,
    bool showBorder = false,
  }) {
    return SocialAvatarComponents.userCard(
      user: user,
      onTap: onTap,
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
    return SocialAvatarComponents.userListTile(
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

  // ===== COLLABORATIVE INDICATORS (Delegated to SocialCollaborativeComponents) =====

  /// Build collaborative status badge
  static Widget collaborativeStatusBadge({
    String text = 'Delat',
    IconData icon = Icons.people,
    Color? color,
    EdgeInsets? padding,
  }) {
    return SocialCollaborativeComponents.collaborativeStatusBadge(
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
    return SocialCollaborativeComponents.collaborativeBanner(
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
    return SocialCollaborativeComponents.smartPermissionsBanner(
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
    return SocialCollaborativeComponents.collaborativeAppBar(
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
    String contentType = 'recipe',
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return SocialCollaborativeComponents.smartCollaborativeBanner(
      context: context,
      contentId: contentId,
      contentType: contentType,
      onTap: onTap,
      trailing: trailing,
    );
  }

  /// Build collaborative status indicator
  static Widget collaborativeStatusIndicator({
    required String contentId,
    String contentType = 'recipe',
    bool showText = true,
    Color? activeColor,
    Color? inactiveColor,
  }) {
    return SocialCollaborativeComponents.collaborativeStatusIndicator(
      contentId: contentId,
      contentType: contentType,
      showText: showText,
      activeColor: activeColor,
      inactiveColor: inactiveColor,
    );
  }

  /// Build participants list
  static Widget participantsList({
    required String contentId,
    String contentType = 'recipe',
    int maxParticipants = 5,
    bool horizontal = true,
    VoidCallback? onViewAll,
  }) {
    return SocialCollaborativeComponents.participantsList(
      contentId: contentId,
      contentType: contentType,
      maxParticipants: maxParticipants,
      horizontal: horizontal,
      onViewAll: onViewAll,
    );
  }

  // ===== FRIEND CATEGORY MANAGEMENT (Delegated to SocialGroupComponents) =====

  /// Build friend category selector
  static Widget friendCategorySelector({
    required List<FriendCategory> categories,
    FriendCategory? selectedCategory,
    Function(FriendCategory?)? onCategoryChanged,
    String? hint,
    bool enabled = true,
    Widget? leading,
    Widget? trailing,
    EdgeInsets? padding,
    Color? backgroundColor,
    BorderRadius? borderRadius,
  }) {
    return SocialGroupComponents.friendCategorySelector(
      categories: categories,
      selectedCategory: selectedCategory,
      onCategoryChanged: onCategoryChanged,
      hint: hint,
      enabled: enabled,
      leading: leading,
      trailing: trailing,
      padding: padding,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
    );
  }

  /// Build friend category chip
  static Widget friendCategoryChip({
    required FriendCategory category,
    bool selected = false,
    VoidCallback? onTap,
    VoidCallback? onDeleted,
    Color? backgroundColor,
    Color? selectedColor,
    EdgeInsets? padding,
  }) {
    return SocialGroupComponents.friendCategoryChip(
      category: category,
      selected: selected,
      onTap: onTap,
      onDeleted: onDeleted,
      backgroundColor: backgroundColor,
      selectedColor: selectedColor,
      padding: padding,
    );
  }

  // ===== GROUP DIALOGS (Delegated to SocialGroupComponents) =====

  /// Show create group dialog
  static Future<bool?> showCreateGroupDialog({
    required BuildContext context,
    List<String>? preselectedMemberIds,
    String? initialGroupName,
    Function(String groupName, List<String> memberIds)? onGroupCreated,
  }) {
    return SocialGroupComponents.showCreateGroupDialog(
      context: context,
      preselectedMemberIds: preselectedMemberIds,
      initialGroupName: initialGroupName,
      onGroupCreated: onGroupCreated,
    );
  }

  /// Show edit group dialog
  static Future<bool?> showEditGroupDialog({
    required BuildContext context,
    required String groupId,
    String? currentGroupName,
    List<String>? currentMemberIds,
    Function(String groupName, List<String> memberIds)? onGroupUpdated,
  }) {
    return SocialGroupComponents.showEditGroupDialog(
      context: context,
      groupId: groupId,
      currentGroupName: currentGroupName,
      currentMemberIds: currentMemberIds,
      onGroupUpdated: onGroupUpdated,
    );
  }

  /// Show delete group dialog
  static Future<bool?> showDeleteGroupDialog({
    required BuildContext context,
    required String groupId,
    required String groupName,
    VoidCallback? onGroupDeleted,
  }) {
    return SocialGroupComponents.showDeleteGroupDialog(
      context: context,
      groupId: groupId,
      groupName: groupName,
      onGroupDeleted: onGroupDeleted,
    );
  }

  /// Show remove member dialog
  static Future<bool?> showRemoveMemberDialog({
    required BuildContext context,
    required String groupId,
    required String memberId,
    required String memberName,
    VoidCallback? onMemberRemoved,
  }) {
    return SocialGroupComponents.showRemoveMemberDialog(
      context: context,
      groupId: groupId,
      memberId: memberId,
      memberName: memberName,
      onMemberRemoved: onMemberRemoved,
    );
  }

  // ===== INVITATION TARGET WIDGETS (Delegated to SocialInvitationComponents) =====

  /// Build invitation target display
  static Widget invitationTargetDisplay({
    required InvitationTarget target,
    VoidCallback? onTap,
    bool selected = false,
    bool compact = false,
    Widget? trailing,
    EdgeInsets? padding,
    Color? backgroundColor,
    BorderRadius? borderRadius,
  }) {
    return SocialInvitationComponents.invitationTargetDisplay(
      target: target,
      onTap: onTap,
      selected: selected,
      compact: compact,
      trailing: trailing,
      padding: padding,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
    );
  }

  /// Build target card
  static Widget targetCard({
    required InvitationTarget target,
    VoidCallback? onTap,
    bool selected = false,
    Widget? trailing,
    bool showType = true,
    bool showMemberCount = true,
    EdgeInsets? padding,
    Color? backgroundColor,
  }) {
    return SocialInvitationComponents.targetCard(
      target: target,
      onTap: onTap,
      selected: selected,
      trailing: trailing,
      showType: showType,
      showMemberCount: showMemberCount,
      padding: padding,
      backgroundColor: backgroundColor,
    );
  }

  /// Build target chip
  static Widget targetChip({
    required InvitationTarget target,
    VoidCallback? onTap,
    VoidCallback? onDeleted,
    bool selected = false,
    Color? backgroundColor,
    Color? selectedColor,
    EdgeInsets? padding,
  }) {
    return SocialInvitationComponents.targetChip(
      target: target,
      onTap: onTap,
      onDeleted: onDeleted,
      selected: selected,
      backgroundColor: backgroundColor,
      selectedColor: selectedColor,
      padding: padding,
    );
  }

  /// Build target list tile
  static Widget targetListTile({
    required InvitationTarget target,
    VoidCallback? onTap,
    bool selected = false,
    Widget? trailing,
    bool showSubtitle = true,
    bool enabled = true,
    EdgeInsets? contentPadding,
  }) {
    return SocialInvitationComponents.targetListTile(
      target: target,
      onTap: onTap,
      selected: selected,
      trailing: trailing,
      showSubtitle: showSubtitle,
      enabled: enabled,
      contentPadding: contentPadding,
    );
  }

  /// Build target badge
  static Widget targetBadge({
    required InvitationTarget target,
    bool showCount = false,
    Color? backgroundColor,
    Color? textColor,
    EdgeInsets? padding,
    double? fontSize,
  }) {
    return SocialInvitationComponents.targetBadge(
      target: target,
      showCount: showCount,
      backgroundColor: backgroundColor,
      textColor: textColor,
      padding: padding,
      fontSize: fontSize,
    );
  }

  /// Build target list
  static Widget targetList({
    required List<InvitationTarget> targets,
    Function(InvitationTarget)? onTargetTap,
    bool allowMultiSelect = false,
    List<InvitationTarget>? selectedTargets,
    Function(List<InvitationTarget>)? onSelectionChanged,
    bool showTrailing = true,
    ScrollPhysics? physics,
    EdgeInsets? padding,
  }) {
    return SocialInvitationComponents.targetList(
      targets: targets,
      onTargetTap: onTargetTap,
      allowMultiSelect: allowMultiSelect,
      selectedTargets: selectedTargets,
      onSelectionChanged: onSelectionChanged,
      showTrailing: showTrailing,
      physics: physics,
      padding: padding,
    );
  }

  /// Build target grid
  static Widget targetGrid({
    required List<InvitationTarget> targets,
    Function(InvitationTarget)? onTargetTap,
    bool allowMultiSelect = false,
    List<InvitationTarget>? selectedTargets,
    Function(List<InvitationTarget>)? onSelectionChanged,
    int crossAxisCount = 2,
    double crossAxisSpacing = 8.0,
    double mainAxisSpacing = 8.0,
    EdgeInsets? padding,
  }) {
    return SocialInvitationComponents.targetGrid(
      targets: targets,
      onTargetTap: onTargetTap,
      allowMultiSelect: allowMultiSelect,
      selectedTargets: selectedTargets,
      onSelectionChanged: onSelectionChanged,
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      padding: padding,
    );
  }

  /// Build target selector
  static Widget targetSelector({
    required List<InvitationTarget> availableTargets,
    List<InvitationTarget>? selectedTargets,
    Function(List<InvitationTarget>)? onSelectionChanged,
    bool allowMultiSelect = true,
    bool showSearch = true,
    bool showTypeFilters = true,
    String? searchHint,
    int? maxSelections,
    Widget? emptyWidget,
    ScrollPhysics? physics,
  }) {
    return SocialInvitationComponents.targetSelector(
      availableTargets: availableTargets,
      selectedTargets: selectedTargets,
      onSelectionChanged: onSelectionChanged,
      allowMultiSelect: allowMultiSelect,
      showSearch: showSearch,
      showTypeFilters: showTypeFilters,
      searchHint: searchHint,
      maxSelections: maxSelections,
      emptyWidget: emptyWidget,
      physics: physics,
    );
  }

  /// Build checkable target list
  static Widget checkableTargetList({
    required List<InvitationTarget> targets,
    List<InvitationTarget>? selectedTargets,
    Function(List<InvitationTarget>)? onSelectionChanged,
    bool showSelectAll = true,
    String? selectAllText = 'Välj alla',
    String? selectNoneText = 'Avmarkera alla',
    ScrollPhysics? physics,
    EdgeInsets? padding,
  }) {
    return SocialInvitationComponents.checkableTargetList(
      targets: targets,
      selectedTargets: selectedTargets,
      onSelectionChanged: onSelectionChanged,
      showSelectAll: showSelectAll,
      selectAllText: selectAllText,
      selectNoneText: selectNoneText,
      physics: physics,
      padding: padding,
    );
  }

  /// Build radio target selector
  static Widget radioTargetSelector({
    required List<InvitationTarget> targets,
    InvitationTarget? selectedTarget,
    Function(InvitationTarget?)? onSelectionChanged,
    ScrollPhysics? physics,
    EdgeInsets? padding,
  }) {
    return SocialInvitationComponents.radioTargetSelector(
      targets: targets,
      selectedTarget: selectedTarget,
      onSelectionChanged: onSelectionChanged,
      physics: physics,
      padding: padding,
    );
  }

  /// Build target search field
  static Widget targetSearchField({
    Function(String)? onSearchChanged,
    String? hint = 'Sök målgrupper...',
    IconData prefixIcon = Icons.search,
    bool autofocus = false,
    TextEditingController? controller,
    EdgeInsets? margin,
  }) {
    return SocialInvitationComponents.targetSearchField(
      onSearchChanged: onSearchChanged,
      hint: hint,
      prefixIcon: prefixIcon,
      autofocus: autofocus,
      controller: controller,
      margin: margin,
    );
  }

  /// Build target type filters
  static Widget targetTypeFilters({
    required List<String> availableTypes,
    List<String>? selectedTypes,
    Function(List<String>)? onTypesChanged,
    bool allowMultiSelect = true,
    EdgeInsets? padding,
    double spacing = 8.0,
  }) {
    return SocialInvitationComponents.targetTypeFilters(
      availableTypes: availableTypes,
      selectedTypes: selectedTypes,
      onTypesChanged: onTypesChanged,
      allowMultiSelect: allowMultiSelect,
      padding: padding,
      spacing: spacing,
    );
  }

  /// Build quick selection buttons
  static Widget quickSelectionButtons({
    VoidCallback? onSelectAll,
    VoidCallback? onSelectNone,
    VoidCallback? onSelectFriends,
    VoidCallback? onSelectGroups,
    String? selectAllText = 'Alla',
    String? selectNoneText = 'Inga',
    String? selectFriendsText = 'Vänner',
    String? selectGroupsText = 'Grupper',
    EdgeInsets? padding,
    MainAxisAlignment alignment = MainAxisAlignment.spaceEvenly,
  }) {
    return SocialInvitationComponents.quickSelectionButtons(
      onSelectAll: onSelectAll,
      onSelectNone: onSelectNone,
      onSelectFriends: onSelectFriends,
      onSelectGroups: onSelectGroups,
      selectAllText: selectAllText,
      selectNoneText: selectNoneText,
      selectFriendsText: selectFriendsText,
      selectGroupsText: selectGroupsText,
      padding: padding,
      alignment: alignment,
    );
  }

  // ===== SOCIAL BUILDERS (Delegated to SocialBuilderComponents) =====

  /// Build social action button
  static Widget socialActionButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    Color? backgroundColor,
    Color? textColor,
    EdgeInsets? padding,
    bool outlined = false,
    bool compact = false,
    bool loading = false,
  }) {
    return SocialBuilderComponents.socialActionButton(
      text: text,
      onPressed: onPressed,
      icon: icon,
      backgroundColor: backgroundColor,
      textColor: textColor,
      padding: padding,
      outlined: outlined,
      compact: compact,
      loading: loading,
    );
  }

  /// Build social stats widget
  static Widget socialStats({
    required Map<String, dynamic> stats,
    bool horizontal = true,
    EdgeInsets? padding,
    Color? backgroundColor,
    BorderRadius? borderRadius,
    bool showLabels = true,
    bool showIcons = true,
  }) {
    return SocialBuilderComponents.socialStats(
      stats: stats,
      horizontal: horizontal,
      padding: padding,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      showLabels: showLabels,
      showIcons: showIcons,
    );
  }

  // ===== SOCIAL HELPERS (Delegated to SocialBuilderComponents) =====

  /// Format user display name consistently
  static String formatUserDisplayName(dynamic user) {
    return SocialBuilderComponents.formatUserDisplayName(user);
  }

  /// Check if user is currently online
  static bool isUserOnline(dynamic user) {
    return SocialBuilderComponents.isUserOnline(user);
  }

  /// Get user avatar URL with fallbacks
  static String? getUserAvatarUrl(dynamic user) {
    return SocialBuilderComponents.getUserAvatarUrl(user);
  }

  /// Format invitation target display name
  static String formatInvitationTargetDisplayName(InvitationTarget target) {
    return SocialBuilderComponents.formatInvitationTargetDisplayName(target);
  }

  /// Get invitation target type icon
  static IconData getInvitationTargetTypeIcon(String targetType) {
    return SocialBuilderComponents.getInvitationTargetTypeIcon(targetType);
  }

  // ===== INVITATION TARGET STATES (Delegated to SocialInvitationComponents) =====

  /// Build target list loading state
  static Widget targetListLoading({
    String? text = 'Laddar målgrupper...',
  }) {
    return SocialInvitationComponents.targetListLoading(text: text);
  }

  /// Build target card loading state
  static Widget targetCardLoading({
    int count = 3,
  }) {
    return SocialInvitationComponents.targetCardLoading(count: count);
  }

  /// Build target loading error state
  static Widget targetLoadingError({
    String? title = 'Kunde inte ladda målgrupper',
    String? message = 'Kontrollera din internetanslutning och försök igen.',
    VoidCallback? onRetry,
    String? retryText = 'Försök igen',
    IconData errorIcon = Icons.error_outline,
  }) {
    return SocialInvitationComponents.targetLoadingError(
      title: title,
      message: message,
      onRetry: onRetry,
      retryText: retryText,
      errorIcon: errorIcon,
    );
  }

  /// Build no targets available state
  static Widget noTargetsAvailable({
    String? title = 'Inga målgrupper tillgängliga',
    String? message = 'Du har inte lagt till några vänner eller grupper än.',
    IconData icon = Icons.group_outlined,
    VoidCallback? onAddTargets,
    String? addButtonText = 'Lägg till vänner',
    bool showAddButton = true,
  }) {
    return SocialInvitationComponents.noTargetsAvailable(
      title: title,
      message: message,
      icon: icon,
      onAddTargets: onAddTargets,
      addButtonText: addButtonText,
      showAddButton: showAddButton,
    );
  }

  /// Build no search results state
  static Widget noSearchResults({
    String? query,
    String? title = 'Inga sökresultat',
    String? message = 'Prova att söka med andra ord eller kontrollera stavningen.',
    IconData icon = Icons.search_off,
    VoidCallback? onClearSearch,
    String? clearButtonText = 'Rensa sökning',
    bool showClearButton = true,
  }) {
    return SocialInvitationComponents.noSearchResults(
      query: query,
      title: title,
      message: message,
      icon: icon,
      onClearSearch: onClearSearch,
      clearButtonText: clearButtonText,
      showClearButton: showClearButton,
    );
  }

  /// Build targets selected success state
  static Widget targetsSelectedSuccess({
    required int selectedCount,
    String? title = 'Målgrupper valda',
    String? message = 'Du har valt {count} målgrupper för inbjudan.',
    IconData icon = Icons.check_circle_outline,
    VoidCallback? onContinue,
    String? continueButtonText = 'Fortsätt',
    Color? successColor = Colors.green,
  }) {
    return SocialInvitationComponents.targetsSelectedSuccess(
      selectedCount: selectedCount,
      title: title,
      message: message,
      icon: icon,
      onContinue: onContinue,
      continueButtonText: continueButtonText,
      successColor: successColor,
    );
  }
}