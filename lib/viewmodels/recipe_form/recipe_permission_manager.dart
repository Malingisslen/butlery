// lib/viewmodels/recipe_form/recipe_permission_manager.dart

import 'package:flutter/material.dart';
import '../../models/recipe_unified.dart';
import '../../models/permissions/resource_permission.dart';
import '../../models/permissions/edit_mode.dart';
import '../../models/shared_recipe.dart';
import '../../services/permission_service.dart';
import '../../core/utils/logger.dart';
import '../../core/injection.dart';

/// Manages permissions for recipe forms
class RecipePermissionManager extends ChangeNotifier {
  final PermissionService _permissionService;

  EditMode? _editMode;
  SharedRecipe? _sharedRecipe;
  ResourcePermission? _currentUserPermission;
  bool _isOwner = false;

  RecipePermissionManager({
    PermissionService? permissionService,
  }) : _permissionService = permissionService ?? sl<PermissionService>();

  // ===== GETTERS =====

  EditMode? get editMode => _editMode;
  SharedRecipe? get sharedRecipe => _sharedRecipe;
  ResourcePermission? get currentUserPermission => _currentUserPermission;
  bool get isOwner => _isOwner;
  bool get hasPermissions => _editMode != null;

  // Permission checks
  bool get canEdit => _editMode == EditMode.edit;
  bool get canView => _editMode == EditMode.view || canEdit;
  bool get canShare => _isOwner || _currentUserPermission == ResourcePermission.admin;
  bool get canInvite => _isOwner || _currentUserPermission == ResourcePermission.admin;
  bool get canDelete => _isOwner;
  bool get canChangePermissions => _isOwner || _currentUserPermission == ResourcePermission.admin;

  // Specific field permissions
  bool get canEditTitle => canEdit;
  bool get canEditDescription => canEdit;
  bool get canEditIngredients => canEdit;
  bool get canEditInstructions => canEdit;
  bool get canEditImages => canEdit;
  bool get canEditMetadata => canEdit; // portions, time, etc.
  bool get canEditTags => canEdit;

  // ===== PERMISSION LOADING =====

  /// Ladda permissions för ett recept
  Future<void> loadPermissions(Recipe recipe) async {
    try {
      // Kontrollera om användaren är ägare
      final currentUserId = _permissionService.currentUserId;
      if (currentUserId == null) {
        _setNoPermissions();
        return;
      }

      _isOwner = recipe.createdBy == currentUserId;

      // Om användaren är ägare, ge full edit-åtkomst
      if (_isOwner) {
        _setOwnerPermissions();
        return;
      }

      // Kontrollera om receptet är delat med användaren
      final sharedRecipe = await _permissionService.getSharedRecipe(recipe.id);
      if (sharedRecipe != null) {
        _setSharedPermissions(sharedRecipe);
        return;
      }

      // Kontrollera om receptet är publikt
      if (recipe.isPublic) {
        _setPublicPermissions();
        return;
      }

      // Ingen åtkomst
      _setNoPermissions();
    } catch (e) {
      AppLogger.error('Fel vid laddning av permissions: $e');
      _setNoPermissions();
    }
  }

  /// Ladda permissions för kollaborativt recept
  Future<void> loadCollaborativePermissions(String recipeId, String userId) async {
    try {
      final sharedRecipe = await _permissionService.getSharedRecipe(recipeId);
      if (sharedRecipe != null) {
        _setSharedPermissions(sharedRecipe);
      } else {
        _setNoPermissions();
      }
    } catch (e) {
      AppLogger.error('Fel vid laddning av kollaborativa permissions: $e');
      _setNoPermissions();
    }
  }

  /// Uppdatera permissions för en användare
  Future<void> updateUserPermission(String recipeId, String userId, ResourcePermission permission) async {
    if (!canChangePermissions) {
      throw Exception('Ingen behörighet att ändra permissions');
    }

    try {
      await _permissionService.updateRecipePermission(recipeId, userId, permission);
      
      // Uppdatera lokal state om det gäller nuvarande användare
      final currentUserId = _permissionService.currentUserId;
      if (userId == currentUserId) {
        _currentUserPermission = permission;
        _updateEditMode();
      }
      
      notifyListeners();
      AppLogger.info('Permission uppdaterad för användare $userId: $permission');
    } catch (e) {
      AppLogger.error('Fel vid uppdatering av permission: $e');
      throw Exception('Kunde inte uppdatera permission: $e');
    }
  }

