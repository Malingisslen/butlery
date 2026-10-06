import 'package:butlery/models/household.dart';
import 'package:butlery/repositories/interfaces/repository.dart';

/// Repository for the shared [Household] entity (top-level `households`
/// collection). A household is the symmetric identity that scopes diner
/// profiles and family ratings — both parents are members of the same doc.
abstract class HouseholdRepository extends Repository<Household> {
  /// All households [userId] is a member of. Since BUT-2267 a member of a
  /// group marked as household can be in that household AND their own, so
  /// read [getActiveForUser] for "the" household.
  Future<List<Household>> getForUser(String userId);

  /// The household [userId]'s menu, settings and family views use, picked by
  /// [Household.pickActive]; null when they are in none. Read-only.
  Future<Household?> getActiveForUser(String userId);

  /// [userId]'s active household, creating a fresh single-member one if they
  /// are in none. Used to resolve the household id that scopes diner profiles.
  Future<Household> ensureForUser(String userId);

  /// Joins the household of the group `users/{ownerId}/friend_categories/
  /// {groupId}`, which must be marked as household and list the caller
  /// (BUT-2267). Runs on the server; returns the household's id. Repeating it
  /// changes nothing.
  Future<String> joinGroupHousehold({
    required String ownerId,
    required String groupId,
  });

  /// Whether [userId] is a member of household [householdId]. Used by the
  /// diner-profile / family-rating repositories to gate access.
  Future<bool> isMember(String householdId, String userId);
}
