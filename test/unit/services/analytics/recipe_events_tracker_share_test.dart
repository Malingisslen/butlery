import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics/trackers/recipe_events_tracker.dart';

import '../../../test_support/base_unit_test.dart';

class _MockAnalyticsRepo extends Mock implements AnalyticsRepository {}

class _MockConsentService extends Mock implements ConsentService {}

void main() {
  group('RecipeEventsTracker share instrumentation (BUT-532, BUT-584)', () {
    late _MockAnalyticsRepo repo;
    late _MockConsentService consent;
    late RecipeEventsTracker tracker;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(<String, Object>{});
      registerFallbackValue(ConsentPurpose.analytics);
    });

    setUp(() {
      // Empty SharedPreferences per test so first_share dedupe state
      // doesn't leak across cases.
      SharedPreferences.setMockInitialValues(<String, Object>{});

      repo = _MockAnalyticsRepo();
      when(() => repo.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          )).thenAnswer((_) async {});
      when(() => repo.setUserProperty(
            name: any(named: 'name'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      consent = _MockConsentService();
      // Default to consent granted; individual tests can override.
      when(() => consent.hasConsent(any())).thenAnswer((_) async => true);

      tracker = RecipeEventsTracker(repository: repo);
      tracker.setConsentService(consent);
    });

    tearDown(() {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('logRecipeShared', () {
      test('emits recipe_shared with friend method + bucketed count', () async {
        await tracker.logRecipeShared(
          method: 'friend',
          recipeId: 'recipe-abc',
          recipientCount: 1,
        );

        final captured = verify(() => repo.logEvent(
              name: 'recipe_shared',
              parameters: captureAny(named: 'parameters'),
            )).captured.single as Map<String, Object>;

        expect(captured['method'], 'friend');
        expect(captured['recipient_count_bucket'], '1');
        // recipe_id is passed raw — repo's PII gate hashes it before send.
        expect(captured['recipe_id'], 'recipe-abc');
        expect(captured['timestamp'], isA<String>());
      });

      test('emits recipe_shared with group method + multi-recipient bucket',
          () async {
        await tracker.logRecipeShared(
          method: 'group',
          recipeId: 'recipe-xyz',
          recipientCount: 4,
        );

        final captured = verify(() => repo.logEvent(
              name: 'recipe_shared',
              parameters: captureAny(named: 'parameters'),
            )).captured.single as Map<String, Object>;

        expect(captured['method'], 'group');
        expect(captured['recipient_count_bucket'], '2-5');
        expect(captured['recipe_id'], 'recipe-xyz');
      });

      test('emits recipe_shared with system_share_sheet method + 0 bucket',
          () async {
        await tracker.logRecipeShared(
          method: 'system_share_sheet',
          recipeId: 'recipe-sys',
          recipientCount: 0,
        );

        final captured = verify(() => repo.logEvent(
              name: 'recipe_shared',
              parameters: captureAny(named: 'parameters'),
            )).captured.single as Map<String, Object>;

        expect(captured['method'], 'system_share_sheet');
        expect(captured['recipient_count_bucket'], '0');
      });

      test('emits recipe_shared with link_copy method', () async {
        await tracker.logRecipeShared(
          method: 'link_copy',
          recipeId: 'recipe-copy',
        );

        final captured = verify(() => repo.logEvent(
              name: 'recipe_shared',
              parameters: captureAny(named: 'parameters'),
            )).captured.single as Map<String, Object>;

        expect(captured['method'], 'link_copy');
        expect(captured['recipient_count_bucket'], '0');
      });

      test('omits recipe_id when not provided', () async {
        await tracker.logRecipeShared(method: 'friend', recipientCount: 1);
        final captured = verify(() => repo.logEvent(
              name: 'recipe_shared',
              parameters: captureAny(named: 'parameters'),
            )).captured.single as Map<String, Object>;

        expect(captured.containsKey('recipe_id'), isFalse);
      });

      test('skips event when consent not granted', () async {
        when(() => consent.hasConsent(any())).thenAnswer((_) async => false);

        await tracker.logRecipeShared(
          method: 'friend',
          recipeId: 'recipe-1',
          recipientCount: 1,
        );

        verifyNever(() => repo.logEvent(
              name: any(named: 'name'),
              parameters: any(named: 'parameters'),
            ));
      });

      test('buckets recipient counts correctly across all bands', () async {
        Future<String> bucketFor(int count) async {
          clearInteractions(repo);
          await tracker.logRecipeShared(
            method: 'group',
            recipeId: 'r$count',
            recipientCount: count,
          );
          final params = verify(() => repo.logEvent(
                name: 'recipe_shared',
                parameters: captureAny(named: 'parameters'),
              )).captured.single as Map<String, Object>;
          return params['recipient_count_bucket'] as String;
        }

        expect(await bucketFor(0), '0');
        expect(await bucketFor(1), '1');
        expect(await bucketFor(2), '2-5');
        expect(await bucketFor(5), '2-5');
        expect(await bucketFor(6), '6-10');
        expect(await bucketFor(10), '6-10');
        expect(await bucketFor(11), '11-50');
        expect(await bucketFor(50), '11-50');
        expect(await bucketFor(51), '51+');
        expect(await bucketFor(500), '51+');
      });
    });

    group('logFirstShareIfMilestone', () {
      test('fires first_share + sets sharing_activated user prop on first call',
          () async {
        final joinedAt = DateTime.now().subtract(const Duration(minutes: 90));

        final fired = await tracker.logFirstShareIfMilestone(
          userId: 'user-1',
          shareMethod: 'friend',
          joinedAt: joinedAt,
        );

        expect(fired, isTrue);

        final captured = verify(() => repo.logEvent(
              name: 'first_share',
              parameters: captureAny(named: 'parameters'),
            )).captured.single as Map<String, Object>;

        expect(captured['share_method'], 'friend');
        // Allow 1-min slack for clock drift between setUp and the call.
        expect(captured['minutes_since_signup'], inInclusiveRange(89, 91));

        verify(() => repo.setUserProperty(
              name: 'sharing_activated',
              value: 'true',
            )).called(1);
      });

      test('omits minutes_since_signup when joinedAt is null', () async {
        await tracker.logFirstShareIfMilestone(
          userId: 'user-2',
          shareMethod: 'group',
          joinedAt: null,
        );

        final captured = verify(() => repo.logEvent(
              name: 'first_share',
              parameters: captureAny(named: 'parameters'),
            )).captured.single as Map<String, Object>;

        expect(captured.containsKey('minutes_since_signup'), isFalse);
        expect(captured['share_method'], 'group');
      });

      test('does NOT re-fire on subsequent shares for same user', () async {
        // First share — fires.
        final firstFired = await tracker.logFirstShareIfMilestone(
          userId: 'user-3',
          shareMethod: 'friend',
          joinedAt: DateTime.now(),
        );
        expect(firstFired, isTrue);

        // Second share — should be a no-op.
        clearInteractions(repo);
        final secondFired = await tracker.logFirstShareIfMilestone(
          userId: 'user-3',
          shareMethod: 'system_share_sheet',
          joinedAt: DateTime.now(),
        );
        expect(secondFired, isFalse);

        verifyNever(() => repo.logEvent(
              name: 'first_share',
              parameters: any(named: 'parameters'),
            ));
        verifyNever(() => repo.setUserProperty(
              name: 'sharing_activated',
              value: any(named: 'value'),
            ));
      });

      test('dedupe is per-user — different uid still fires', () async {
        await tracker.logFirstShareIfMilestone(
          userId: 'user-A',
          shareMethod: 'friend',
          joinedAt: DateTime.now(),
        );
        clearInteractions(repo);

        final fired = await tracker.logFirstShareIfMilestone(
          userId: 'user-B',
          shareMethod: 'friend',
          joinedAt: DateTime.now(),
        );

        expect(fired, isTrue);
        verify(() => repo.logEvent(
              name: 'first_share',
              parameters: any(named: 'parameters'),
            )).called(1);
      });

      test('skips when userId is null/empty', () async {
        final firedNull = await tracker.logFirstShareIfMilestone(
          userId: null,
          shareMethod: 'friend',
        );
        final firedEmpty = await tracker.logFirstShareIfMilestone(
          userId: '',
          shareMethod: 'friend',
        );

        expect(firedNull, isFalse);
        expect(firedEmpty, isFalse);
        verifyNever(() => repo.logEvent(
              name: 'first_share',
              parameters: any(named: 'parameters'),
            ));
      });

      test('skips when consent not granted', () async {
        when(() => consent.hasConsent(any())).thenAnswer((_) async => false);

        final fired = await tracker.logFirstShareIfMilestone(
          userId: 'user-noconsent',
          shareMethod: 'friend',
        );

        expect(fired, isFalse);
        verifyNever(() => repo.logEvent(
              name: 'first_share',
              parameters: any(named: 'parameters'),
            ));
      });
    });
  });
}
