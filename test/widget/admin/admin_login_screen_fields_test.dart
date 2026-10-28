import 'package:butlery/admin_main.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/widgets/common/brand/provider_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

// BUT-2472: the admin site signs in with Google only.
void main() {
  Future<void> pump(WidgetTester tester, AuthService auth) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: AdminLoginScreen(authService: auth),
        wrapInScaffold: false,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the screen has one Google button and no password field', (
    tester,
  ) async {
    await pump(tester, MockFactory.createAuthService());

    expect(find.byType(TextField), findsNothing);
    final button = tester.widget<ProviderButton>(find.byType(ProviderButton));
    expect(button.provider, SignInProvider.google);
  });

  testWidgets('a tap signs in with Google', (tester) async {
    final auth = MockFactory.createAuthService();
    when(
      () => auth.signInWithProvider(SignInProvider.google),
    ).thenAnswer((_) async => ProviderSignInOutcome.signedIn);
    await pump(tester, auth);

    await tester.tap(find.byType(ProviderButton));
    await tester.pumpAndSettle();

    verify(() => auth.signInWithProvider(SignInProvider.google)).called(1);
    expect(find.text('Inloggning misslyckades'), findsNothing);
  });

  testWidgets('a failed sign-in shows the service error', (tester) async {
    final auth = MockFactory.createAuthService(
      error: 'Butlery är bara öppet för inbjudna just nu.',
    );
    when(
      () => auth.signInWithProvider(SignInProvider.google),
    ).thenAnswer((_) async => ProviderSignInOutcome.failed);
    await pump(tester, auth);

    await tester.tap(find.byType(ProviderButton));
    await tester.pumpAndSettle();

    expect(
      find.text('Butlery är bara öppet för inbjudna just nu.'),
      findsOneWidget,
    );
  });

  testWidgets('a second factor is refused with the admin failure text', (
    tester,
  ) async {
    final auth = MockFactory.createAuthService();
    when(
      () => auth.signInWithProvider(SignInProvider.google),
    ).thenAnswer((_) async => ProviderSignInOutcome.mfaRequired);
    await pump(tester, auth);

    await tester.tap(find.byType(ProviderButton));
    await tester.pumpAndSettle();

    expect(find.text('Inloggning misslyckades'), findsOneWidget);
  });
}
