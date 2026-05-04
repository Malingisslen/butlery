/// Comprehensive unified shopping list model providing advanced shopping list management with collaborative features.
/// This model implements sophisticated shopping list management following Single Responsibility Principle,
/// handling all aspects of shopping lists including basic functionality, collaborative features, real-time
/// synchronization, and comprehensive member management. It provides complete unified shopping list
/// capabilities while maintaining clean separation from UI concerns and individual item management.
/// **Single Responsibility Focus:**
/// This model exclusively handles shopping list management and coordination:
/// - **Unified List Management**: Seamlessly handles personal, collaborative, and template shopping lists
/// - **Real-Time Synchronization**: Complete sync status management with conflict resolution and offline support
/// - **Collaborative Features**: Advanced member management with permission-based access control and activity tracking
/// - **List Operations**: Comprehensive item operations with user attribution and collaborative tracking
/// **What This Model Does NOT Handle:**
/// - Individual shopping item creation and management (handled by UnifiedShoppingItem)
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Shopping list persistence and storage operations (handled by repositories and services)
/// - Permission validation and enforcement (handled by PermissionService for centralized management)
/// **Unified Shopping List Features:**
/// - **Triple-Mode Support**: Personal lists, collaborative sharing, and reusable templates with seamless transitions
/// - **Real-Time Synchronization**: Complete sync status management with conflict resolution and offline capabilities
/// - **Advanced Collaboration**: Member management with granular permissions and real-time activity tracking
/// - **Comprehensive Analytics**: List completion tracking, member activity summaries, and progress analytics
/// - **Swedish Localization**: Complete Swedish language support for status messages and activity summaries
/// **Usage Examples:**
/// ```dart
/// // Create personal shopping list
/// final personalList = UnifiedShoppingList.personal(
///   name: 'Veckans inköp',
///   ownerId: currentUserId,
///   ownerDisplayName: 'Anna Andersson',
///   items: [milk, bread, eggs],
/// );
/// // Create collaborative shopping list
/// final collabList = UnifiedShoppingList.collaborative(
///   name: 'Gemensam handlingslista',
///   ownerId: currentUserId,
///   ownerDisplayName: 'Anna Andersson',
///   memberPermissions: {
///     friend1Id: SharedListPermission.edit,
///     friend2Id: SharedListPermission.view,
///   },
///   description: 'Lista för helgens middag',
///   allowGuestEditing: true,
/// );
/// // List operations with user tracking
/// final updatedList = collabList
///   .addItem(newItem, userId: currentUserId, userDisplayName: 'Erik')
///   .toggleItemBought(itemId, userId: currentUserId, userDisplayName: 'Erik');
/// // Check list status and analytics
/// print(updatedList.summary); // "2 av 5 artiklar kvar"
/// print(updatedList.completionPercentage); // 60.0
/// print(updatedList.activitySummary); // "Senaste aktivitet av Erik 5 min sedan"
/// ```

// lib/models/unified/unified_shopping_list.dart

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Enumeration defining synchronization status for shopping list data management.
/// Provides comprehensive sync state tracking for offline-first shopping list functionality
/// with conflict resolution and error handling capabilities.
enum SyncStatus {
  /// Successfully synchronized with Firebase backend.
  synced, // Synkad med Firebase

  /// Pending synchronization with backend, changes waiting to be uploaded.
  pending, // Waiting for sync

  /// Synchronization conflict detected, requires user resolution.
  conflict, // Conflict that needs resolution

  /// Local-only data, not synchronized with backend (offline mode).
  local, // Endast lokal (offline)

  /// Synchronization error occurred, retry or manual intervention needed.
  error, // Synk-fel
}

/// Enumeration defining shopping list types for different usage patterns.
/// Supports multiple list types with different behavioral characteristics and
/// collaboration features for flexible shopping list management.
enum ListType {
  /// Personal shopping list for individual use without collaboration.
  personal, // Personlig lista

  /// Collaborative shopping list shared with other users with real-time sync.
  collaborative, // Delad med andra, real-time sync

  /// Template shopping list for reuse and duplication across users.
  template, // Template list for reuse
}

/// Alias for backward compatibility with legacy code.
typedef ShoppingListType = ListType;

