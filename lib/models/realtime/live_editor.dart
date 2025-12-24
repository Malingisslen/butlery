/// Comprehensive live editor model providing advanced collaborative editing presence and activity tracking.
/// This model implements sophisticated collaborative editing management following Single Responsibility Principle,
/// handling all aspects of live editor presence including activity tracking, field-level editing status,
/// temporal awareness, and comprehensive UI integration. It provides complete collaborative editing infrastructure
/// while maintaining clean separation from resource content and UI presentation concerns.
/// **Single Responsibility Focus:**
/// This model exclusively handles collaborative editor presence and activity management:
/// - **Presence Tracking**: Complete editor activity monitoring with real-time presence detection and timeout handling
/// - **Field-Level Awareness**: Granular editing status tracking for specific resource fields preventing edit conflicts
/// - **Temporal Management**: Advanced activity timeline tracking with last-seen timestamps and activity timeouts
/// - **Status Intelligence**: Smart activity detection with automatic timeout handling and editor state management
/// **What This Model Does NOT Handle:**
/// - Resource content editing and validation (handled by resource-specific services and validation systems)
/// - Real-time synchronization and conflict resolution (handled by collaborative editing services)
/// - UI presentation and interaction handling (handled by ViewModels and UI components)
/// - Editor authentication and permission validation (handled by permission services)
/// **Live Editor Features:**
/// - **Real-Time Presence**: Continuous editor activity monitoring with automatic presence detection and status updates
/// - **Field-Level Granularity**: Specific field editing awareness preventing conflicts and enabling smart conflict resolution
/// - **Activity Intelligence**: Advanced activity detection with configurable timeout periods and editor state transitions
/// - **Temporal Awareness**: Complete activity timeline with last-seen tracking and time-based activity calculations
/// - **Collaborative Integration**: Seamless integration with collaborative editing systems and conflict resolution mechanisms
/// **Usage Examples:**
/// ```dart
/// // Create a new live editor for collaborative editing
/// final editor = LiveEditor(
///   userId: currentUserId,
///   displayName: 'Anna Andersson',
///   lastSeen: DateTime.now(),
///   currentField: 'ingredients[2].name',
///   isActive: true,
/// );
/// // Track editor activity and field changes
/// final updatedEditor = editor.copyWith(
///   lastSeen: DateTime.now(),
///   currentField: 'instructions[0].description',
/// );
/// // Check editor status and activity
/// final isCurrentlyActive = editor.isRecentlyActive();
/// final fieldBeingEdited = editor.currentField;
/// final timeSinceLastSeen = editor.timeSinceLastSeen;
/// // Display editor presence in UI
/// LiveEditorIndicator(
///   editor: editor,
///   showField: editor.currentField != null,
///   isActive: editor.isRecentlyActive(),
/// );
/// // Handle editor timeout
/// if (!editor.isRecentlyActive()) {
///   final inactiveEditor = editor.markInactive();
///   await collaborativeService.updateEditor(inactiveEditor);
/// }
/// ```

// lib/models/realtime/live_editor.dart

import 'package:butlery/core/utils/serialization_utils.dart';

/// Comprehensive live editor model with collaborative presence tracking and field-level editing awareness.
/// Represents an active collaborative editor with complete presence management, activity tracking,
/// and field-specific editing status for advanced collaborative editing features and conflict prevention.
/// This class serves as the foundation for all collaborative editing presence and activity management.
class LiveEditor {
  /// Unique identifier of the user acting as a collaborative editor.
  /// References the user who is actively participating in collaborative editing,
  /// used for editor identification, presence tracking, and activity attribution
  /// throughout the collaborative editing interface and conflict resolution systems.
  final String userId;

  /// Cached display name of the editor for UI performance optimization.
  /// Stored locally to avoid additional user profile lookups during editor presence display,
  /// collaborative activity indicators, and editor attribution in collaborative editing interfaces.
  final String displayName;

  /// Timestamp of the editor's most recent activity for presence tracking.
  /// Tracks the last interaction time for activity monitoring, timeout detection,
  /// and editor presence calculations enabling accurate collaborative editing status
  /// and automatic cleanup of inactive editor sessions.
  final DateTime lastSeen;

  /// Optional field identifier currently being edited by this editor for conflict prevention.
  /// Specifies the exact resource field (e.g., 'ingredients[2].name', 'instructions[0].description')
  /// currently under edit to prevent edit conflicts, enable field-level locking, and provide
  /// granular collaborative editing awareness. Null when editor is not actively editing a specific field.
  final String? currentField;

  /// Flag indicating whether the editor is currently active in the collaborative session.
  /// Tracks editor activity status for presence indicators, collaborative UI state management,
  /// and automatic session cleanup with true for active editors and false for inactive or timed-out sessions.
  final bool isActive;

  /// Creates a new live editor with comprehensive collaborative editing configuration.
  /// This constructor provides complete editor initialization with presence tracking, activity monitoring,
  /// and field-level editing awareness for advanced collaborative editing features and conflict prevention.
  /// [userId] Required user identifier for editor identification and attribution
  /// [displayName] Required editor display name for UI performance and presentation
  /// [lastSeen] Required timestamp of most recent activity for presence tracking
  /// [currentField] Optional field identifier currently being edited for conflict prevention
  /// [isActive] Activity status flag, defaults to true for new active editor sessions
  const LiveEditor({
    required this.userId,
    required this.displayName,
    required this.lastSeen,
    this.currentField,
    this.isActive = true,
  });

