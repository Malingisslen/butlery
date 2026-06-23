/// Reusable widget components for the PersonalTagsView.
///
/// Extracted to keep the main view under 500 lines.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tags/personal_tag_selection_manager.dart';
import 'package:butlery/views/personal_tags/personal_tag_dialogs.dart';
import 'package:butlery/views/tag_detail_view.dart';

/// A single tag list item with icon, usage stats, and navigation.
class PersonalTagTile extends StatelessWidget {
  const PersonalTagTile({
    super.key,
    required this.tag,
    required this.viewModel,
  });

  final PersonalTag tag;
  final PersonalTagViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final usageCount = viewModel.getUsageCount(tag.name);
    final ruleCount = tag.rules.length;
    final enabledRuleCount = tag.rules.where((r) => r.isEnabled).length;
    final hasActiveRules = enabledRuleCount > 0;
    final isUnused = usageCount == 0;

    final selection = context.watch<PersonalTagSelectionManager>();
    final inSelectionMode = selection.isSelectionMode;
    final isSelected = selection.isSelected(tag.id);

    return Semantics(
      label: context.l10n.personalTagTileSemantics(
        tag.name,
        usageCount,
        enabledRuleCount,
        ruleCount,
      ),
      button: true,
      selected: inSelectionMode ? isSelected : null,
      child: Opacity(
        opacity: isUnused ? 0.6 : 1.0,
        child: ListTile(
          selected: isSelected,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer
              .withValues(alpha: AppDimensions.opacityLight),
          leading: inSelectionMode
              ? Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: AppDimensions.iconSizeL,
                )
              : Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: hasActiveRules
                          ? context.butleryColors.success.withValues(
                              alpha: AppDimensions.opacityLight,
                            )
                          : colorScheme.primary.withValues(
                              alpha: AppDimensions.opacityLight,
                            ),
                      child: Icon(
                        Icons.label,
                        color: hasActiveRules
                            ? context.butleryColors.success
                            : colorScheme.primary,
                        size: AppDimensions.iconSizeM,
                      ),
                    ),
                    if (hasActiveRules)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: AppDimensions.paddingAll2,
                          decoration: BoxDecoration(
                            color: context.butleryColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            size: 10,
                            color: colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                  ],
                ),
          title: Text(tag.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _buildSubtitle(
                  context,
                  usageCount,
                  ruleCount,
                  enabledRuleCount,
                ),
                style: AppTextStyles.bodySmall.copyWith(
                  color: isUnused
                      ? colorScheme.onSurfaceVariant.withValues(
                          alpha: AppDimensions.opacityDark,
                        )
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              if (usageCount > 0 && viewModel.maxUsageCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TagUsageBar(
                    usageCount: usageCount,
                    maxCount: viewModel.maxUsageCount,
                  ),
                ),
            ],
          ),
          trailing: inSelectionMode
              ? null
              : IconButton(
                  icon: const Icon(Icons.more_vert),
                  tooltip: context.l10n.personalTagOptions,
                  onPressed: () =>
                      PersonalTagDialogs.showTagOptionsSheet(context, tag),
                ),
          onTap: inSelectionMode
              ? () => selection.toggle(tag.id)
              : () => _navigateToTagDetail(context),
          // BUT-948: long-press = multi-select (convention).
          onLongPress: inSelectionMode
              ? null
              : () => selection.enterSelection(tag.id),
        ),
      ),
    );
  }

  void _navigateToTagDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TagDetailView(tagId: tag.id),
      ),
    );
  }

  static String _buildSubtitle(
    BuildContext context,
    int usageCount,
    int ruleCount,
    int enabledRuleCount,
  ) {
    final parts = <String>[];

    if (usageCount > 0) {
      parts.add(context.l10n.personalTagRecipeCount(usageCount));
    }

    if (ruleCount > 0) {
      if (enabledRuleCount == ruleCount) {
        parts.add(context.l10n.personalTagRuleCount(ruleCount));
      } else {
        parts.add(
          context.l10n.personalTagRuleCountActive(enabledRuleCount, ruleCount),
        );
      }
    }

    return parts.isEmpty ? context.l10n.personalTagNoUsage : parts.join(' · ');
  }
}

/// A section header with a list of tags, used for both ungrouped and grouped tags.
class PersonalTagSection extends StatelessWidget {
  const PersonalTagSection({
    super.key,
    required this.title,
    required this.tags,
    required this.viewModel,
    this.trailing,
  });

  final String title;
  final List<PersonalTag> tags;
  final PersonalTagViewModel viewModel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingLg,
            vertical: AppDimensions.spacingSm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        ...tags.map(
          (tag) => PersonalTagTile(
            key: ValueKey(tag.id),
            tag: tag,
            viewModel: viewModel,
          ),
        ),
        if (tags.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingLg,
              vertical: AppDimensions.spacingMd,
            ),
            child: Text(
              context.l10n.personalTagGroupEmpty,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

/// Inline usage bar showing relative tag usage.
class TagUsageBar extends StatelessWidget {
  const TagUsageBar({
    super.key,
    required this.usageCount,
    required this.maxCount,
  });

  final int usageCount;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fraction = maxCount > 0 ? usageCount / maxCount : 0.0;

    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: fraction,
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: colorScheme.primary,
            minHeight: 6,
            borderRadius: BorderRadius.zero,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        Text(
          '$usageCount',
          style: AppTextStyles.labelSmall.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Collapsible section showing tags with zero usage and a "delete all" action.
class UnusedTagsSection extends StatelessWidget {
  const UnusedTagsSection({
    super.key,
    required this.unusedTags,
    required this.onDeleteAll,
    required this.viewModel,
  });

  final List<PersonalTag> unusedTags;
  final VoidCallback onDeleteAll;
  final PersonalTagViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ExpansionTile(
      leading: Icon(
        Icons.label_off,
        color: colorScheme.onSurfaceVariant,
        size: AppDimensions.iconSizeM,
      ),
      title: Text(
        context.l10n.personalTagUnusedTags(unusedTags.length),
        style: AppTextStyles.labelLarge.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      children: [
        ...unusedTags.map(
          (tag) => PersonalTagTile(
            key: ValueKey(tag.id),
            tag: tag,
            viewModel: viewModel,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingLg,
            vertical: AppDimensions.spacingSm,
          ),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDeleteAll,
              icon: Icon(Icons.delete_sweep, color: colorScheme.error),
              label: Text(
                context.l10n.personalTagDeleteAllUnused,
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Builds the group section with its popup menu for rename/delete.
class PersonalTagGroupSection extends StatelessWidget {
  const PersonalTagGroupSection({
    super.key,
    required this.group,
    required this.tags,
    required this.viewModel,
  });

  final PersonalTagGroup group;
  final List<PersonalTag> tags;
  final PersonalTagViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return PersonalTagSection(
      title: group.name,
      tags: tags,
      viewModel: viewModel,
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: AppDimensions.iconSizeM),
        onSelected: (value) {
          // Defer to next frame so PopupMenu fully dismisses before dialog opens
          // Fixes BUG-033 (RenderBox assertion during popup dismiss animation)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            PersonalTagDialogs.handleGroupAction(context, value, group);
          });
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: Text(context.l10n.commonRename),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                context.l10n.personalTagDeleteGroup,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
