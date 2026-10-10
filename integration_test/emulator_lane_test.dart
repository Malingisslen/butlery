/// Emulator lane entrypoint (BUT-1730).
///
/// `flutter test` only runs a file on a device when it lives under
/// `integration_test/`, and each file there is a separate app build. Running
/// the emulator-only suites from one file keeps the lane to a single build.
/// A new `emulatorOnlySkip` suite must be added here, or it runs nowhere.
///
/// Run with the Firestore emulator up on the host:
/// `flutter test integration_test/emulator_lane_test.dart -d emulator-5554
///  --dart-define=USE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2`
library;

import 'package:integration_test/integration_test.dart';

import '../test/integration/firebase/repositories/firebase_shared_recipe_repository_integration_test.dart'
    as shared_recipes;
import '../test/integration/firebase/repositories/offline_writes_integration_test.dart'
    as offline_writes;
import '../test/integration/firebase/repositories/shopping_collaborative_mutation_integration_test.dart'
    as shopping_transactions;
import '../test/integration/firebase/services/notification_analytics_integration_test.dart'
    as notification_analytics;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  shopping_transactions.main();
  shared_recipes.main();
  notification_analytics.main();
  offline_writes.main();
}
