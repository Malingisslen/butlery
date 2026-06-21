/// Content services initialization stage.
/// Handles initialization of content-related services including recipe
/// management, menu planning, import functionality, and search services.
library;

import 'package:butlery/core/bootstrap/stages/bootstrap_stage.dart';
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/core/di/modules/tagging_module.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/parsing/ingredient_registry_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

/// Content stage for recipe and menu service initialization.
/// This stage ensures that all content-related services are properly
/// initialized and ready for use. It handles:
/// - Recipe management services
/// - Menu planning and organization
/// - Import functionality (text, photo, URL, archive)
/// - Search and discovery services
/// - Storage and file management
/// - Offline content synchronization
/// - Automatic retagging of failed recipes
class ContentStage implements BootstrapStage {
  /// BUT-431 cold-start: when true, [execute] skips the Firestore ingredient
  /// enrich so it can run after the first frame. The registry already falls
  /// back to static [KnownIngredients] until enrichment lands, so deferring
  /// only delays enrichment — it never throws. Defaults to false so the admin
  /// entry point keeps the original eager behavior.
  static bool deferIngredientEnrich = false;

  /// Retagging scheduler instance - kept alive for periodic checks.
  RetaggingScheduler? _retaggingScheduler;

  @override
  String get name => 'Content';

  @override
  List<Type> get requiredModules => [CoreModule, ContentModule];

  @override
  Duration get timeout => const Duration(seconds: 45);

  @override
  int get priority => 20; // After Core stage

  @override
  bool get isOptional => false; // Critical for app functionality

  @override
  Future<void> execute() async {
    try {
      // Content module initialization is handled by the DI container
      // UnifiedRecipeService.initialize() is called during ContentModule.initialize()
      // No duplicate initialization needed here - the early return guard would prevent it anyway

      // Enrich ingredient registry from Firestore (Firebase = source of truth).
      // BUT-431: when deferral is on, main() runs this after the first frame
      // via [enrichIngredientRegistry]; the registry falls back to static
      // KnownIngredients until then, so parsing still works in the meantime.
      if (!deferIngredientEnrich) {
        await enrichIngredientRegistry();
      }

      // CRIT-5 FIX: Initialize RetaggingScheduler for automatic retry of failed tagging
      await _initializeRetaggingScheduler();
    } catch (e) {
      throw BootstrapException(
        name,
        'execution',
        'Content services initialization failed',
        e,
      );
    }
  }

  /// Loads Firestore ingredients into the registry so CRF and normalizer
  /// can use Firebase as the source of truth for ingredient recognition.
  /// Static + public so the deferred post-frame path (BUT-431) can invoke the
  /// exact same work. Idempotent: [IngredientRegistryService.enrichFromFirestore]
  /// guards on its internal enriched flag.
  static Future<void> enrichIngredientRegistry() async {
    try {
      final registry = ServiceLocator.tryGet<IngredientRegistryService>();
      if (registry != null) {
        await registry.enrichFromFirestore();
      }
    } catch (e) {
      // Non-critical: falls back to static KnownIngredients
      AppLogger.warning('Failed to enrich ingredient registry: $e');
    }
  }

  /// Initializes the RetaggingScheduler to automatically retry failed recipe tagging.
  ///
  /// The scheduler runs 30 seconds after startup and then every 24 hours,
  /// processing up to 100 recipes per session in batches of 10.
  Future<void> _initializeRetaggingScheduler() async {
    try {
      // TaggingService and UnifiedRecipeService are user-scoped.
      // On cold start (no persisted session) they won't be available yet.
      final taggingService = ServiceLocator.tryGet<TaggingService>();
      final recipeService = ServiceLocator.tryGet<UnifiedRecipeService>();
      if (taggingService == null || recipeService == null) {
        AppLogger.info('📅 RetaggingScheduler skipped (no user session yet)');
        return;
      }

      _retaggingScheduler = RetaggingScheduler(
        taggingService: taggingService,
        getRecipes: () async {
          // Get all user's personal recipes for retagging check
          // Use the synchronous getter which returns cached recipes
          return recipeService.personalRecipes;
        },
        saveRecipe: (recipe) async {
          // Update the recipe with new tags
          await recipeService.personal.updateRecipe(recipe);
        },
      );

      // Schedule initial retagging check (runs after 30 second delay)
      // Fire-and-forget - don't await to avoid blocking startup
      _retaggingScheduler!.scheduleRetaggingCheck();

      // Start periodic checks every 24 hours
      _retaggingScheduler!.startPeriodicChecks(intervalHours: 24);

      AppLogger.info('📅 RetaggingScheduler initialized and scheduled');
    } catch (e) {
      // Log but don't fail startup - retagging is not critical
      AppLogger.warning('⚠️ Failed to initialize RetaggingScheduler: $e');
    }
  }

  @override
  Future<bool> validate() async {
    try {
      // Validation is primarily handled by the DI container's health checks
      // This stage confirms content services are ready

      return true;
    } catch (e) {
      return false;
    }
  }
}
