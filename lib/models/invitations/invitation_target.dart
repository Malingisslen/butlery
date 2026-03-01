/// Comprehensive invitation target model providing advanced target management for multi-recipient invitation systems.
/// This model implements sophisticated invitation targeting following Single Responsibility Principle,
/// handling all aspects of invitation recipient management including individual users, group targeting,
/// metadata management, and comprehensive utility operations. It provides complete invitation targeting
/// capabilities while maintaining clean separation from UI concerns and invitation logic.
/// **Single Responsibility Focus:**
/// This model exclusively handles invitation target representation and management:
/// - **Dual Target Support**: Seamlessly handles both individual users and group-based invitation targeting
/// - **Metadata Management**: Comprehensive metadata system for target-specific information and UI optimization
/// - **Business Logic**: Rich business logic getters for target validation, display formatting, and data extraction
/// - **Utility Operations**: Complete utility methods for target manipulation, filtering, and analysis
/// **What This Model Does NOT Handle:**
/// - Invitation creation and sending operations (handled by invitation services)
/// - UI widgets, styling, and theme methods (handled by UI components and themes)
/// - User and group management operations (handled by user and friend services)
/// - Authentication and permission validation (handled by authentication services)
/// **Invitation Target Features:**
/// - **Flexible Targeting**: Support for both individual users and group-based targeting with unified interface
/// - **Rich Metadata**: Comprehensive metadata system for target information, UI optimization, and analytics
/// - **Swedish Localization**: Complete Swedish language support for descriptions, counts, and UI text
/// - **Advanced Filtering**: Sophisticated search, type filtering, and sorting capabilities for target management
/// - **Business Logic**: Rich validation, comparison, and utility methods for invitation target operations
/// **Usage Examples:**
/// ```dart
/// // Create individual user targets
/// final userTargets = InvitationTarget.fromUsers([user1, user2, user3]);
/// // Create group targets with member expansion
/// final groupTargets = InvitationTarget.fromGroups(categories, memberMaps);
/// // Combined targeting with filtering
/// final allTargets = [...userTargets, ...groupTargets];
/// final filteredTargets = InvitationTarget.filterBySearch(allTargets, 'anna');
/// final sortedTargets = InvitationTarget.sortForUI(filteredTargets);
/// // Target analysis and validation
/// final totalUsers = InvitationTarget.getTotalUserCount(allTargets);
/// final allUserIds = InvitationTarget.extractAllUserIds(allTargets);
/// final hasUser = InvitationTarget.containsUser(allTargets, userId);
/// // Individual target operations
/// final target = InvitationTarget.individual(user);
/// print(target.displayEmoji); // 👤
/// print(target.subtitle); // "Butlery-användare"
/// print(target.allUserIds); // [userId]
/// ```

// lib/models/invitations/invitation_target.dart

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';

/// Enumeration defining invitation target types for recipient classification.
/// Provides clear categorization of invitation targets with support for both
/// individual user targeting and group-based invitation distribution.
enum InvitationTargetType {
  /// Individual user targeting for direct personal invitations.
  /// Represents a single user recipient for personalized invitation delivery.
  individual,

  /// Group targeting using friend categories for bulk invitation distribution.
  /// Represents a group of users organized in a FriendCategory for efficient group invitations.
  group,
}

/// Comprehensive invitation target with dual-mode support and rich metadata management.
/// Represents invitation recipients with unified interface for both individual users and groups,
/// comprehensive metadata support, and extensive utility methods for target management and analysis.
/// This class is a pure data model focused exclusively on target representation and business logic.
class InvitationTarget {
  /// Type classification of the invitation target determining behavioral characteristics.
  /// Controls whether this target represents an individual user or a group for
  /// appropriate invitation handling and UI presentation adaptation.
  final InvitationTargetType type;

  /// Unique identifier for the invitation target.
  /// For individual targets: userId referencing the specific user to invite.
  /// For group targets: groupId referencing the FriendCategory for bulk operations.
  final String targetId;

  /// Display name for UI presentation and user identification.
  /// Human-readable name shown in invitation interfaces and target selection lists.
  /// For individuals: user's display name. For groups: category name.
  final String displayName;

  /// Visual representation for UI display optimization.
  /// For individual users: avatar image URL for profile picture display.
  /// For group targets: emoji character for visual group identification.
  /// Used for consistent UI presentation across invitation interfaces.
  final String? imageOrEmoji;

