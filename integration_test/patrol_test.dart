// Patrol MVP — BUT-395
//
// Intent: prove end-to-end that Patrol can boot the real Butlery app against
// the Firebase emulator suite, render the Swedish auth screen, and interact
// with the registration form fields. This is deliberately narrow — a
// proof-of-life journey, not comprehensive coverage.
//
// Why narrow: the production ButleryApp runs a multi-stage bootstrap
// (ApplicationBootstrap + 10 DI modules + 5 bootstrap stages + AuthWrapper
// with email-verification gate and onboarding gate + post-frame callbacks).
// Getting past `pumpAndSettle` to a fully-stable tree in a real device
// environment is the hard part of any first Patrol run. The journey below
// is the narrowest proof that a user can see the login form and type into
// it against the real widget tree + real Firebase emulators.
//
// Follow-up journeys (register → home → create recipe → shopping list) are
// intentionally out of scope for this ticket and will be added in separate
// BUT-39x tickets, one per journey, once the emulator lane is shown to be
// green and stable on CI.
//
// Run locally:
//   1. Boot Android emulator / iOS simulator.
//   2. `firebase emulators:start --only auth,firestore,storage`
//   3. On Android, forward emulator ports:
//      `adb reverse tcp:8080 tcp:8080`
//      `adb reverse tcp:9099 tcp:9099`
//      `adb reverse tcp:9199 tcp:9199`
//   4. `patrol test --target integration_test/patrol_test.dart`

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Production bootstrap pieces — we re-run the same bootstrap the real app
// uses, minus the Crashlytics / AppCheck / consent surface that's brittle
// in a test environment.
import 'package:butlery/main.dart' show ButleryApp;
import 'package:butlery/firebase_options.dart';
import 'package:butlery/core/bootstrap/application_bootstrap.dart';
import 'package:butlery/core/bootstrap/stages/platform_stage.dart';
import 'package:butlery/core/bootstrap/stages/core_stage.dart';
import 'package:butlery/core/bootstrap/stages/content_stage.dart';
import 'package:butlery/core/bootstrap/stages/social_stage.dart';
import 'package:butlery/core/bootstrap/stages/ui_stage.dart';
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/core/di/modules/social_module.dart';
import 'package:butlery/core/di/modules/messaging_module.dart';
import 'package:butlery/core/di/modules/collaboration_module.dart';
import 'package:butlery/core/di/modules/performance_module.dart';
import 'package:butlery/core/di/modules/ui_module.dart';

/// Boots Firebase + all Firebase clients against the local emulator suite,
/// then initializes the same DI container and bootstrap stages the
/// production app uses, then calls runApp(ButleryApp).
///
/// Mirrors `test/e2e/main_e2e_emulator.dart` but lives inside
/// `integration_test/` because the `test/` tree isn't part of Patrol's
/// instrumentation build surface.
///
/// Hosts:
///   - Android emulator: use `adb reverse tcp:<port> tcp:<port>` on the
///     host so `localhost` inside the emulator points at the host's
///     Firebase emulator. The CI workflow does this; see the file-header
///     comment for local-run instructions.
///   - iOS simulator: shares the host loopback, `localhost` already works.
Future<void> _bootAppWithEmulators() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  const host = 'localhost';
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  await FirebaseStorage.instance.useStorageEmulator(host, 9199);

  // Same module + stage set as production main.dart, minus the modules
  // whose wiring isn't exercised by this MVP (search/tagging/pantry).
  // If a follow-up Patrol journey needs those modules, add them here and
  // keep the set in sync with `lib/main.dart`.
  await ApplicationBootstrap.initialize(
    modules: [
      CoreModule(),
      ContentModule(),
      SocialModule(),
      MessagingModule(),
      CollaborationModule(),
      PerformanceModule(),
      UIModule(),
    ],
    stages: [
      PlatformStage(),
      CoreStage(),
      ContentStage(),
      SocialStage(),
      UIStage(),
    ],
  );

  runApp(const ButleryApp());
}

void main() {
  patrolTest(
    'auth screen renders against Firebase emulator and accepts input',
    ($) async {
      await _bootAppWithEmulators();
      await $.pumpAndSettle(timeout: const Duration(seconds: 30));

      // Assert we landed on the Swedish auth screen. "butlery" is the
      // brand wordmark in the green header; it's stable across auth
      // login/register modes. If this fails, the app crashed or the user
      // was unexpectedly signed in from a previous run.
      await $(const Key('email_field')).waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );
      expect($(find.text('butlery')), findsOneWidget);

      // Enter Register mode. The auth view starts in Login mode; the
      // mode-toggle button text reads 'Skapa konto' (Swedish for
      // "Create account") in Login mode.
      //
      // We tap the bottom OutlinedButton toggle rather than any text
      // matching 'Skapa konto' to avoid ambiguity with the title / submit
      // button states across modes.
      final toggleButton = find.descendant(
        of: find.byType(OutlinedButton),
        matching: find.text('Skapa konto'),
      );
      expect(toggleButton, findsOneWidget,
          reason: 'Expected Login-mode toggle button reading "Skapa konto"');
      await $(toggleButton).tap();
      await $.pumpAndSettle();

      // In Register mode, the name field appears.
      await $(const Key('name_field')).waitUntilVisible();

      // Type into the three fields. This exercises the real
      // TextEditingController wiring on AuthView + the real AutofillGroup.
      // Use a unique email per run so the Firebase Auth emulator doesn't
      // reject a re-run with "email-already-in-use".
      final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
      await $(const Key('name_field')).enterText('Patrol Tester');
      await $(const Key('email_field'))
          .enterText('patrol+$uniqueSuffix@butlery.test');
      await $(const Key('password_field')).enterText('PatrolTest123!');

      // Assert the entered text is visible. We don't submit — that
      // would exercise Firebase Auth + the AuthWrapper's post-login
      // navigation chain, which is the next ticket's journey and needs
      // its own stabilisation work. The intent of THIS test is only:
      // "the app boots, the auth screen renders, fields accept input."
      expect($(find.text('Patrol Tester')), findsOneWidget);
      expect(
        $(find.textContaining('patrol+$uniqueSuffix')),
        findsOneWidget,
      );

      // Submit button is present — cheapest possible regression check
      // that StyledButton.primary still renders with the expected key.
      expect($(const Key('submit_button')), findsOneWidget);
    },
  );
}
