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

  setUp(() async {
    // Without the production locator the static method returns null before it
    // reaches the repository.
    await BaseUnitTest.setupUnitWithProductionLocator();
    repository = MockDeepLinkRepository();
    TestServiceLocator.registerMock<DeepLinkService>(
      DeepLinkService(deepLinkRepository: repository),
    );
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  test('a known code resolves to its long link and records no click', () async {
    when(
      () => repository.getLongUrl('Ab3dE5gH'),
    ).thenAnswer((_) async => 'https://butlery.se/recipe?id=abc');
    when(() => repository.trackUrlClick(any())).thenAnswer((_) async {});

    final longUrl = await DeepLinkService.resolveShortUrl('Ab3dE5gH');

    expect(longUrl, 'https://butlery.se/recipe?id=abc');
    verifyNever(() => repository.trackUrlClick(any()));
  });

  test('an unknown code resolves to null', () async {
    when(
      () => repository.getLongUrl('Zz9Zz9Zz'),
    ).thenAnswer((_) async => null);

    expect(await DeepLinkService.resolveShortUrl('Zz9Zz9Zz'), isNull);
  });

  test('a failing lookup resolves to null', () async {
    when(
      () => repository.getLongUrl('Ab3dE5gH'),
    ).thenAnswer((_) async => throw Exception('Database error'));

    expect(await DeepLinkService.resolveShortUrl('Ab3dE5gH'), isNull);
  });
}
