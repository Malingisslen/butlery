// lib/models/unified/unified_shopping_list.dart


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'unified_shopping_item.dart';

enum SyncStatus {
  synced, // Synkad med Firebase
  pending, // Väntar på synk
  conflict, // Konflikt som behöver lösas
  local, // Endast lokal (offline)
  error, // Synk-fel
}

enum ListType {
  personal, // Personlig lista
  collaborative, // Delad med andra, real-time sync
  template, // Mall-lista för återanvändning
}

// Alias for compatibility
typedef ShoppingListType = ListType;

enum SharedListPermission {
  view, // Kan bara se listan
  edit, // Kan lägga till/ta bort items
  admin, // Kan redigera behörigheter och ta bort lista
}

/// Enhetlig shopping list som kombinerar alla features från:
/// - ShoppingList (grundläggande funktionalitet)
/// - SharedShoppingList (collaborative features)
///
/// Detta behåller ALL befintlig funktionalitet men gör koden enklare
class UnifiedShoppingList {
  final String id;
  final String name;
  final String ownerId;
  final String ownerDisplayName;
  final List<UnifiedShoppingItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;
  final SyncStatus syncStatus;

  // COLLABORATIVE FEATURES - samma som du har idag
  final ListType type;
  final Map<String, SharedListPermission>
      memberPermissions; // userId -> permission
  final DateTime? lastActivityAt;
  final String? lastActivityByUserId;
  final String? lastActivityByDisplayName;
  final String? description;
  final Map<String, dynamic> settings; // Framtida inställningar
  final List<String> categoryIds; // Related friend categories for bulk sharing
  final bool allowGuestEditing;
  final bool autoRemoveCompleted;

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
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // ===== FACTORY CONSTRUCTORS - samma patterns som du använder =====

  /// Skapa personal shopping list - ERSÄTTER ShoppingList.personal
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

  /// Skapa collaborative shopping list - ERSÄTTER SharedShoppingList
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
    final now = DateTime.now();
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

  // ===== PROPERTIES - BEHÅLLER alla dina befintliga getters =====

  bool get isPersonal => type == ListType.personal;
  bool get isCollaborative => type == ListType.collaborative;
  bool get needsSync => syncStatus == SyncStatus.pending;
  bool get isOnline => syncStatus == SyncStatus.synced;
  bool get hasError => syncStatus == SyncStatus.error;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  int get totalItems => items.length;
  int get itemCount => items.length;  // Alias for compatibility
  int get boughtItems => items.where((item) => item.bought).length;
  int get unboughtItems => totalItems - boughtItems;
  int get memberCount => memberPermissions.length;

  bool get allItemsBought => totalItems > 0 && boughtItems == totalItems;
  double get completionPercentage =>
      totalItems == 0 ? 0.0 : (boughtItems / totalItems) * 100;

  String get summary {
    if (isEmpty) return 'Tom lista';
    if (allItemsBought) return 'Alla $totalItems artiklar köpta ✓';
    return '$unboughtItems av $totalItems artiklar kvar';
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
    if (lastActivityAt == null || lastActivityByDisplayName == null) {
      return 'Ingen aktivitet';
    }

    final timeDiff = DateTime.now().difference(lastActivityAt!);
    String timeText;

    if (timeDiff.inMinutes < 1) {
      timeText = 'nu';
    } else if (timeDiff.inHours < 1) {
      timeText = '${timeDiff.inMinutes} min sedan';
    } else if (timeDiff.inDays < 1) {
      timeText = '${timeDiff.inHours} tim sedan';
    } else {
      timeText = '${timeDiff.inDays} dagar sedan';
    }

    return 'Senaste aktivitet av $lastActivityByDisplayName $timeText';
  }

  bool get hasRecentActivity {
    if (lastActivityAt == null) return false;
    return DateTime.now().difference(lastActivityAt!).inHours < 24;
  }

  // ===== PERMISSION METHODS - REMOVED: Use PermissionService instead =====
  // All permission methods have been migrated to PermissionService for centralized permission management

