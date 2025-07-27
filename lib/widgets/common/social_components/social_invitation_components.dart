// lib/widgets/common/social_components/social_invitation_components.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/invitations/invitation_target.dart';

// Focused modules
import 'package:butlery/widgets/common/social_components/invitation_displays.dart';
import 'package:butlery/widgets/common/social_components/invitation_selectors.dart';
import 'package:butlery/widgets/common/social_components/invitation_lists.dart';
import 'package:butlery/widgets/common/social_components/invitation_states.dart';
import 'package:butlery/widgets/common/social_components/invitation_actions.dart';

/// Clean facade for social invitation components using focused modules
/// 
/// This facade provides a unified API that delegates to focused modules:
/// - InvitationDisplays: Target cards, chips, tiles, badges
/// - InvitationSelectors: Selection interfaces and filtering
/// - InvitationLists: List and grid layouts
/// - InvitationStates: Loading, error, empty, success states
/// - InvitationActions: Quick actions and bulk operations
/// 
/// ❌ DOES NOT CONTAIN: Business logic, API calls, complex state management
class SocialInvitationComponents {

  // ===== DISPLAY WIDGETS (DELEGATE TO INVITATION_DISPLAYS) =====

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
    return InvitationDisplays.invitationTargetDisplay(
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
    return InvitationDisplays.targetCard(
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
    return InvitationDisplays.targetChip(
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
    return InvitationDisplays.targetListTile(
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
    return InvitationDisplays.targetBadge(
      target: target,
      showCount: showCount,
      backgroundColor: backgroundColor,
      textColor: textColor,
      padding: padding,
      fontSize: fontSize,
    );
  }

  // ===== LIST AND GRID LAYOUTS (DELEGATE TO INVITATION_LISTS) =====

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
    return InvitationLists.targetList(
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
    return InvitationLists.targetGrid(
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

  // ===== SELECTION INTERFACES (DELEGATE TO INVITATION_SELECTORS) =====

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
    return InvitationSelectors.targetSelector(
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
    return InvitationSelectors.checkableTargetList(
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
    return InvitationSelectors.radioTargetSelector(
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
    return InvitationSelectors.targetSearchField(
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
    return InvitationSelectors.targetTypeFilters(
      availableTypes: availableTypes,
      selectedTypes: selectedTypes,
      onTypesChanged: onTypesChanged,
      allowMultiSelect: allowMultiSelect,
      padding: padding,
      spacing: spacing,
    );
  }

  // ===== ACTION WIDGETS (DELEGATE TO INVITATION_ACTIONS) =====

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
    return InvitationActions.quickSelectionButtons(
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

  // ===== EXTENDED DISPLAY METHODS (DELEGATE TO INVITATION_DISPLAYS) =====

  /// Build invitation target display with extended options
  static Widget extendedInvitationTargetDisplay({
    required InvitationTarget target,
    VoidCallback? onTap,
    bool selected = false,
    bool compact = false,
    Widget? trailing,
    bool showDescription = true,
    bool showMemberCount = true,
    bool showLastActivity = false,
    EdgeInsets? padding,
    Color? backgroundColor,
    BorderRadius? borderRadius,
  }) {
    return InvitationDisplays.extendedInvitationTargetDisplay(
      target: target,
      onTap: onTap,
      selected: selected,
      compact: compact,
      trailing: trailing,
      showDescription: showDescription,
      showMemberCount: showMemberCount,
      showLastActivity: showLastActivity,
      padding: padding,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
    );
  }

  /// Build invitation target with status
  static Widget invitationTargetWithStatus({
    required InvitationTarget target,
    String? status, // 'pending', 'accepted', 'declined', 'expired'
    VoidCallback? onTap,
    bool showStatusIcon = true,
    Color? statusColor,
    EdgeInsets? padding,
  }) {
    return InvitationDisplays.invitationTargetWithStatus(
      target: target,
      status: status,
      onTap: onTap,
      showStatusIcon: showStatusIcon,
      statusColor: statusColor,
      padding: padding,
    );
  }

  /// Build detailed target card
  static Widget detailedTargetCard({
    required InvitationTarget target,
    VoidCallback? onTap,
    bool selected = false,
    bool showActions = true,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onViewMembers,
    EdgeInsets? padding,
  }) {
    return InvitationDisplays.detailedTargetCard(
      target: target,
      onTap: onTap,
      selected: selected,
      showActions: showActions,
      onEdit: onEdit,
      onDelete: onDelete,
      onViewMembers: onViewMembers,
      padding: padding,
    );
  }

  /// Build compact target list
  static Widget compactTargetList({
    required List<InvitationTarget> targets,
    Function(InvitationTarget)? onTargetTap,
    bool showIcons = true,
    int? maxItems,
    String? moreItemsText = '+{count} till',
    ScrollPhysics? physics,
  }) {
    return InvitationDisplays.compactTargetList(
      targets: targets,
      onTargetTap: onTargetTap,
      showIcons: showIcons,
      maxItems: maxItems,
      moreItemsText: moreItemsText,
      physics: physics,
    );
  }

  // ===== STATE WIDGETS (DELEGATE TO INVITATION_STATES) =====

  /// Build target list loading state
  static Widget targetListLoading({
    String? text = 'Laddar målgrupper...',
  }) {
    return InvitationStates.targetListLoading(text: text);
  }

  /// Build target card loading state
  static Widget targetCardLoading({
    int count = 3,
  }) {
    return InvitationStates.targetCardLoading(count: count);
  }

  /// Build target loading error state
  static Widget targetLoadingError({
    String? title = 'Kunde inte ladda målgrupper',
    String? message = 'Kontrollera din internetanslutning och försök igen.',
    VoidCallback? onRetry,
    String? retryText = 'Försök igen',
    IconData errorIcon = Icons.error_outline,
  }) {
    return InvitationStates.targetLoadingError(
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
    return InvitationStates.noTargetsAvailable(
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
    return InvitationStates.noSearchResults(
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
    return InvitationStates.targetsSelectedSuccess(
      selectedCount: selectedCount,
      title: title,
      message: message,
      icon: icon,
      onContinue: onContinue,
      continueButtonText: continueButtonText,
      successColor: successColor,
    );
  }

  // ===== MANAGEMENT HELPERS (DELEGATE TO INVITATION_SELECTORS) =====

  /// Build target selection summary
  /// 
  /// Shows summary of selected targets
  static Widget targetSelectionSummary({
    required List<InvitationTarget> selectedTargets,
    VoidCallback? onClearAll,
    Function(InvitationTarget)? onRemoveTarget,
    String? title = 'Valda målgrupper',
    bool showClearAll = true,
    bool compact = false,
    EdgeInsets? padding,
  }) {
    return InvitationSelectors.targetSelectionSummary(
      selectedTargets: selectedTargets,
      onClearAll: onClearAll,
      onRemoveTarget: onRemoveTarget,
      title: title,
      showClearAll: showClearAll,
      compact: compact,
      padding: padding,
    );
  }

  /// Build target filtering widget
  /// 
  /// Complete filtering interface for targets
  static Widget targetFiltering({
    required List<InvitationTarget> allTargets,
    required List<InvitationTarget> filteredTargets,
    Function(List<InvitationTarget>)? onFilterChanged,
    bool showSearch = true,
    bool showTypeFilters = true,
    bool showSorting = true,
    EdgeInsets? padding,
  }) {
    return InvitationSelectors.targetFiltering(
      allTargets: allTargets,
      filteredTargets: filteredTargets,
      onFilterChanged: onFilterChanged,
      showSearch: showSearch,
      showTypeFilters: showTypeFilters,
      showSorting: showSorting,
      padding: padding,
    );
  }
}