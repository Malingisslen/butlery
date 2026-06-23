// lib/widgets/common/menu_persistence/menu_load_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Bottom sheet for loading a saved menu.
class LoadMenuBottomSheet extends StatefulWidget {
  final MenuViewModel viewModel;

  /// Unused — kept for API compatibility during cleanup.
  final ValueChanged<String>? onTemplateSelected;

  const LoadMenuBottomSheet({
    super.key,
    required this.viewModel,
    this.onTemplateSelected,
  });

  @override
  State<LoadMenuBottomSheet> createState() => _LoadMenuBottomSheetState();
}

class _LoadMenuBottomSheetState extends State<LoadMenuBottomSheet> {
  List<dynamic> _savedMenus = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedMenus();
  }

  Future<void> _loadSavedMenus() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      await widget.viewModel.refreshSavedMenus();

      if (mounted) {
        setState(() {
          _savedMenus = widget.viewModel.savedMenus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(
          AppDimensions.bottomSheetBorderRadius,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: AppDimensions.iconSizeDisplay,
            height: AppDimensions.spacingXs,
            margin: const EdgeInsets.symmetric(
              vertical: AppDimensions.spacingL,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(
                alpha: AppDimensions.opacityMedium,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.spacingXs),
            ),
          ),

          // Title row with close button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingL,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_open,
                  size: AppDimensions.iconSizeAction,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppDimensions.spacingS),
                Text(
                  context.l10n.menuSavedMenus,
                  style: AppTextStyles.headlineSmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.commonClose),
                ),
              ],
            ),
          ),

          // Saved menus content
          Flexible(
            child: _isLoading
                ? const Center(child: LoadingIndicator())
                : _savedMenus.isEmpty
                ? _buildEmptyState()
                : _buildMenuList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      child: StateWidget.empty(
        title: context.l10n.menuNoSavedMenus,
        subtitle: context.l10n.menuNoSavedMenusDescription,
        icon: Icons.folder_outlined,
        onAction: () => Navigator.pop(context),
        actionLabel: context.l10n.commonClose,
      ),
    );
  }

  Widget _buildMenuList() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _savedMenus.length,
      itemBuilder: (context, index) {
        final menu = _savedMenus[index];
        return _buildMenuListItem(menu);
      },
    );
  }

  Widget _buildMenuListItem(dynamic menu) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingXs,
      ),
      child: ListTile(
        leading: Container(
          width: AppDimensions.iconSizeDisplay,
          height: AppDimensions.iconSizeDisplay,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          ),
          child: Icon(
            Icons.restaurant_menu,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          menu.name ?? context.l10n.menuUnnamed,
          style: AppTextStyles.titleMedium,
        ),
        subtitle: Text(
          context.l10n.menuSavedEarlier,
          style: AppTextStyles.bodySmall,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(menu, value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'load',
              child: Builder(
                builder: (context) => Row(
                  children: [
                    const Icon(Icons.download),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Text(context.l10n.menuLoad),
                  ],
                ),
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Builder(
                builder: (context) => Row(
                  children: [
                    Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Text(
                      context.l10n.commonDelete,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        onTap: () => _loadMenu(menu),
      ),
    );
  }

  void _handleMenuAction(dynamic menu, String action) {
    switch (action) {
      case 'load':
        _loadMenu(menu);
        break;
      case 'delete':
        _confirmDeleteMenu(menu);
        break;
    }
  }

  Future<void> _loadMenu(dynamic menu) async {
    try {
      final success = await widget.viewModel.loadSavedMenu(menu.key);

      if (mounted) {
        Navigator.pop(context);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.menuLoadedSuccess(menu.name ?? '')),
              backgroundColor: context.butleryColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.viewModel.error ?? context.l10n.menuLoadFailed,
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.errorLoadingWithDetails(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteMenu(dynamic menu) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.menuDeleteTitle),
        content: Text(context.l10n.menuDeleteConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        final success = await widget.viewModel.deleteSavedMenu(menu.key);

        if (mounted) {
          if (success) {
            setState(() {
              _savedMenus.remove(menu);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.menuDeletedSuccess(menu.name ?? '')),
                backgroundColor: context.butleryColors.success,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  widget.viewModel.error ?? context.l10n.menuDeleteFailed,
                ),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.errorDeletingWithDetails(e.toString()),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}
