/// Full-screen view for managing personal tags and automation rules.
///
/// Displays user's personal tags organized by groups with options to:
/// - Create, edit, delete tags
/// - Navigate to tag detail for rule management
/// - Reorder tags within groups
///
/// Replaces the dialog-based PersonalTagManagerDialog with a full-screen approach.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/views/tag_detail_view.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Sort order for personal tags.
enum TagSortOrder {
  byName('Namn'),
  byUsage('Användning'),
  byRuleCount('Antal regler');

  final String label;
  const TagSortOrder(this.label);
}

/// Full-screen view for managing personal tags.
class PersonalTagsView extends StatelessWidget {
  const PersonalTagsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PersonalTagViewModel()..initialize(),
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

  @override
  void initState() {
    super.initState();
    // Load statistics after initial build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<PersonalTagViewModel>();
      if (viewModel.hasTags && !viewModel.isLoadingStats) {
        viewModel.loadTagStatistics();
      }
    });
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
          return bCount.compareTo(aCount); // Descending
        });
      case TagSortOrder.byRuleCount:
        sorted.sort((a, b) {
          final aRules = a.rules.where((r) => r.isEnabled).length;
          final bRules = b.rules.where((r) => r.isEnabled).length;
          return bRules.compareTo(aRules); // Descending
        });
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personliga taggar'),
        actions: [
          PopupMenuButton<TagSortOrder>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sortera',
            onSelected: (order) => setState(() => _sortOrder = order),
            itemBuilder: (context) => TagSortOrder.values.map((order) {
              return PopupMenuItem(
                value: order,
                child: Row(
                  children: [
                    if (order == _sortOrder)
                      const Icon(Icons.check, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Text(order.label),
                  ],
                ),
              );
            }).toList(),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Skapa tagg',
            onPressed: () => _createTag(context),
          ),
        ],
      ),
      body: Consumer<PersonalTagViewModel>(
        builder: (context, viewModel, _) {
          if (viewModel.isLoading && !viewModel.hasTags) {
            return StateWidget.loading();
          }

          if (viewModel.hasError) {
            return StateWidget.error(
              message: viewModel.error ?? 'Ett fel uppstod',
              onAction: viewModel.initialize,
            );
          }

          if (!viewModel.hasTags) {
            return _buildEmptyState(context);
          }

          return _buildTagList(context, viewModel);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return StateWidget.empty(
      icon: Icons.label_outline,
      title: 'Inga personliga taggar',
      subtitle: 'Skapa taggar för att organisera dina recept',
      actionLabel: 'Skapa tagg',
      onAction: () => _createTag(context),
    );
  }

  Widget _buildTagList(BuildContext context, PersonalTagViewModel viewModel) {
    final groups = viewModel.groups;
    final ungroupedTags = _sortTags(viewModel.getTagsForGroup(null), viewModel);

    return RefreshIndicator(
      onRefresh: () async {
        await viewModel.initialize();
        await viewModel.loadTagStatistics();
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingMd),
        children: [
          // Ungrouped tags section
          if (ungroupedTags.isNotEmpty) ...[
            _buildTagSection(
              context,
              viewModel,
              title: 'Taggar',
              tags: ungroupedTags,
              groupId: null,
            ),
          ],

          // Grouped tags
          for (final group in groups) ...[
            _buildGroupSection(context, viewModel, group),
          ],

          // Bottom padding
          const SizedBox(height: AppDimensions.spacingXxl),
        ],
      ),
    );
  }

  Widget _buildGroupSection(
    BuildContext context,
    PersonalTagViewModel viewModel,
    PersonalTagGroup group,
  ) {
    final tags = _sortTags(viewModel.getTagsForGroup(group.id), viewModel);

    return _buildTagSection(
      context,
      viewModel,
      title: group.name,
      tags: tags,
      groupId: group.id,
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        onSelected: (value) => _handleGroupAction(context, value, group),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: Icon(Icons.edit),
              title: Text('Byt namn'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Ta bort grupp', style: TextStyle(color: Colors.red)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagSection(
    BuildContext context,
    PersonalTagViewModel viewModel, {
    required String title,
    required List<PersonalTag> tags,
    required String? groupId,
    Widget? trailing,
  }) {
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
                child: Text(
                  title,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
        ...tags.map((tag) => _buildTagTile(context, viewModel, tag)),
        if (tags.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingLg,
              vertical: AppDimensions.spacingMd,
            ),
            child: Text(
              'Inga taggar i denna grupp',
              style: AppTextStyles.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTagTile(
    BuildContext context,
    PersonalTagViewModel viewModel,
    PersonalTag tag,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final usageCount = viewModel.getUsageCount(tag.name);
    final ruleCount = tag.rules.length;
    final enabledRuleCount = tag.rules.where((r) => r.isEnabled).length;
    final hasActiveRules = enabledRuleCount > 0;
    final isUnused = usageCount == 0;

    return Opacity(
      opacity: isUnused ? 0.6 : 1.0,
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: hasActiveRules
                  ? AppColors.success.withValues(alpha: AppDimensions.opacityLight)
                  : colorScheme.primary.withValues(alpha: AppDimensions.opacityLight),
              child: Icon(
                Icons.label,
                color: hasActiveRules ? AppColors.success : colorScheme.primary,
                size: 20,
              ),
            ),
            if (hasActiveRules)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        title: Text(tag.name),
        subtitle: Text(
          _buildSubtitle(usageCount, ruleCount, enabledRuleCount),
          style: AppTextStyles.bodySmall.copyWith(
            color: isUnused
                ? colorScheme.onSurfaceVariant.withValues(alpha: AppDimensions.opacityDark)
                : colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _navigateToTagDetail(context, tag),
        onLongPress: () => _showTagOptions(context, tag),
      ),
    );
  }

  String _buildSubtitle(int usageCount, int ruleCount, int enabledRuleCount) {
    final parts = <String>[];

    if (usageCount > 0) {
      parts.add('$usageCount recept');
    }

    if (ruleCount > 0) {
      if (enabledRuleCount == ruleCount) {
        parts.add('$ruleCount regler');
      } else {
        parts.add('$enabledRuleCount/$ruleCount regler aktiva');
      }
    }

    return parts.isEmpty ? 'Ingen användning' : parts.join(' · ');
  }

  void _navigateToTagDetail(BuildContext context, PersonalTag tag) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TagDetailView(tagId: tag.id),
      ),
    );
  }

  void _showTagOptions(BuildContext context, PersonalTag tag) {
    final hasRules = tag.rules.isNotEmpty;
    final enabledRuleCount = tag.rules.where((r) => r.isEnabled).length;
    final allRulesEnabled = enabledRuleCount == tag.rules.length;
    final allRulesDisabled = enabledRuleCount == 0;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLg),
              child: Row(
                children: [
                  const Icon(Icons.label, size: 24),
                  const SizedBox(width: AppDimensions.spacingM),
                  Expanded(
                    child: Text(
                      tag.name,
                      style: AppTextStyles.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Visa detaljer'),
              onTap: () {
                Navigator.pop(sheetContext);
                _navigateToTagDetail(context, tag);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Redigera namn'),
              onTap: () {
                Navigator.pop(sheetContext);
                _editTag(context, tag);
              },
            ),
            if (hasRules && !allRulesEnabled)
              ListTile(
                leading: const Icon(Icons.play_arrow, color: AppColors.success),
                title: const Text('Aktivera alla regler'),
                subtitle: Text(
                    '${tag.rules.length - enabledRuleCount} regler inaktiverade'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _toggleAllRules(context, tag, enable: true);
                },
              ),
            if (hasRules && !allRulesDisabled)
              ListTile(
                leading: Icon(Icons.pause, color: Colors.orange.shade700),
                title: const Text('Inaktivera alla regler'),
                subtitle: Text('$enabledRuleCount regler aktiva'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _toggleAllRules(context, tag, enable: false);
                },
              ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Flytta till grupp'),
              onTap: () {
                Navigator.pop(sheetContext);
                _moveTagToGroup(context, tag);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Ta bort tagg',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetContext);
                _deleteTag(context, tag);
              },
            ),
            const SizedBox(height: AppDimensions.spacingM),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAllRules(
    BuildContext context,
    PersonalTag tag, {
    required bool enable,
  }) async {
    final viewModel = context.read<PersonalTagViewModel>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(enable ? 'Aktivera alla regler?' : 'Inaktivera alla regler?'),
        content: Text(
          enable
              ? 'Alla ${tag.rules.length} regler för "${tag.name}" kommer att aktiveras.'
              : 'Alla ${tag.rules.length} regler för "${tag.name}" kommer att inaktiveras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(enable ? 'Aktivera' : 'Inaktivera'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        for (final rule in tag.rules) {
          if (rule.isEnabled != enable) {
            await viewModel.toggleRuleEnabled(tag.id, rule.id);
          }
        }
        if (context.mounted) {
          SnackBarUtils.showSuccess(
            context,
            enable ? 'Alla regler aktiverade' : 'Alla regler inaktiverade',
          );
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(context, 'Kunde inte ändra reglerna');
        }
      }
    }
  }

  Future<void> _createTag(BuildContext context) async {
    final viewModel = context.read<PersonalTagViewModel>();
    final nameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skapa tagg'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Taggnamn',
            hintText: 'T.ex. Favoriter',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skapa'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        await viewModel.createTag(name: nameController.text.trim());
        if (context.mounted) {
          SnackBarUtils.showSuccess(context, 'Tagg skapad');
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(context, e.toString());
        }
      }
    }

    nameController.dispose();
  }

  Future<void> _editTag(BuildContext context, PersonalTag tag) async {
    final viewModel = context.read<PersonalTagViewModel>();
    final nameController = TextEditingController(text: tag.name);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redigera tagg'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Taggnamn',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Spara'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        final updated = tag.copyWith(name: nameController.text.trim());
        await viewModel.updateTag(updated);
        if (context.mounted) {
          SnackBarUtils.showSuccess(context, 'Tagg uppdaterad');
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(context, e.toString());
        }
      }
    }

    nameController.dispose();
  }

  Future<void> _deleteTag(BuildContext context, PersonalTag tag) async {
    final viewModel = context.read<PersonalTagViewModel>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort tagg?'),
        content: Text(
          'Är du säker på att du vill ta bort "${tag.name}"? '
          'Taggen tas bort från alla recept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await viewModel.deleteTag(tag.id);
        if (context.mounted) {
          SnackBarUtils.showSuccess(context, 'Tagg borttagen');
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(context, e.toString());
        }
      }
    }
  }

  Future<void> _moveTagToGroup(BuildContext context, PersonalTag tag) async {
    final viewModel = context.read<PersonalTagViewModel>();
    final groups = viewModel.groups;

    final selectedGroupId = await showDialog<String?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Flytta till grupp'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: const ListTile(
              leading: Icon(Icons.folder_off),
              title: Text('Ingen grupp'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          for (final group in groups)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, group.id),
              child: ListTile(
                leading: const Icon(Icons.folder),
                title: Text(group.name),
                contentPadding: EdgeInsets.zero,
                selected: tag.groupId == group.id,
              ),
            ),
        ],
      ),
    );

    if (selectedGroupId != null) {
      try {
        final groupId = selectedGroupId.isEmpty ? null : selectedGroupId;
        await viewModel.moveTagToGroup(tag.id, groupId);
        if (context.mounted) {
          SnackBarUtils.showSuccess(context, 'Tagg flyttad');
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(context, e.toString());
        }
      }
    }
  }

  Future<void> _handleGroupAction(
    BuildContext context,
    String action,
    PersonalTagGroup group,
  ) async {
    final viewModel = context.read<PersonalTagViewModel>();

    switch (action) {
      case 'rename':
        final nameController = TextEditingController(text: group.name);
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Byt namn på grupp'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Gruppnamn'),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Avbryt'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Spara'),
              ),
            ],
          ),
        );

        if (result == true && nameController.text.trim().isNotEmpty) {
          try {
            final updated = group.copyWith(name: nameController.text.trim());
            await viewModel.updateGroup(updated);
            if (context.mounted) {
              SnackBarUtils.showSuccess(context, 'Grupp uppdaterad');
            }
          } catch (e) {
            if (context.mounted) {
              SnackBarUtils.showError(context, e.toString());
            }
          }
        }
        nameController.dispose();
        break;

      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ta bort grupp?'),
            content: Text(
              'Är du säker på att du vill ta bort "${group.name}"? '
              'Taggar i gruppen blir ogrupperade.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Avbryt'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ta bort'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          try {
            await viewModel.deleteGroup(group.id);
            if (context.mounted) {
              SnackBarUtils.showSuccess(context, 'Grupp borttagen');
            }
          } catch (e) {
            if (context.mounted) {
              SnackBarUtils.showError(context, e.toString());
            }
          }
        }
        break;
    }
  }
}
