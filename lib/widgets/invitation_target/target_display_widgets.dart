// lib/widgets/invitation_target/target_display_widgets.dart

import 'package:flutter/material.dart';
import '../../models/invitations/invitation_target.dart';
import '../../theme/app_theme.dart';


/// Widget builders för att visa InvitationTarget på olika sätt
///
/// Denna klass innehåller BARA UI widget builders som:
/// - Tar InvitationTarget data som parametrar
/// - Använder AppTheme för ALL styling
/// - Returnerar styled widgets
/// - Hanterar user interactions via callbacks
class TargetDisplayWidgets {
  // ===== PRIMARY DISPLAY WIDGETS =====

  /// Bygg target-kort widget med konsistent AppTheme styling
  static Widget buildTargetCard(
    BuildContext context,
    InvitationTarget target, {
    VoidCallback? onTap,
    bool isSelected = false,
    bool isDisabled = false,
  }) {
    BoxDecoration decoration;

    if (isDisabled) {
      decoration = AppTheme.cardDecoration.copyWith(
        color: AppTheme.cardColor.withValues(alpha: 0.5),
        border: Border.all(color: AppTheme.dividerColor),
      );
    } else if (isSelected) {
      decoration = AppTheme.cardDecoration.copyWith(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        border: Border.all(color: AppTheme.primaryColor, width: 2),
      );
    } else {
      decoration = AppTheme.cardDecoration;
    }

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      decoration: decoration,
      child: Material(
        color: AppTheme.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: AppTheme.largeRadius,
          child: Padding(
            padding: AppTheme.cardPadding,
            child: Row(
              children: [
                // Emoji container
                _buildEmojiContainer(target),
                AppTheme.smallHorizontalGap,

                // Namn och beskrivning
                Expanded(
                  child: _buildTargetInfo(target, isDisabled),
                ),

                // Typ-ikon
                _buildTargetTypeIcon(target.type),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bygg kompakt target chip
  static Widget buildTargetChip(
    BuildContext context,
    InvitationTarget target, {
    VoidCallback? onTap,
    VoidCallback? onRemove,
    bool showCount = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: AppTheme.chipRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Material(
        color: AppTheme.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.chipRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Emoji
                Text(
                  target.displayEmoji,
                  style: TextStyle(fontSize: AppTheme.bodyStyle.fontSize),
                ),
                const SizedBox(width: 4),

                // Namn
                Flexible(
                  child: Text(
                    target.displayName,
                    style: AppTheme.chipLabelStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Medlemsantal för grupper
                if (target.isGroup &&
                    target.memberCount != null &&
                    showCount) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(${target.memberCount})',
                    style: AppTheme.captionStyle,
                  ),
                ],

                // Ta bort knapp
                if (onRemove != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onRemove,
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bygg target list tile för listor
  static Widget buildTargetListTile(
    BuildContext context,
    InvitationTarget target, {
    VoidCallback? onTap,
    Widget? trailing,
    bool showSubtitle = true,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: AppTheme.listItemPadding,

      // Leading: Emoji container
      leading: _buildSmallEmojiContainer(target),

      // Title: Namn
      title: Text(
        target.displayName,
        style: AppTheme.cardTitleStyle,
        overflow: TextOverflow.ellipsis,
      ),

      // Subtitle: Beskrivning
      subtitle: showSubtitle && target.subtitle.isNotEmpty
          ? Text(
              target.subtitle,
              style: AppTheme.subtitleStyle,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            )
          : null,

      // Trailing: Custom widget eller typ-ikon
      trailing: trailing ?? _buildTargetTypeIcon(target.type),
    );
  }

  /// Bygg target badge för status display
  static Widget buildTargetBadge(
    BuildContext context,
    InvitationTarget target, {
    bool showEmoji = true,
    bool showCount = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.chipRadius,
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showEmoji) ...[
            Text(
              target.displayEmoji,
              style: TextStyle(fontSize: AppTheme.smallText.fontSize),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            target.displayName,
            style: AppTheme.chipOnPrimaryTextStyle.copyWith(
              color: AppTheme.primaryColor,
            ),
          ),
          if (target.isGroup && target.memberCount != null && showCount) ...[
            const SizedBox(width: 2),
            Text(
              '(${target.memberCount})',
              style: AppTheme.captionStyle.copyWith(
                color: AppTheme.primaryColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Bygg target grid item för grid layouts
  static Widget buildTargetGridItem(
    BuildContext context,
    InvitationTarget target, {
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    final decoration = isSelected
        ? AppTheme.cardDecoration.copyWith(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            border: Border.all(color: AppTheme.primaryColor, width: 2),
          )
        : AppTheme.cardDecoration;

    return Container(
      decoration: decoration,
      child: Material(
        color: AppTheme.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.largeRadius,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Emoji
                Text(
                  target.displayEmoji,
                  style: TextStyle(fontSize: AppTheme.displayLarge.fontSize),
                ),
                const SizedBox(width: 8),

                // Namn
                Text(
                  target.displayName,
                  style: AppTheme.cardTitleStyle,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),

                // Beskrivning för grupper
                if (target.isGroup && target.memberCount != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    target.description,
                    style: AppTheme.captionStyle,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== LIST BUILDERS =====

  /// Bygg lista av targets med separatorer
  static Widget buildTargetList(
    BuildContext context,
    List<InvitationTarget> targets, {
    required Function(InvitationTarget) onTargetTap,
    bool showDividers = true,
    bool groupByType = false,
  }) {
    if (targets.isEmpty) {
      return _buildEmptyTargetList(context);
    }

    List<InvitationTarget> sortedTargets = targets;
    if (groupByType) {
      sortedTargets = InvitationTarget.sortForUI(targets);
    }

    return Container(
      decoration: AppTheme.cardDecoration,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sortedTargets.length,
        separatorBuilder: (context, index) => showDividers
            ? Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.dividerColor,
              )
            : const SizedBox.shrink(),
        itemBuilder: (context, index) {
          final target = sortedTargets[index];
          return buildTargetListTile(
            context,
            target,
            onTap: () => onTargetTap(target),
          );
        },
      ),
    );
  }

  /// Bygg grid av targets
  static Widget buildTargetGrid(
    BuildContext context,
    List<InvitationTarget> targets, {
    required Function(InvitationTarget) onTargetTap,
    int crossAxisCount = 2,
  }) {
    if (targets.isEmpty) {
      return _buildEmptyTargetList(context);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.2,
        crossAxisSpacing: AppTheme.spacingSm,
        mainAxisSpacing: AppTheme.spacingSm,
      ),
      itemCount: targets.length,
      itemBuilder: (context, index) {
        final target = targets[index];
        return buildTargetGridItem(
          context,
          target,
          onTap: () => onTargetTap(target),
        );
      },
    );
  }

  /// Bygg section header för grouped lists
  static Widget buildTargetSectionHeader(
    BuildContext context,
    String title, {
    int? count,
  }) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingMd),
      child: Row(
        children: [
          Text(
            title,
            style: AppTheme.sectionTitleStyle,
          ),
          if (count != null) ...[
            AppTheme.smallHorizontalGap,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.1),
                borderRadius: AppTheme.chipRadius,
              ),
              child: Text(
                '$count',
                style: AppTheme.captionStyle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Bygg wrappade chips för flera targets
  static Widget buildTargetChipWrap(
    BuildContext context,
    List<InvitationTarget> targets, {
    Function(InvitationTarget)? onChipTap,
    Function(InvitationTarget)? onChipRemove,
    double spacing = 8.0,
    double runSpacing = 4.0,
  }) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: targets.map((target) {
        return buildTargetChip(
          context,
          target,
          onTap: onChipTap != null ? () => onChipTap(target) : null,
          onRemove: onChipRemove != null ? () => onChipRemove(target) : null,
        );
      }).toList(),
    );
  }

  // ===== PRIVATE HELPER METHODS =====

  /// Bygg emoji container för target cards
  static Widget _buildEmojiContainer(InvitationTarget target) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: AppTheme.smallRadius,
      ),
      child: Center(
        child: Text(
          target.displayEmoji,
          style: TextStyle(fontSize: AppTheme.iconSizeInfo.toDouble()),
        ),
      ),
    );
  }

  /// Bygg liten emoji container för list tiles
  static Widget _buildSmallEmojiContainer(InvitationTarget target) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: AppTheme.smallRadius,
      ),
      child: Center(
        child: Text(
          target.displayEmoji,
          style: TextStyle(fontSize: AppTheme.bodyStyle.fontSize),
        ),
      ),
    );
  }

  /// Bygg target info (namn och beskrivning)
  static Widget _buildTargetInfo(InvitationTarget target, bool isDisabled) {
    final nameStyle = isDisabled
        ? AppTheme.cardTitleStyle.copyWith(
            color: AppTheme.textTertiary,
          )
        : AppTheme.cardTitleStyle;

    final descriptionStyle = isDisabled
        ? AppTheme.subtitleStyle.copyWith(
            color: AppTheme.textTertiary,
          )
        : AppTheme.subtitleStyle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          target.displayName,
          style: nameStyle,
          overflow: TextOverflow.ellipsis,
        ),
        if (target.subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            target.subtitle,
            style: descriptionStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ],
    );
  }

  /// Bygg target type icon
  static Widget _buildTargetTypeIcon(InvitationTargetType type) {
    switch (type) {
      case InvitationTargetType.individual:
        return Icon(
          Icons.person,
          size: AppTheme.iconSizeInfo,
          color: AppTheme.textSecondary,
        );
      case InvitationTargetType.group:
        return Icon(
          Icons.group,
          size: AppTheme.iconSizeInfo,
          color: AppTheme.textSecondary,
        );
    }
  }

  /// Bygg empty state för target lists
  static Widget _buildEmptyTargetList(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingXl),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: AppTheme.iconSizeEmptyState,
            color: AppTheme.textTertiary,
          ),
          AppTheme.mediumGap,
          Text(
            'Inga mål valda',
            style: AppTheme.sectionTitleStyle.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
          AppTheme.smallGap,
          Text(
            'Välj vänner eller grupper att dela med',
            style: AppTheme.subtitleStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
