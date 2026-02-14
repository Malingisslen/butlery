// lib/widgets/menu/menu_template_browser.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

/// Displays available menu templates for selection.
/// Each template shows its name, description, and category structure.
/// Selecting a template triggers [onTemplateSelected] with a prompt string
/// built from the template's category structure.
///
/// Designed to work both embedded in a TabBarView (inside LoadMenuBottomSheet)
/// and standalone. Does not include bottom sheet chrome.
class MenuTemplateBrowser extends StatefulWidget {
  final MenuViewModel viewModel;

  /// Called with the prompt string when a template is selected
  final ValueChanged<String> onTemplateSelected;

  const MenuTemplateBrowser({
    super.key,
    required this.viewModel,
    required this.onTemplateSelected,
  });

  @override
  State<MenuTemplateBrowser> createState() => _MenuTemplateBrowserState();
}

class _MenuTemplateBrowserState extends State<MenuTemplateBrowser> {
  List<Map<String, dynamic>> _templates = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final templates = await widget.viewModel.getUserMenuTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_templates.isEmpty) {
      return _buildEmptyState();
    }

    return _buildTemplateList();
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      child: StateWidget.empty(
        title: context.l10n.menuTemplateNoTemplates,
        subtitle: context.l10n.menuTemplateNoTemplatesDescription,
        icon: Icons.dashboard_customize_outlined,
      ),
    );
  }

  Widget _buildTemplateList() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        final template = _templates[index];
        return _buildTemplateCard(template);
      },
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    final templateName = template['templateName'] as String? ?? '';
    final description = template['description'] as String? ?? '';
    final categories = List<String>.from(template['categories'] as List? ?? []);
    final totalRecipeCount = template['totalRecipeCount'] as int? ?? 0;
    final useCount = template['useCount'] as int? ?? 0;
    final templateId = template['id'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingXs,
      ),
      shape: const RoundedRectangleBorder(),
      child: InkWell(
        onTap: () => _useTemplate(template),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Template icon
                  Container(
                    width: AppDimensions.iconSizeDisplay,
                    height: AppDimensions.iconSizeDisplay,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Icon(
                      Icons.dashboard_customize,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingM),

                  // Name and metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          templateName,
                          style: AppTextStyles.titleMedium,
                        ),
                        if (description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                                top: AppDimensions.spacingXs),
                            child: Text(
                              description,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textMedium,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Actions menu
                  PopupMenuButton<String>(
                    onSelected: (value) =>
                        _handleAction(templateId, templateName, value),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'use',
                        child: Row(
                          children: [
                            const Icon(Icons.play_arrow),
                            const SizedBox(width: AppDimensions.spacingSm),
                            Text(context.l10n.menuTemplateUseTemplate),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete, color: AppColors.error),
                            const SizedBox(width: AppDimensions.spacingSm),
                            Text(
                              context.l10n.commonDelete,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spacingM),

              // Category chips showing what the template contains
              Wrap(
                spacing: AppDimensions.spacingXs,
                runSpacing: AppDimensions.spacingXs,
                children: [
                  for (final category in categories)
                    _buildCategoryChip(category, template),
                ],
              ),

              const SizedBox(height: AppDimensions.spacingSm),

              // Stats row
              Row(
                children: [
                  Text(
                    context.l10n.menuTemplateRecipes(totalRecipeCount),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMedium,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingL),
                  if (useCount > 0)
                    Text(
                      context.l10n.menuTemplateUsedCount(useCount),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMedium,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a chip showing a category and its recipe count from the template
  Widget _buildCategoryChip(String category, Map<String, dynamic> template) {
    // Try to get recipe count for this category from the snapshot
    final menuSnapshot = template['menuSnapshot'] as Map<String, dynamic>?;
    int count = 0;
    if (menuSnapshot != null) {
      final recipes = menuSnapshot[category] as List<dynamic>?;
      count = recipes?.length ?? 0;
    }

    final label = count > 0 ? '$count $category' : category;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSm,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.forestGreen.withValues(alpha: 0.08),
        border: Border.all(
          color: AppColors.forestGreen.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.forestGreenDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _useTemplate(Map<String, dynamic> template) {
    final prompt = widget.viewModel.buildPromptFromTemplate(template);
    if (prompt.isNotEmpty) {
      widget.onTemplateSelected(prompt);
    }
  }

  void _handleAction(String templateId, String templateName, String action) {
    switch (action) {
      case 'use':
        final template = _templates.firstWhere((t) => t['id'] == templateId);
        _useTemplate(template);
        break;
      case 'delete':
        _confirmDelete(templateId, templateName);
        break;
    }
  }

  Future<void> _confirmDelete(String templateId, String templateName) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.menuTemplateDeleteTitle),
        content: Text(context.l10n.menuTemplateDeleteConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final success = await widget.viewModel.deleteMenuTemplate(templateId);
      if (mounted) {
        if (success) {
          SnackBarUtils.showSuccess(
              context, context.l10n.menuTemplateDeletedSuccess);
          setState(() {
            _templates.removeWhere((t) => t['id'] == templateId);
          });
        } else {
          SnackBarUtils.showError(
              context, context.l10n.menuTemplateDeleteFailed);
        }
      }
    }
  }
}
