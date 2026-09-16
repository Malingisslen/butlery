// lib/services/account/export/family_export_manager.dart

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/family_rating_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show
        ExportPaginationHelper,
        normalizeTimestampPaths,
        projectExportFields,
        sanitizeForJson;

/// Exports the household family-rating data for GDPR Article 15/20 (BUT family
/// Phase 5 item 14): the non-account diner profiles the user manages, plus the
/// family verdicts that concern the user.
///
/// Scoping note: diner profiles are household-shared data the user co-controls
/// (children/guests), so all of the household's profiles are included. Family
/// ratings are scoped to THIS user — verdicts that are theirs (`memberId`) or
/// that they physically entered (`enteredByUid`) — so a user's export never
/// leaks another household member's private verdict.
///
/// DPIA note: this export legitimately carries a child's special-category
/// (Art. 9 allergen) data and the guardian-consent record (incl. guardian UID)
/// into a co-controlling adult's self-service export. That third-party-special-
/// category disclosure is a documented condition the family-rating DPIA must
/// cover — not a new consent flow (it only exposes already-consented stored
/// data).
class FamilyExportManager {
  // Test seams: production resolves via ServiceLocator on first use.
  final HouseholdRepository? _householdRepo;
  final DinerProfileRepository? _dinerRepo;
  final FamilyRatingRepository? _familyRatingRepo;
  final FirebaseDataExportRepository? _exportRepo;

  static const String _logTag = 'FamilyExportManager';

  FamilyExportManager({
    HouseholdRepository? householdRepository,
    DinerProfileRepository? dinerProfileRepository,
    FamilyRatingRepository? familyRatingRepository,
    FirebaseDataExportRepository? dataExportRepository,
  }) : _householdRepo = householdRepository,
       _dinerRepo = dinerProfileRepository,
       _familyRatingRepo = familyRatingRepository,
       _exportRepo = dataExportRepository;

  HouseholdRepository get _households =>
      _householdRepo ?? ServiceLocator.get<HouseholdRepository>();
  DinerProfileRepository get _diners =>
      _dinerRepo ?? ServiceLocator.get<DinerProfileRepository>();
  FamilyRatingRepository get _familyRatings =>
      _familyRatingRepo ?? ServiceLocator.get<FamilyRatingRepository>();
  FirebaseDataExportRepository get _exports =>
      _exportRepo ?? ServiceLocator.get<FirebaseDataExportRepository>();

  /// The fields of a share this section carries. An allowlist, so a field
  /// nobody has decided about is withheld rather than exported. `userId` is
  /// left out: it is the requester's own uid and the query's filter.
  static const householdAllergenShareFields = <String>[
    'householdId',
    'trackedAllergens',
    'trackedDietary',
    'includeUnknownInMenu',
    'consentGranted',
    'consentVersion',
    'consentGrantedAt',
    'updatedAt',
  ];

  /// BUT-1693: the user's OWN shared allergen lists, under every household
  /// id (DPIA §9 decision 5). Other members' shares are never read here.
  Future<Map<String, dynamic>> exportHouseholdAllergenShares(
    String userId,
  ) async {
    try {
      final entries = await ExportPaginationHelper.fetchCapped(
        type: 'household_allergen_shares',
        fetch: (max) =>
            _exports.exportHouseholdAllergenShares(userId, maxDocuments: max),
      );
      return {
        'total_count': entries.items.length,
        'household_allergen_shares': entries.items
            .map(
              (entry) => {
                'share_id': entry['id'],
                'data': sanitizeForJson(
                  projectExportFields(
                    entry['data'],
                    householdAllergenShareFields,
                  ),
                ),
              },
            )
            .toList(),
        if (entries.truncated) 'truncated': true,
        'data_minimisation':
            'Only allergen lists you shared yourself are included, not those '
            'other household members shared. This section carries only the '
            'fields it recognises, so a field added later may be missing.',
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export household allergen shares',
        e,
      );
      return {
        'error': 'Shared allergen lists could not be exported.',
        'error_code': 'household-allergen-shares-export-failed',
      };
    }
  }

  Future<Map<String, dynamic>> exportFamily(String userId) async {
    try {
      // READ-ONLY: never `ensureForUser` here — an Article 15 access request
      // must not create a household as a side effect. No household → empty
      // section. getForUser is caller-scoped, so passing another uid yields
      // nothing rather than leaking that user's household.
      final households = await _households.getForUser(userId);
      if (households.isEmpty) {
        return _empty(null);
      }
      final householdId = households.first.id;

      final diners = await _diners.getByHousehold(householdId);

      // Only the caller's own / caller-entered verdicts — never another
      // member's private rating.
      final all = await _familyRatings.getForHousehold(householdId);
      final mine = all
          .where((r) => r.memberId == userId || r.enteredByUid == userId)
          .toList();

      return {
        'household_id': householdId,
        'diner_profiles_count': diners.length,
        'family_ratings_count': mine.length,
        // Both sections serialise MODELS, not raw documents, and `toJson()`
        // emits `toIso8601String()` on a `DateTime` that
        // `SerializationUtils.parseDateTimeValue` built from
        // `Timestamp.toDate()` — which is LOCAL, so the string carries neither
        // `Z` nor an offset and passes through `sanitizeForJson` as a plain
        // primitive. Normalised at this boundary rather than in the models:
        // `toJson()` is also the local-cache and Firestore write format, so
        // changing it there would be a migration.
        'diner_profiles': [
          for (final d in diners)
            _utcStamps(d.toJson(), const [
              'createdAt',
              'updatedAt',
              'guardianConsent.at',
            ]),
        ],
        'family_ratings': [
          for (final r in mine)
            _utcStamps(r.toJson(), const ['createdAt', 'lastUpdatedAt']),
        ],
      };
    } catch (e) {
      // Log the full error, but return a generic stable token + error_code so
      // a raw Firestore/permission string (which can carry uids / doc paths)
      // never lands in the GDPR export artifact. error_code joins the bundle's
      // top-level warnings roll-up (BUT-864).
      app_logger.AppLogger.error('[$_logTag] Failed to export family data', e);
      return {
        'error': 'Family data could not be exported.',
        'error_code': 'family-export-failed',
      };
    }
  }

  Map<String, dynamic> _utcStamps(
    Map<String, dynamic> json,
    List<String> paths,
  ) {
    final row = sanitizeForJson(json) as Map<String, dynamic>;
    normalizeTimestampPaths(row, paths);
    return row;
  }

  Map<String, dynamic> _empty(String? householdId) => {
    'household_id': householdId,
    'diner_profiles_count': 0,
    'family_ratings_count': 0,
    'diner_profiles': const [],
    'family_ratings': const [],
  };
}
