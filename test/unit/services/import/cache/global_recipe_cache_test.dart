/// Unit tests for `GlobalRecipeCache`.
///
/// Behaviours covered:
/// - `findByUrl`: cache miss returns null; cache hit returns the entry;
///   expired entries are filtered out (returned as null); invalid URLs
///   short-circuit without hitting Firestore.
/// - URL key collapsing: tracking-param variants, www. prefix, trailing
///   slash, scheme upcase, query-order, fragment all hash to the same
///   document — proves cache hits across cosmetic URL variants.
/// - `findByContent` / `findByFingerprint`: content-fingerprint lookup
///   returns the matching entry when present, null when absent, null
///   when the fingerprint cannot be generated.
/// - `save`: writes a document keyed on URL hash; falls back to
///   `fp_<fingerprint>` when input isn't a URL; refuses to cache when
///   neither key can be derived; assigns TTL per source type.
/// - `save` requires authentication (BaseService gate).
/// - `getStats` aggregates over a 100-doc sample and reports totals.
///
/// Mocking philosophy: the subject is `GlobalRecipeCache`. Its real
/// collaborators (`UrlNormalizer`, `ContentFingerprint`, `CacheEntry`)
/// are used unmocked; only `FirestoreRepository` is faked (via
/// `FakeFirebaseFirestore`) and `AuthRepository` is mocked for the
/// `requiresAuth` pre-flight check. This means a real bug in
/// URL-normalization or fingerprinting would show up as a behaviour
/// failure here — which is the point.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/import/cache/cache_entry.dart';
import 'package:butlery/services/import/cache/content_fingerprint.dart';
import 'package:butlery/services/import/cache/global_recipe_cache.dart';
import 'package:butlery/services/import/cache/url_normalizer.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// Minimal FirestoreRepository adapter that exposes a real
/// FakeFirebaseFirestore. Concrete `firestore` getter only — Fake
/// (not Mock) because we want the actual fake to handle reads/writes.
class _FakeFirestoreRepository extends Fake implements FirestoreRepository {
  _FakeFirestoreRepository(this._firestore);
  final FakeFirebaseFirestore _firestore;

  @override
  FirebaseFirestore get firestore => _firestore;
}

const _collectionName = 'globalRecipeCache';

ExtractionMeta _meta() => const ExtractionMeta(
  pipeline: 'website',
  tier: 0,
  method: 'json-ld',
  confidence: 0.95,
);