  /// Member count for group targets providing size information.
  /// Only populated for group targets, indicating the number of users within
  /// the group for invitation scope understanding and UI display purposes.
  final int? memberCount;

  /// Expanded member user IDs for group targets enabling individual access.
  /// Only populated for group targets, containing the complete list of user IDs
  /// within the group for invitation expansion and individual user operations.
  final List<String>? memberIds;

  /// Flexible metadata container for target-specific information and UI optimization.
  /// Stores additional target information including:
  /// - For individuals: isSearchable, friendsCount, memberSince
  /// - For groups: description, createdAt, ownerId
  /// Used for enhanced UI display and target filtering capabilities.
  final Map<String, dynamic>? metadata;

  /// Creates a new invitation target with comprehensive metadata support.
  /// This constructor provides complete target initialization with support for both
  /// individual users and group targets. Metadata is optional and used for enhanced
  /// UI display and filtering capabilities.
  /// [type] Required target type classification (individual or group)
  /// [targetId] Required unique identifier for the target
  /// [displayName] Required display name for UI presentation
  /// [imageOrEmoji] Optional visual representation (avatar URL or emoji)
  /// [memberCount] Optional member count for group targets
  /// [memberIds] Optional member user IDs for group expansion
  /// [metadata] Optional flexible metadata for additional target information
  const InvitationTarget({
    required this.type,
    required this.targetId,
    required this.displayName,
    this.imageOrEmoji,
    this.memberCount,
    this.memberIds,
    this.metadata,
  });

  /// Factory constructors for simplified invitation target creation with specific configurations.

  /// Creates an individual user target with comprehensive user metadata.
  /// This factory provides streamlined creation for individual user targets with automatic
  /// metadata extraction from UserProfile including searchability, friend count, and
  /// membership information for enhanced UI display and filtering capabilities.
  /// [user] Required UserProfile containing complete user information for target creation
  /// Returns a new [InvitationTarget] configured for individual user invitations with
  /// comprehensive metadata including searchability status, and social information.
  factory InvitationTarget.individual(UserProfile user) {
    return InvitationTarget(
      type: InvitationTargetType.individual,
      targetId: user.uid,
      displayName: user.displayName,
      imageOrEmoji: user.avatarUrl,
      memberCount: null,
      memberIds: null,
      metadata: {
        'isSearchable': user.isSearchable,
        'friendsCount': user.friendsCount,
        'memberSince': user.memberSinceText,
      },
    );
  }

  /// Creates a group target with comprehensive member expansion and metadata.
  /// This factory provides complete group target creation with automatic member expansion,
  /// count calculation, and comprehensive metadata extraction from FriendCategory including
  /// description, creation timestamp, and ownership information for optimal group invitation management.
  /// [group] Required FriendCategory containing group information and configuration
  /// [members] Required list of UserProfile instances representing group members for expansion
  /// Returns a new [InvitationTarget] configured for group-based invitations with complete
  /// member expansion and comprehensive group metadata for bulk invitation operations.
  factory InvitationTarget.group(
    FriendCategory group,
    List<UserProfile> members,
  ) {
    return InvitationTarget(
      type: InvitationTargetType.group,
      targetId: group.id,
      displayName: group.name,
      imageOrEmoji: group.emoji ?? '👥',
      memberCount: members.length,
      memberIds: members.map((m) => m.uid).toList(),
      metadata: {
        'description': group.description,
        'createdAt': group.createdAt.toIso8601String(),
        'ownerId': group.ownerId,
      },
    );
  }

  /// Business logic getters providing comprehensive target analysis and UI state management.

  /// Checks if this target represents an individual user for invitation handling.
  /// Returns true for individual user targets, enabling appropriate UI elements
  /// and invitation processing logic for single-user operations.
  bool get isIndividual => type == InvitationTargetType.individual;

  /// Checks if this target represents a group for bulk invitation operations.
  /// Returns true for group targets, enabling group-specific UI elements
  /// and bulk invitation processing logic for multi-user operations.
  bool get isGroup => type == InvitationTargetType.group;

  /// Gets the appropriate emoji for UI display with fallback handling.
  /// For group targets: returns the stored emoji or default group emoji '👥'.
  /// For individual targets: returns standard person emoji '👤' for consistency.
  /// Used for consistent visual representation across invitation interfaces.
  String get displayEmoji {
    if (isGroup) {
      return imageOrEmoji ?? '👥';
    } else {
      return '👤'; // Default person emoji
    }
  }

