// Regression test for BUT-563: privacy policy + terms of service must be
// reachable from the AuthView BEFORE the user authenticates. Play Store and
// App Store policy require both legal documents to be one tap away on the
// pre-login surface — these tests lock that contract in.
//
// BUT-1426 (a11y): the register-mode inline ToS / Privacy links were
// TapGestureRecognizer spans on a Text.rich — no link role, no accessible
// name. They are now Semantics(link: true, label:) + GestureDetector widgets,
// and the consent checkboxes carry a >=48dp tap target. This file additionally
// pins (a) the inline links navigate via their NEW widget structure, (b) the
// link semantics labels are exposed to screen readers, and (c) the consent
// checkbox hit areas meet the 48dp minimum.

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

// Visible link/footer text (Swedish — harness defaults to sv locale).
const _kTermsLabel = 'Villkor';
const _kPrivacyLabel = 'Integritetspolicy';

// Accessible link names (a11yTermsOfServiceLink / a11yPrivacyPolicyLink in
// app_sv.arb). The ToS one deliberately differs from the visible "Villkor"
// so a screen reader announces the fuller "Användarvillkor".
//
// The inline link's semantics node merges the Semantics(label:) with the
// child Text's visible word, so the rendered label is e.g.
// "Användarvillkor\nVillkor". We match the a11y name as a substring via a
// RegExp finder rather than asserting an exact string.
final _kTermsA11yLabel = RegExp('Användarvillkor');
final _kPrivacyA11yLabel = RegExp(r'^Integritetspolicy');

const _kPumpCap = Duration(seconds: 2);
const _kMinTapTarget = 48.0; // WCAG 2.5.5 / EAA minimum touch target.

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

    /// Pump the view and flip to register mode so the consent rows + inline
    /// acceptance copy render.
    Future<void> pumpRegisterMode(WidgetTester tester) async {
      await tester.pumpWidget(_appUnderTest());
      await tester.pumpAndSettle(_kPumpCap);
      realViewModel.toggleAuthMode();
      await tester.pumpAndSettle(_kPumpCap);
    }

    testWidgets('footer "$_kTermsLabel" link navigates to TermsOfServiceView', (
      tester,
    ) async {
      await tester.pumpWidget(_appUnderTest());
      await tester.pumpAndSettle(_kPumpCap);

      await tester.tap(find.text(_kTermsLabel).first);
      await tester.pumpAndSettle(_kPumpCap);

      expect(find.text('ROUTE:${Routes.termsOfService}'), findsOneWidget);
    });

    testWidgets(
      'footer "$_kPrivacyLabel" link navigates to PrivacyPolicyView',
      (tester) async {
        await tester.pumpWidget(_appUnderTest());
        await tester.pumpAndSettle(_kPumpCap);

        await tester.tap(find.text(_kPrivacyLabel).first);
        await tester.pumpAndSettle(_kPumpCap);

        expect(find.text('ROUTE:${Routes.privacyPolicy}'), findsOneWidget);
      },
    );

    testWidgets('register-mode inline ToS link navigates to ToS', (
      tester,
    ) async {
      await pumpRegisterMode(tester);

      // BUT-1426: the inline link is now a Semantics(link:)+GestureDetector,
      // located by its accessible name (the contract screen readers see).
      final link = find.bySemanticsLabel(_kTermsA11yLabel);
      await tester.ensureVisible(link);
      await tester.pumpAndSettle(_kPumpCap);
      await tester.tap(link);
      await tester.pumpAndSettle(_kPumpCap);

      expect(find.text('ROUTE:${Routes.termsOfService}'), findsOneWidget);
    });

    testWidgets(
      'register-mode inline Privacy link navigates to PrivacyPolicy',
      (
        tester,
      ) async {
        await pumpRegisterMode(tester);

        // Two nodes carry "Integritetspolicy" (the footer link + this inline
        // link). .last is the inline one (footer renders first in the tree).
        final link = find.bySemanticsLabel(_kPrivacyA11yLabel).last;
        await tester.ensureVisible(link);
        await tester.pumpAndSettle(_kPumpCap);
        await tester.tap(link);
        await tester.pumpAndSettle(_kPumpCap);

        expect(find.text('ROUTE:${Routes.privacyPolicy}'), findsOneWidget);
      },
    );

    testWidgets('inline links expose a named link role to screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpRegisterMode(tester);

      // The whole BUT-1426 a11y win: each inline legal link is announced with
      // a link role AND a human name. Scroll into view so the off-screen
      // (isHidden) semantics node materializes, then assert the label exists.
      // Its absence (e.g. a regression to bare GestureDetector or Text.rich
      // recognizer spans) fails this assertion.
      final tosLink = find.bySemanticsLabel(_kTermsA11yLabel);
      await tester.ensureVisible(tosLink);
      await tester.pumpAndSettle(_kPumpCap);

      expect(
        tosLink,
        findsOneWidget,
        reason: 'ToS inline link must carry its a11y label',
      );
      expect(
        find.bySemanticsLabel(_kPrivacyA11yLabel),
        findsWidgets,
        reason: 'Privacy inline link must carry its a11y label',
      );

      handle.dispose();
    });

    testWidgets('consent checkboxes provide a >=48dp tap target', (
      tester,
    ) async {
      await pumpRegisterMode(tester);

      // BUT-1426 / WCAG 2.5.5: the consent boxes were SizedBox(24,24), which
      // clamped the hit area to half the minimum. Both the age-confirm and
      // terms-accept checkboxes must now sit in a >=48dp box. Asserting the
      // rendered size (not a literal in the widget) keeps this honest against
      // a refactor that swaps the SizedBox for Padding/constraints.
      final checkboxFinders = find.byType(Checkbox);
      expect(
        checkboxFinders,
        findsNWidgets(2),
        reason: 'register mode shows the age + terms consent checkboxes',
      );

      for (final element in checkboxFinders.evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(
          size.width,
          greaterThanOrEqualTo(_kMinTapTarget),
          reason: 'checkbox tap target width must be >=48dp',
        );
        expect(
          size.height,
          greaterThanOrEqualTo(_kMinTapTarget),
          reason: 'checkbox tap target height must be >=48dp',
        );
      }
    });
  });
}
