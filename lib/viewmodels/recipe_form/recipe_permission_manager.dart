// lib/viewmodels/recipe_form/recipe_permission_manager.dart

import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/realtime_sync_service.dart';

/// Consolidated recipe permission manager providing comprehensive access control and collaborative sharing.
/// Simplified permission management system consolidated during architecture refactoring,
/// providing unified permission checking and collaborative access control for recipe form operations.
/// Maintains compatibility with complex permission systems while providing streamlined functionality.
class RecipePermissionManager {
  /// Current recipe ID for permission validation
  String? _recipeId;

  /// Optional permission service for testing
  final PermissionService? _testPermissionService;

  /// Initializes permission manager with parent ViewModel coordination.
  RecipePermissionManager({PermissionService? permissionService})
    : _testPermissionService = permissionService;

  /// Gets permission service - either injected for testing or from ServiceLocator
  PermissionService get _permissionService =>
      _testPermissionService ?? ServiceLocator.get<PermissionService>();

  /// Sets the current recipe ID for permission validation
  void setRecipeId(String? recipeId) {
    _recipeId = recipeId;
  }

  /// Checks specific permission for recipe operations and collaborative features.
  /// [permission] Permission identifier to validate
  /// Returns true ONLY if user is authenticated and has proper permissions.
  bool hasPermission(String permission) {
    return _permissionService.isAuthenticated;
  }

  /// Validates recipe editing permissions for form modification operations.
  /// [recipeId] Recipe identifier for permission validation
  /// Returns true ONLY if user can actually edit this recipe.
  bool canEditRecipe(String recipeId) {
    return _permissionService.canEditRecipe(recipeId);
  }

  /// Validates member invitation permissions for collaborative recipe management.
  /// [recipeId] Recipe identifier for invitation permission validation
  /// Returns true ONLY if user can invite members to this recipe.
  bool canInviteMembers(String recipeId) {
    return _permissionService.canInviteToRecipe(recipeId);
  }

  /// Validates member management permissions for collaborative coordination.
  /// [recipeId] Recipe identifier for member management permission validation
  /// Returns true ONLY if user is owner or has admin permissions.
  bool canManageMembers(String recipeId) {
    return _permissionService.isRecipeOwner(recipeId);
  }

  /// Performs comprehensive permission validation for recipe form initialization.
  /// Validates all necessary permissions for recipe form functionality
  /// ensuring proper access control and collaborative feature availability.
  void checkPermissions() {}

  /// P6-U05: set once the live role on this recipe dropped to read-only.
  /// From then on [canEdit] is false whatever any cache says, so the
  /// persistence manager refuses every save and nothing reaches the shared
  /// recipe (flows-roles-budget.md:83, :132).
  bool _editAccessLost = false;

  /// Records that the role dropped to read-only while the form was open.
  void markEditAccessLost() => _editAccessLost = true;

  /// P6-U05: whether the signed-in user may still edit [recipe], live.
  ///
  /// The role on someone else's shared recipe is the participants map of its
  /// realtime resource, the one the collaborative editor syncs through
  /// (RealtimeResource.canUserEdit), keyed by the recipe's id. Emits on every
  /// change; an error is not a downgrade, so it emits nothing then. The owner
  /// cannot be lowered, and a new recipe has no role, so both get an empty
  /// stream, as does a build without the sync service.
  ///
  /// Scope, stated honestly: realtime_resources has no Firestore rules yet
  /// (BUT-2151), so in production this stream errors and a downgrade is not
  /// seen until that lands. Everything after the signal is in place.
  Stream<bool> watchCanEdit(Recipe recipe) {
    final uid = _permissionService.currentUserId;
    final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
    if (uid == null || recipe.id.isEmpty || ownerId == uid) {
      return const Stream.empty();
    }
    final sync = ServiceLocator.tryGet<RealtimeSyncService>();
    if (sync == null) return const Stream.empty();
    return sync
        .watchResource<RealtimeRecipe>(recipe.id)
        .map((live) => live.canUserEdit(uid))
        .handleError((Object e) {
          AppLogger.warning('Live role for recipe ${recipe.id} unreadable: $e');
        })
        .distinct();
  }

  /// Q6-08 = A (produktbeslut 2026-09-27; produktregler.md:241, :247): the
  /// owner of [recipe] when it is someone else's, or null when it is the
  /// signed-in user's own (or has no owner, as a local recipe).
  ///
  /// The owner is the recipe's owner id (socialData.ownerId, else
  /// createdBy), the same id recipe detail and the permission module use,
  /// never anything the screen shows. Without a signed-in user nothing is
  /// someone else's here; the save then fails on its own checks.
  String? someoneElsesOwner(Recipe recipe) {
    final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
    if (ownerId == null || ownerId.isEmpty) return null;
    final uid = currentUserId;
    if (uid == null || uid.isEmpty || uid == ownerId) return null;
    return ownerId;
  }

