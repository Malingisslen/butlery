// P6-U09 — the MFA challenge view and the backup-code gate
// (Skarmar v12 etapp 3 #authmfa, etapp 6 #mfaaktiv; produktregler.md:745-749).

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/views/auth/mfa_challenge_view.dart';
import 'package:butlery/views/settings/mfa_backup_codes_dialog.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _FakeMfa implements AuthMfaService {
  bool codeOk = false;
  MfaRecoveryOutcome recovery = MfaRecoveryOutcome.rejected;
  final List<String> recoveredWith = [];
  final List<String> signInCodes = [];

  @override
  Future<bool> completeMfaSignIn(
    MfaResolverInfo resolverInfo,
    String code,
  ) async {
    signInCodes.add(code);
    return codeOk;
  }

  @override
  Future<MfaRecoveryOutcome> recoverWithBackupCode({
    required String email,
    required String password,
    required String code,
  }) async {
    recoveredWith.add(code);
    return recovery;
  }

  @override
  String? get errorMessage => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAuth implements AuthService {
  bool signedIn = false;
  int finishCalls = 0;
  int signIns = 0;
  int cleared = 0;

  @override
  Future<bool> finishMfaSignIn() async {
    finishCalls++;
    signedIn = true;
    return true;
  }

  @override
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signIns++;
    signedIn = true;
    return true;
  }

  @override
  void clearPendingMfa() => cleared++;

  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _challenge = MfaResolverInfo(resolver: Object());

