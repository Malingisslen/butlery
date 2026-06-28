import 'package:clock/clock.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// Whether a family-rating belongs to a real app user or a non-account
/// [DinerProfile]. Drives how the rating is attributed and how it relates to
/// the rater's private personal rating.
enum HouseholdMemberType {
  user,
  profile
  ;

  static HouseholdMemberType fromName(String? value) =>
      HouseholdMemberType.values.firstWhere(
        (t) => t.name == value,
        orElse: () => HouseholdMemberType.profile,
      );
}

/// One household member's private star verdict on a recipe the household
/// cooked. Distinct from the public social rating (`recipe_ratings`) and from
/// a user's own personal `RecipeCore.rating`.
///
/// Latest-verdict-wins: there is exactly one [FamilyRating] per
/// (recipeId, memberId), so re-rating overwrites. Use [buildId] for the
/// deterministic document id that enforces this.
///
/// [enteredByUid] records who physically entered the stars (the logged-in
/// session). For an adult who self-rated on their own device this equals
/// [memberId]; for a proxy entry at a shared phone it differs — the UI surfaces
/// "inmatat av {name}" and the rater's private personal rating is never touched
/// (spec §6, adult hybrid).
class FamilyRating {
  final String id;
  final String recipeId;
  final String householdId;
  final String memberId;
  final HouseholdMemberType memberType;

  /// Star verdict, 1–5.
  final int stars;

  final String enteredByUid;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final int schemaVersion;

  FamilyRating({
    required this.id,
    required this.recipeId,
    required this.householdId,
    required this.memberId,
    required this.memberType,
    required this.stars,
    required this.enteredByUid,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    this.schemaVersion = 1,
  }) : createdAt = createdAt ?? clock.now(),
       lastUpdatedAt = lastUpdatedAt ?? clock.now();

  /// Deterministic document id for the single rating per (recipe, member).
  /// Uses '|' (never present in a UUID or a Firebase UID, and a valid Firestore
  /// id char) so `buildId('a|b','c')` can never collide with `buildId('a','b|c')`.
  static String buildId(String recipeId, String memberId) =>
      '$recipeId|$memberId';

  factory FamilyRating.create({
    required String recipeId,
    required String householdId,
    required String memberId,
    required HouseholdMemberType memberType,
    required int stars,
    required String enteredByUid,
  }) {
    return FamilyRating(
      id: buildId(recipeId, memberId),
      recipeId: recipeId,
      householdId: householdId,
      memberId: memberId,
      memberType: memberType,
      stars: stars,
      enteredByUid: enteredByUid,
    );
  }

  /// Whether the stars value is within the valid 1–5 range.
  bool get hasValidStars => stars >= 1 && stars <= 5;

  /// Whether this rating was entered by someone other than the member it
  /// belongs to (a proxy entry at a shared phone).
  bool get isProxyEntry =>
      memberType == HouseholdMemberType.user && enteredByUid != memberId;

