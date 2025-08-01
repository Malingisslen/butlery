/// Comprehensive shared content model providing advanced content sharing and permission management capabilities.
///
/// This model implements sophisticated content sharing functionality following Single Responsibility Principle,
/// handling all aspects of social content sharing including multi-target distribution, granular permissions,
/// recipient tracking, and comprehensive engagement analytics. It provides complete content sharing capabilities
/// while maintaining clean separation from content data and user management concerns.
///
/// **Single Responsibility Focus:**
/// This model exclusively handles shared content management and tracking:
/// - **Multi-Target Sharing**: Complete sharing system with individual user and group distribution capabilities
/// - **Permission Management**: Granular permission control with view, edit, reshare, and comment permissions
/// - **Engagement Tracking**: Comprehensive recipient interaction tracking with viewed, accepted, and declined states
/// - **Content Metadata**: Flexible metadata system for content-specific sharing information and context
///
/// **What This Model Does NOT Handle:**
/// - Content data management and business logic (handled by specific content models)
/// - User and group management operations (handled by social services)
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Content persistence and storage operations (handled by repositories and services)
///
/// **Shared Content Features:**
/// - **Universal Content Sharing**: Multi-type content sharing supporting recipes, menus, and shopping lists
/// - **Advanced Permission System**: Granular access control with expiration support and capability-based permissions
/// - **Comprehensive Analytics**: Complete engagement tracking with view counts, acceptance rates, and interaction timestamps
/// - **Multi-Target Distribution**: Simultaneous sharing with individual users and groups with unified management
/// - **Flexible Metadata**: Extensible metadata system for content-specific sharing context and customization
///
/// **Usage Examples:**
/// ```dart
/// // Create new shared content with permissions
/// final sharedContent = SharedContent(
///   id: contentId,
///   contentType: 'recipe',
///   contentId: recipeId,
///   ownerId: currentUserId,
///   sharedWithUserIds: [friend1Id, friend2Id],
///   sharedWithGroupIds: [cookingGroupId],
///   sharedAt: DateTime.now(),
///   metadata: {
///     'title': 'Mormors köttbullar',
///     'description': 'Familjerecept från Sverige',
///     'difficulty': 'medium',
///   },
///   permissions: SharingPermissions(
///     canView: true,
///     canEdit: false,
///     canReshare: true,
///     canComment: true,
///     expiresAt: DateTime.now().add(Duration(days: 30)),
///   ),
/// );
/// 
/// // Track recipient engagement
/// final viewedContent = sharedContent.copyWith(
///   viewedBy: {
///     ...sharedContent.viewedBy,
///     friend1Id: DateTime.now(),
///   },
/// );
/// 
/// // Update sharing permissions
/// final updatedPermissions = SharingPermissions(
///   canView: true,
///   canEdit: true,
///   canReshare: false,
///   canComment: true,
/// );
/// 
/// // Check permission status
/// final hasExpired = sharedContent.permissions.isExpired;
/// final canEdit = sharedContent.permissions.canEdit;
/// ```

// lib/models/shared_content.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Comprehensive shared content model with multi-target distribution and engagement tracking.
///
/// Represents complete shared content with all associated metadata including recipients,
/// permissions, engagement analytics, and flexible content metadata.
class SharedContent {
  /// Unique identifier for this shared content instance.
  final String id;
  
  /// Type of content being shared for categorization and handling.
  ///
  /// Supports 'recipe', 'menu', and 'shopping_list' content types with extensible design.
  final String contentType; // 'recipe', 'menu', 'shopping_list'
  
  /// Identifier of the actual content being shared.
  ///
  /// References the specific recipe, menu, or shopping list instance.
  final String contentId;
  
  /// User identifier of the content owner who initiated sharing.
  ///
  /// References the user who owns and is sharing the content.
  final String ownerId;
  
  /// List of individual user IDs that the content is shared with.
  ///
  /// Enables direct user-to-user content sharing with individual targeting.
  final List<String> sharedWithUserIds;
  
  /// List of group IDs that the content is shared with.
  ///
  /// Enables group-based content sharing for community distribution.
  final List<String> sharedWithGroupIds;
  
