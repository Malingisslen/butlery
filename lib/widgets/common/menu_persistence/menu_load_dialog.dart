// lib/widgets/common/menu_persistence/menu_load_dialog.dart

import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_styles.dart';
import '../../../viewmodels/menu_viewmodel.dart';
import '../state_widget.dart';

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
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implement actual load logic
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        setState(() {
          _savedMenus = []; // Empty for now
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
        borderRadius: BorderRadius.circular(AppDimensions.bottomSheetBorderRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: AppDimensions.iconSizeDisplay,
            height: AppDimensions.spacingXs,
            margin: EdgeInsets.symmetric(vertical: AppDimensions.spacingL),
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
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
            child: Row(
              children: [
                Icon(
                  Icons.folder_open,
                  size: AppDimensions.iconSizeAction,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: AppDimensions.spacingS),
                Text(
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

          Divider(height: AppDimensions.spacingL),

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
      padding: EdgeInsets.all(AppDimensions.spacingXl),
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
      margin: EdgeInsets.symmetric(
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
        subtitle: Text(
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
                  SizedBox(width: 8),
                  Text('Ladda'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: AppColors.error),
                  SizedBox(width: 8),
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
      // TODO: Implement actual load logic
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meny laddad!'),
            backgroundColor: AppColors.success,
          ),
        );
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
        // TODO: Implement actual delete logic
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          setState(() {
            _savedMenus.remove(menu);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Meny borttagen'),
              backgroundColor: AppColors.success,
            ),
          );
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
}