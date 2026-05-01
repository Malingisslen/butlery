/// BUT-580 — Algolia EU cluster invariant tests.
///
/// Proves that the GDPR Chapter V cross-border-transfer guard at
/// [AlgoliaSearchRepository] construction:
///   1. Accepts an EU-cluster app id (suffix `-eu`).
///   2. Rejects a non-EU app id with [ArgumentError] in release builds
///      (NOT just `assert`), so the DI module's catch-and-fall-back to
///      Firestore actually triggers in production.
///   3. Allows opt-out via `assertEuCluster: false` for shared-cluster
///      apps where region is verified out-of-band in the dashboard.
///
/// We do NOT test the full SearchModule.initialize() consent gate here —
/// that path reads `String.fromEnvironment('ALGOLIA_APP_ID')` (compile-
/// time) and instantiates Firebase, both of which require integration-
/// level setup. The constructor invariant is the load-bearing check; the
/// SearchModule simply catches `ArgumentError` and stays on Firestore.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/algolia/algolia_search_repository.dart';

void main() {
  group('AlgoliaSearchRepository EU cluster invariant (BUT-580)', () {
    test('isLikelyEuAppId accepts -eu suffix (case insensitive)', () {
      expect(AlgoliaSearchRepository.isLikelyEuAppId('ABCDEF1234-eu'), isTrue);
      expect(AlgoliaSearchRepository.isLikelyEuAppId('abcdef1234-EU'), isTrue);
      expect(AlgoliaSearchRepository.isLikelyEuAppId('xyz-Eu'), isTrue);
    });

    test('isLikelyEuAppId rejects non-EU app ids', () {
      expect(AlgoliaSearchRepository.isLikelyEuAppId('ABCDEF1234'), isFalse);
      expect(AlgoliaSearchRepository.isLikelyEuAppId('ABCDEF1234-us'), isFalse);
      expect(AlgoliaSearchRepository.isLikelyEuAppId(''), isFalse);
    });

    test(
        'constructor throws ArgumentError for non-EU app id when '
        'assertEuCluster is on (default) — release-mode behaviour, not '
        'a debug-only assert', () {
      expect(
        () => AlgoliaSearchRepository(
          appId: 'ABCDEF1234', // no -eu suffix
          apiKey: 'fake-key',
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message.toString(),
          'message',
          contains('BUT-580'),
        )),
      );
    });

    test('constructor accepts EU app id', () {
      // Construction must not throw. We don't make real network calls.
      final repo = AlgoliaSearchRepository(
        appId: 'ABCDEF1234-eu',
        apiKey: 'fake-key',
      );
      expect(repo.usesExternalSearch, isTrue);
    });

    test(
        'constructor accepts non-EU app id when assertEuCluster: false '
        '(escape hatch for shared-cluster apps with region verified '
        'out-of-band)', () {
      final repo = AlgoliaSearchRepository(
        appId: 'ABCDEF1234',
        apiKey: 'fake-key',
        assertEuCluster: false,
      );
      expect(repo.usesExternalSearch, isTrue);
    });
  });
}
