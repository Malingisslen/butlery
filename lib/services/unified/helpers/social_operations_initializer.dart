// lib/services/unified/helpers/social_operations_initializer.dart

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/firebase/firebase_ratings_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';

/// Helper class for initializing SocialRecipeOperations with fallback and retry logic.
/// Handles the complex dependency initialization where repositories might not be immediately available.
class SocialOperationsInitializer {
  /// Try to initialize social operations with available repositories.
  /// Returns initialized operations or null if repositories not available.
  static SocialRecipeOperations? tryInitialize(
    dynamic parentService,
    RatingsRepository? providedRatingsRepo,
    FirestoreRepository? providedFirestoreRepo,
  ) {
    try {
      final ratingsRepo =
          providedRatingsRepo ?? ServiceLocator.tryGet<RatingsRepository>();
      final firestoreRepo =
          providedFirestoreRepo ?? ServiceLocator.tryGet<FirestoreRepository>();

      if (ratingsRepo != null && firestoreRepo != null) {
        AppLogger.info(
            '✅ SocialRecipeOperations initialized with repositories');
        return SocialRecipeOperations(
          parentService,
          ratingsRepository: ratingsRepo,
          firestoreRepository: firestoreRepo,
        );
      }

      AppLogger.warning(
          '⚠️ Repositories not yet available for SocialRecipeOperations');
      return null;
    } catch (e) {
      AppLogger.error('❌ Failed to initialize SocialRecipeOperations: $e');
      return null;
    }
  }

  /// Initialize with fallback repositories to prevent crashes.
  /// Should be followed by retry to get real repositories.
  static SocialRecipeOperations initializeWithFallback(
    dynamic parentService,
    RatingsRepository? providedRatingsRepo,
    FirestoreRepository? providedFirestoreRepo,
    FirebaseAuthRepository authRepository,
  ) {
    AppLogger.warning('⚠️ Creating fallback SocialRecipeOperations');

    final ratingsRepo = providedRatingsRepo ??
        ServiceLocator.tryGet<RatingsRepository>() ??
        FirebaseRatingsRepository(authRepository: authRepository);

    final firestoreRepo = providedFirestoreRepo ??
        ServiceLocator.tryGet<FirestoreRepository>() ??
        FirestoreRepository();

    return SocialRecipeOperations(
      parentService,
      ratingsRepository: ratingsRepo,
      firestoreRepository: firestoreRepo,
    );
  }

  /// Retry initialization with real repositories from service locator.
  /// Returns new operations instance if successful, null otherwise.
  static SocialRecipeOperations? retryWithRealRepositories(
    dynamic parentService,
  ) {
    try {
      final ratingsRepo = ServiceLocator.tryGet<RatingsRepository>();
      final firestoreRepo = ServiceLocator.tryGet<FirestoreRepository>();

      if (ratingsRepo != null && firestoreRepo != null) {
        AppLogger.info(
            '✅ SocialRecipeOperations re-initialized with real repositories');
        return SocialRecipeOperations(
          parentService,
          ratingsRepository: ratingsRepo,
          firestoreRepository: firestoreRepo,
        );
      }

      return null;
    } catch (e) {
      AppLogger.error('❌ Failed to reinitialize SocialRecipeOperations: $e');
      return null;
    }
  }

  /// Schedule retry initialization after delay.
  static void scheduleRetry(
    dynamic parentService,
    void Function(SocialRecipeOperations) onSuccess,
    Duration delay,
  ) {
    Future.delayed(delay, () {
      final operations = retryWithRealRepositories(parentService);
      if (operations != null) {
        onSuccess(operations);
      } else {
        // Retry again with exponential backoff
        scheduleRetry(
            parentService, onSuccess, Duration(seconds: delay.inSeconds * 2));
      }
    });
  }
}
