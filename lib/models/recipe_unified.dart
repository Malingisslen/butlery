/// Unified recipe data model with multi-type support and modular architecture.

// lib/models/recipe_unified.dart

import 'package:clock/clock.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/mixins/json_serializable_mixin.dart';
import 'package:butlery/core/utils/serialization_utils.dart' as utils;
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe/source_artefact.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/tagging/recipe_personal_tag.dart';
import 'package:butlery/models/nutrition_info.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tag_result.dart';

// Focused modules
import 'package:butlery/models/recipe/recipe_operations.dart';
import 'package:butlery/models/recipe/recipe_factory.dart';
import 'package:butlery/models/recipe/recipe_serialization.dart';
import 'package:butlery/models/recipe/heirloom_metadata.dart';

/// Sentinel value for copyWith methods — distinguishes "not provided" from null.
const _sentinel = Object();

/// Enumeration defining the different types of recipes and their behavior.
/// Recipe types determine the sharing model, editing permissions, and
/// collaboration features available for a recipe:
/// - [personal] - Private recipe owned by a single user
/// - [shared] - Recipe shared with others in read-only mode
/// - [collaborative] - Recipe that can be edited by multiple users
/// - [realtime] - Recipe with live collaborative editing capabilities
enum RecipeType {
  /// Private recipe accessible only to the owner.
  /// Personal recipes are stored in the user's private collection and
  /// cannot be accessed by other users unless explicitly shared.
  personal,

  /// Recipe shared with others in read-only mode.
  /// Shared recipes allow other users to view and copy the recipe
  /// but not modify the original. The owner retains full control.
  shared,

  /// Recipe that can be collaboratively edited by multiple users.
  /// Collaborative recipes allow designated users to modify the recipe
  /// content with proper conflict resolution and change tracking.
  collaborative,

  /// Recipe with real-time collaborative editing capabilities.
  /// Realtime recipes support simultaneous editing by multiple users
  /// with live updates, operational transforms, and presence indicators.
  realtime,
}

/// Status of recipe data integrity verification.
/// Used to track checksum validation results without persisting to Firestore.
/// Option A: Track silently for analytics, no user-facing UI.
enum DataIntegrityStatus {
  /// Integrity not verified (legacy recipe without checksum).
  unverified,

  /// Checksum matches computed value.
  valid,

  /// Checksum mismatch detected - possible data corruption.
  invalid,
}

/// Core recipe data model containing common recipe information.
/// This class represents the fundamental recipe data that is shared across
/// all recipe types in the unified recipe system. It includes all the basic
/// recipe information such as title, ingredients, instructions, and metadata.
/// The class is serializable for both local storage (Drift SQLite) and network
/// transmission (JSON), enabling efficient caching and synchronization.
/// Key features:
/// - Immutable ID for unique identification
/// - Mutable content fields for editing
/// - Timestamp tracking for audit and sync
/// - Permission and sharing metadata
/// - Image and media URL storage
/// - Cooking history and analytics data
/// Usage example:
/// ```dart
/// final recipe = RecipeCore(
///   title: 'Pasta Carbonara',
///   description: 'Classic Italian pasta dish',
///   ingredients: ['pasta', 'eggs', 'bacon'],
///   instructions: ['Boil pasta', 'Cook bacon', 'Mix with eggs'],
///   portions: 4,
///   timeMinutes: 30,
/// );
/// ```
class RecipeCore with JsonSerializableMixin {
  /// Unique identifier for this recipe.
  /// This ID is immutable and generated once when the recipe is created.
  /// It's used for database references, sharing, and cache management.
  final String id;

  /// The display name of the recipe.
  /// This is the primary user-visible identifier for the recipe,
  /// shown in lists, search results, and detail views.
  String title;

  /// Detailed description of the recipe.
  /// Provides additional context, cooking tips, origin story,
  /// or other descriptive information about the recipe.
  String description;

  /// Number of servings this recipe produces.
  /// Used for scaling ingredients and nutritional calculations.
  /// Can be null if portion size is not specified.
  int? portions;

  /// Total cooking and preparation time in minutes.
  /// Includes active cooking time and any waiting/resting periods.
  /// Used for meal planning and filtering by available time.
  int? timeMinutes;

  /// List of ingredients required for this recipe.
  /// Each string represents one ingredient with quantity and preparation
  /// instructions (e.g., "2 cups flour, sifted", "1 large onion, diced").
  /// Order typically reflects the sequence of use in cooking.
  List<String> ingredients;

  /// BUT-1216: structured ingredient data (amount/unit/name) parallel to
  /// [ingredients] — entry i corresponds to ingredients[i] and carries the
  /// original line in `raw`. Null for legacy recipes and manual entry;
  /// populated by import pipelines that produce ParsedIngredient. NEVER
  /// read this directly for features — use `Recipe.structuredIngredients`,
  /// which validates alignment against [ingredients] and falls back to
  /// raw-only entries when the strings were edited after import.
  /// Deliberately excluded from [computeChecksum] (derived data).
  List<RecipeIngredient>? structuredIngredients;

  /// Step-by-step cooking instructions.
  /// Each string represents one cooking step, ordered from first to last.
  /// Instructions should be clear and actionable for the home cook.
  List<String> instructions;

  /// User-created personal tags for custom categorization.
  /// Stores tag UUIDs for efficient Firestore arrayContains queries.
  /// Display names available via [personalTags] rich objects.
  List<String>? personalTagIds;

  /// Rich personal tag data with source tracking.
  /// Stores full [RecipePersonalTag] objects (tagId, name, sources).
  /// Used for display and source tracking. Dual-written alongside personalTagIds.
  List<RecipePersonalTag>? personalTags;

  /// User rating for this recipe (0.0 to 5.0).
  /// Represents the average user rating or personal rating depending
  /// on the recipe type. Used for sorting and recommendation algorithms.
  double? rating;

  String mealType;

  String? sourceUrl;

  /// Pooled-ratings "Butlery-betyget" hint: the content-derived poolKey for this
  /// dish, computed client-side on save (display/index only — the server stays
  /// authoritative). Lets the card/detail read canonical_recipe_stats/{poolKey}
  /// without recomputing. Nullable + backward-safe (mirrors [sourceUrl]); null
  /// when the dish yields no key (fail-closed) or the recipe predates this field.
  String? ratingPoolKey;

  /// BUT-989: ids of recipes related to this one (variations, "used in"
  /// references, base components). Symmetric — if A.relatedRecipeIds
  /// contains B, then B.relatedRecipeIds should contain A. The
  /// `RecipeRelationsService.link/unlink` API maintains symmetry via
  /// batched writes; do not mutate this list directly.
  ///
  /// Nullable: recipes created before this field shipped have null and
  /// readers should treat that as "no relations". Empty list and null
  /// are interchangeable for display purposes.
  List<String>? relatedRecipeIds;

  /// BUT-1045: the raw source artefact this recipe was extracted from
  /// (transcript, caption, pasted text, OCR output, or just the URL).
  /// Persisted so the import pipeline can be re-run offline without
  /// re-fetching — unblocks BUT-940 "Re-extract from source".
  ///
  /// Nullable: recipes created before this field shipped will be null
  /// and simply won't show the re-extract affordance.
  SourceArtefact? sourceArtefact;

  List<String> imageUrls;

  /// URL of the pre-generated 300x300 thumbnail for this recipe's primary image.
  /// Stored after upload to avoid downloading multi-MB originals in list views.
  /// Null for recipes created before thumbnail tracking was added.
  String? thumbnailUrl;

  final DateTime createdAt;

  DateTime updatedAt;

  String? createdBy;

  bool isPublic;

  DateTime? lastCookedAt;