  // ===== UPDATE METHODS - samma patterns =====

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
  }) {
    return UnifiedShoppingList(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      items: items ?? List.from(this.items),
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
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
    );
  }

  UnifiedShoppingList markAsSynced() {
    return copyWith(
      syncStatus: SyncStatus.synced,
      lastSyncedAt: DateTime.now(),
    );
  }

  UnifiedShoppingList markAsPending() {
    return copyWith(syncStatus: SyncStatus.pending);
  }

  UnifiedShoppingList markAsError() {
    return copyWith(syncStatus: SyncStatus.error);
  }

  // ===== ITEM OPERATIONS - BEHÅLLER alla dina metoder =====

  UnifiedShoppingList addItem(
    UnifiedShoppingItem item, {
    String? userId,
    String? userDisplayName,
  }) {
    final now = DateTime.now();
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
    final now = DateTime.now();
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
    final now = DateTime.now();
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
    final now = DateTime.now();
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
    final now = DateTime.now();
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

  // ===== SERIALIZATION - kompatibel med Firebase =====

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
    };
  }

  /// JSON serialization för cache (konverterar Timestamps till Strings)
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

  /// ✅ NY: JSON deserialization för cache-loading
  factory UnifiedShoppingList.fromJson(Map<String, dynamic> json) {
    return UnifiedShoppingList(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      ownerDisplayName: json['ownerDisplayName'] as String,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) =>
                  UnifiedShoppingItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.parse(json['lastSyncedAt'] as String)
          : null,
      syncStatus: SyncStatus.values.firstWhere(
        (s) => s.name == json['syncStatus'],
        orElse: () => SyncStatus.local,
      ),
      type: ListType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ListType.personal,
      ),
      memberPermissions: (json['memberPermissions'] as Map<String, dynamic>?)
              ?.map((userId, permissionName) => MapEntry(
                  userId,
                  SharedListPermission.values.firstWhere(
                    (p) => p.name == permissionName,
                    orElse: () => SharedListPermission.view,
                  ))) ??
          {},
      lastActivityAt: json['lastActivityAt'] != null
          ? DateTime.parse(json['lastActivityAt'] as String)
          : null,
      lastActivityByUserId: json['lastActivityByUserId'] as String?,
      lastActivityByDisplayName: json['lastActivityByDisplayName'] as String?,
      description: json['description'] as String?,
      settings: Map<String, dynamic>.from(json['settings'] as Map? ?? {}),
      categoryIds: List<String>.from(json['categoryIds'] as List? ?? []),
      allowGuestEditing: json['allowGuestEditing'] as bool? ?? true,
      autoRemoveCompleted: json['autoRemoveCompleted'] as bool? ?? false,
    );
  }

  factory UnifiedShoppingList.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UnifiedShoppingList(
      id: doc.id,
      name: data['name'] as String,
      ownerId: data['ownerId'] as String,
      ownerDisplayName: data['ownerDisplayName'] as String,
      items: (data['items'] as List<dynamic>?)
              ?.map((item) =>
                  UnifiedShoppingItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSyncedAt: (data['lastSyncedAt'] as Timestamp?)?.toDate(),
      syncStatus: SyncStatus.synced, // From Firebase = synced
      type: ListType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => ListType.personal,
      ),
      memberPermissions: (data['memberPermissions'] as Map<String, dynamic>?)
              ?.map((userId, permissionName) => MapEntry(
                  userId,
                  SharedListPermission.values.firstWhere(
                    (p) => p.name == permissionName,
                    orElse: () => SharedListPermission.view,
                  ))) ??
          {},
      lastActivityAt: (data['lastActivityAt'] as Timestamp?)?.toDate(),
      lastActivityByUserId: data['lastActivityByUserId'] as String?,
      lastActivityByDisplayName: data['lastActivityByDisplayName'] as String?,
      description: data['description'] as String?,
      settings: (data['settings'] as Map<String, dynamic>?) ?? {},
      categoryIds: List<String>.from(data['categoryIds'] ?? []),
      allowGuestEditing: data['allowGuestEditing'] as bool? ?? true,
      autoRemoveCompleted: data['autoRemoveCompleted'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'UnifiedShoppingList(id: $id, name: $name, items: $totalItems, type: $type, sync: $syncStatus)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnifiedShoppingList &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
