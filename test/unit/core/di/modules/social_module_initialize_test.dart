/// The friends list starts loading at sign-in, so share dialogs rarely have
/// to wait for it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/modules/social_module.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/deep_link_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';

class _MockUserService extends Mock implements UserService {}

class _MockDeepLinkService extends Mock implements DeepLinkService {}

class _MockConnectivityMonitoringService extends Mock
    implements ConnectivityMonitoringService {}

class _MockFriendsService extends Mock implements UnifiedFriendsService {}

void main() {
  final getIt = GetIt.instance;

  setUp(() {
    final userService = _MockUserService();
    when(userService.initialize).thenAnswer((_) async {});
    getIt
      ..registerSingleton<UserService>(userService)
      ..registerSingleton<DeepLinkService>(_MockDeepLinkService())
      ..registerSingleton<ConnectivityMonitoringService>(
        _MockConnectivityMonitoringService(),
      );
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('signing in loads the friends list', () async {
    final friends = _MockFriendsService();
    when(friends.initialize).thenAnswer((_) async {});
    getIt.registerSingleton<UnifiedFriendsService>(friends);

    await SocialModule().initialize();
    await pumpEventQueue();

    verify(friends.initialize).called(1);
  });

  test('a failed friends load does not fail the module', () async {
    final friends = _MockFriendsService();
    when(friends.initialize).thenAnswer((_) async => throw Exception('down'));
    getIt.registerSingleton<UnifiedFriendsService>(friends);

    await expectLater(SocialModule().initialize(), completes);
    await pumpEventQueue();
  });

  test('before sign-in there is no friends service to load', () async {
    await expectLater(SocialModule().initialize(), completes);
  });
}
