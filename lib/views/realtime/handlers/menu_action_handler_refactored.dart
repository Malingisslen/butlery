// lib/views/realtime/handlers/menu_action_handler_refactored.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/core/base/base_action_handler.dart';
import 'package:butlery/viewmodels/realtime_menu_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';

/// Refactored MenuActionHandler using BaseActionHandler
/// 
/// This class provides standardized menu action operations with:
/// - Consistent error handling and user feedback
/// - Proper confirmation dialogs for dangerous operations
/// - Safe context handling for UI operations
/// - Standardized clipboard and sharing operations
class MenuActionHandler extends BaseActionHandler with ActionStateMixin {
  final RealtimeMenuViewModel viewModel;

  @override
  String get serviceName => 'MenuActionHandler';

  MenuActionHandler({
    required this.viewModel,
  });

  // ===== MAIN ACTION HANDLER =====

  /// Handle action selected from menu
  Future<void> handleAction(BuildContext context, String action) async {
    if (!validateContext(context)) return;

    switch (action) {
      case 'refresh':
        await handleRefresh(context);
        break;
      case 'invite':
        await handleInvite(context);
        break;
      case 'permissions':
        await handlePermissions(context);
        break;
      case 'copy':
        await handleCopy(context);
        break;
      case 'delete':
        await handleDelete(context);
        break;
      default:
        showErrorMessage(context, 'Okänd åtgärd: $action');
    }
  }

  // ===== INDIVIDUAL ACTION OPERATIONS =====

  /// Handle menu refresh action
  Future<void> handleRefresh(BuildContext context) async {
    if (!validateContext(context)) return;

    await executeAction(
      context: context,
      action: () async {
        if (viewModel.currentMenu != null) {
          final menuId = viewModel.currentMenu!.id;
          await viewModel.stopWatching();
          await viewModel.startWatching(menuId);
        }
        return true;
      },
      successMessage: 'Meny uppdaterad',
      errorMessage: 'Kunde inte uppdatera meny',
      metadata: {
        'menu_id': viewModel.currentMenu?.id,
        'action': 'refresh_menu',
      },
    );
  }

