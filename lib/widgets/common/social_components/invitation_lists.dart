// lib/widgets/common/social_components/invitation_lists.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/widgets/common/social/social_facade.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Focused module for invitation target list and grid layouts
/// 
/// This module handles ONLY list and grid presentations:
/// - Target lists and grids with selection capabilities
/// - Layout management and scrolling behavior
/// - Collection presentations
/// 
/// ❌ DOES NOT CONTAIN: Display widgets, selectors, states, actions
class InvitationLists {

  // ===== TARGET LISTS AND GRIDS =====

  /// Build target list
  /// 
  /// Scrollable list of invitation targets
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
    return SocialFacade.targetList(
      targets: targets,
      onTap: onTargetTap,
    );
  }

  /// Build target grid
  /// 
  /// Grid layout for invitation targets
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
    return SocialFacade.targetGrid(
      targets: targets,
      onTap: onTargetTap,
    );
  }

  /// Build paginated target list
  /// 
  /// List with pagination support
  static Widget paginatedTargetList({
    required List<InvitationTarget> targets,
    Function(InvitationTarget)? onTargetTap,
    int itemsPerPage = 20,
    bool showPagination = true,
    ScrollPhysics? physics,
    EdgeInsets? padding,
  }) {
    // Simple implementation - would need proper pagination in real scenario
    return ListView.builder(
      physics: physics,
      padding: padding,
      itemCount: targets.length,
      itemBuilder: (context, index) {
        final target = targets[index];
        return ListTile(
          title: Text(target.displayName),
          subtitle: Text('${target.type.name} • ${target.memberCount ?? 0} medlemmar'),
          onTap: onTargetTap != null ? () => onTargetTap(target) : null,
        );
      },
    );
  }

  /// Build sectioned target list
  /// 
  /// List grouped by target type
  static Widget sectionedTargetList({
    required List<InvitationTarget> targets,
    Function(InvitationTarget)? onTargetTap,
    bool groupByType = true,
    ScrollPhysics? physics,
    EdgeInsets? padding,
  }) {
    if (!groupByType) {
      return targetList(
        targets: targets,
        onTargetTap: onTargetTap,
        physics: physics,
        padding: padding,
      );
    }

    // Group targets by type
    final groupedTargets = <InvitationTargetType, List<InvitationTarget>>{};
    for (final target in targets) {
      groupedTargets.putIfAbsent(target.type, () => []).add(target);
    }

    return ListView(
      physics: physics,
      padding: padding,
      children: groupedTargets.entries.map((entry) {
        final type = entry.key;
        final typeTargets = entry.value;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              child: Text(
                type == InvitationTargetType.group ? 'Grupper' : 'Individer',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...typeTargets.map((target) => ListTile(
              title: Text(target.displayName),
              subtitle: Text('${target.memberCount ?? 0} medlemmar'),
              onTap: onTargetTap != null ? () => onTargetTap(target) : null,
            )),
            const Divider(),
          ],
        );
      }).toList(),
    );
  }

  /// Build virtual scrolling target list
  /// 
  /// Optimized list for large datasets
  static Widget virtualScrollingTargetList({
    required List<InvitationTarget> targets,
    Function(InvitationTarget)? onTargetTap,
    double itemHeight = 72.0,
    ScrollPhysics? physics,
    EdgeInsets? padding,
  }) {
    // Using regular ListView.builder as Flutter handles virtualization automatically
    return ListView.builder(
      physics: physics,
      padding: padding,
      itemCount: targets.length,
      itemExtent: itemHeight,
      itemBuilder: (context, index) {
        final target = targets[index];
        return ListTile(
          title: Text(target.displayName),
          subtitle: Text('${target.type.name} • ${target.memberCount ?? 0} medlemmar'),
          onTap: onTargetTap != null ? () => onTargetTap(target) : null,
        );
      },
    );
  }

  /// Build horizontal target list
  /// 
  /// Horizontal scrolling list
  static Widget horizontalTargetList({
    required List<InvitationTarget> targets,
    Function(InvitationTarget)? onTargetTap,
    double itemWidth = 120.0,
    double itemHeight = 80.0,
    EdgeInsets? padding,
  }) {
    return SizedBox(
      height: itemHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: targets.length,
        itemBuilder: (context, index) {
          final target = targets[index];
          return SizedBox(
            width: itemWidth,
            child: Card(
              child: InkWell(
                onTap: onTargetTap != null ? () => onTargetTap(target) : null,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingSm),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        target.type == InvitationTargetType.group 
                            ? Icons.group 
                            : Icons.person,
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        target.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build staggered target grid
  /// 
  /// Grid with variable item heights
  static Widget staggeredTargetGrid({
    required List<InvitationTarget> targets,
    Function(InvitationTarget)? onTargetTap,
    int crossAxisCount = 2,
    double crossAxisSpacing = 8.0,
    double mainAxisSpacing = 8.0,
    EdgeInsets? padding,
  }) {
    // Simple grid implementation - would use flutter_staggered_grid_view in real scenario
    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: targets.length,
      itemBuilder: (context, index) {
        final target = targets[index];
        return Card(
          child: InkWell(
            onTap: onTargetTap != null ? () => onTargetTap(target) : null,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacing12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    target.type == InvitationTargetType.group 
                        ? Icons.group 
                        : Icons.person,
                    size: 32,
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  Text(
                    target.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    '${target.memberCount ?? 0} medlemmar',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}