  /// Gets the descriptive text for target information display.
  /// For group targets: returns Swedish-localized member count (e.g., "3 medlemmar").
  /// For individual targets: returns empty string.
  /// Used for secondary information display in target selection interfaces.
  String get description {
    if (isGroup) {
      final count = memberCount ?? 0;
      return '$count medlem${count != 1 ? 'mar' : ''}';
    } else {
      return '';
    }
  }

  /// Gets the subtitle text for ListTile widget display optimization.
  /// For group targets: returns the description with member count information.
  /// For individual targets: returns fallback text for user.
  /// Optimized for UI display with appropriate fallback text for enhanced user experience.
  String get subtitle {
    if (isGroup) {
      return description;
    } else {
      return AppLocale.current.labelButleryUser;
    }
  }

  /// Validates the target for invitation operations and data integrity.
  /// Performs comprehensive validation including:
  /// - Required field presence (targetId, displayName)
  /// - Group-specific validation (groups must have members)
  /// - Data consistency checks for invitation processing
  /// Returns true if the target is valid for invitation operations.
  bool get isValid {
    if (targetId.isEmpty || displayName.isEmpty) return false;

    if (isGroup) {
      // Groups must have members
      return memberIds?.isNotEmpty == true;
    }

    return true;
  }

  /// Gets all user IDs represented by this target for invitation expansion.
  /// For individual targets: returns single-item list with the user ID.
  /// For group targets: returns complete list of member user IDs for bulk operations.
  /// Used for invitation processing and recipient list expansion.
  List<String> get allUserIds {
    if (isIndividual) {
      return [targetId];
    } else {
      return memberIds ?? [];
    }
  }

  /// Gets the creation date from metadata for group targets.
  /// Parses the ISO 8601 creation date string from group metadata, returning
  /// null if date is not available or parsing fails. Used for group information display.
  DateTime? get createdAt {
    final dateString = metadata?['createdAt'] as String?;
    return dateString != null ? DateTime.tryParse(dateString) : null;
  }

  /// Gets the owner ID from metadata for group targets.
  /// Extracts the group owner user ID from metadata for group targets.
  /// Used for ownership validation and administrative operations.
  String? get ownerId {
    return metadata?['ownerId'] as String?;
  }

  /// Gets the friend count from metadata for individual user targets.
  /// Extracts the friend count from user metadata, returning 0 if not available.
  /// Used for social information display and user engagement indicators.
  int get friendsCount {
    return metadata?['friendsCount'] as int? ?? 0;
  }

  /// Checks if the user is searchable from metadata for individual targets.
  /// Extracts searchability status from user metadata, defaulting to true.
  /// Used for search functionality and privacy controls in invitation interfaces.
  bool get isSearchable {
    return metadata?['isSearchable'] as bool? ?? true;
  }

  /// Data persistence and serialization methods for Firestore and caching integration.

