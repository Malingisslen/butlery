/// Mixin providing copy-on-write collaboration functionality for shared content models.
///
/// This mixin implements TRUE copy-on-write behavior where users initially view the original
/// content and only on first edit attempt is a static copy created for the original owner
/// while the shared version becomes collaborative. This eliminates duplication between
/// SharedRecipe and SharedMenu while providing standardized CoW functionality.
///
/// **Copy-on-Write Behavior:**
/// 1. **Initial State**: Users view original content (isOriginalReference: true)
/// 2. **First Edit**: Static copy created for owner, shared version becomes collaborative
/// 3. **Collaborative Mode**: Multiple users can edit the shared collaborative version
///
/// **Eliminated Duplication:**
/// - CoW fields (isOriginalReference, copyOnWriteTriggered, etc.) - identical implementations
/// - triggerCopyOnWrite() method - 100% identical logic
/// - addActiveCollaborator() method - identical user management
/// - canBeEditedBy() method - identical permission logic
///
/// **Benefits:**
/// - **Unified CoW Logic**: Single implementation for recipes and menus
/// - **Extensible**: Shopping lists can opt-in to CoW collaboration
/// - **Type Safety**: Generic implementation works with any content type
/// - **Code Reduction**: ~80 lines of duplicate CoW code eliminated
///
/// **Usage:**
/// ```dart
/// class SharedRecipe extends BaseSharedContentModel<Recipe> 
///     with SharedContentStatusMixin, CopyOnWriteSupport {
///   
///   // CoW functionality automatically available
///   final collaborative = recipe.triggerCopyOnWrite(
///     editingUserId: userId,
///     staticCopyId: copyId,
///   );
/// }
/// ```

// lib/models/shared_content/copy_on_write_mixin.dart

import 'package:butlery/models/shared_content/base_shared_content_model.dart';