/// Enumeration defining permission levels for collaborative shopping list access.
/// Provides granular access control for collaborative shopping lists with
/// hierarchical permission management and administrative capabilities.
enum SharedListPermission {
  /// View-only permission, can see list and items but cannot modify.
  view, // Kan bara se listan

  /// Edit permission, can add, remove, and modify items in the list.
  edit, // Can add/remove items

  /// Administrative permission, can manage permissions and delete the list.
  admin, // Can edit permissions and delete list
}

/// Comprehensive unified shopping list with triple-mode support and collaborative features.
/// Represents a complete shopping list with all associated metadata including items, collaboration
/// settings, synchronization status, and comprehensive member management. Supports personal,
/// collaborative, and template shopping list modes with seamless mode transitions.
class UnifiedShoppingList {
  /// Unique identifier for this shopping list instance.
  final String id;

  /// Name of the shopping list for identification and display.
  /// The primary identifier that users see and use to recognize the list.
  final String name;

  /// User identifier of the shopping list owner.
  /// References the user who created and owns the shopping list with administrative privileges.
  final String ownerId;

  /// Cached display name of the list owner for UI performance optimization.
  /// Stored locally to avoid additional user profile lookups during list display and attribution.
  final String ownerDisplayName;

  /// List of shopping items contained within this shopping list.
  /// Complete collection of UnifiedShoppingItem instances that make up the shopping list content.
  final List<UnifiedShoppingItem> items;

  /// Timestamp when the shopping list was originally created.
  /// Used for chronological tracking and list organization by creation date.
  final DateTime createdAt;

  /// Timestamp when the shopping list was last updated.
  /// Tracks the most recent modification for synchronization and freshness determination.
  final DateTime updatedAt;

  /// Optional timestamp when the list was last synchronized with the backend.
  /// Used for sync status tracking and determining data freshness for offline-first functionality.
  final DateTime? lastSyncedAt;

  /// Current synchronization status of the shopping list.
  /// Tracks sync state for offline-first functionality with conflict resolution and error handling.
  final SyncStatus syncStatus;

  /// Collaborative features and advanced shopping list metadata.

  /// Type classification of the shopping list determining its behavioral characteristics.
  /// Controls whether the list is personal, collaborative, or a reusable template.
  final ListType type;

  /// Member permissions mapping for collaborative access control.
  /// Maps user IDs to their permission levels for granular collaborative list management.
  final Map<String, SharedListPermission>
      memberPermissions; // userId -> permission

  /// Optional timestamp of the most recent activity on the shopping list.
  /// Used for activity tracking and determining list engagement for collaborative features.
  final DateTime? lastActivityAt;

  /// Optional user identifier who performed the most recent activity.
  /// Tracks the last user to modify the list for collaborative attribution and activity summaries.
  final String? lastActivityByUserId;

  /// Optional display name of the user who performed the most recent activity.
  /// Cached display name for performance optimization in activity summaries and collaborative UI.
  final String? lastActivityByDisplayName;

  /// Optional description providing additional context for the shopping list.
  /// Allows users to add detailed information about the list's purpose or special instructions.
  final String? description;

  /// Flexible settings container for future feature extensions.
  /// Extensible settings system for storing list-specific configuration and preferences.
  final Map<String, dynamic> settings; // Future settings

  /// List of friend category IDs for bulk sharing operations.
  /// References friend categories that can be used for efficient bulk sharing of the shopping list.
  final List<String> categoryIds; // Related friend categories for bulk sharing

  /// Flag indicating whether guest users can edit the collaborative list.
  /// Controls editing permissions for users without explicit member permissions in collaborative lists.
  final bool allowGuestEditing;

  /// Flag indicating whether completed items should be automatically removed.
  /// Controls automatic cleanup behavior for purchased items to maintain list cleanliness.
  final bool autoRemoveCompleted;

  /// Optional field tracking the origin of collaborative lists to prevent duplicates.
  /// Used to distinguish between collaborative lists created explicitly vs those created
  /// from shared list acceptance. Helps prevent showing duplicates in the shopping list dropdown.
  /// - null: Explicitly created collaborative list or personal list (show in dropdown)
  /// - 'shared': Created from accepting a shared list invitation (don't show in dropdown)
  final String? collaborativeOrigin;

