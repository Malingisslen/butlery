// lib/models/unified/unified_shopping_item.dart

/// 🔍 AI INFO BLOCK:
/// Component: Unified Shopping Item Model - FÖRBÄTTRAD FORMATERING
/// File: models/unified/unified_shopping_item.dart
/// Quick Guide: Smart formatering av mängd och enhet + förbättrad displayText
/// Dependencies IN: cloud_firestore, uuid
/// Dependencies OUT: UnifiedShoppingService, alla shopping UI-komponenter
/// Data flow: Recipe ingredients → UnifiedShoppingItem → UI rendering → Firebase sync
/// State management: Immutable data class med copyWith pattern
/// Purpose: Enhetlig representation av shopping items med SMART FORMATERING
/// Common issues: Inga onödiga decimaler, korrekt enhetsvisning
/// Test coverage: 0% (förbättring av befintlig komponent)
/// Performance: ⚡ Optimerad serialization, effektiv state management
/// Analytics: ✅ Shopping item interactions tracking
/// Code smells: ✅ Clean unified design med smart formatering
/// Connected to: UnifiedShoppingService, alla shopping views, Firebase
/// Used in phases: 18.3 (Unified Shopping Migration) + UI förbättringar

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// Enhetlig shopping item som kombinerar alla features från:
/// - ShoppingItem (grundläggande funktionalitet)
/// - EnhancedShoppingItem (social features)
/// + SMART FORMATERING för bättre UX
class UnifiedShoppingItem {
  final String id;
  final String name;
  final double amount;
  final String unit;
  final String category;
  final bool bought;

  // SOCIAL/COLLABORATIVE METADATA (optional - null för basic lists)
  final String? addedByUserId;
  final String? addedByDisplayName;
  final DateTime? addedAt;
  final String? purchasedByUserId;
  final String? purchasedByDisplayName;
  final DateTime? purchasedAt;
  final String? lastModifiedByUserId;
  final String? lastModifiedByDisplayName;
  final DateTime? lastModifiedAt;
  final String? note;
  final double? estimatedPrice;
  final int priority; // 1-5, 5 = highest

  UnifiedShoppingItem({
    String? id,
    required this.name,
    required this.amount,
    this.unit = '',
    this.category = 'Övrigt',
    this.bought = false,
    this.addedByUserId,
    this.addedByDisplayName,
    this.addedAt,
    this.purchasedByUserId,
    this.purchasedByDisplayName,
    this.purchasedAt,
    this.lastModifiedByUserId,
    this.lastModifiedByDisplayName,
    this.lastModifiedAt,
    this.note,
    this.estimatedPrice,
    this.priority = 3,
  }) : id = id ?? const Uuid().v4();

  // ===== FACTORY CONSTRUCTORS för enklare skapande =====

  /// Skapa basic shopping item (för vanliga listor)
  factory UnifiedShoppingItem.basic({
    required String name,
    required double amount,
    String unit = '',
    String category = 'Övrigt',
    bool bought = false,
  }) {
    return UnifiedShoppingItem(
      name: name,
      amount: amount,
      unit: unit,
      category: category,
      bought: bought,
    );
  }

  /// Skapa collaborative item (för shared lists)
  factory UnifiedShoppingItem.collaborative({
    required String name,
    required double amount,
    String unit = '',
    String category = 'Övrigt',
    required String addedByUserId,
    required String addedByDisplayName,
    String? note,
    double? estimatedPrice,
    int priority = 3,
  }) {
    final now = DateTime.now();
    return UnifiedShoppingItem(
      name: name,
      amount: amount,
      unit: unit,
      category: category,
      addedByUserId: addedByUserId,
      addedByDisplayName: addedByDisplayName,
      addedAt: now,
      lastModifiedByUserId: addedByUserId,
      lastModifiedByDisplayName: addedByDisplayName,
      lastModifiedAt: now,
      note: note,
      estimatedPrice: estimatedPrice,
      priority: priority,
    );
  }

  /// Migrera från din befintliga ShoppingItem
  factory UnifiedShoppingItem.fromShoppingItem(dynamic oldItem) {
    return UnifiedShoppingItem.basic(
      name: oldItem.name,
      amount: oldItem.amount,
      unit: oldItem.unit ?? '',
      category: oldItem.category ?? 'Övrigt',
      bought: oldItem.bought ?? false,
    );
  }