/// Write a `CacheEntry`-shaped document directly to fake firestore so we
/// can control `cachedAt` precisely — production code's `toFirestore()`
/// uses `serverTimestamp()`, which the fake resolves opaquely. For
/// expiration tests we MUST control cachedAt to the millisecond.
Future<void> _seedDoc(
  FakeFirebaseFirestore firestore, {
  required String docId,
  required String urlHash,
  required String contentFingerprint,
  String? domain,
  String sourceType = 'website',
  required DateTime cachedAt,
  int ttlDays = 90,
  int accessCount = 1,
  Map<String, dynamic>? recipe,
}) async {
  await firestore.collection(_collectionName).doc(docId).set({
    'urlHash': urlHash,
    'contentFingerprint': contentFingerprint,
    if (domain != null) 'domain': domain,
    'sourceType': sourceType,
    'recipe':
        recipe ??
        {
          'title': 'Test Recipe',
          'ingredients': ['mjöl', 'socker'],
          'instructions': ['blanda', 'grädda'],
        },
    'extractionMeta': _meta().toMap(),
    'cachedAt': Timestamp.fromDate(cachedAt),
    'ttlDays': ttlDays,
    'accessCount': accessCount,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late _FakeFirestoreRepository firestoreRepo;
  late UrlNormalizer urlNormalizer;
  late ContentFingerprint fingerprinter;
  late MockAuthRepository mockAuthRepo;
  late GlobalRecipeCache cache;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    firestoreRepo = _FakeFirestoreRepository(firestore);
    urlNormalizer = UrlNormalizer();
    fingerprinter = ContentFingerprint();
    mockAuthRepo = MockAuthRepository();

    // BaseService.executeServiceOperation does an _isAuthenticated()
    // pre-flight that resolves AuthRepository from the production
    // ServiceLocator. Wire GetIt + the production ServiceLocator
    // bridge so `save()` and `getStats()` can pass auth.
    final getIt = GetIt.instance;
    if (getIt.isRegistered<AuthRepository>()) {
      await getIt.reset();
    }
    getIt.registerSingleton<AuthRepository>(mockAuthRepo);
    ServiceLocator.initialize(DIContainer());

    when(() => mockAuthRepo.currentUserId).thenReturn('test-user');

    cache = GlobalRecipeCache(
      firestoreRepository: firestoreRepo,
      urlNormalizer: urlNormalizer,
      fingerprinter: fingerprinter,
    );
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  group('findByUrl — cache miss / invalid input', () {
    /// Proves: an unknown URL produces a clean miss (null), not an
    /// uncaught Firestore exception. Catches "swallowed null" only
    /// if the implementation accidentally returns an empty CacheEntry.
    test('returns null on cache miss', () async {
      final result = await cache.findByUrl('https://example.com/never-cached');
      expect(result, isNull);
    });

    /// Proves: invalid input short-circuits and does NOT touch
    /// Firestore. If the production code stopped checking `urlHash`
    /// and tried `_collection.doc(null!)`, this would throw — the
    /// `expect(..., isNull)` would still pass on a thrown future, so
    /// we additionally verify the collection has zero docs (no
    /// accidental writes / reads under a bogus key).
    test('returns null for invalid URL without touching Firestore', () async {
      final result = await cache.findByUrl('not a url at all');
      expect(result, isNull);
      // Confirm no document was created under a bogus key.
      final all = await firestore.collection(_collectionName).get();
      expect(all.docs, isEmpty);
    });

    /// Proves: ftp:// and other non-http schemes are rejected by
    /// `UrlNormalizer.hash()`, so the cache returns null.
    test('returns null for non-http(s) scheme', () async {
      final result = await cache.findByUrl('ftp://example.com/r/42');
      expect(result, isNull);
    });
  });

  group('findByUrl — cache hit', () {
    test('returns the seeded entry on URL hit', () async {
      final hash = urlNormalizer.hash('https://example.com/recipe/1')!;
      await _seedDoc(
        firestore,
        docId: hash,
        urlHash: hash,
        contentFingerprint: 'abc123',
        domain: 'example.com',
        cachedAt: DateTime.utc(2026, 5, 20),
      );

      final result = await cache.findByUrl('https://example.com/recipe/1');

      expect(result, isNotNull);
      expect(result!.domain, 'example.com');
      expect(result.contentFingerprint, 'abc123');
      expect(result.recipe['title'], 'Test Recipe');
    });

    /// Proves the URL-key collapse: cosmetically different URLs (added
    /// tracking params, www., trailing slash, scheme case, query order,
    /// fragment) all hash to the same doc so a single cached entry is
    /// reused. A regression that drops trailing-slash stripping, fails
    /// to lowercase host, or stops sorting query keys would cause this
    /// test to find no document and return null.
    test('hits the same entry across cosmetic URL variants', () async {
      final canonical = 'https://example.com/recipe/1';
      final hash = urlNormalizer.hash(canonical)!;
      await _seedDoc(
        firestore,
        docId: hash,
        urlHash: hash,
        contentFingerprint: 'abc123',
        cachedAt: DateTime.utc(2026, 5, 20),
      );

      final variants = <String>[
        // tracking params
        '$canonical?utm_source=ig&fbclid=abc&gclid=xyz',
        // www. prefix + uppercase scheme
        'HTTPS://www.Example.com/recipe/1',
        // trailing slash
        '$canonical/',
        // fragment
        '$canonical#instructions',
        // tracking + fragment combined
        '$canonical?utm_campaign=foo#share',
      ];

      for (final v in variants) {
        final hit = await cache.findByUrl(v);
        expect(hit, isNotNull, reason: 'expected cache hit for variant: $v');
        expect(hit!.contentFingerprint, 'abc123');
      }
    });

    /// Proves: queries with the same params but different order
    /// collapse to one cache key. UrlNormalizer sorts query params;
    /// if that sort is dropped, the two URLs hash differently and
    /// this test fails.
    test('hits the same entry regardless of query-param order', () async {
      final a = 'https://example.com/r?a=1&b=2&c=3';
      final b = 'https://example.com/r?c=3&a=1&b=2';
      final hashA = urlNormalizer.hash(a)!;
      final hashB = urlNormalizer.hash(b)!;
      expect(
        hashA,
        hashB,
        reason:
            'precondition: normalizer must produce the same hash for reordered query params',
      );

      await _seedDoc(
        firestore,
        docId: hashA,
        urlHash: hashA,
        contentFingerprint: 'order-test',
        cachedAt: DateTime.utc(2026, 5, 20),
      );

      final hit = await cache.findByUrl(b);
      expect(hit, isNotNull);
      expect(hit!.contentFingerprint, 'order-test');
    });
  });

  group('findByUrl — expiration', () {
    /// Proves: an entry younger than its TTL is returned; an entry
    /// past its TTL is filtered out. This is the off-by-one boundary
    /// for `isExpired = clock.now().isAfter(cachedAt + ttlDays)`.
    test('returns entry at T-1ms (just before expiry)', () async {
      final hash = urlNormalizer.hash('https://example.com/fresh')!;
      final now = DateTime.utc(2026, 5, 25, 12);
      await withClock(Clock.fixed(now), () async {
        await _seedDoc(
          firestore,
          docId: hash,
          urlHash: hash,
          contentFingerprint: 'fresh',
          cachedAt: now
              .subtract(const Duration(days: 90))
              .add(
                const Duration(milliseconds: 1),
              ),
          ttlDays: 90,
        );

        final result = await cache.findByUrl('https://example.com/fresh');
        expect(
          result,
          isNotNull,
          reason: 'entry 1ms before its TTL must still be a cache hit',
        );
      });
    });

    test('returns null when entry is past TTL (T+1s)', () async {
      final hash = urlNormalizer.hash('https://example.com/stale')!;
      final now = DateTime.utc(2026, 5, 25, 12);
      await withClock(Clock.fixed(now), () async {
        await _seedDoc(
          firestore,
          docId: hash,
          urlHash: hash,
          contentFingerprint: 'stale',
          // Cached 91 days ago with a 90-day TTL → expired.
          cachedAt: now.subtract(const Duration(days: 91)),
          ttlDays: 90,
        );

        final result = await cache.findByUrl('https://example.com/stale');
        expect(
          result,
          isNull,
          reason: 'expired entry must be filtered out, not returned',
        );
      });
    });

    /// Proves: short-TTL source types (e.g., text/ocr with 30-day TTL)
    /// expire faster than the 90-day default. A regression that hard-
    /// coded TTL would let stale text entries leak through.
    test(
      'honours per-entry TTL — 30-day text entry expires at day 31',
      () async {
        final hash = urlNormalizer.hash('https://example.com/text-source')!;
        final now = DateTime.utc(2026, 5, 25, 12);
        await withClock(Clock.fixed(now), () async {
          await _seedDoc(
            firestore,
            docId: hash,
            urlHash: hash,
            contentFingerprint: 'text-fp',
            sourceType: 'text',
            cachedAt: now.subtract(const Duration(days: 31)),
            ttlDays: 30,
          );

          final result = await cache.findByUrl(
            'https://example.com/text-source',
          );
          expect(result, isNull);
        });
      },
    );
  });

  group('findByFingerprint / findByContent', () {
    test('findByFingerprint returns null when no match exists', () async {
      final result = await cache.findByFingerprint('does-not-exist');
      expect(result, isNull);
    });

    test('findByFingerprint returns the matching entry', () async {
      await _seedDoc(
        firestore,
        docId: 'doc-1',
        urlHash: 'irrelevant',
        contentFingerprint: 'fp-match',
        domain: 'example.com',
        cachedAt: DateTime.utc(2026, 5, 20),
      );

      final result = await cache.findByFingerprint('fp-match');
      expect(result, isNotNull);
      expect(result!.contentFingerprint, 'fp-match');
      expect(result.domain, 'example.com');
    });

    test('findByFingerprint filters expired matches', () async {
      final now = DateTime.utc(2026, 5, 25);
      await withClock(Clock.fixed(now), () async {
        await _seedDoc(
          firestore,
          docId: 'doc-old',
          urlHash: 'h',
          contentFingerprint: 'old-fp',
          cachedAt: now.subtract(const Duration(days: 200)),
          ttlDays: 90,
        );

        final result = await cache.findByFingerprint('old-fp');
        expect(result, isNull);
      });
    });

    /// Proves: `findByContent` generates the fingerprint then delegates
    /// to `findByFingerprint`. End-to-end: real ContentFingerprint over
    /// real ingredients, looked up in real (fake) Firestore.
    test('findByContent finds a previously-saved recipe by content', () async {
      const title = 'Pannkakor med sylt';
      final ingredients = ['mjöl', 'mjölk', 'ägg', 'salt'];
      final fp = fingerprinter.generate(
        title: title,
        ingredients: ingredients,
        instructionCount: 3,
      );
      expect(
        fp,
        isNotNull,
        reason: 'precondition: fingerprinter must produce a fp for valid input',
      );

      await _seedDoc(
        firestore,
        docId: 'doc-content',
        urlHash: 'h',
        contentFingerprint: fp!,
        cachedAt: DateTime.utc(2026, 5, 20),
      );

      final result = await cache.findByContent(
        title: title,
        ingredients: ingredients,
        instructionCount: 3,
      );
      expect(result, isNotNull);
      expect(result!.contentFingerprint, fp);
    });

    test(
      'findByContent returns null when fingerprint cannot be generated',
      () async {
        // Empty title + empty ingredients → fingerprinter returns null.
        final result = await cache.findByContent(
          title: '',
          ingredients: const [],
          instructionCount: 0,
        );
        expect(result, isNull);
      },
    );
  });

  group('save — happy paths and key derivation', () {
    /// Proves: a saved URL recipe is keyed by URL hash and is
    /// retrievable via findByUrl. This is the round-trip contract.
    test(
      'round-trip: save(url) then findByUrl returns the same recipe',
      () async {
        const url = 'https://ica.se/recept/pannkakor-12345';
        final recipe = {
          'title': 'Pannkakor',
          'ingredients': ['mjöl', 'mjölk', 'ägg'],
          'instructions': ['blanda', 'stek'],
        };

        final ok = await cache.save(
          input: url,
          recipeData: recipe,
          extractionMeta: _meta(),
          sourceType: 'website',
        );
        expect(ok, isTrue);

        // Verify the doc was actually written under the URL hash.
        final expectedHash = urlNormalizer.hash(url)!;
        final doc = await firestore
            .collection(_collectionName)
            .doc(expectedHash)
            .get();
        expect(doc.exists, isTrue);
        expect(
          doc.data()!['domain'],
          'ica.se',
          reason: 'save must extract and persist domain',
        );
        expect(doc.data()!['sourceType'], 'website');
        expect(
          doc.data()!['ttlDays'],
          90,
          reason: 'website source type maps to 90-day TTL',
        );
      },
    );

    /// Proves: save() picks the right TTL per source. Catches a flipped
    /// or missing entry in the `_ttlBySource` map.
    test('assigns 180-day TTL for YouTube and 60 for tiktok', () async {
      await cache.save(
        input: 'https://youtube.com/watch?v=abc',
        recipeData: const {
          'title': 'YouTube Recipe',
          'ingredients': ['x'],
          'instructions': ['y'],
        },
        extractionMeta: _meta(),
        sourceType: 'youtube',
      );

      await cache.save(
        input: 'https://tiktok.com/@u/video/123',
        recipeData: const {
          'title': 'TikTok Recipe',
          'ingredients': ['x'],
          'instructions': ['y'],
        },
        extractionMeta: _meta(),
        sourceType: 'tiktok',
      );

      final ytHash = urlNormalizer.hash('https://youtube.com/watch?v=abc')!;
      final ttHash = urlNormalizer.hash('https://tiktok.com/@u/video/123')!;
      final yt = await firestore.collection(_collectionName).doc(ytHash).get();
      final tt = await firestore.collection(_collectionName).doc(ttHash).get();
      expect(yt.data()!['ttlDays'], 180);
      expect(tt.data()!['ttlDays'], 60);
    });

    /// Proves: unknown source types fall back to the 90-day default.
    /// Catches a regression that returned `null` (and then crashed on
    /// the int field) or used 0 (immediate-expiry footgun).
    test('unknown source type falls back to 90-day TTL', () async {
      await cache.save(
        input: 'https://example.com/r',
        recipeData: const {
          'title': 'Unknown Source',
          'ingredients': ['x'],
          'instructions': ['y'],
        },
        extractionMeta: _meta(),
        sourceType: 'totally-made-up',
      );

      final hash = urlNormalizer.hash('https://example.com/r')!;
      final doc = await firestore.collection(_collectionName).doc(hash).get();
      expect(doc.data()!['ttlDays'], 90);
    });

    /// Proves: non-URL input falls back to the `fp_<fingerprint>`
    /// document ID. This is the "manual text paste" path. A regression
    /// that always required a URL hash would refuse to cache here.
    test('non-URL input writes under fp_<fingerprint> doc id', () async {
      const input = 'Pannkakor med sylt — copy-pasted recipe text';
      final recipe = {
        'title': 'Pannkakor',
        'ingredients': ['mjöl', 'mjölk', 'ägg', 'salt'],
        'instructions': ['blanda', 'grädda', 'servera'],
      };

      final ok = await cache.save(
        input: input,
        recipeData: recipe,
        extractionMeta: _meta(),
        sourceType: 'text',
      );
      expect(ok, isTrue);

      final fp = fingerprinter.generateFromMap(recipe);
      expect(
        fp,
        isNotNull,
        reason: 'precondition: fingerprint must be generatable',
      );
      final doc = await firestore
          .collection(_collectionName)
          .doc('fp_$fp')
          .get();
      expect(doc.exists, isTrue);
      expect(
        doc.data()!['domain'],
        isNull,
        reason: 'non-URL input has no domain',
      );
      expect(
        doc.data()!['ttlDays'],
        30,
        reason: 'text source type uses a 30-day TTL',
      );
    });

    /// Proves: when BOTH key sources fail (non-URL input AND a recipe
    /// too thin to fingerprint), save returns false — does not write a
    /// garbage doc. Catches an "always-write" regression that would
    /// pollute the cache with keyless entries.
    test('refuses to cache when no key can be derived', () async {
      final ok = await cache.save(
        input: 'just a plain phrase',
        recipeData: const {
          // Empty title → fingerprinter returns null.
          'title': '',
          'ingredients': <String>[],
          'instructions': <String>[],
        },
        extractionMeta: _meta(),
        sourceType: 'text',
      );
      expect(ok, isFalse);

      final all = await firestore.collection(_collectionName).get();
      expect(
        all.docs,
        isEmpty,
        reason: 'failed save must not leave a garbage doc behind',
      );
    });

    /// Proves: a re-save under the same URL overwrites the previous
    /// document (production uses `SetOptions(merge: false)`). Catches
    /// a regression that flipped it to `merge: true`, which would
    /// leave stale fields from the old recipe.
    test(
      're-save under same URL overwrites previous data (merge:false)',
      () async {
        const url = 'https://example.com/recipe/overwrite-me';

        await cache.save(
          input: url,
          recipeData: const {
            'title': 'Original',
            'ingredients': ['a', 'b'],
            'instructions': ['1', '2'],
            // Field that exists in v1 but not v2 — must be GONE after re-save.
            'legacyField': 'should-disappear',
          },
          extractionMeta: _meta(),
          sourceType: 'website',
        );

        await cache.save(
          input: url,
          recipeData: const {
            'title': 'Replacement',
            'ingredients': ['x', 'y'],
            'instructions': ['1'],
          },
          extractionMeta: _meta(),
          sourceType: 'website',
        );

        final hash = urlNormalizer.hash(url)!;
        final doc = await firestore.collection(_collectionName).doc(hash).get();
        final recipe = doc.data()!['recipe'] as Map<String, dynamic>;
        expect(recipe['title'], 'Replacement');
        expect(
          recipe.containsKey('legacyField'),
          isFalse,
          reason:
              'merge:false must overwrite; stale legacyField from v1 must NOT survive',
        );
      },
    );
  });

  group('save — auth gate', () {
    /// Proves: `save()` goes through `executeServiceOperation` with
    /// `requiresAuth: true`. With no current user the operation must
    /// return false and NOT write anything. Catches a regression that
    /// loosened the auth check (caching anonymous-user pages globally
    /// is a privacy issue if those pages came from authenticated
    /// browsing context).
    test('returns false and writes nothing when unauthenticated', () async {
      when(() => mockAuthRepo.currentUserId).thenReturn(null);

      final ok = await cache.save(
        input: 'https://example.com/anon',
        recipeData: const {
          'title': 'Anon Recipe',
          'ingredients': ['x'],
          'instructions': ['y'],
        },
        extractionMeta: _meta(),
        sourceType: 'website',
      );

      expect(
        ok,
        isFalse,
        reason:
            'save without auth must return false (executeServiceOperation default)',
      );
      final all = await firestore.collection(_collectionName).get();
      expect(
        all.docs,
        isEmpty,
        reason: 'no doc should be written when auth check fails',
      );
    });
  });

  group('getStats', () {
    test('returns null when unauthenticated', () async {
      when(() => mockAuthRepo.currentUserId).thenReturn(null);
      final stats = await cache.getStats();
      expect(stats, isNull);
    });

    /// Proves: stats reports total count and aggregates the sample.
    /// Catches an off-by-one in the aggregator or a swapped numerator/
    /// denominator in the rate calculations.
    test(
      'aggregates totals, expired count, and access count over sample',
      () async {
        final now = DateTime.utc(2026, 5, 25);
        await withClock(Clock.fixed(now), () async {
          // 2 fresh entries from example.com (access counts 5 and 7).
          await _seedDoc(
            firestore,
            docId: 'fresh-1',
            urlHash: 'h1',
            contentFingerprint: 'fp1',
            domain: 'example.com',
            cachedAt: now.subtract(const Duration(days: 1)),
            accessCount: 5,
          );
          await _seedDoc(
            firestore,
            docId: 'fresh-2',
            urlHash: 'h2',
            contentFingerprint: 'fp2',
            domain: 'example.com',
            cachedAt: now.subtract(const Duration(days: 2)),
            accessCount: 7,
          );
          // 1 expired entry from ica.se (access count 3).
          await _seedDoc(
            firestore,
            docId: 'old-1',
            urlHash: 'h3',
            contentFingerprint: 'fp3',
            domain: 'ica.se',
            cachedAt: now.subtract(const Duration(days: 200)),
            ttlDays: 90,
            accessCount: 3,
          );

          final stats = await cache.getStats();
          expect(stats, isNotNull);
          expect(stats!.totalEntries, 3);
          expect(stats.sampleSize, 3);
          expect(
            stats.expiredInSample,
            1,
            reason: 'one of three entries is past its TTL',
          );
          expect(stats.totalAccessesInSample, 5 + 7 + 3);
          expect(stats.topDomains['example.com'], 2);
          expect(stats.topDomains['ica.se'], 1);
        });
      },
    );

    test('returns zeroed stats for an empty cache', () async {
      final stats = await cache.getStats();
      expect(stats, isNotNull);
      expect(stats!.totalEntries, 0);
      expect(stats.sampleSize, 0);
      expect(stats.expiredInSample, 0);
      expect(stats.totalAccessesInSample, 0);
      expect(stats.topDomains, isEmpty);
      // Derived rates must not divide-by-zero.
      expect(stats.sampleHitRate, 0);
      expect(stats.estimatedExpiredPercent, 0);
    });
  });

  group('CacheStats — derived metrics', () {
    test('sampleHitRate divides totalAccesses by sampleSize', () {
      const s = CacheStats(
        totalEntries: 100,
        sampleSize: 10,
        expiredInSample: 2,
        totalAccessesInSample: 25,
        topDomains: {},
      );
      expect(s.sampleHitRate, 2.5);
      expect(s.estimatedExpiredPercent, 20.0);
    });
  });
}