  FamilyRating copyWith({
    int? stars,
    String? enteredByUid,
    DateTime? lastUpdatedAt,
  }) {
    return FamilyRating(
      id: id,
      recipeId: recipeId,
      householdId: householdId,
      memberId: memberId,
      memberType: memberType,
      stars: stars ?? this.stars,
      enteredByUid: enteredByUid ?? this.enteredByUid,
      createdAt: createdAt,
      lastUpdatedAt: lastUpdatedAt ?? clock.now(),
      schemaVersion: schemaVersion,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'recipeId': recipeId,
    'householdId': householdId,
    'memberId': memberId,
    'memberType': memberType.name,
    'stars': stars,
    'enteredByUid': enteredByUid,
    'createdAt': AppTimestamp.fromDateTime(createdAt).toFirestore(),
    'lastUpdatedAt': AppTimestamp.fromDateTime(lastUpdatedAt).toFirestore(),
    'schemaVersion': schemaVersion,
  };

  factory FamilyRating.fromMap(String id, Map<String, dynamic> data) {
    return FamilyRating(
      id: id,
      recipeId: SerializationUtils.safeString(data, 'recipeId'),
      householdId: SerializationUtils.safeString(data, 'householdId'),
      memberId: SerializationUtils.safeString(data, 'memberId'),
      memberType: HouseholdMemberType.fromName(
        SerializationUtils.safeNullableString(data, 'memberType'),
      ),
      stars: SerializationUtils.safeInt(data, 'stars'),
      enteredByUid: SerializationUtils.safeString(data, 'enteredByUid'),
      createdAt: SerializationUtils.parseRequiredDateTimeValue(
        data['createdAt'],
      ),
      lastUpdatedAt: SerializationUtils.parseRequiredDateTimeValue(
        data['lastUpdatedAt'],
      ),
      schemaVersion: SerializationUtils.safeInt(
        data,
        'schemaVersion',
        defaultValue: 1,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'recipeId': recipeId,
    'householdId': householdId,
    'memberId': memberId,
    'memberType': memberType.name,
    'stars': stars,
    'enteredByUid': enteredByUid,
    'createdAt': createdAt.toIso8601String(),
    'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
    'schemaVersion': schemaVersion,
  };

  factory FamilyRating.fromJson(Map<String, dynamic> json) {
    return FamilyRating(
      id: SerializationUtils.safeString(json, 'id'),
      recipeId: SerializationUtils.safeString(json, 'recipeId'),
      householdId: SerializationUtils.safeString(json, 'householdId'),
      memberId: SerializationUtils.safeString(json, 'memberId'),
      memberType: HouseholdMemberType.fromName(
        SerializationUtils.safeNullableString(json, 'memberType'),
      ),
      stars: SerializationUtils.safeInt(json, 'stars'),
      enteredByUid: SerializationUtils.safeString(json, 'enteredByUid'),
      createdAt:
          SerializationUtils.safeDateTime(json, 'createdAt') ?? clock.now(),
      lastUpdatedAt:
          SerializationUtils.safeDateTime(json, 'lastUpdatedAt') ?? clock.now(),
      schemaVersion: SerializationUtils.safeInt(
        json,
        'schemaVersion',
        defaultValue: 1,
      ),
    );
  }

  @override
  String toString() =>
      'FamilyRating(recipeId: $recipeId, memberId: $memberId, stars: $stars)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FamilyRating && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Aggregate of a household's family ratings for one recipe — the value the
/// recipe-card "familj" pill renders. Computed from all [FamilyRating]s for a
/// recipe (simple mean, every diner weighted equally — spec §3).
class FamilyRatingSummary {
  final String recipeId;
  final double familyAverage;
  final int familyRatingCount;

  const FamilyRatingSummary({
    required this.recipeId,
    required this.familyAverage,
    required this.familyRatingCount,
  });

  /// Build a summary from a recipe's family ratings (simple unweighted mean).
  factory FamilyRatingSummary.fromRatings(
    String recipeId,
    List<FamilyRating> ratings,
  ) {
    final valid = ratings.where((r) => r.hasValidStars).toList();
    if (valid.isEmpty) {
      return FamilyRatingSummary(
        recipeId: recipeId,
        familyAverage: 0,
        familyRatingCount: 0,
      );
    }
    final sum = valid.fold<int>(0, (acc, r) => acc + r.stars);
    return FamilyRatingSummary(
      recipeId: recipeId,
      familyAverage: sum / valid.length,
      familyRatingCount: valid.length,
    );
  }

  bool get hasRatings => familyRatingCount > 0;

  /// Display-friendly average using Swedish decimal comma (e.g. "4,2").
  /// toStringAsFixed always emits '.' regardless of locale, so the replace is safe.
  String get displayAverage =>
      familyAverage.toStringAsFixed(1).replaceAll('.', ',');
}
