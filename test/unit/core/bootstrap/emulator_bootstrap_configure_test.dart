import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/bootstrap/emulator_bootstrap.dart';

// Own file: a registered default app would let the refusal tests in
// emulator_bootstrap_test.dart pass through this guard instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  test('refuses an app not started with EmulatorBootstrap.options()', () {
    expect(
      Firebase.app().options.projectId,
      isNot(EmulatorBootstrap.projectId),
    );
    expect(
      () => EmulatorBootstrap.configure(releaseMode: false, isWeb: true),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('EmulatorBootstrap.options()'),
        ),
      ),
    );
  });
}
