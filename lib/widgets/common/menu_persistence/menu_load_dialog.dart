// lib/widgets/common/menu_persistence/menu_load_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/press_fill.dart';

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
          AppDimensions.radiusCard,
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
              color: AppModeColors.textDisabled(Theme.of(context).brightness),
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
                ButleryIcon(
                  ButleryIcons.folder,
                  size: AppDimensions.iconSizeAction,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: AppDimensions.space4),
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
                // The plate line says what it fetches (produktregler.md:163).
                ? Center(
                    child: PlateLineMessage(
                      message: context.l10n.menuLoadingSaved,
                    ),
                  )
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
        icon: ButleryIcons.folder,
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
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
          ),
          child: ButleryIcon(
            ButleryIcons.utensils,
            color: Theme.of(context).colorScheme.onSurface,
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
        trailing: PressFill(
          surface: PressSurface.base,
          child: PopupMenuButton<String>(
            icon: const ButleryIcon(ButleryIcons.moreVertical),
            onSelected: (value) => _handleMenuAction(menu, value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'load',
                child: Builder(
                  builder: (context) => Row(
                    children: [
                      const ButleryIcon(ButleryIcons.download),
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
                      ButleryIcon(
                        ButleryIcons.trash2,
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
        _deleteMenuWithUndo(menu);
        break;
    }
  }

  Future<void> _loadMenu(dynamic menu) async {
    try {
      final success = await widget.viewModel.loadSavedMenu(menu.key);

      if (mounted) {
        Navigator.pop(context);
        if (success) {
          SnackBarUtils.showSuccess(
            context,
            context.l10n.menuLoadedSuccess((menu.name as String?).orEmpty()),
          );
        } else {
          SnackBarUtils.showFailure(
            context,
            what: widget.viewModel.error ?? context.l10n.menuLoadFailed,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.errorLoadingWithDetails(
            SnackBarUtils.userFriendlyMessage(context, e),
          ),
        );
      }
    }
  }

  // BUT-2145: deleting a saved menu is class 1 (produktregler.md § 2.4):
  // it happens at once with seven seconds of Ångra, no confirmation dialog.
  // The delete commits only when the snackbar closes without Ångra.
  void _deleteMenuWithUndo(dynamic menu) {
    final index = _savedMenus.indexOf(menu);
    if (index < 0) return;
    // A copy: savedMenus hands out an unmodifiable list.
    setState(() => _savedMenus = [..._savedMenus]..removeAt(index));

    void restore() {
      if (!mounted || _savedMenus.contains(menu)) return;
      setState(() {
        _savedMenus = [..._savedMenus]
          ..insert(index.clamp(0, _savedMenus.length), menu);
      });
    }

    // The sheet may be closed before the delete commits; the root navigator
    // outlives it, so a failure still reaches the user.
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    SnackBarUtils.showUndoDeferred(
      context,
      context.l10n.menuDeletedSuccess((menu.name as String?).orEmpty()),
      onUndo: restore,
      onCommit: () async {
        final success = await widget.viewModel.deleteSavedMenu(menu.key);
        if (success) return;
        final target = mounted ? context : rootContext;
        if (!target.mounted) return;
        restore();
        SnackBarUtils.showFailure(
          target,
          what: widget.viewModel.error ?? target.l10n.menuDeleteFailed,
        );
      },
    );
  }
}