  /// Handle invite friends action
  Future<void> handleInvite(BuildContext context) async {
    if (!validateContext(context)) return;

    final menu = viewModel.currentMenu;
    if (menu == null) {
      showErrorMessage(context, 'Ingen meny att bjuda in till');
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        // Show friend selection dialog
        final selectedFriendIds = await _showFriendSelectionDialog(context);
        if (selectedFriendIds == null || selectedFriendIds.isEmpty) {
          throw Exception('Ingen vän vald för inbjudan');
        }

        // In real implementation, send invitations
        await Future.delayed(const Duration(milliseconds: 800));
        
        return selectedFriendIds.length;
      },
      successMessage: 'Inbjudningar skickade!',
      errorMessage: 'Kunde inte skicka inbjudningar',
      metadata: {
        'menu_id': menu.id,
        'menu_title': menu.menuTitle,
        'action': 'invite_friends',
      },
    );
  }

  /// Handle permissions management
  Future<void> handlePermissions(BuildContext context) async {
    if (!validateContext(context)) return;

    final menu = viewModel.currentMenu;
    if (menu == null) {
      showErrorMessage(context, 'Ingen meny att hantera behörigheter för');
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        // Show permissions management dialog
        await _showPermissionsDialog(context, menu);
        return true;
      },
      errorMessage: 'Kunde inte hantera behörigheter',
      metadata: {
        'menu_id': menu.id,
        'menu_title': menu.menuTitle,
        'participant_count': menu.participants.length,
        'action': 'manage_permissions',
      },
    );
  }

  /// Handle copy menu to clipboard
  Future<void> handleCopy(BuildContext context) async {
    if (!validateContext(context)) return;

    final menu = viewModel.currentMenu;
    if (menu == null) {
      showErrorMessage(context, 'Ingen meny att kopiera');
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        // Create a shareable text version of the menu
        final menuText = _generateMenuText(menu);
        
        // Copy to clipboard
        await Clipboard.setData(ClipboardData(text: menuText));
        
        return true;
      },
      successMessage: 'Meny kopierad till urklipp',
      errorMessage: 'Kunde inte kopiera meny',
      metadata: {
        'menu_id': menu.id,
        'menu_title': menu.menuTitle,
        'action': 'copy_menu',
      },
    );
  }

  /// Handle delete menu with confirmation
  Future<void> handleDelete(BuildContext context) async {
    if (!validateContext(context)) return;

    final menu = viewModel.currentMenu;
    if (menu == null) {
      showErrorMessage(context, 'Ingen meny att ta bort');
      return;
    }

    await executeDeleteAction(
      context: context,
      deleteAction: () async {
        await viewModel.deleteMenu();
        return true;
      },
      itemName: menu.menuTitle,
      itemType: 'meny',
      warningMessage: 'Alla deltagare kommer att förlora åtkomst till menyn.',
      icon: Icons.restaurant_menu,
      successMessage: 'Meny "${menu.menuTitle}" borttagen',
      errorMessage: 'Kunde inte ta bort meny',
      popOnSuccess: true,
      metadata: {
        'menu_id': menu.id,
        'menu_title': menu.menuTitle,
        'participant_count': menu.participants.length,
        'action': 'delete_menu',
      },
    );
  }

  // ===== BATCH OPERATIONS =====

  /// Invite multiple friends at once
  Future<void> inviteMultipleFriends(
    BuildContext context,
    List<String> friendIds,
  ) async {
    if (!validateContext(context) || friendIds.isEmpty) {
      showErrorMessage(context, 'Inga vänner valda för inbjudan');
      return;
    }

    final menu = viewModel.currentMenu;
    if (menu == null) {
      showErrorMessage(context, 'Ingen meny att bjuda in till');
      return;
    }

    await executeWithLoadingState(
      context: context,
      action: () async {
        // In real implementation, send batch invitations
        await Future.delayed(const Duration(milliseconds: 1200));
        return friendIds.length;
      },
      successMessage: '${friendIds.length} inbjudningar skickade!',
      errorMessage: 'Kunde inte skicka alla inbjudningar',
      metadata: {
        'menu_id': menu.id,
        'friend_count': friendIds.length,
        'friend_ids': friendIds,
        'action': 'invite_multiple_friends',
      },
    );
  }

  /// Remove multiple participants
  Future<void> removeMultipleParticipants(
    BuildContext context,
    List<String> participantIds,
  ) async {
    if (!validateContext(context) || participantIds.isEmpty) {
      showErrorMessage(context, 'Inga deltagare valda');
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // In real implementation, remove participants
        await Future.delayed(const Duration(milliseconds: 800));
        return participantIds.length;
      },
      confirmationTitle: 'Ta bort deltagare?',
      confirmationMessage: 'Vill du ta bort ${participantIds.length} deltagare från menyn?',
      confirmActionText: 'Ta bort alla',
      confirmationIcon: Icons.person_remove,
      isDangerous: true,
      successMessage: '${participantIds.length} deltagare borttagna',
      errorMessage: 'Kunde inte ta bort alla deltagare',
      metadata: {
        'participant_count': participantIds.length,
        'participant_ids': participantIds,
        'action': 'remove_multiple_participants',
      },
    );
  }

  // ===== HELPER DIALOGS =====

  /// Show friend selection dialog for invitations
  Future<List<String>?> _showFriendSelectionDialog(BuildContext context) async {
    return await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bjud in vänner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Välj vänner att bjuda in till menyn.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.accent, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vän-inbjudningar kommer att implementeras snart.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ['demo-friend-1', 'demo-friend-2']),
            child: const Text('Bjud in (Demo)'),
          ),
        ],
      ),
    );
  }

  /// Show permissions management dialog
  Future<void> _showPermissionsDialog(BuildContext context, menu) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hantera behörigheter'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Meny: ${menu.menuTitle}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Deltagare:'),
              const SizedBox(height: 8),
              if (menu.participants.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Inga deltagare ännu',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: menu.participants.length,
                    itemBuilder: (context, index) {
                      final participant = menu.participants[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(participant.toString()),
                        subtitle: const Text('Medlem'),
                        trailing: PopupMenuButton(
                          icon: const Icon(Icons.more_vert),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'change_role',
                              child: Row(
                                children: [
                                  Icon(Icons.edit),
                                  SizedBox(width: 8),
                                  Text('Ändra roll'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(Icons.person_remove, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Ta bort', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            // Handle participant actions
                            showInfoMessage(context, 'Deltagarhantering kommer snart');
                          },
                        ),
                        dense: true,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stäng'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              showInfoMessage(context, 'Bjud in fler kommer snart');
            },
            child: const Text('Bjud in fler'),
          ),
        ],
      ),
    );
  }

  // ===== UTILITY METHODS =====

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

  /// Check if menu can be deleted
  bool canDeleteMenu() {
    final menu = viewModel.currentMenu;
    return menu != null; // Simplified permission check
  }

  /// Check if user can invite friends
  bool canInviteFriends() {
    final menu = viewModel.currentMenu;
    return menu != null; // Simplified permission check
  }

  /// Check if user can manage permissions
  bool canManagePermissions() {
    final menu = viewModel.currentMenu;
    return menu != null; // Simplified permission check
  }

  /// Get menu statistics for sharing
  Map<String, dynamic> getMenuStats() {
    final menu = viewModel.currentMenu;
    if (menu == null) return {};

    int totalRecipes = 0;
    for (final recipes in menu.menuSnapshot.values) {
      totalRecipes += recipes.length;
    }

    return {
      'title': menu.menuTitle,
      'participant_count': menu.participants.length,
      'recipe_count': totalRecipes,
      'category_count': menu.menuSnapshot.keys.length,
      'created_at': menu.createdAt,
      'has_notes': menu.menuNotes?.isNotEmpty ?? false,
    };
  }

  // ===== CLEANUP =====

  /// Dispose resources
  void dispose() {
    clearError();
  }
}