  /// Number of times this recipe has been marked as cooked.
  /// Null = legacy (recipe existed before the cook counter was introduced);
  /// do NOT coerce to 0 — the backfill script distinguishes "never counted"
  /// (null + lastCookedAt present) from "counted-and-zero" (explicit 0).
  int? cookCount;

  /// Normalized ingredient names for search and tagging.
  /// MODUL1 Enhancement: Stores normalized versions of ingredients
  /// with preparation words removed and plural forms normalized.
  /// Used for improved search, filtering, and shopping list grouping.
  /// Examples:
  /// - "2 dl hackad lök" → "lök"
  /// - "3 st stora ägg" → "ägg"
  /// - "glutenfri pasta" → "glutenfri pasta" (diet descriptors preserved)
  /// Optional field for backward compatibility. Null for recipes created
  /// before MODUL1 integration.
  List<String>? ingredientsNormalized;

  /// Total number of ratings this recipe has received.
  /// Denormalized aggregate maintained by Cloud Function on rating changes.
  /// Used for sorting by popularity and displaying rating counts in UI.
  /// Null for recipes without any ratings.
  int? ratingCount;

  /// Average rating value (1.0-5.0).
  /// Denormalized aggregate calculated from all ratings by Cloud Function.
  /// Provides instant access to recipe rating without querying all rating documents.
  /// Null for recipes without any ratings.
  double? averageRating;

  /// Distribution of ratings across star levels.
  /// Map structure: {1: count, 2: count, 3: count, 4: count, 5: count}
  /// Example: {1: 2, 2: 5, 3: 18, 4: 45, 5: 86} = 156 total ratings
  /// Denormalized for instant rating histogram display.
  /// Null for recipes without any ratings.
  Map<int, int>? ratingDistribution;

  /// Household family-rating average (1.0–5.0), denormalized for the card pill
  /// so the list never reads the per-household rating store per card. Written
  /// best-effort by `FamilyRatingService` when a family rating is saved on a
  /// recipe the household owns; null until then. Distinct from [averageRating]
  /// (the public/"alla" aggregate) — this is the private household verdict.
  double? familyAverage;

  /// Number of family verdicts behind [familyAverage]. Null when unrated.
  int? familyRatingCount;

  /// Timestamp of the most recent rating.
  /// Used for cache freshness detection and sorting by recently rated.
  /// Updated by Cloud Function on every rating change.
  /// Null for recipes that have never been rated.
  DateTime? lastRatedAt;

  /// SHA256 checksum of critical recipe fields for data integrity verification.
  /// Computed from: id, title, ingredients (joined), instructions (joined).
  /// Used to detect data corruption during storage/transmission.
  /// Null for recipes created before checksum feature was added.
  String? dataChecksum;

  /// Automatically generated tags with allergen and dietary status.
  /// Generated by TaggingService when recipe is saved.
  /// Contains tags, allergenStatus (tri-valued), dietaryStatus, coverage.
  /// Null for recipes created before tagging system was added.
  TagResult? tagResult;

  /// User-applied overrides to auto-generated tag results.
  /// Allows users to correct allergen/dietary status when they know better.
  /// Overrides persist across retagging operations to preserve user intent.
  /// Null for recipes that have never been manually edited.
  TagOverrides? tagOverrides;

  /// Optional heirloom OCR metadata ("Farmors lapp") — preserves the original
  /// hand-written/printed source image alongside the parsed recipe text.
  /// Null for recipes imported without an heirloom scan.
  HeirloomMetadata? heirloom;

  /// Version of the personal tag rules when tags were last evaluated.
  /// Stored as epoch milliseconds of the latest tag `updatedAt`.
  /// If any tag's `updatedAt` is newer than this, the recipe is stale.
  /// Null for recipes that haven't been evaluated by the rule engine.
  int? personalTagVersion;

  /// Whether this recipe is marked as a favorite by the user.
  /// Simple boolean flag for quick filtering in recipe list.
  bool isFavorite;

  /// Preparation time in minutes (separate from cooking time).
  int? prepTimeMinutes;

  /// Active cooking time in minutes (separate from prep time).
  int? cookTimeMinutes;

  /// Cuisine type extracted from Schema.org or auto-tagging (e.g., "Italian").
  String? cuisine;

  /// Recipe difficulty level if available from source.
  String? difficulty;

  /// Structured nutrition data from Schema.org NutritionInformation.
  NutritionInfo? nutritionInfo;

  /// In-memory status of data integrity verification.
  /// Set during deserialization based on checksum validation.
  /// Not persisted to Firestore - tracked silently for analytics.
  DataIntegrityStatus dataIntegrityStatus;

  /// BUT-648: Schema version for lazy migration on read.
  /// Default 1 — old docs without this field are treated as v1.
  final int schemaVersion;