  /// Creates a new unified shopping list with comprehensive metadata and automatic ID generation.
  /// This constructor provides complete shopping list initialization with support for personal,
  /// collaborative, and template shopping lists. All collaborative features are optional and
  /// default to appropriate values for different list types.
  /// [id] Optional custom identifier, auto-generated UUID if not provided
  /// [name] Required list name for identification and display
  /// [ownerId] Required owner user ID for ownership and administrative privileges
  /// [ownerDisplayName] Required owner display name for collaborative UI and attribution
  /// [items] List of shopping items, defaults to empty list for new lists
  /// [createdAt] Creation timestamp, defaults to current time for new lists
  /// [updatedAt] Last update timestamp, defaults to current time for new lists
  /// [lastSyncedAt] Optional last sync timestamp for synchronization tracking
  /// [syncStatus] Synchronization status, defaults to local for new lists
  /// [type] List type classification, defaults to personal for individual use
  /// [memberPermissions] Member permissions mapping, defaults to empty for personal lists
  /// [lastActivityAt] Optional last activity timestamp for collaborative tracking
  /// [lastActivityByUserId] Optional last activity user ID for attribution
  /// [lastActivityByDisplayName] Optional last activity display name for UI
  /// [description] Optional list description for additional context
  /// [settings] Flexible settings container, defaults to empty for future extensions
  /// [categoryIds] Friend category IDs for bulk sharing, defaults to empty
  /// [allowGuestEditing] Guest editing permission flag, defaults to true for accessibility
  /// [autoRemoveCompleted] Auto-removal of completed items flag, defaults to false for safety
  UnifiedShoppingList({
    String? id,
    required this.name,
    required this.ownerId,
    required this.ownerDisplayName,
    this.items = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastSyncedAt,
    this.syncStatus = SyncStatus.local,
    this.type = ListType.personal,
    this.memberPermissions = const {},
    this.lastActivityAt,
    this.lastActivityByUserId,
    this.lastActivityByDisplayName,
    this.description,
    this.settings = const {},
    this.categoryIds = const [],
    this.allowGuestEditing = true,
    this.autoRemoveCompleted = false,
    this.collaborativeOrigin,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? clock.now(),
        updatedAt = updatedAt ?? clock.now();

  /// Factory constructors for simplified shopping list creation with specific configurations.

  /// Creates a personal shopping list optimized for individual use without collaboration.
  /// This factory provides simplified creation for non-collaborative shopping with minimal
  /// required parameters and no member management overhead. Ideal for personal shopping lists
  /// where collaboration features are not needed. Replaces legacy ShoppingList.personal.
  /// [name] Required list name for identification and display
  /// [ownerId] Required owner user ID for ownership and administrative privileges
  /// [ownerDisplayName] Required owner display name for UI display and attribution
  /// [items] Optional list of shopping items, defaults to empty for new lists
  /// Returns a new [UnifiedShoppingList] configured for personal use with auto-generated ID.
  factory UnifiedShoppingList.personal({
    required String name,
    required String ownerId,
    required String ownerDisplayName,
    List<UnifiedShoppingItem>? items,
  }) {
    return UnifiedShoppingList(
      name: name,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      items: items ?? [],
      type: ListType.personal,
    );
  }

  /// Creates a collaborative shopping list optimized for shared use with member management.
  /// This factory provides comprehensive creation for collaborative shopping with full
  /// member management, permissions, and activity tracking. Automatically sets up proper
  /// collaborative features with current timestamp initialization. Replaces legacy SharedShoppingList.
  /// [name] Required list name for identification and display
  /// [ownerId] Required owner user ID for ownership and administrative privileges
  /// [ownerDisplayName] Required owner display name for collaborative UI and attribution
  /// [memberPermissions] Required member permissions mapping for access control
  /// [items] Optional list of shopping items, defaults to empty for new lists
  /// [description] Optional list description for additional context and communication
  /// [categoryIds] Optional friend category IDs for bulk sharing operations
  /// [allowGuestEditing] Guest editing permission flag, defaults to true for accessibility
  /// [autoRemoveCompleted] Auto-removal of completed items flag, defaults to false for safety
  /// Returns a new [UnifiedShoppingList] configured for collaboration with current timestamps.
  /// **Permission Management:** Owner automatically receives admin permissions regardless
  /// of the provided memberPermissions map to ensure proper administrative access.
  factory UnifiedShoppingList.collaborative({
    required String name,
    required String ownerId,
    required String ownerDisplayName,
    required Map<String, SharedListPermission> memberPermissions,
    List<UnifiedShoppingItem>? items,
    String? description,
    List<String>? categoryIds,
    bool allowGuestEditing = true,
    bool autoRemoveCompleted = false,
  }) {
    final now = clock.now();
    final permissions =
        Map<String, SharedListPermission>.from(memberPermissions);
    permissions[ownerId] = SharedListPermission.admin; // Owner gets admin

    return UnifiedShoppingList(
      name: name,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      items: items ?? [],
      type: ListType.collaborative,
      memberPermissions: permissions,
      description: description,
      categoryIds: categoryIds ?? [],
      allowGuestEditing: allowGuestEditing,
      autoRemoveCompleted: autoRemoveCompleted,
      lastActivityAt: now,
      lastActivityByUserId: ownerId,
      lastActivityByDisplayName: ownerDisplayName,
    );
  }

  /// List state and analytics properties for shopping list management and UI display.

  /// Checks if this shopping list is configured for personal use without collaboration.
  /// Returns true if the list type is personal, indicating individual usage without member management.
  bool get isPersonal => type == ListType.personal;
  bool get isCollaborative => type == ListType.collaborative;
  bool get needsSync => syncStatus == SyncStatus.pending;
  bool get isOnline => syncStatus == SyncStatus.synced;
  bool get hasError => syncStatus == SyncStatus.error;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  int get totalItems => items.length;
  int get itemCount => items.length; // Alias for compatibility
  int get boughtItems => items.where((item) => item.bought).length;
  int get unboughtItems => totalItems - boughtItems;
  int get memberCount => memberPermissions.length;

  /// Gets list of collaborator user IDs for test compatibility.
  List<String> get collaborators => memberPermissions.keys.toList();

  bool get allItemsBought => totalItems > 0 && boughtItems == totalItems;
  double get completionPercentage =>
      totalItems == 0 ? 0.0 : (boughtItems / totalItems) * 100;

  String get summary {
    final l = AppLocale.current;
    if (isEmpty) return l.shoppingListEmpty;
    if (allItemsBought) return l.shoppingListAllBought(totalItems);
    return l.shoppingListItemsRemaining(unboughtItems, totalItems);
  }

  String get syncStatusEmoji {
    switch (syncStatus) {
      case SyncStatus.synced:
        return '✅';
      case SyncStatus.pending:
        return '🔄';
      case SyncStatus.conflict:
        return '⚠️';
      case SyncStatus.local:
        return '📱';
      case SyncStatus.error:
        return '❌';
    }
  }

  String get activitySummary {
    final l = AppLocale.current;
    if (lastActivityAt == null || lastActivityByDisplayName == null) {
      return l.shoppingListNoActivity;
    }

    final timeDiff = clock.now().difference(lastActivityAt!);
    String timeText;

    if (timeDiff.inMinutes < 1) {
      timeText = l.shoppingListActivityNow;
    } else if (timeDiff.inHours < 1) {
      timeText = l.shoppingListActivityMinAgo(timeDiff.inMinutes);
    } else if (timeDiff.inDays < 1) {
      timeText = l.shoppingListActivityHoursAgo(timeDiff.inHours);
    } else {
      timeText = l.shoppingListActivityDaysAgo(timeDiff.inDays);
    }

    return l.shoppingListLastActivityBy(lastActivityByDisplayName!, timeText);
  }

  bool get hasRecentActivity {
    if (lastActivityAt == null) return false;
    return clock.now().difference(lastActivityAt!).inHours < 24;
  }

  UnifiedShoppingList copyWith({
    String? name,
    List<UnifiedShoppingItem>? items,
    DateTime? updatedAt,
    DateTime? lastSyncedAt,
    SyncStatus? syncStatus,
    Map<String, SharedListPermission>? memberPermissions,
    DateTime? lastActivityAt,
    String? lastActivityByUserId,
    String? lastActivityByDisplayName,
    String? description,
    Map<String, dynamic>? settings,
    List<String>? categoryIds,
    bool? allowGuestEditing,
    bool? autoRemoveCompleted,
    String? collaborativeOrigin,
  }) {
    return UnifiedShoppingList(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      items: items ?? List.from(this.items),
      createdAt: createdAt,
      updatedAt: updatedAt ?? clock.now(),
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      type: type,
      memberPermissions: memberPermissions ?? Map.from(this.memberPermissions),
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      lastActivityByUserId: lastActivityByUserId ?? this.lastActivityByUserId,
      lastActivityByDisplayName:
          lastActivityByDisplayName ?? this.lastActivityByDisplayName,
      description: description ?? this.description,
      settings: settings ?? Map.from(this.settings),
      categoryIds: categoryIds ?? List.from(this.categoryIds),
      allowGuestEditing: allowGuestEditing ?? this.allowGuestEditing,
      autoRemoveCompleted: autoRemoveCompleted ?? this.autoRemoveCompleted,
      collaborativeOrigin: collaborativeOrigin ?? this.collaborativeOrigin,
    );
  }

  UnifiedShoppingList markAsSynced() {
    return copyWith(
      syncStatus: SyncStatus.synced,
      lastSyncedAt: clock.now(),
    );
  }

  UnifiedShoppingList markAsPending() {
    return copyWith(syncStatus: SyncStatus.pending);
  }

  UnifiedShoppingList markAsError() {
    return copyWith(syncStatus: SyncStatus.error);
  }

  /// Item operations methods for shopping list content management with collaborative tracking.

  /// Adds a new shopping item to the list with collaborative user attribution.
  /// Implements item addition functionality with automatic timestamp updates, sync status
  /// management, and collaborative activity tracking for shared shopping lists.
  /// Returns a new [UnifiedShoppingList] instance with the added item and updated metadata.
  UnifiedShoppingList addItem(
    UnifiedShoppingItem item, {
    String? userId,
    String? userDisplayName,
  }) {
    final now = clock.now();
    return copyWith(
      items: [...items, item],
      updatedAt: now,
      syncStatus: SyncStatus.pending,
      lastActivityAt: now,
      lastActivityByUserId: userId,
      lastActivityByDisplayName: userDisplayName,
    );
  }

  UnifiedShoppingList removeItem(
    String itemId, {
    String? userId,
    String? userDisplayName,
  }) {
    final now = clock.now();
    return copyWith(
      items: items.where((item) => item.id != itemId).toList(),
      updatedAt: now,
      syncStatus: SyncStatus.pending,
      lastActivityAt: now,
      lastActivityByUserId: userId,
      lastActivityByDisplayName: userDisplayName,
    );
  }

  UnifiedShoppingList updateItem(
    String itemId,
    UnifiedShoppingItem updatedItem, {
    String? userId,
    String? userDisplayName,
  }) {
    final now = clock.now();
    final updatedItems = items.map((item) {
      return item.id == itemId ? updatedItem : item;
    }).toList();

    return copyWith(
      items: updatedItems,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
      lastActivityAt: now,
      lastActivityByUserId: userId,
      lastActivityByDisplayName: userDisplayName,
    );
  }

  UnifiedShoppingList toggleItemBought(
    String itemId, {
    String? userId,
    String? userDisplayName,
  }) {
    final item = items.firstWhere((item) => item.id == itemId);
    final updatedItem = item.togglePurchased(
      userId: userId,
      userDisplayName: userDisplayName,
    );

    return updateItem(itemId, updatedItem,
        userId: userId, userDisplayName: userDisplayName);
  }

  UnifiedShoppingList clearBoughtItems({
    String? userId,
    String? userDisplayName,
  }) {
    final now = clock.now();
    final unboughtItems = items.where((item) => !item.bought).toList();

    return copyWith(
      items: unboughtItems,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
      lastActivityAt: now,
      lastActivityByUserId: userId,
      lastActivityByDisplayName: userDisplayName,
    );
  }

  UnifiedShoppingList uncheckAllItems({
    String? userId,
    String? userDisplayName,
  }) {
    final now = clock.now();
    final uncheckedItems =
        items.map((item) => item.copyWith(bought: false)).toList();

    return copyWith(
      items: uncheckedItems,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
      lastActivityAt: now,
      lastActivityByUserId: userId,
      lastActivityByDisplayName: userDisplayName,
    );
  }

  /// Data persistence and serialization methods for Firestore and caching integration.

  /// Converts the shopping list to Firestore-compatible format for persistence.
  /// Transforms all shopping list data including items and collaborative metadata into Firestore format
  /// with proper timestamp handling and member permissions serialization for database efficiency.
  /// Returns a map containing all shopping list data formatted for Firestore persistence.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
      'items': items.map((item) => item.toFirestore()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastSyncedAt':
          lastSyncedAt != null ? Timestamp.fromDate(lastSyncedAt!) : null,
      'type': type.name,
      'memberPermissions': memberPermissions.map(
        (userId, permission) => MapEntry(userId, permission.name),
      ),
      'lastActivityAt':
          lastActivityAt != null ? Timestamp.fromDate(lastActivityAt!) : null,
      'lastActivityByUserId': lastActivityByUserId,
      'lastActivityByDisplayName': lastActivityByDisplayName,
      'description': description,
      'settings': settings,
      'categoryIds': categoryIds,
      'allowGuestEditing': allowGuestEditing,
      'autoRemoveCompleted': autoRemoveCompleted,
      'collaborativeOrigin': collaborativeOrigin,
    };
  }

  /// Converts the shopping list to JSON format for caching and client-side storage.
  /// Provides JSON serialization for client-side caching, local storage, and data transfer
  /// with ISO timestamp formatting and complete collaborative metadata serialization.
  /// Returns a JSON-compatible map with all shopping list data properly formatted.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
      'items': items.map((item) => item.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'syncStatus': syncStatus.name,
      'type': type.name,
      'memberPermissions': memberPermissions.map(
        (userId, permission) => MapEntry(userId, permission.name),
      ),
      'lastActivityAt': lastActivityAt?.toIso8601String(),
      'lastActivityByUserId': lastActivityByUserId,
      'lastActivityByDisplayName': lastActivityByDisplayName,
      'description': description,
      'settings': settings,
      'categoryIds': categoryIds,
      'allowGuestEditing': allowGuestEditing,
      'autoRemoveCompleted': autoRemoveCompleted,
    };
  }

