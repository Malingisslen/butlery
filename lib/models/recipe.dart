// lib/models/recipe.dart
import 'package:uuid/uuid.dart';

class Recipe {
  final String id; // unikt ID
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

  Recipe({
    String? id, // generera om inget skickas in
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
  }) : id = id ?? const Uuid().v4();

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
    );
  }

  /// Hjälp-getter för snygg visning av tid
  String get cookTimeText =>
      timeMinutes != null ? '${timeMinutes!} minuter' : '–';

  // ==================== JSON SERIALIZATION ====================

  /// 💾 Konverterar Recipe-objekt till Map för JSON-lagring
  /// Används av PersistenceService för att spara recept
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'portions': portions,
      'timeMinutes': timeMinutes,
      'ingredients': ingredients,
      'instructions': instructions,
      'tags': tags, // null är OK i JSON
      'rating': rating,
      'imageUrl': imageUrl,
      'mealType': mealType,
    };
  }

  /// 📖 Skapar Recipe-objekt från Map (från JSON)
  /// Används av PersistenceService för att ladda sparade recept
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
      rating: json['rating'] as double?,
      imageUrl: json['imageUrl'] as String?,
      mealType: json['mealType'] as String,
    );
  }

  // ==================== UTILITY METHODS ====================

  /// 🔍 För debugging - visar receptinfo som text
  @override
  String toString() {
    return 'Recipe(id: $id, title: $title, mealType: $mealType, ingredients: ${ingredients.length})';
  }

  /// ⚖️ Jämför två recept baserat på ID
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Recipe && other.id == id;
  }

  /// 🏷️ Hash-kod för Set/Map-användning
  @override
  int get hashCode => id.hashCode;
}
