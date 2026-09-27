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
/// recipe the owner has shared with them), only the owner decide it, and only
/// the suggester replace a pending one with a newer edit (Q6-12 = B). It is
/// never edited otherwise and never deleted by a client: the Firestore TTL
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
    this.replacedAt,
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

  /// Q6-12 = B (produktbeslut 2026-09-27b): when the suggester last replaced
  /// this pending suggestion with a newer edit of the recipe. Null for one
  /// never replaced. The owner is told it was updated from this.
  final DateTime? replacedAt;

  /// Whether the suggester replaced it with a newer edit (Q6-12 = B).
  bool get wasReplaced => replacedAt != null;

  /// When its content was made: the latest replacement, else its creation.
  /// Lists are ordered by this, newest first.
  DateTime get madeAt => replacedAt ?? createdAt;

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

  /// Q6-07 = B (produktbeslut 2026-09-27): a member has at most one pending
  /// suggestion per recipe. The one among [rows] (one member's suggestions
  /// to one recipe) that still waits for the owner at [now], or null.
  static RecipeSuggestion? waitingAmong(
    Iterable<RecipeSuggestion> rows,
    DateTime now,
  ) {
    for (final s in rows) {
      if (s.isPending && s.isKeptAt(now)) return s;
    }
    return null;
  }

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
    replacedAt: replacedAt,
  );

  /// Q6-12 = B: this pending suggestion with [newSuggestion] in place of its
  /// content, replaced at [at]. Same document id, recipe, owner and
  /// suggester; kept [keptFor] from [at], since it is a new suggestion
  /// (produktregler.md:103, "ja, 7 dagar").
  RecipeSuggestion replacedWith(
    Map<String, dynamic> newSuggestion, {
    required DateTime at,
  }) {
    final replaced = at.toUtc();
    return RecipeSuggestion(
      id: id,
      recipeId: recipeId,
      ownerId: ownerId,
      suggesterId: suggesterId,
      suggestion: newSuggestion,
      status: status,
      createdAt: createdAt,
      expiresAt: replaced.add(keptFor),
      decidedAt: decidedAt,
      replacedAt: replaced,
    );
  }

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

  /// The fields a replacement changes (Q6-12 = B). The set matches the
  /// suggester's update rule in firestore.rules
  /// (`match /recipe_suggestions/{suggestionId}`). Only for a copy made by
  /// [replacedWith].
  Map<String, dynamic> toReplacementFirestore() => {
    'suggestion': suggestion,
    'replacedAt': Timestamp.fromDate(replacedAt!),
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
      replacedAt: _date(data['replacedAt']),
    );
  }

  static DateTime? _date(Object? value) => switch (value) {
    final Timestamp t => t.toDate().toUtc(),
    final DateTime d => d.toUtc(),
    _ => null,
  };
}
