/// Content module for recipe and menu management services.
/// This module handles all content-related functionality including:
/// - Recipe management and operations
/// - Menu planning and organization
/// - Import functionality (text, photo, URL, archive)
/// - Search and discovery services
/// - Storage and file management
/// - Image handling services
/// Depends on Core Module for authentication and database access.
library;

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

// Core interfaces
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/di/interfaces/service_health.dart';

// Dependencies from Core Module
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';

// Recipe repositories and interfaces
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/collaborative_recipe_repository.dart';

// Storage repository
import 'package:butlery/repositories/interfaces/storage_repository.dart';
import 'package:butlery/repositories/firebase/firebase_storage_repository.dart';

// Social repositories (for UnifiedRecipeService dependencies)
import 'package:butlery/repositories/interfaces/ratings_repository.dart';

// Content services
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/services/share_service.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/backup_service.dart';
import 'package:butlery/services/social_media_extractor.dart';
import 'package:butlery/services/content_detector_service.dart';
import 'package:butlery/services/permission_service.dart';

// Recipe presence repository (for realtime operations)
import 'package:butlery/repositories/firebase/firebase_recipe_presence_repository.dart';

// Import core module for dependencies
import 'package:butlery/core/di/modules/core_module.dart';

// Site parsers for URL import
import 'package:butlery/services/extraction/site_parsers/site_parser_registry.dart';
import 'package:butlery/services/extraction/site_parsers/ica_recipe_parser.dart';
import 'package:butlery/services/extraction/site_parsers/arla_recipe_parser.dart';
import 'package:butlery/services/extraction/site_parsers/koket_recipe_parser.dart';
import 'package:butlery/services/extraction/site_parsers/recept_recipe_parser.dart';

// Import cache services
import 'package:butlery/services/import/cache/url_normalizer.dart';
import 'package:butlery/services/import/cache/content_fingerprint.dart';
import 'package:butlery/services/import/cache/global_recipe_cache.dart';

// Import rate limiting
import 'package:butlery/services/import/import_rate_limiter.dart';

// LLM services
import 'package:butlery/services/llm/llm_service.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';

// YouTube import services
import 'package:butlery/services/import/youtube/youtube_transcript_service.dart';
import 'package:butlery/services/import/youtube/youtube_import_strategy.dart';

// TikTok import pipeline
import 'package:butlery/services/import/pipelines/tiktok_pipeline.dart';

// Recipe parser services (tier-based architecture)
import 'package:butlery/services/parsing/recipe_parser_service.dart';
import 'package:butlery/repositories/site_config_repository.dart';

// Parser feedback loop (correction tracking)
import 'package:butlery/services/parsing/feedback/recipe_diff_calculator.dart';
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';
import 'package:butlery/repositories/parsing_correction_repository.dart';

// Ingredient substitution service
import 'package:butlery/services/ingredient_substitution_service.dart';

// Ingredient registry (enriches static KnownIngredients from Firestore)
import 'package:butlery/services/parsing/ingredient_registry_service.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';

/// Content module providing recipe and menu management services.
/// This module handles all content-related functionality and depends on
/// the Core Module for foundational services. It provides:
/// - Recipe management through UnifiedRecipeService
/// - Import functionality for various content types
/// - Menu planning and organization
/// - Search and discovery capabilities
/// - Storage and file management
/// - Offline content synchronization
class ContentModule implements DIModule {
  @override
  String get name => 'Content';

  @override
  List<Type> get dependencies => [CoreModule]; // Depends on Core Module

  @override
  List<Type> get provides => [
        RecipeRepository,
        UnifiedRecipeService,
        UnifiedMenuService,
        ImportManager,
        MenuService,
        SearchService,
        ShareService,
        StorageRepository,
        StorageService,
        ImagePickerService,
        ImageUploadService,
        OfflineService,
        CollaborativeRecipeRepository,
        BackupService,
        SocialMediaExtractor,
        ExtractionManager,
        ContentDetectorService,
        PermissionService, // Moved from CollaborationModule for proper module ordering
        FirebaseRecipePresenceRepository, // Moved from CollaborationModule for UnifiedRecipeService
        // Import cache services
        UrlNormalizer,
        ContentFingerprint,
        GlobalRecipeCache,
        // Import rate limiting
        ImportRateLimiter,
        // LLM services
        LlmService,
        LlmEnhancementService,
        // YouTube import services
        YouTubeTranscriptService,
        YouTubeImportStrategy,
        // TikTok import pipeline
        TikTokPipeline,
        // Recipe parser services
        SiteConfigRepository,
        RecipeParserService,
        // Parser feedback loop
        ParsedRecipeCache,
        RecipeDiffCalculator,
        ParsingCorrectionRepository,
        // Ingredient substitution
        IngredientSubstitutionService,
      ];