  /// Compute SHA256 checksum from critical recipe fields.
  /// Critical fields: id, title, ingredients, instructions.
  /// These fields define the recipe's core content and any corruption
  /// would fundamentally alter what the recipe is.
  static String computeChecksum({
    required String id,
    required String title,
    required List<String> ingredients,
    required List<String> instructions,
  }) {
    final data =
        '$id|$title|${ingredients.join('|')}|${instructions.join('|')}';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify data integrity by comparing stored checksum with computed one.
  /// Returns true if checksum matches or if no checksum exists (legacy data).
  bool verifyIntegrity() {
    if (dataChecksum == null) return true; // Legacy data without checksum
    final computed = computeChecksum(
      id: id,
      title: title,
      ingredients: ingredients,
      instructions: instructions,
    );
    return computed == dataChecksum;
  }

  /// Compute and update the checksum for this recipe.
  void updateChecksum() {
    dataChecksum = computeChecksum(
      id: id,
      title: title,
      ingredients: ingredients,
      instructions: instructions,
    );
  }

  RecipeCore({
    String? id,
    required this.title,
    required this.description,
    this.portions,
    this.timeMinutes,
    required this.ingredients,
    this.structuredIngredients,
    required this.instructions,
    this.personalTagIds,
    this.personalTags,
    this.rating,
    required this.mealType,
    this.sourceUrl,
    this.ratingPoolKey,
    this.relatedRecipeIds,
    this.sourceArtefact,
    List<String>? imageUrls,
    this.thumbnailUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdBy,
    this.isPublic = false,
    this.lastCookedAt,
    this.cookCount,
    this.ingredientsNormalized,
    this.ratingCount,
    this.averageRating,
    this.ratingDistribution,
    this.familyAverage,
    this.familyRatingCount,
    this.lastRatedAt,
    this.dataChecksum,
    this.tagResult,
    this.tagOverrides,
    this.heirloom,
    this.personalTagVersion,
    this.isFavorite = false,
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    this.cuisine,
    this.difficulty,
    this.nutritionInfo,
    this.dataIntegrityStatus = DataIntegrityStatus.unverified,
    this.schemaVersion = 1,
  }) : id = id ?? const Uuid().v4(),
       imageUrls = imageUrls ?? [],
       createdAt = createdAt ?? clock.now(),
       updatedAt = updatedAt ?? clock.now() {
    // Debug-only: verify personalTagIds and personalTags stay in sync.
    // Both null or both non-null, and IDs must match when both present.
    assert(
      _personalTagsConsistent(),
      'personalTagIds and personalTags out of sync: '
      'ids=${personalTagIds?.length}, tags=${personalTags?.length}',
    );
  }

  bool _personalTagsConsistent() {
    if (personalTagIds == null && personalTags == null) return true;
    if (personalTagIds == null || personalTags == null) return true;
    if (personalTagIds!.length != personalTags!.length) return false;
    final tagIdSet = personalTags!.map((t) => t.tagId).toSet();
    return personalTagIds!.every(tagIdSet.contains);
  }

  /// Create copy with updated values.
  /// Uses sentinel pattern so passing null explicitly clears nullable fields.
  /// Note: If critical fields (title, ingredients, instructions) change,
  /// the checksum is automatically recomputed.
  RecipeCore copyWith({
    String? title,
    String? description,
    Object? portions = _sentinel,
    Object? timeMinutes = _sentinel,
    List<String>? ingredients,
    Object? structuredIngredients = _sentinel,
    List<String>? instructions,
    Object? personalTagIds = _sentinel,
    Object? personalTags = _sentinel,
    Object? rating = _sentinel,
    String? mealType,
    Object? sourceUrl = _sentinel,
    Object? ratingPoolKey = _sentinel,
    Object? relatedRecipeIds = _sentinel,
    Object? sourceArtefact = _sentinel,
    List<String>? imageUrls,
    Object? thumbnailUrl = _sentinel,
    DateTime? updatedAt,
    Object? createdBy = _sentinel,
    bool? isPublic,
    Object? lastCookedAt = _sentinel,
    Object? cookCount = _sentinel,
    Object? ingredientsNormalized = _sentinel,
    Object? ratingCount = _sentinel,
    Object? averageRating = _sentinel,
    Object? ratingDistribution = _sentinel,
    Object? familyAverage = _sentinel,
    Object? familyRatingCount = _sentinel,
    Object? lastRatedAt = _sentinel,
    Object? dataChecksum = _sentinel,
    Object? tagResult = _sentinel,
    Object? tagOverrides = _sentinel,
    Object? heirloom = _sentinel,
    Object? personalTagVersion = _sentinel,
    bool? isFavorite,
    Object? prepTimeMinutes = _sentinel,
    Object? cookTimeMinutes = _sentinel,
    Object? cuisine = _sentinel,
    Object? difficulty = _sentinel,
    Object? nutritionInfo = _sentinel,
    DataIntegrityStatus? dataIntegrityStatus,
    int? schemaVersion,
  }) {
    final newTitle = title ?? this.title;
    final newIngredients = ingredients ?? this.ingredients;
    final newInstructions = instructions ?? this.instructions;

    // Recompute checksum if critical fields changed
    final needsChecksumUpdate =
        title != null || ingredients != null || instructions != null;
    final resolvedChecksum = dataChecksum == _sentinel
        ? this.dataChecksum
        : dataChecksum as String?;
    final newChecksum = needsChecksumUpdate
        ? computeChecksum(
            id: id,
            title: newTitle,
            ingredients: newIngredients,
            instructions: newInstructions,
          )
        : resolvedChecksum;

    // Set status to valid when checksum is recomputed
    final newIntegrityStatus = needsChecksumUpdate
        ? DataIntegrityStatus.valid
        : (dataIntegrityStatus ?? this.dataIntegrityStatus);

    return RecipeCore(
      id: id,
      title: newTitle,
      description: description ?? this.description,
      portions: portions == _sentinel ? this.portions : portions as int?,
      timeMinutes: timeMinutes == _sentinel
          ? this.timeMinutes
          : timeMinutes as int?,
      ingredients: newIngredients,
      structuredIngredients: structuredIngredients == _sentinel
          ? this.structuredIngredients
          : (structuredIngredients as List?)?.cast<RecipeIngredient>(),
      instructions: newInstructions,
      // Use `(x as List?)?.cast<T>()` instead of `x as List<T>?` because
      // Dart infers a bare `[]` literal as `List<dynamic>`, which cannot be
      // cast to a parameterised list type at runtime.
      personalTagIds: personalTagIds == _sentinel
          ? this.personalTagIds
          : (personalTagIds as List?)?.cast<String>(),
      personalTags: personalTags == _sentinel
          ? this.personalTags
          : (personalTags as List?)?.cast<RecipePersonalTag>(),
      rating: rating == _sentinel ? this.rating : rating as double?,
      mealType: mealType ?? this.mealType,
      sourceUrl: sourceUrl == _sentinel ? this.sourceUrl : sourceUrl as String?,
      ratingPoolKey: ratingPoolKey == _sentinel
          ? this.ratingPoolKey
          : ratingPoolKey as String?,
      relatedRecipeIds: relatedRecipeIds == _sentinel
          ? this.relatedRecipeIds
          : (relatedRecipeIds as List?)?.cast<String>(),
      sourceArtefact: sourceArtefact == _sentinel
          ? this.sourceArtefact
          : sourceArtefact as SourceArtefact?,
      imageUrls: imageUrls ?? this.imageUrls,
      thumbnailUrl: thumbnailUrl == _sentinel
          ? this.thumbnailUrl
          : thumbnailUrl as String?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? clock.now(),
      createdBy: createdBy == _sentinel ? this.createdBy : createdBy as String?,
      isPublic: isPublic ?? this.isPublic,
      lastCookedAt: lastCookedAt == _sentinel
          ? this.lastCookedAt
          : lastCookedAt as DateTime?,
      cookCount: cookCount == _sentinel ? this.cookCount : cookCount as int?,
      ingredientsNormalized: ingredientsNormalized == _sentinel
          ? this.ingredientsNormalized
          : (ingredientsNormalized as List?)?.cast<String>(),
      ratingCount: ratingCount == _sentinel
          ? this.ratingCount
          : ratingCount as int?,
      averageRating: averageRating == _sentinel
          ? this.averageRating
          : averageRating as double?,
      ratingDistribution: ratingDistribution == _sentinel
          ? this.ratingDistribution
          : (ratingDistribution as Map?)?.cast<int, int>(),
      familyAverage: familyAverage == _sentinel
          ? this.familyAverage
          : familyAverage as double?,
      familyRatingCount: familyRatingCount == _sentinel
          ? this.familyRatingCount
          : familyRatingCount as int?,
      lastRatedAt: lastRatedAt == _sentinel
          ? this.lastRatedAt
          : lastRatedAt as DateTime?,
      dataChecksum: newChecksum,
      tagResult: tagResult == _sentinel
          ? this.tagResult
          : tagResult as TagResult?,
      tagOverrides: tagOverrides == _sentinel
          ? this.tagOverrides
          : tagOverrides as TagOverrides?,
      heirloom: heirloom == _sentinel
          ? this.heirloom
          : heirloom as HeirloomMetadata?,
      personalTagVersion: personalTagVersion == _sentinel
          ? this.personalTagVersion
          : personalTagVersion as int?,
      isFavorite: isFavorite ?? this.isFavorite,
      prepTimeMinutes: prepTimeMinutes == _sentinel
          ? this.prepTimeMinutes
          : prepTimeMinutes as int?,
      cookTimeMinutes: cookTimeMinutes == _sentinel
          ? this.cookTimeMinutes
          : cookTimeMinutes as int?,
      cuisine: cuisine == _sentinel ? this.cuisine : cuisine as String?,
      difficulty: difficulty == _sentinel
          ? this.difficulty
          : difficulty as String?,
      nutritionInfo: nutritionInfo == _sentinel
          ? this.nutritionInfo
          : nutritionInfo as NutritionInfo?,
      dataIntegrityStatus: newIntegrityStatus,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  // Helper getters
  bool get hasImages => imageUrls.isNotEmpty;
  String? get primaryImageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;
  String? get displayThumbnailUrl => thumbnailUrl ?? primaryImageUrl;
  String get cookTimeText => timeMinutes != null
      ? AppLocale.current.recipeCookTimeMinutes(timeMinutes!)
      : '–';

  /// Display text for prep time, or null if not available.
  String? get prepTimeText =>
      prepTimeMinutes != null ? '$prepTimeMinutes min prep' : null;

  /// Display text for active cooking time, or null if not available.
  String? get activeCookTimeText =>
      cookTimeMinutes != null ? '$cookTimeMinutes min tillagning' : null;

  /// Whether separate prep/cook times are available.
  bool get hasSplitTime => prepTimeMinutes != null || cookTimeMinutes != null;

  String? get lastCookedText {
    if (lastCookedAt == null) return null;
    final now = clock.now();
    final difference = now.difference(lastCookedAt!);
    if (difference.inDays == 0) return AppLocale.current.recipeLastCookedToday;
    if (difference.inDays == 1) {
      return AppLocale.current.recipeLastCookedYesterday;
    }
    return AppLocale.current.recipeLastCookedDaysAgo(difference.inDays);
  }

  /// Star histogram with STRING keys.
  ///
  /// The field is `Map<int, int>` in memory because every consumer wants int
  /// stars, but neither sink accepts int keys: `jsonEncode` (offline cache)
  /// throws on a non-String key, and cloud_firestore casts every nested map key
  /// with `key as String` in `_CodecUtility.replaceValueWithDelegatesInMap`
  /// before the write leaves Dart. `SerializationUtils.safeIntKeyIntMap` parses
  /// them back on read, so this is lossless in both directions.
  Map<String, int>? get _ratingDistributionSerialized =>
      ratingDistribution?.map((stars, tally) => MapEntry('$stars', tally));

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'portions': portions,
    'timeMinutes': timeMinutes,
    'ingredients': ingredients,
    // Omit when null so legacy/manual recipes stay legacy — readers
    // treat absence as "no structured data" and fall back to raw.
    if (structuredIngredients != null)
      'structuredIngredients': structuredIngredients!
          .map((i) => i.toJson())
          .toList(),
    'instructions': instructions,
    'personalTagIds': personalTagIds,
    'personalTags': personalTags?.map((t) => t.toMap()).toList(),
    'rating': rating,
    'mealType': mealType,
    'sourceUrl': sourceUrl,
    'ratingPoolKey': ratingPoolKey,
    'relatedRecipeIds': relatedRecipeIds,
    'sourceArtefact': sourceArtefact?.toJson(),
    'imageUrls': imageUrls,
    'thumbnailUrl': thumbnailUrl,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'createdBy': createdBy,
    'isPublic': isPublic,
    'lastCookedAt': lastCookedAt?.toIso8601String(),
    // Omit cookCount when null so legacy recipes stay legacy — readers
    // treat absence as "pre-counter era," distinct from an explicit 0.
    if (cookCount != null) 'cookCount': cookCount,
    'ingredientsNormalized': ingredientsNormalized,
    'ratingCount': ratingCount,
    'averageRating': averageRating,
    'ratingDistribution': _ratingDistributionSerialized,
    'familyAverage': familyAverage,
    'familyRatingCount': familyRatingCount,
    'lastRatedAt': lastRatedAt?.toIso8601String(),
    'dataChecksum': dataChecksum,
    'tagResult': tagResult?.toJson(),
    'tagOverrides': tagOverrides?.toJson(),
    'heirloom': heirloom?.toJson(),
    'personalTagVersion': personalTagVersion,
    'isFavorite': isFavorite,
    'prepTimeMinutes': prepTimeMinutes,
    'cookTimeMinutes': cookTimeMinutes,
    'cuisine': cuisine,
    'difficulty': difficulty,
    'nutritionInfo': nutritionInfo?.toJson(),
    'schemaVersion': schemaVersion,
  };

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'title': title,
    'titleLower': title.toLowerCase(),
    'description': description,
    'portions': portions,
    'timeMinutes': timeMinutes,
    'ingredients': ingredients,
    // Omit when null — see toJson.
    if (structuredIngredients != null)
      'structuredIngredients': structuredIngredients!
          .map((i) => i.toJson())
          .toList(),
    'instructions': instructions,
    'personalTagIds': personalTagIds,
    'personalTags': personalTags?.map((t) => t.toMap()).toList(),
    'rating': rating,
    'mealType': mealType,
    'sourceUrl': sourceUrl,
    'ratingPoolKey': ratingPoolKey,
    'relatedRecipeIds': relatedRecipeIds,
    'sourceArtefact': sourceArtefact?.toJson(),
    'imageUrls': imageUrls,
    'thumbnailUrl': thumbnailUrl,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'createdBy': createdBy,
    'isPublic': isPublic,
    'lastCookedAt': lastCookedAt != null
        ? Timestamp.fromDate(lastCookedAt!)
        : null,
    // Safe-map: write cookCount only when set so legacy docs are untouched
    // and the security rule's "null -> 1 on first increment" branch applies.
    if (cookCount != null) 'cookCount': cookCount,
    'ingredientsNormalized': ingredientsNormalized,
    'ratingCount': ratingCount,
    'averageRating': averageRating,
    'ratingDistribution': _ratingDistributionSerialized,
    'familyAverage': familyAverage,
    'familyRatingCount': familyRatingCount,
    'lastRatedAt': lastRatedAt != null
        ? Timestamp.fromDate(lastRatedAt!)
        : null,
    'dataChecksum': dataChecksum,
    'tagResult': tagResult?.toFirestore(),
    'tagOverrides': tagOverrides?.toJson(),
    'heirloom': heirloom?.toFirestore(),
    'personalTagVersion': personalTagVersion,
    'isFavorite': isFavorite,
    'prepTimeMinutes': prepTimeMinutes,
    'cookTimeMinutes': cookTimeMinutes,
    'cuisine': cuisine,
    'difficulty': difficulty,
    'nutritionInfo': nutritionInfo?.toFirestore(),
    'schemaVersion': schemaVersion,
  };

  factory RecipeCore.fromJson(Map<String, dynamic> json) {
    final id = utils.SerializationUtils.safeString(json, 'id');
    final title = utils.SerializationUtils.safeString(json, 'title');
    final ingredients = List<String>.from(
      (json['ingredients'] as List?).orEmpty(),
    );
    final instructions = List<String>.from(
      (json['instructions'] as List?).orEmpty(),
    );
    final storedChecksum = utils.SerializationUtils.safeNullableString(
      json,
      'dataChecksum',
    );

    // Compute data integrity status
    DataIntegrityStatus integrityStatus;
    if (storedChecksum == null) {
      integrityStatus = DataIntegrityStatus.unverified;
    } else {
      final computedChecksum = computeChecksum(
        id: id,
        title: title,
        ingredients: ingredients,
        instructions: instructions,
      );
      if (computedChecksum == storedChecksum) {
        integrityStatus = DataIntegrityStatus.valid;
      } else {
        integrityStatus = DataIntegrityStatus.invalid;
        AppLogger.warning(
          '⚠️ Data integrity check failed for recipe $id: '
          'stored checksum does not match computed checksum',
        );
      }
    }

    return RecipeCore(
      id: id,
      title: title,
      description: utils.SerializationUtils.safeString(json, 'description'),
      portions: utils.SerializationUtils.safeNullableInt(json, 'portions'),
      timeMinutes: utils.SerializationUtils.safeNullableInt(
        json,
        'timeMinutes',
      ),
      ingredients: ingredients,
      structuredIngredients: RecipeIngredient.listFromJson(
        json['structuredIngredients'],
      ),
      instructions: instructions,
      personalTagIds: json['personalTagIds'] != null
          ? List<String>.from(json['personalTagIds'])
          : null,
      personalTags: _parsePersonalTags(
        json['personalTags'],
        json['personalTagIds'],
      ),
      rating: (json['rating'] as num?)?.toDouble(),
      mealType: utils.SerializationUtils.safeString(
        json,
        'mealType',
        defaultValue: 'Middag',
      ),
      sourceUrl: utils.SerializationUtils.safeNullableString(json, 'sourceUrl'),
      ratingPoolKey: utils.SerializationUtils.safeNullableString(
        json,
        'ratingPoolKey',
      ),
      relatedRecipeIds: json['relatedRecipeIds'] is List
          ? List<String>.from(json['relatedRecipeIds'] as List)
          : null,
      sourceArtefact: json['sourceArtefact'] is Map<String, dynamic>
          ? SourceArtefact.fromJson(
              json['sourceArtefact'] as Map<String, dynamic>,
            )
          : null,
      imageUrls: List<String>.from((json['imageUrls'] as List?).orEmpty()),
      thumbnailUrl: utils.SerializationUtils.safeNullableString(
        json,
        'thumbnailUrl',
      ),
      createdAt: utils.SerializationUtils.safeRequiredDateTime(
        json,
        'createdAt',
      ),
      updatedAt: utils.SerializationUtils.safeRequiredDateTime(
        json,
        'updatedAt',
      ),
      createdBy: utils.SerializationUtils.safeNullableString(json, 'createdBy'),
      isPublic: utils.SerializationUtils.safeBool(json, 'isPublic'),
      lastCookedAt: utils.SerializationUtils.safeDateTime(json, 'lastCookedAt'),
      cookCount: utils.SerializationUtils.safeNullableInt(json, 'cookCount'),
      ingredientsNormalized: json['ingredientsNormalized'] != null
          ? List<String>.from(json['ingredientsNormalized'])
          : null,
      ratingCount: utils.SerializationUtils.safeNullableInt(
        json,
        'ratingCount',
      ),
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      ratingDistribution: utils.SerializationUtils.safeIntKeyIntMap(
        json,
        'ratingDistribution',
      ),
      familyAverage: (json['familyAverage'] as num?)?.toDouble(),
      familyRatingCount: utils.SerializationUtils.safeNullableInt(
        json,
        'familyRatingCount',
      ),
      lastRatedAt: utils.SerializationUtils.safeDateTime(json, 'lastRatedAt'),
      dataChecksum: storedChecksum,
      tagResult: _parseTagResult(json['tagResult']),
      tagOverrides: _parseTagOverrides(json['tagOverrides']),
      heirloom: _parseHeirloom(json['heirloom']),
      personalTagVersion: utils.SerializationUtils.safeNullableInt(
        json,
        'personalTagVersion',
      ),
      isFavorite: utils.SerializationUtils.safeBool(json, 'isFavorite'),
      prepTimeMinutes: utils.SerializationUtils.safeNullableInt(
        json,
        'prepTimeMinutes',
      ),
      cookTimeMinutes: utils.SerializationUtils.safeNullableInt(
        json,
        'cookTimeMinutes',
      ),
      cuisine: utils.SerializationUtils.safeNullableString(json, 'cuisine'),
      difficulty: utils.SerializationUtils.safeNullableString(
        json,
        'difficulty',
      ),
      nutritionInfo: json['nutritionInfo'] != null
          ? NutritionInfo.fromJson(
              json['nutritionInfo'] as Map<String, dynamic>,
            )
          : null,
      dataIntegrityStatus: integrityStatus,
      schemaVersion: json['schemaVersion'] as int? ?? 1,
    );
  }

  /// Parses personalTags from stored data with lazy migration.
  /// If the new field exists, uses it. Otherwise, converts old names
  /// to RecipePersonalTag objects with 'manual' source.
  static List<RecipePersonalTag>? _parsePersonalTags(
    dynamic personalTagsData,
    dynamic personalTagIdsData,
  ) {
    // New field exists - use it
    if (personalTagsData != null && personalTagsData is List) {
      try {
        return personalTagsData
            .whereType<Map>()
            .map((m) => RecipePersonalTag.fromMap(Map<String, dynamic>.from(m)))
            .toList();
      } catch (e) {
        AppLogger.warning('Failed to parse personalTags: $e');
      }
    }

    // Fallback: create RecipePersonalTag objects from personalTagIds UUIDs
    if (personalTagIdsData != null && personalTagIdsData is List) {
      final ids = personalTagIdsData
          .map((e) => e?.toString())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
      if (ids.isNotEmpty) {
        return ids
            .map((id) => RecipePersonalTag.manual(tagId: id, name: id))
            .toList();
      }
    }

    return null;
  }

  /// Safely parses tagResult from dynamic value.
  /// Returns null if parsing fails instead of throwing.
  static TagResult? _parseTagResult(dynamic value) {
    if (value == null) return null;
    try {
      if (value is Map<String, dynamic>) {
        return TagResult.fromFirestore(value);
      }
      // Handle Map<dynamic, dynamic> case from Firestore
      if (value is Map) {
        return TagResult.fromFirestore(Map<String, dynamic>.from(value));
      }
    } catch (e) {
      AppLogger.warning('Failed to parse tagResult: $e');
    }
    return null;
  }

  /// Safely parses heirloom metadata from dynamic value.
  /// Returns null if parsing fails instead of throwing — preserves
  /// backward compatibility for recipes saved before heirloom field existed.
  static HeirloomMetadata? _parseHeirloom(dynamic value) {
    if (value == null) return null;
    try {
      if (value is Map<String, dynamic>) {
        return HeirloomMetadata.fromMap(value);
      }
      if (value is Map) {
        return HeirloomMetadata.fromMap(Map<String, dynamic>.from(value));
      }
    } catch (e) {
      AppLogger.warning('Failed to parse heirloom: $e');
    }
    return null;
  }

  /// Safely parses tagOverrides from dynamic value.
  /// Returns null if parsing fails instead of throwing.
  static TagOverrides? _parseTagOverrides(dynamic value) {
    if (value == null) return null;
    try {
      if (value is Map<String, dynamic>) {
        return TagOverrides.fromJson(value);
      }
      // Handle Map<dynamic, dynamic> case from Firestore
      if (value is Map) {
        return TagOverrides.fromJson(Map<String, dynamic>.from(value));
      }
    } catch (e) {
      AppLogger.warning('Failed to parse tagOverrides: $e');
    }
    return null;
  }

  /// Create from repository data map (removes Firebase dependency)
  factory RecipeCore.fromMap(String id, Map<String, dynamic> data) {
    final title = utils.SerializationUtils.safeString(data, 'title');
    final ingredients = utils.SerializationUtils.safeStringList(
      data,
      'ingredients',
    );
    final instructions = utils.SerializationUtils.safeStringList(
      data,
      'instructions',
    );
    final storedChecksum = utils.SerializationUtils.safeNullableString(
      data,
      'dataChecksum',
    );

    // Compute data integrity status
    DataIntegrityStatus integrityStatus;
    if (storedChecksum == null) {
      integrityStatus = DataIntegrityStatus.unverified;
    } else {
      final computedChecksum = computeChecksum(
        id: id,
        title: title,
        ingredients: ingredients,
        instructions: instructions,
      );
      if (computedChecksum == storedChecksum) {
        integrityStatus = DataIntegrityStatus.valid;
      } else {
        integrityStatus = DataIntegrityStatus.invalid;
        AppLogger.warning(
          '⚠️ Data integrity check failed for recipe $id: '
          'stored checksum does not match computed checksum',
        );
      }
    }

    return RecipeCore(
      id: id,
      title: title,
      description: utils.SerializationUtils.safeString(data, 'description'),
      portions: utils.SerializationUtils.safeNullableInt(data, 'portions'),
      timeMinutes: utils.SerializationUtils.safeNullableInt(
        data,
        'timeMinutes',
      ),
      ingredients: ingredients,
      structuredIngredients: RecipeIngredient.listFromJson(
        data['structuredIngredients'],
      ),
      instructions: instructions,
      personalTagIds:
          utils.SerializationUtils.safeStringList(
            data,
            'personalTagIds',
          ).isNotEmpty
          ? utils.SerializationUtils.safeStringList(data, 'personalTagIds')
          : null,
      personalTags: _parsePersonalTags(
        data['personalTags'],
        data['personalTagIds'],
      ),
      rating: utils.SerializationUtils.safeNullableDouble(data, 'rating'),
      mealType: utils.SerializationUtils.safeString(
        data,
        'mealType',
        defaultValue: 'Middag',
      ),
      sourceUrl: utils.SerializationUtils.safeNullableString(data, 'sourceUrl'),
      ratingPoolKey: utils.SerializationUtils.safeNullableString(
        data,
        'ratingPoolKey',
      ),
      relatedRecipeIds: data['relatedRecipeIds'] is List
          ? List<String>.from(data['relatedRecipeIds'] as List)
          : null,
      sourceArtefact: data['sourceArtefact'] is Map<String, dynamic>
          ? SourceArtefact.fromJson(
              data['sourceArtefact'] as Map<String, dynamic>,
            )
          : null,
      imageUrls: utils.SerializationUtils.safeStringList(data, 'imageUrls'),
      thumbnailUrl: utils.SerializationUtils.safeNullableString(
        data,
        'thumbnailUrl',
      ),
      createdAt: utils.SerializationUtils.safeDateTime(
        data,
        'createdAt',
      ).orNow(),
      updatedAt: utils.SerializationUtils.safeDateTime(
        data,
        'updatedAt',
      ).orNow(),
      createdBy: utils.SerializationUtils.safeNullableString(data, 'createdBy'),
      isPublic: utils.SerializationUtils.safeBool(
        data,
        'isPublic',
        defaultValue: false,
      ),
      lastCookedAt: utils.SerializationUtils.safeDateTime(data, 'lastCookedAt'),
      cookCount: utils.SerializationUtils.safeNullableInt(data, 'cookCount'),
      ingredientsNormalized:
          utils.SerializationUtils.safeStringList(
            data,
            'ingredientsNormalized',
          ).isNotEmpty
          ? utils.SerializationUtils.safeStringList(
              data,
              'ingredientsNormalized',
            )
          : null,
      ratingCount: utils.SerializationUtils.safeNullableInt(
        data,
        'ratingCount',
      ),
      averageRating: utils.SerializationUtils.safeNullableDouble(
        data,
        'averageRating',
      ),
      ratingDistribution: utils.SerializationUtils.safeIntKeyIntMap(
        data,
        'ratingDistribution',
      ),
      familyAverage: utils.SerializationUtils.safeNullableDouble(
        data,
        'familyAverage',
      ),
      familyRatingCount: utils.SerializationUtils.safeNullableInt(
        data,
        'familyRatingCount',
      ),
      lastRatedAt: utils.SerializationUtils.safeDateTime(data, 'lastRatedAt'),
      dataChecksum: storedChecksum,
      tagResult: _parseTagResult(data['tagResult']),
      tagOverrides: _parseTagOverrides(data['tagOverrides']),
      heirloom: _parseHeirloom(data['heirloom']),
      personalTagVersion: utils.SerializationUtils.safeNullableInt(
        data,
        'personalTagVersion',
      ),
      isFavorite: utils.SerializationUtils.safeBool(
        data,
        'isFavorite',
        defaultValue: false,
      ),
      prepTimeMinutes: utils.SerializationUtils.safeNullableInt(
        data,
        'prepTimeMinutes',
      ),
      cookTimeMinutes: utils.SerializationUtils.safeNullableInt(
        data,
        'cookTimeMinutes',
      ),
      cuisine: utils.SerializationUtils.safeNullableString(data, 'cuisine'),
      difficulty: utils.SerializationUtils.safeNullableString(
        data,
        'difficulty',
      ),
      nutritionInfo: _parseNutritionInfo(data['nutritionInfo']),
      dataIntegrityStatus: integrityStatus,
      schemaVersion: data['schemaVersion'] as int? ?? 1,
    );
  }

  /// Safely parses NutritionInfo from dynamic value.
  static NutritionInfo? _parseNutritionInfo(dynamic value) {
    if (value == null) return null;
    try {
      if (value is Map<String, dynamic>) {
        return NutritionInfo.fromJson(value);
      }
      if (value is Map) {
        return NutritionInfo.fromJson(Map<String, dynamic>.from(value));
      }
    } catch (_) {}
    return null;
  }

  factory RecipeCore.fromFirestore(DocumentSnapshot doc) {
    return RecipeCore.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }
}

/// Social/sharing metadata for recipes
class RecipeSocialData {
  final String? ownerId;
  final String? ownerDisplayName;
  final Map<String, ResourcePermission>? memberPermissions;
  final bool allowGuestViewing;
  final bool allowMemberInvites;
  final List<String>? categoryIds;
  final String? descriptionCollaborative;