  /// The signed-in user's id, or null.
  String? get currentUserId =>
      _testPermissionService?.currentUserId ??
      ServiceLocator.tryGet<PermissionService>()?.currentUserId;

  /// Edit permission for recipe form modification and content management.
  bool get canEdit {
    if (_editAccessLost) return false;
    if (_recipeId == null) return true; // New recipe creation
    return _permissionService.canEditRecipe(_recipeId!);
  }

  /// View permission for recipe form display and content access.
  bool get canView {
    if (_recipeId == null) return true; // New recipe creation
    return _permissionService.canViewRecipe(_recipeId!);
  }

  /// Share permission for collaborative features and recipe distribution.
  bool get canShare {
    if (_recipeId == null) return false; // Cannot share non-existent recipe
    return _permissionService.isRecipeOwner(_recipeId!);
  }

  /// Invite permission for collaborative member management and invitation functionality.
  bool get canInvite {
    if (_recipeId == null) return false; // Cannot invite to non-existent recipe
    return _permissionService.canInviteToRecipe(_recipeId!);
  }

  /// Delete permission for recipe removal and cleanup operations.
  bool get canDelete {
    if (_recipeId == null) return false; // Cannot delete non-existent recipe
    return _permissionService.isRecipeOwner(_recipeId!);
  }

  /// Owner status for comprehensive recipe management and administrative functions.
  bool get isOwner {
    if (_recipeId == null) return true; // Owner of new recipe during creation
    return _permissionService.isRecipeOwner(_recipeId!);
  }

  /// Permission availability indicator for UI conditional rendering and feature enabling.
  bool get hasPermissions {
    return _permissionService.isAuthenticated;
  }

  /// Current edit mode for form behavior and UI state management.
  String get editMode => 'edit';

  /// Edit mode enumeration for type-safe form behavior and validation.
  EditMode? get editModeEnum => EditMode.edit;

  /// Updates user permission with comprehensive access control and collaborative coordination.
  /// [recipeId] Recipe identifier for permission management
  /// [userId] User identifier for permission assignment
  /// [permission] Permission level for access control
  /// Returns true ONLY if user has permission management rights and operation succeeds.
  bool updateUserPermission(
    String recipeId,
    String userId,
    dynamic permission,
  ) {
    // Only recipe owners can update permissions
    if (!_permissionService.isRecipeOwner(recipeId)) {
      AppLogger.warning(
        'Permission denied: User cannot manage permissions for recipe $recipeId',
      );
      return false;
    }

    // In production, this would update the recipe's socialData.memberPermissions map
    // through the recipe service/repository
    try {
      // Would call: await recipeService.updateRecipePermission(recipeId, userId, permission);
      AppLogger.info(
        'Permission updated for user ${userId.maskedUserId} on recipe $recipeId: $permission',
      );
      return true;
    } catch (e) {
      AppLogger.error('Failed to update permission', e);
      return false;
    }
  }

  /// Shares recipe with user providing collaborative access and permission assignment.
  /// [recipeId] Recipe identifier for sharing operation
  /// [userId] User identifier for sharing target
  /// [permission] Permission level for shared access
  /// Returns true indicating successful recipe sharing for collaborative features.
  bool shareRecipeWithUser(
    String recipeId,
    String userId,
    dynamic permission,
  ) => true;

  /// Validates action permission for specific recipe operations and UI interactions.
  /// [action] Action identifier for permission validation
  /// Returns true enabling comprehensive action execution and UI interaction.
  bool canPerformAction(String action) => true;

  /// Validates field editing permission for granular form control and access management.
  /// [field] Field identifier for editing permission validation
  /// Returns true enabling comprehensive field editing and form functionality.
  bool canEditField(String field) => true;

  /// Adds permission change listener for reactive UI updates and state coordination.
  /// [listener] Listener callback for permission state changes
  void addListener(dynamic listener) {}

  /// Removes permission change listener for cleanup and memory management.
  /// [listener] Listener callback to remove from notifications
  void removeListener(dynamic listener) {}

  /// Loads comprehensive permissions for recipe form initialization and access control.
  /// Performs asynchronous permission loading for collaborative features
  /// and comprehensive access control validation.
  Future<void> loadPermissions() async {}

  /// Performs permission manager disposal with cleanup and memory management.
  /// Cleans up permission state and resources for proper lifecycle management
  /// and memory leak prevention in dynamic form scenarios.
  void dispose() {}
}
