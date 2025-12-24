import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Recipe serialization (JSON, Firestore, export/import formats).
class RecipeSerialization {
  /// Serialize recipe to JSON format
  static Map<String, dynamic> toJson(Recipe recipe) {
    return {
      'core': recipe.core.toJson(),
      'type': recipe.type.index,
      'socialData': recipe.socialData?.toJson(),
      'realtimeData': recipe.realtimeData?.toJson(),
      'offlineData': recipe.offlineData?.toJson(),
    };
  }

  /// Deserialize recipe from JSON format
  static Recipe fromJson(Map<String, dynamic> json) {
    return Recipe(
      core: RecipeCore.fromJson(json['core'] as Map<String, dynamic>),
      type: RecipeType.values[json['type'] as int],
      socialData: json['socialData'] != null
          ? RecipeSocialData.fromJson(
              json['socialData'] as Map<String, dynamic>)
          : null,
      realtimeData: json['realtimeData'] != null
          ? RecipeRealtimeData.fromJson(
              json['realtimeData'] as Map<String, dynamic>)
          : null,
      offlineData: json['offlineData'] != null
          ? RecipeOfflineData.fromJson(
              json['offlineData'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Serialize recipe to Firestore format
  static Map<String, dynamic> toFirestore(Recipe recipe) {
    return {
      'core': recipe.core.toFirestore(),
      'type': recipe.type.index,
      'socialData': recipe.socialData?.toJson(),
      'realtimeData': recipe.realtimeData?.toJson(),
      // Don't include offline data in Firestore
    };
  }

  /// Deserialize recipe from repository data map (removes Firebase dependency)
  static Recipe fromMap(String id, Map<String, dynamic> data) {
    // Handle both nested and flat structures for backward compatibility
    final coreData = data['core'] as Map<String, dynamic>? ?? data;

    return Recipe(
      core: RecipeCore.fromMap(id, coreData),
      type: RecipeType.values[(data['type'] as int?).orZero()],
      socialData: data['socialData'] != null
          ? RecipeSocialData.fromJson(
              data['socialData'] as Map<String, dynamic>)
          : null,
      realtimeData: data['realtimeData'] != null
          ? RecipeRealtimeData.fromJson(
              data['realtimeData'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Deserialize recipe from Firestore document
  static Recipe fromFirestore(DocumentSnapshot doc) {
    return fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  /// Serialize multiple recipes to JSON
  static List<Map<String, dynamic>> toJsonBatch(List<Recipe> recipes) {
    return recipes.map(toJson).toList();
  }

  /// Deserialize multiple recipes from JSON
  static List<Recipe> fromJsonBatch(List<Map<String, dynamic>> jsonList) {
    return jsonList.map(fromJson).toList();
  }

  /// Serialize multiple recipes to Firestore format
  static List<Map<String, dynamic>> toFirestoreBatch(List<Recipe> recipes) {
    return recipes.map(toFirestore).toList();
  }

  /// Deserialize multiple recipes from Firestore documents
  static List<Recipe> fromFirestoreBatch(List<DocumentSnapshot> docs) {
    return docs.map(fromFirestore).toList();
  }

  /// Serialize only core recipe data
  static Map<String, dynamic> toCoreJson(Recipe recipe) {
    return recipe.core.toJson();
  }

  /// Serialize only social data
  static Map<String, dynamic>? toSocialJson(Recipe recipe) {
    return recipe.socialData?.toJson();
  }

  /// Serialize only realtime data
  static Map<String, dynamic>? toRealtimeJson(Recipe recipe) {
    return recipe.realtimeData?.toJson();
  }

  /// Serialize only offline data
  static Map<String, dynamic>? toOfflineJson(Recipe recipe) {
    return recipe.offlineData?.toJson();
  }

  /// Validate JSON structure before deserialization
  static bool isValidJsonStructure(Map<String, dynamic> json) {
    // Check required fields
    if (!json.containsKey('core')) return false;
    if (!json.containsKey('type')) return false;

    // Validate core structure
    final core = json['core'];
    if (core is! Map<String, dynamic>) return false;

    final coreRequiredFields = [
      'id',
      'title',
      'description',
      'ingredients',
      'instructions',
      'mealType'
    ];
    for (final field in coreRequiredFields) {
      if (!core.containsKey(field)) return false;
    }

    // Validate type
    final type = json['type'];
    if (type is! int || type < 0 || type >= RecipeType.values.length) {
      return false;
    }

    return true;
  }

  /// Validate Firestore document structure
  static bool isValidFirestoreStructure(Map<String, dynamic> data) {
    // Firestore validation is similar to JSON but with timestamp handling
    return isValidJsonStructure(data);
  }

  /// Sanitize JSON data before deserialization
  static Map<String, dynamic> sanitizeJsonData(Map<String, dynamic> json) {
    final sanitized = Map<String, dynamic>.from(json);

    // Ensure type is valid
    final type = (sanitized['type'] as int?).orZero();
    sanitized['type'] = type.clamp(0, RecipeType.values.length - 1);

    // Sanitize core data if needed
    if (sanitized['core'] is Map<String, dynamic>) {
      sanitized['core'] =
          _sanitizeCoreData(sanitized['core'] as Map<String, dynamic>);
    }

    return sanitized;
  }

  /// Sanitize core recipe data
  static Map<String, dynamic> _sanitizeCoreData(Map<String, dynamic> core) {
    final sanitized = Map<String, dynamic>.from(core);

    // Ensure required string fields are strings
    sanitized['title'] = (sanitized['title']?.toString()).orEmpty();
    sanitized['description'] = (sanitized['description']?.toString()).orEmpty();
    sanitized['mealType'] =
        (sanitized['mealType']?.toString()).orDefault('Middag');

    // Ensure list fields are lists
    if (sanitized['ingredients'] is! List) {
      sanitized['ingredients'] = <String>[];
    } else {
      sanitized['ingredients'] = (sanitized['ingredients'] as List)
          .map((item) => (item?.toString()).orEmpty())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (sanitized['instructions'] is! List) {
      sanitized['instructions'] = <String>[];
    } else {
      sanitized['instructions'] = (sanitized['instructions'] as List)
          .map((item) => (item?.toString()).orEmpty())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (sanitized['imageUrls'] is! List) {
      sanitized['imageUrls'] = <String>[];
    } else {
      sanitized['imageUrls'] = (sanitized['imageUrls'] as List)
          .map((item) => (item?.toString()).orEmpty())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    // Handle tags (can be null)
    if (sanitized['tags'] != null && sanitized['tags'] is! List) {
      sanitized['tags'] = <String>[];
    } else if (sanitized['tags'] is List) {
      sanitized['tags'] = (sanitized['tags'] as List)
          .map((item) => (item?.toString()).orEmpty())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return sanitized;
  }

  /// Export recipe to simplified format for sharing
  static Map<String, dynamic> toSimpleExport(Recipe recipe) {
    return {
      'title': recipe.core.title,
      'description': recipe.core.description,
      'ingredients': recipe.core.ingredients,
      'instructions': recipe.core.instructions,
      'mealType': recipe.core.mealType,
      'portions': recipe.core.portions,
      'timeMinutes': recipe.core.timeMinutes,
      'rating': recipe.core.rating,
      'tags': recipe.core.tags,
      'imageUrls': recipe.core.imageUrls,
      'sourceUrl': recipe.core.sourceUrl,
      'exportedAt': DateTime.now().toIso8601String(),
      'exportFormat': 'butlery-simple-v1',
    };
  }

  /// Import recipe from simplified format
  static Recipe fromSimpleImport(
    Map<String, dynamic> data, {
    String? importedBy,
    RecipeType type = RecipeType.personal,
  }) {
    return Recipe(
      core: RecipeCore(
        title: (data['title']?.toString()).orDefault('Importerat recept'),
        description: (data['description']?.toString()).orEmpty(),
        ingredients: data['ingredients'] is List
            ? List<String>.from(data['ingredients'])
            : [],
        instructions: data['instructions'] is List
            ? List<String>.from(data['instructions'])
            : [],
        mealType: (data['mealType']?.toString()).orDefault('Middag'),
        portions: data['portions'] as int?,
        timeMinutes: data['timeMinutes'] as int?,
        rating: (data['rating'] as num?)?.toDouble(),
        tags: data['tags'] is List ? List<String>.from(data['tags']) : null,
        imageUrls: data['imageUrls'] is List
            ? List<String>.from(data['imageUrls'])
            : [],
        sourceUrl: data['sourceUrl']?.toString(),
        createdBy: importedBy,
      ),
      type: type,
    );
  }

  /// Get compressed representation for storage optimization
  static Map<String, dynamic> toCompressed(Recipe recipe) {
    final compressed = <String, dynamic>{};

    // Use shorter field names
    compressed['t'] = recipe.core.title;
    compressed['d'] = recipe.core.description;
    compressed['i'] = recipe.core.ingredients;
    compressed['s'] = recipe.core.instructions;
    compressed['m'] = recipe.core.mealType;
    compressed['ty'] = recipe.type.index;

    // Optional fields only if not null/empty
    if (recipe.core.portions != null) compressed['p'] = recipe.core.portions;
    if (recipe.core.timeMinutes != null) {
      compressed['tm'] = recipe.core.timeMinutes;
    }
    if (recipe.core.rating != null) compressed['r'] = recipe.core.rating;
    if (recipe.core.tags != null && recipe.core.tags!.isNotEmpty) {
      compressed['tg'] = recipe.core.tags;
    }
    if (recipe.core.imageUrls.isNotEmpty) {
      compressed['img'] = recipe.core.imageUrls;
    }
    if (recipe.core.sourceUrl != null) {
      compressed['src'] = recipe.core.sourceUrl;
    }

    return compressed;
  }

  /// Expand compressed representation
  static Recipe fromCompressed(Map<String, dynamic> compressed) {
    return Recipe(
      core: RecipeCore(
        title: (compressed['t']?.toString()).orEmpty(),
        description: (compressed['d']?.toString()).orEmpty(),
        ingredients:
            compressed['i'] is List ? List<String>.from(compressed['i']) : [],
        instructions:
            compressed['s'] is List ? List<String>.from(compressed['s']) : [],
        mealType: (compressed['m']?.toString()).orDefault('Middag'),
        portions: compressed['p'] as int?,
        timeMinutes: compressed['tm'] as int?,
        rating: (compressed['r'] as num?)?.toDouble(),
        tags: compressed['tg'] is List
            ? List<String>.from(compressed['tg'])
            : null,
        imageUrls: compressed['img'] is List
            ? List<String>.from(compressed['img'])
            : [],
        sourceUrl: compressed['src']?.toString(),
      ),
      type: RecipeType.values[(compressed['ty'] as int?).orZero()],
    );
  }
}
