// lib/services/account/export/family_export_manager.dart

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/family_rating_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show sanitizeForJson;

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

  static const String _logTag = 'FamilyExportManager';

  FamilyExportManager({
    HouseholdRepository? householdRepository,
    DinerProfileRepository? dinerProfileRepository,
    FamilyRatingRepository? familyRatingRepository,
  }) : _householdRepo = householdRepository,
       _dinerRepo = dinerProfileRepository,
       _familyRatingRepo = familyRatingRepository;

  HouseholdRepository get _households =>
      _householdRepo ?? ServiceLocator.get<HouseholdRepository>();
  DinerProfileRepository get _diners =>
      _dinerRepo ?? ServiceLocator.get<DinerProfileRepository>();
  FamilyRatingRepository get _familyRatings =>
      _familyRatingRepo ?? ServiceLocator.get<FamilyRatingRepository>();

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
        'diner_profiles': [
          for (final d in diners) sanitizeForJson(d.toJson()),
        ],
        'family_ratings': [for (final r in mine) sanitizeForJson(r.toJson())],
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

  Map<String, dynamic> _empty(String? householdId) => {
    'household_id': householdId,
    'diner_profiles_count': 0,
    'family_ratings_count': 0,
    'diner_profiles': const [],
    'family_ratings': const [],
  };
}
