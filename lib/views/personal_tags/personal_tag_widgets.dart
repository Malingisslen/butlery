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
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';
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

    final cs = Theme.of(context).colorScheme;
    final summary = subtitleFor(
      context,
      usageCount: usageCount,
      ruleCount: ruleCount,
      enabledRuleCount: enabledRuleCount,
    );
    return Semantics(
      selected: inSelectionMode ? isSelected : null,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // BUT-948: long-press stays a shortcut into multi-select; the Välj
        // button in the top bar is the way in that needs no gesture.
        onLongPress: inSelectionMode
            ? null
            : () => selection.enterSelection(tag.id),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: PressFill(
            surface: PressSurface.base,
            child: InkWell(
              onTap: inSelectionMode
                  ? () => selection.toggle(tag.id)
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => TagDetailView(tagId: tag.id),
                      ),
                    ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppDimensions.minTouchTarget,
                ),
                child: Row(
                  children: [
                    if (inSelectionMode)
                      ButleryIcon(
                        isSelected
                            ? ButleryIcons.circleCheck
                            : ButleryIcons.circle,
                      )
                    else
                      _TagDot(color: _dotColor(cs, tag.id)),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: Text(
                        tag.name,
                        style: AppTextStyles.bodySmallBold.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space8),
                    Flexible(
                      child: Text(
                        summary,
                        textAlign: TextAlign.end,
                        style: AppTextStyles.captionText.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (!inSelectionMode) ...[
                      const SizedBox(width: AppDimensions.space8),
                      ButleryIcon(
                        ButleryIcons.chevronRight,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The tag's dot: one of five steps from ink to muted, fixed by the tag's id
  /// so it stays the same between visits.
  static Color _dotColor(ColorScheme cs, String tagId) {
    final step = tagId.codeUnits.fold<int>(0, (sum, u) => sum + u) % 5;
    return Color.lerp(cs.onSurface, cs.outline, step / 4)!;
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

class _TagDot extends StatelessWidget {
  const _TagDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: AppDimensions.space12,
        height: AppDimensions.space12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
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

/// Tags no recipe uses, drawn as pills under a heading that deletes them all.
class UnusedTagsSection extends StatelessWidget {
  const UnusedTagsSection({
    super.key,
    required this.unusedTags,
    required this.onDeleteAll,
  });

  final List<PersonalTag> unusedTags;
  final VoidCallback onDeleteAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppDimensions.space16),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.personalTagUnusedHeading(unusedTags.length),
                  style: AppTextStyles.labelMediumBold.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: onDeleteAll,
                child: Text(
                  l10n.personalTagDeleteAllShort,
                  style: AppTextStyles.labelMediumBold.copyWith(
                    color: cs.error,
                  ),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: AppDimensions.space8,
          runSpacing: AppDimensions.space8,
          children: [
            for (final tag in unusedTags)
              PressFill(
                surface: PressSurface.base,
                child: ActionChip(
                  key: ValueKey(tag.id),
                  label: Text(tag.name),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TagDetailView(tagId: tag.id),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
