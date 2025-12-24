import 'package:mocktail/mocktail.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';

/// Mock implementation of AnalyticsRepository for testing
///
/// This mock follows the architecture pattern: NO concrete implementations.
/// All methods are handled by Mock to allow proper stubbing with when().
/// Only configuration state and getters are implemented.
class MockAnalyticsRepository extends Mock implements AnalyticsRepository {
  // Configuration state only
  dynamic _observer;

  // Configuration methods only
  void setObserver(dynamic observer) {
    _observer = observer;
  }

  // Getters return configured state
  @override
  dynamic get observer => _observer;

  // Reset method for test cleanup
  void resetForTesting() {
    _observer = null;
  }

  // NO method implementations - Mock handles all these methods:
  // - initialize()
  // - logEvent()
  // - logLogin()
  // - logSignUp()
  // - logLogout()
  // - setUserProperty()
  // - setAnalyticsCollectionEnabled()
  // - logImportStarted()
  // - logImportSuccess()
  // - logExtractionError()
  // - logManualCopyFallback()
  // - logRecipeCreated()
  // - logRecipeShared()
  // - logRecipeCooked()
  // - logMenuGenerated()
  // - logRecipeDeleted()
  // - logAccountDeleted()
  // - setUserProperties()
  //
  // These can all be stubbed with when() in tests
}
