// BUT-916 mockup screen 3, "Koppla ihop": the password of the account at the
// provider's verified address is asked for once.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/viewmodels/auth/provider_link_viewmodel.dart';
import 'package:butlery/views/auth/mfa_challenge_view.dart';
import 'package:butlery/views/auth/provider_link_view.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart';

class _Auth extends MockAuthService {
  bool passwordOk = true;
  bool secondFactor = false;
  MfaResolverInfo? _challenge;
  int cancelled = 0;
  final List<String> signIns = [];

  @override
  PendingProviderLink? get pendingProviderLink => const PendingProviderLink(
    email: 'malin@example.com',
    provider: SignInProvider.google,
  );

  @override
  MfaResolverInfo? get pendingMfaChallenge => _challenge;

  @override
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signIns.add('$email/$password');
    if (secondFactor) {
      _challenge = const MfaResolverInfo(resolver: Object());
      return false;
    }
    return passwordOk;
  }

  @override
  void cancelPendingProviderLink() => cancelled++;
}

class _Outcome {
  bool closed = false;
  MfaChallengeResult? result;
}

void main() {
  Future<_Outcome> open(WidgetTester tester, _Auth auth) async {
    final outcome = _Outcome();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              outcome.result = await Navigator.of(context)
                  .push<MfaChallengeResult>(
                    MaterialPageRoute(
                      builder: (_) => ProviderLinkView(
                        viewModel: ProviderLinkViewModel(authService: auth),
                      ),
                    ),
                  );
              outcome.closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return outcome;
  }

  testWidgets('names the address and the provider', (tester) async {
    await open(tester, _Auth());

    expect(find.text('Koppla ihop'), findsWidgets);
    expect(find.textContaining('malin@example.com'), findsOneWidget);
    expect(find.textContaining('kopplas Google till kontot'), findsOneWidget);
  });

  testWidgets('the password signs in to that address and the step closes', (
    tester,
  ) async {
    final auth = _Auth();
    final outcome = await open(tester, auth);

    await tester.enterText(
      find.byKey(const ValueKey('providerLink.password')),
      'hemligt123',
    );
    await tester.tap(find.byKey(const ValueKey('providerLink.submit')));
    await tester.pumpAndSettle();

    expect(auth.signIns, ['malin@example.com/hemligt123']);
    expect(outcome.closed, isTrue);
    expect(outcome.result, MfaChallengeResult.signedIn);
    expect(auth.cancelled, 0);
  });

  testWidgets('with two-step on, the code is asked for before linking', (
    tester,
  ) async {
    final auth = _Auth()..secondFactor = true;
    await open(tester, auth);

    await tester.enterText(
      find.byKey(const ValueKey('providerLink.password')),
      'hemligt123',
    );
    await tester.tap(find.byKey(const ValueKey('providerLink.submit')));
    await tester.pumpAndSettle();

    final challenge = tester.widget<MfaChallengeView>(
      find.byType(MfaChallengeView),
    );
    expect(challenge.email, 'malin@example.com');
    expect(challenge.provider, isNull, reason: 'the password was the factor');
  });

  testWidgets('Avbryt drops the waiting credential', (tester) async {
    final auth = _Auth();
    final outcome = await open(tester, auth);

    final cancel = find.byKey(const ValueKey('providerLink.cancel'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    expect(auth.cancelled, 1);
    expect(outcome.closed, isTrue);
    expect(outcome.result, isNull);
    expect(auth.signIns, isEmpty);
  });
}
