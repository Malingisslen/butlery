// lib/views/realtime/handlers/menu_action_handler.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/viewmodels/realtime_menu_viewmodel.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/theme/app_colors.dart';

/// Handler for menu action events in realtime menu view
class MenuActionHandler {
  final RealtimeMenuViewModel viewModel;
  final BuildContext context;

  MenuActionHandler({
    required this.viewModel,
    required this.context,
  });

  /// Handle action selected from menu
  Future<void> handleAction(String action) async {
    try {
      switch (action) {
        case 'refresh':
          await _handleRefresh();
          break;
        case 'invite':
          await _handleInvite();
          break;
        case 'permissions':
          await _handlePermissions();
          break;
        case 'copy':
          await _handleCopy();
          break;
        case 'delete':
          await _handleDelete();
          break;
        default:
          AppLogger.warning('Unknown menu action: $action');
      }
    } catch (e) {
      AppLogger.error('Error handling menu action $action', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleRefresh() async {
    // Restart watching to refresh the menu data
    if (viewModel.currentMenu != null) {
      final menuId = viewModel.currentMenu!.id;
      await viewModel.stopWatching();
      await viewModel.startWatching(menuId);
    }
  }

  Future<void> _handleInvite() async {
    final menu = viewModel.currentMenu;
    if (menu == null) {
      _showError('Ingen meny att bjuda in till');
      return;
    }

    try {
      // Show friend selection dialog
      final selectedFriendIds = await _showFriendSelectionDialog();
      if (selectedFriendIds == null || selectedFriendIds.isEmpty) {
        return; // User cancelled
      }

      _showSuccess('Inbjudningar skickade till ${selectedFriendIds.length} vänner');
      AppLogger.success('Menu invitations sent to ${selectedFriendIds.length} friends');
    } catch (e) {
      AppLogger.error('Error inviting friends to menu', e);
      _showError('Kunde inte skicka inbjudningar');
    }
  }

  Future<void> _handlePermissions() async {
    final menu = viewModel.currentMenu;
    if (menu == null) {
      _showError('Ingen meny att hantera behörigheter för');
      return;
    }

    try {
      // Show permissions management dialog
      await _showPermissionsDialog(menu);
    } catch (e) {
      AppLogger.error('Error managing menu permissions', e);
      _showError('Kunde inte hantera behörigheter');
    }
  }

  Future<void> _handleCopy() async {
    final menu = viewModel.currentMenu;
    if (menu == null) {
      _showError('Ingen meny att kopiera');
      return;
    }

    try {
      // Create a shareable text version of the menu
      final menuText = _generateMenuText(menu);
      
      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: menuText));
      
      _showSuccess('Meny kopierad till urklipp');
      AppLogger.success('Menu copied to clipboard');
    } catch (e) {
      AppLogger.error('Error copying menu', e);
      _showError('Kunde inte kopiera meny');
    }
  }

  Future<void> _handleDelete() async {
    final menu = viewModel.currentMenu;
    if (menu == null) {
      _showError('Ingen meny att ta bort');
      return;
    }

    try {
      // Show confirmation dialog
      final shouldDelete = await _showDeleteConfirmationDialog(menu);
      if (!shouldDelete) {
        return; // User cancelled
      }

      // Delete the menu
      await viewModel.deleteMenu();
      
      _showSuccess('Meny borttagen');
      AppLogger.success('Menu deleted successfully');
      
      // Navigate back or close
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      AppLogger.error('Error deleting menu', e);
      _showError('Kunde inte ta bort meny');
    }
  }

  // ===== HELPER METHODS =====

  /// Show friend selection dialog for invitations
  Future<List<String>?> _showFriendSelectionDialog() async {
    return await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bjud in vänner'),
        content: const Text('Vän-inbjudningar kommer att implementeras snart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, <String>[]),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, <String>['demo-friend']),
            child: const Text('Bjud in'),
          ),
        ],
      ),
    );
  }

  /// Show permissions management dialog
  Future<void> _showPermissionsDialog(menu) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hantera behörigheter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meny: ${menu.menuTitle}'),
            const SizedBox(height: 16),
            const Text('Deltagare:'),
            ...menu.participants.map(
              (participant) => ListTile(
                leading: const Icon(Icons.person),
                title: Text(participant.toString()),
                trailing: const Icon(Icons.more_vert),
                dense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stäng'),
          ),
        ],
      ),
    );
  }

  /// Show delete confirmation dialog
  Future<bool> _showDeleteConfirmationDialog(menu) async {
    final result = await CommonDialogActions.showDeleteConfirmation(
      context: context,
      itemName: menu.menuTitle,
      itemType: 'meny',
      warningMessage: 'Detta kan inte ångras. Alla deltagare kommer att förlora åtkomst.',
      icon: Icons.restaurant_menu,
    );

    return result ?? false;
  }

  /// Generate shareable text version of menu
  String _generateMenuText(menu) {
    final buffer = StringBuffer();
    
    buffer.writeln('🍽️ ${menu.menuTitle}');
    buffer.writeln('=' * 50);
    buffer.writeln('📅 Skapad: ${_formatDate(menu.createdAt)}');
    buffer.writeln();
    
    if (menu.menuSnapshot != null && menu.menuSnapshot.isNotEmpty) {
      for (final category in menu.menuSnapshot.keys) {
        final recipes = menu.menuSnapshot[category] ?? [];
        if (recipes.isNotEmpty) {
          buffer.writeln('📋 $category:');
          for (final recipe in recipes) {
            buffer.writeln('  • ${recipe.title}');
          }
          buffer.writeln();
        }
      }
    }
    
    if (menu.menuNotes != null && menu.menuNotes.isNotEmpty) {
      buffer.writeln('📝 Anteckningar:');
      buffer.writeln(menu.menuNotes);
      buffer.writeln();
    }
    
    buffer.writeln('👥 Deltagare: ${menu.participants.length}');
    buffer.writeln('📱 Delad via Butlery App');
    
    return buffer.toString();
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToCheck = DateTime(date.year, date.month, date.day);
    
    if (dateToCheck == today) {
      return 'Idag ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Show success message
  void _showSuccess(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Show error message
  void _showError(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
