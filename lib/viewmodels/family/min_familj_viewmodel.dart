import 'package:clock/clock.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// Drives the "Min familj" screen — the household's account holders plus the
/// non-account family members (children and guests represented as
/// [DinerProfile]s).
///
/// Owns the two-tier GDPR consent gating in one place: a minor profile requires
/// guardian consent (Art. 6), and storing allergen data requires *separate,
/// explicit* consent (Art. 9). Both gates are also enforced by the repository
/// and Firestore rules — this layer surfaces them as user-facing errors before
/// a doomed write.
class MinFamiljViewModel extends BaseViewModel {
  final HouseholdRepository _householdRepository;
  final DinerProfileRepository _dinerProfileRepository;
  final HouseholdRosterService _rosterService;
  final PermissionService _permissionService;

  MinFamiljViewModel({
    HouseholdRepository? householdRepository,
    DinerProfileRepository? dinerProfileRepository,
    HouseholdRosterService? rosterService,
    PermissionService? permissionService,
  }) : _householdRepository =
           householdRepository ?? ServiceLocator.get<HouseholdRepository>(),
       _dinerProfileRepository =
           dinerProfileRepository ??
           ServiceLocator.get<DinerProfileRepository>(),
       _rosterService =
           rosterService ?? ServiceLocator.get<HouseholdRosterService>(),
       _permissionService =
           permissionService ?? ServiceLocator.get<PermissionService>();

  Household? _household;
  List<HouseholdRosterMember> _roster = const [];
  List<DinerProfile> _familyMembers = const [];

  /// Account holders (real app users), for the "hushållet" section.
  List<HouseholdRosterMember> get accounts =>
      _roster.where((m) => m.isUser).toList();

  /// Non-account family members (children + guests), for the "familjen"
  /// section. Full [DinerProfile]s so the edit form has consent + allergens.
  List<DinerProfile> get familyMembers => _familyMembers;

  String? get householdId => _household?.id;

  /// Whether [userId] is an admin of the current household (drives the "admin"
  /// tag on an account row).
  bool isAdmin(String userId) => _household?.canAdmin(userId) ?? false;

  /// Resolve-or-create the household, then load its roster + diner profiles.
  Future<void> load() async {
    await executeAsyncVoid(() async {
      final uid = _permissionService.currentUserId;
      if (uid == null) {
        throw StateError('Ingen inloggad användare');
      }
      final household = await _householdRepository.ensureForUser(uid);
      _household = household;
      await _refresh(household.id);
    }, errorPrefix: 'Kunde inte ladda familjen');
  }

  Future<void> _refresh(String householdId) async {
    _roster = await _rosterService.getRoster(householdId);
    _familyMembers = await _dinerProfileRepository.getByHousehold(householdId);
  }

  /// Best-effort reload after a successful mutation. A reload failure must NOT
  /// flip the mutation's result to "failed" — the write already landed, so the
  /// user would otherwise see a spurious save error. The list is left stale (a
  /// later [load] corrects it) and the failure is logged.
  Future<void> _safeRefresh(String householdId) async {
    try {
      await _refresh(householdId);
    } catch (e) {
      AppLogger.warning('MinFamiljViewModel: post-write refresh failed: $e');
    }
  }

