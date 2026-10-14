import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/social/social_facade.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/styled/styled_card.dart';

/// Invitation target list and grid layouts.
class InvitationLists {
  /// Build target list.
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
        return ButleryItemRow(
          title: target.displayName,
          subtitle:
              '${target.type.name} • ${context.l10n.labelMemberCount(target.memberCount ?? 0)}',
          onTap: onTargetTap != null ? () => onTargetTap(target) : null,
        );
      },
    );
  }

  /// Build sectioned target list
  /// List grouped by target type
  static Widget sectionedTargetList(
    BuildContext context, {
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
              padding: const EdgeInsets.all(AppDimensions.space16),
              child: Text(
                type == InvitationTargetType.group
                    ? context.l10n.socialGroups
                    : context.l10n.invitationIndividuals,
                style: AppTextStyles.titleBold,
              ),
            ),
            ...typeTargets.map(
              (target) => ButleryItemRow(
                title: target.displayName,
                subtitle: context.l10n.labelMemberCount(
                  target.memberCount ?? 0,
                ),
                onTap: onTargetTap != null ? () => onTargetTap(target) : null,
              ),
            ),
            const ButleryDivider(),
          ],
        );
      }).toList(),
    );
  }

  /// Build virtual scrolling target list
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
        return ButleryItemRow(
          title: target.displayName,
          subtitle:
              '${target.type.name} • ${context.l10n.labelMemberCount(target.memberCount ?? 0)}',
          onTap: onTargetTap != null ? () => onTargetTap(target) : null,
        );
      },
    );
  }

  /// Build horizontal target list
  /// Horizontal scrolling list
  static Widget horizontalTargetList(
    BuildContext context, {
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
            child: _targetCard(
              context,
              onTap: onTargetTap != null ? () => onTargetTap(target) : null,
              padding: const EdgeInsets.all(AppDimensions.space8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ButleryIcon(
                    target.type == InvitationTargetType.group
                        ? ButleryIcons.users
                        : ButleryIcons.user,
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  Text(
                    target.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build staggered target grid
  /// Grid with variable item heights
  static Widget staggeredTargetGrid(
    BuildContext context, {
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
        return _targetCard(
          context,
          onTap: onTargetTap != null ? () => onTargetTap(target) : null,
          padding: const EdgeInsets.all(
            (AppDimensions.space8 + AppDimensions.space4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ButleryIcon(
                target.type == InvitationTargetType.group
                    ? ButleryIcons.users
                    : ButleryIcons.user,
                size: AppDimensions.iconSizeXl,
              ),
              const SizedBox(height: AppDimensions.space8),
              Text(
                target.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.contentLabel,
              ),
              const SizedBox(height: AppDimensions.space4),
              Text(
                context.l10n.labelMemberCount(target.memberCount ?? 0),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // The label stays on a card with no tap handler too, which StyledCard's own
  // semanticLabel only gives a tappable card.
  static Widget _targetCard(
    BuildContext context, {
    required VoidCallback? onTap,
    required EdgeInsetsGeometry padding,
    required Widget child,
  }) {
    return StyledCard(
      onTap: onTap,
      padding: padding,
      child: Semantics(
        label: context.l10n.a11yInvitationTargetCard,
        button: true,
        enabled: onTap != null,
        child: child,
      ),
    );
  }
}
