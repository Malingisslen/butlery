import 'package:clock/clock.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:uuid/uuid.dart';

/// Coarse age band for a household diner who does not hold an app account.
///
/// Deliberately coarse (no birthdate) for data minimisation — see the
/// family-rating spec §8. [adult] represents a non-account adult guest;
/// the minor bands ([toddler], [child], [teen]) require [GuardianConsent].
enum DinerAgeBand {
  toddler,
  child,
  teen,
  adult
  ;

  /// Whether this band represents a minor (guardian consent required to
  /// store the profile, per ADR-0001 / GDPR Art. 8).
  bool get isMinor => this != DinerAgeBand.adult;

  static DinerAgeBand fromName(String? value) => DinerAgeBand.values.firstWhere(
    (b) => b.name == value,
    orElse: () => DinerAgeBand.child,
  );
}

/// Lawful-basis record for storing a non-account household member's data.
///
/// Captures the guardian's attestation, when it was given, and the version
/// of the consent text shown (so a policy change can be detected and
/// re-consent requested). [includesAllergenConsent] records the *separate*,
/// explicit Art. 9(2)(a) consent for storing the diner's allergen/dietary
/// data — it is unbundled from base profile consent (spec §8 condition 2):
/// a profile may exist with consent but no allergen data.
class GuardianConsent {
  final String byUid;
  final DateTime at;
  final String consentVersion;
  final bool includesAllergenConsent;

  const GuardianConsent({
    required this.byUid,
    required this.at,
    required this.consentVersion,
    this.includesAllergenConsent = false,
  });