  /// Why each member has access: uid -> ['direct', 'group:<categoryId>', ...].
  ///
  /// Purely descriptive. [memberPermissions] stays the sole source of truth for
  /// access, and `firestore.rules` reads only that — so nothing here can widen
  /// what anyone may see. Revoking a group has to answer "does this person still
  /// have any reason to be here?", which is a question about a member, not about
  /// a group; hence uid-keyed rather than a per-group member list.
  final Map<String, List<String>>? grants;

  const RecipeSocialData({
    this.ownerId,
    this.ownerDisplayName,
    this.memberPermissions,
    this.allowGuestViewing = false,
    this.allowMemberInvites = true,
    this.categoryIds,
    this.descriptionCollaborative,
    this.grants,
  });

  /// The grant token recorded for a share made to [categoryId].
  static String groupGrant(String categoryId) => 'group:$categoryId';

  /// The grant token recorded for an individually made share.
  static const String directGrant = 'direct';

  Map<String, dynamic> toJson() => {
    'ownerId': ownerId,
    'ownerDisplayName': ownerDisplayName,
    'memberPermissions': memberPermissions?.map((k, v) => MapEntry(k, v.index)),
    'allowGuestViewing': allowGuestViewing,
    'allowMemberInvites': allowMemberInvites,
    'categoryIds': categoryIds,
    'descriptionCollaborative': descriptionCollaborative,
    'grants': grants,
  };

