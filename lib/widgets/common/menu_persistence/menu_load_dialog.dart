// lib/widgets/common/menu_persistence/menu_load_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Bottom sheet for loading a saved menu
///
/// This bottom sheet allows users to browse and load their saved menus,
/// with options to load, mark as modified, or delete menus.
class LoadMenuBottomSheet extends StatefulWidget {
  final MenuViewModel viewModel;

  const LoadMenuBottomSheet({
    super.key,
    required this.viewModel,
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
    if (mounted) setState(() {
      _isLoading = true;
    });

    try {
      // FIXED: Use actual ViewModel saved menus
      await widget.viewModel.refreshSavedMenus(); // Ensure menus are loaded
      
      if (mounted) {
        if (mounted) setState(() {
          _savedMenus = widget.viewModel.savedMenus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (mounted) setState(() {
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
        borderRadius: BorderRadius.circular(AppDimensions.bottomSheetBorderRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: AppDimensions.iconSizeDisplay,
            height: AppDimensions.spacingXs,
            margin: const EdgeInsets.symmetric(vertical: AppDimensions.spacingL),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppDimensions.spacingXs),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
            child: Row(
              children: [
                Icon(
                  Icons.folder_open,
                  size: AppDimensions.iconSizeAction,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppDimensions.spacingS),
                const Text(
                  'Sparade menyer',
                  style: AppTextStyles.headlineSmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Stäng'),
                ),
              ],
            ),
          ),

          const Divider(height: AppDimensions.spacingL),

          // Content
          Flexible(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
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
        title: 'Inga sparade menyer',
        subtitle: 'Du har inga sparade menyer än. Generera och spara en meny först!',
        icon: Icons.folder_outlined,
        onAction: () => Navigator.pop(context),
        actionLabel: 'Stäng',
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
            borderRadius: BorderRadius.circular(AppDimensions.smallRadius),
          ),
          child: Icon(
            Icons.restaurant_menu,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          'Meny ${menu.toString()}',
          style: AppTextStyles.titleMedium,
        ),
        subtitle: const Text(
          'Sparad tidigare',
          style: AppTextStyles.bodySmall,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(menu, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'load',
              child: Row(
                children: [
                  Icon(Icons.download),
                  SizedBox(width: AppDimensions.spacingSm),
                  Text('Ladda'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: AppColors.error),
                  SizedBox(width: AppDimensions.spacingSm),
                  Text('Ta bort', style: TextStyle(color: AppColors.error)),
                ],
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
      // FIXED: Use actual ViewModel load logic
      final success = await widget.viewModel.loadSavedMenu(menu.key);
      
      if (mounted) {
        Navigator.pop(context);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Meny "${menu.name}" laddad!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.viewModel.error ?? 'Kunde inte ladda meny'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fel vid laddning: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteMenu(dynamic menu) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort meny'),
        content: const Text('Är du säker på att du vill ta bort denna meny?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        // FIXED: Use actual ViewModel delete logic
        final success = await widget.viewModel.deleteSavedMenu(menu.key);
        
        if (mounted) {
          if (success) {
            if (mounted) setState(() {
              _savedMenus.remove(menu);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Meny "${menu.name}" borttagen'),
                backgroundColor: AppColors.success,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(widget.viewModel.error ?? 'Kunde inte ta bort meny'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fel vid borttagning: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreams(); // From StreamManagementMixin
    super.dispose();
  }
}