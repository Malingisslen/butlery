/// Auth-routing subtree for the Butlery app shell.
///
/// Extracted from `main.dart` (BUT-530). Holds the gate that decides what the
/// signed-in (or signed-out) user sees: the auth view, the soft email-
/// verification gate, the onboarding flow (with mid-flow resume), or the main
/// menu. [InitializationWrapper], [AuthWrapper]/[_AuthWrapperState] and
/// [_OnboardingResumeGate] live together because the wrapper keys the auth
/// state via a private-typed [GlobalKey] — splitting them would break that key.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/bootstrap/handlers/deep_link_handler.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/onboarding/onboarding_progress_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/auth/email_verification_view.dart';
import 'package:butlery/views/auth_view.dart';
import 'package:butlery/views/onboarding/onboarding_view.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';

class InitializationWrapper extends StatelessWidget {
  // CRITICAL: Use GlobalKey to prevent AuthWrapper recreation
  static final GlobalKey<_AuthWrapperState> _authWrapperKey =
      GlobalKey<_AuthWrapperState>();

  const InitializationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthWrapper(key: _authWrapperKey);
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final AuthService _authService;
  late final UserService _userService;
  bool _verificationDismissed = false;
  bool _wasAuthenticated = false;

  /// Only gate users created after this date (grandfather existing users).
  static final DateTime _verificationGateDate = DateTime(2026, 3, 20);