  factory RecipeSocialData.fromJson(Map<String, dynamic> json) =>
      RecipeSocialData(
        ownerId: utils.SerializationUtils.safeNullableString(json, 'ownerId'),
        ownerDisplayName: utils.SerializationUtils.safeNullableString(
          json,
          'ownerDisplayName',
        ),
        memberPermissions: json['memberPermissions'] != null
            ? Map<String, ResourcePermission>.from(
                (json['memberPermissions'] as Map).map(
                  (k, v) => MapEntry(
                    k,
                    utils.SerializationUtils.safeEnumByIndex(
                      v,
                      ResourcePermission.values,
                      ResourcePermission.viewer,
                    ),
                  ),
                ),
              )
            : null,
        allowGuestViewing: utils.SerializationUtils.safeBool(
          json,
          'allowGuestViewing',
        ),
        allowMemberInvites: utils.SerializationUtils.safeBool(
          json,
          'allowMemberInvites',
          defaultValue: true,
        ),
        categoryIds: json['categoryIds'] != null
            ? List<String>.from(json['categoryIds'])
            : null,
        descriptionCollaborative: utils.SerializationUtils.safeNullableString(
          json,
          'descriptionCollaborative',
        ),
        // Absent stays absent. A missing `grants` is NOT read as "everyone is
        // direct" — that compatibility path would be dead code, since the only
        // documents without the field are test data (Malin, 2026-08-03).
        grants: json['grants'] != null
            ? (json['grants'] as Map).map(
                (k, v) => MapEntry(
                  k as String,
                  v is List
                      ? List<String>.from(v.whereType<String>())
                      : <String>[],
                ),
              )
            : null,
      );

