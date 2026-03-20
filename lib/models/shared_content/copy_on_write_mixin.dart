import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/shared_content/base_shared_content_model.dart';

/// Mixin providing copy-on-write collaboration support for shared content.
mixin CopyOnWriteSupport<TContent> on BaseSharedContentModel<TContent> {
  bool get isOriginalReference;
  bool get copyOnWriteTriggered;
  String? get originalOwnerStaticCopyId;
  int get activeCollaboratorCount;

  BaseSharedContentModel<TContent> triggerCopyOnWrite({
    required String editingUserId,
    required String staticCopyId,
  });

  BaseSharedContentModel<TContent> addActiveCollaborator(String userId);

  bool get isCollaborative => copyOnWriteTriggered;

  String get editingMode {
    if (copyOnWriteTriggered) {
      return 'collaborative';
    } else if (isOriginalReference) {
      return 'original_reference';
    } else {
      return 'unknown';
    }
  }

  bool get hasActiveCollaborators => activeCollaboratorCount > 0;

  /// Collaboration statistics for analytics.
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

  /// Swedish collaboration status summary for UI.
  String getCollaborationSummary() {
    if (!_allowsCollaboration()) {
      return AppLocale.current.collaborationNotAllowed;
    }

    if (!copyOnWriteTriggered) {
      return AppLocale.current.collaborationReady;
    }

    if (activeCollaboratorCount == 0) {
      return AppLocale.current.collaborationVersionCreated;
    } else if (activeCollaboratorCount == 1) {
      return AppLocale.current.collaborationOneActive;
    } else {
      return AppLocale.current
          .collaborationMultipleActive(activeCollaboratorCount);
    }
  }

  /// Copy-on-write fields for Firestore.
  Map<String, dynamic> getCopyOnWriteFirestoreFields() {
    return {
      'isOriginalReference': isOriginalReference,
      'copyOnWriteTriggered': copyOnWriteTriggered,
      'originalOwnerStaticCopyId': originalOwnerStaticCopyId,
      'activeCollaboratorCount': activeCollaboratorCount,
    };
  }

  /// Copy-on-write fields for JSON.
  Map<String, dynamic> getCopyOnWriteJsonFields() {
    return {
      'isOriginalReference': isOriginalReference,
      'copyOnWriteTriggered': copyOnWriteTriggered,
      'originalOwnerStaticCopyId': originalOwnerStaticCopyId,
      'activeCollaboratorCount': activeCollaboratorCount,
    };
  }

  static Map<String, dynamic> parseCopyOnWriteFieldsFromFirestore(
      Map<String, dynamic> data) {
    return {
      'isOriginalReference': SerializationUtils.safeBool(data, 'isOriginalReference', defaultValue: true),
      'copyOnWriteTriggered': SerializationUtils.safeBool(data, 'copyOnWriteTriggered'),
      'originalOwnerStaticCopyId': SerializationUtils.safeNullableString(data, 'originalOwnerStaticCopyId'),
      'activeCollaboratorCount': SerializationUtils.safeInt(data, 'activeCollaboratorCount'),
    };
  }

  static Map<String, dynamic> parseCopyOnWriteFieldsFromJson(
      Map<String, dynamic> json) {
    return {
      'isOriginalReference': SerializationUtils.safeBool(json, 'isOriginalReference', defaultValue: true),
      'copyOnWriteTriggered': SerializationUtils.safeBool(json, 'copyOnWriteTriggered'),
      'originalOwnerStaticCopyId': SerializationUtils.safeNullableString(json, 'originalOwnerStaticCopyId'),
      'activeCollaboratorCount': SerializationUtils.safeInt(json, 'activeCollaboratorCount'),
    };
  }

  /// Override in content models to control collaboration behavior.
  bool _allowsCollaboration();

  /// Check if copy-on-write can be triggered.
  bool canTriggerCopyOnWrite() {
    return !copyOnWriteTriggered && _allowsCollaboration();
  }

  /// Determine next collaboration action for a user.
  String getNextCollaborationAction(String userId) {
    if (!_allowsCollaboration()) {
      return 'view';
    }

    if (sharedByUserId == userId) {
      return copyOnWriteTriggered ? 'edit_collaborative' : 'edit_original';
    }

    if (!copyOnWriteTriggered) {
      return 'trigger_collaboration';
    }

    return hasActiveCollaborators ? 'join_collaboration' : 'edit_collaborative';
  }
}