  /// Timestamp when the content was originally shared.
  ///
  /// Used for chronological tracking and time-based analytics.
  final DateTime sharedAt;
  
  /// Flexible metadata container for content-specific sharing information.
  ///
  /// Stores additional context like titles, descriptions, and content-specific data.
  final Map<String, dynamic> metadata;
  
  /// Granular permissions controlling recipient capabilities.
  ///
  /// Defines what actions recipients can perform with the shared content.
  final SharingPermissions permissions;
  
  /// Tracking map of users who have viewed the shared content.
  ///
  /// Maps user IDs to timestamps for engagement analytics and view tracking.
  final Map<String, DateTime> viewedBy;
  
  /// Tracking map of users who have accepted the shared content.
  ///
  /// Maps user IDs to timestamps for acceptance analytics and conversion tracking.
  final Map<String, DateTime> acceptedBy;
  
  /// Tracking map of users who have declined the shared content.
  ///
  /// Maps user IDs to timestamps for decline analytics and feedback tracking.
  final Map<String, DateTime> declinedBy;

  /// Creates a new shared content instance with all required sharing metadata.
  ///
  /// [id] Unique identifier for the shared content instance
  /// [contentType] Type of content being shared (recipe, menu, shopping_list)
  /// [contentId] Identifier of the actual content being shared
  /// [ownerId] User identifier of the content owner
  /// [sharedWithUserIds] List of individual users to share with
  /// [sharedWithGroupIds] List of groups to share with
  /// [sharedAt] Timestamp when sharing occurred
  /// [metadata] Flexible metadata for content-specific information
  /// [permissions] Granular permissions for recipient capabilities
  /// [viewedBy] Optional map of users who have viewed the content
  /// [acceptedBy] Optional map of users who have accepted the content
  /// [declinedBy] Optional map of users who have declined the content
  SharedContent({
    required this.id,
    required this.contentType,
    required this.contentId,
    required this.ownerId,
    required this.sharedWithUserIds,
    required this.sharedWithGroupIds,
    required this.sharedAt,
    required this.metadata,
    required this.permissions,
    Map<String, DateTime>? viewedBy,
    Map<String, DateTime>? acceptedBy,
    Map<String, DateTime>? declinedBy,
  }) : viewedBy = viewedBy ?? {},
       acceptedBy = acceptedBy ?? {},
       declinedBy = declinedBy ?? {};

  /// Data persistence and serialization methods for Firestore integration.

  /// Creates a shared content instance from Firestore document data.
  ///
  /// Transforms Firestore document into a complete [SharedContent] instance with proper
  /// type conversion, timestamp parsing, and engagement tracking deserialization.
  ///
  /// [doc] Firestore document snapshot containing shared content data
  ///
  /// Returns a new [SharedContent] instance with all data properly parsed from Firestore.
  factory SharedContent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SharedContent(
      id: doc.id,
      contentType: data['contentType'] ?? '',
      contentId: data['contentId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      sharedWithUserIds: List<String>.from(data['sharedWithUserIds'] ?? []),
      sharedWithGroupIds: List<String>.from(data['sharedWithGroupIds'] ?? []),
      sharedAt: (data['sharedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      permissions: SharingPermissions.fromMap(data['permissions'] ?? {}),
      viewedBy: _dateMapFromFirestore(data['viewedBy']),
      acceptedBy: _dateMapFromFirestore(data['acceptedBy']),
      declinedBy: _dateMapFromFirestore(data['declinedBy']),
    );
  }

  /// Converts the shared content to Firestore-compatible format for persistence.
  ///
  /// Transforms all sharing data into Firestore format with proper timestamp handling
  /// and engagement tracking serialization for database storage.
  ///
  /// Returns a map containing all shared content data formatted for Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'contentType': contentType,
      'contentId': contentId,
      'ownerId': ownerId,
      'sharedWithUserIds': sharedWithUserIds,
      'sharedWithGroupIds': sharedWithGroupIds,
      'sharedAt': Timestamp.fromDate(sharedAt),
      'metadata': metadata,
      'permissions': permissions.toMap(),
      'viewedBy': _dateMapToFirestore(viewedBy),
      'acceptedBy': _dateMapToFirestore(acceptedBy),
      'declinedBy': _dateMapToFirestore(declinedBy),
    };
  }

