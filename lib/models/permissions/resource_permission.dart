/// Comprehensive resource permission enumeration providing hierarchical access control for collaborative content management.
///
/// This enumeration implements sophisticated permission management following Single Responsibility Principle,
/// handling all aspects of resource access control including viewing, editing, ownership, and administrative
/// privileges. It provides comprehensive permission classification while maintaining clean separation from
/// content management and permission validation logic.
///
/// **Single Responsibility Focus:**
/// This enumeration exclusively handles resource permission classification and hierarchy:
/// - **Hierarchical Access Control**: Structured permission levels from basic viewing to full administrative control
/// - **Modern Permission System**: Contemporary viewer/editor/owner model with intuitive permission mapping
/// - **Legacy Compatibility**: Backward compatibility with read/write/admin permission systems for migration support
/// - **Permission Validation**: Built-in capability checking for common permission operations and access control
///
/// **What This Enumeration Does NOT Handle:**
/// - Permission validation and enforcement logic (handled by permission services and validators)
/// - User management and authentication (handled by user services and authentication systems)
/// - Resource-specific business logic (handled by content services and domain models)
/// - UI implementation and presentation logic (handled by ViewModels and UI components)
///
/// **Resource Permission Features:**
/// - **Hierarchical Structure**: Clear permission hierarchy with escalating privileges and capability inheritance
/// - **Modern Permission Model**: Intuitive viewer/editor/owner classification aligned with contemporary collaboration patterns
/// - **Legacy Support**: Complete backward compatibility with traditional read/write/admin permission systems
/// - **Built-in Validation**: Comprehensive capability checking methods for streamlined permission validation
/// - **Display Integration**: User-friendly display names for UI integration and permission communication
///
/// **Usage Examples:**
/// ```dart
/// // Check permission capabilities
/// final permission = ResourcePermission.editor;
/// if (permission.canEdit) {
///   enableEditingFeatures();
/// }
/// 
/// // Permission hierarchy validation
/// final userPermission = getUserPermission(userId, resourceId);
/// final requiredPermission = ResourcePermission.editor;
/// if (ResourcePermissionHelper.canEditContent(userPermission, requiredPermission)) {
///   allowContentModification();
/// }
/// 
/// // Permission comparison and hierarchy
/// final permissions = [ResourcePermission.viewer, ResourcePermission.owner, ResourcePermission.editor];
/// final highest = ResourcePermissionHelper.getHighest(permissions); // Returns owner
/// 
/// // Legacy permission migration
/// final legacyPermission = 'write';
/// final modernPermission = ResourcePermissionHelper.fromString(legacyPermission); // Returns editor
/// 
/// // Display permission information
/// showPermissionStatus(permission.displayName); // "Editor"
/// ```

// Consolidated permission models - ResourcePermission enum

/// Enumeration defining hierarchical resource permissions for collaborative content access control.
///
/// Provides comprehensive permission classification with modern viewer/editor/owner model,
/// legacy compatibility, and built-in capability validation for streamlined access management.
enum ResourcePermission {
  /// View-only permission allowing content consumption without modification capabilities.
  ///
  /// Users can view and consume content but cannot make any modifications or administrative changes.
  viewer,
  
  /// Edit permission allowing content modification while preserving ownership restrictions.
  ///
  /// Users can modify content and perform editing operations but cannot manage permissions or ownership.
  editor,
  
  /// Full ownership permission with complete control over content and permission management.
  ///
  /// Content owners have full privileges including editing, permission management, and administrative control.
  owner,
  
  /// Legacy permission levels maintained for backward compatibility with existing systems.
  
  /// Legacy read permission equivalent to viewer for backward compatibility.
  ///
  /// Maintained for migration support from traditional read/write permission systems.
  read,
  
  /// Legacy write permission equivalent to editor for backward compatibility.
  ///
  /// Maintained for migration support from traditional read/write permission systems.
  write,
  
  /// Legacy administrative permission with highest privilege level for backward compatibility.
  ///
  /// Maintained for migration support from traditional administrative permission systems.
  admin;

  /// Permission capability checking methods for access control validation.

  /// Checks if this permission level allows content editing operations.
  ///
  /// Returns true for editor, owner, write, and admin permissions that enable content modification.
  /// Used for validating editing capabilities and enabling/disabling editing UI elements.
  bool get canEdit => this == editor || this == owner || this == write || this == admin;

  /// Checks if this permission level allows ownership and administrative actions.
  ///
  /// Returns true for owner and admin permissions that enable permission management,
  /// content deletion, and administrative operations. Used for administrative UI control.
  bool get canOwn => this == owner || this == admin;

  /// Checks if this permission level allows content viewing operations.
  ///
  /// Returns true for all permission levels as viewing is the minimum capability.
  /// All users with any permission level can view content, making this universally true.
  bool get canView => true; // All permission levels can view

  /// Gets the user-friendly display name for this permission level.
  ///
  /// Provides intuitive permission names for UI display, user communication, and
  /// permission selection interfaces with clear hierarchical understanding.
  ///
  /// Returns capitalized permission name suitable for user interface display.
  String get displayName {
    switch (this) {
      case ResourcePermission.viewer:
        return 'Viewer';
      case ResourcePermission.editor:
        return 'Editor';
      case ResourcePermission.owner:
        return 'Owner';
      case ResourcePermission.read:
        return 'Read';
      case ResourcePermission.write:
        return 'Write';
      case ResourcePermission.admin:
        return 'Admin';
    }
  }
}