  GuardianConsent copyWith({
    String? byUid,
    DateTime? at,
    String? consentVersion,
    bool? includesAllergenConsent,
  }) {
    return GuardianConsent(
      byUid: byUid ?? this.byUid,
      at: at ?? this.at,
      consentVersion: consentVersion ?? this.consentVersion,
      includesAllergenConsent:
          includesAllergenConsent ?? this.includesAllergenConsent,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'byUid': byUid,
    'at': AppTimestamp.fromDateTime(at).toFirestore(),
    'consentVersion': consentVersion,
    'includesAllergenConsent': includesAllergenConsent,
  };

  factory GuardianConsent.fromMap(Map<String, dynamic> data) => GuardianConsent(
    byUid: SerializationUtils.safeString(data, 'byUid'),
    at: SerializationUtils.parseRequiredDateTimeValue(data['at']),
    consentVersion: SerializationUtils.safeString(data, 'consentVersion'),
    includesAllergenConsent: SerializationUtils.safeBool(
      data,
      'includesAllergenConsent',
    ),
  );

  Map<String, dynamic> toJson() => {
    'byUid': byUid,
    'at': at.toIso8601String(),
    'consentVersion': consentVersion,
    'includesAllergenConsent': includesAllergenConsent,
  };

  factory GuardianConsent.fromJson(Map<String, dynamic> json) =>
      GuardianConsent(
        byUid: SerializationUtils.safeString(json, 'byUid'),
        at: SerializationUtils.safeDateTime(json, 'at') ?? clock.now(),
        consentVersion: SerializationUtils.safeString(json, 'consentVersion'),
        includesAllergenConsent: SerializationUtils.safeBool(
          json,
          'includesAllergenConsent',
        ),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GuardianConsent &&
          byUid == other.byUid &&
          at == other.at &&
          consentVersion == other.consentVersion &&
          includesAllergenConsent == other.includesAllergenConsent;

  @override
  int get hashCode =>
      Object.hash(byUid, at, consentVersion, includesAllergenConsent);
}

/// A household member who eats at the table but does NOT hold an app account
/// — primarily children under the account age (ADR-0001 floor 15), but also
/// adult guests. Shared across the household so every household member sees
/// and edits the same profile, and family ratings merge.
///
/// Storage is household-scoped (see `DinerProfileRepository`) and isolated by
/// security rules to current household members only. Allergen data, when
/// present, is special-category (GDPR Art. 9) and is only stored when
/// [guardianConsent.includesAllergenConsent] is true.
class DinerProfile {
  /// Current consent-text version. Bump when the consent wording changes so
  /// existing consents can be detected as stale and re-requested.
  static const String currentConsentVersion = 'v1';

  final String id;
  final String householdId;

  /// Display name or nickname. Minimise: a nickname/initial is preferred over
  /// a full legal name (spec §8).
  final String name;

  final DinerAgeBand ageBand;

  /// Hex colour for the avatar chip (e.g. '#B5532A'). UI-only.
  final String? avatarColor;

  /// Allergen/dietary data. Null/empty unless allergen consent was given
  /// (see [GuardianConsent.includesAllergenConsent]).
  final UserAllergenPreferences? allergenPreferences;

  /// Lawful-basis record. Required for minor age bands before the profile may
  /// be persisted; the repository enforces this.
  final GuardianConsent? guardianConsent;

  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  DinerProfile({
    required this.id,
    required this.householdId,
    required this.name,
    required this.ageBand,
    this.avatarColor,
    this.allergenPreferences,
    this.guardianConsent,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.schemaVersion = 1,
  }) : createdAt = createdAt ?? clock.now(),
       updatedAt = updatedAt ?? clock.now();

  factory DinerProfile.create({
    required String householdId,
    required String name,
    required DinerAgeBand ageBand,
    required String createdBy,
    String? avatarColor,
    UserAllergenPreferences? allergenPreferences,
    GuardianConsent? guardianConsent,
  }) {
    return DinerProfile(
      id: const Uuid().v4(),
      householdId: householdId,
      name: name,
      ageBand: ageBand,
      avatarColor: avatarColor,
      allergenPreferences: allergenPreferences,
      guardianConsent: guardianConsent,
      createdBy: createdBy,
    );
  }

  /// Whether this profile represents a minor (guardian consent required).
  bool get isMinor => ageBand.isMinor;

  /// Whether allergen data may be stored — true only when explicit allergen
  /// consent is on record (spec §8 condition 2, unbundled consent).
  bool get hasAllergenConsent =>
      guardianConsent?.includesAllergenConsent ?? false;

  /// Sentinel distinguishing "argument omitted" from "explicitly set to null"
  /// for the nullable fields below — required so the consent-revocation flow
  /// can CLEAR [allergenPreferences]/[guardianConsent], not just overwrite them.
  static const Object _unset = Object();

  DinerProfile copyWith({
    String? householdId,
    String? name,
    DinerAgeBand? ageBand,
    Object? avatarColor = _unset,
    Object? allergenPreferences = _unset,
    Object? guardianConsent = _unset,
    String? createdBy,
    DateTime? updatedAt,
  }) {
    return DinerProfile(
      id: id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      ageBand: ageBand ?? this.ageBand,
      avatarColor: identical(avatarColor, _unset)
          ? this.avatarColor
          : avatarColor as String?,
      allergenPreferences: identical(allergenPreferences, _unset)
          ? this.allergenPreferences
          : allergenPreferences as UserAllergenPreferences?,
      guardianConsent: identical(guardianConsent, _unset)
          ? this.guardianConsent
          : guardianConsent as GuardianConsent?,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? clock.now(),
      schemaVersion: schemaVersion,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'householdId': householdId,
    'name': name,
    'ageBand': ageBand.name,
    if (avatarColor != null) 'avatarColor': avatarColor,
    if (allergenPreferences != null)
      'allergenPreferences': allergenPreferences!.toFirestore(),
    if (guardianConsent != null)
      'guardianConsent': guardianConsent!.toFirestore(),
    'createdBy': createdBy,
    'createdAt': AppTimestamp.fromDateTime(createdAt).toFirestore(),
    'updatedAt': AppTimestamp.fromDateTime(updatedAt).toFirestore(),
    'schemaVersion': schemaVersion,
  };

  factory DinerProfile.fromMap(String id, Map<String, dynamic> data) {
    final consent = data['guardianConsent'];
    final allergens = data['allergenPreferences'];
    return DinerProfile(
      id: id,
      householdId: SerializationUtils.safeString(data, 'householdId'),
      name: SerializationUtils.safeString(data, 'name'),
      ageBand: DinerAgeBand.fromName(
        SerializationUtils.safeNullableString(data, 'ageBand'),
      ),
      avatarColor: SerializationUtils.safeNullableString(data, 'avatarColor'),
      allergenPreferences: allergens is Map<String, dynamic>
          ? UserAllergenPreferences.fromFirestore(allergens)
          : null,
      guardianConsent: consent is Map<String, dynamic>
          ? GuardianConsent.fromMap(consent)
          : null,
      createdBy: SerializationUtils.safeString(data, 'createdBy'),
      createdAt: SerializationUtils.parseRequiredDateTimeValue(
        data['createdAt'],
      ),
      updatedAt: SerializationUtils.parseRequiredDateTimeValue(
        data['updatedAt'],
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
    'householdId': householdId,
    'name': name,
    'ageBand': ageBand.name,
    'avatarColor': avatarColor,
    // UserAllergenPreferences has no toJson(); toFirestore() output is plain
    // JSON-safe primitives, so the two paths are currently equivalent.
    'allergenPreferences': allergenPreferences?.toFirestore(),
    'guardianConsent': guardianConsent?.toJson(),
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'schemaVersion': schemaVersion,
  };

  factory DinerProfile.fromJson(Map<String, dynamic> json) {
    final consent = json['guardianConsent'];
    final allergens = json['allergenPreferences'];
    return DinerProfile(
      id: SerializationUtils.safeString(json, 'id'),
      householdId: SerializationUtils.safeString(json, 'householdId'),
      name: SerializationUtils.safeString(json, 'name'),
      ageBand: DinerAgeBand.fromName(
        SerializationUtils.safeNullableString(json, 'ageBand'),
      ),
      avatarColor: SerializationUtils.safeNullableString(json, 'avatarColor'),
      allergenPreferences: allergens is Map<String, dynamic>
          ? UserAllergenPreferences.fromFirestore(allergens)
          : null,
      guardianConsent: consent is Map<String, dynamic>
          ? GuardianConsent.fromJson(consent)
          : null,
      createdBy: SerializationUtils.safeString(json, 'createdBy'),
      createdAt:
          SerializationUtils.safeDateTime(json, 'createdAt') ?? clock.now(),
      updatedAt:
          SerializationUtils.safeDateTime(json, 'updatedAt') ?? clock.now(),
      schemaVersion: SerializationUtils.safeInt(
        json,
        'schemaVersion',
        defaultValue: 1,
      ),
    );
  }

  @override
  String toString() =>
      'DinerProfile(id: $id, name: $name, ageBand: ${ageBand.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DinerProfile && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
