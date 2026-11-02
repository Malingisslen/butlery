import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/di/share_links_from_locator.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/firebase/firebase_block_repository.dart';
import 'package:butlery/services/deep_link_service.dart';
import 'package:butlery/services/social/blocking/blocked_user_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _MockDeepLinks extends Mock implements DeepLinkService {}

class _MockBlockRepo extends Mock implements FirebaseBlockRepository {}

void main() {
  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  group('shortUrlFromLocator', () {
    test(
      'hands the long link back when no DeepLinkService is registered',
      () async {
        expect(
          await shortUrlFromLocator('https://butlery.se/x'),
          'https://butlery.se/x',
        );
      },
    );

    test('shortens through the service registered at call time', () async {
      final deepLinks = _MockDeepLinks();
      when(
        () => deepLinks.generateShortUrl('https://butlery.se/x'),
      ).thenAnswer((_) async => 'https://butlery.se/s/abc');
      ServiceLocator.initialize(DIContainer());
      GetIt.instance.registerSingleton<DeepLinkService>(deepLinks);

      expect(
        await shortUrlFromLocator('https://butlery.se/x'),
        'https://butlery.se/s/abc',
      );
    });
  });

  group('shareRecipientsFromLocator', () {
    test('passes recipients through when no filter is registered', () async {
      expect(await shareRecipientsFromLocator(['a']), ['a']);
    });

    test(
      'drops blocked people using the filter registered at call time',
      () async {
        final repo = _MockBlockRepo();
        when(
          () => repo.getBlockedUserIdsFromServer(),
        ).thenAnswer((_) async => {'a'});
        when(
          () => repo.getBlockedByUserIdsFromServer(),
        ).thenAnswer((_) async => {'b'});
        ServiceLocator.initialize(DIContainer());
        GetIt.instance.registerSingleton<BlockedUserFilter>(
          BlockedUserFilter(blockRepository: repo),
        );

        expect(await shareRecipientsFromLocator(['a', 'b', 'c']), ['c']);
      },
    );
  });
}
