// lib/models/permissions/resource_permission.dart


/// Behörighetstyper för realtidsresurser
enum ResourcePermission {
  /// Äger resursen - kan göra allt
  owner,

  /// Kan redigera innehåll
  editor,

  /// Kan bara se innehåll
  viewer,
}

/// Helper för ResourcePermission operations
class ResourcePermissionHelper {
  /// Kan användaren redigera innehåll?
  static bool canEditContent(ResourcePermission permission) {
    return permission == ResourcePermission.owner ||
        permission == ResourcePermission.editor;
  }

  /// Kan användaren bjuda in andra?
  static bool canInviteParticipants(ResourcePermission permission) {
    return permission == ResourcePermission.owner;
  }

  /// Kan användaren lämna resursen?
  static bool canLeaveResource(ResourcePermission permission) {
    return permission != ResourcePermission.owner; // Ägare kan inte lämna
  }

  /// Kan användaren ta bort resursen?
  static bool canDeleteResource(ResourcePermission permission) {
    return permission == ResourcePermission.owner;
  }

  /// Kan användaren hantera andra användares behörigheter?
  static bool canManagePermissions(ResourcePermission permission) {
    return permission == ResourcePermission.owner;
  }

  /// Kan användaren arkivera/återaktivera resursen?
  static bool canArchiveResource(ResourcePermission permission) {
    return permission == ResourcePermission.owner;
  }

  /// Konvertera permission till string för serialization
  static String permissionToString(ResourcePermission permission) {
    switch (permission) {
      case ResourcePermission.owner:
        return 'owner';
      case ResourcePermission.editor:
        return 'editor';
      case ResourcePermission.viewer:
        return 'viewer';
    }
  }

  /// Parsa permission från string
  static ResourcePermission fromString(String value) {
    switch (value) {
      case 'owner':
        return ResourcePermission.owner;
      case 'editor':
        return ResourcePermission.editor;
      case 'viewer':
        return ResourcePermission.viewer;
      default:
        throw ArgumentError('Okänd ResourcePermission: $value');
    }
  }

  /// Få användarläsbar beskrivning
  static String getDescription(ResourcePermission permission) {
    switch (permission) {
      case ResourcePermission.owner:
        return 'Ägare - kan göra allt';
      case ResourcePermission.editor:
        return 'Redigerare - kan ändra innehåll';
      case ResourcePermission.viewer:
        return 'Betraktare - kan bara se';
    }
  }

  /// Få kort beskrivning för UI
  static String getShortDescription(ResourcePermission permission) {
    switch (permission) {
      case ResourcePermission.owner:
        return 'Ägare';
      case ResourcePermission.editor:
        return 'Redigerare';
      case ResourcePermission.viewer:
        return 'Betraktare';
    }
  }

  /// Få emoji för behörighetstyp
  static String getEmoji(ResourcePermission permission) {
    switch (permission) {
      case ResourcePermission.owner:
        return '👑'; // Krona för ägare
      case ResourcePermission.editor:
        return '✏️'; // Penna för redigerare
      case ResourcePermission.viewer:
        return '👀'; // Ögon för betraktare
    }
  }

  /// Få alla tillgängliga behörigheter som kan tilldelas
  static List<ResourcePermission> getAssignablePermissions() {
    return [
      ResourcePermission.editor,
      ResourcePermission.viewer,
    ]; // Owner kan inte tilldelas, bara ägas
  }

  /// Kontrollera om en behörighet är högre än en annan
  static bool isHigherPermission(
    ResourcePermission permission1,
    ResourcePermission permission2,
  ) {
    const hierarchy = {
      ResourcePermission.viewer: 0,
      ResourcePermission.editor: 1,
      ResourcePermission.owner: 2,
    };

    return (hierarchy[permission1] ?? 0) > (hierarchy[permission2] ?? 0);
  }
}

/// Extension for ResourcePermission to add static method access
extension ResourcePermissionExtension on ResourcePermission {
  /// Static method to check if one permission is higher than another
  static bool isHigherPermission(
    ResourcePermission permission1,
    ResourcePermission permission2,
  ) {
    return ResourcePermissionHelper.isHigherPermission(permission1, permission2);
  }

  /// Få den högsta behörigheten från en lista
  static ResourcePermission getHighestPermission(
    List<ResourcePermission> permissions,
  ) {
    if (permissions.isEmpty) return ResourcePermission.viewer;

    var highest = permissions.first;
    for (final permission in permissions.skip(1)) {
      if (isHigherPermission(permission, highest)) {
        highest = permission;
      }
    }
    return highest;
  }
}