  /// Helper methods for Firestore timestamp conversion and data processing.

  /// Converts Firestore timestamp map to DateTime map for engagement tracking.
  ///
  /// Transforms Firestore timestamp data into DateTime objects for internal use
  /// with proper null handling and type validation for robust data recovery.
  ///
  /// [data] Raw Firestore data containing timestamp mappings
  ///
  /// Returns a map of user IDs to DateTime objects for engagement tracking.
  static Map<String, DateTime> _dateMapFromFirestore(dynamic data) {
    if (data == null || data is! Map) return {};
    
    final result = <String, DateTime>{};
    data.forEach((key, value) {
      if (value is Timestamp) {
        result[key] = value.toDate();
      }
    });
    return result;
  }

  /// Converts DateTime map to Firestore timestamp map for persistence.
  ///
  /// Transforms DateTime objects into Firestore-compatible timestamps for
  /// database storage with proper format conversion for engagement data.
  ///
  /// [dates] Map of user IDs to DateTime objects for engagement tracking
  ///
  /// Returns a map formatted for Firestore timestamp storage.
  static Map<String, Timestamp> _dateMapToFirestore(Map<String, DateTime> dates) {
    return dates.map((key, value) => MapEntry(key, Timestamp.fromDate(value)));
  }

  /// Creates a copy of this shared content with updated values while preserving immutability.
  ///
  /// Used for all sharing modifications while maintaining immutable data patterns
  /// and ensuring consistent state management for engagement tracking and permissions.
  ///
  /// [id] Updated shared content identifier
  /// [contentType] Updated content type classification
  /// [contentId] Updated content reference identifier
  /// [ownerId] Updated owner user identifier
  /// [sharedWithUserIds] Updated list of individual recipient users
  /// [sharedWithGroupIds] Updated list of recipient groups
  /// [sharedAt] Updated sharing timestamp
  /// [metadata] Updated flexible metadata container
  /// [permissions] Updated granular permission settings
  /// [viewedBy] Updated view engagement tracking
  /// [acceptedBy] Updated acceptance engagement tracking
  /// [declinedBy] Updated decline engagement tracking
  ///
  /// Returns a new [SharedContent] instance with updated values.
  SharedContent copyWith({
    String? id,
    String? contentType,
    String? contentId,
    String? ownerId,
    List<String>? sharedWithUserIds,
    List<String>? sharedWithGroupIds,
    DateTime? sharedAt,
    Map<String, dynamic>? metadata,
    SharingPermissions? permissions,
    Map<String, DateTime>? viewedBy,
    Map<String, DateTime>? acceptedBy,
    Map<String, DateTime>? declinedBy,
  }) {
    return SharedContent(
      id: id ?? this.id,
      contentType: contentType ?? this.contentType,
      contentId: contentId ?? this.contentId,
      ownerId: ownerId ?? this.ownerId,
      sharedWithUserIds: sharedWithUserIds ?? this.sharedWithUserIds,
      sharedWithGroupIds: sharedWithGroupIds ?? this.sharedWithGroupIds,
      sharedAt: sharedAt ?? this.sharedAt,
      metadata: metadata ?? this.metadata,
      permissions: permissions ?? this.permissions,
      viewedBy: viewedBy ?? this.viewedBy,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      declinedBy: declinedBy ?? this.declinedBy,
    );
  }

  /// Analytics and utility methods for engagement tracking and sharing insights.

  /// Gets the total number of recipients (users and groups combined).
  ///
  /// Provides quick access to total distribution reach for analytics
  /// and sharing statistics without manual counting.
  int get totalRecipients => sharedWithUserIds.length + sharedWithGroupIds.length;
  
  /// Gets the total number of users who have viewed the shared content.
  ///
  /// Provides engagement metrics for view tracking and content analytics.
  int get viewCount => viewedBy.length;
  
