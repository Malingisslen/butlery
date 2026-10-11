/// Full-screen view for managing personal tags and automation rules.
///
/// Tags are rows grouped in sections; a tag's own actions live on its page
/// (TagDetailView). Dialogs live in [PersonalTagDialogs], rows in
/// personal_tag_widgets.
library;

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/layout/butlery_page_body.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tags/personal_tag_selection_manager.dart';
import 'package:butlery/widgets/common/feedback/partial_outcome.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/dialogs/destructive_confirmation_dialog.dart';
import 'package:butlery/views/personal_tags/personal_tag_dialogs.dart';
import 'package:butlery/views/personal_tags/personal_tag_widgets.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';

/// Sort order for personal tags.
enum TagSortOrder { byName, byUsage, byRuleCount }

/// Full-screen view for managing personal tags.
class PersonalTagsView extends StatefulWidget {
  const PersonalTagsView({this.backTo, super.key});

  /// Where Back leads, given only by the Mer row; the recipe list, recipe
  /// page and tag picker that also open this page leave it null.
  final String? backTo;

  @override
  State<PersonalTagsView> createState() => _PersonalTagsViewState();
}

class _PersonalTagsViewState extends State<PersonalTagsView> {
  // BUT-1185: selection manager is view-local UI state — created and disposed
  // here (not DI-registered) per views/CLAUDE.md.
  final PersonalTagSelectionManager _selectionManager =
      PersonalTagSelectionManager();

  @override
  void dispose() {
    _selectionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PersonalTagViewModel>.value(
          value: ServiceLocator.get<PersonalTagViewModel>(),
        ),
        ChangeNotifierProvider<PersonalTagSelectionManager>.value(
          value: _selectionManager,
        ),
      ],
      child: _PersonalTagsViewContent(backTo: widget.backTo),
    );
  }
}

class _PersonalTagsViewContent extends StatefulWidget {
  const _PersonalTagsViewContent({required this.backTo});

  final String? backTo;

  @override
  State<_PersonalTagsViewContent> createState() =>
      _PersonalTagsViewContentState();
}

class _PersonalTagsViewContentState extends State<_PersonalTagsViewContent> {
  TagSortOrder _sortOrder = TagSortOrder.byUsage;

  /// Cached sorted tags per group key (null = ungrouped)
  final Map<String?, List<PersonalTag>> _sortedTagsCache = {};
  TagSortOrder? _lastSortOrder;
  int _lastTagHash = 0;

