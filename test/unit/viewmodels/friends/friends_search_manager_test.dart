import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/search_repository.dart';
import 'package:butlery/viewmodels/friends/friends_search_manager.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

/// Behaviour under test (BUT-1442): the friend-search box must distinguish a
/// search-backend OUTAGE (degraded notice, no caching) from a legitimate
/// zero-match (neutral empty). `FriendsSearchManager._performSearch` reads the
/// `failed` flag off `management.searchUsersResult` and drives `searchDegraded`
/// + `searchError` accordingly, and must NOT cache a failed result.
void main() {
  group('FriendsSearchManager — degraded-search handling (BUT-1442)', () {
    late FriendsSearchManager manager;
    late MockUnifiedFriendsService mockFriendsService;
    late MockFriendsManagementOperations mockManagement;

    SearchResult<UserProfile> successResult(List<UserProfile> hits) =>
        SearchResult<UserProfile>(
          hits: hits,
          totalHits: hits.length,
          page: 0,
          totalPages: 1,
          processingTimeMs: 0,
        );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue('');
    });

    setUp(() {
      mockFriendsService = MockFactory.createUnifiedFriendsService();
      mockManagement = MockFriendsManagementOperations();
      mockFriendsService.setFriendsState(
        isInitialized: true,
        management: mockManagement,
      );
      manager = FriendsSearchManager(friendsService: mockFriendsService);
    });

    tearDown(() {
      manager.dispose();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    test('a FAILED result surfaces a degraded notice instead of "no users '
        'found"', () {
      fakeAsync((async) {
        when(
          () => mockManagement.searchUsersResult('anna'),
        ).thenAnswer((_) async => const SearchResult<UserProfile>.failure());

        manager.updateSearch('anna');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        expect(
          manager.searchDegraded,
          isTrue,
          reason: 'a backend outage must raise the degraded flag',
        );
        expect(manager.searchError, AppLocale.current.socialSearchUnavailable);
        expect(manager.searchResults, isEmpty);
      });
    });

    test('a successful EMPTY result is a neutral empty, NOT degraded', () {
      fakeAsync((async) {
        when(
          () => mockManagement.searchUsersResult('ghost'),
        ).thenAnswer((_) async => successResult(const []));

        manager.updateSearch('ghost');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        expect(
          manager.searchDegraded,
          isFalse,
          reason: 'a query that ran and matched nobody is not an outage',
        );
        expect(manager.searchError, isNull);
        expect(manager.searchResults, isEmpty);
      });
    });

    test('a successful non-empty result clears any degraded state and exposes '
        'the hits', () {
      fakeAsync((async) {
        final hit = MockFactory.createUserProfile(
          userId: 'u1',
          displayName: 'Anna',
          email: 'anna@example.com',
        );
        when(
          () => mockManagement.searchUsersResult('anna'),
        ).thenAnswer((_) async => successResult([hit]));

        manager.updateSearch('anna');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        expect(manager.searchDegraded, isFalse);
        expect(manager.searchError, isNull);
        expect(manager.searchResults, hasLength(1));
        expect(manager.searchResults.first.displayName, 'Anna');
      });
    });

    test('a FAILED result is NOT cached: re-searching the same query hits the '
        'backend again and can recover', () {
      fakeAsync((async) {
        final hit = MockFactory.createUserProfile(
          userId: 'u1',
          displayName: 'Anna',
          email: 'anna@example.com',
        );

        // First attempt: the backend is down.
        when(
          () => mockManagement.searchUsersResult('anna'),
        ).thenAnswer((_) async => const SearchResult<UserProfile>.failure());

        manager.updateSearch('anna');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        expect(manager.searchDegraded, isTrue);

        // Backend recovers. Searching the SAME query must re-query (a cached
        // failure would otherwise poison this query until eviction) and recover.
        when(
          () => mockManagement.searchUsersResult('anna'),
        ).thenAnswer((_) async => successResult([hit]));

        // Force a fresh search of the identical query. clearSearch resets the
        // query string so updateSearch('anna') is seen as a change and the
        // debounce fires again.
        manager.clearSearch();
        manager.updateSearch('anna');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        expect(
          manager.searchDegraded,
          isFalse,
          reason:
              're-querying a recovered backend must clear the degraded flag',
        );
        expect(manager.searchResults, hasLength(1));
        // The backend was consulted on both attempts — the failed first result
        // was never served from cache.
        verify(() => mockManagement.searchUsersResult('anna')).called(2);
      });
    });

    test('a SUCCESSFUL result IS cached: re-searching the same query serves '
        'the cache without re-querying', () {
      fakeAsync((async) {
        final hit = MockFactory.createUserProfile(
          userId: 'u1',
          displayName: 'Anna',
          email: 'anna@example.com',
        );
        when(
          () => mockManagement.searchUsersResult('anna'),
        ).thenAnswer((_) async => successResult([hit]));

        manager.updateSearch('anna');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();
        expect(manager.searchResults, hasLength(1));

        manager.clearSearch();
        manager.updateSearch('anna');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        expect(manager.searchResults, hasLength(1));
        // Second search served from cache — backend consulted only once. This
        // is the contrast that makes the no-cache-on-failure test meaningful.
        verify(() => mockManagement.searchUsersResult('anna')).called(1);
      });
    });
  });
}