  /// Ta bort användare från recept
  Future<void> removeUserFromRecipe(String recipeId, String userId) async {
    if (!canChangePermissions) {
      throw Exception('Ingen behörighet att ta bort användare');
    }

    try {
      await _permissionService.removeRecipePermission(recipeId, userId);
      
      // Om det var nuvarande användare, ta bort permissions
      final currentUserId = _permissionService.currentUserId;
      if (userId == currentUserId) {
        _setNoPermissions();
      }
      
      notifyListeners();
      AppLogger.info('Användare borttagen från recept: $userId');
    } catch (e) {
      AppLogger.error('Fel vid borttagning av användare: $e');
      throw Exception('Kunde inte ta bort användare: $e');
    }
  }

  /// Dela recept med användare
  Future<void> shareRecipeWithUser(String recipeId, String userId, ResourcePermission permission) async {
    if (!canShare) {
      throw Exception('Ingen behörighet att dela recept');
    }

    try {
      await _permissionService.shareRecipe(recipeId, [userId], permission);
      notifyListeners();
      AppLogger.info('Recept delat med användare $userId: $permission');
    } catch (e) {
      AppLogger.error('Fel vid delning av recept: $e');
      throw Exception('Kunde inte dela recept: $e');
    }
  }

  // ===== VALIDATION =====

  /// Validera om användaren kan utföra en specifik action
  bool canPerformAction(String action) {
    switch (action.toLowerCase()) {
      case 'edit':
        return canEdit;
      case 'view':
        return canView;
      case 'share':
        return canShare;
      case 'invite':
        return canInvite;
      case 'delete':
        return canDelete;
      case 'change_permissions':
        return canChangePermissions;
      default:
        return false;
    }
  }

  /// Validera fältspecifika permissions
  bool canEditField(String fieldName) {
    if (!canEdit) return false;
    
    switch (fieldName.toLowerCase()) {
      case 'title':
        return canEditTitle;
      case 'description':
        return canEditDescription;
      case 'ingredients':
        return canEditIngredients;
      case 'instructions':
        return canEditInstructions;
      case 'images':
        return canEditImages;
      case 'metadata':
        return canEditMetadata;
      case 'tags':
        return canEditTags;
      default:
        return canEdit;
    }
  }

  // ===== PRIVATE METHODS =====

  void _setOwnerPermissions() {
    _editMode = EditMode.edit;
    _currentUserPermission = ResourcePermission.owner;
    _isOwner = true;
    _sharedRecipe = null;
    notifyListeners();
  }

  void _setSharedPermissions(SharedRecipe sharedRecipe) {
    _sharedRecipe = sharedRecipe;
    _currentUserPermission = sharedRecipe.permission;
    _isOwner = false;
    _updateEditMode();
    notifyListeners();
  }

  void _setPublicPermissions() {
    _editMode = EditMode.view;
    _currentUserPermission = ResourcePermission.read;
    _isOwner = false;
    _sharedRecipe = null;
    notifyListeners();
  }

  void _setNoPermissions() {
    _editMode = null;
    _currentUserPermission = null;
    _isOwner = false;
    _sharedRecipe = null;
    notifyListeners();
  }

  void _updateEditMode() {
    if (_currentUserPermission == null) {
      _editMode = null;
    } else {
      switch (_currentUserPermission!) {
        case ResourcePermission.owner:
        case ResourcePermission.admin:
        case ResourcePermission.write:
        case ResourcePermission.editor:
          _editMode = EditMode.edit;
          break;
        case ResourcePermission.read:
        case ResourcePermission.viewer:
          _editMode = EditMode.view;
          break;
      }
    }
  }

  /// Hämta permission text för UI
  String getPermissionText(ResourcePermission permission) {
    switch (permission) {
      case ResourcePermission.owner:
        return 'Ägare';
      case ResourcePermission.admin:
        return 'Administratör';
      case ResourcePermission.editor:
        return 'Redigerare';
      case ResourcePermission.write:
        return 'Redigera';
      case ResourcePermission.viewer:
        return 'Betraktare';
      case ResourcePermission.read:
        return 'Visa';
    }
  }

  /// Hämta permission beskrivning för UI
  String getPermissionDescription(ResourcePermission permission) {
    switch (permission) {
      case ResourcePermission.owner:
        return 'Full kontroll över receptet';
      case ResourcePermission.admin:
        return 'Kan redigera och bjuda in andra';
      case ResourcePermission.editor:
        return 'Kan redigera receptet';
      case ResourcePermission.write:
        return 'Kan redigera receptet';
      case ResourcePermission.viewer:
        return 'Kan bara visa receptet';
      case ResourcePermission.read:
        return 'Kan bara visa receptet';
    }
  }

  /// Hämta tillgängliga permissions för delegation
  List<ResourcePermission> getAvailablePermissions() {
    if (_isOwner) {
      return [
        ResourcePermission.admin,
        ResourcePermission.write,
        ResourcePermission.read,
      ];
    } else if (_currentUserPermission == ResourcePermission.admin) {
      return [
        ResourcePermission.write,
        ResourcePermission.read,
      ];
    } else {
      return [];
    }
  }

}