// lib/services/unified/operations/collaborative_menu_operations.dart

import 'dart:ui';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/menu_collaboration_repository.dart';

/// Collaborative menu operations for real-time menu sharing.
/// Handles collaboration setup and real-time listener management.
class CollaborativeMenuOperations {
  final MenuCollaborationRepository _repository;
  final VoidCallback _notifyListeners;

  CollaborativeMenuOperations({
    required VoidCallback notifyListeners,
    required MenuCollaborationRepository repository,
  }) : _notifyListeners = notifyListeners,
       _repository = repository;

  /// Enable real-time collaboration for a menu
  Future<bool> enableMenuCollaboration({
    required String menuId,
    required List<String> collaboratorIds,
    Map<String, String>? collaboratorDisplayNames,
  }) async {
    final result = await _repository.enableCollaboration(
      menuId: menuId,
      collaboratorIds: collaboratorIds,
      collaboratorDisplayNames: collaboratorDisplayNames,
    );

    if (result) {
      _startMenuCollaborationListener(menuId);
    }

    return result;
  }

  /// Start real-time listener for menu collaboration
  void _startMenuCollaborationListener(String menuId) {
    _repository.startCollaborationListener(menuId, (menu) {
      AppLogger.debug('Menu $menuId updated in real-time');
      _notifyListeners();
    });
  }

  /// Dispose of resources
  void dispose() {
    _repository.disposeAllListeners();
    AppLogger.info('Disposed collaborative menu operations');
  }
}