  /// Gets the total number of users who have accepted the shared content.
  ///
  /// Provides conversion metrics for acceptance tracking and engagement analysis.
  int get acceptanceCount => acceptedBy.length;
  
  /// Gets the total number of users who have declined the shared content.
  ///
  /// Provides feedback metrics for decline tracking and content optimization.
  int get declineCount => declinedBy.length;
  
  /// Calculates the acceptance rate as a percentage of total views.
  ///
  /// Provides conversion analytics for measuring content effectiveness
  /// and user engagement quality with the shared content.
  ///
  /// Returns acceptance rate as a percentage (0.0 to 100.0).
  double get acceptanceRate {
    if (viewCount == 0) return 0.0;
    return (acceptanceCount / viewCount) * 100.0;
  }
  
  /// Checks if the specified user has viewed the shared content.
  ///
  /// Provides convenient access to user-specific engagement status
  /// for UI state management and analytics tracking.
  ///
  /// [userId] The user identifier to check for view status
  ///
  /// Returns true if the user has viewed the shared content.
  bool hasUserViewed(String userId) => viewedBy.containsKey(userId);
  
  /// Checks if the specified user has accepted the shared content.
  ///
  /// Provides convenient access to user-specific acceptance status
  /// for conversion tracking and engagement analysis.
  ///
  /// [userId] The user identifier to check for acceptance status
  ///
  /// Returns true if the user has accepted the shared content.
  bool hasUserAccepted(String userId) => acceptedBy.containsKey(userId);
  
  /// Checks if the specified user has declined the shared content.
  ///
  /// Provides convenient access to user-specific decline status
  /// for feedback tracking and content optimization insights.
  ///
  /// [userId] The user identifier to check for decline status
  ///
  /// Returns true if the user has declined the shared content.
  bool hasUserDeclined(String userId) => declinedBy.containsKey(userId);
}

/// Comprehensive sharing permissions model providing granular access control and expiration management.
///
/// This model implements sophisticated permission management following Single Responsibility Principle,
/// handling all aspects of content access control including capability-based permissions, temporal
/// restrictions, and comprehensive permission validation. It provides complete access control capabilities
/// while maintaining clean separation from content and user management concerns.
///
/// **Single Responsibility Focus:**
/// This model exclusively handles sharing permission management:
/// - **Capability-Based Permissions**: Granular control over view, edit, reshare, and comment capabilities
/// - **Temporal Access Control**: Time-based permission expiration with automatic validation
/// - **Permission Validation**: Comprehensive permission checking with expiration awareness
/// - **Serialization Support**: Complete Firestore integration with timestamp handling
///
/// **Sharing Permission Features:**
/// - **Granular Access Control**: Individual permission flags for different content interaction capabilities
/// - **Expiration Management**: Optional time-based access control with automatic expiration detection
/// - **Default Permission Sets**: Sensible defaults for common sharing scenarios with customization options
/// - **Firestore Integration**: Complete serialization support with proper timestamp conversion
class SharingPermissions {
  /// Permission to view the shared content.
  ///
  /// Controls basic access to view and consume the shared content.
  final bool canView;
  
  /// Permission to edit the shared content.
  ///
  /// Controls ability to modify the content and make changes to shared data.
  final bool canEdit;
  
  /// Permission to reshare the content with others.
  ///
  /// Controls ability to distribute the content to additional recipients.
  final bool canReshare;
  
  /// Permission to comment on the shared content.
  ///
  /// Controls ability to add comments and engage in discussions about the content.
  final bool canComment;
  
  /// Optional expiration timestamp for time-limited sharing.
  ///
  /// When set, permissions automatically expire after this time for security and control.
  final DateTime? expiresAt;

  /// Creates sharing permissions with customizable capability settings.
  ///
  /// [canView] Permission to view content, defaults to true
  /// [canEdit] Permission to edit content, defaults to false for security
  /// [canReshare] Permission to reshare content, defaults to false for control
  /// [canComment] Permission to comment, defaults to true for engagement
  /// [expiresAt] Optional expiration time for temporal access control
  SharingPermissions({
    this.canView = true,
    this.canEdit = false,
    this.canReshare = false,
    this.canComment = true,
    this.expiresAt,
  });

