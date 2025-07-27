// lib/widgets/social/social_components.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/widgets/social/invitations/invitation_target_displays.dart';
import 'package:butlery/widgets/social/invitations/invitation_target_inputs.dart';
import 'package:butlery/widgets/social/invitations/invitation_target_states.dart';

/// Social components - delegates to focused widgets
class SocialComponents {
  // ===== INVITATION TARGET DISPLAYS =====

  /// Build target card
  static Widget targetCard({
    required InvitationTarget target,
    bool showStatus = true,
    bool showTypeIcon = true,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InvitationTargetDisplays.buildTargetCard(
      target,
      onTap: onTap,
      showTypeIcon: showTypeIcon,
    );
  }

  /// Build target chip
  static Widget targetChip({
    required InvitationTarget target,
    bool showTypeIcon = true,
    VoidCallback? onTap,
  }) {
    return InvitationTargetDisplays.buildTargetChip(
      target,
      onTap: onTap,
      showCount: showTypeIcon,
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
    return InvitationTargetDisplays.buildTargetListTile(
      target,
      onTap: onTap,
      trailing: trailing,
      showSubtitle: showStatus,
    );
  }

  /// Build target badge
  static Widget targetBadge({
    required InvitationTarget target,
    bool showTypeIcon = true,
  }) {
    return InvitationTargetDisplays.buildTargetChip(
      target,
      showCount: showTypeIcon,
    );
  }

  /// Build target list
  static Widget targetList({
    required List<InvitationTarget> targets,
    Function(InvitationTarget)? onTargetTap,
    bool showDividers = true,
    bool groupByType = false,
  }) {
    return InvitationTargetDisplays.buildTargetList(
      targets,
      onTargetTap: onTargetTap ?? (_) {},
      showDividers: showDividers,
      groupByType: groupByType,
    );
  }

  /// Build target grid
  static Widget targetGrid({
    required List<InvitationTarget> targets,
    Function(InvitationTarget)? onTargetTap,
    int crossAxisCount = 2,
  }) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.5,
      ),
      itemCount: targets.length,
      itemBuilder: (context, index) {
        final target = targets[index];
        return InvitationTargetDisplays.buildTargetCard(
          target,
          onTap: onTargetTap != null ? () => onTargetTap(target) : null,
        );
      },
    );
  }

  // ===== INVITATION TARGET INPUTS =====

  /// Build target selector
  static Widget targetSelector({
    required List<InvitationTarget> availableTargets,
    required Set<String> selectedTargetIds,
    required Function(InvitationTarget) onTargetToggled,
    bool allowMultipleSelection = true,
    String? title,
    String? emptyMessage,
  }) {
    return InvitationTargetInputs.invitationTargetSelector(
      availableTargets: availableTargets,
      selectedTargetIds: selectedTargetIds,
      onTargetToggled: onTargetToggled,
      allowMultipleSelection: allowMultipleSelection,
      title: title,
      emptyMessage: emptyMessage,
    );
  }

  /// Build checkable target list
  static Widget checkableTargetList({
    required List<InvitationTarget> targets,
    required Set<String> selectedTargetIds,
    required Function(InvitationTarget, bool) onTargetToggled,
    bool groupByType = true,
  }) {
    return InvitationTargetInputs.buildCheckableTargetList(
      targets: targets,
      selectedTargetIds: selectedTargetIds,
      onTargetToggled: onTargetToggled,
      groupByType: groupByType,
    );
  }

  /// Build radio target selector
  static Widget radioTargetSelector({
    required List<InvitationTarget> availableTargets,
    required Set<String> selectedTargetIds,
    required Function(InvitationTarget) onTargetToggled,
    bool allowMultipleSelection = false,
    String? title,
    String? emptyMessage,
  }) {
    return InvitationTargetInputs.buildTargetSelector(
      availableTargets: availableTargets,
      selectedTargetIds: selectedTargetIds,
      onTargetToggled: onTargetToggled,
      allowMultipleSelection: allowMultipleSelection,
      title: title,
      emptyMessage: emptyMessage,
    );
  }

  /// Build target search field
  static Widget targetSearchField({
    required Function(String) onSearch,
    String? hintText,
    VoidCallback? onClear,
  }) {
    return InvitationTargetInputs.buildTargetSearchField(
      hint: hintText ?? 'Sök...',
      onChanged: onSearch,
      onClear: onClear,
    );
  }

  /// Build target type filters
  static Widget targetTypeFilters({
    Set<InvitationTargetType> selectedTypes = const {},
    Function(Set<InvitationTargetType>)? onTypesChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Individual'),
            selected: selectedTypes.contains(InvitationTargetType.individual),
            onSelected: (selected) {
              final newTypes = Set<InvitationTargetType>.from(selectedTypes);
              if (selected) {
                newTypes.add(InvitationTargetType.individual);
              } else {
                newTypes.remove(InvitationTargetType.individual);
              }
              onTypesChanged?.call(newTypes);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Group'),
            selected: selectedTypes.contains(InvitationTargetType.group),
            onSelected: (selected) {
              final newTypes = Set<InvitationTargetType>.from(selectedTypes);
              if (selected) {
                newTypes.add(InvitationTargetType.group);
              } else {
                newTypes.remove(InvitationTargetType.group);
              }
              onTypesChanged?.call(newTypes);
            },
          ),
        ],
      ),
    );
  }

  /// Build quick selection buttons
  static Widget quickSelectionButtons({
    required List<InvitationTarget> targets,
    Function(List<InvitationTarget>)? onQuickSelection,
  }) {
    return Row(
      children: [
        TextButton(
          onPressed: () => onQuickSelection?.call([]),
          child: const Text('Select None'),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => onQuickSelection?.call(targets),
          child: const Text('Select All'),
        ),
      ],
    );
  }

  // ===== INVITATION TARGET STATES =====

  /// Build target list loading state
  static Widget targetListLoading() {
    return InvitationTargetStates.buildTargetListLoading();
  }

  /// Build target card loading state
  static Widget targetCardLoading() {
    return InvitationTargetStates.buildTargetCardLoading();
  }

  /// Build target loading error state
  static Widget targetLoadingError({
    String? message,
    VoidCallback? onRetry,
  }) {
    return InvitationTargetStates.buildTargetLoadingError(
      errorMessage: message,
      onRetry: onRetry,
    );
  }

  /// Build no targets available state
  static Widget noTargetsAvailable({
    String? message,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return InvitationTargetStates.buildNoTargetsAvailable();
  }

  /// Build no search results state
  static Widget noSearchResults({
    required String searchQuery,
    VoidCallback? onClearSearch,
  }) {
    return InvitationTargetStates.buildNoSearchResults(
      searchQuery: searchQuery,
      onClearSearch: onClearSearch,
    );
  }

  /// Build targets selected success state
  static Widget targetsSelectedSuccess({
    required List<InvitationTarget> selectedTargets,
    VoidCallback? onContinue,
  }) {
    return InvitationTargetStates.buildTargetsSelectedSuccess(
      targets: selectedTargets,
      onContinue: onContinue,
    );
  }
}