  /// Creates a shopping list instance from JSON data for caching and deserialization.
  /// Transforms JSON cache data into a complete [UnifiedShoppingList] instance with proper
  /// type conversion and collaborative metadata deserialization for client-side caching support.
  /// Returns a new [UnifiedShoppingList] instance with all data properly parsed from JSON.
  factory UnifiedShoppingList.fromJson(Map<String, dynamic> json) {
    final lastSyncedAtStr =
        SerializationUtils.safeNullableString(json, 'lastSyncedAt');
    final lastActivityAtStr =
        SerializationUtils.safeNullableString(json, 'lastActivityAt');

    return UnifiedShoppingList(
      id: SerializationUtils.safeString(json, 'id'),
      name: SerializationUtils.safeString(json, 'name'),
      ownerId: SerializationUtils.safeString(json, 'ownerId'),
      ownerDisplayName: SerializationUtils.safeString(json, 'ownerDisplayName'),
      items: SerializationUtils.safeObjectList(
        json,
        'items',
        (item) => UnifiedShoppingItem.fromJson(item),
      ),
      createdAt: SerializationUtils.safeRequiredDateTime(json, 'createdAt'),
      updatedAt: SerializationUtils.safeRequiredDateTime(json, 'updatedAt'),
      lastSyncedAt:
          lastSyncedAtStr != null ? DateTime.tryParse(lastSyncedAtStr) : null,
      syncStatus: SyncStatus.values.firstWhere(
        (s) => s.name == SerializationUtils.safeString(json, 'syncStatus'),
        orElse: () => SyncStatus.local,
      ),
      type: ListType.values.firstWhere(
        (t) => t.name == SerializationUtils.safeString(json, 'type'),
        orElse: () => ListType.personal,
      ),
      memberPermissions: SerializationUtils.safeMap(json, 'memberPermissions')
          .map((userId, permissionName) => MapEntry(
              userId,
              SharedListPermission.values.firstWhere(
                (p) => p.name == permissionName,
                orElse: () => SharedListPermission.view,
              ))),
      lastActivityAt: lastActivityAtStr != null
          ? DateTime.tryParse(lastActivityAtStr)
          : null,
      lastActivityByUserId:
          SerializationUtils.safeNullableString(json, 'lastActivityByUserId'),
      lastActivityByDisplayName: SerializationUtils.safeNullableString(
          json, 'lastActivityByDisplayName'),
      description: SerializationUtils.safeNullableString(json, 'description'),
      settings: SerializationUtils.safeMap(json, 'settings'),
      categoryIds: SerializationUtils.safeStringList(json, 'categoryIds'),
      allowGuestEditing: SerializationUtils.safeBool(json, 'allowGuestEditing',
          defaultValue: true),
      autoRemoveCompleted:
          SerializationUtils.safeBool(json, 'autoRemoveCompleted'),
    );
  }

