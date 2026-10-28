/// A short link is the form people actually paste into chats. It only opens
/// the app when it sits on the host the phone verifies, so the success arm of
/// generateShortUrl has to name that host.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/deep_link_service.dart';
import 'package:butlery/services/permission_service.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  late MockDeepLinkRepository repository;
  late FakePermissionService permissions;

  setUp(() async {
    // The production ServiceLocator is what the static method resolves
    // through; without it the success arm is never entered.
    await BaseUnitTest.setupUnitWithProductionLocator();
    repository = MockDeepLinkRepository();
    permissions = FakePermissionService()
      ..setPermissionState(
        defaultHasPermission: true,
        currentUserId: 'test-user-id',
      );
    TestServiceLocator.registerMock<PermissionService>(permissions);
    TestServiceLocator.registerMock<DeepLinkService>(
      DeepLinkService(deepLinkRepository: repository),
    );
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  test('a signed-in user gets the short link on butlery.se', () async {
    when(
      () => repository.createShortUrl(any(), any()),
    ).thenAnswer((_) async => 'abc123');

    final shortUrl = await DeepLinkService.generateShortUrl(
      'https://butlery.se/recipe?id=123',
    );

    expect(shortUrl, 'https://butlery.se/s/abc123');
    verify(() => repository.createShortUrl(any(), any())).called(1);
  });
}
