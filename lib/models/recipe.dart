// lib/models/recipe.dart

import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

// VIKTIGT: Kör denna kommando efter att ha sparat filen:
// flutter packages pub run build_runner build --delete-conflicting-outputs

part 'recipe.g.dart'; // Genererad fil av Hive

/// Recipe model som representerar ett recept i appen
///
/// Uppdaterad med:
/// - sourceUrl för att spara ursprungskällan
/// - Firestore serialization support
/// - createdAt/updatedAt för tidsstämplar
/// - Hive support för offline-lagring
@HiveType(typeId: 0) // Unikt ID för denna model i Hive
class Recipe extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  int? portions;

  @HiveField(4)
  int? timeMinutes;

  @HiveField(5)
  List<String> ingredients;

  @HiveField(6)
  List<String> instructions;

  @HiveField(7)
  List<String>? tags;

  @HiveField(8)
  double? rating;

  @HiveField(9)
  String? imageUrl;

  @HiveField(10)
  String mealType;

  @HiveField(11)
  String? sourceUrl;

  @HiveField(12)
  final DateTime createdAt;

  @HiveField(13)
  final DateTime updatedAt;

  // Nya fält för offline-synk
  @HiveField(14)
  DateTime? lastSyncedAt; // när receptet senast synkades med Firebase

  @HiveField(15)
  bool isModifiedOffline; // om receptet har ändrats offline

  Recipe({
    String? id,
    required this.title,
    required this.description,
    this.portions,
    this.timeMinutes,
    required this.ingredients,
    required this.instructions,
    this.tags,
    this.rating,
    this.imageUrl,
    required this.mealType,
    this.sourceUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastSyncedAt,
    this.isModifiedOffline = false,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Skapa kopia med uppdaterade värden
  Recipe copyWith({
    String? title,
    String? description,
    int? portions,
    int? timeMinutes,
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? tags,
    double? rating,
    String? imageUrl,
    String? mealType,
    String? sourceUrl,
    DateTime? updatedAt,
    DateTime? lastSyncedAt,
    bool? isModifiedOffline,
  }) {
    return Recipe(
      id: id, // behåll samma ID!
      title: title ?? this.title,
      description: description ?? this.description,
      portions: portions ?? this.portions,
      timeMinutes: timeMinutes ?? this.timeMinutes,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      tags: tags ?? this.tags,
      rating: rating ?? this.rating,
      imageUrl: imageUrl ?? this.imageUrl,
      mealType: mealType ?? this.mealType,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      createdAt: createdAt, // behåll original skapandetid
      updatedAt: updatedAt ?? DateTime.now(), // uppdatera till nu
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isModifiedOffline: isModifiedOffline ?? this.isModifiedOffline,
    );
  }

  /// Hjälp-getter för snygg visning av tid
  String get cookTimeText =>
      timeMinutes != null ? '${timeMinutes!} minuter' : '–';

  /// Kontrollera om receptet behöver synkas
  bool get needsSync => isModifiedOffline || lastSyncedAt == null;

  /// Markera som modifierad offline
  void markAsModifiedOffline() {
    isModifiedOffline = true;
    save(); // Hive's save method
  }

  /// Markera som synkad
  void markAsSynced() {
    isModifiedOffline = false;
    lastSyncedAt = DateTime.now();
    save(); // Hive's save method
  }

  // ==================== JSON SERIALIZATION (SharedPreferences) ====================

  /// Konverterar Recipe-objekt till Map för JSON-lagring
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'portions': portions,
      'timeMinutes': timeMinutes,
      'ingredients': ingredients,
      'instructions': instructions,
      'tags': tags,
      'rating': rating,
      'imageUrl': imageUrl,
      'mealType': mealType,
      'sourceUrl': sourceUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'isModifiedOffline': isModifiedOffline,
    };
  }

  /// Skapar Recipe-objekt från Map (från JSON)
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      portions: json['portions'] as int?,
      timeMinutes: json['timeMinutes'] as int?,
      ingredients: List<String>.from(json['ingredients'] as List),
      instructions: List<String>.from(json['instructions'] as List),
      tags:
          json['tags'] != null ? List<String>.from(json['tags'] as List) : null,
      rating: (json['rating'] as num?)?.toDouble(),
      imageUrl: json['imageUrl'] as String?,
      mealType: json['mealType'] as String,
      sourceUrl: json['sourceUrl'] as String?,
      createdAt:
          json['createdAt'] != null
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now(),
      updatedAt:
          json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'] as String)
              : DateTime.now(),
      lastSyncedAt:
          json['lastSyncedAt'] != null
              ? DateTime.parse(json['lastSyncedAt'] as String)
              : null,
      isModifiedOffline: json['isModifiedOffline'] as bool? ?? false,
    );
  }

  // ==================== FIRESTORE SERIALIZATION ====================

  /// Skapa Recipe från Firestore DocumentSnapshot
  factory Recipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Recipe(
      id: doc.id, // Använd dokument-ID från Firestore
      title: data['title'] as String,
      description: data['description'] as String,
      portions: data['portions'] as int?,
      timeMinutes: data['timeMinutes'] as int?,
      ingredients: List<String>.from(data['ingredients'] as List),
      instructions: List<String>.from(data['instructions'] as List),
      tags:
          data['tags'] != null ? List<String>.from(data['tags'] as List) : null,
      rating: (data['rating'] as num?)?.toDouble(),
      imageUrl: data['imageUrl'] as String?,
      mealType: data['mealType'] as String,
      sourceUrl: data['sourceUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSyncedAt: DateTime.now(), // Markera som just synkad
      isModifiedOffline: false,
    );
  }

  /// Konvertera Recipe till Firestore-format
  Map<String, dynamic> toFirestore() {
    return {
      // ID hanteras separat som dokument-ID
      'title': title,
      'description': description,
      'portions': portions,
      'timeMinutes': timeMinutes,
      'ingredients': ingredients,
      'instructions': instructions,
      'tags': tags,
      'rating': rating,
      'imageUrl': imageUrl,
      'mealType': mealType,
      'sourceUrl': sourceUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt':
          FieldValue.serverTimestamp(), // Använd server-tid för uppdatering
    };
  }

  // ==================== UTILITY METHODS ====================

  /// För debugging - visar receptinfo som text
  @override
  String toString() {
    return 'Recipe(id: $id, title: $title, mealType: $mealType, ingredients: ${ingredients.length}, sourceUrl: $sourceUrl, needsSync: $needsSync)';
  }

  /// Jämför två recept baserat på ID
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Recipe && other.id == id;
  }

  /// Hash-kod för Set/Map-användning
  @override
  int get hashCode => id.hashCode;
}
