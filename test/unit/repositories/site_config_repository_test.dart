/// Unit tests for SiteConfigRepository.
///
/// Covers normalization, the in-memory LRU cache, Firestore fallback,
/// the built-in defaults list, and supported-config queries. Brings
/// the file from 0% → ~80% coverage as part of the BUT-852-followup
/// repositories-coverage push.
library;

import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/site_config_repository.dart';

void main() {
  group('SiteConfigRepository', () {
    late FakeFirebaseFirestore firestore;
    late SiteConfigRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = SiteConfigRepository(firestore: firestore);
    });

    group('Domain normalization', () {
      test('lowercases mixed-case domains', () async {
        await firestore.collection('site_configs').doc('ica.se').set({
          'domain': 'ica.se',
          'isSupported': true,
          'qualityScore': 0.9,
        });

        final config = await repo.getConfig('ICA.SE');

        expect(config.domain, equals('ica.se'));
      });

      test('strips www. prefix', () async {
        await firestore.collection('site_configs').doc('ica.se').set({
          'domain': 'ica.se',
          'isSupported': true,
          'qualityScore': 0.9,
        });

        final config = await repo.getConfig('www.ica.se');

        expect(config.domain, equals('ica.se'));
      });

      test('strips m. mobile prefix', () async {
        await firestore.collection('site_configs').doc('koket.se').set({
          'domain': 'koket.se',
          'isSupported': true,
          'qualityScore': 0.85,
        });

        final config = await repo.getConfig('m.koket.se');

        expect(config.domain, equals('koket.se'));
      });

      test('strips trailing slash', () async {
        await firestore.collection('site_configs').doc('ica.se').set({
          'domain': 'ica.se',
          'isSupported': true,
          'qualityScore': 0.9,
        });

        final config = await repo.getConfig('ica.se/');

        expect(config.domain, equals('ica.se'));
      });

      test('trims surrounding whitespace', () async {
        await firestore.collection('site_configs').doc('ica.se').set({
          'domain': 'ica.se',
          'isSupported': true,
          'qualityScore': 0.9,
        });

        final config = await repo.getConfig('  ica.se  ');

        expect(config.domain, equals('ica.se'));
      });
    });

    group('getConfig', () {
      test('loads an existing config from Firestore', () async {
        await firestore.collection('site_configs').doc('example.com').set({
          'domain': 'example.com',
          'titleSelector': 'h1.title',
          'ingredientsSelector': '.ingredients li',
          'instructionsSelector': '.steps li',
          'isSupported': true,
          'qualityScore': 0.8,
        });

        final config = await repo.getConfig('example.com');

        expect(config.domain, equals('example.com'));
        expect(config.titleSelector, equals('h1.title'));
        expect(config.isSupported, isTrue);
      });

      test('falls back to default when config missing in Firestore', () async {
        final config = await repo.getConfig('unknown-site.com');

        // SiteConfig.defaultFor mirrors the input domain even when no
        // Firestore doc exists; the returned config should carry that
        // domain and is what callers downstream rely on.
        expect(config.domain, equals('unknown-site.com'));
      });

      test('caches loaded config (second call no firestore read)', () async {
        await firestore.collection('site_configs').doc('example.com').set({
          'domain': 'example.com',
          'titleSelector': 'h1',
          'isSupported': true,
          'qualityScore': 0.8,
        });

        final first = await repo.getConfig('example.com');
        // Delete the firestore doc — second call must come from cache.
        await firestore.collection('site_configs').doc('example.com').delete();
        final second = await repo.getConfig('example.com');

        expect(second.titleSelector, equals(first.titleSelector));
      });

      test('cache expires after the documented hour and reloads', () async {
        final base = DateTime(2026, 1, 1, 12, 0);
        await withClock(Clock.fixed(base), () async {
          await firestore.collection('site_configs').doc('example.com').set({
            'domain': 'example.com',
            'titleSelector': 'h1.first',
            'isSupported': true,
            'qualityScore': 0.8,
          });
          final first = await repo.getConfig('example.com');
          expect(first.titleSelector, equals('h1.first'));
        });

        // Update underlying doc; without expiry the cache would still
        // serve the old value.
        await firestore.collection('site_configs').doc('example.com').set({
          'domain': 'example.com',
          'titleSelector': 'h1.second',
          'isSupported': true,
          'qualityScore': 0.8,
        });

        await withClock(
          Clock.fixed(base.add(const Duration(hours: 2))),
          () async {
            final reloaded = await repo.getConfig('example.com');
            expect(reloaded.titleSelector, equals('h1.second'));
          },
        );
      });
    });

    group('getConfigIfExists', () {
      test('returns supported config from Firestore', () async {
        await firestore.collection('site_configs').doc('example.com').set({
          'domain': 'example.com',
          'titleSelector': 'h1',
          'ingredientsSelector': '.ing',
          'instructionsSelector': '.step',
          'isSupported': true,
          'qualityScore': 0.8,
        });

        final config = await repo.getConfigIfExists('example.com');

        expect(config, isNotNull);
        expect(config!.domain, equals('example.com'));
      });

      test(
        'returns null for unknown domain with no built-in default',
        () async {
          final config = await repo.getConfigIfExists('totally-unknown.xyz');

          expect(config, isNull);
        },
      );

      test('falls back to built-in default when Firestore missing', () async {
        // ica.se is in the built-in default list inside the repo.
        final config = await repo.getConfigIfExists('ica.se');

        expect(config, isNotNull);
        expect(config!.domain, equals('ica.se'));
      });
    });

    group('getSupportedConfigs', () {
      test(
        'returns supported docs from Firestore sorted by qualityScore',
        () async {
          await firestore.collection('site_configs').doc('high.com').set({
            'domain': 'high.com',
            'titleSelector': 'h1',
            'isSupported': true,
            'qualityScore': 0.9,
          });
          await firestore.collection('site_configs').doc('low.com').set({
            'domain': 'low.com',
            'titleSelector': 'h1',
            'isSupported': true,
            'qualityScore': 0.5,
          });
          await firestore.collection('site_configs').doc('unsupported.com').set(
            {
              'domain': 'unsupported.com',
              'titleSelector': 'h1',
              'isSupported': false,
              'qualityScore': 0.95,
            },
          );

          final configs = await repo.getSupportedConfigs();

          // Order matters — the contract is desc-by-qualityScore.
          expect(
            configs.map((c) => c.domain).toList(),
            equals(['high.com', 'low.com']),
          );
          expect(
            configs.map((c) => c.domain),
            isNot(contains('unsupported.com')),
          );
        },
      );
    });

    group('isHighQualityDomain', () {
      test('false before any load (cache is empty)', () {
        expect(repo.isHighQualityDomain('ica.se'), isFalse);
      });

      test('true after loading a high-quality config', () async {
        await firestore.collection('site_configs').doc('ica.se').set({
          'domain': 'ica.se',
          'titleSelector': 'h1',
          'ingredientsSelector': '.ing',
          'instructionsSelector': '.step',
          'isSupported': true,
          'qualityScore': 0.9,
        });
        await repo.getConfig('ica.se');

        expect(repo.isHighQualityDomain('ica.se'), isTrue);
      });
    });

    group('Lifecycle', () {
      test('ensureDefaultConfigs is idempotent', () async {
        await repo.ensureDefaultConfigs();
        await expectLater(repo.ensureDefaultConfigs(), completes);
      });

      test(
        'clearCache empties the cache (next call hits Firestore again)',
        () async {
          await firestore.collection('site_configs').doc('example.com').set({
            'domain': 'example.com',
            'titleSelector': 'h1.original',
            'isSupported': true,
            'qualityScore': 0.8,
          });

          await repo.getConfig('example.com');
          await firestore.collection('site_configs').doc('example.com').set({
            'domain': 'example.com',
            'titleSelector': 'h1.updated',
            'isSupported': true,
            'qualityScore': 0.8,
          });

          repo.clearCache();
          final reloaded = await repo.getConfig('example.com');

          expect(reloaded.titleSelector, equals('h1.updated'));
        },
      );
    });
  });
}