  /// Creates sharing permissions from Firestore data with proper type conversion.
  ///
  /// Transforms Firestore permission data into [SharingPermissions] instance with
  /// proper timestamp parsing and default value handling for robust data recovery.
  ///
  /// [map] Raw Firestore data containing permission settings
  ///
  /// Returns a new [SharingPermissions] instance with parsed data and defaults.
  factory SharingPermissions.fromMap(Map<String, dynamic> map) {
    return SharingPermissions(
      canView: map['canView'] ?? true,
      canEdit: map['canEdit'] ?? false,
      canReshare: map['canReshare'] ?? false,
      canComment: map['canComment'] ?? true,
      expiresAt: map['expiresAt'] != null
          ? (map['expiresAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Converts sharing permissions to Firestore-compatible format.
  ///
  /// Transforms permission settings into Firestore format with proper timestamp
  /// conversion and optional field handling for database storage efficiency.
  ///
  /// Returns a map containing all permission data formatted for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'canView': canView,
      'canEdit': canEdit,
      'canReshare': canReshare,
      'canComment': canComment,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
    };
  }

  /// Permission validation and utility methods.

  /// Checks if the permissions have expired and are no longer valid.
  ///
  /// Provides automatic expiration validation for time-based access control
  /// with current time comparison for real-time permission enforcement.
  ///
  /// Returns true if permissions have expired and should be denied.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
  
  /// Checks if the permissions are currently valid and not expired.
  ///
  /// Provides convenient validation for active permission checking
  /// with expiration awareness for access control decisions.
  ///
  /// Returns true if permissions are valid and not expired.
  bool get isValid => !isExpired;
  
  /// Creates a copy of permissions with updated capability settings.
  ///
  /// Used for permission modifications while maintaining immutable patterns
  /// and ensuring consistent permission state management.
  ///
  /// [canView] Updated view permission setting
  /// [canEdit] Updated edit permission setting  
  /// [canReshare] Updated reshare permission setting
  /// [canComment] Updated comment permission setting
  /// [expiresAt] Updated expiration timestamp
  ///
  /// Returns a new [SharingPermissions] instance with updated settings.
  SharingPermissions copyWith({
    bool? canView,
    bool? canEdit,
    bool? canReshare,
    bool? canComment,
    DateTime? expiresAt,
  }) {
    return SharingPermissions(
      canView: canView ?? this.canView,
      canEdit: canEdit ?? this.canEdit,
      canReshare: canReshare ?? this.canReshare,
      canComment: canComment ?? this.canComment,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  /// Predefined permission sets for common sharing scenarios.

  /// Creates read-only permissions for viewing and commenting only.
  ///
  /// Provides secure sharing with minimal permissions for content consumption
  /// without editing or redistribution capabilities.
  static SharingPermissions readOnly({DateTime? expiresAt}) {
    return SharingPermissions(
      canView: true,
      canEdit: false,
      canReshare: false,
      canComment: true,
      expiresAt: expiresAt,
    );
  }
  
  /// Creates collaborative permissions for full content interaction.
  ///
  /// Provides comprehensive permissions for active collaboration including
  /// editing, resharing, and commenting for team-based content work.
  static SharingPermissions collaborative({DateTime? expiresAt}) {
    return SharingPermissions(
      canView: true,
      canEdit: true,
      canReshare: true,
      canComment: true,
      expiresAt: expiresAt,
    );
  }
  
  /// Creates view-only permissions with no interaction capabilities.
  ///
  /// Provides minimal permissions for content viewing only without any
  /// modification, sharing, or commenting abilities for maximum security.
  static SharingPermissions viewOnly({DateTime? expiresAt}) {
    return SharingPermissions(
      canView: true,
      canEdit: false,
      canReshare: false,
      canComment: false,
      expiresAt: expiresAt,
    );
  }
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreams(); // From StreamManagementMixin
    super.dispose();
  }
}