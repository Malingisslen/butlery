/// BUT-1340 AUTH-05: widget tests for EmailVerificationView.
///
/// Two contracts:
///   1. The unverified state renders the title, the user's email address, the
///      resend button, and a "continue anyway" dismiss link.
///   2. Tapping the dismiss link calls the onDismiss callback — the view must
///      not navigate itself; it delegates control to the caller.
///
/// The view resolves AuthService from ServiceLocator in initState. We wire it
/// via DIContainer + ServiceLocator.initialize(), the same pattern used by
/// settings_hub_food_tile_test.dart. AuthService has no ViewModel — state is
/// local (_isSending, _verified, _errorMessage) plus the service's isEmailVerified.
///
/// Would fail if: the title/email Text was removed, or if onDismiss stopped
///   being called when the "Fortsätt ändå" TextButton is tapped.
/// Won't break from: icon changes, padding tweaks, cooldown text rearrangement.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/views/auth/email_verification_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

const _testEmail = 'anna@example.com';

void main() {
  late MockAuthService authService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    ServiceLocator.reset();

    authService = MockAuthService();
    // Unverified state: the view should show the gate screen, not the
    // success screen.
    authService.setAuthState(isAuthenticated: true);
    // Stub the async methods that initState will schedule on the poll timer.
    when(() => authService.reloadUser()).thenAnswer((_) async {});
    when(() => authService.sendEmailVerification()).thenAnswer((_) async {});

    final container = DIContainer();
    container.container.registerSingleton<AuthService>(authService);
    ServiceLocator.initialize(container);
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Widget buildView({VoidCallback? onDismiss}) => createLocalizedTestApp(
        wrapInScaffold: false,
        child: EmailVerificationView(
          email: _testEmail,
          onDismiss: onDismiss,
        ),
      );

  // ────────────────────────────────────────────────────────────────────────────
  // Test 1: unverified state renders the gate screen.
  //
  // Intent: when the user is not yet verified, the view shows the title text,
  // the destination email address, and the resend button — so the user knows
  // what to do next.
  //
  // Would fail if: the Column children were removed or the email Text widget
  //   was dropped.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('shows title and email address in unverified state',
      (tester) async {
    await tester.pumpWidget(buildView());
    // One pump to process initState; don't pumpAndSettle because the view
    // has a 5-second polling Timer that would run forever.
    await tester.pump();

    final l10n = AppLocalizationsSv();

    expect(find.text(l10n.emailVerificationTitle), findsOneWidget,
        reason: 'Title must appear to tell the user what is happening.');

    expect(find.textContaining(_testEmail), findsOneWidget,
        reason: 'The destination email must be shown so the user knows where '
            'to look for the verification link.');

    // Resend button is visible and not in "sending" (loading) state yet.
    expect(find.text(l10n.emailVerificationResend), findsOneWidget,
        reason: 'Resend button must be present in the initial state.');

    // Dismiss link is present.
    expect(find.text(l10n.emailVerificationContinue), findsOneWidget,
        reason: '"Fortsätt ändå" link must let the user skip verification.');
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Test 2: tapping "Fortsätt ändå" calls onDismiss.
  //
  // Intent: the dismiss link must invoke the caller's callback — the view
  // itself must not navigate. If onDismiss is never called, the user cannot
  // leave the gate screen without verifying.
  //
  // Would fail if: the TextButton's onPressed removed the `widget.onDismiss?.call()`
  //   line, or if the button were replaced with a Navigator.pop() that bypasses
  //   the callback.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('tapping dismiss link invokes the onDismiss callback',
      (tester) async {
    var dismissCount = 0;

    await tester.pumpWidget(buildView(onDismiss: () => dismissCount++));
    await tester.pump();

    final l10n = AppLocalizationsSv();
    await tester.tap(find.text(l10n.emailVerificationContinue));
    await tester.pump();

    expect(dismissCount, 1,
        reason: 'Tapping the continue-anyway button must call onDismiss '
            'exactly once so the caller can decide what to show next.');
  });
}
