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
/// - lastCookedAt för "senast tillagad" tracking
/// - imageUrls för flera bilder per recept (NY!)
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

  // BORTTAGET: imageUrl - ersatt av imageUrls nedan
  // @HiveField(9) var reserved för imageUrl

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

  @HiveField(16)
  DateTime? lastCookedAt; // när receptet senast tillagades

  // NYT FÄLT för Fas 15 - flera bilder
  @HiveField(17)
  List<String> imageUrls; // Lista med bild-URLs

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
    List<String>? imageUrls, // NY parameter
    required this.mealType,
    this.sourceUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastSyncedAt,
    this.isModifiedOffline = false,
    this.lastCookedAt,
  })  : id = id ?? const Uuid().v4(),
        imageUrls = imageUrls ?? [], // Tom lista som default
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Hjälp-getter för att kontrollera om recept har bilder
  bool get hasImages => imageUrls.isNotEmpty;

  /// Hjälp-getter för första bilden (primary image)
  String? get primaryImageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;

  /// Skapa kopia med uppdaterade värden
  Recipe copyWith({
    String? id, // ← NYTT
    String? title,
    String? description,
    int? portions,
    int? timeMinutes,
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? tags,
    double? rating,
    List<String>? imageUrls,
    String? mealType,
    String? sourceUrl,
    DateTime? createdAt, // ← NYTT
    DateTime? updatedAt,
    DateTime? lastCookedAt,
    DateTime? lastSyncedAt,
    bool? isModifiedOffline,
  }) {
    return Recipe(
      id: id ?? this.id, // ← NYTT
      title: title ?? this.title,
      description: description ?? this.description,
      portions: portions ?? this.portions,
      timeMinutes: timeMinutes ?? this.timeMinutes,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      tags: tags ?? this.tags,
      rating: rating ?? this.rating,
      imageUrls: imageUrls ?? this.imageUrls,
      mealType: mealType ?? this.mealType,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      createdAt: createdAt ?? this.createdAt, // ← NYTT
      updatedAt: updatedAt ?? this.updatedAt,
      lastCookedAt: lastCookedAt ?? this.lastCookedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isModifiedOffline: isModifiedOffline ?? this.isModifiedOffline,
    );
  }

  /// Hjälp-getter för snygg visning av tid
  String get cookTimeText =>
      timeMinutes != null ? '${timeMinutes!} minuter' : '–';

  /// Kontrollera om receptet behöver synkas
  bool get needsSync => isModifiedOffline || lastSyncedAt == null;

  /// Hjälp-getter för "senast tillagad" text
  String? get lastCookedText {
    if (lastCookedAt == null) return null;

    final now = DateTime.now();
    final difference = now.difference(lastCookedAt!);

    if (difference.inDays == 0) {
      return 'Tillagad idag';
    } else if (difference.inDays == 1) {
      return 'Tillagad igår';
    } else if (difference.inDays < 7) {
      return 'Tillagad för ${difference.inDays} dagar sedan';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Tillagad för $weeks ${weeks == 1 ? 'vecka' : 'veckor'} sedan';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Tillagad för $months ${months == 1 ? 'månad' : 'månader'} sedan';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Tillagad för $years ${years == 1 ? 'år' : 'år'} sedan';
    }
  }

  /// Kontrollera om receptet tillagats nyligen (senaste 7 dagarna)
  bool get wasCookedRecently {
    if (lastCookedAt == null) return false;
    return DateTime.now().difference(lastCookedAt!).inDays < 7;
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
      'imageUrls': imageUrls, // NY
      'mealType': mealType,
      'sourceUrl': sourceUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'isModifiedOffline': isModifiedOffline,
      'lastCookedAt': lastCookedAt?.toIso8601String(),
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
      imageUrls: // NY - med migration från gamla imageUrl
          json['imageUrls'] != null
              ? List<String>.from(json['imageUrls'] as List)
              : json['imageUrl'] != null // Bakåtkompatibilitet för import
                  ? [json['imageUrl'] as String]
                  : [],
      mealType: json['mealType'] as String,
      sourceUrl: json['sourceUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.parse(json['lastSyncedAt'] as String)
          : null,
      isModifiedOffline: json['isModifiedOffline'] as bool? ?? false,
      lastCookedAt: json['lastCookedAt'] != null
          ? DateTime.parse(json['lastCookedAt'] as String)
          : null,
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
      imageUrls: // NY - med migration från gamla imageUrl
          data['imageUrls'] != null
              ? List<String>.from(data['imageUrls'] as List)
              : data['imageUrl'] != null // Migration från gamla recept
                  ? [data['imageUrl'] as String]
                  : [],
      mealType: data['mealType'] as String,
      sourceUrl: data['sourceUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSyncedAt: DateTime.now(), // Markera som just synkad
      isModifiedOffline: false,
      lastCookedAt: (data['lastCookedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Konvertera Recipe till Firestore-format
  Map<String, dynamic> toFirestore({bool isNested = false}) {
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
      'imageUrls': imageUrls, // NY
      'mealType': mealType,
      'sourceUrl': sourceUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      // 🔧 FIXED: Använd serverTimestamp endast för top-level dokument
      'updatedAt': isNested
          ? Timestamp.fromDate(updatedAt)
          : FieldValue.serverTimestamp(),
      'lastCookedAt':
          lastCookedAt != null ? Timestamp.fromDate(lastCookedAt!) : null,
    };
  }

  // ==================== UTILITY METHODS ====================

  /// För debugging - visar receptinfo som text
  @override
  String toString() {
    return 'Recipe(id: $id, title: $title, mealType: $mealType, images: ${imageUrls.length}, ingredients: ${ingredients.length}, sourceUrl: $sourceUrl, needsSync: $needsSync, lastCooked: ${lastCookedText ?? "aldrig"})';
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
