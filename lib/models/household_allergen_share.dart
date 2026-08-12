import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/user_allergen_preferences.dart';

/// One household member's own allergen list, shared with their household by
/// explicit consent (BUT-1693, GDPR Art. 9(2)(a)).
///
/// A member's real preferences live in `users/{uid}/settings/preferences`,
/// which only that user may read. Without a share, menu generation cannot see
/// them and falls back to a guessed common-allergen floor (BUT-1663). This
/// document is the member's decision to be seen instead of guessed at.
///
/// **Absent is not empty.** No document means "has not shared" — the floor
/// applies. A document with empty lists means "I have no allergies", which is a
/// declaration and must NOT trigger the floor. That distinction is the whole
/// point of the collection, and the aggregate that will consume it
/// (`HouseholdService`) must decide per member from document EXISTENCE, never
/// from list contents.
class HouseholdAllergenShare {
  /// The household this share is readable inside — `households/{householdId}`,
  /// the symmetric roster, never the owner-scoped `FriendCategory` household.
  final String householdId;

  /// The member whose list this is. The only user allowed to write it.
  final String userId;

  final Set<String> trackedAllergens;

  /// Vegetarisk / vegansk. Shared in the same act as the allergens by Malin's
  /// explicit decision (ADR-0005): a tracked diet is a HARD requirement in menu
  /// generation, so sharing one narrows the whole household's menu, and the
  /// consent copy says so before the toggle is flipped.
  final Set<String> trackedDietary;

  /// The member's own caution about unverified recipes. The household
  /// aggregate AND-folds this, so a shared `false` can only tighten filtering.
  final bool includeUnknownInMenu;

  /// Art. 9(2)(a) explicit consent, and the version of the wording it was given
  /// under. Never inferred: a document without a true [consentGranted] is not a
  /// share, and [isValidConsent] is what every reader checks.
  final bool consentGranted;
  final String consentVersion;

  /// Nullable on purpose. A consent record with no readable timestamp is not a
  /// record, so [isValidConsent] refuses it — rather than the shared helper's
  /// habit of defaulting a missing date to "now", which would make a corrupted
  /// document look freshly consented.
  final DateTime? consentGrantedAt;

  /// Last time the member's own preferences were mirrored here.
  ///
  /// The rule this field exists to serve: it MUST move in the same atomic write
  /// as the member's own settings edit, because a share that lags behind is a
  /// household filtering on an allergen list its owner has already changed —
  /// on this field that is a safety defect, not an inconsistency (DPIA R4).
  /// **That seam is not built yet**: nothing writes this collection, and the
  /// repository has no method taking an externally-created `WriteBatch`. Do not
  /// read this doc comment as a description of existing behaviour.
  final DateTime? updatedAt;

  const HouseholdAllergenShare({
    required this.householdId,
    required this.userId,
    required this.trackedAllergens,
    required this.trackedDietary,
    required this.includeUnknownInMenu,
    required this.consentGranted,
    required this.consentVersion,
    required this.consentGrantedAt,
    required this.updatedAt,
  });

  /// The wording version the current consent copy carries. Bump when the text
  /// materially changes what the member is agreeing to; a share written under
  /// an older version stays valid until the controller decides otherwise.
  static const String currentConsentVersion = 'v1';

  /// Deterministic id, so a member can hold exactly one share per household and
  /// the rules can derive ownership from the path.
  static String documentId(String householdId, String userId) =>
      '${householdId}_$userId';

  String get id => documentId(householdId, userId);

  /// Whether this document may be used as a declaration at all. A share with
  /// `consentGranted: false` is treated exactly like no share — the floor.
  /// A declaration also has to say WHO and WHERE. `safeString` defaults to the
  /// empty string, so without this a document missing its `userId` would parse
  /// as a valid share belonging to nobody — and be attributed by whoever read
  /// it next.
  bool get isValidConsent =>
      consentGranted &&
      consentVersion.isNotEmpty &&
      consentGrantedAt != null &&
      householdId.isNotEmpty &&
      userId.isNotEmpty;

  /// The member's list in the shape the household aggregate consumes. Only the
  /// three fields that decide filtering; the display flags are personal and
  /// stay behind.
  UserAllergenPreferences toPreferences() => UserAllergenPreferences(
    trackedAllergens: trackedAllergens,
    trackedDietary: trackedDietary,
    includeUnknownInMenu: includeUnknownInMenu,
  );

