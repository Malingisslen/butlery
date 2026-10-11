// BUT-920: the sign-in screen's way into guest mode, and the failure a guest
// start leaves for it when its own screen was gone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/account/age_verification_service.dart';
import 'package:butlery/services/auth/guest_auth_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/guest/guest_start_coordinator.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/views/auth/guest_start_view.dart';
import 'package:butlery/views/auth_view.dart';
import 'package:butlery/widgets/auth/guest_entry_button.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

final _sv = AppLocalizationsSv();

class _MockGuestAuth extends Mock implements GuestAuthService {}

class _MockAge extends Mock implements AgeVerificationService {}

void main() {
  late MockAuthService authService;
  late _MockGuestAuth guestAuth;
  late GuestStartCoordinator coordinator;

  setUpAll(() async => BaseUnitTest.setupUnit());

  setUp(() async {
    await TestServiceLocator.initialize();
    authService = MockFactory.createAuthService(isAuthenticated: false);
    authService.setAuthState(isAuthenticated: false, isLoading: false);
    TestServiceLocator.registerMock<AuthService>(authService);
    TestServiceLocator.registerMock<AuthViewModel>(
      AuthViewModel(authService: authService),
    );
    guestAuth = _MockGuestAuth();
    coordinator = GuestStartCoordinator(
      guestAuth: () => guestAuth,
      authService: authService,
      ageVerification: _MockAge.new,
      eraseGuest: () async => true,
      seedStarterRecipes: (_) async {},
    );
    TestServiceLocator.registerMock<GuestStartCoordinator>(coordinator);
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async => BaseUnitTest.teardownUnit());

  Widget app() =>
      createLocalizedTestApp(child: const AuthView(), wrapInScaffold: false);

  testWidgets('"Prova utan konto" opens the guest start', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text(_sv.guestTryWithoutAccount), findsOneWidget);
    await tester.ensureVisible(find.byKey(GuestEntryButton.buttonKey));
    await tester.tap(find.byKey(GuestEntryButton.buttonKey));
    await tester.pumpAndSettle();

    expect(find.byType(GuestStartView), findsOneWidget);
  });

  testWidgets('a guest start that failed after its screen was gone is told '
      'here, once', (tester) async {
    when(() => guestAuth.signInAsGuest()).thenAnswer((_) async => false);
    await coordinator.start(1990);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text(_sv.guestStartFailed), findsOneWidget);
    expect(coordinator.takePendingFailure(), isNull);
  });
}
