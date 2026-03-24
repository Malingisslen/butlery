// lib/services/unified/helpers/social_operations_initializer.dart

import 'dart:async';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/firebase_ratings_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';
import 'package:butlery/services/unified/operations/modules/recipe_sharing_manager.dart'
    show CreateCollaborativeRecipeFn, CreatePersonalRecipeFn;

/// Context object bundling the dependency getters that SocialRecipeOperations needs.
class SocialOpsContext {
  final String? Function() getCurrentUserId;
  final String? Function() getCurrentUserDisplayName;
  final List<Recipe> Function() getRecipes;
  final Future<bool> Function(Recipe) updateRecipe;
  final CreateCollaborativeRecipeFn createCollaborativeRecipe;
  final CreatePersonalRecipeFn createPersonalRecipe;

  const SocialOpsContext({
    required this.getCurrentUserId,
    required this.getCurrentUserDisplayName,
    required this.getRecipes,
    required this.updateRecipe,
    required this.createCollaborativeRecipe,
    required this.createPersonalRecipe,
  });
}

/// Helper class for initializing SocialRecipeOperations with fallback and retry logic.
/// Handles the complex dependency initialization where repositories might not be immediately available.
class SocialOperationsInitializer {
  /// Try to initialize social operations with available repositories.
  /// Returns initialized operations or null if repositories not available.
  static SocialRecipeOperations? tryInitialize(
    SocialOpsContext context,
    RatingsRepository? providedRatingsRepo,
    FirestoreRepository? providedFirestoreRepo,
  ) {
    try {
      final ratingsRepo =
          providedRatingsRepo ?? ServiceLocator.tryGet<RatingsRepository>();
      final firestoreRepo =
          providedFirestoreRepo ?? ServiceLocator.tryGet<FirestoreRepository>();

      if (ratingsRepo != null && firestoreRepo != null) {
        final ctx = context;
        AppLogger.info('SocialRecipeOperations initialized with repositories');
        return SocialRecipeOperations(
          getCurrentUserId: ctx.getCurrentUserId,
          getCurrentUserDisplayName: ctx.getCurrentUserDisplayName,
          getRecipes: ctx.getRecipes,
          updateRecipe: ctx.updateRecipe,
          createCollaborativeRecipe: ctx.createCollaborativeRecipe,
          createPersonalRecipe: ctx.createPersonalRecipe,
          ratingsRepository: ratingsRepo,
          firestoreRepository: firestoreRepo,
        );
      }

      AppLogger.warning(
          'Repositories not yet available for SocialRecipeOperations');
      return null;
    } catch (e) {
      AppLogger.error('Failed to initialize SocialRecipeOperations: $e');
      return null;
    }
  }

  /// Initialize with fallback repositories to prevent crashes.
  /// Should be followed by retry to get real repositories.
  static SocialRecipeOperations initializeWithFallback(
    SocialOpsContext context,
    RatingsRepository? providedRatingsRepo,
    FirestoreRepository? providedFirestoreRepo,
    FirebaseAuthRepository authRepository,
  ) {
    AppLogger.warning('Creating fallback SocialRecipeOperations');

    final ratingsRepo = providedRatingsRepo ??
        ServiceLocator.tryGet<RatingsRepository>() ??
        FirebaseRatingsRepository(authRepository: authRepository);

    final firestoreRepo = providedFirestoreRepo ??
        ServiceLocator.tryGet<FirestoreRepository>() ??
        FirestoreRepository();

    final ctx = context;
    return SocialRecipeOperations(
      getCurrentUserId: ctx.getCurrentUserId,
      getCurrentUserDisplayName: ctx.getCurrentUserDisplayName,
      getRecipes: ctx.getRecipes,
      updateRecipe: ctx.updateRecipe,
      createCollaborativeRecipe: ctx.createCollaborativeRecipe,
      createPersonalRecipe: ctx.createPersonalRecipe,
      ratingsRepository: ratingsRepo,
      firestoreRepository: firestoreRepo,
    );
  }

  /// Retry initialization with real repositories from service locator.
  /// Returns new operations instance if successful, null otherwise.
  static SocialRecipeOperations? retryWithRealRepositories(
    SocialOpsContext context,
  ) {
    try {
      final ratingsRepo = ServiceLocator.tryGet<RatingsRepository>();
      final firestoreRepo = ServiceLocator.tryGet<FirestoreRepository>();

      if (ratingsRepo != null && firestoreRepo != null) {
        final ctx = context;
        AppLogger.info(
            'SocialRecipeOperations re-initialized with real repositories');
        return SocialRecipeOperations(
          getCurrentUserId: ctx.getCurrentUserId,
          getCurrentUserDisplayName: ctx.getCurrentUserDisplayName,
          getRecipes: ctx.getRecipes,
          updateRecipe: ctx.updateRecipe,
          createCollaborativeRecipe: ctx.createCollaborativeRecipe,
          createPersonalRecipe: ctx.createPersonalRecipe,
          ratingsRepository: ratingsRepo,
          firestoreRepository: firestoreRepo,
        );
      }

      return null;
    } catch (e) {
      AppLogger.error('Failed to reinitialize SocialRecipeOperations: $e');
      return null;
    }
  }

  /// Max retry attempts to prevent unbounded recursion.
  static const _maxRetries = 5;

  /// Schedule retry initialization after delay.
  /// Returns a [Timer] so callers can cancel on dispose.
  /// [onTimerCreated] is called for each subsequent retry timer so
  /// the caller can track the latest pending timer for cancellation.
  static Timer? scheduleRetry(
    SocialOpsContext context,
    void Function(SocialRecipeOperations) onSuccess,
    Duration delay, {
    int attempt = 0,
    void Function(Timer)? onTimerCreated,
  }) {
    if (attempt >= _maxRetries) {
      AppLogger.error(
          'Max social init retries ($_maxRetries) reached, giving up');
      return null;
    }

    final timer = Timer(delay, () {
      final operations = retryWithRealRepositories(context);
      if (operations != null) {
        onSuccess(operations);
      } else {
        // Retry with exponential backoff using Duration multiplication
        final nextTimer = scheduleRetry(context, onSuccess, delay * 2,
            attempt: attempt + 1, onTimerCreated: onTimerCreated);
        if (nextTimer != null) {
          onTimerCreated?.call(nextTimer);
        }
      }
    });
    return timer;
  }
}
