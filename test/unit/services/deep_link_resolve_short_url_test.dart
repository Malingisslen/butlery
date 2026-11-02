/// BUT-2462: opening a short link must not write the opener's uid on someone
/// else's `deep_links` document (nothing reads it and erasure cannot reach it),
/// so a successful resolve reads the long link and records nothing.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/deep_link_service.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  late MockDeepLinkRepository repository;
  late DeepLinkService service;

  setUp(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    repository = MockDeepLinkRepository();
    service = DeepLinkService(
      deepLinkRepository: repository,
      isAuthenticated: () => true,
    );
    TestServiceLocator.registerMock<DeepLinkService>(service);
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  test('a known code resolves to its long link and records no click', () async {
    when(
      () => repository.getLongUrl('Ab3dE5gH'),
    ).thenAnswer((_) async => 'https://butlery.se/recipe?id=abc');

    final longUrl = await service.resolveShortUrl('Ab3dE5gH');

    expect(longUrl, 'https://butlery.se/recipe?id=abc');
    verify(() => repository.getLongUrl('Ab3dE5gH')).called(1);
    verifyNoMoreInteractions(repository);
  });

  test('an unknown code resolves to null', () async {
    when(
      () => repository.getLongUrl('Zz9Zz9Zz'),
    ).thenAnswer((_) async => null);

    expect(await service.resolveShortUrl('Zz9Zz9Zz'), isNull);
  });

  test('a failing lookup resolves to null', () async {
    when(
      () => repository.getLongUrl('Ab3dE5gH'),
    ).thenAnswer((_) async => throw Exception('Database error'));

    expect(await service.resolveShortUrl('Ab3dE5gH'), isNull);
  });
}
