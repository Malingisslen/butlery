// lib/models/shopping_list.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'shopping_item.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Shopping List Model (Multi-list support)
/// File: models/shopping_list.dart
/// Quick Guide: Inköpslista med full Firebase-synk och offline support
/// Dependencies IN: cloud_firestore, uuid, shopping_item.dart
/// Dependencies OUT: ShoppingListService, shopping list viewmodels
/// Data flow: Hive (cache) ↔ ShoppingList ↔ Firebase (source of truth)
/// State management: Immutable med copyWith pattern
/// Purpose: Hantera flera namngivna inköpslistor med real-time Firebase synk
/// Common issues: Sync conflicts, offline/online transitions
/// Test coverage: 0%
/// Performance: ⚡ Offline-first med optimistic updates
/// Analytics: ✅ List usage patterns, popular items
/// Code smells: ✅ Clean MVVM separation
/// Connected to: ShoppingItem, SharedShoppingList, Firebase
/// Used in phases: Multi-list shopping feature

enum SyncStatus {
  synced, // Synkad med Firebase
  pending, // Väntar på synk
  conflict, // Konflikt som behöver lösas
  local, // Endast lokal (offline)
}

class ShoppingList {
  final String id;
  final String name;
  final String ownerId; // Firebase user ID
  final List<ShoppingItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;
  final SyncStatus syncStatus;
  final bool isShared; // Om listan är delad med andra
  final List<String> sharedWithUserIds; // Om delad
  final Map<String, dynamic> metadata;