Widget _host(
  _FakeMfa mfa,
  _FakeAuth auth,
  void Function(MfaChallengeResult?) onResult,
) => createLocalizedTestApp(
  child: Builder(
    builder: (context) => ElevatedButton(
      onPressed: () async {
        final result = await Navigator.of(context).push<MfaChallengeResult>(
          MaterialPageRoute(
            builder: (_) => MfaChallengeView(
              challenge: _challenge,
              email: 'anna@example.com',
              password: 'hemligt123',
              mfaService: mfa,
              authService: auth,
            ),
          ),
        );
        onResult(result);
      },
      child: const Text('open'),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  testWidgets('asks for the app code in one field, without a timer or resend', (
    tester,
  ) async {
    final mfa = _FakeMfa();
    await tester.pumpWidget(_host(mfa, _FakeAuth(), (_) {}));
    await _open(tester);

    expect(find.text('Skriv koden'), findsOneWidget);
    expect(
      find.text(
        'Öppna din autentiseringsapp och skriv den sexsiffriga koden för Butlery.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mfaChallenge.code')), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(const ValueKey('mfaChallenge.resend')), findsNothing);
    expect(find.byKey(const ValueKey('mfaChallenge.timer')), findsNothing);
    expect(find.text('Använd en reservkod'), findsOneWidget);

    FilledButton verify() => tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey('mfaChallenge.verify')),
        matching: find.byType(FilledButton),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('mfaChallenge.code')),
      '41900',
    );
    await tester.pump();
    expect(verify().onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('mfaChallenge.code')),
      '419000',
    );
    await tester.pump();
    expect(mfa.signInCodes, isEmpty, reason: 'nothing is sent by typing alone');
    await tester.tap(find.byKey(const ValueKey('mfaChallenge.verify')));
    await tester.pump();

    expect(mfa.signInCodes, ['419000']);
  });

  testWidgets('Verifiera stays off until six digits are there', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_FakeMfa(), _FakeAuth(), (_) {}));
    await _open(tester);

    FilledButton verify() => tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey('mfaChallenge.verify')),
        matching: find.byType(FilledButton),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('mfaChallenge.code')),
      '41900',
    );
    await tester.pump();
    expect(verify().onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('mfaChallenge.code')),
      '419000',
    );
    await tester.pump();
    expect(verify().onPressed, isNotNull);
  });

  testWidgets('a wrong code says so and does not sign in', (tester) async {
    final mfa = _FakeMfa()..codeOk = false;
    final auth = _FakeAuth();
    await tester.pumpWidget(_host(mfa, auth, (_) {}));
    await _open(tester);

    await tester.enterText(
      find.byKey(const ValueKey('mfaChallenge.code')),
      '123456',
    );
    await tester.pump(); // Verifiera turns on at six digits
    await tester.tap(find.byKey(const ValueKey('mfaChallenge.verify')));
    await tester.pump();

    expect(
      find.text(
        'Koden stämmer inte. Ta den senaste koden för Butlery i autentiseringsappen och försök igen.',
      ),
      findsOneWidget,
    );
    expect(auth.finishCalls, 0);
  });

  testWidgets('a right code signs in', (tester) async {
    final mfa = _FakeMfa()..codeOk = true;
    final auth = _FakeAuth();
    MfaChallengeResult? result;
    await tester.pumpWidget(_host(mfa, auth, (r) => result = r));
    await _open(tester);

    await tester.enterText(
      find.byKey(const ValueKey('mfaChallenge.code')),
      '419000',
    );
    await tester.pump(); // Verifiera turns on at six digits
    await tester.tap(find.byKey(const ValueKey('mfaChallenge.verify')));
    await tester.pumpAndSettle();

    expect(result, MfaChallengeResult.signedIn);
    expect(auth.finishCalls, 1);
  });

  testWidgets('a rejected backup code says so and stays', (tester) async {
    final mfa = _FakeMfa()..recovery = MfaRecoveryOutcome.rejected;
    final auth = _FakeAuth();
    await tester.pumpWidget(_host(mfa, auth, (_) {}));
    await _open(tester);

    await tester.tap(find.text('Använd en reservkod'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('mfaChallenge.backupCode')),
      'ABCDE-FGHJK',
    );
    await tester.tap(find.byKey(const ValueKey('mfaChallenge.backupSubmit')));
    await tester.pump();

    expect(
      find.textContaining('Lösenordet eller reservkoden stämmer inte'),
      findsOneWidget,
    );
    expect(auth.signIns, 0);
  });

  testWidgets('a locked recovery says to wait', (tester) async {
    final mfa = _FakeMfa()..recovery = MfaRecoveryOutcome.locked;
    await tester.pumpWidget(_host(mfa, _FakeAuth(), (_) {}));
    await _open(tester);

    await tester.tap(find.text('Använd en reservkod'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('mfaChallenge.backupCode')),
      'ABCDE-FGHJK',
    );
    await tester.tap(find.byKey(const ValueKey('mfaChallenge.backupSubmit')));
    await tester.pump();

    expect(find.textContaining('upp till en timme'), findsOneWidget);
  });

  testWidgets('a backup code signs in again and reports the reset', (
    tester,
  ) async {
    final mfa = _FakeMfa()..recovery = MfaRecoveryOutcome.recovered;
    final auth = _FakeAuth();
    MfaChallengeResult? result;
    await tester.pumpWidget(_host(mfa, auth, (r) => result = r));
    await _open(tester);

    await tester.tap(find.text('Använd en reservkod'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('mfaChallenge.backupCode')),
      'abcde-fghjk',
    );
    await tester.tap(find.byKey(const ValueKey('mfaChallenge.backupSubmit')));
    await tester.pumpAndSettle();

    expect(mfa.recoveredWith, ['abcde-fghjk']);
    expect(auth.signIns, 1, reason: 'a fresh sign-in with the password');
    expect(result, MfaChallengeResult.signedInWithBackupCode);
  });

  group('backup codes before the protection applies', () {
    final codes = List.generate(10, (i) => 'ABCDE-FGH${i}K');

    Widget dialogHost(void Function(bool) onResult) => createLocalizedTestApp(
      child: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async =>
              onResult(await MfaBackupCodesDialog.show(context, codes)),
          child: const Text('open'),
        ),
      ),
    );

    testWidgets('all ten codes are shown and Fortsätt waits for the tick', (
      tester,
    ) async {
      bool? acknowledged;
      await tester.pumpWidget(dialogHost((v) => acknowledged = v));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final list = tester.widget<SelectableText>(
        find.byKey(const ValueKey('mfa.backupCodes.list')),
      );
      expect(list.data!.split('\n'), codes);

      final continueButton = find.byKey(
        const ValueKey('mfa.backupCodes.continue'),
      );
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

      final saved = find.byKey(const ValueKey('mfa.backupCodes.saved'));
      await tester.ensureVisible(saved);
      await tester.pumpAndSettle();
      await tester.tap(saved);
      await tester.pump();
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);

      await tester.ensureVisible(continueButton);
      await tester.pumpAndSettle();
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(acknowledged, isTrue);
    });

    testWidgets('cancelling enrolls nothing', (tester) async {
      bool? acknowledged;
      await tester.pumpWidget(dialogHost((v) => acknowledged = v));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();
      expect(acknowledged, isFalse);
    });

    testWidgets('copied codes are wiped from the clipboard after a minute, '
        'even once the dialog is closed', (tester) async {
      final writes = <String?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            writes.add((call.arguments as Map)['text'] as String?);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(dialogHost((_) {}));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final copy = find.text('Kopiera koderna');
      await tester.ensureVisible(copy);
      await tester.pumpAndSettle();
      await tester.tap(copy);
      await tester.pump();
      expect(writes, [codes.join('\n')]);

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();
      await tester.pump(
        mfaBackupCodesClipboardLifetime - const Duration(seconds: 1),
      );
      expect(writes, hasLength(1), reason: 'still there before the minute');

      await tester.pump(const Duration(seconds: 1));
      expect(writes, [codes.join('\n'), '']);
    });

    testWidgets('copying again restarts the minute', (tester) async {
      final writes = <String?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            writes.add((call.arguments as Map)['text'] as String?);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(dialogHost((_) {}));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final copy = find.text('Kopiera koderna');
      await tester.ensureVisible(copy);
      await tester.pumpAndSettle();

      await tester.tap(copy);
      await tester.pump(const Duration(seconds: 50));
      await tester.tap(copy);
      await tester.pump(const Duration(seconds: 59));
      expect(writes, hasLength(2), reason: 'the first minute no longer counts');

      await tester.pump(const Duration(seconds: 1));
      expect(writes.last, '');
      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();
    });
  });
}
