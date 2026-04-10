/// Full-screen view for managing personal tags and automation rules.
///
/// Displays user's personal tags organized by groups with options to:
/// - Create, edit, delete tags
/// - Navigate to tag detail for rule management
/// - Reorder tags within groups
///
/// Dialogs extracted to [PersonalTagDialogs], widgets to personal_tag_widgets.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/views/personal_tags/personal_tag_dialogs.dart';
import 'package:butlery/views/personal_tags/personal_tag_widgets.dart';
import 'package:butlery/widgets/common/layout_components.dart';

/// Sort order for personal tags.
enum TagSortOrder {
  byName,
  byUsage,
  byRuleCount;
}

/// Full-screen view for managing personal tags.
class PersonalTagsView extends StatelessWidget {
  const PersonalTagsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PersonalTagViewModel>.value(
      value: ServiceLocator.get<PersonalTagViewModel>(),
      child: const _PersonalTagsViewContent(),
    );
  }
}

class _PersonalTagsViewContent extends StatefulWidget {
  const _PersonalTagsViewContent();

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
      tags.map((t) => Object.hash(t.id, t.name, t.groupId, t.sortOrder)));

  List<PersonalTag> _sortTags(
      List<PersonalTag> tags, PersonalTagViewModel vm, String? groupId) {
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
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
    return Scaffold(
      appBar: _buildAppBar(context),
      body: FocusTraversalGroup(
        child: Column(
          children: [
            LayoutComponents.offlineIndicator(),
            Expanded(
              child: Consumer<PersonalTagViewModel>(
                builder: (context, viewModel, _) {
                  if (viewModel.isLoading && !viewModel.hasTags) {
                    return StateWidget.loading();
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
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
        tooltip: context.l10n.commonBack,
      ),
      title: Text(context.l10n.personalTagsViewTitle),
      actions: [
        IconButton(
          icon: const Icon(Icons.sync),
          tooltip: context.l10n.personalTagApplyRulesToAll,
          onPressed: () => PersonalTagDialogs.showRetagDialog(context),
        ),
        _buildSortMenu(context),
        _buildAddMenu(context),
      ],
    );
  }

  Widget _buildSortMenu(BuildContext context) {
    return PopupMenuButton<TagSortOrder>(
      icon: const Icon(Icons.sort),
      tooltip: context.l10n.commonSort,
      onSelected: (order) => setState(() {
        _sortOrder = order;
        _invalidateSortCache();
      }),
      itemBuilder: (context) => TagSortOrder.values.map((order) {
        final label = switch (order) {
          TagSortOrder.byName => context.l10n.personalTagSortByName,
          TagSortOrder.byUsage => context.l10n.personalTagSortByUsage,
          TagSortOrder.byRuleCount => context.l10n.personalTagSortByRuleCount,
        };
        return PopupMenuItem(
          value: order,
          child: Row(
            children: [
              if (order == _sortOrder)
                const Icon(Icons.check, size: AppDimensions.iconSize18)
              else
                const SizedBox(width: AppDimensions.iconSize18),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(label),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAddMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.add),
      tooltip: context.l10n.commonCreate,
      onSelected: (value) {
        // Defer to next frame so PopupMenu fully dismisses before dialog opens
        // Fixes BUG-025 (RenderBox assertion) and BUG-022 (Provider lifecycle)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          if (value == 'tag') {
            PersonalTagDialogs.showCreateTagDialog(context);
          } else if (value == 'group') {
            PersonalTagDialogs.showCreateGroupDialog(context);
          }
        });
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'tag',
          child: ListTile(
            leading: const Icon(Icons.label_outline),
            title: Text(context.l10n.personalTagCreateTag),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'group',
          child: ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(context.l10n.personalTagCreateGroup),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return StateWidget.empty(
      icon: Icons.label_outline,
      title: context.l10n.personalTagEmptyTitle,
      subtitle: context.l10n.personalTagEmptySubtitle,
      actionLabel: context.l10n.personalTagCreateTag,
      onAction: () => PersonalTagDialogs.showCreateTagDialog(context),
    );
  }

  Widget _buildTagList(BuildContext context, PersonalTagViewModel viewModel) {
    final groups = viewModel.groups;
    final ungroupedTags =
        _sortTags(viewModel.getTagsForGroup(null), viewModel, null);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: LayoutComponents.valueFor(
              context: context,
              mobile: double.infinity,
              tablet: 700,
              desktop: 800,
            ),
          ),
          child: RefreshIndicator(
            onRefresh: () async {
              await viewModel.initialize();
              await viewModel.loadTagStatistics();
            },
            child: Builder(
              builder: (context) {
                final items = <Widget>[
                  if (ungroupedTags.isNotEmpty)
                    PersonalTagSection(
                      title: context.l10n.personalTagSectionTags,
                      tags: ungroupedTags,
                      viewModel: viewModel,
                    ),
                  for (final group in groups)
                    PersonalTagGroupSection(
                      key: ValueKey(group.id),
                      group: group,
                      tags: _sortTags(viewModel.getTagsForGroup(group.id),
                          viewModel, group.id),
                      viewModel: viewModel,
                    ),
                  if (viewModel.unusedTags.isNotEmpty)
                    UnusedTagsSection(
                      unusedTags: viewModel.unusedTags,
                      viewModel: viewModel,
                      onDeleteAll: () =>
                          _confirmDeleteUnusedTags(context, viewModel),
                    ),
                  const SizedBox(height: AppDimensions.spacingXxl),
                ];
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.spacingMd),
                  itemCount: items.length,
                  itemBuilder: (context, index) => items[index],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteUnusedTags(
      BuildContext context, PersonalTagViewModel viewModel) async {
    final count = viewModel.unusedTags.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.personalTagDeleteAllUnusedConfirm),
        content: Text(context.l10n.personalTagDeleteAllUnusedMessage(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              context.l10n.commonDelete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final deleted = await viewModel.deleteUnusedTags();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.personalTagUnusedDeleted(deleted)),
          ),
        );
      }
    }
  }
}