  @override
  int get priority => 10; // After Core Module (priority 1)

  @override
  Future<void> configure(GetIt container) async {
    try {
      // Recipe repository - depends on Auth from Core Module
      container.registerLazySingleton<RecipeRepository>(
        () => FirebaseRecipeRepository(
            authRepository: container<auth.AuthRepository>()),
      );

      // Collaborative recipe repository with permission validation and audit logging
      container.registerLazySingleton<CollaborativeRecipeRepository>(
        () => CollaborativeRecipeRepository(
          authRepository: container<auth.AuthRepository>(),
          auditRepository: container<FirebaseAuditRepository>(),
        ),
      );

      // PermissionService - comprehensive authorization system
      // Moved from CollaborationModule to ContentModule to ensure availability in SocialModule
      // Now includes RecipeRepository for proper ownership validation
      container.registerLazySingleton<PermissionService>(
        () => PermissionService(
          authRepository: container<auth.AuthRepository>(),
          recipeRepository: container<RecipeRepository>(),
        ),
      );

      // FirebaseRecipePresenceRepository - recipe presence tracking for collaborative editing
      // Moved from CollaborationModule to ContentModule for UnifiedRecipeService availability
      container.registerLazySingleton<FirebaseRecipePresenceRepository>(
        () => FirebaseRecipePresenceRepository(
          firestoreRepository: container<FirestoreRepository>(),
        ),
      );

      // UnifiedRecipeService - core recipe management
      // Note: We use lazy singleton to ensure social dependencies are available
      container.registerLazySingleton<UnifiedRecipeService>(
        () => UnifiedRecipeService(
          authRepository:
              container<auth.AuthRepository>() as FirebaseAuthRepository,
          // Include social dependencies if available (from SocialModule)
          ratingsRepository: container.isRegistered<RatingsRepository>()
              ? container<RatingsRepository>()
              : null,
          firestoreRepository: container.isRegistered<FirestoreRepository>()
              ? container<FirestoreRepository>()
              : null,
        ),
      );

      // Import manager for various content import methods
      container.registerLazySingleton<ImportManager>(
        () => ImportManager(container<UnifiedRecipeService>().personal),
      );

      // URL normalizer for consistent cache keys
      container.registerLazySingleton<UrlNormalizer>(
        () => UrlNormalizer(),
      );

      // Content fingerprint generator for recipe deduplication
      container.registerLazySingleton<ContentFingerprint>(
        () => ContentFingerprint(),
      );

      // Global recipe cache for cross-user deduplication
      container.registerLazySingleton<GlobalRecipeCache>(
        () => GlobalRecipeCache(
          firestoreRepository: container<FirestoreRepository>(),
          urlNormalizer: container<UrlNormalizer>(),
          fingerprinter: container<ContentFingerprint>(),
        ),
      );

      // Import rate limiter for cost protection
      container.registerLazySingleton<ImportRateLimiter>(
        () => ImportRateLimiter(
          firestoreRepository: container<FirestoreRepository>(),
          authRepository: container<auth.AuthRepository>(),
        ),
      );

      // LLM service for recipe extraction (Mistral AI via Cloud Functions)
      container.registerLazySingleton<LlmService>(
        () => LlmService(
          rateLimiter: container<ImportRateLimiter>(),
        ),
      );

      // LLM enhancement service for import pipeline integration
      container.registerLazySingleton<LlmEnhancementService>(
        () => LlmEnhancementService(
          llmService: container<LlmService>(),
          rateLimiter: container<ImportRateLimiter>(),
        ),
      );

      // YouTube transcript service for fetching video transcripts
      container.registerLazySingleton<YouTubeTranscriptService>(
        () => YouTubeTranscriptService(
          client: container<http.Client>(),
        ),
      );

      // YouTube import strategy for video recipe imports
      container.registerLazySingleton<YouTubeImportStrategy>(
        () => YouTubeImportStrategy(
          transcriptService: container<YouTubeTranscriptService>(),
          llmService: container<LlmEnhancementService>(),
        ),
      );

      // TikTok import pipeline for TikTok video recipe imports
      container.registerLazySingleton<TikTokPipeline>(
        () => TikTokPipeline(
          llmService: container<LlmEnhancementService>(),
          client: container<http.Client>(),
        ),
      );

      // Site config repository for dynamic CSS selectors from Firestore
      container.registerLazySingleton<SiteConfigRepository>(
        () => SiteConfigRepository(),
      );

      // Recipe parser service with tier-based architecture
      // Provides quality-based parsing with Swedish text support
      container.registerLazySingleton<RecipeParserService>(
        () {
          final authRepo = container<auth.AuthRepository>();
          final userId =
              (authRepo as FirebaseAuthRepository).currentUser?.uid ??
                  'anonymous';
          return RecipeParserService(
            userId: userId,
            siteConfigRepository: container<SiteConfigRepository>(),
            llmService: container<LlmService>(),
          );
        },
      );

      // Ingredient registry — enriches static KnownIngredients from Firestore
      container.registerLazySingleton<IngredientRegistryService>(
        () => IngredientRegistryService(
          ingredientRepository: container<IngredientRepository>(),
        ),
      );

      // Parser feedback loop - tracks user corrections for parser improvement
      // ParsedRecipeCache bridges the gap between import and form editing
      container.registerLazySingleton<ParsedRecipeCache>(
        () => ParsedRecipeCache(),
      );

      container.registerLazySingleton<RecipeDiffCalculator>(
        () => RecipeDiffCalculator(),
      );

      container.registerLazySingleton<ParsingCorrectionRepository>(
        () => ParsingCorrectionRepository(),
      );

      // Ingredient substitution service for replacement suggestions
      container.registerLazySingleton<IngredientSubstitutionService>(
        () => IngredientSubstitutionService(
          firestoreRepository: container<FirestoreRepository>(),
        ),
      );

      // Menu service for meal planning
      container.registerLazySingleton<MenuService>(
        () => MenuService(),
      );

      // Unified menu service for collaborative menu planning
      container.registerLazySingleton<UnifiedMenuService>(
        () => UnifiedMenuService(
          firestoreRepository: container<FirestoreRepository>(),
        ),
      );

      // Search service for content discovery
      container.registerLazySingleton<SearchService>(
        () => SearchService(),
      );

      // Share service for content sharing
      container.registerLazySingleton<ShareService>(
        () => ShareService(),
      );

      // Storage repository for storage operations
      container.registerLazySingleton<StorageRepository>(
        () => FirebaseStorageRepository(
          authRepository: container<auth.AuthRepository>(),
          auditRepository: container<FirebaseAuditRepository>(),
        ),
      );

      // Storage service for file management
      container.registerLazySingleton<StorageService>(
        () => StorageService(repository: container<StorageRepository>()),
      );

      // Image picker service for photo handling
      container.registerLazySingleton<ImagePickerService>(
        () => ImagePickerService(),
      );

      // Image upload service for upload coordination with retry and progress
      container.registerLazySingleton<ImageUploadService>(
        () => ImageUploadService(
          storageService: container<StorageService>(),
        ),
      );

      // Offline service for content synchronization (lazy for faster startup)
      container.registerLazySingleton<OfflineService>(
        () => OfflineService(
          firestoreRepository: container<FirestoreRepository>(),
          authRepository: container<auth.AuthRepository>(),
        ),
      );

      // Backup service for recipe data export and import
      container.registerLazySingleton<BackupService>(
        () => BackupService(),
      );

      // Social media extractor for content extraction from social platforms
      container.registerLazySingleton<SocialMediaExtractor>(
        () => SocialMediaExtractor(),
      );

      // Extraction manager for multi-platform content extraction pipeline
      container.registerLazySingleton<ExtractionManager>(
        () => ExtractionManager(),
      );

      // Content detector for intelligent content type detection and classification
      container.registerLazySingleton<ContentDetectorService>(
        () => ContentDetectorService(),
      );
    } catch (e) {
      throw DIModuleException(
        name,
        'configuration',
        'Failed to configure content services',
        e,
      );
    }
  }

