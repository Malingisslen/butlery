import 'package:butlery/core/di/service_roles_registration.dart';
import 'package:butlery/services/unified/friends/friends_service_roles.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _User extends Mock implements UserService {}

class _Friends extends Mock implements UnifiedFriendsService {}

void main() {
  late GetIt container;

  setUp(() => container = GetIt.asNewInstance());
  tearDown(() => container.reset());

  test('every UserService role is the registered UserService', () {
    final service = _User();
    container.registerSingleton<UserService>(service);
    registerUserServiceRoles(container);

    expect(identical(container<OwnProfileReader>(), service), isTrue);
    expect(identical(container<ProfileDirectory>(), service), isTrue);
    expect(identical(container<OwnProfileEditor>(), service), isTrue);
    expect(identical(container<ProfileSession>(), service), isTrue);
  });

  test('a UserService registered later is what the roles return', () {
    container.registerSingleton<UserService>(_User());
    registerUserServiceRoles(container);
    final replacement = _User();
    container
      ..unregister<UserService>()
      ..registerSingleton<UserService>(replacement);

    expect(identical(container<OwnProfileReader>(), replacement), isTrue);
    expect(identical(container<OwnProfileEditor>(), replacement), isTrue);
  });

  test('every UnifiedFriendsService role is the registered service', () {
    final service = _Friends();
    container.registerSingleton<UnifiedFriendsService>(service);
    registerFriendsServiceRoles(container);

    expect(identical(container<FriendsReader>(), service), isTrue);
    expect(identical(container<FriendsActions>(), service), isTrue);
    expect(identical(container<FriendsSession>(), service), isTrue);
  });
}
