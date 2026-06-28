import 'package:butlery/models/household.dart';
import 'package:butlery/repositories/interfaces/repository.dart';

/// Repository for the shared [Household] entity (top-level `households`
/// collection). A household is the symmetric identity that scopes diner
/// profiles and family ratings — both parents are members of the same doc.
abstract class HouseholdRepository extends Repository<Household> {
  /// All households [userId] is a member of (normally 0 or 1).
  Future<List<Household>> getForUser(String userId);

  /// [userId]'s primary household, creating a fresh single-member one if none
  /// exists. Used to resolve the household id that scopes diner profiles.
  Future<Household> ensureForUser(String userId);

  /// Whether [userId] is a member of household [householdId]. Used by the
  /// diner-profile / family-rating repositories to gate access.
  Future<bool> isMember(String householdId, String userId);
}