  // ===== SMART FORMATERING - HUVUDFÖRBÄTTRINGEN =====

  bool get isCollaborative => addedByUserId != null;
  bool get isPurchased => bought;

  /// ✅ SMART: Formatera mängd utan onödiga decimaler
  String get formattedAmount {
    // Om det är ett heltal, visa utan decimaler
    if (amount == amount.roundToDouble()) {
      return amount.round().toString();
    }

    // Annars visa med minimal precision
    return amount.toString();
  }

  /// ✅ SMART: Formatera enhet med korrekta förkortningar
  String get formattedUnit {
    if (unit.isEmpty) return '';

    // Mappa långa enhetsnamn till korta för visning
    final unitMappings = {
      'liter': 'l',
      'styck': 'st',
      'stycken': 'st',
      'förpackning': 'förp',
      'förpackningar': 'förp',
      'påse': 'påse',
      'påsar': 'påse',
      'burk': 'burk',
      'burkar': 'burk',
      'flaska': 'flaska',
      'flaskor': 'flaska',
      'bit': 'bit',
      'bitar': 'bit',
      'klyfta': 'klyfta',
      'klyftor': 'klyfta',
      'tesked': 'tsk',
      'teskedar': 'tsk',
    };

    return unitMappings[unit.toLowerCase()] ?? unit;
  }

  /// ✅ SMART: Perfekt displayText som hanterar alla fall
  String get displayText {
    final amountStr = formattedAmount;
    final unitStr = formattedUnit;

    // Om vi har enhet, visa: "1,5 l Mjölk" eller "2 st Ägg"
    if (unitStr.isNotEmpty) {
      return '$amountStr $unitStr $name';
    }

    // Om bara amount utan enhet: "3 Bananer"
    if (amount != 1.0) {
      return '$amountStr $name';
    }

    // Om amount är 1 utan enhet, visa bara namnet: "Bröd"
    return name;
  }

  String get priorityEmoji {
    switch (priority) {
      case 5:
        return '🔴'; // Highest
      case 4:
        return '🟠'; // High
      case 3:
        return '🟡'; // Medium
      case 2:
        return '🟢'; // Low
      case 1:
        return '⚪'; // Lowest
      default:
        return '🟡';
    }
  }

  // ===== UPDATE METHODS =====

  UnifiedShoppingItem copyWith({
    String? name,
    double? amount,
    String? unit,
    String? category,
    bool? bought,
    String? note,
    double? estimatedPrice,
    int? priority,
    String? lastModifiedByUserId,
    String? lastModifiedByDisplayName,
    DateTime? lastModifiedAt,
  }) {
    return UnifiedShoppingItem(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      bought: bought ?? this.bought,
      addedByUserId: addedByUserId,
      addedByDisplayName: addedByDisplayName,
      addedAt: addedAt,
      purchasedByUserId:
          bought == true ? (lastModifiedByUserId ?? purchasedByUserId) : null,
      purchasedByDisplayName: bought == true
          ? (lastModifiedByDisplayName ?? purchasedByDisplayName)
          : null,
      purchasedAt: bought == true ? DateTime.now() : null,
      lastModifiedByUserId: lastModifiedByUserId ?? this.lastModifiedByUserId,
      lastModifiedByDisplayName:
          lastModifiedByDisplayName ?? this.lastModifiedByDisplayName,
      lastModifiedAt: lastModifiedAt ?? DateTime.now(),
      note: note ?? this.note,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      priority: priority ?? this.priority,
    );
  }

  /// Toggle purchased status med collaborative tracking
  UnifiedShoppingItem togglePurchased({
    String? userId,
    String? userDisplayName,
  }) {
    final now = DateTime.now();
    final newBought = !bought;

    return UnifiedShoppingItem(
      id: id,
      name: name,
      amount: amount,
      unit: unit,
      category: category,
      bought: newBought,
      addedByUserId: addedByUserId,
      addedByDisplayName: addedByDisplayName,
      addedAt: addedAt,
      purchasedByUserId: newBought ? userId : null,
      purchasedByDisplayName: newBought ? userDisplayName : null,
      purchasedAt: newBought ? now : null,
      lastModifiedByUserId: userId ?? lastModifiedByUserId,
      lastModifiedByDisplayName: userDisplayName ?? lastModifiedByDisplayName,
      lastModifiedAt: now,
      note: note,
      estimatedPrice: estimatedPrice,
      priority: priority,
    );
  }

