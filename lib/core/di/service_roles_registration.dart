import 'package:get_it/get_it.dart';
import 'package:butlery/services/unified/friends/friends_service_roles.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';

// BUT-1507: each role resolves to whichever service instance is registered at
// the moment it is asked for, so a role is never a second copy, and a test
// that swaps in its own UserService mock gets that mock under every role too.

/// Call in the same scope that registers [UserService].
void registerUserServiceRoles(GetIt container) {
  container
    ..registerFactory<OwnProfileReader>(() => container<UserService>())
    ..registerFactory<ProfileDirectory>(() => container<UserService>())
    ..registerFactory<OwnProfileEditor>(() => container<UserService>())
    ..registerFactory<ProfileSession>(() => container<UserService>());
}

/// Call in the same scope that registers [UnifiedFriendsService].
void registerFriendsServiceRoles(GetIt container) {
  container
    ..registerFactory<FriendsReader>(() => container<UnifiedFriendsService>())
    ..registerFactory<FriendsActions>(() => container<UnifiedFriendsService>())
    ..registerFactory<FriendsSession>(() => container<UnifiedFriendsService>());
}
