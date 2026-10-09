/// BUT-907: something the user deleted, kept 30 days in their trash.
///
/// Where it lives: `users/{uid}/trash/{id}`, where the id is the deleted
/// recipe's own id, so deleting a restored recipe again leaves one row, not
/// two. firestore.rules lets only the owner read and create it, never update
/// it, and lets the owner or an admin delete it. [expireAt] is what the
/// Firestore TTL policy deletes on (firestore.indexes.json), and it is also
/// the line after which the app stops offering the row, because the TTL sweep
/// can run a day late.
///
/// [payload] is the recipe's own Firestore map built from [payloadKeys], an
/// allowlist: who the recipe was shared with ([Recipe.socialData]) and who
/// last edited it ([Recipe.realtimeData]) never reach the trash, so a restored
/// recipe is private and the copy names nobody but its owner (F7).
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/recipe/recipe_serialization.dart';
import 'package:butlery/models/recipe_unified.dart';

/// What kind of thing a trash row holds. Only recipes in step 1.
enum TrashItemKind {
  recipe('recipe')
  ;

  const TrashItemKind(this.value);

  /// The stored `kind`, the value firestore.rules checks.
  final String value;

  static TrashItemKind? fromValue(Object? value) =>
      values.where((k) => k.value == value).firstOrNull;
}

class TrashItem {
  const TrashItem({
    required this.id,
    required this.kind,
    required this.ownerId,
    required this.sourceId,
    required this.title,
    required this.thumbnailUrl,
    required this.payload,
    required this.deletedAt,
    required this.expireAt,
  });

  /// How long a deleted item is kept (F3).
  static const Duration keptFor = Duration(days: 30);

  /// The longest title stored, in UTF-16 code units; firestore.rules refuses
  /// a longer one.
  static const int maxTitleLength = 200;

  /// The recipe's top-level Firestore keys a trash copy keeps. `rev` is the
  /// recipe's revision (BUT-2213), which a restore raises by one.
  static const Set<String> payloadKeys = {'core', 'type', 'rev'};

  /// Document id, equal to [sourceId].
  final String id;
  final TrashItemKind kind;

  /// The user whose trash this is.
  final String ownerId;

  /// The id the item had, and gets back on a restore.
  final String sourceId;

  /// Shown in the trash list, so the list never parses [payload].
  final String title;
  final String? thumbnailUrl;

  /// The item as its own collection stores it (see [payloadKeys]).
  final Map<String, dynamic> payload;

  /// When it was deleted (the device's clock), and exactly [keptFor] later,
  /// when it stops being kept.
  final DateTime deletedAt;
  final DateTime expireAt;

  /// [recipe], owned by [ownerId], as it goes into the trash now.
  factory TrashItem.fromRecipe(Recipe recipe, {required String ownerId}) {
    final deletedAt = clock.now().toUtc();
    final stored = <String, dynamic>{
      ...RecipeSerialization.toFirestore(recipe),
      // A restored recipe is private (F7), so it comes back as a personal one.
      'type': RecipeType.personal.index,
      'rev': ?recipe.rev,
    };
    return TrashItem(
      id: recipe.id,
      kind: TrashItemKind.recipe,
      ownerId: ownerId,
      sourceId: recipe.id,
      title: capTitle(recipe.title.trim()),
      thumbnailUrl: recipe.displayThumbnailUrl,
      payload: {
        for (final key in payloadKeys)
          if (stored.containsKey(key)) key: stored[key],
      },
      deletedAt: deletedAt,
      expireAt: deletedAt.add(keptFor),
    );
  }

  /// [title] cut to [maxTitleLength] without splitting a character.
  static String capTitle(String title) {
    if (title.length <= maxTitleLength) return title;
    final out = StringBuffer();
    for (final rune in title.runes) {
      final char = String.fromCharCode(rune);
      if (out.length + char.length > maxTitleLength) break;
      out.write(char);
    }
    return out.toString();
  }

  /// Whether the item may still be offered, or restored, at [now].
  bool isKeptAt(DateTime now) => now.isBefore(expireAt);

  /// The recipe [payload] holds, under its own id.
  Recipe get recipe => RecipeSerialization.fromMap(sourceId, payload);

  /// The stored shape. The field set matches the create rule in
  /// firestore.rules (`match /users/{userId}/trash/{itemId}`).
  Map<String, dynamic> toFirestore() => {
    'kind': kind.value,
    'ownerId': ownerId,
    'sourceId': sourceId,
    'title': title,
    'thumbnailUrl': thumbnailUrl,
    'payload': payload,
    'deletedAt': Timestamp.fromDate(deletedAt),
    'expireAt': Timestamp.fromDate(expireAt),
  };

  /// Parses a stored row, or returns null when it is not one this app can
  /// restore (an unknown kind or a missing field). Such a row is never
  /// offered.
  static TrashItem? fromFirestore(String id, Map<String, dynamic> data) {
    final kind = TrashItemKind.fromValue(data['kind']);
    final deletedAt = SerializationUtils.safeDateTime(data, 'deletedAt');
    final expireAt = SerializationUtils.safeDateTime(data, 'expireAt');
    final payload = SerializationUtils.safeNullableMap(data, 'payload');
    final ownerId = SerializationUtils.safeString(data, 'ownerId');
    final sourceId = SerializationUtils.safeString(data, 'sourceId');
    if (kind == null ||
        deletedAt == null ||
        expireAt == null ||
        payload == null ||
        ownerId.isEmpty ||
        sourceId.isEmpty) {
      return null;
    }
    return TrashItem(
      id: id,
      kind: kind,
      ownerId: ownerId,
      sourceId: sourceId,
      title: SerializationUtils.safeString(data, 'title'),
      thumbnailUrl: SerializationUtils.safeNullableString(data, 'thumbnailUrl'),
      payload: payload,
      deletedAt: deletedAt.toUtc(),
      expireAt: expireAt.toUtc(),
    );
  }
}