  ShoppingList({
    required this.id,
    required this.name,
    required this.ownerId,
    this.items = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastSyncedAt,
    this.syncStatus = SyncStatus.local,
    this.isShared = false,
    this.sharedWithUserIds = const [],
    this.metadata = const {},
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Factory constructor med auto-genererat ID
  factory ShoppingList.create({
    required String name,
    required String ownerId,
    List<ShoppingItem>? items,
  }) {
    return ShoppingList(
      id: const Uuid().v4(),
      name: name,
      ownerId: ownerId,
      items: items ?? [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Skapa från veckomeny
  factory ShoppingList.fromMenu({
    required String name,
    required String ownerId,
    required List<ShoppingItem> items,
  }) {
    return ShoppingList.create(
      name: name,
      ownerId: ownerId,
      items: items,
    );
  }

  /// Kopiera med uppdaterade värden
  ShoppingList copyWith({
    String? name,
    List<ShoppingItem>? items,
    DateTime? updatedAt,
    DateTime? lastSyncedAt,
    SyncStatus? syncStatus,
    bool? isShared,
    List<String>? sharedWithUserIds,
    Map<String, dynamic>? metadata,
  }) {
    return ShoppingList(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId,
      items: items ?? List.from(this.items),
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isShared: isShared ?? this.isShared,
      sharedWithUserIds: sharedWithUserIds ?? List.from(this.sharedWithUserIds),
      metadata: metadata ?? Map.from(this.metadata),
    );
  }

  /// Markera som synkad
  ShoppingList markAsSynced() {
    return copyWith(
      syncStatus: SyncStatus.synced,
      lastSyncedAt: DateTime.now(),
    );
  }

  /// Markera som pending
  ShoppingList markAsPending() {
    return copyWith(
      syncStatus: SyncStatus.pending,
    );
  }

  /// Lägg till artikel
  ShoppingList addItem(ShoppingItem item) {
    return copyWith(
      items: [...items, item],
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
  }

  /// Ta bort artikel
  ShoppingList removeItem(int index) {
    if (index < 0 || index >= items.length) return this;

    final updatedItems = List<ShoppingItem>.from(items)..removeAt(index);
    return copyWith(
      items: updatedItems,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
  }

  /// Lägg till artikel på specifik plats (för undo)
  ShoppingList insertItemAt(int index, ShoppingItem item) {
    final updatedItems = List<ShoppingItem>.from(items);
    if (index < 0 || index > updatedItems.length) {
      updatedItems.add(item);
    } else {
      updatedItems.insert(index, item);
    }

    return copyWith(
      items: updatedItems,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
  }

  /// Uppdatera artikel
  ShoppingList updateItem(int index, ShoppingItem item) {
    if (index < 0 || index >= items.length) return this;

    final updatedItems = List<ShoppingItem>.from(items);
    updatedItems[index] = item;

    return copyWith(
      items: updatedItems,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
  }

  /// Toggle köpt-status för artikel
  ShoppingList toggleItemBought(int index) {
    if (index < 0 || index >= items.length) return this;

    final item = items[index];
    final updatedItem = ShoppingItem(
      name: item.name,
      amount: item.amount,
      unit: item.unit,
      category: item.category,
      bought: !item.bought,
    );

    return updateItem(index, updatedItem);
  }

  /// Rensa alla köpta artiklar
  ShoppingList clearBoughtItems() {
    final unboughtItems = items.where((item) => !item.bought).toList();
    return copyWith(
      items: unboughtItems,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
  }

  /// Rensa alla checkmarkeringar
  ShoppingList uncheckAllItems() {
    final uncheckedItems = items
        .map((item) => ShoppingItem(
              name: item.name,
              amount: item.amount,
              unit: item.unit,
              category: item.category,
              bought: false,
            ))
        .toList();

    return copyWith(
      items: uncheckedItems,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
  }

  // ===== GETTERS =====

  int get itemCount => items.length;
  int get boughtCount => items.where((item) => item.bought).length;
  int get unboughtCount => itemCount - boughtCount;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  bool get allItemsBought => isNotEmpty && boughtCount == itemCount;
  bool get needsSync => syncStatus == SyncStatus.pending;

  /// Få sammanfattning för UI
  String get summary {
    if (isEmpty) return 'Tom lista';
    if (allItemsBought) return 'Alla $itemCount artiklar köpta ✓';
    return '$unboughtCount av $itemCount artiklar kvar';
  }

  /// Formaterat uppdateringsdatum
  String get lastUpdatedDisplay {
    final now = DateTime.now();
    final diff = now.difference(updatedAt);

    if (diff.inMinutes < 1) return 'Just nu';
    if (diff.inHours < 1) return '${diff.inMinutes} min sedan';
    if (diff.inDays < 1) return '${diff.inHours} tim sedan';
    if (diff.inDays < 7) return '${diff.inDays} dagar sedan';

    return '${updatedAt.day}/${updatedAt.month}';
  }

  /// Sync status ikon för UI
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
    }
  }

  // ===== FIREBASE SERIALIZATION =====

  /// Konvertera till Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'ownerId': ownerId,
      'items': items.map((item) => item.toJson()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastSyncedAt':
          lastSyncedAt != null ? Timestamp.fromDate(lastSyncedAt!) : null,
      'isShared': isShared,
      'sharedWithUserIds': sharedWithUserIds,
      'metadata': metadata,
    };
  }

  /// Skapa från Firestore document
  factory ShoppingList.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ShoppingList(
      id: doc.id,
      name: data['name'] as String,
      ownerId: data['ownerId'] as String,
      items: (data['items'] as List<dynamic>?)
              ?.map(
                  (item) => ShoppingItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSyncedAt: (data['lastSyncedAt'] as Timestamp?)?.toDate(),
      syncStatus: SyncStatus.synced, // Från Firebase = synced
      isShared: data['isShared'] as bool? ?? false,
      sharedWithUserIds: List<String>.from(data['sharedWithUserIds'] ?? []),
      metadata: (data['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  // ===== LOCAL STORAGE SERIALIZATION =====

  /// Konvertera till JSON för Hive-lagring
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ownerId': ownerId,
      'items': items.map((item) => item.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'syncStatus': syncStatus.name,
      'isShared': isShared,
      'sharedWithUserIds': sharedWithUserIds,
      'metadata': metadata,
    };
  }

  /// Skapa från JSON
  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    return ShoppingList(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      items: (json['items'] as List<dynamic>?)
              ?.map(
                  (item) => ShoppingItem.fromJson(item as Map<String, dynamic>))
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
      isShared: json['isShared'] as bool? ?? false,
      sharedWithUserIds: List<String>.from(json['sharedWithUserIds'] ?? []),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  @override
  String toString() {
    return 'ShoppingList(id: $id, name: $name, items: $itemCount, sync: $syncStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShoppingList && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
