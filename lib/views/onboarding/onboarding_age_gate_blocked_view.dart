/// Blocking screen for under-15 users (GDPR Art 8). Best-effort deletes the
/// Firebase Auth record so no orphan remains, then signs out.
import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/layout/butlery_page_body.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/brand/butlery_cloche.dart';
import 'package:butlery/widgets/onboarding/onboarding_parts.dart';

class OnboardingAgeGateBlockedView extends StatefulWidget {
  const OnboardingAgeGateBlockedView({super.key});

  @override
  State<OnboardingAgeGateBlockedView> createState() =>
      _OnboardingAgeGateBlockedViewState();
}

class _OnboardingAgeGateBlockedViewState
    extends State<OnboardingAgeGateBlockedView> {
  bool _isSigningOut = false;

  Future<void> _handleSignOut() async {
    setState(() => _isSigningOut = true);
    await _signOutAndCleanup();
    if (mounted) setState(() => _isSigningOut = false);
  }

  Future<void> _signOutAndCleanup() async {
    final authService = ServiceLocator.get<AuthService>();

    // Best-effort: delete the Firebase Auth user so no orphan account remains
    // for underage users. Routed through the service (BUT-1551) so the view
    // never touches FirebaseAuth directly; the service maps reauth-required and
    // other failures internally, and we sign out regardless (session-expiry
    // cleanup handles any leftover orphan).
    await authService.deleteCurrentAuthUser();

    try {
      await authService.signOut();
    } catch (e) {
      AppLogger.warning('Sign-out after age-gate fail: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: ButleryPageBody(
            width: PageWidth.text,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppDimensions.layoutMarginOf(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // The same row the skip link has on the other steps, so the
                          // mark stands where it does there.
                          const SizedBox(height: AppDimensions.minTouchTarget),
                          const Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: ButleryClocheMark(),
                          ),
                          const SizedBox(height: AppDimensions.space16),
                          const OnboardingPlateRule(),
                          const SizedBox(height: AppDimensions.space24),
                          OnboardingIntro(
                            title: l10n.onboardingAgeGateTooYoungTitle,
                            description: l10n.onboardingAgeGateTooYoungBody,
                          ),
                          const SizedBox(height: AppDimensions.space16),
                          Container(
                            padding: const EdgeInsets.all(
                              AppDimensions.space16,
                            ),
                            color: cs.surfaceContainerHighest,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.onboardingAgeGateParentTitle,
                                  style: AppTextStyles.bodyBold.copyWith(
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: AppDimensions.space4),
                                Text(
                                  l10n.onboardingAgeGateParentBody,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    color: cs.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppDimensions.space16),
                          Text(
                            l10n.onboardingAgeGateNothingSaved,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Signing out keeps the name and draws the plate line
                  // never a spinner in its place.
                  OnboardingNavButtons(
                    nextKey: const Key('onboarding_age_gate_signout_button'),
                    nextLabel: l10n.onboardingAgeGateSignOut,
                    onNext: _handleSignOut,
                    busy: _isSigningOut,
                  ),
                  const SizedBox(height: AppDimensions.space16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