  @override
  void initState() {
    super.initState();
    _invalidateSortCache();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<PersonalTagViewModel>();
      if (viewModel.hasTags && !viewModel.isLoadingStats) {
        viewModel.loadTagStatistics();
      }
    });
  }

  void _invalidateSortCache() {
    _sortedTagsCache.clear();
  }

  int _computeTagHash(List<PersonalTag> tags) => Object.hashAll(
    tags.map((t) => Object.hash(t.id, t.name, t.groupId, t.sortOrder)),
  );

  List<PersonalTag> _sortTags(
    List<PersonalTag> tags,
    PersonalTagViewModel vm,
    String? groupId,
  ) {
    final currentHash = _computeTagHash(vm.tags);
    if (_lastSortOrder != _sortOrder || currentHash != _lastTagHash) {
      _invalidateSortCache();
      _lastSortOrder = _sortOrder;
      _lastTagHash = currentHash;
    }

    final cached = _sortedTagsCache[groupId];
    if (cached != null) return cached;

    final sorted = List<PersonalTag>.from(tags);
    switch (_sortOrder) {
      case TagSortOrder.byName:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case TagSortOrder.byUsage:
        sorted.sort((a, b) {
          final aCount = vm.getUsageCount(a.name);
          final bCount = vm.getUsageCount(b.name);
          return bCount.compareTo(aCount);
        });
      case TagSortOrder.byRuleCount:
        sorted.sort((a, b) {
          final aRules = a.rules.where((r) => r.isEnabled).length;
          final bRules = b.rules.where((r) => r.isEnabled).length;
          return bRules.compareTo(aRules);
        });
    }
    _sortedTagsCache[groupId] = sorted;
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final selection = context.watch<PersonalTagSelectionManager>();
    return Scaffold(
      bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
      appBar: selection.isSelectionMode
          ? _buildSelectionAppBar(context, selection)
          : _buildAppBar(context),
      body: FocusTraversalGroup(
        child: Column(
          children: [
            LayoutComponents.offlineIndicator(),
            Expanded(
              child: Consumer<PersonalTagViewModel>(
                builder: (context, viewModel, _) {
                  if (viewModel.isLoading && !viewModel.hasTags) {
                    return StateWidget.loading(
                      message: context.l10n.loadingPersonalTags,
                    );
                  }

                  if (viewModel.hasError) {
                    return StateWidget.error(
                      message:
                          viewModel.error ?? context.l10n.commonErrorOccurred,
                      onAction: viewModel.initialize,
                    );
                  }

                  if (!viewModel.hasTags) {
                    return _buildEmptyState(context);
                  }

                  return _buildTagList(context, viewModel);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final tagCount = context.watch<PersonalTagViewModel>().tags.length;
    return ButleryTopBar.undersida(
      title: context.l10n.morePersonalTags,
      backTo: widget.backTo,
      actions: [
        // P5-U31: "Välj" in the view's own bar, from two tags (B-46;
        // produktregler.md:870-874). Long-press stays as a shortcut.
        if (ButlerySelectButton.shownFor(tagCount))
          ButlerySelectButton(
            key: const ValueKey('personal-tags-select-enter'),
            semanticLabel: context.l10n.selectionEnterTags,
            onPressed: context
                .read<PersonalTagSelectionManager>()
                .startSelection,
          ),
        IconButton(
          icon: const ButleryIcon(ButleryIcons.refreshCw),
          tooltip: context.l10n.personalTagApplyRulesToAll,
          onPressed: () => PersonalTagDialogs.showRetagDialog(context),
        ),
        IconButton(
          icon: const ButleryIcon(ButleryIcons.arrowUpDown),
          tooltip: context.l10n.commonSort,
          onPressed: () => _pickSortOrder(context),
        ),
        IconButton(
          key: const ValueKey('personal-tags-create'),
          icon: const ButleryIcon(ButleryIcons.plus),
          tooltip: context.l10n.commonCreate,
          onPressed: () => _showCreateSheet(context),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(
    BuildContext context,
    PersonalTagSelectionManager selection,
  ) {
    final viewModel = context.read<PersonalTagViewModel>();
    final count = selection.selectedCount;
    final selectedTags = selection.selectedTagIds
        .map(viewModel.getTagById)
        .whereType<PersonalTag>()
        .toList();

    // Multi-select keeps the bar and changes its content: "Avbryt" on the
    // left instead of an X, the count in tabular figures (produktregler.md
    // 17.1 :870, :873; Skarmar v12 etapp 9 #flervalingang, "Flerval — slå
    // samman taggar"). The text is the bar's paper foreground on ink.
    return ButleryTopBar.undersida(
      leading: TextButton(
        key: const ValueKey('personal-tags-selection-cancel'),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        onPressed: selection.exitSelection,
        child: Text(context.l10n.commonCancel),
      ),
      // "{n} valda" in tabular figures (produktregler.md:876).
      title: context.l10n.bulkSelectedCount(count),
      titleStyle: const TextStyle(
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      actions: [
        IconButton(
          icon: const ButleryIcon(ButleryIcons.merge),
          tooltip: context.l10n.personalTagMergeAction,
          onPressed: count >= 2
              ? () => PersonalTagDialogs.showMergeDialog(context, selectedTags)
              : null,
        ),
        IconButton(
          icon: const ButleryIcon(ButleryIcons.trash2),
          tooltip: context.l10n.commonDelete,
          onPressed: count >= 1
              ? () => PersonalTagDialogs.showBulkDeleteDialog(
                  context,
                  selectedTags,
                )
              : null,
        ),
      ],
    );
  }

  Future<void> _pickSortOrder(BuildContext context) async {
    final l10n = context.l10n;
    final picked = await showButleryChoiceSheet<TagSortOrder>(
      context,
      title: l10n.commonSort,
      options: [
        (TagSortOrder.byName, l10n.personalTagSortByName),
        (TagSortOrder.byUsage, l10n.personalTagSortByUsage),
        (TagSortOrder.byRuleCount, l10n.personalTagSortByRuleCount),
      ],
      selected: _sortOrder,
    );
    if (picked == null || picked == _sortOrder) return;
    setState(() {
      _sortOrder = picked;
      _invalidateSortCache();
    });
  }

  void _showCreateSheet(BuildContext context) {
    showButleryListSheet<void>(
      context,
      title: context.l10n.commonCreate,
      rows: (sheetContext) => [
        ButleryListRow(
          label: context.l10n.personalTagNewTag,
          onTap: () {
            Navigator.pop(sheetContext);
            PersonalTagDialogs.showCreateTagDialog(context);
          },
        ),
        ButleryListRow(
          label: context.l10n.personalTagNewGroup,
          onTap: () {
            Navigator.pop(sheetContext);
            PersonalTagDialogs.showCreateGroupDialog(context);
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return StateWidget.empty(
      icon: ButleryIcons.tag,
      title: context.l10n.personalTagEmptyTitle,
      subtitle: context.l10n.personalTagEmptySubtitle,
      actionLabel: context.l10n.personalTagCreateTag,
      onAction: () => PersonalTagDialogs.showCreateTagDialog(context),
    );
  }

  Widget _buildTagList(BuildContext context, PersonalTagViewModel viewModel) {
    final groups = viewModel.groups;
    // While the counts load every tag would read as unused, so none is
    // moved to that section until they are in.
    final unused = viewModel.isLoadingStats
        ? const <PersonalTag>[]
        : viewModel.unusedTags;
    final unusedIds = {for (final t in unused) t.id};
    List<PersonalTag> used(String? groupId) => _sortTags(
      viewModel.getTagsForGroup(groupId),
      viewModel,
      groupId,
    ).where((t) => !unusedIds.contains(t.id)).toList();
    final ungrouped = used(null);
    final margin = ButleryTopBar.sideMargin(context);

    return SafeArea(
      child: ButleryPageBody(
        width: PageWidth.text,
        child: RefreshIndicator(
          onRefresh: () async {
            await viewModel.initialize();
            await viewModel.loadTagStatistics();
          },
          child: ListView(
            padding: EdgeInsetsDirectional.only(
              start: margin,
              end: margin,
              bottom: AppDimensions.spacingLg,
            ),
            children: [
              ?_buildPartialDelete(context, viewModel),
              if (ungrouped.isNotEmpty)
                PersonalTagSection(
                  title: groups.isEmpty
                      ? context.l10n.personalTagSectionTags
                      : context.l10n.personalTagUngroupedSection,
                  tags: ungrouped,
                  viewModel: viewModel,
                ),
              for (final group in groups)
                PersonalTagGroupSection(
                  key: ValueKey(group.id),
                  group: group,
                  tags: used(group.id),
                  viewModel: viewModel,
                ),
              if (unused.isNotEmpty)
                UnusedTagsSection(
                  unusedTags: unused,
                  viewModel: viewModel,
                  onDeleteAll: () =>
                      _confirmDeleteUnusedTags(context, viewModel),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// P5-U33: a bulk delete where only some tags went (produktregler.md:
  /// 905-909; the shared surface of Skarmar v12 etapp 9 :390-393). It says
  /// how many of how many went, names the tags that went, names each tag
  /// that is still there with its reason, and those stay selected. "Klart"
  /// leaves selection mode.
  ///
  /// Interpretations (recorded; no drawing shows the tag surface):
  /// - The box sits above the tags, not below the rows as #flergrupp draws
  ///   it for members: a tag list can run long, and below it the outcome
  ///   would land out of sight.
  /// - "Försök igen" is the way on. #flergrupp's first action fixes the
  ///   member's cause ("Ändra Saras roll"); a tag delete that was not saved
  ///   has no cause to fix, only the attempt to repeat. It asks again for
  ///   the tags selected now, not for the ids the outcome remembers.
  Widget? _buildPartialDelete(
    BuildContext context,
    PersonalTagViewModel viewModel,
  ) {
    final selection = context.watch<PersonalTagSelectionManager>();
    final result = selection.partialDelete;
    if (result == null) return null;
    final l = context.l10n;
    final remaining = result.failedIds
        .map(viewModel.getTagById)
        .whereType<PersonalTag>()
        .toList(growable: false);
    final selectedNow = selection.selectedTagIds
        .map(viewModel.getTagById)
        .whereType<PersonalTag>()
        .toList(growable: false);
    final went = l.personalTagBulkDeletePartialDeleted(
      PartialOutcome.joinNames(
        selection.partialDeletedNames,
        l.partialOutcomeListAnd,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.spacingMd),
      child: PartialOutcome(
        key: const ValueKey('personal-tags-partial-outcome'),
        title: l.personalTagBulkDeletePartialTitle(
          result.deletedIds.length,
          result.deletedIds.length + result.failedIds.length,
        ),
        message: '$went ${l.personalTagBulkDeletePartialMessage}',
        items: [
          for (final tag in remaining)
            PartialOutcomeItem(
              id: tag.id,
              label: tag.name,
              reason: l.personalTagBulkDeleteNotSaved,
            ),
        ],
        actions: [
          if (selectedNow.isNotEmpty)
            TextButton(
              key: const ValueKey('personal-tags-partial-retry'),
              onPressed: () =>
                  PersonalTagDialogs.showBulkDeleteDialog(context, selectedNow),
              child: Text(l.commonRetry),
            ),
          TextButton(
            key: const ValueKey('personal-tags-partial-done'),
            onPressed: selection.exitSelection,
            child: Text(l.partialOutcomeDone),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteUnusedTags(
    BuildContext context,
    PersonalTagViewModel viewModel,
  ) async {
    final count = viewModel.unusedTags.length;
    final confirmed = await DestructiveConfirmationDialog.show(
      context,
      title: context.l10n.personalTagDeleteAllUnusedConfirm,
      message: context.l10n.personalTagDeleteAllUnusedMessage(count),
      primaryActionText: context.l10n.personalTagDeleteUnusedAction,
    );

    if (confirmed == true && context.mounted) {
      final deleted = await viewModel.deleteUnusedTags();
      if (context.mounted) {
        SnackBarUtils.showSuccess(
          context,
          context.l10n.personalTagUnusedDeleted(deleted),
        );
      }
    }
  }
}
