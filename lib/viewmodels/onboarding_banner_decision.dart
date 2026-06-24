/// Which one-time onboarding banner the recipe list shows, if any.
///
/// Two mutually-exclusive, dismissible banners live on the recipe list:
///   - [OnboardingBannerKind.skipped]  — for users who skipped onboarding
///     (prompts them to set allergen prefs).
///   - [OnboardingBannerKind.welcome]  — shown once to users who COMPLETED
///     onboarding, greeting them and pointing to a first step (BUT-1369).
///
/// Each banner has its own persisted "dismissed" flag. Skip wins over welcome
/// because `markOnboardingSkipped` also sets `hasCompletedOnboarding = true`, so
/// a skipped user would otherwise match both.
enum OnboardingBannerKind { none, skipped, welcome }

OnboardingBannerKind decideOnboardingBanner({
  required bool skippedBannerDismissed,
  required bool welcomeBannerDismissed,
  required bool hasCompletedOnboarding,
  required DateTime? onboardingSkippedAt,
}) {
  if (onboardingSkippedAt != null) {
    return skippedBannerDismissed
        ? OnboardingBannerKind.none
        : OnboardingBannerKind.skipped;
  }
  if (hasCompletedOnboarding) {
    return welcomeBannerDismissed
        ? OnboardingBannerKind.none
        : OnboardingBannerKind.welcome;
  }
  return OnboardingBannerKind.none;
}