  /// Create a new family member, or update [existing] when editing. The
  /// submitted form state is authoritative; consent is (re)derived from it.
  ///
  /// Returns true on success. On a consent-gate violation or write failure the
  /// error is surfaced via [error] and the method returns false.
  Future<bool> saveFamilyMember({
    DinerProfile? existing,
    required String name,
    required DinerAgeBand ageBand,
    String? avatarColor,
    required bool guardianConsentGiven,
    required bool allergenConsentGiven,
    Set<String> allergenKeys = const {},
  }) async {
    return executeAsyncVoid(() async {
      final householdId = _household?.id;
      final uid = _permissionService.currentUserId;
      if (householdId == null || uid == null) {
        throw StateError('Ingen aktiv hushållssession');
      }

      final trimmed = name.trim();
      if (trimmed.isEmpty) {
        throw ArgumentError('Namn krävs');
      }

      final hasAllergens = allergenKeys.isNotEmpty;

      // Consent gates — mirror the repository + rules, surfaced early.
      if (ageBand.isMinor && !guardianConsentGiven) {
        throw StateError('Vårdnadshavarens samtycke krävs för en minderårig.');
      }
      if (hasAllergens && !allergenConsentGiven) {
        throw StateError(
          'Allergiuppgifter kräver uttryckligt samtycke (hälsouppgifter).',
        );
      }

      final consent = _buildConsent(
        existing: existing,
        uid: uid,
        needsBaseConsent: ageBand.isMinor || hasAllergens,
        includesAllergens: hasAllergens,
      );

      final prefs = hasAllergens
          ? UserAllergenPreferences(
              trackedAllergens: allergenKeys.toSet(),
              trackedDietary: const {},
            )
          : null;

      if (existing == null) {
        await _dinerProfileRepository.create(
          DinerProfile.create(
            householdId: householdId,
            name: trimmed,
            ageBand: ageBand,
            createdBy: uid,
            avatarColor: avatarColor,
            allergenPreferences: prefs,
            guardianConsent: consent,
          ),
        );
      } else {
        await _dinerProfileRepository.update(
          existing.copyWith(
            name: trimmed,
            ageBand: ageBand,
            avatarColor: avatarColor,
            allergenPreferences: prefs,
            guardianConsent: consent,
          ),
        );
      }

      await _safeRefresh(householdId);
    }, errorPrefix: 'Kunde inte spara familjemedlemmen');
  }

  /// One-tap allergen-consent withdrawal: erase the diner's allergen data and
  /// clear the allergen flag, keeping the base profile consent intact. As easy
  /// to withdraw as to give (spec §8 condition 2).
  Future<bool> withdrawAllergenConsent(DinerProfile profile) async {
    return executeAsyncVoid(() async {
      final householdId = _household?.id;
      if (householdId == null) {
        throw StateError('Ingen aktiv hushållssession');
      }
      await _dinerProfileRepository.update(
        profile.copyWith(
          allergenPreferences: null,
          guardianConsent: profile.guardianConsent?.copyWith(
            includesAllergenConsent: false,
          ),
        ),
      );
      await _safeRefresh(householdId);
    }, errorPrefix: 'Kunde inte återkalla samtycket');
  }

  /// Permanently remove a family member (and, via the cascade, their ratings).
  Future<bool> deleteFamilyMember(String dinerProfileId) async {
    return executeAsyncVoid(() async {
      final householdId = _household?.id;
      if (householdId == null) {
        throw StateError('Ingen aktiv hushållssession');
      }
      await _dinerProfileRepository.delete(dinerProfileId);
      await _safeRefresh(householdId);
    }, errorPrefix: 'Kunde inte ta bort familjemedlemmen');
  }

  /// Build the consent record for a save.
  ///
  /// Attribution integrity: a *fresh* consent (no prior) or an *upgrade*
  /// (allergen consent newly granted) must credit the current session's user
  /// and stamp now — otherwise a second household admin adding allergens would
  /// be wrongly recorded as consent given by the original consenter. An edit
  /// that doesn't widen consent scope preserves the original attester + date.
  GuardianConsent? _buildConsent({
    required DinerProfile? existing,
    required String uid,
    required bool needsBaseConsent,
    required bool includesAllergens,
  }) {
    if (!needsBaseConsent) return null;
    final prior = existing?.guardianConsent;
    final isFreshOrUpgrade =
        prior == null || (includesAllergens && !prior.includesAllergenConsent);
    return GuardianConsent(
      byUid: isFreshOrUpgrade ? uid : prior.byUid,
      at: isFreshOrUpgrade ? clock.now() : prior.at,
      consentVersion: DinerProfile.currentConsentVersion,
      includesAllergenConsent: includesAllergens,
    );
  }
}
