import 'package:butlery/models/household_allergen_share.dart';
import 'package:butlery/repositories/interfaces/repository.dart';

/// Repository for [HouseholdAllergenShare] — a member's own allergen list,
/// shared with their household by explicit consent (BUT-1693, GDPR Art. 9).
///
/// Reads are gated by household membership; writes are gated by ownership on
/// top of it, because a share is a statement about oneself. Firestore rules are
/// the authoritative layer — see the impl.
abstract class HouseholdAllergenShareRepository
    extends Repository<HouseholdAllergenShare> {
  /// Every share readable inside [householdId], in one query rather than one
  /// read per member. Returns empty when the caller is not a member.
  ///
  /// Only shares whose consent is intact are returned: a document without a
  /// valid consent record is not a declaration, and its member must keep the
  /// safety floor.
  Future<List<HouseholdAllergenShare>> getByHousehold(String householdId);

  /// The caller's own share in [householdId], or null when they have not
  /// shared. Null is the answer that keeps the floor on.
  Future<HouseholdAllergenShare?> getOwn(String householdId);

  /// Withdraws the consent: deletes the document. The list itself must not
  /// survive the consent.
  ///
  /// What survives a withdrawal today is the PERMISSION-CHECK row in
  /// `audit_logs` (actor, resource, operation, timestamp, granted). That is not
  /// yet a consent record: it carries no `consentVersion`, and its operation
  /// spelling puts it in the 180-day general retention bucket rather than the
  /// 730-day `consent_*` one. DPIA R5 expects a real `consent_granted` /
  /// `consent_withdrawn` pair; the writer ticket lands it with the consent UI.
  /// Do not describe the Art. 7(1) trail as complete until it does.
  Future<void> revoke(String householdId);
}
