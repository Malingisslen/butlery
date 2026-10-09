// lib/widgets/shopping/shopping_template_browser.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/press_fill.dart';

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

  /// Deleting a template is class 1: it goes at once and "Ångra" brings it
  /// back for 7 s (produktregler.md § 2.4), so there is no confirmation. The
  /// delete itself is written only once the snackbar closes without Ångra.
  void _deleteTemplate(String templateId) {
    final index = _templates.indexWhere((t) => t['id'] == templateId);
    if (index < 0) return;
    final removed = _templates[index];
    final failureText = context.l10n.commonUnknownError;
    setState(() => _templates = [..._templates]..removeAt(index));

    SnackBarUtils.showUndoDeferred(
      context,
      context.l10n.shoppingTemplateDeleted,
      onUndo: () {
        if (!mounted) return;
        setState(() {
          _templates = [..._templates]
            ..insert(index.clamp(0, _templates.length), removed);
        });
      },
      onCommit: () async {
        try {
          await _shoppingService.deleteTemplate(templateId);
        } catch (_) {
          // The row is already gone from the screen, so a failed delete has
          // to bring it back and say so. A closed browser has nothing to
          // correct: the template is still stored and shows on next open.
          if (!mounted) return;
          SnackBarUtils.showFailure(context, what: failureText);
          _loadTemplates();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      // The plate line says what it fetches (produktregler.md:163).
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.layoutMarginOf(context),
            vertical: AppDimensions.space16,
          ),
          child: PlateLineMessage(
            message: context.l10n.shoppingLoadingTemplates,
          ),
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
        icon: ButleryIcons.list,
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
            leading: ButleryIcon(
              ButleryIcons.list,
              color: cs.onSurface,
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
                // The two counts share a phone-width tile with the menu
                // button, so the second wraps under the first rather than
                // overflowing.
                Wrap(
                  spacing: AppDimensions.spacingM,
                  children: [
                    Text(
                      context.l10n.shoppingTemplateItemCount(itemCount),
                      style: AppTextStyles.labelSmall,
                    ),
                    Text(
                      context.l10n.shoppingTemplateUsedCount(useCount),
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
            trailing: PressFill(
              surface: PressSurface.base,
              child: PopupMenuButton<String>(
                icon: const ButleryIcon(ButleryIcons.moreVertical),
                onSelected: (action) {
                  if (action == 'use') {
                    widget.onTemplateSelected(id);
                  } else if (action == 'delete') {
                    _deleteTemplate(id);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'use',
                    child: Row(
                      children: [
                        ButleryIcon(
                          ButleryIcons.check,
                          size: AppDimensions.iconSizeM,
                          color: cs.onSurface,
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
                        ButleryIcon(
                          ButleryIcons.trash2,
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
          ),
        );
      },
    );
  }
}
