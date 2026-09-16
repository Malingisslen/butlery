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
  /// What survives a withdrawal is a `consent_revoked` row in `audit_logs`
  /// carrying the share's `consentVersion`, written by the Firebase
  /// implementation after the delete succeeds (DPIA R5). Its `resourceType`
  /// separates it from the account-level consent document's own row.
  Future<void> revoke(String householdId);
}
