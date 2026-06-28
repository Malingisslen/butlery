import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/repositories/interfaces/repository.dart';

/// Repository for [DinerProfile]s — non-account household members (kids, guests)
/// stored in the top-level `diner_profiles` collection, scoped to a household.
///
/// Access is gated by household membership. Persistence additionally enforces
/// the GDPR consent invariants (a minor needs guardian consent; allergen data
/// needs explicit allergen consent) at the data boundary — see the impl.
abstract class DinerProfileRepository extends Repository<DinerProfile> {
  /// All diner profiles belonging to [householdId]. Returns empty if the caller
  /// is not a member of that household.
  Future<List<DinerProfile>> getByHousehold(String householdId);
}
