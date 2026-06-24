// BUT-1369: which onboarding banner (if any) the recipe list shows.
//
// Two mutually-exclusive, one-time, dismissible banners:
//   - SKIPPED  : shown to users who skipped onboarding (existing behaviour).
//   - WELCOME  : shown once to users who COMPLETED onboarding (new).
// Each has its own dismissed flag. This pins the precedence + gating as a pure
// function so the logic is covered without standing up the heavy ViewModel.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/viewmodels/onboarding_banner_decision.dart';

void main() {
  final skippedAt = DateTime(2026, 6, 1);

  group('decideOnboardingBanner', () {
    test('completed, not skipped, nothing dismissed → welcome', () {
      expect(
        decideOnboardingBanner(
          skippedBannerDismissed: false,
          welcomeBannerDismissed: false,
          hasCompletedOnboarding: true,
          onboardingSkippedAt: null,
        ),
        OnboardingBannerKind.welcome,
      );
    });

    test('skipped, nothing dismissed → skipped', () {
      expect(
        decideOnboardingBanner(
          skippedBannerDismissed: false,
          welcomeBannerDismissed: false,
          hasCompletedOnboarding: true,
          onboardingSkippedAt: skippedAt,
        ),
        OnboardingBannerKind.skipped,
      );
    });

    test('skip takes precedence over completed (skip also marks completed)', () {
      // markOnboardingSkipped sets hasCompletedOnboarding=true AND
      // onboardingSkippedAt; the skipped banner must win, never the welcome one.
      expect(
        decideOnboardingBanner(
          skippedBannerDismissed: false,
          welcomeBannerDismissed: false,
          hasCompletedOnboarding: true,
          onboardingSkippedAt: skippedAt,
        ),
        OnboardingBannerKind.skipped,
      );
    });

    test('welcome dismissed → none (completed, not skipped)', () {
      expect(
        decideOnboardingBanner(
          skippedBannerDismissed: false,
          welcomeBannerDismissed: true,
          hasCompletedOnboarding: true,
          onboardingSkippedAt: null,
        ),
        OnboardingBannerKind.none,
      );
    });

    test('skipped dismissed → none (skipped)', () {
      expect(
        decideOnboardingBanner(
          skippedBannerDismissed: true,
          welcomeBannerDismissed: false,
          hasCompletedOnboarding: true,
          onboardingSkippedAt: skippedAt,
        ),
        OnboardingBannerKind.none,
      );
    });

    test('neither completed nor skipped → none', () {
      expect(
        decideOnboardingBanner(
          skippedBannerDismissed: false,
          welcomeBannerDismissed: false,
          hasCompletedOnboarding: false,
          onboardingSkippedAt: null,
        ),
        OnboardingBannerKind.none,
      );
    });

    test('skipped + skip-dismissed → none, never falls through to welcome', () {
      // A skipped user who dismissed the skip banner must NOT then see the
      // welcome banner (their welcome flag is untouched) — the skip branch
      // short-circuits. Pins the invariant a refactor could silently break.
      expect(
        decideOnboardingBanner(
          skippedBannerDismissed: true,
          welcomeBannerDismissed: false,
          hasCompletedOnboarding: true,
          onboardingSkippedAt: skippedAt,
        ),
        OnboardingBannerKind.none,
      );
    });

    test('a dismissed welcome flag does not suppress the skipped banner', () {
      // The two flags are independent — dismissing one must not hide the other.
      expect(
        decideOnboardingBanner(
          skippedBannerDismissed: false,
          welcomeBannerDismissed: true,
          hasCompletedOnboarding: true,
          onboardingSkippedAt: skippedAt,
        ),
        OnboardingBannerKind.skipped,
      );
    });
  });
}
