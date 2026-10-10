import 'package:flutter/foundation.dart';

import 'package:butlery/core/utils/serialization_utils.dart';

/// What a cookbook's cover shows.
enum CookbookCoverKind {
  color,

  /// A photo the user uploaded for the cover.
  photo,

  /// The photo of one recipe in the book, resolved from the recipe when drawn
  /// so a deleted recipe falls back to the colour instead of a dead URL.
  recipe
  ;

  static CookbookCoverKind fromName(String? name) => CookbookCoverKind.values
      .firstWhere((k) => k.name == name, orElse: () => CookbookCoverKind.color);
}

@immutable
class CookbookCover {
  final CookbookCoverKind kind;

  /// Palette key from `CookbookCoverPalette`; also the fallback when the
  /// photo is missing.
  final String colorKey;
  final String? imageUrl;
  final String? recipeId;

  const CookbookCover({
    this.kind = CookbookCoverKind.color,
    this.colorKey = defaultColorKey,
    this.imageUrl,
    this.recipeId,
  });

  static const String defaultColorKey = 'moss';

  factory CookbookCover.fromMap(Map<String, dynamic> data) {
    return CookbookCover(
      kind: CookbookCoverKind.fromName(
        SerializationUtils.safeNullableString(data, 'kind'),
      ),
      colorKey: SerializationUtils.safeString(
        data,
        'colorKey',
        defaultValue: defaultColorKey,
      ),
      imageUrl: SerializationUtils.safeNullableString(data, 'imageUrl'),
      recipeId: SerializationUtils.safeNullableString(data, 'recipeId'),
    );
  }

  Map<String, dynamic> toMap() => {
    'kind': kind.name,
    'colorKey': colorKey,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (recipeId != null) 'recipeId': recipeId,
  };

  @override
  bool operator ==(Object other) =>
      other is CookbookCover &&
      other.kind == kind &&
      other.colorKey == colorKey &&
      other.imageUrl == imageUrl &&
      other.recipeId == recipeId;

  @override
  int get hashCode => Object.hash(kind, colorKey, imageUrl, recipeId);
}

/// The cookbook half of a personal tag (BUT-1325). A tag whose document has
/// no `cookbook` map is not a cookbook.
///
/// Membership is the recipe's `personalTagIds`, never [recipeOrder]: the
/// list only orders, so tagging a recipe from the recipe screen needs no
/// second write and the two can never disagree about who is in the book.
@immutable
class CookbookDetails {
  final String description;
  final CookbookCover cover;

  /// Null means A–Ö; a list means the user's own order.
  final List<String>? recipeOrder;

  /// Text the user wrote for a recipe in this book only, keyed by recipe id.
  /// The recipe itself is never changed, so the same recipe can carry a
  /// different note in each book.
  final Map<String, String> recipeNotes;

  const CookbookDetails({
    this.description = '',
    this.cover = const CookbookCover(),
    this.recipeOrder,
    this.recipeNotes = const {},
  });

  static const int maxDescriptionLength = 300;

  /// Keeps the tag document far below Firestore's 1 MiB limit.
  static const int maxOrderedRecipes = 1000;

  static const int maxNoteLength = 300;

  String? noteFor(String recipeId) => recipeNotes[recipeId];

  bool get hasCustomOrder => recipeOrder != null;

  factory CookbookDetails.fromMap(Map<String, dynamic> data) {
    final order = data['recipeOrder'];
    return CookbookDetails(
      description: SerializationUtils.safeString(
        data,
        'description',
        defaultValue: '',
      ),
      cover: CookbookCover.fromMap(SerializationUtils.safeMap(data, 'cover')),
      recipeOrder: order is List
          ? SerializationUtils.safeStringList(data, 'recipeOrder')
          : null,
      recipeNotes: _parseNotes(data['recipeNotes']),
    );
  }

  static Map<String, String> _parseNotes(dynamic value) {
    if (value is! Map) return const {};
    return {
      for (final e in value.entries)
        if (e.key is String &&
            e.value is String &&
            (e.value as String).isNotEmpty)
          e.key as String: e.value as String,
    };
  }

  Map<String, dynamic> toMap() => {
    'description': description,
    'cover': cover.toMap(),
    if (recipeOrder != null) 'recipeOrder': recipeOrder,
    if (recipeNotes.isNotEmpty) 'recipeNotes': recipeNotes,
  };

  CookbookDetails copyWith({
    String? description,
    CookbookCover? cover,
    List<String>? recipeOrder,
    bool clearRecipeOrder = false,
    Map<String, String>? recipeNotes,
  }) {
    return CookbookDetails(
      description: description ?? this.description,
      cover: cover ?? this.cover,
      recipeOrder: clearRecipeOrder ? null : (recipeOrder ?? this.recipeOrder),
      recipeNotes: recipeNotes ?? this.recipeNotes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CookbookDetails &&
      other.description == description &&
      other.cover == cover &&
      listEquals(other.recipeOrder, recipeOrder) &&
      mapEquals(other.recipeNotes, recipeNotes);

  @override
  int get hashCode => Object.hash(
    description,
    cover,
    recipeOrder == null ? null : Object.hashAll(recipeOrder!),
    recipeNotes.length,
  );
}
