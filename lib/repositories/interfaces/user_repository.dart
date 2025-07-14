import 'repository.dart';
import '../../models/user_profile.dart';

abstract class UserRepository extends Repository<UserProfile> {
  /// Search for profiles matching a query
  Future<List<UserProfile>> searchProfiles(String query);

  /// Check if a display name is available
  Future<bool> isDisplayNameAvailable(String displayName);
}
