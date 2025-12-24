/// Comprehensive edit mode enumeration providing granular access control for content editing operations.
/// This enumeration implements sophisticated editing permission management following Single Responsibility Principle,
/// handling all aspects of content access control including ownership-based editing, collaborative features,
/// read-only access with fork capabilities, and complete access denial. It provides comprehensive editing
/// permission control while maintaining clean separation from content management and UI concerns.
/// **Single Responsibility Focus:**
/// This enumeration exclusively handles edit mode classification and permissions:
/// - **Ownership-Based Editing**: Full editing rights for content owners with original content modification
/// - **Collaborative Editing**: Multi-user editing with synchronized changes and conflict resolution
/// - **Read-Only with Fork**: View-only access with copy/fork capabilities for independent editing
/// - **Access Control**: Complete access management including no-access restrictions
/// **What This Enumeration Does NOT Handle:**
/// - Content editing operations and business logic (handled by content services and editors)
/// - UI implementation and presentation logic (handled by ViewModels and UI components)
/// - Permission validation and enforcement (handled by permission services and validators)
/// - Content persistence and storage operations (handled by repositories and services)
/// **Edit Mode Features:**
/// - **Hierarchical Permissions**: Structured permission levels from full ownership to no access
/// - **Collaborative Support**: Advanced multi-user editing with synchronized collaborative features
/// - **Fork Capabilities**: Independent copy creation for users without direct editing permissions
/// - **Swedish Localization**: Complete Swedish language support for permission descriptions and UI text
/// - **Extension Support**: Comprehensive extension methods for permission checking and UI state management
/// **Usage Examples:**
/// ```dart
/// // Check editing permissions
/// final mode = getEditModeForUser(userId, contentId);
/// if (mode.canEdit) {
///   // Allow editing operations
///   showEditInterface();
/// }
/// // Show appropriate UI elements
/// if (mode.showForkButton) {
///   showForkButton(); // Display "Spara min kopia" button
/// }
/// // Display permission status
/// showPermissionText(mode.description); // "Du äger detta recept"
/// // Permission-based routing
/// switch (mode) {
///   case EditMode.owner:
///     navigateToOwnerEditor();
///     break;
///   case EditMode.collaborative:
///     navigateToCollaborativeEditor();
///     break;
///   case EditMode.readOnlyWithFork:
///     navigateToReadOnlyViewer();
///     break;
///   case EditMode.noAccess:
///     showAccessDeniedMessage();
///     break;
/// }
/// ```

// lib/models/permissions/edit_mode.dart

/// Enumeration defining edit modes for granular content access control and permission management.
/// Provides comprehensive editing permission classification with hierarchical access levels,
/// collaborative features, and Swedish-localized permission descriptions for optimal user experience.
enum EditMode {
  /// Full ownership mode with complete editing rights for original content modification.
  /// Content owners can always edit the original content with all privileges and administrative control.
  owner, // Äger receptet - kan alltid redigera original

  /// Collaborative editing mode with synchronized multi-user editing capabilities.
  /// Multiple users can edit simultaneously with changes synchronized across all collaborative editors.
  collaborative, // Kollaborativ redigering - ändringar synkas

  /// Read-only mode with fork/copy capabilities for independent content creation.
  /// Users can view content and create their own independent copies but cannot modify the original.
  readOnlyWithFork, // Bara läsning + "Spara min kopia"

  /// No access mode with complete content access restriction.
  /// Users have no access to view or interact with the content in any way.
  noAccess, // Ingen åtkomst

  /// Standard edit mode with basic editing permissions for general content modification.
  /// Provides standard editing capabilities without collaborative features or ownership privileges.
  edit, // Standard edit mode

  /// Standard view mode with read-only access without fork capabilities.
  /// Users can view content but cannot edit or create copies, suitable for public content display.
  view, // Standard view mode
}

/// Extension methods for EditMode providing comprehensive permission checking and UI state management.
/// This extension provides convenient methods for permission validation, UI state determination,
/// and Swedish-localized descriptions for optimal user experience and clean permission handling.
extension EditModeExtension on EditMode {
  /// Checks if the current edit mode allows content editing operations.
  /// Returns true for ownership, collaborative, and standard edit modes that permit content modification.
  /// Used for enabling/disabling editing UI elements and validating editing permissions.
  bool get canEdit =>
      this == EditMode.owner ||
      this == EditMode.collaborative ||
      this == EditMode.edit;

  /// Checks if the current edit mode allows content forking/copying operations.
  /// Returns true for all modes except noAccess, allowing users to create independent copies
  /// of content even when they cannot edit the original. Used for fork/copy functionality.
  bool get canFork => this != EditMode.noAccess;

  /// Determines if the fork button should be displayed in the UI for content duplication.
  /// Returns true for read-only modes with fork capabilities and collaborative modes where
  /// users might want to create independent copies. Used for UI element visibility control.
  bool get showForkButton =>
      this == EditMode.readOnlyWithFork || this == EditMode.collaborative;

  /// Gets the Swedish-localized description text for the current edit mode.
  /// Provides user-friendly Swedish descriptions explaining the current permission level
  /// and available actions for optimal user experience and clear permission communication.
  /// Returns Swedish description text appropriate for UI display and user guidance.
  String get description {
    switch (this) {
      case EditMode.owner:
        return 'Du äger detta recept';
      case EditMode.collaborative:
        return 'Du redigerar tillsammans med andra';
      case EditMode.readOnlyWithFork:
        return 'Skrivskyddat - du kan spara din egen kopia';
      case EditMode.noAccess:
        return 'Ingen åtkomst';
      case EditMode.edit:
        return 'Redigeringsläge';
      case EditMode.view:
        return 'Visningsläge';
    }
  }
}
