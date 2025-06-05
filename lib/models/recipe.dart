// lib/data/recipe.dart
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
}
