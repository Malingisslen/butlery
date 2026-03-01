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
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/shared_personal_tag.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/views/personal_tags/personal_tag_dialogs.dart';
import 'package:butlery/views/personal_tags/personal_tag_widgets.dart';

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
  List<SharedPersonalTag> _pendingSharedTags = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<PersonalTagViewModel>();
      if (viewModel.hasTags && !viewModel.isLoadingStats) {
        viewModel.loadTagStatistics();
      }
      _loadPendingSharedTags();
    });
  }

  Future<void> _loadPendingSharedTags() async {
    final authService = ServiceLocator.get<AuthService>();
    final userId = authService.currentUser?.uid;
    if (userId == null) return;

    try {
      final personalTagService = ServiceLocator.get<PersonalTagService>();
      final tags = await personalTagService.getPendingSharedTags(userId);
      if (mounted) {
        setState(() => _pendingSharedTags = tags);
      }
    } catch (e) {
      AppLogger.warning('Failed to load pending shared tags: $e');
    }
  }

  Future<void> _importSharedTag(
      BuildContext context, SharedPersonalTag sharedTag) async {
    try {
      final personalTagService = ServiceLocator.get<PersonalTagService>();
      final result = await personalTagService.importSharedTag(sharedTag.id);
      if (result != null && context.mounted) {
        SnackBarUtils.showSuccess(context, context.l10n.tagImportedSuccess);
        setState(() {
          _pendingSharedTags.removeWhere((t) => t.id == sharedTag.id);
        });
        context.read<PersonalTagViewModel>().initialize();
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, context.l10n.commonErrorOccurred);
      }
    }
  }

  List<PersonalTag> _sortTags(List<PersonalTag> tags, PersonalTagViewModel vm) {
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
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: FocusTraversalGroup(
        child: Consumer<PersonalTagViewModel>(
          builder: (context, viewModel, _) {
            if (viewModel.isLoading && !viewModel.hasTags) {
              return StateWidget.loading();
            }

            if (viewModel.hasError) {
              return StateWidget.error(
                message: viewModel.error ?? context.l10n.commonErrorOccurred,
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
      onSelected: (order) => setState(() => _sortOrder = order),
      itemBuilder: (context) => TagSortOrder.values.map((order) {
        final label = switch (order) {
          TagSortOrder.byName => context.l10n.personalTagSortByName,
          TagSortOrder.byUsage => context.l10n.personalTagSortByUsage,
          TagSortOrder.byRuleCount =>
            context.l10n.personalTagSortByRuleCount,
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
    final ungroupedTags = _sortTags(viewModel.getTagsForGroup(null), viewModel);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth =
              constraints.maxWidth > 700 ? 700.0 : constraints.maxWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: contentWidth,
              child: RefreshIndicator(
                onRefresh: () async {
                  await viewModel.initialize();
                  await viewModel.loadTagStatistics();
                  await _loadPendingSharedTags();
                },
                child: Builder(
                  builder: (context) {
                    final items = <Widget>[
                      if (_pendingSharedTags.isNotEmpty)
                        SharedTagsSection(
                          pendingSharedTags: _pendingSharedTags,
                          onImport: _importSharedTag,
                        ),
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
                          tags: _sortTags(
                              viewModel.getTagsForGroup(group.id), viewModel),
                          viewModel: viewModel,
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
          );
        },
      ),
    );
  }
}