/// Comprehensive helper class providing advanced operations for ResourcePermission management and validation.
///
/// This helper class implements sophisticated permission utility methods following Single Responsibility Principle,
/// handling permission conversion, hierarchy validation, comparison operations, and migration support. It provides
/// comprehensive permission management utilities while maintaining clean separation from core permission logic.
///
/// **Helper Class Features:**
/// - **Permission Conversion**: String-to-enum conversion with case-insensitive parsing and fallback handling
/// - **Hierarchy Management**: Permission comparison, ranking, and highest permission determination
/// - **Legacy Migration**: Seamless conversion between legacy and modern permission systems
/// - **Validation Utilities**: Permission capability validation and requirement checking
/// - **Default Creation**: Standard permission map generation for resource initialization
class ResourcePermissionHelper {
  /// Permission conversion methods for string-to-enum mapping and legacy migration support.

  /// Converts string permission level to ResourcePermission enum with case-insensitive parsing.
  ///
  /// Provides robust string-to-permission conversion with comprehensive mapping for both modern
  /// and legacy permission systems. Includes fallback to viewer permission for unknown values
  /// ensuring system stability and graceful degradation.
  ///
  /// [permission] String representation of the permission level (case-insensitive)
  ///
  /// Returns corresponding [ResourcePermission] enum value with viewer fallback for unknown strings.
  static ResourcePermission fromString(String permission) {
    switch (permission.toLowerCase()) {
      case 'viewer':
        return ResourcePermission.viewer;
      case 'editor':
        return ResourcePermission.editor;
      case 'owner':
        return ResourcePermission.owner;
      case 'read':
        return ResourcePermission.read;
      case 'write':
        return ResourcePermission.write;
      case 'admin':
        return ResourcePermission.admin;
      default:
        return ResourcePermission.viewer;
    }
  }

  /// Converts ResourcePermission enum to string representation for serialization.
  ///
  /// Provides simple enum-to-string conversion for database storage, API communication,
  /// and serialization operations with consistent naming conventions.
  ///
  /// Returns the enum name as a string for serialization and storage purposes.
  static String permissionToName(ResourcePermission permission) {
    return permission.name;
  }

  /// Permission hierarchy and comparison methods for advanced permission validation.

  /// Checks if one permission level is higher than another in the permission hierarchy.
  ///
  /// Implements comprehensive permission hierarchy comparison with support for both modern
  /// and legacy permission systems. Uses numerical hierarchy mapping for reliable comparison
  /// across different permission models.
  ///
  /// Returns true if permission [a] has higher privileges than permission [b].
  static bool isHigherThan(ResourcePermission a, ResourcePermission b) {
    const hierarchy = {
      ResourcePermission.read: 1,
      ResourcePermission.viewer: 1,
      ResourcePermission.write: 2,
      ResourcePermission.editor: 2,
      ResourcePermission.owner: 3,
      ResourcePermission.admin: 4,
    };
    
    return (hierarchy[a] ?? 0) > (hierarchy[b] ?? 0);
  }

  /// Determines the highest permission level from a list of permissions.
  ///
  /// Analyzes a collection of permissions and returns the one with the highest privilege level
  /// according to the permission hierarchy. Uses hierarchical comparison to ensure accurate
  /// highest permission determination across mixed modern and legacy permission types.
  ///
  /// Returns the permission with the highest privilege level, or viewer if list is empty.
  static ResourcePermission getHighest(List<ResourcePermission> permissions) {
    if (permissions.isEmpty) return ResourcePermission.viewer;
    
    return permissions.reduce((a, b) => isHigherThan(a, b) ? a : b);
  }

  /// Utility methods for permission management and validation operations.

  /// Creates a default permissions map with owner having administrative privileges.
  ///
  /// Generates a standard permission mapping for new resources with the specified owner
  /// receiving admin privileges. Used for initializing permission structures for new content.
  ///
  /// Returns a permissions map with the owner having administrative access.
  static Map<String, ResourcePermission> createDefault(String ownerId) {
    return {ownerId: ResourcePermission.admin};
  }

  /// Converts permission to string representation (legacy compatibility method).
  ///
  /// Provides backward compatibility for legacy code that expects string-based permission handling.
  /// Maintained for migration support and gradual modernization of permission systems.
  ///
  /// Returns the permission name as a string for legacy system compatibility.
  static String permissionToString(ResourcePermission permission) {
    return permission.name;
  }

  /// Checks if the specified permission level allows permission management operations.
  ///
  /// Validates whether a user with the given permission can manage other users' permissions,
  /// add/remove members, and perform administrative operations on the resource.
  ///
  /// Returns true if the permission allows administrative and permission management operations.
  static bool canManagePermissions(ResourcePermission permission) {
    return permission == ResourcePermission.admin || permission == ResourcePermission.owner;
  }

  /// Validates if user permission meets or exceeds the required permission level for content editing.
  ///
  /// Implements comprehensive permission validation by comparing user permission against required
  /// permission level using hierarchical comparison. Enables flexible content access control
  /// with support for both exact matches and hierarchical privilege inheritance.
  ///
  /// [userPermission] The permission level held by the user attempting the operation
  /// [requiredPermission] The minimum permission level required for the operation
  ///
  /// Returns true if the user permission meets or exceeds the required permission level.
  static bool canEditContent(ResourcePermission userPermission, ResourcePermission requiredPermission) {
    return isHigherThan(userPermission, requiredPermission) || userPermission == requiredPermission;
  }
}