  RecipeSocialData copyWith({
    Object? ownerId = _sentinel,
    Object? ownerDisplayName = _sentinel,
    Object? memberPermissions = _sentinel,
    bool? allowGuestViewing,
    bool? allowMemberInvites,
    Object? categoryIds = _sentinel,
    Object? descriptionCollaborative = _sentinel,
    Object? grants = _sentinel,
  }) {
    return RecipeSocialData(
      ownerId: ownerId == _sentinel ? this.ownerId : ownerId as String?,
      ownerDisplayName: ownerDisplayName == _sentinel
          ? this.ownerDisplayName
          : ownerDisplayName as String?,
      memberPermissions: memberPermissions == _sentinel
          ? this.memberPermissions
          : memberPermissions as Map<String, ResourcePermission>?,
      allowGuestViewing: allowGuestViewing ?? this.allowGuestViewing,
      allowMemberInvites: allowMemberInvites ?? this.allowMemberInvites,
      categoryIds: categoryIds == _sentinel
          ? this.categoryIds
          : categoryIds as List<String>?,
      descriptionCollaborative: descriptionCollaborative == _sentinel
          ? this.descriptionCollaborative
          : descriptionCollaborative as String?,
      grants: grants == _sentinel
          ? this.grants
          : grants as Map<String, List<String>>?,
    );
  }
}

/// Realtime collaboration metadata
class RecipeRealtimeData {
  final List<String>? activeEditorIds;
  final Map<String, DateTime>? lastSeenAt;
  final String? lastEditedByUserId;
  final String? lastEditedByDisplayName;
  final DateTime? lastEditedAt;
  final int editCount;
  final bool isActive;

