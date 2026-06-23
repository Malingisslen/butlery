// lib/widgets/shopping/shopping_template_browser.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Displays saved shopping list templates for selection or management.
/// Follows the same pattern as MenuTemplateBrowser.
class ShoppingTemplateBrowser extends StatefulWidget {
  final ValueChanged<String> onTemplateSelected;

  const ShoppingTemplateBrowser({
    super.key,
    required this.onTemplateSelected,
  });

  @override
  State<ShoppingTemplateBrowser> createState() =>
      _ShoppingTemplateBrowserState();
}

class _ShoppingTemplateBrowserState extends State<ShoppingTemplateBrowser> {
  List<Map<String, dynamic>> _templates = [];
  bool _isLoading = false;
  bool _hasError = false;
  late final UnifiedShoppingService _shoppingService;

  @override
  void initState() {
    super.initState();
    _shoppingService = ServiceLocator.get<UnifiedShoppingService>();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final templates = await _shoppingService.getUserTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _deleteTemplate(String templateId, String name) async {
    final confirmed = await CommonDialogActions.showDeleteConfirmation(
      context: context,
      itemName: name,
      itemType: context.l10n.shoppingTemplateDelete,
      icon: Icons.delete_outline,
    );
    if (confirmed != true || !mounted) return;

    try {
      await _shoppingService.deleteTemplate(templateId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.shoppingTemplateDeleted)),
      );
      _loadTemplates();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.commonUnknownError),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingXl),
          child: LoadingIndicator(),
        ),
      );
    }

    if (_hasError) {
      return StateWidget.error(
        message: context.l10n.errorGeneric,
        actionLabel: context.l10n.commonRetry,
        onAction: () {
          setState(() => _hasError = false);
          _loadTemplates();
        },
      );
    }

    if (_templates.isEmpty) {
      return StateWidget.empty(
        icon: Icons.list_alt_outlined,
        title: context.l10n.shoppingTemplateEmpty,
        subtitle: context.l10n.shoppingTemplateEmptyDescription,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      itemCount: _templates.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.spacingSm),
      itemBuilder: (context, index) {
        final template = _templates[index];
        final id = (template['id'] as String?).orEmpty();
        final name = (template['name'] as String?).orEmpty();
        final description = (template['description'] as String?).orEmpty();
        final itemCount = (template['itemCount'] as num?)?.toInt() ?? 0;
        final useCount = (template['useCount'] as num?)?.toInt() ?? 0;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            border: Border.all(color: cs.outlineVariant),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM,
              vertical: AppDimensions.paddingS,
            ),
            leading: Icon(
              Icons.list_alt,
              color: cs.primary,
              size: AppDimensions.iconSizeAction,
            ),
            title: Text(name, style: AppTextStyles.titleMedium),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: AppTextStyles.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: AppDimensions.spacingXs),
                Row(
                  children: [
                    Text(
                      context.l10n.shoppingTemplateItemCount(itemCount),
                      style: AppTextStyles.labelSmall,
                    ),
                    const SizedBox(width: AppDimensions.spacingM),
                    Text(
                      context.l10n.shoppingTemplateUsedCount(useCount),
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'use') {
                  widget.onTemplateSelected(id);
                } else if (action == 'delete') {
                  _deleteTemplate(id, name);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'use',
                  child: Row(
                    children: [
                      Icon(
                        Icons.check,
                        size: AppDimensions.iconSizeM,
                        color: cs.primary,
                      ),
                      const SizedBox(width: AppDimensions.spacingM),
                      Text(context.l10n.shoppingTemplateUse),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: AppDimensions.iconSizeM,
                        color: cs.error,
                      ),
                      const SizedBox(width: AppDimensions.spacingM),
                      Text(
                        context.l10n.shoppingTemplateDelete,
                        style: TextStyle(color: cs.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
