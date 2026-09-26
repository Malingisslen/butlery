/// P5-U27b: a change to someone else's shared recipe, kept as a suggestion.
///
/// produktregler.md:103: "Recept (delat, andras) · Ägarens version vinner, din
/// ändring blir ett förslag · banner + 'Se ditt förslag' · ja, 7 dagar".
/// produktregler.md:241: a member cannot edit a recipe someone else owns; the
/// change is kept as a suggestion that the owner accepts or dismisses.
/// PQ-02 = A (2026-09-23) put the store in package 6.
///
/// Where it lives: the top-level `recipe_suggestions/{id}`, because two people
/// read it: the one who suggested it and the recipe's owner. firestore.rules
/// lets only those two read it, only the suggester create it (and only for a
/// recipe the owner has shared with them), and only the owner decide it. It
/// is never edited otherwise and never deleted by a client: the Firestore TTL
/// policy deletes it at [expiresAt] (firestore.indexes.json), and the account
/// deletion cascade erases it with either account.
///
/// Identity is the document id, never the recipe's title, a row number or the
/// time it was made.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Where a suggestion stands. Only [pending] is offered to the owner.
enum RecipeSuggestionStatus { pending, accepted, dismissed }

/// One suggested change to a shared recipe, kept for [RecipeSuggestion.keptFor].
class RecipeSuggestion {
  const RecipeSuggestion({
    required this.id,
    required this.recipeId,
    required this.ownerId,
    required this.suggesterId,
    required this.suggestion,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.decidedAt,
  });

  /// How long a suggestion is kept (produktregler.md:103, "ja, 7 dagar").
  static const Duration keptFor = Duration(days: 7);

  /// Firestore document id. Empty until the repository has stored it.
  final String id;

  /// The shared recipe the suggestion is for. The same id recipe detail and
  /// the realtime sync use (RealtimeRecipe.fromRecipe keeps `recipe.id`).
  final String recipeId;

  /// The recipe's owner: the only one who may accept or dismiss it.
  final String ownerId;

  /// Who suggested it: the only one who may create it.
  final String suggesterId;

  // No name is stored: the owner decides on a name no one but the suggester
  // could have typed. The app resolves the name from [suggesterId], which
  // firestore.rules pins to the signed-in writer
  // (RecipeSuggestionService.suggesterNameOf).

  /// The suggested recipe, serialized as the realtime recipe's own
  /// `toFirestore()` map.
  final Map<String, dynamic> suggestion;

  final RecipeSuggestionStatus status;

  /// When it was made, and when it stops being kept (exactly [keptFor]
  /// later; firestore.rules checks that).
  final DateTime createdAt;
  final DateTime expiresAt;

  /// When the owner accepted or dismissed it. Null while pending.
  final DateTime? decidedAt;

  /// A new pending suggestion made at [at].
  factory RecipeSuggestion.create({
    required String recipeId,
    required String ownerId,
    required String suggesterId,
    required Map<String, dynamic> suggestion,
    required DateTime at,
  }) {
    final createdAt = at.toUtc();
    return RecipeSuggestion(
      id: '',
      recipeId: recipeId,
      ownerId: ownerId,
      suggesterId: suggesterId,
      suggestion: suggestion,
      status: RecipeSuggestionStatus.pending,
      createdAt: createdAt,
      expiresAt: createdAt.add(keptFor),
    );
  }

  /// Whether the suggestion may still be shown at [now].
  bool isKeptAt(DateTime now) => now.isBefore(expiresAt);

  bool get isPending => status == RecipeSuggestionStatus.pending;

  /// A copy carrying the document id the repository stored it under.
  RecipeSuggestion withId(String newId) => RecipeSuggestion(
    id: newId,
    recipeId: recipeId,
    ownerId: ownerId,
    suggesterId: suggesterId,
    suggestion: suggestion,
    status: status,
    createdAt: createdAt,
    expiresAt: expiresAt,
    decidedAt: decidedAt,
  );

  /// The stored shape of a new suggestion. The field set matches the create
  /// rule in firestore.rules (`match /recipe_suggestions/{suggestionId}`).
  Map<String, dynamic> toFirestore() => {
    'recipeId': recipeId,
    'ownerId': ownerId,
    'suggesterId': suggesterId,
    'suggestion': suggestion,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'expiresAt': Timestamp.fromDate(expiresAt),
  };

  /// Parses a stored row, or returns null when it is not one this app can
  /// show (a missing field or an unknown status). Such a row is never offered.
  static RecipeSuggestion? fromFirestore(String id, Map<String, dynamic> data) {
    final status = RecipeSuggestionStatus.values
        .where((s) => s.name == data['status'])
        .firstOrNull;
    final createdAt = _date(data['createdAt']);
    final expiresAt = _date(data['expiresAt']);
    final suggestion = data['suggestion'];
    final recipeId = data['recipeId'];
    final ownerId = data['ownerId'];
    final suggesterId = data['suggesterId'];
    if (status == null ||
        createdAt == null ||
        expiresAt == null ||
        suggestion is! Map ||
        recipeId is! String ||
        recipeId.isEmpty ||
        ownerId is! String ||
        ownerId.isEmpty ||
        suggesterId is! String ||
        suggesterId.isEmpty) {
      return null;
    }
    return RecipeSuggestion(
      id: id,
      recipeId: recipeId,
      ownerId: ownerId,
      suggesterId: suggesterId,
      suggestion: Map<String, dynamic>.from(suggestion),
      status: status,
      createdAt: createdAt,
      expiresAt: expiresAt,
      decidedAt: _date(data['decidedAt']),
    );
  }

  static DateTime? _date(Object? value) => switch (value) {
    final Timestamp t => t.toDate().toUtc(),
    final DateTime d => d.toUtc(),
    _ => null,
  };
}
