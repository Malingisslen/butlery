// lib/views/realtime/handlers/menu_action_handler.dart

import 'package:flutter/material.dart';
import '../../../viewmodels/realtime_menu_viewmodel.dart';
import '../../../core/utils/logger.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Menu Action Handler - SINGLE RESPONSIBILITY för menu action processing
/// Purpose: BARA hantera menu actions från UI (refresh, invite, permissions, etc.)

/// Handler för menu actions med single responsibility
class MenuActionHandler {
  final RealtimeMenuViewModel viewModel;
  final BuildContext context;

  MenuActionHandler({
    required this.viewModel,
    required this.context,
  });

  /// Hantera menu action baserat på action string
  void handleAction(String action) {
    switch (action) {
      case 'refresh':
        _handleRefresh();
        break;
      case 'invite':
        _handleInvite();
        break;
      case 'permissions':
        _handlePermissions();
        break;
      case 'copy':
        _handleCreateCopy();
        break;
      case 'delete':
        _handleDelete();
        break;
      default:
        AppLogger.warning('Okänd menu action: $action');
    }
  }

  void _handleRefresh() {
    viewModel.refreshConnection();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uppdaterar anslutning...')),
    );
  }

  void _handleInvite() {
    // TODO: Implementera invite dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Inbjudningsfunktion kommer snart!')),
    );
  }

  void _handlePermissions() {
    // TODO: Implementera permissions dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Behörighetshantering kommer snart!')),
    );
  }

  void _handleCreateCopy() {
    final copy = viewModel.createPersonalCopy();
    if (copy != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Personlig kopia skapad! Hittar du i Mina Menyer.'),
        ),
      );
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await _showDeleteConfirmation();
    if (confirmed == true) {
      await viewModel.deleteMenu();
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<bool?> _showDeleteConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort meny'),
        content: const Text(
          'Vill du verkligen ta bort denna gemensamma meny? '
          'Detta kan inte ångras och påverkar alla deltagare.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );
  }
}