  // ===== SERIALIZATION =====

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'unit': unit,
      'category': category,
      'bought': bought,
      'addedByUserId': addedByUserId,
      'addedByDisplayName': addedByDisplayName,
      'addedAt': addedAt?.toIso8601String(),
      'purchasedByUserId': purchasedByUserId,
      'purchasedByDisplayName': purchasedByDisplayName,
      'purchasedAt': purchasedAt?.toIso8601String(),
      'lastModifiedByUserId': lastModifiedByUserId,
      'lastModifiedByDisplayName': lastModifiedByDisplayName,
      'lastModifiedAt': lastModifiedAt?.toIso8601String(),
      'note': note,
      'estimatedPrice': estimatedPrice,
      'priority': priority,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'unit': unit,
      'category': category,
      'bought': bought,
      'addedByUserId': addedByUserId,
      'addedByDisplayName': addedByDisplayName,
      'addedAt': addedAt != null ? Timestamp.fromDate(addedAt!) : null,
      'purchasedByUserId': purchasedByUserId,
      'purchasedByDisplayName': purchasedByDisplayName,
      'purchasedAt':
          purchasedAt != null ? Timestamp.fromDate(purchasedAt!) : null,
      'lastModifiedByUserId': lastModifiedByUserId,
      'lastModifiedByDisplayName': lastModifiedByDisplayName,
      'lastModifiedAt':
          lastModifiedAt != null ? Timestamp.fromDate(lastModifiedAt!) : null,
      'note': note,
      'estimatedPrice': estimatedPrice,
      'priority': priority,
    };
  }

  factory UnifiedShoppingItem.fromJson(Map<String, dynamic> json) {
    return UnifiedShoppingItem(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      unit: json['unit'] as String? ?? '',
      category: json['category'] as String? ?? 'Övrigt',
      bought: json['bought'] as bool? ?? false,
      addedByUserId: json['addedByUserId'] as String?,
      addedByDisplayName: json['addedByDisplayName'] as String?,
      addedAt: json['addedAt'] != null ? DateTime.parse(json['addedAt']) : null,
      purchasedByUserId: json['purchasedByUserId'] as String?,
      purchasedByDisplayName: json['purchasedByDisplayName'] as String?,
      purchasedAt: json['purchasedAt'] != null
          ? DateTime.parse(json['purchasedAt'])
          : null,
      lastModifiedByUserId: json['lastModifiedByUserId'] as String?,
      lastModifiedByDisplayName: json['lastModifiedByDisplayName'] as String?,
      lastModifiedAt: json['lastModifiedAt'] != null
          ? DateTime.parse(json['lastModifiedAt'])
          : null,
      note: json['note'] as String?,
      estimatedPrice: (json['estimatedPrice'] as num?)?.toDouble(),
      priority: json['priority'] as int? ?? 3,
    );
  }

  factory UnifiedShoppingItem.fromFirestore(Map<String, dynamic> data) {
    return UnifiedShoppingItem(
      id: data['id'] as String,
      name: data['name'] as String,
      amount: (data['amount'] as num).toDouble(),
      unit: data['unit'] as String? ?? '',
      category: data['category'] as String? ?? 'Övrigt',
      bought: data['bought'] as bool? ?? false,
      addedByUserId: data['addedByUserId'] as String?,
      addedByDisplayName: data['addedByDisplayName'] as String?,
      addedAt: (data['addedAt'] as Timestamp?)?.toDate(),
      purchasedByUserId: data['purchasedByUserId'] as String?,
      purchasedByDisplayName: data['purchasedByDisplayName'] as String?,
      purchasedAt: (data['purchasedAt'] as Timestamp?)?.toDate(),
      lastModifiedByUserId: data['lastModifiedByUserId'] as String?,
      lastModifiedByDisplayName: data['lastModifiedByDisplayName'] as String?,
      lastModifiedAt: (data['lastModifiedAt'] as Timestamp?)?.toDate(),
      note: data['note'] as String?,
      estimatedPrice: (data['estimatedPrice'] as num?)?.toDouble(),
      priority: data['priority'] as int? ?? 3,
    );
  }

  @override
  String toString() => displayText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnifiedShoppingItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
