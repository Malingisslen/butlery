/// Hosts for the sign-in, onboarding, quick capture, legal and FAQ views.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/viewmodels/auth/provider_link_viewmodel.dart';
import 'package:butlery/viewmodels/auth/provider_terms_viewmodel.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/views/auth/provider_link_view.dart';
import 'package:butlery/views/auth/provider_terms_view.dart';
import 'package:butlery/views/auth_view.dart';
import 'package:butlery/views/faq_view.dart';
import 'package:butlery/views/legal/privacy_policy_view.dart';
import 'package:butlery/views/legal/terms_of_service_view.dart';
import 'package:butlery/views/onboarding/onboarding_age_gate_blocked_view.dart';
import 'package:butlery/views/onboarding/onboarding_view.dart';
import 'package:butlery/views/quick_capture_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../state_host.dart';

/// The provider flow state the plain mock hard-codes to "none".
class _ProviderAuth extends MockAuthService {
  @override
  PendingProviderLink? get pendingProviderLink => const PendingProviderLink(
    email: 'malin@example.com',
    provider: SignInProvider.google,
  );

  @override
  String? get providerFirstName => 'Malin';

  @override
  bool isProviderOffered(SignInProvider provider) => true;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 300; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (i > 2 && find.textContaining('Hämtar').evaluate().isEmpty) break;
  }
}

// rootBundle caches the string future of the first test's fake-async zone; the
// dark run then never completes it.
void _forgetLegalAsset(String name) =>
    rootBundle.evict('assets/legal/${name}_sv.md');

final reviewAHosts = <String, StateHost>{
  'AuthView': StateHost(
    build: (ctx) async {
      final auth = _ProviderAuth();
      TestServiceLocator.registerMock<AuthService>(auth);
      TestServiceLocator.registerMock<AuthViewModel>(
        AuthViewModel(authService: auth),
      );
      return const AuthView();
    },
  ),
  'ProviderLinkView': StateHost(
    build: (ctx) async {
      final auth = _ProviderAuth();
      return ProviderLinkView(
        viewModel: ProviderLinkViewModel(authService: auth),
      );
    },
  ),
  'ProviderTermsView': StateHost(
    build: (ctx) async {
      final auth = _ProviderAuth();
      return ProviderTermsView(
        viewModel: ProviderTermsViewModel(
          authService: auth,
          userService: MockUserService(),
        ),
      );
    },
  ),
  'OnboardingView': StateHost(
    build: (ctx) async {
      TestServiceLocator.registerMock<AuthService>(MockAuthService());
      TestServiceLocator.registerFactory<OnboardingViewModel>(
        () => OnboardingViewModel(),
      );
      return const OnboardingView();
    },
  ),
  'OnboardingAgeGateBlockedView': StateHost(
    build: (ctx) async {
      TestServiceLocator.registerMock<AuthService>(MockAuthService());
      return const OnboardingAgeGateBlockedView();
    },
  ),
  'QuickCaptureView': StateHost(
    build: (ctx) async => QuickCaptureView(
      recipeService: MockFactory.createUnifiedRecipeService(),
    ),
  ),
  'PrivacyPolicyView': StateHost(
    build: (ctx) async {
      _forgetLegalAsset('privacy_policy');
      return const PrivacyPolicyView();
    },
    reach: (tester, ctx) => _settle(tester),
  ),
  'TermsOfServiceView': StateHost(
    build: (ctx) async {
      _forgetLegalAsset('terms_of_service');
      return const TermsOfServiceView();
    },
    reach: (tester, ctx) => _settle(tester),
  ),
  'FaqView': StateHost(build: (ctx) async => const FaqView()),
};
