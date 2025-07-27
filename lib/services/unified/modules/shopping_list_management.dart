// lib/services/unified/modules/shopping_list_management.dart

import 'dart:async';
import 'package:collection/collection.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/services/permission_service.dart';

/// Handles shopping list management operations
class ShoppingListManagement {
  final List<UnifiedShoppingList> _lists;
  final String? Function() _getCurrentUserId;
  final String? Function() _getCurrentUserDisplayName;
  final void Function(String?) _setActiveListId;
  final void Function() _notifyListeners;
  final void Function(String) _setError;
  final Future<bool> Function(UnifiedShoppingList) _updateListInternal;
  final Future<void> Function(UnifiedShoppingList) _saveToCache;
  final void Function(String) _scheduleSyncForItem;
  final void Function(String, bool) _scheduleDeleteForList;

  ShoppingListManagement({
    required List<UnifiedShoppingList> lists,
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required void Function(String?) setActiveListId,
    required void Function() notifyListeners,
    required void Function(String) setError,
    required Future<bool> Function(UnifiedShoppingList) updateListInternal,
    required Future<void> Function(UnifiedShoppingList) saveToCache,
    required void Function(String) scheduleSyncForItem,
    required void Function(String, bool) scheduleDeleteForList,
  }) : _lists = lists,
       _getCurrentUserId = getCurrentUserId,
       _getCurrentUserDisplayName = getCurrentUserDisplayName,
       _setActiveListId = setActiveListId,
       _notifyListeners = notifyListeners,
       _setError = setError,
       _updateListInternal = updateListInternal,
       _saveToCache = saveToCache,
       _scheduleSyncForItem = scheduleSyncForItem,
       _scheduleDeleteForList = scheduleDeleteForList;

  Future<String?> createPersonalList(String name,
      {List<UnifiedShoppingItem>? items}) async {
    if (!sl<PermissionService>().isAuthenticated) {
      _setError('Du måste vara inloggad');
      return null;
    }

    if (name.trim().isEmpty) {
      _setError('Listnamn kan inte vara tomt');
      return null;
    }

    try {
      final newList = UnifiedShoppingList.personal(
        name: name.trim(),
        ownerId: _getCurrentUserId()!,
        ownerDisplayName: _getCurrentUserDisplayName()!,
        items: items,
      );

      // Lägg till lokalt (optimistic update)
      _lists.add(newList);
      _setActiveListId(newList.id);
      _notifyListeners();

      // Spara till cache
      await _saveToCache(newList);

      // Synka till Firebase using mixin
      _scheduleSyncForItem(newList.id);

      AppLogger.success('✅ Personlig lista "$name" skapad');
      return newList.id;
    } catch (e) {
      AppLogger.error('❌ Kunde inte skapa personlig lista: $e');
      _setError('Kunde inte skapa lista: $e');
      return null;
    }
  }

  Future<String?> createCollaborativeList({
    required String name,
    String? description,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    List<UnifiedShoppingItem>? items,
    List<String>? categoryIds,
    bool allowGuestEditing = true,
    bool autoRemoveCompleted = false,
  }) async {
    if (!sl<PermissionService>().isAuthenticated) {
      _setError('Du måste vara inloggad');
      return null;
    }

    if (name.trim().isEmpty) {
      _setError('Listnamn kan inte vara tomt');
      return null;
    }

    try {
      // Skapa member permissions
      final memberPermissions = <String, SharedListPermission>{};
      for (final memberId in memberIds) {
        memberPermissions[memberId] = SharedListPermission.edit;
      }

      final newList = UnifiedShoppingList.collaborative(
        name: name.trim(),
        ownerId: _getCurrentUserId()!,
        ownerDisplayName: _getCurrentUserDisplayName()!,
        memberPermissions: memberPermissions,
        items: items,
        description: description?.trim(),
        categoryIds: categoryIds,
        allowGuestEditing: allowGuestEditing,
        autoRemoveCompleted: autoRemoveCompleted,
      );

      // Lägg till lokalt (optimistic update)
      _lists.add(newList);
      _setActiveListId(newList.id);
      _notifyListeners();

      // Spara till cache
      await _saveToCache(newList);

      // Synka till Firebase using mixin (collaborative lists använder annan collection)
      _scheduleSyncForItem(newList.id);

      AppLogger.success(
          '✅ Kollaborativ lista "$name" skapad med ${memberIds.length} medlemmar');
      return newList.id;
    } catch (e) {
      AppLogger.error('❌ Kunde inte skapa kollaborativ lista: $e');
      _setError('Kunde inte skapa kollaborativ lista: $e');
      return null;
    }
  }

  Future<bool> renameList(String listId, String newName) async {
    try {
      if (newName.trim().isEmpty) {
        _setError('Listnamn kan inte vara tomt');
        return false;
      }

      final list = _lists.where((l) => l.id == listId).firstOrNull;
      if (list == null) {
        _setError('Lista hittades inte');
        return false;
      }

      final updatedList = list.copyWith(name: newName.trim());
      return await _updateListInternal(updatedList);
    } catch (e) {
      AppLogger.error('❌ Kunde inte döpa om lista: $e');
      _setError('Kunde inte döpa om lista: $e');
      return false;
    }
  }

  Future<bool> deleteList(String listId) async {
    try {
      final list = _lists.where((l) => l.id == listId).firstOrNull;
      if (list == null) {
        _setError('Lista hittades inte');
        return false;
      }

      // Ta bort från lokal lista
      _lists.removeWhere((l) => l.id == listId);

      // Om detta var aktiv lista, sätt ny aktiv lista
      if (listId == _lists.firstOrNull?.id) {
        _setActiveListId(_lists.isNotEmpty ? _lists.first.id : null);
      }

      _notifyListeners();

      // Schemalägg borttagning från Firebase
      _scheduleDeleteForList(listId, list.isCollaborative);

      AppLogger.success('✅ Lista "${list.name}" borttagen');
      return true;
    } catch (e) {
      AppLogger.error('❌ Kunde inte ta bort lista: $e');
      _setError('Kunde inte ta bort lista: $e');
      return false;
    }
  }

  Future<bool> setActiveList(String listId) async {
    try {
      final list = _lists.where((l) => l.id == listId).firstOrNull;
      if (list == null) {
        _setError('Lista hittades inte');
        return false;
      }

      _setActiveListId(listId);
      _notifyListeners();

      AppLogger.info('✅ Aktiv lista satt till: ${list.name}');
      return true;
    } catch (e) {
      AppLogger.error('❌ Kunde inte sätta aktiv lista: $e');
      _setError('Kunde inte sätta aktiv lista: $e');
      return false;
    }
  }

  String exportListAsText(String listId) {
    final list = _lists.where((l) => l.id == listId).firstOrNull;
    if (list == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('=== ${list.name} ===');
    buffer.writeln('Skapad: ${list.createdAt.toLocal()}');
    buffer.writeln('');

    final pendingItems = list.items.where((item) => !item.isCompleted).toList();
    final boughtItems = list.items.where((item) => item.isCompleted).toList();

    if (pendingItems.isNotEmpty) {
      buffer.writeln('☐ Att köpa:');
      for (final item in pendingItems) {
        buffer.writeln('☐ ${item.displayText}');
      }
      buffer.writeln('');
    }

    if (boughtItems.isNotEmpty) {
      buffer.writeln('☑ Inköpt:');
      for (final item in boughtItems) {
        buffer.writeln('☑ ${item.displayText}');
      }
    }

    return buffer.toString();
  }
}