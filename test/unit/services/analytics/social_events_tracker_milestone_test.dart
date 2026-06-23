import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics/trackers/social_events_tracker.dart';

import '../../../test_support/base_unit_test.dart';

class _MockAnalyticsRepo extends Mock implements AnalyticsRepository {}

class _MockConsentService extends Mock implements ConsentService {}

void main() {
  group('SocialEventsTracker milestones (BUT-593)', () {
    late _MockAnalyticsRepo repo;
    late _MockConsentService consent;
    late SocialEventsTracker tracker;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(<String, Object>{});
      registerFallbackValue(ConsentPurpose.analytics);
    });

    setUp(() {
      // Empty SharedPreferences per test so milestone state doesn't leak.
      SharedPreferences.setMockInitialValues(<String, Object>{});

      repo = _MockAnalyticsRepo();
      when(
        () => repo.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => repo.setUserProperty(
          name: any(named: 'name'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      consent = _MockConsentService();
      when(() => consent.hasConsent(any())).thenAnswer((_) async => true);

      tracker = SocialEventsTracker(repository: repo);
      tracker.setConsentService(consent);
    });

    tearDown(() {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('logFirstFriendIfMilestone', () {
      test(
        'fires first_friend + sets has_friend user prop on first call',
        () async {
          final joinedAt = DateTime.now().subtract(const Duration(minutes: 30));

          final fired = await tracker.logFirstFriendIfMilestone(
            userId: 'user-1',
            joinedAt: joinedAt,
          );

          expect(fired, isTrue);

          final captured =
              verify(
                    () => repo.logEvent(
                      name: 'first_friend',
                      parameters: captureAny(named: 'parameters'),
                    ),
                  ).captured.single
                  as Map<String, Object>;

          expect(captured['minutes_since_signup'], inInclusiveRange(29, 31));

          verify(
            () => repo.setUserProperty(
              name: 'has_friend',
              value: 'true',
            ),
          ).called(1);
        },
      );

      test('omits minutes_since_signup when joinedAt is null', () async {
        await tracker.logFirstFriendIfMilestone(
          userId: 'user-2',
          joinedAt: null,
        );

        final captured =
            verify(
                  () => repo.logEvent(
                    name: 'first_friend',
                    parameters: captureAny(named: 'parameters'),
                  ),
                ).captured.single
                as Map<String, Object>;

        expect(captured.containsKey('minutes_since_signup'), isFalse);
      });

      test('does NOT re-fire on subsequent accepts for same user', () async {
        final first = await tracker.logFirstFriendIfMilestone(
          userId: 'user-3',
          joinedAt: DateTime.now(),
        );
        expect(first, isTrue);

        clearInteractions(repo);
        final second = await tracker.logFirstFriendIfMilestone(
          userId: 'user-3',
          joinedAt: DateTime.now(),
        );
        expect(second, isFalse);

        verifyNever(
          () => repo.logEvent(
            name: 'first_friend',
            parameters: any(named: 'parameters'),
          ),
        );
      });

      test('dedupe is per-user — different uid still fires', () async {
        await tracker.logFirstFriendIfMilestone(
          userId: 'user-A',
          joinedAt: DateTime.now(),
        );
        clearInteractions(repo);

        final fired = await tracker.logFirstFriendIfMilestone(
          userId: 'user-B',
          joinedAt: DateTime.now(),
        );

        expect(fired, isTrue);
        verify(
          () => repo.logEvent(
            name: 'first_friend',
            parameters: any(named: 'parameters'),
          ),
        ).called(1);
      });

      test('skips when userId is null/empty', () async {
        final firedNull = await tracker.logFirstFriendIfMilestone(
          userId: null,
        );
        final firedEmpty = await tracker.logFirstFriendIfMilestone(
          userId: '',
        );

        expect(firedNull, isFalse);
        expect(firedEmpty, isFalse);
      });

      test('skips when consent not granted', () async {
        when(() => consent.hasConsent(any())).thenAnswer((_) async => false);

        final fired = await tracker.logFirstFriendIfMilestone(
          userId: 'user-noconsent',
        );

        expect(fired, isFalse);
        verifyNever(
          () => repo.logEvent(
            name: 'first_friend',
            parameters: any(named: 'parameters'),
          ),
        );
      });
    });

    group('logFirstCommentIfMilestone', () {
      test(
        'fires first_comment + sets has_commented user prop on first call',
        () async {
          final fired = await tracker.logFirstCommentIfMilestone(
            userId: 'user-1',
            joinedAt: DateTime.now().subtract(const Duration(minutes: 60)),
          );

          expect(fired, isTrue);
          verify(
            () => repo.logEvent(
              name: 'first_comment',
              parameters: any(named: 'parameters'),
            ),
          ).called(1);
          verify(
            () => repo.setUserProperty(
              name: 'has_commented',
              value: 'true',
            ),
          ).called(1);
        },
      );

      test('does NOT re-fire on subsequent comments for same user', () async {
        await tracker.logFirstCommentIfMilestone(userId: 'user-3');
        clearInteractions(repo);

        final second = await tracker.logFirstCommentIfMilestone(
          userId: 'user-3',
        );
        expect(second, isFalse);
        verifyNever(
          () => repo.logEvent(
            name: 'first_comment',
            parameters: any(named: 'parameters'),
          ),
        );
      });

      test('omits minutes_since_signup when joinedAt is null', () async {
        await tracker.logFirstCommentIfMilestone(
          userId: 'user-2',
          joinedAt: null,
        );

        final captured =
            verify(
                  () => repo.logEvent(
                    name: 'first_comment',
                    parameters: captureAny(named: 'parameters'),
                  ),
                ).captured.single
                as Map<String, Object>;

        expect(captured.containsKey('minutes_since_signup'), isFalse);
      });

      test('skips when userId is null', () async {
        final fired = await tracker.logFirstCommentIfMilestone(userId: null);
        expect(fired, isFalse);
      });
    });

    group('logFirstGroupIfMilestone', () {
      test(
        'fires first_group + sets has_group user prop on first call',
        () async {
          final fired = await tracker.logFirstGroupIfMilestone(
            userId: 'user-1',
            joinedAt: DateTime.now().subtract(const Duration(minutes: 15)),
          );

          expect(fired, isTrue);
          verify(
            () => repo.logEvent(
              name: 'first_group',
              parameters: any(named: 'parameters'),
            ),
          ).called(1);
          verify(
            () => repo.setUserProperty(
              name: 'has_group',
              value: 'true',
            ),
          ).called(1);
        },
      );

      test(
        'covers both create and join paths — only first one fires',
        () async {
          // Simulating: user creates a group first.
          final first = await tracker.logFirstGroupIfMilestone(
            userId: 'user-3',
          );
          expect(first, isTrue);

          clearInteractions(repo);

          // Simulating: same user later accepts an invitation to a different
          // group. The second call must NOT re-fire.
          final second = await tracker.logFirstGroupIfMilestone(
            userId: 'user-3',
          );
          expect(second, isFalse);

          verifyNever(
            () => repo.logEvent(
              name: 'first_group',
              parameters: any(named: 'parameters'),
            ),
          );
        },
      );

      test('dedupe is per-user — different uid still fires', () async {
        await tracker.logFirstGroupIfMilestone(userId: 'user-A');
        clearInteractions(repo);

        final fired = await tracker.logFirstGroupIfMilestone(userId: 'user-B');
        expect(fired, isTrue);
      });

      test('omits minutes_since_signup when joinedAt is null', () async {
        await tracker.logFirstGroupIfMilestone(
          userId: 'user-2',
          joinedAt: null,
        );

        final captured =
            verify(
                  () => repo.logEvent(
                    name: 'first_group',
                    parameters: captureAny(named: 'parameters'),
                  ),
                ).captured.single
                as Map<String, Object>;

        expect(captured.containsKey('minutes_since_signup'), isFalse);
      });
    });

    group('logSocialOnboardingStartedIfFirstEntry (BUT-1046)', () {
      test('fires once and writes the prefs key on first call', () async {
        final fired = await tracker.logSocialOnboardingStartedIfFirstEntry(
          userId: 'user-1',
          entryPoint: 'friends_tab',
        );

        expect(fired, isTrue);
        final captured =
            verify(
                  () => repo.logEvent(
                    name: 'social_onboarding_started',
                    parameters: captureAny(named: 'parameters'),
                  ),
                ).captured.single
                as Map<String, Object>;
        expect(captured['entry_point'], equals('friends_tab'));

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('social_onboarding_started_v1_user-1'), isTrue);
      });

      test('does NOT re-fire on second entry for same user', () async {
        final first = await tracker.logSocialOnboardingStartedIfFirstEntry(
          userId: 'user-2',
          entryPoint: 'friends_tab',
        );
        expect(first, isTrue);

        clearInteractions(repo);
        final second = await tracker.logSocialOnboardingStartedIfFirstEntry(
          userId: 'user-2',
          entryPoint: 'feed_empty_cta',
        );
        expect(second, isFalse);

        verifyNever(
          () => repo.logEvent(
            name: 'social_onboarding_started',
            parameters: any(named: 'parameters'),
          ),
        );
      });

      test('does NOT fire without userId or consent', () async {
        // Null + empty user.
        final firedNull = await tracker.logSocialOnboardingStartedIfFirstEntry(
          userId: null,
          entryPoint: 'friends_tab',
        );
        final firedEmpty = await tracker.logSocialOnboardingStartedIfFirstEntry(
          userId: '',
          entryPoint: 'friends_tab',
        );
        expect(firedNull, isFalse);
        expect(firedEmpty, isFalse);

        // No-consent path.
        when(() => consent.hasConsent(any())).thenAnswer((_) async => false);
        final firedNoConsent = await tracker
            .logSocialOnboardingStartedIfFirstEntry(
              userId: 'user-noconsent',
              entryPoint: 'friends_tab',
            );
        expect(firedNoConsent, isFalse);
        verifyNever(
          () => repo.logEvent(
            name: 'social_onboarding_started',
            parameters: any(named: 'parameters'),
          ),
        );
      });
    });

    test(
      'milestones use independent prefs keys — friend does not satisfy comment',
      () async {
        // Fire first_friend.
        final friendFired = await tracker.logFirstFriendIfMilestone(
          userId: 'user-X',
        );
        expect(friendFired, isTrue);

        clearInteractions(repo);

        // first_comment must still fire — they have different prefs prefixes.
        final commentFired = await tracker.logFirstCommentIfMilestone(
          userId: 'user-X',
        );
        expect(commentFired, isTrue);

        // first_group must still fire too.
        clearInteractions(repo);
        final groupFired = await tracker.logFirstGroupIfMilestone(
          userId: 'user-X',
        );
        expect(groupFired, isTrue);
      },
    );
  });
}
