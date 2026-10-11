/// Rows and sections for the PersonalTagsView, built from the shared list
/// widgets every page under Mer uses.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tags/personal_tag_selection_manager.dart';
import 'package:butlery/views/personal_tags/personal_tag_dialogs.dart';
import 'package:butlery/views/tag_detail_view.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';

/// One tag as a row that opens the tag's page; in selection mode it toggles.
class PersonalTagRow extends StatelessWidget {
  const PersonalTagRow({super.key, required this.tag, required this.viewModel});

  final PersonalTag tag;
  final PersonalTagViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final selection = context.watch<PersonalTagSelectionManager>();
    final inSelectionMode = selection.isSelectionMode;
    final isSelected = selection.isSelected(tag.id);
    final usageCount = viewModel.getUsageCount(tag.name);
    final ruleCount = tag.rules.length;
    final enabledRuleCount = tag.rules.where((r) => r.isEnabled).length;

    return Semantics(
      selected: inSelectionMode ? isSelected : null,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // BUT-948: long-press stays a shortcut into multi-select; the Välj
        // button in the top bar is the way in that needs no gesture.
        onLongPress: inSelectionMode
            ? null
            : () => selection.enterSelection(tag.id),
        child: ButleryListRow(
          label: tag.name,
          subtitle: subtitleFor(
            context,
            usageCount: usageCount,
            ruleCount: ruleCount,
            enabledRuleCount: enabledRuleCount,
          ),
          leading: inSelectionMode
              ? (isSelected ? ButleryIcons.checkSquare : ButleryIcons.square)
              : null,
          onTap: inSelectionMode
              ? () => selection.toggle(tag.id)
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TagDetailView(tagId: tag.id),
                  ),
                ),
        ),
      ),
    );
  }

  static String subtitleFor(
    BuildContext context, {
    required int usageCount,
    required int ruleCount,
    required int enabledRuleCount,
  }) {
    final parts = <String>[];
    if (usageCount > 0) {
      parts.add(context.l10n.personalTagRecipeCount(usageCount));
    }
    if (ruleCount > 0) {
      parts.add(
        enabledRuleCount == ruleCount
            ? context.l10n.personalTagRuleCount(ruleCount)
            : context.l10n.personalTagRuleCountActive(
                enabledRuleCount,
                ruleCount,
              ),
      );
    }
    return parts.isEmpty ? context.l10n.personalTagNoUsage : parts.join(' · ');
  }
}

/// A titled section of tag rows. [extraRows] come after the tags.
class PersonalTagSection extends StatelessWidget {
  const PersonalTagSection({
    super.key,
    this.title,
    required this.tags,
    required this.viewModel,
    this.extraRows = const [],
  });

  final String? title;
  final List<PersonalTag> tags;
  final PersonalTagViewModel viewModel;
  final List<Widget> extraRows;

  @override
  Widget build(BuildContext context) {
    return ButleryListSection(
      title: title,
      rows: [
        for (final tag in tags)
          PersonalTagRow(key: ValueKey(tag.id), tag: tag, viewModel: viewModel),
        ...extraRows,
      ],
    );
  }
}

/// A group's tags, ended by one row that holds the group's own actions.
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
      extraRows: [
        ButleryListRow(
          label: context.l10n.personalTagManageGroup,
          onTap: () => showButleryListSheet<void>(
            context,
            title: group.name,
            rows: (sheetContext) => [
              ButleryListRow(
                label: context.l10n.commonRename,
                onTap: () {
                  Navigator.pop(sheetContext);
                  PersonalTagDialogs.handleGroupAction(
                    context,
                    'rename',
                    group,
                  );
                },
              ),
              ButleryListRow.danger(
                label: context.l10n.personalTagDeleteGroup,
                onTap: () {
                  Navigator.pop(sheetContext);
                  PersonalTagDialogs.handleGroupAction(
                    context,
                    'delete',
                    group,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tags no recipe uses, ended by the row that deletes them all.
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
    return PersonalTagSection(
      title: context.l10n.personalTagUnusedSection(unusedTags.length),
      tags: unusedTags,
      viewModel: viewModel,
      extraRows: [
        ButleryListRow.danger(
          label: context.l10n.personalTagDeleteUnusedAction,
          onTap: onDeleteAll,
        ),
      ],
    );
  }
}