  /// Converts the invitation target to Firestore-compatible format for persistence.
  /// Transforms all target data including type, metadata, and member information into
  /// Firestore format with proper field mapping and type preservation for efficient
  /// database storage and querying capabilities.
  /// Returns a map containing all target data formatted for Firestore persistence.
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'targetId': targetId,
      'displayName': displayName,
      'imageOrEmoji': imageOrEmoji,
      'memberCount': memberCount,
      'memberIds': memberIds,
      'metadata': metadata,
    };
  }

  /// Creates an invitation target instance from Firestore document data.
  /// Transforms Firestore document data into a complete [InvitationTarget] instance with
  /// proper type conversion, enum parsing, and metadata deserialization. Includes fallback
  /// handling for missing or invalid data to ensure robust data recovery.
  /// [data] Firestore document data containing target information
  /// Returns a new [InvitationTarget] instance with all data properly parsed from Firestore.
  factory InvitationTarget.fromFirestore(Map<String, dynamic> data) {
    return InvitationTarget(
      type: InvitationTargetType.values.firstWhere(
        (t) => t.name == SerializationUtils.safeString(data, 'type'),
        orElse: () => InvitationTargetType.individual,
      ),
      targetId: SerializationUtils.safeString(data, 'targetId'),
      displayName: SerializationUtils.safeString(data, 'displayName'),
      imageOrEmoji: SerializationUtils.safeNullableString(data, 'imageOrEmoji'),
      memberCount: SerializationUtils.safeNullableInt(data, 'memberCount'),
      memberIds: data['memberIds'] != null
          ? SerializationUtils.safeStringList(data, 'memberIds')
          : null,
      metadata: data['metadata'] != null
          ? SerializationUtils.safeMap(data, 'metadata')
          : null,
    );
  }

  /// Converts the invitation target to JSON format for caching and client-side storage.
  /// Provides JSON serialization for client-side caching, local storage, and data transfer
  /// with complete metadata preservation and type information for efficient caching operations.
  /// Returns a JSON-compatible map with all target data properly formatted.
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'targetId': targetId,
      'displayName': displayName,
      'imageOrEmoji': imageOrEmoji,
      'memberCount': memberCount,
      'memberIds': memberIds,
      'metadata': metadata,
    };
  }

  /// Creates an invitation target instance from JSON data for caching and deserialization.
  /// Transforms JSON cache data into a complete [InvitationTarget] instance with proper
  /// type conversion, enum parsing, and metadata deserialization for client-side caching
  /// support and data restoration capabilities.
  /// [json] JSON data containing target information from cache or transfer
  /// Returns a new [InvitationTarget] instance with all data properly parsed from JSON.
  factory InvitationTarget.fromJson(Map<String, dynamic> json) {
    return InvitationTarget(
      type: InvitationTargetType.values.firstWhere(
        (t) => t.name == SerializationUtils.safeString(json, 'type'),
        orElse: () => InvitationTargetType.individual,
      ),
      targetId: SerializationUtils.safeString(json, 'targetId'),
      displayName: SerializationUtils.safeString(json, 'displayName'),
      imageOrEmoji: SerializationUtils.safeNullableString(json, 'imageOrEmoji'),
      memberCount: SerializationUtils.safeNullableInt(json, 'memberCount'),
      memberIds: json['memberIds'] != null
          ? SerializationUtils.safeStringList(json, 'memberIds')
          : null,
      metadata: json['metadata'] != null
          ? SerializationUtils.safeMap(json, 'metadata')
          : null,
    );
  }

  /// Utility methods for target manipulation and data management operations.

  /// Creates a copy of this invitation target with updated values while preserving immutability.
  /// Used for all target modifications while maintaining immutable data patterns and ensuring
  /// consistent state management for target operations and UI updates. Provides comprehensive
  /// field updating with null-safe value preservation.
  /// [type] Optional updated target type classification
  /// [targetId] Optional updated target identifier
  /// [displayName] Optional updated display name
  /// [imageOrEmoji] Optional updated visual representation
  /// [memberCount] Optional updated member count for groups
  /// [memberIds] Optional updated member IDs list for groups
  /// [metadata] Optional updated metadata container
  /// Returns a new [InvitationTarget] instance with updated values.
  InvitationTarget copyWith({
    InvitationTargetType? type,
    String? targetId,
    String? displayName,
    String? imageOrEmoji,
    int? memberCount,
    List<String>? memberIds,
    Map<String, dynamic>? metadata,
  }) {
    return InvitationTarget(
      type: type ?? this.type,
      targetId: targetId ?? this.targetId,
      displayName: displayName ?? this.displayName,
      imageOrEmoji: imageOrEmoji ?? this.imageOrEmoji,
      memberCount: memberCount ?? this.memberCount,
      memberIds: memberIds ?? this.memberIds,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Updates the target metadata with new key-value pairs while preserving existing data.
  /// Merges new metadata with existing metadata, allowing partial updates without losing
  /// existing information. Used for metadata enrichment and progressive data enhancement
  /// during target operations and user interactions.
  /// [newMetadata] Map containing new metadata key-value pairs to merge
  /// Returns a new [InvitationTarget] instance with merged metadata.
  InvitationTarget withMetadata(Map<String, dynamic> newMetadata) {
    final updatedMetadata = Map<String, dynamic>.from(metadata ?? {});
    updatedMetadata.addAll(newMetadata);

    return copyWith(metadata: updatedMetadata);
  }

  /// Removes a specific metadata key while preserving other metadata entries.
  /// Provides selective metadata removal for privacy management, data cleanup,
  /// and dynamic metadata management without affecting other stored information.
  /// Returns unchanged instance if key doesn't exist.
  /// [key] Metadata key to remove from the target metadata
  /// Returns a new [InvitationTarget] instance with the specified metadata key removed.
  InvitationTarget withoutMetadata(String key) {
    if (metadata == null || !metadata!.containsKey(key)) {
      return this;
    }

    final updatedMetadata = Map<String, dynamic>.from(metadata!);
    updatedMetadata.remove(key);

    return copyWith(metadata: updatedMetadata);
  }

  /// Equality, comparison, and identity methods for target management and collections.

  /// Compares two invitation targets for equality based on type and target ID.
  /// Uses type and targetId for equality comparison ensuring consistent object identity
  /// across different instances of the same invitation target data. Essential for
  /// collection operations and duplicate detection in invitation systems.
  /// Returns true if both targets have the same type and targetId.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InvitationTarget &&
        other.type == type &&
        other.targetId == targetId;
  }

  /// Generates hash code based on type and target ID for collection operations.
  /// Provides consistent hash code generation for use in collections and
  /// data structures requiring hash-based operations and target identification.
  @override
  int get hashCode => Object.hash(type, targetId);

  /// Returns a string representation of the invitation target for debugging and logging.
  /// Provides essential target information in a readable format for development
  /// and debugging purposes with type, ID, display name, and member count.
  @override
  String toString() {
    return 'InvitationTarget('
        'type: $type, '
        'targetId: $targetId, '
        'displayName: $displayName, '
        'memberCount: $memberCount'
        ')';
  }

  /// Compares targets for sorting with groups prioritized over individuals.
  /// Implements comprehensive target comparison for UI sorting with groups appearing
  /// first followed by alphabetical sorting within each type category. Used for
  /// consistent target list organization in invitation interfaces.
  /// Returns negative value if this target should appear before the other target.
  int compareTo(InvitationTarget other) {
    // Groups first
    if (isGroup && !other.isGroup) return -1;
    if (!isGroup && other.isGroup) return 1;

    // Alfabetisk sortering inom samma typ
    return displayName.compareTo(other.displayName);
  }

  /// Static utility methods for comprehensive target collection operations and batch processing.

  /// Converts a list of UserProfile instances to individual invitation targets.
  /// Provides streamlined conversion from user profiles to invitation targets with automatic
  /// metadata extraction and target configuration. Used for creating individual user target
  /// lists from user search results and friend lists.
  /// [users] List of UserProfile instances to convert to individual targets
  /// Returns a list of individual [InvitationTarget] instances with comprehensive metadata.
  static List<InvitationTarget> fromUsers(List<UserProfile> users) {
    return users.map(InvitationTarget.individual).toList();
  }

  /// Converts friend categories to group invitation targets with member expansion.
  /// Provides comprehensive group target creation with automatic member expansion and
  /// metadata extraction. Used for creating group target lists from friend categories
  /// with complete member information for bulk invitation operations.
  /// [groups] List of FriendCategory instances to convert to group targets
  /// [groupMembersMap] Map from group ID to member UserProfile lists for expansion
  /// Returns a list of group [InvitationTarget] instances with expanded member information.
  static List<InvitationTarget> fromGroups(
    List<FriendCategory> groups,
    Map<String, List<UserProfile>> groupMembersMap,
  ) {
    return groups.map((group) {
      final members = groupMembersMap[group.id] ?? [];
      return InvitationTarget.group(group, members);
    }).toList();
  }

  /// Extracts all unique user IDs from a collection of invitation targets.
  /// Performs comprehensive user ID extraction from both individual and group targets,
  /// expanding group members to get all affected user IDs. Used for invitation scope
  /// analysis, duplicate detection, and recipient list compilation.
  /// [targets] List of invitation targets to extract user IDs from
  /// Returns a set of unique user IDs represented by all targets.
  static Set<String> extractAllUserIds(List<InvitationTarget> targets) {
    final userIds = <String>{};

    for (final target in targets) {
      userIds.addAll(target.allUserIds);
    }

    return userIds;
  }

  /// Groups invitation targets by type for organized processing and display.
  /// Categorizes targets into type-based groups for efficient processing, UI organization,
  /// and batch operations. Used for creating separated individual and group target sections
  /// in invitation interfaces and processing workflows.
  /// [targets] List of invitation targets to group by type
  /// Returns a map from target type to list of targets of that type.
  static Map<InvitationTargetType, List<InvitationTarget>> groupByType(
    List<InvitationTarget> targets,
  ) {
    final grouped = <InvitationTargetType, List<InvitationTarget>>{};

    for (final target in targets) {
      grouped.putIfAbsent(target.type, () => []).add(target);
    }

    return grouped;
  }

  /// Sorts invitation targets for optimal UI presentation with groups prioritized.
  /// Implements comprehensive target sorting with groups appearing first followed by
  /// alphabetical sorting within each type category. Used for consistent target list
  /// organization in invitation interfaces and selection dialogs.
  /// [targets] List of invitation targets to sort for UI display
  /// Returns a new sorted list of targets optimized for UI presentation.
  static List<InvitationTarget> sortForUI(List<InvitationTarget> targets) {
    final sorted = List<InvitationTarget>.from(targets);
    sorted.sort((a, b) => a.compareTo(b));
    return sorted;
  }

  /// Filters invitation targets based on search text with comprehensive matching.
  /// Performs multi-field search including display names, descriptions, and metadata.
  /// For groups: searches in group descriptions. For individuals: searches in display name.
  /// Implements case-insensitive matching for optimal search user experience.
  /// [targets] List of invitation targets to filter
  /// [searchText] Search query string for target filtering
  /// Returns filtered list of targets matching the search criteria.
  static List<InvitationTarget> filterBySearch(
    List<InvitationTarget> targets,
    String searchText,
  ) {
    if (searchText.isEmpty) return targets;

    final query = searchText.toLowerCase();

    return targets.where((target) {
      // Search in name
      if (target.displayName.toLowerCase().contains(query)) {
        return true;
      }

      // Search in description
      if (target.description.toLowerCase().contains(query)) {
        return true;
      }

      // For groups: search in description from metadata
      if (target.isGroup) {
        final description =
            (target.metadata?['description'] as String?).orEmpty();
        if (description.toLowerCase().contains(query)) {
          return true;
        }
      }

      return false;
    }).toList();
  }

  /// Filters invitation targets by specific type for targeted operations.
  /// Provides type-specific filtering for creating homogeneous target lists.
  /// Used for processing only individuals or only groups in invitation workflows.
  /// [targets] List of invitation targets to filter by type
  /// [type] Target type to filter for (individual or group)
  /// Returns filtered list of targets matching the specified type.
  static List<InvitationTarget> filterByType(
    List<InvitationTarget> targets,
    InvitationTargetType type,
  ) {
    return targets.where((target) => target.type == type).toList();
  }

  /// Gets only individual user targets from a mixed target list.
  /// Convenience method for filtering individual targets from mixed collections.
  /// Used for individual-specific processing and UI sections.
  /// [targets] List of mixed invitation targets
  /// Returns filtered list containing only individual user targets.
  static List<InvitationTarget> individualsOnly(
      List<InvitationTarget> targets) {
    return filterByType(targets, InvitationTargetType.individual);
  }

  /// Gets only group targets from a mixed target list.
  /// Convenience method for filtering group targets from mixed collections.
  /// Used for group-specific processing and bulk invitation operations.
  /// [targets] List of mixed invitation targets
  /// Returns filtered list containing only group targets.
  static List<InvitationTarget> groupsOnly(List<InvitationTarget> targets) {
    return filterByType(targets, InvitationTargetType.group);
  }

  /// Counts the total number of unique users represented by all targets.
  /// Performs comprehensive user counting including group member expansion
  /// to determine the total invitation scope. Used for invitation analytics
  /// and scope validation before sending invitations.
  /// [targets] List of invitation targets to count users from
  /// Returns the total count of unique users across all targets.
  static int getTotalUserCount(List<InvitationTarget> targets) {
    return extractAllUserIds(targets).length;
  }

  /// Checks if a specific user ID is represented in any of the targets.
  /// Performs comprehensive user ID search including group member expansion
  /// to determine if a user would be affected by the target collection.
  /// Used for duplicate detection and invitation scope validation.
  /// [targets] List of invitation targets to search in
  /// [userId] User ID to search for in the target collection
  /// Returns true if the user ID is found in any target (individual or group member).
  static bool containsUser(List<InvitationTarget> targets, String userId) {
    return extractAllUserIds(targets).contains(userId);
  }
}