  @override
  Future<void> initialize() async {
    try {
      final container = GetIt.instance;

      // Initialize OfflineService FIRST - other services depend on its database
      final offlineService = container<OfflineService>();
      await offlineService.initialize();

      // Initialize UnifiedRecipeService (depends on OfflineService.database)
      final unifiedRecipeService = container<UnifiedRecipeService>();
      await unifiedRecipeService.initialize();

      // Initialize UnifiedMenuService and RecipeParserService in parallel
      // (both are independent after OfflineService + UnifiedRecipeService)
      await Future.wait([
        container<UnifiedMenuService>().initialize(),
        container<RecipeParserService>().init(),
      ]);

      // Validate other services are accessible (no explicit initialization needed)
      final services = [
        container<MenuService>(),
        container<SearchService>(),
        container<ShareService>(),
        container<StorageService>(),
        container<ImagePickerService>(),
        container<BackupService>(),
      ];

      for (final service in services) {
        // Basic validation - service is accessible
        service.toString();
      }

      // Register site-specific recipe parsers for URL import
      _registerSiteParsers();
    } catch (e) {
      throw DIModuleException(
        name,
        'initialization',
        'Failed to initialize content services',
        e,
      );
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final container = GetIt.instance;

      // Check that all content services are registered and accessible
      final services = <String, dynamic>{
        'RecipeRepository': container<RecipeRepository>(),
        'UnifiedRecipeService': container<UnifiedRecipeService>(),
        'ImportManager': container<ImportManager>(),
        'MenuService': container<MenuService>(),
        'SearchService': container<SearchService>(),
        'ShareService': container<ShareService>(),
        'StorageService': container<StorageService>(),
        'ImagePickerService': container<ImagePickerService>(),
        'OfflineService': container<OfflineService>(),
        'CollaborativeRecipeRepository':
            container<CollaborativeRecipeRepository>(),
        'BackupService': container<BackupService>(),
        'SocialMediaExtractor': container<SocialMediaExtractor>(),
        'ExtractionManager': container<ExtractionManager>(),
        'GlobalRecipeCache': container<GlobalRecipeCache>(),
        'ImportRateLimiter': container<ImportRateLimiter>(),
        'LlmService': container<LlmService>(),
        'LlmEnhancementService': container<LlmEnhancementService>(),
        'YouTubeTranscriptService': container<YouTubeTranscriptService>(),
        'YouTubeImportStrategy': container<YouTubeImportStrategy>(),
        'TikTokPipeline': container<TikTokPipeline>(),
        'SiteConfigRepository': container<SiteConfigRepository>(),
        'RecipeParserService': container<RecipeParserService>(),
        'IngredientSubstitutionService':
            container<IngredientSubstitutionService>(),
      };

      // Perform health checks on services that support it
      for (final entry in services.entries) {
        final service = entry.value;

        if (service is HealthCheckable) {
          final isHealthy = await service.healthCheck();
          if (!isHealthy) {
            return false;
          }
        }

        // Basic validation - service is not null
        if (service == null) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Register site-specific recipe parsers for URL import.
  /// This method registers parsers for Swedish recipe websites (ICA.se, Arla.se, Koket.se, Recept.se)
  /// that are used by UrlImportStrategy to extract recipes with site-specific enhancements.
  void _registerSiteParsers() {
    // Register Swedish recipe site parsers
    SiteParserRegistry.register(IcaRecipeParser());
    SiteParserRegistry.register(ArlaRecipeParser());
    SiteParserRegistry.register(KoketRecipeParser());
    SiteParserRegistry.register(ReceptRecipeParser());
  }
}

/// Content module factory for easy instantiation.
class ContentModuleFactory {
  /// Create a new ContentModule instance.
  static ContentModule create() => ContentModule();

  /// Create ContentModule with custom configuration.
  static ContentModule createWithConfig({
    bool enableOfflineSync = true,
    bool enableCollaboration = true,
    bool enableImport = true,
  }) {
    // For now, return standard module
    // In future, this could customize the module based on config
    return ContentModule();
  }
}
