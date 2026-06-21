/// BUT-1347 (ENG-25): PwaInstallService — session counter, dismiss flag, and
/// no-op stub contract.
///
/// ## What's testable here vs what's web-only
///
/// The production conditional export resolves to [PwaInstallService] in
/// `pwa_install_service_stub.dart` on non-web targets (this test environment).
/// The web implementation lives in `pwa_install_service_web.dart`, which
/// imports `dart:js_interop` and `package:web` — those are only available when
/// compiling for the browser.  The state machine (session counter, dismiss flag,
/// deferred-prompt check) is contained entirely within the web file and cannot
/// be compiled or exercised here.
///
/// Tests in this file cover the **non-web stub contract**, which proves:
/// 1. `canPromptInstall` is always false on non-web (no install banner on mobile).
/// 2. All entry-points (`onInitialize`, `promptInstall`, `dismissInstall`)
///    complete without throwing, even when called in any order.
///
/// The web state-machine invariants (session counter gates at 3, dismiss flag
/// suppresses future prompts) cannot be tested without either:
///   a) Compiling and running under a browser/web target, or
///   b) Extracting the pure logic into a platform-agnostic Dart file and
///      importing it here (a small production refactor, deferred to BUT-1347).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/pwa_install_service.dart';

void main() {
  group('PwaInstallService stub (non-web, BUT-1347 ENG-25)', () {
    late PwaInstallService service;

    setUp(() {
      service = PwaInstallService();
    });

    // Intent: proves canPromptInstall is always false on non-web platforms
    // so that install banners never appear on iOS/Android.
    // Would fail if the stub were accidentally changed to return true.
    test('canPromptInstall is always false on non-web', () {
      expect(service.canPromptInstall, isFalse,
          reason: 'PWA install banner must never surface on non-web platforms');
    });

    // Intent: proves onInitialize() does not throw on non-web, so the service
    // can be registered and initialized safely in DI without platform guards.
    test('onInitialize() completes without throwing on non-web', () async {
      await expectLater(service.initialize(), completes);
    });

    // Intent: proves promptInstall() is a safe no-op on non-web — calling it
    // from UI code that runs cross-platform must never crash.
    test('promptInstall() completes without throwing on non-web', () async {
      await expectLater(service.promptInstall(), completes);
    });

    // Intent: proves dismissInstall() is a safe no-op on non-web — dismiss
    // taps in UI code that runs cross-platform must never crash.
    test('dismissInstall() does not throw on non-web', () {
      expect(() => service.dismissInstall(), returnsNormally);
    });

    // Intent: proves the stub's canPromptInstall remains false even after
    // calling dismissInstall() — state mutation in the stub must not create
    // an inconsistent true reading.
    test('canPromptInstall stays false after dismissInstall() on non-web', () {
      service.dismissInstall();
      expect(service.canPromptInstall, isFalse);
    });
  });
}
