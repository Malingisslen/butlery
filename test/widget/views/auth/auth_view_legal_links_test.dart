// Regression test for BUT-563: privacy policy + terms of service must be
// reachable from the AuthView BEFORE the user authenticates. Play Store and
// App Store policy require both legal documents to be one tap away on the
// pre-login surface — these tests lock that contract in.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/views/auth_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

const _kTermsLabel = 'Villkor';
const _kPrivacyLabel = 'Integritetspolicy';
const _kPumpCap = Duration(seconds: 2);

/// Marker widget rendered in place of the real legal pages so the test only
/// has to verify navigation reached the right route — the legal views
/// themselves have their own widget tests.
class _LegalRouteMarker extends StatelessWidget {
  const _LegalRouteMarker(this.routeName);
  final String routeName;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('ROUTE:$routeName')));
}

Widget _appUnderTest() => createLocalizedTestApp(
      child: const AuthView(),
      wrapInScaffold: false,
      onGenerateRoute: (settings) {
        if (settings.name == Routes.privacyPolicy ||
            settings.name == Routes.termsOfService) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => _LegalRouteMarker(settings.name!),
          );
        }
        return null;
      },
    );

/// Tap a TextSpan whose text contains [substring]. Hit-testing a Finder for an
/// inline TextSpan maps the gesture to the whole RichText, so we trigger the
/// recognizer directly — the same code path the framework dispatches when
/// the user actually taps the span.
void _tapSpan(WidgetTester tester, String substring) {
  for (final element in find.byType(RichText).evaluate()) {
    final widget = element.widget as RichText;
    TapGestureRecognizer? hit;
    widget.text.visitChildren((child) {
      if (hit != null) return false;
      if (child is TextSpan &&
          child.text != null &&
          child.text!.contains(substring) &&
          child.recognizer is TapGestureRecognizer) {
        hit = child.recognizer as TapGestureRecognizer;
        return false;
      }
      return true;
    });
    if (hit != null) {
      hit!.onTap?.call();
      return;
    }
  }
  fail('No tappable TextSpan containing "$substring" was found.');
}

typedef _LegalLinkCase = ({
  String name,
  bool register,
  String label,
  bool spanTap,
  String route,
});

const _cases = <_LegalLinkCase>[
  (
    name: 'footer "$_kTermsLabel" link navigates to TermsOfServiceView',
    register: false,
    label: _kTermsLabel,
    spanTap: false,
    route: Routes.termsOfService,
  ),
  (
    name: 'footer "$_kPrivacyLabel" link navigates to PrivacyPolicyView',
    register: false,
    label: _kPrivacyLabel,
    spanTap: false,
    route: Routes.privacyPolicy,
  ),
  (
    name: 'register-mode inline "$_kTermsLabel" span navigates to ToS',
    register: true,
    label: _kTermsLabel,
    spanTap: true,
    route: Routes.termsOfService,
  ),
  (
    name:
        'register-mode inline "$_kPrivacyLabel" span navigates to PrivacyPolicy',
    register: true,
    label: _kPrivacyLabel,
    spanTap: true,
    route: Routes.privacyPolicy,
  ),
];

void main() {
  group('AuthView pre-login legal links', () {
    late MockAuthService mockAuthService;
    late AuthViewModel realViewModel;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Real AuthViewModel + mocked service: the view binds to a real
      // ChangeNotifier so isLoginMode/togglePasswordVisibility behave
      // exactly as in production, but no Firebase calls leave the test.
      mockAuthService = MockFactory.createAuthService(isAuthenticated: false);
      mockAuthService.setAuthState(isAuthenticated: false, isLoading: false);
      TestServiceLocator.registerMock<AuthService>(mockAuthService);

      realViewModel = AuthViewModel(authService: mockAuthService);
      TestServiceLocator.registerMock<AuthViewModel>(realViewModel);

      // AuthView resolves its viewmodel via the production ServiceLocator
      // (lib/core/providers/application_provider.dart). Both that locator and
      // TestServiceLocator share GetIt.instance, so initializing production
      // ServiceLocator with a bare DIContainer is enough — registrations
      // already on GetIt resolve through it.
      prod.ServiceLocator.initialize(DIContainer());
    });

    tearDown(() async {
      // Do NOT call realViewModel.dispose() here: BaseUnitTest.resetMocks()
      // disposes registered ChangeNotifiers; an explicit dispose double-fires
      // the assertion through the StateNotifierMixin chain.
      prod.ServiceLocator.reset();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    for (final c in _cases) {
      testWidgets(c.name, (tester) async {
        await tester.pumpWidget(_appUnderTest());
        await tester.pumpAndSettle(_kPumpCap);

        if (c.register) {
          // Switch to register mode so the inline acceptance copy renders.
          realViewModel.toggleAuthMode();
          await tester.pumpAndSettle(_kPumpCap);
        }

        if (c.spanTap) {
          _tapSpan(tester, c.label);
        } else {
          await tester.tap(find.text(c.label).first);
        }
        await tester.pumpAndSettle(_kPumpCap);

        expect(find.text('ROUTE:${c.route}'), findsOneWidget);
      });
    }
  });
}
