/// Manager handling permission validation for collaborative shopping lists.

import 'package:flutter/foundation.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Manages permission validation for collaborative shopping lists with comprehensive access control.
class ShoppingPermissionManager extends ChangeNotifier {
  final String listId;

  ShoppingPermissionManager(this.listId);

  bool get canEdit {
    final permissionService = ServiceLocator.get<PermissionService>();
    return permissionService.canEditShoppingList(listId);
  }

  bool get canView {
    final permissionService = ServiceLocator.get<PermissionService>();
    return permissionService.canViewShoppingList(listId);
  }

  bool canEditShoppingList(String listId) {
    final permissionService = ServiceLocator.get<PermissionService>();
    return permissionService.canEditShoppingList(listId);
  }

  bool canViewShoppingList(String listId) {
    final permissionService = ServiceLocator.get<PermissionService>();
    return permissionService.canViewShoppingList(listId);
  }
}
