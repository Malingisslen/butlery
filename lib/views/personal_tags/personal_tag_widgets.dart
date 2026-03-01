/// Reusable widget components for the PersonalTagsView.
///
/// Extracted to keep the main view under 500 lines.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/models/shared_personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
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

    return Semantics(
      label: context.l10n.personalTagTileSemantics(
          tag.name, usageCount, enabledRuleCount, ruleCount),
      button: true,
      child: Opacity(
        opacity: isUnused ? 0.6 : 1.0,
        child: ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: hasActiveRules
                    ? context.butleryColors.success
                        .withValues(alpha: AppDimensions.opacityLight)
                    : colorScheme.primary
                        .withValues(alpha: AppDimensions.opacityLight),
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
                    padding: const EdgeInsets.all(2),
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
          subtitle: Text(
            _buildSubtitle(context, usageCount, ruleCount, enabledRuleCount),
            style: AppTextStyles.bodySmall.copyWith(
              color: isUnused
                  ? colorScheme.onSurfaceVariant
                      .withValues(alpha: AppDimensions.opacityDark)
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _navigateToTagDetail(context),
          onLongPress: () =>
              PersonalTagDialogs.showTagOptionsSheet(context, tag),
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

  static String _buildSubtitle(BuildContext context, int usageCount,
      int ruleCount, int enabledRuleCount) {
    final parts = <String>[];

    if (usageCount > 0) {
      parts.add(context.l10n.personalTagRecipeCount(usageCount));
    }

    if (ruleCount > 0) {
      if (enabledRuleCount == ruleCount) {
        parts.add(context.l10n.personalTagRuleCount(ruleCount));
      } else {
        parts.add(context.l10n
            .personalTagRuleCountActive(enabledRuleCount, ruleCount));
      }
    }

    return parts.isEmpty ? context.l10n.personalTagNoUsage : parts.join(' · ');
  }
}

/// Section displaying pending shared tags from friends.
class SharedTagsSection extends StatelessWidget {
  const SharedTagsSection({
    super.key,
    required this.pendingSharedTags,
    required this.onImport,
  });

  final List<SharedPersonalTag> pendingSharedTags;
  final Future<void> Function(BuildContext context, SharedPersonalTag tag)
      onImport;

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
          child: Text(
            context.l10n.sharedWithYou,
            style: AppTextStyles.labelLarge.copyWith(
              color: colorScheme.primary,
            ),
          ),
        ),
        for (final shared in pendingSharedTags)
          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingLg,
              vertical: AppDimensions.spacingXs,
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.primary
                    .withValues(alpha: AppDimensions.opacityLight),
                child: Icon(Icons.label,
                    color: colorScheme.primary,
                    size: AppDimensions.iconSizeM),
              ),
              title: Text(shared.tagName),
              subtitle: Text(
                context.l10n.sharedByName(shared.sharedByDisplayName),
                style: AppTextStyles.bodySmall.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: FilledButton.tonal(
                onPressed: () => onImport(context, shared),
                child: Text(context.l10n.importTag),
              ),
            ),
          ),
        const SizedBox(height: AppDimensions.spacingMd),
        const Divider(),
      ],
    );
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
        ...tags.map((tag) => PersonalTagTile(
              key: ValueKey(tag.id),
              tag: tag,
              viewModel: viewModel,
            )),
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
        onSelected: (value) =>
            PersonalTagDialogs.handleGroupAction(context, value, group),
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
              leading: Icon(Icons.delete,
                  color: Theme.of(context).colorScheme.error),
              title: Text(context.l10n.personalTagDeleteGroup,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