/// Mixin providing copy-on-write collaboration support for shared content.
/// 
/// Implements TRUE copy-on-write where users view original content until first edit
/// triggers creation of a static copy for the owner and collaborative version for others.
mixin CopyOnWriteSupport<TContent> on BaseSharedContentModel<TContent> {
  
  // ===== COPY-ON-WRITE FIELDS =====
  
  /// Indicates if this shared content still references the original content.
  /// 
  /// When true, users view the original content until first edit triggers copy creation.
  /// When false, this represents a collaborative version that has been copied.
  bool get isOriginalReference;
  
  /// Indicates if copy-on-write has been triggered for this shared content.
  /// 
  /// When true, a static copy has been created for the original owner and this
  /// shared version is now collaborative.
  bool get copyOnWriteTriggered;
  
  /// ID of the static copy created for the original owner when CoW triggered.
  /// 
  /// This copy preserves the original content state for the owner while the shared
  /// version becomes collaborative.
  String? get originalOwnerStaticCopyId;
  
  /// List of user IDs actively collaborating on this shared content.
  /// 
  /// Only populated after copy-on-write is triggered and users join collaboration.
  List<String> get activeCollaboratorIds;

  // ===== COPY-ON-WRITE OPERATIONS =====
  
  /// Triggers copy-on-write for this shared content.
  /// 
  /// This method converts the shared content from original reference mode to
  /// collaborative mode by:
  /// 1. Creating a static copy for the original owner
  /// 2. Marking the shared version as collaborative
  /// 3. Adding the editing user as an active collaborator
  /// 
  /// [editingUserId] User who triggered the copy-on-write
  /// [staticCopyId] ID of the static copy created for original owner
  /// 
  /// Returns updated content in collaborative mode.
  BaseSharedContentModel<TContent> triggerCopyOnWrite({
    required String editingUserId,
    required String staticCopyId,
  });
  
  /// Adds a user as an active collaborator to this shared content.
  /// 
  /// This method adds a new user to the active collaborators list for
  /// collaborative editing. Prevents duplicate entries.
  /// 
  /// [userId] User to add as collaborator
  /// 
  /// Returns updated content with new collaborator added.
  BaseSharedContentModel<TContent> addActiveCollaborator(String userId);
  
  /// Checks if a user can edit this shared content.
  /// 
  /// Edit permissions are granted to:
  /// - Original owner (always can edit)
  /// - Active collaborators (after CoW is triggered)
  /// - Shared recipients (if collaboration is allowed and CoW not triggered)
  /// 
  /// [userId] User to check edit permissions for
  /// 
  /// Returns true if user can edit the content.
  bool canBeEditedBy(String userId) {
    // Original owner can always edit
    if (sharedByUserId == userId) return true;
    
    // If CoW is triggered, only active collaborators can edit
    if (copyOnWriteTriggered) {
      return activeCollaboratorIds.contains(userId);
    }
    
    // Before CoW, check if content allows collaboration and user is recipient
    return _allowsCollaboration() && sharedToUserIds.contains(userId);
  }

  // ===== COPY-ON-WRITE STATUS METHODS =====
  
  /// Returns true if this content is in collaborative mode.
  /// 
  /// A content is collaborative if copy-on-write has been triggered,
  /// indicating that active collaboration is taking place.
  bool get isCollaborative => copyOnWriteTriggered;
  
  /// Returns the current editing mode for this shared content.
  /// 
  /// - Original reference: Users view original until first edit
  /// - Collaborative: Users collaborate on shared version after CoW
  String get editingMode {
    if (copyOnWriteTriggered) {
      return 'collaborative';
    } else if (isOriginalReference) {
      return 'original_reference';
    } else {
      return 'unknown';
    }
  }
  
  /// Check if user is an active collaborator
  bool isActiveCollaborator(String userId) {
    return activeCollaboratorIds.contains(userId);
  }
  
  /// Get count of active collaborators
  int get activeCollaboratorCount => activeCollaboratorIds.length;
  
  /// Check if content has any active collaborators
  bool get hasActiveCollaborators => activeCollaboratorIds.isNotEmpty;

  // ===== COLLABORATION ANALYTICS =====
  
  /// Get collaboration statistics for this content
  Map<String, dynamic> getCollaborationAnalytics() {
    return {
      'isCollaborative': isCollaborative,
      'editingMode': editingMode,
      'activeCollaboratorCount': activeCollaboratorCount,
      'hasStaticCopy': originalOwnerStaticCopyId != null,
      'allowsCollaboration': _allowsCollaboration(),
      'isOriginalReference': isOriginalReference,
    };
  }
  
  /// Get collaboration status summary for UI display
  String getCollaborationSummary() {
    if (!_allowsCollaboration()) {
      return 'Ingen kollaboration tillåten';
    }
    
    if (!copyOnWriteTriggered) {
      return 'Redo för kollaboration';
    }
    
    if (activeCollaboratorCount == 0) {
      return 'Kollaborativ version skapad';
    } else if (activeCollaboratorCount == 1) {
      return '1 aktiv kollaboratör';
    } else {
      return '$activeCollaboratorCount aktiva kollaboratörer';
    }
  }

  // ===== COPY-ON-WRITE SERIALIZATION HELPERS =====
  
  /// Get copy-on-write fields for Firestore serialization
  Map<String, dynamic> getCopyOnWriteFirestoreFields() {
    return {
      'isOriginalReference': isOriginalReference,
      'copyOnWriteTriggered': copyOnWriteTriggered,
      'originalOwnerStaticCopyId': originalOwnerStaticCopyId,
      'activeCollaboratorIds': activeCollaboratorIds,
    };
  }
  
  /// Get copy-on-write fields for JSON serialization
  Map<String, dynamic> getCopyOnWriteJsonFields() {
    return {
      'isOriginalReference': isOriginalReference,
      'copyOnWriteTriggered': copyOnWriteTriggered,
      'originalOwnerStaticCopyId': originalOwnerStaticCopyId,
      'activeCollaboratorIds': activeCollaboratorIds,
    };
  }
  
  /// Parse copy-on-write fields from Firestore data
  static Map<String, dynamic> parseCopyOnWriteFieldsFromFirestore(Map<String, dynamic> data) {
    return {
      'isOriginalReference': data['isOriginalReference'] as bool? ?? true,
      'copyOnWriteTriggered': data['copyOnWriteTriggered'] as bool? ?? false,
      'originalOwnerStaticCopyId': data['originalOwnerStaticCopyId'] as String?,
      'activeCollaboratorIds': List<String>.from(data['activeCollaboratorIds'] ?? []),
    };
  }
  
  /// Parse copy-on-write fields from JSON data
  static Map<String, dynamic> parseCopyOnWriteFieldsFromJson(Map<String, dynamic> json) {
    return {
      'isOriginalReference': json['isOriginalReference'] as bool? ?? true,
      'copyOnWriteTriggered': json['copyOnWriteTriggered'] as bool? ?? false,
      'originalOwnerStaticCopyId': json['originalOwnerStaticCopyId'] as String?,
      'activeCollaboratorIds': List<String>.from(json['activeCollaboratorIds'] ?? []),
    };
  }

  // ===== ABSTRACT METHODS FOR CONTENT-SPECIFIC CUSTOMIZATION =====
  
  /// Check if this content type allows collaboration.
  /// 
  /// Override in specific content models to control collaboration behavior:
  /// - SharedRecipe/SharedMenu: Usually true (supports CoW)
  /// - SharedShoppingList: Could be true or false based on list type
  bool _allowsCollaboration();

  // ===== CONVENIENCE METHODS =====
  
  /// Check if copy-on-write can be triggered for this content
  bool canTriggerCopyOnWrite(String userId) {
    // CoW can only be triggered if:
    // 1. Not already triggered
    // 2. User has edit permissions
    // 3. Content allows collaboration
    return !copyOnWriteTriggered && 
           canBeEditedBy(userId) && 
           _allowsCollaboration();
  }
  
  /// Get next action user should take for collaboration
  String getNextCollaborationAction(String userId) {
    if (!_allowsCollaboration()) {
      return 'view'; // Can only view non-collaborative content
    }
    
    if (sharedByUserId == userId) {
      return copyOnWriteTriggered ? 'edit_collaborative' : 'edit_original';
    }
    
    if (!copyOnWriteTriggered) {
      return 'trigger_collaboration'; // First edit will trigger CoW
    }
    
    if (activeCollaboratorIds.contains(userId)) {
      return 'edit_collaborative';
    }
    
    return 'join_collaboration';
  }
}