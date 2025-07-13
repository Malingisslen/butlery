import '../interfaces/user_repository.dart';
import '../../models/user_profile.dart';
import 'in_memory_repository.dart';

/// In-memory implementation of [UserRepository] for tests.
class MockUserRepository extends InMemoryRepository<UserProfile>
    implements UserRepository {
  MockUserRepository() : super((p) => p.uid);

  @override
  Future<List<UserProfile>> searchProfiles(String query) async {
    return items.values
        .where((p) => p.matchesSearchTerm(query))
        .toList();
  }

  @override
  Future<bool> isDisplayNameAvailable(String displayName) async {
    return !items.values.any((p) => p.displayName == displayName);
  }
}