  /// [id] is accepted for symmetry with the other models and deliberately NOT
  /// used: identity comes from the BODY, which is what lets the repository
  /// detect a forgery by comparing the derived [id] against the document's
  /// actual path. "Fixing" this to read the path instead would turn that check
  /// into a tautology and the forgery test into a vacuous one.
  factory HouseholdAllergenShare.fromMap(String id, Map<String, dynamic> data) {
    return HouseholdAllergenShare(
      householdId: SerializationUtils.safeString(data, 'householdId'),
      userId: SerializationUtils.safeString(data, 'userId'),
      // Parsed field by field rather than through
      // UserAllergenPreferences.fromFirestore, which returns the four-allergen
      // DEFAULTS for a null map — here that would turn a member who declared
      // no allergies into one who declared four.
      // Normalised the way every other allergen read normalises: a legacy
      // ASCII `mjolk` that stayed raw would match nothing downstream, so the
      // allergen would disappear instead of failing loud.
      trackedAllergens: SerializationUtils.safeStringList(
        data,
        'trackedAllergens',
      ).map(UserAllergenPreferences.normalizeAllergenKey).toSet(),
      trackedDietary: SerializationUtils.safeStringList(
        data,
        'trackedDietary',
      ).map(UserAllergenPreferences.normalizeAllergenKey).toSet(),
      // Fails SAFE: a missing flag means "exclude unverified recipes", the
      // cautious reading, matching the degraded household path.
      includeUnknownInMenu: SerializationUtils.safeBool(
        data,
        'includeUnknownInMenu',
        defaultValue: false,
      ),
      // Fails CLOSED: a missing flag is not consent.
      consentGranted: SerializationUtils.safeBool(
        data,
        'consentGranted',
        defaultValue: false,
      ),
      consentVersion: SerializationUtils.safeString(data, 'consentVersion'),
      consentGrantedAt: SerializationUtils.safeDateTime(
        data,
        'consentGrantedAt',
      ),
      updatedAt: SerializationUtils.safeDateTime(data, 'updatedAt'),
    );
  }

  /// Dates go out as Firestore `Timestamp`s, like every sibling in this
  /// household cluster (`DinerProfile`, `GuardianConsent`, `FamilyRating`) —
  /// an ISO string cannot be type-checked or bounded against `request.time` in
  /// firestore.rules, and the wire format stops being free to change the moment
  /// the first document is written. A null date is OMITTED rather than stored
  /// as null, so a rule can test presence.
  Map<String, dynamic> toFirestore() => {
    'householdId': householdId,
    'userId': userId,
    'trackedAllergens': trackedAllergens.toList(),
    'trackedDietary': trackedDietary.toList(),
    'includeUnknownInMenu': includeUnknownInMenu,
    'consentGranted': consentGranted,
    'consentVersion': consentVersion,
    if (consentGrantedAt != null)
      'consentGrantedAt': AppTimestamp.fromDateTime(
        consentGrantedAt!,
      ).toFirestore(),
    if (updatedAt != null)
      'updatedAt': AppTimestamp.fromDateTime(updatedAt!).toFirestore(),
  };

  /// The preference half is freely editable; the consent half is not, and is
  /// only ever replaced with a record read back from storage — see
  /// [withStoredConsent]. Identity ([householdId], [userId]) is never editable:
  /// re-pointing a share is a new share, not an edit.
  HouseholdAllergenShare copyWith({
    Set<String>? trackedAllergens,
    Set<String>? trackedDietary,
    bool? includeUnknownInMenu,
    DateTime? updatedAt,
  }) => HouseholdAllergenShare(
    householdId: householdId,
    userId: userId,
    trackedAllergens: trackedAllergens ?? this.trackedAllergens,
    trackedDietary: trackedDietary ?? this.trackedDietary,
    includeUnknownInMenu: includeUnknownInMenu ?? this.includeUnknownInMenu,
    consentGranted: consentGranted,
    consentVersion: consentVersion,
    consentGrantedAt: consentGrantedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// This share's preferences carrying [stored]'s consent record instead of its
  /// own. The repository uses it so an ordinary preference edit can never
  /// re-date the consent or move it to a different wording version — that
  /// record is the Art. 7(1) evidence, and only a fresh grant may write it.
  HouseholdAllergenShare withStoredConsent(HouseholdAllergenShare stored) =>
      HouseholdAllergenShare(
        householdId: householdId,
        userId: userId,
        trackedAllergens: trackedAllergens,
        trackedDietary: trackedDietary,
        includeUnknownInMenu: includeUnknownInMenu,
        consentGranted: stored.consentGranted,
        consentVersion: stored.consentVersion,
        consentGrantedAt: stored.consentGrantedAt,
        updatedAt: updatedAt,
      );
}