  /// Creates a shopping list instance from repository data with robust timestamp parsing.
  /// Transforms repository data into a complete [UnifiedShoppingList] instance with proper
  /// type conversion, timestamp parsing, and collaborative metadata deserialization for
  /// robust data recovery from various data sources.
  /// Returns a new [UnifiedShoppingList] instance with all data properly parsed from repository data.
  factory UnifiedShoppingList.fromMap(String id, Map<String, dynamic> data) {
    return UnifiedShoppingList(
      id: id,
      name: SerializationUtils.safeString(data, 'name'),
      ownerId: SerializationUtils.safeString(data, 'ownerId'),
      ownerDisplayName: SerializationUtils.safeString(data, 'ownerDisplayName'),
      items: SerializationUtils.safeObjectList(
        data,
        'items',
        (item) => UnifiedShoppingItem.fromFirestore(item),
      ),
      createdAt: data['createdAt'] is DateTime
          ? data['createdAt'] as DateTime
          : SerializationUtils.safeRequiredDateTime(data, 'createdAt'),
      updatedAt: data['updatedAt'] is DateTime
          ? data['updatedAt'] as DateTime
          : SerializationUtils.safeRequiredDateTime(data, 'updatedAt'),
      lastSyncedAt: data['lastSyncedAt'] is DateTime
          ? data['lastSyncedAt'] as DateTime
          : SerializationUtils.safeDateTime(data, 'lastSyncedAt'),
      syncStatus: SyncStatus.synced, // From Firebase = synced
      type: ListType.values.firstWhere(
        (t) => t.name == SerializationUtils.safeString(data, 'type'),
        orElse: () => ListType.personal,
      ),
      memberPermissions: SerializationUtils.safeMap(data, 'memberPermissions')
          .map((userId, permissionName) => MapEntry(
              userId,
              SharedListPermission.values.firstWhere(
                (p) => p.name == permissionName,
                orElse: () => SharedListPermission.view,
              ))),
      lastActivityAt: data['lastActivityAt'] is DateTime
          ? data['lastActivityAt'] as DateTime
          : SerializationUtils.safeDateTime(data, 'lastActivityAt'),
      lastActivityByUserId:
          SerializationUtils.safeNullableString(data, 'lastActivityByUserId'),
      lastActivityByDisplayName: SerializationUtils.safeNullableString(
          data, 'lastActivityByDisplayName'),
      description: SerializationUtils.safeNullableString(data, 'description'),
      settings: SerializationUtils.safeMap(data, 'settings'),
      categoryIds: SerializationUtils.safeStringList(data, 'categoryIds'),
      allowGuestEditing: SerializationUtils.safeBool(data, 'allowGuestEditing',
          defaultValue: true),
      autoRemoveCompleted:
          SerializationUtils.safeBool(data, 'autoRemoveCompleted'),
      collaborativeOrigin:
          SerializationUtils.safeNullableString(data, 'collaborativeOrigin'),
    );
  }

  factory UnifiedShoppingList.fromFirestore(DocumentSnapshot doc) {
    return UnifiedShoppingList.fromMap(
        doc.id, doc.data() as Map<String, dynamic>);
  }

  /// Standard object methods for debugging, comparison, and identity management.

  /// Returns a string representation of the shopping list for debugging and logging.
  /// Provides essential list information in a readable format for development
  /// and debugging purposes with list name, item count, type, and sync status.
  @override
  String toString() {
    return 'UnifiedShoppingList(id: $id, name: $name, items: $totalItems, type: $type, sync: $syncStatus)';
  }

  /// Compares two shopping lists for equality based on unique identifier.
  /// Uses list ID for equality comparison ensuring consistent object identity
  /// across different instances of the same shopping list data.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnifiedShoppingList &&
          runtimeType == other.runtimeType &&
          id == other.id;

  /// Generates hash code based on unique shopping list identifier.
  /// Provides consistent hash code generation for use in collections and
  /// data structures requiring hash-based operations and list identification.
  @override
  int get hashCode => id.hashCode;
}