  /// Data persistence and serialization methods for Firestore integration.

  /// Creates a live editor instance from Firestore document data with robust parsing.
  /// Transforms Firestore document data into a complete LiveEditor instance with proper
  /// type conversion, timestamp handling, and fallback values for missing or invalid data.
  /// Provides reliable deserialization for collaborative editing session management.
  factory LiveEditor.fromFirestore(Map<String, dynamic> data) {
    return LiveEditor(
      userId: SerializationUtils.safeString(data, 'userId'),
      displayName: SerializationUtils.safeString(data, 'displayName'),
      lastSeen: DateTime.fromMillisecondsSinceEpoch(
        SerializationUtils.safeInt(data, 'lastSeen'),
      ),
      currentField: SerializationUtils.safeNullableString(data, 'currentField'),
      isActive:
          SerializationUtils.safeBool(data, 'isActive', defaultValue: true),
    );
  }

  /// Converts the live editor to Firestore-compatible format for persistence.
  /// Transforms all editor data including timestamps and field references into Firestore format
  /// with proper field mapping and type preservation for efficient database storage and querying
  /// in collaborative editing session management systems.
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'displayName': displayName,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'currentField': currentField,
      'isActive': isActive,
    };
  }

  /// Utility methods for editor manipulation and immutable updates.

  /// Creates a copy of this live editor with updated values while preserving immutability.
  /// Used for all editor modifications while maintaining immutable data patterns and ensuring
  /// consistent state management for presence updates, activity tracking, and field changes
  /// in collaborative editing session management.
  LiveEditor copyWith({
    String? userId,
    String? displayName,
    DateTime? lastSeen,
    String? currentField,
    bool? isActive,
  }) {
    return LiveEditor(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      lastSeen: lastSeen ?? this.lastSeen,
      currentField: currentField ?? this.currentField,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Activity tracking and presence utility methods for collaborative editing management.

  /// Checks if the editor is currently active based on recent activity and status.
  /// Determines editor activity by combining explicit active status with temporal activity analysis,
  /// using a default 5-minute timeout for activity detection. Returns true only when editor is
  /// marked active and has recent activity within the timeout threshold.
  /// [timeoutMinutes] Optional custom timeout in minutes, defaults to 5 minutes for standard activity detection
  /// Returns true if editor is active and has recent activity, false for inactive or timed-out editors.
  bool isRecentlyActive({int timeoutMinutes = 5}) {
    if (!isActive) return false;
    final now = DateTime.now();
    final timeoutDuration = Duration(minutes: timeoutMinutes);
    return now.difference(lastSeen) <= timeoutDuration;
  }

  /// Gets the duration since the editor's last activity for activity monitoring.
  /// Calculates time elapsed since last editor activity for presence indicators,
  /// timeout detection, and activity timeline displays in collaborative editing interfaces.
  /// Returns [Duration] representing time elapsed since last editor activity.
  Duration get timeSinceLastSeen {
    return DateTime.now().difference(lastSeen);
  }

  /// Creates an inactive copy of this editor for session cleanup and timeout handling.
  /// Marks the editor as inactive while preserving all other editor information
  /// for session cleanup, timeout handling, and collaborative editing state management.
  /// Returns a new [LiveEditor] instance marked as inactive for session management.
  LiveEditor markInactive() {
    return copyWith(isActive: false);
  }

  /// Updates the editor's activity timestamp to current time for presence tracking.
  /// Updates last seen timestamp to current time while preserving active status
  /// for activity tracking, presence updates, and collaborative editing session management.
  /// Returns a new [LiveEditor] instance with updated activity timestamp.
  LiveEditor updateActivity() {
    return copyWith(lastSeen: DateTime.now());
  }

  /// Checks if the editor is actively editing a specific field for conflict detection.
  /// Determines if the editor is currently working on a specific resource field
  /// enabling field-level conflict detection and granular collaborative editing awareness.
  /// [fieldPath] Required field identifier to check for active editing
  /// Returns true if editor is actively editing the specified field, false otherwise.
  bool isEditingField(String fieldPath) {
    return isActive && currentField == fieldPath;
  }

  /// Standard object methods for debugging, comparison, and identity management.

  /// Compares two live editors for equality based on unique user identifier.
  /// Uses editor user ID for equality comparison ensuring consistent object identity
  /// across different instances of the same editor data in collaborative sessions.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LiveEditor && other.userId == userId;
  }

  /// Generates hash code based on unique user identifier.
  /// Provides consistent hash code generation for use in collections and
  /// data structures requiring hash-based operations and editor identification.
  @override
  int get hashCode => userId.hashCode;

  /// Returns a string representation of the live editor for debugging and logging.
  /// Provides essential editor information in a readable format for development
  /// and debugging purposes with user identification, activity status, and field information.
  @override
  String toString() {
    return 'LiveEditor(userId: $userId, displayName: $displayName, isActive: $isActive, currentField: $currentField)';
  }
}
