// lib/models/recipe.dart

import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Recipe model som representerar ett recept i appen
///
/// Uppdaterad med:
/// - sourceUrl för att spara ursprungskällan
/// - Firestore serialization support
/// - createdAt/updatedAt för tidsstämplar
class Recipe {
  final String id;
  String title;
  String description;
  int? portions;
  int? timeMinutes;
  List<String> ingredients;
  List<String> instructions;
  List<String>? tags;
  double? rating;
  String? imageUrl;
  String mealType;
  String? sourceUrl; // NY! URL till receptets ursprung
  final DateTime createdAt; // NY! När receptet skapades
  final DateTime updatedAt; // NY! När receptet senast uppdaterades

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
    this.sourceUrl, // NY parameter
    DateTime? createdAt,
    DateTime? updatedAt,
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
    );
  }

  /// Hjälp-getter för snygg visning av tid
  String get cookTimeText =>
      timeMinutes != null ? '${timeMinutes!} minuter' : '–';

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
    return 'Recipe(id: $id, title: $title, mealType: $mealType, ingredients: ${ingredients.length}, sourceUrl: $sourceUrl)';
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