  const RecipeRealtimeData({
    this.activeEditorIds,
    this.lastSeenAt,
    this.lastEditedByUserId,
    this.lastEditedByDisplayName,
    this.lastEditedAt,
    this.editCount = 0,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'activeEditorIds': activeEditorIds,
    'lastSeenAt': lastSeenAt?.map((k, v) => MapEntry(k, v.toIso8601String())),
    'lastEditedByUserId': lastEditedByUserId,
    'lastEditedByDisplayName': lastEditedByDisplayName,
    'lastEditedAt': lastEditedAt?.toIso8601String(),
    'editCount': editCount,
    'isActive': isActive,
  };

  factory RecipeRealtimeData.fromJson(Map<String, dynamic> json) =>
      RecipeRealtimeData(
        activeEditorIds: json['activeEditorIds'] != null
            ? List<String>.from(json['activeEditorIds'])
            : null,
        lastSeenAt: json['lastSeenAt'] != null
            ? Map<String, DateTime>.from(
                (json['lastSeenAt'] as Map).map(
                  (k, v) => MapEntry(
                    k,
                    utils.SerializationUtils.parseRequiredDateTimeValue(v),
                  ),
                ),
              )
            : null,
        lastEditedByUserId: utils.SerializationUtils.safeNullableString(
          json,
          'lastEditedByUserId',
        ),
        lastEditedByDisplayName: utils.SerializationUtils.safeNullableString(
          json,
          'lastEditedByDisplayName',
        ),
        lastEditedAt: utils.SerializationUtils.safeDateTime(
          json,
          'lastEditedAt',
        ),
        editCount: utils.SerializationUtils.safeInt(json, 'editCount'),
        isActive: utils.SerializationUtils.safeBool(
          json,
          'isActive',
          defaultValue: true,
        ),
      );
}

/// Offline sync metadata
class RecipeOfflineData {
  final DateTime? lastSyncedAt;
  final bool isModifiedOffline;
  final List<String>? pendingChanges;

  const RecipeOfflineData({
    this.lastSyncedAt,
    this.isModifiedOffline = false,
    this.pendingChanges,
  });

  bool get needsSync => isModifiedOffline || lastSyncedAt == null;

  Map<String, dynamic> toJson() => {
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    'isModifiedOffline': isModifiedOffline,
    'pendingChanges': pendingChanges,
  };

  factory RecipeOfflineData.fromJson(Map<String, dynamic> json) =>
      RecipeOfflineData(
        lastSyncedAt: utils.SerializationUtils.safeDateTime(
          json,
          'lastSyncedAt',
        ),
        isModifiedOffline: utils.SerializationUtils.safeBool(
          json,
          'isModifiedOffline',
        ),
        pendingChanges: json['pendingChanges'] != null
            ? List<String>.from(json['pendingChanges'])
            : null,
      );
}

/// Clean facade for unified recipe using focused modules
/// This facade provides a unified API that delegates to focused modules:
/// - RecipeOperations: Content manipulation (ingredients, instructions, etc.)
/// - RecipeFactory: Construction and conversion methods
/// - RecipeSerialization: JSON/Firestore serialization
/// ❌ DOES NOT CONTAIN: Complex business logic, direct implementation details
class Recipe {
  final RecipeCore core;
  final RecipeType type;
  final RecipeSocialData? socialData;
  final RecipeRealtimeData? realtimeData;
  final RecipeOfflineData? offlineData;

  /// BUT-955: hard cap on per-recipe share count. At ~36 bytes per UUID the
  /// 1MB Firestore doc limit is reached around 27k shares; capping at 200
  /// leaves plenty of headroom for other fields. The 200 value tracks
  /// Dunbar's number (~150 stable social relationships) plus a margin —
  /// realistic friend-reach for a personal cooking app, not a viral feed.
  /// Subcollection migration is deferred until a real user hits the cap.
  static const int maxSharesPerRecipe = 200;

  const Recipe({
    required this.core,
    required this.type,
    this.socialData,
    this.realtimeData,
    this.offlineData,
  });

  // Convenience getters that delegate to core
  String get id => core.id;
  String get title => core.title;
  String get description => core.description;
  int? get portions => core.portions;
  int? get timeMinutes => core.timeMinutes;
  List<String> get ingredients => core.ingredients;
  List<String> get instructions => core.instructions;

  /// BUT-1216: structured ingredients for quantity-aware features (portion
  /// scaling, shopping aggregation). Returns the persisted structured list
  /// ONLY when it still aligns with [ingredients] (same length, each entry's
  /// `raw` matches the string at its index) — editing the free-text
  /// ingredients after import makes the stored data stale, and serving a
  /// stale amount is worse than serving none. Misaligned or missing data
  /// degrades to raw-only entries, so callers always get one entry per
  /// ingredient line.
  List<RecipeIngredient> get structuredIngredients {
    final stored = core.structuredIngredients;
    if (stored != null && _structuredAligned(stored)) return stored;
    return core.ingredients.map(RecipeIngredient.rawOnly).toList();
  }

  bool _structuredAligned(List<RecipeIngredient> stored) {
    if (stored.length != core.ingredients.length) return false;
    for (var i = 0; i < stored.length; i++) {
      if (stored[i].raw != core.ingredients[i]) return false;
    }
    return true;
  }

  List<String>? get personalTagIds => core.personalTagIds;
  double? get rating => core.rating;
  String get mealType => core.mealType;
  String? get sourceUrl => core.sourceUrl;
  List<String> get imageUrls => core.imageUrls;
  DateTime get createdAt => core.createdAt;
  DateTime get updatedAt => core.updatedAt;
  String? get createdBy => core.createdBy;
  bool get isPublic => core.isPublic;
  DateTime? get lastCookedAt => core.lastCookedAt;

  /// Display-facing cook count — null legacy values surface as 0 so UI,
  /// sort comparisons, and aggregations work without per-call-site guards.
  /// Use [cookCountRaw] when the null/zero distinction matters (e.g. backfill).
  int get cookCount => core.cookCount ?? 0;

