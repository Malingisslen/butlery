/// Hosts for the sign-in, guest and legal views the register had not compared.
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';
import 'package:butlery/services/auth/password_reset_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/password_reset_viewmodel.dart';
import 'package:butlery/views/auth/guest_start_view.dart';
import 'package:butlery/views/auth/guest_upgrade_view.dart';
import 'package:butlery/views/auth/mfa_challenge_view.dart';
import 'package:butlery/views/auth/set_new_password_view.dart';
import 'package:butlery/views/legal/community_guidelines_view.dart';
import 'package:butlery/views/more/help_area_view.dart';
import 'package:butlery/views/settings/licenses_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../state_harness.dart';
import '../state_host.dart';

class _MockResetService extends Mock implements PasswordResetService {}

class _MockReports extends Mock implements ReportService {}

class _MockMfa extends Mock implements AuthMfaService {}

Future<void> _letAssetsLoad(WidgetTester tester, String loadingText) async {
  for (var i = 0; i < 50; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (find.text(loadingText).evaluate().isEmpty) break;
  }
}

final reviewAuthHosts = <String, StateHost>{
  'GuestStartView': StateHost(build: (ctx) async => const GuestStartView()),
  'GuestUpgradeView': StateHost(build: (ctx) async => const GuestUpgradeView()),
  'MfaChallengeView': StateHost(
    build: (ctx) async {
      final mfa = _MockMfa();
      final auth = MockAuthService();
      return MfaChallengeView(
        challenge: const MfaResolverInfo(resolver: Object()),
        email: 'malin@example.com',
        password: 'hemligt',
        mfaService: mfa,
        authService: auth,
      );
    },
  ),
  'SetNewPasswordView': StateHost(
    build: (ctx) async {
      final service = _MockResetService();
      final auth = MockAuthService();
      when(() => service.check('code-1')).thenAnswer(
        (_) async => (email: 'anna@example.com', failure: null),
      );
      TestServiceLocator.registerMock<PasswordResetViewModel>(
        PasswordResetViewModel(resetService: service, authService: auth),
      );
      return const SetNewPasswordView(code: 'code-1');
    },
  ),
  'CommunityGuidelinesView': StateHost(
    build: (ctx) async {
      // The asset future is cached from the light run's fake-async zone.
      rootBundle.evict('assets/legal/community_guidelines_sv.md');
      return const CommunityGuidelinesView();
    },
    reach: (tester, ctx) =>
        _letAssetsLoad(tester, sv.loadingCommunityGuidelines),
  ),
  'LicensesView': StateHost(
    build: (ctx) async => const LicensesView(),
    reach: (tester, ctx) async {
      for (var i = 0; i < 50; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    },
  ),
  'HelpAreaView': StateHost(
    build: (ctx) async {
      final reports = _MockReports();
      when(reports.watchIsAdmin).thenAnswer((_) => Stream.value(false));
      TestServiceLocator.registerMock<ReportService>(reports);
      return const HelpAreaView();
    },
  ),
};