  @override
  void initState() {
    super.initState();
    _authService = ServiceLocator.get<AuthService>();
    _userService = ServiceLocator.get<UserService>();

    // Log initial state
    if (_authService.currentUser != null) {
      AppLogger.debug(
        'AuthWrapper: User logged in at startup: ${_authService.currentUser!.uid}',
      );
    }

    // Listen to AuthService ChangeNotifier for auth state changes
    _authService.addListener(_onAuthStateChanged);
    // Listen to UserService to react when profile loads
    _userService.addListener(_onUserProfileChanged);

    // Handle race: if UserService loaded the profile before our listener
    // was attached, we'd never get notified. Re-read state after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _userService.currentUserProfile != null) {
        setState(() {});
      }
    });
  }

  void _onAuthStateChanged() {
    if (mounted) {
      setState(() {});

      final user = _authService.currentUser;
      if (user != null) {
        AppLogger.debug(
            'AuthWrapper: User authenticated: ${user.uid.maskedUserId}');
        // Re-process pending deep link when transitioning to authenticated
        if (!_wasAuthenticated) {
          DeepLinkHandler().processPendingDeepLink(context);
        }
      } else {
        AppLogger.debug('AuthWrapper: User signed out');
      }
      _wasAuthenticated = user != null;
    }
  }

  void _onUserProfileChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    AppLogger.debug(
      'AuthWrapper: Disposing wrapper for user: ${_authService.currentUser?.uid.maskedUserId ?? 'NULL'}',
    );
    _authService.removeListener(_onAuthStateChanged);
    _userService.removeListener(_onUserProfileChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // State-based rendering - AuthService ChangeNotifier triggers rebuilds
    final user = _authService.currentUser;

    if (user != null) {
      // Email verification gate for new users (soft — dismissable)
      if (!_verificationDismissed) {
        final createdAfterGate = user.metadata.creationTime?.isAfter(
              _verificationGateDate,
            ) ??
            false;

        if (createdAfterGate && !user.emailVerified) {
          return EmailVerificationView(
            email: user.email.orEmpty(),
            key: ValueKey('verify_${user.uid}'),
            onDismiss: () {
              setState(() => _verificationDismissed = true);
            },
          );
        }
      }

      // Check if user has completed onboarding
      final profile = _userService.currentUserProfile;
      if (profile == null) {
        // BUG-12: a null profile can mean "still loading" OR "load/create
        // failed" (permission-denied / App Check / unavailable). Only show the
        // bare spinner while genuinely loading — when the load errored, show a
        // retryable error state so the user isn't stuck on an endless spinner.
        if (_userService.hasError) {
          return _ProfileLoadErrorView(
            message:
                _userService.error ?? context.l10n.errorCouldNotLoadProfile,
            onRetry: () => _userService.retryLoadProfile(),
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!profile.hasCompletedOnboarding) {
        AppLogger.debug('AuthWrapper: User needs onboarding');
        // BUT-745: Skip the resume Firestore round-trip for users who just
        // signed up — there can't be a progress doc yet, so the gate's
        // FutureBuilder spinner is pure flicker. Heuristic: auth-account is
        // fresh (creationTime within ~5s of now). Falls through to the gate
        // when creationTime is null/unknown so returning users still resume
        // correctly.
        final createdAt = user.metadata.creationTime;
        final isFreshSignup = createdAt != null &&
            clock.now().difference(createdAt) < const Duration(seconds: 5);
        if (isFreshSignup) {
          return KeyedSubtree(
            key: ValueKey('onboarding_${user.uid}'),
            child: const OnboardingView(initialPage: 0),
          );
        }
        return _OnboardingResumeGate(
          key: ValueKey('onboarding_${user.uid}'),
          userId: user.uid,
        );
      }

      AppLogger.debug(
        'AuthWrapper: NAVIGATION SUCCESS - User logged in: ${user.uid}',
      );
      return KeyedSubtree(
        key: ValueKey(user.uid),
        child: LayoutScaffolds.mainMenu(),
      );
    }

    AppLogger.debug('AuthWrapper: No user logged in, showing auth view');
    return const AuthView();
  }
}

/// BUT-675: One-shot Firestore lookup to resolve the next-incomplete onboarding
/// step for resume support. Fires the `onboarding_resumed` analytics event when
/// the user re-enters mid-flow, and the `onboarding_abandoned` event + a
/// bottom-sheet nudge when the last step is older than 24h.
class _OnboardingResumeGate extends StatefulWidget {
  final String userId;

  const _OnboardingResumeGate({super.key, required this.userId});

  @override
  State<_OnboardingResumeGate> createState() => _OnboardingResumeGateState();
}

class _OnboardingResumeGateState extends State<_OnboardingResumeGate> {
  late final Future<_ResumeResolution> _future;
  bool _nudgeShown = false;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  Future<_ResumeResolution> _resolve() async {
    // BUT-743: resolved via DI; no FirebaseFirestore.instance here.
    final svc = ServiceLocator.get<OnboardingProgressService>();
    final progress = await svc.readProgress(widget.userId);
    final pageIndex = svc.resolveResumePageIndex(progress);
    final showNudge = svc.shouldShowAbandonedNudge(progress, clock.now());
    // Fire-and-forget analytics — never block UI.
    if (progress.hasProgress && (pageIndex ?? 0) > 0) {
      unawaited(svc.logResumed(lastStep: progress.lastCompletedStep));
    }
    if (showNudge) {
      unawaited(svc.logAbandoned(lastStep: progress.lastCompletedStep));
    }
    return _ResumeResolution(
      pageIndex: pageIndex ?? 0,
      showNudge: showNudge,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ResumeResolution>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final resolution = snap.data!;
        // Schedule nudge for after first frame so we have a Scaffold context.
        if (resolution.showNudge && !_nudgeShown) {
          _nudgeShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showResumeNudge(context);
          });
        }
        return OnboardingView(initialPage: resolution.pageIndex);
      },
    );
  }

  Future<void> _showResumeNudge(BuildContext context) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.onboardingResumeTitle,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  l10n.onboardingResumeBody,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.surfaceContainerHighest,
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: Text(l10n.onboardingResumeCta),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ResumeResolution {
  final int pageIndex;
  final bool showNudge;
  const _ResumeResolution({required this.pageIndex, required this.showNudge});
}

/// BUG-12: Retryable error state shown when the user is authenticated but the
/// profile load/create failed. Replaces the previously un-retryable spinner.
class _ProfileLoadErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ProfileLoadErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: AppDimensions.iconSizeXxl,
                  color: cs.error,
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.surfaceContainerHighest,
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: Text(context.l10n.commonRetry),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