  /// Raw cook count including null for legacy recipes (pre-counter era).
  /// Null means "never tracked" — do NOT confuse with "tracked, value 0".
  int? get cookCountRaw => core.cookCount;
  bool get isFavorite => core.isFavorite;
  int? get prepTimeMinutes => core.prepTimeMinutes;
  int? get cookTimeMinutes => core.cookTimeMinutes;
  String? get cuisine => core.cuisine;
  String? get difficulty => core.difficulty;
  NutritionInfo? get nutritionInfo => core.nutritionInfo;

  // Helper getters
  bool get hasImages => core.hasImages;
  String? get primaryImageUrl => core.primaryImageUrl;
  String? get displayThumbnailUrl => core.displayThumbnailUrl;
  String get cookTimeText => core.cookTimeText;
  String? get prepTimeText => core.prepTimeText;
  String? get activeCookTimeText => core.activeCookTimeText;
  bool get hasSplitTime => core.hasSplitTime;
  String? get lastCookedText => core.lastCookedText;
  TagResult? get tagResult => core.tagResult;
  TagOverrides? get tagOverrides => core.tagOverrides;
  HeirloomMetadata? get heirloom => core.heirloom;
  bool get hasHeirloom => core.heirloom != null;

  /// Check if recipe was cooked recently (within last 7 days)
  bool get wasCookedRecently {
    if (lastCookedAt == null) return false;
    return clock.now().difference(lastCookedAt!).inDays < 7;
  }

  // Feature-specific getters
  bool get isPersonal => type == RecipeType.personal;
  bool get isShared => type == RecipeType.shared;
  bool get isCollaborative => type == RecipeType.collaborative;
  bool get isRealtime => type == RecipeType.realtime;
  bool get needsSync => offlineData?.needsSync ?? false;

  Recipe addIngredient(
    String ingredient, {
    String? userId,
    String? userDisplayName,
  }) {
    return RecipeOperations.addIngredient(
      this,
      ingredient,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Update ingredient at index
  Recipe updateIngredient(
    int index,
    String newIngredient, {
    String? userId,
    String? userDisplayName,
  }) {
    return RecipeOperations.updateIngredient(
      this,
      index,
      newIngredient,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Remove ingredient at index
  Recipe removeIngredient(
    int index, {
    String? userId,
    String? userDisplayName,
  }) {
    return RecipeOperations.removeIngredient(
      this,
      index,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Add instruction with user tracking
  Recipe addInstruction(
    String instruction, {
    String? userId,
    String? userDisplayName,
  }) {
    return RecipeOperations.addInstruction(
      this,
      instruction,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Update instruction at index
  Recipe updateInstruction(
    int index,
    String newInstruction, {
    String? userId,
    String? userDisplayName,
  }) {
    return RecipeOperations.updateInstruction(
      this,
      index,
      newInstruction,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Remove instruction at index
  Recipe removeInstruction(
    int index, {
    String? userId,
    String? userDisplayName,
  }) {
    return RecipeOperations.removeInstruction(
      this,
      index,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Mark recipe as cooked
  Recipe markAsCooked({
    String? userId,
    String? userDisplayName,
  }) {
    return RecipeOperations.markAsCooked(
      this,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  factory Recipe.personal({
    required String title,
    required String description,
    required List<String> ingredients,
    required List<String> instructions,
    required String mealType,
    String? createdBy,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
    List<String>? imageUrls,
    bool isPublic = false,
    List<RecipeIngredient>? structuredIngredients,
  }) {
    return RecipeFactory.createPersonal(
      title: title,
      description: description,
      ingredients: ingredients,
      structuredIngredients: structuredIngredients,
      instructions: instructions,
      mealType: mealType,
      createdBy: createdBy,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      personalTagIds: personalTagIds,
      sourceUrl: sourceUrl,
      imageUrls: imageUrls,
      isPublic: isPublic,
    );
  }

  /// Create collaborative recipe
  factory Recipe.collaborative({
    required String title,
    required String description,
    required List<String> ingredients,
    required List<String> instructions,
    required String mealType,
    required String ownerId,
    required String ownerDisplayName,
    Map<String, ResourcePermission>? memberPermissions,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    String? descriptionCollaborative,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
    List<String>? imageUrls,
  }) {
    return RecipeFactory.createCollaborative(
      title: title,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      mealType: mealType,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      memberPermissions: memberPermissions,
      allowGuestViewing: allowGuestViewing,
      allowMemberInvites: allowMemberInvites,
      descriptionCollaborative: descriptionCollaborative,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      personalTagIds: personalTagIds,
      sourceUrl: sourceUrl,
      imageUrls: imageUrls,
    );
  }

  Map<String, dynamic> toJson() => RecipeSerialization.toJson(this);
  Map<String, dynamic> toFirestore() => RecipeSerialization.toFirestore(this);

  factory Recipe.fromJson(Map<String, dynamic> json) =>
      RecipeSerialization.fromJson(json);
  factory Recipe.fromMap(String id, Map<String, dynamic> data) =>
      RecipeSerialization.fromMap(id, data);
  factory Recipe.fromFirestore(DocumentSnapshot doc) =>
      RecipeSerialization.fromFirestore(doc);

  Recipe copyWith({
    String? title,
    String? description,
    Object? portions = _sentinel,
    Object? timeMinutes = _sentinel,
    List<String>? ingredients,
    Object? structuredIngredients = _sentinel,
    List<String>? instructions,
    Object? personalTagIds = _sentinel,
    Object? personalTags = _sentinel,
    Object? rating = _sentinel,
    String? mealType,
    Object? sourceUrl = _sentinel,
    Object? relatedRecipeIds = _sentinel,
    Object? sourceArtefact = _sentinel,
    List<String>? imageUrls,
    Object? createdBy = _sentinel,
    bool? isPublic,
    Object? lastCookedAt = _sentinel,
    Object? cookCount = _sentinel,
    Object? ingredientsNormalized = _sentinel,
    String? lastEditedByUserId,
    String? lastEditedByDisplayName,
    RecipeType? type,
    Object? socialData = _sentinel,
    Object? realtimeData = _sentinel,
    Object? offlineData = _sentinel,
    Object? tagOverrides = _sentinel,
    Object? tagResult = _sentinel,
    Object? heirloom = _sentinel,
    Object? personalTagVersion = _sentinel,
    bool? isFavorite,
    Object? familyAverage = _sentinel,
    Object? familyRatingCount = _sentinel,
    DateTime? updatedAt,
  }) {
    return Recipe(
      core: core.copyWith(
        familyAverage: familyAverage,
        familyRatingCount: familyRatingCount,
        title: title,
        description: description,
        portions: portions,
        timeMinutes: timeMinutes,
        ingredients: ingredients,
        structuredIngredients: structuredIngredients,
        instructions: instructions,
        personalTagIds: personalTagIds,
        personalTags: personalTags,
        rating: rating,
        mealType: mealType,
        sourceUrl: sourceUrl,
        relatedRecipeIds: relatedRecipeIds,
        sourceArtefact: sourceArtefact,
        imageUrls: imageUrls,
        createdBy: createdBy,
        isPublic: isPublic,
        lastCookedAt: lastCookedAt,
        cookCount: cookCount,
        ingredientsNormalized: ingredientsNormalized,
        tagOverrides: tagOverrides,
        tagResult: tagResult,
        heirloom: heirloom,
        personalTagVersion: personalTagVersion,
        isFavorite: isFavorite,
        updatedAt: updatedAt ?? clock.now(),
      ),
      type: type ?? this.type,
      // When converting to personal recipe, clear social data
      socialData: (type == RecipeType.personal && type != this.type)
          ? null
          : (socialData == _sentinel
                ? this.socialData
                : socialData as RecipeSocialData?),
      realtimeData: realtimeData == _sentinel
          ? this.realtimeData
          : realtimeData as RecipeRealtimeData?,
      offlineData: offlineData == _sentinel
          ? this.offlineData
          : offlineData as RecipeOfflineData?,
    );
  }
}
