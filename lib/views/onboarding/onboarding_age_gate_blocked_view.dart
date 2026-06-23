/// Blocking screen for under-15 users (GDPR Art 8). Best-effort deletes the
/// Firebase Auth record so no orphan remains, then signs out.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';

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

  /// BUT-946: a supportive, parent-mediated path. Shows an info dialog rather
  /// than a real consent flow (that's the larger BUT-674) — it points the child
  /// toward asking a parent to create their own account.
  void _showParentInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.onboardingAgeGateParentInfoTitle),
        content: Text(ctx.l10n.onboardingAgeGateParentInfoBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.l10n.commonOk),
          ),
        ],
      ),
    );
  }

  Future<void> _signOutAndCleanup() async {
    final authService = ServiceLocator.get<AuthService>();

    // Best-effort: delete the Firebase Auth user so no orphan account remains
    // for underage users. If reauth is required (session too old), swallow —
    // session-expiry cleanup will handle it eventually.
    try {
      await FirebaseAuth.instance.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        AppLogger.info(
          'Underage auth delete needs reauth; signing out instead',
        );
      } else {
        AppLogger.warning('Underage auth delete failed: ${e.code}');
      }
    } catch (e) {
      AppLogger.warning('Underage auth delete failed: $e');
    }

    try {
      await authService.signOut();
    } catch (e) {
      AppLogger.warning('Sign-out after age-gate fail: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingXl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 72, color: cs.primary),
                    const SizedBox(height: AppDimensions.spacingXl),
                    Text(
                      context.l10n.onboardingAgeGateTooYoungTitle,
                      style: AppTextStyles.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    Text(
                      context.l10n.onboardingAgeGateTooYoungBody,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingXxl),
                    SizedBox(
                      width: double.infinity,
                      height: AppDimensions.buttonHeight,
                      child: ElevatedButton(
                        key: const Key('onboarding_age_gate_signout_button'),
                        onPressed: _isSigningOut ? null : _handleSignOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.surfaceContainerHighest,
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: _isSigningOut
                            ? LoadingIndicator(
                                size: AppDimensions.iconSizeM,
                                strokeWidth: 2,
                                color: cs.surfaceContainerHighest,
                              )
                            : Text(
                                context.l10n.onboardingAgeGateSignOut,
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: cs.surfaceContainerHighest,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    // BUT-946: a kinder, parent-mediated alternative to a bare
                    // forced sign-out.
                    TextButton(
                      onPressed: () => _showParentInfo(context),
                      child: Text(
                        context.l10n.onboardingAgeGateParentOption,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
