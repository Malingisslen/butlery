import 'package:butlery/services/pwa/pwa_install_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PwaInstallGate.shouldPrompt (pure rule)', () {
    test('no prompt before the 3rd session even with a deferred prompt', () {
      for (var session = 0; session < PwaInstallGate.minSessions; session++) {
        expect(
          PwaInstallGate.shouldPrompt(
            hasDeferredPrompt: true,
            sessionCount: session,
            dismissed: false,
          ),
          isFalse,
          reason: 'session $session is below minSessions',
        );
      }
    });

    test('prompts on the 3rd session only when a deferred prompt exists', () {
      expect(
        PwaInstallGate.shouldPrompt(
          hasDeferredPrompt: true,
          sessionCount: PwaInstallGate.minSessions,
          dismissed: false,
        ),
        isTrue,
      );
      expect(
        PwaInstallGate.shouldPrompt(
          hasDeferredPrompt: false,
          sessionCount: PwaInstallGate.minSessions,
          dismissed: false,
        ),
        isFalse,
        reason: 'no deferred prompt available means nothing to show',
      );
    });

    test('keeps prompting after the 3rd session when conditions hold', () {
      expect(
        PwaInstallGate.shouldPrompt(
          hasDeferredPrompt: true,
          sessionCount: PwaInstallGate.minSessions + 5,
          dismissed: false,
        ),
        isTrue,
      );
    });

    test('once dismissed, never prompts again regardless of session/deferred',
        () {
      expect(
        PwaInstallGate.shouldPrompt(
          hasDeferredPrompt: true,
          sessionCount: PwaInstallGate.minSessions + 10,
          dismissed: true,
        ),
        isFalse,
      );
    });
  });

  group('PwaInstallGate stateful flow', () {
    test('counts sessions and prompts on the 3rd, not before', () {
      final gate = PwaInstallGate();
      gate.restore(sessionCount: 0, dismissed: false);

      gate.incrementSession(); // session 1
      expect(gate.canPrompt(hasDeferredPrompt: true), isFalse);

      gate.incrementSession(); // session 2
      expect(gate.canPrompt(hasDeferredPrompt: true), isFalse);

      gate.incrementSession(); // session 3
      expect(gate.canPrompt(hasDeferredPrompt: true), isTrue);
    });

    test('a missing deferred prompt suppresses the prompt on the 3rd session',
        () {
      final gate = PwaInstallGate();
      gate.restore(sessionCount: 2, dismissed: false);
      gate.incrementSession(); // session 3
      expect(gate.canPrompt(hasDeferredPrompt: false), isFalse);
      expect(gate.canPrompt(hasDeferredPrompt: true), isTrue);
    });

    test('restore reports dismissed and markDismissed sticks forever', () {
      final gate = PwaInstallGate();
      final alreadyDismissed = gate.restore(sessionCount: 10, dismissed: true);
      expect(alreadyDismissed, isTrue);
      expect(gate.canPrompt(hasDeferredPrompt: true), isFalse);

      final fresh = PwaInstallGate();
      fresh.restore(sessionCount: PwaInstallGate.minSessions, dismissed: false);
      expect(fresh.canPrompt(hasDeferredPrompt: true), isTrue);
      fresh.markDismissed();
      expect(fresh.canPrompt(hasDeferredPrompt: true), isFalse);
    });
  });
}
