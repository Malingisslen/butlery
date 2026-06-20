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

// Cook-event log (BUT-838)
import 'package:butlery/repositories/interfaces/cook_event_repository.dart';
import 'package:butlery/repositories/firebase/firebase_cook_event_repository.dart';

// Storage repository
import 'package:butlery/repositories/interfaces/storage_repository.dart';
import 'package:butlery/repositories/firebase/firebase_storage_repository.dart';

// Social repositories (for UnifiedRecipeService dependencies)
import 'package:butlery/repositories/interfaces/ratings_repository.dart';

// Content services
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/services/recipe/recipe_cooking_service.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/menu/parser/code_lexicon_provider.dart';
import 'package:butlery/services/menu/parser/composite_lexicon_provider.dart';
import 'package:butlery/services/menu/parser/firestore_lexicon_provider.dart';
import 'package:butlery/services/menu/parser/lexicon_provider.dart';
import 'package:butlery/repositories/firebase/firebase_menu_lexicon_repository.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/menu/group_weekly_menu_plan_service.dart';
import 'package:butlery/services/unified/operations/realtime_group_menu/realtime_group_menu_module.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/repositories/firebase/firebase_weekly_menu_plan_repository.dart';
import 'package:butlery/repositories/interfaces/group_weekly_menu_plan_repository.dart';
import 'package:butlery/repositories/firebase/firebase_group_weekly_menu_plan_repository.dart';
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
import 'package:butlery/core/di/modules/tagging_module.dart';

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

// Consent service (for AI processing consent gate)
import 'package:butlery/services/account/consent_service.dart';

// LLM services
import 'package:butlery/services/llm/llm_service.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';

// YouTube import services
import 'package:butlery/services/import/youtube/youtube_transcript_service.dart';
import 'package:butlery/services/import/youtube/youtube_import_strategy.dart';

// TikTok import pipeline
import 'package:butlery/services/import/pipelines/tiktok_pipeline.dart';
import 'package:butlery/services/import/pipelines/instagram_pipeline.dart';

// Recipe parser services (tier-based architecture)
import 'package:butlery/services/parsing/recipe_parser_service.dart';
import 'package:butlery/repositories/site_config_repository.dart';
import 'package:butlery/repositories/engagement_repository.dart';
import 'package:butlery/repositories/recipe_stats_repository.dart';
import 'package:butlery/repositories/ops_log_repository.dart';
import 'package:butlery/repositories/parse_events_repository.dart';
import 'package:butlery/services/admin/metrics_assembler.dart';

// Parser feedback loop (correction tracking + remote weight updates)
import 'package:butlery/services/parsing/feedback/recipe_diff_calculator.dart';
import 'package:butlery/services/parsing/feedback/parse_correction_uploader.dart';
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';
import 'package:butlery/services/parsing/crf/remote_weight_loader.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
import 'package:butlery/repositories/parsing_correction_repository.dart';

// On-device BERT NER for ingredient parsing
import 'package:firebase_storage/firebase_storage.dart';
import 'package:butlery/services/parsing/ner/onnx_ner_service.dart';
import 'package:butlery/services/parsing/ner/ner_model_manager.dart';
import 'package:butlery/services/parsing/ner/neural_ingredient_parser.dart';

// On-device neural line classifier
import 'package:butlery/services/parsing/line_classifier/line_classifier_model_manager.dart';
import 'package:butlery/services/parsing/line_classifier/onnx_line_classifier_service.dart';
import 'package:butlery/services/parsing/line_classifier/neural_line_classifier.dart';

// Cooking-mode substitution suggestions (canonical-ID based, BUT-202)
import 'package:butlery/services/cooking/step_timer_service.dart';
import 'package:butlery/services/notifications/local_timer_notification_service.dart';
import 'package:butlery/services/cooking/substitution_suggestion_service.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';

// Ingredient registry (enriches static KnownIngredients from Firestore)
import 'package:butlery/services/parsing/ingredient_registry_service.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';

// BUT-409: seasonal hero (assets-backed, no Firebase — app-scoped)
import 'package:butlery/services/seasonal/seasonal_hero_service.dart';

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
  List<Type> get dependencies => [
        CoreModule,
        TaggingModule
      ]; // Depends on Core Module + TaggingModule (IngredientRepository)

  @override
  List<Type> get provides => [
        RecipeRepository,
        CookEventRepository,
        UnifiedRecipeService,
        UnifiedMenuService,
        ImportManager,
        RecipeCookingService,
        MenuService,
        WeeklyMenuPlanRepository,
        WeeklyMenuPlanService,
        GroupWeeklyMenuPlanRepository,
        GroupWeeklyMenuPlanService,
        RealtimeGroupMenuModule,
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
        InstagramPipeline,
        // Recipe parser services
        SiteConfigRepository,
        RecipeParserService,
        // Parser feedback loop + active learning
        ParsedRecipeCache,
        RecipeDiffCalculator,
        ParsingCorrectionRepository,
        ParseCorrectionUploader,
        RemoteWeightLoader,
        IngredientParsingStrategy,
        // On-device BERT NER
        NerModelManager,
        OnnxNerService,
        NeuralIngredientParser,
        // On-device neural line classifier
        LineClassifierModelManager,
        OnnxLineClassifierService,
        NeuralLineClassifier,
        // Cooking-mode substitution suggestions (BUT-202)
        SubstitutionSuggestionService,
        // Cooking-mode step timer (BUT-406) + backgrounded-expiry alert (BUT-1242)
        StepTimerService,
        LocalTimerNotificationService,
        // Menu lexicon overlay (BUT-370)
        FirebaseMenuLexiconRepository,
        // Ingredient registry (enriches static KnownIngredients from Firestore)
        IngredientRegistryService,
        // Firebase Storage instance for model loaders
        FirebaseStorage,
        // BUT-409: seasonal hero header data service
        SeasonalHeroService,
      ];

  @override
  int get priority => 10; // After Core Module (priority 1)

  @override
  Future<void> configureUserScope(GetIt container) async {
    final app = GetIt.instance;

    container.registerLazySingleton<UnifiedRecipeService>(
      () => UnifiedRecipeService(
        authRepository: app<auth.AuthRepository>() as FirebaseAuthRepository,
        ratingsRepository: app.isRegistered<RatingsRepository>()
            ? app<RatingsRepository>()
            : null,
        firestoreRepository: app.isRegistered<FirestoreRepository>()
            ? app<FirestoreRepository>()
            : null,
      ),
      dispose: (s) => s.dispose(),
    );

    container.registerLazySingleton<ImportManager>(
      () => ImportManager(container<UnifiedRecipeService>().personal),
    );

    // RecipeCookingService — owns atomic cook-event logging (event doc +
    // cook-count increment in one batch, BUT-838) and per-session dedup.
    // Depends only on CookEventRepository so it stays testable without a
    // full UnifiedRecipeService graph.
    container.registerLazySingleton<RecipeCookingService>(
      () => RecipeCookingService(
        cookEventRepository: app<CookEventRepository>(),
      ),
      dispose: (s) => s.dispose(),
    );

    container.registerLazySingleton<UnifiedMenuService>(
      () => UnifiedMenuService(
        firestoreRepository: app<FirestoreRepository>(),
      ),
      dispose: (s) => s.dispose(),
    );

    container.registerLazySingleton<OfflineService>(
      () => OfflineService(
        firestoreRepository: app<FirestoreRepository>(),
        authRepository: app<auth.AuthRepository>(),
      ),
      dispose: (s) => s.resetForLogout(),
    );

    // LLM service for recipe extraction (depends on ConsentService — user-scoped)
    container.registerLazySingleton<LlmService>(
      () => LlmService(
        rateLimiter: app<ImportRateLimiter>(),
        consentService: container<ConsentService>(),
      ),
    );

    // LLM enhancement service for import pipeline integration
    container.registerLazySingleton<LlmEnhancementService>(
      () => LlmEnhancementService(
        llmService: container<LlmService>(),
        rateLimiter: app<ImportRateLimiter>(),
      ),
    );

    // YouTube import strategy for video recipe imports
    container.registerLazySingleton<YouTubeImportStrategy>(
      () => YouTubeImportStrategy(
        transcriptService: app<YouTubeTranscriptService>(),
        llmService: container<LlmEnhancementService>(),
      ),
    );

    // TikTok import pipeline for TikTok video recipe imports
    container.registerLazySingleton<TikTokPipeline>(
      () => TikTokPipeline(
        llmService: container<LlmEnhancementService>(),
        client: app<http.Client>(),
      ),
    );

    container.registerLazySingleton<InstagramPipeline>(
      () => InstagramPipeline(
        llmService: container<LlmEnhancementService>(),
      ),
    );

    // BUT-202: substitution suggestions — user-scoped because it depends on
    // IngredientLookupService (which is user-scoped via TaggingModule for the
    // UserIngredientRepository override).
    container.registerLazySingleton<SubstitutionSuggestionService>(
      () => SubstitutionSuggestionService(
        firestoreRepository: app<FirestoreRepository>(),
        lookupService: app<IngredientLookupService>(),
      ),
    );

    // BUT-1242: schedules OS-level local notifications for backgrounded timer
    // expiry. Local-only, no Firestore/FCM.
    container.registerLazySingleton<LocalTimerNotificationService>(
      () => LocalTimerNotificationService(),
    );

    // BUT-406: in-memory cooking-mode step timer. Local-only, no repository
    // deps — registered alongside other cooking services for discoverability.
    // BUT-1242: now multi-timer + backgrounded-expiry notifications.
    container.registerLazySingleton<StepTimerService>(
      () => StepTimerService(
        notifications: app<LocalTimerNotificationService>(),
      ),
    );

    // Recipe parser service — depends on LlmService (user-scoped)
    container.registerLazySingleton<RecipeParserService>(
      () {
        final authRepo = app<auth.AuthRepository>() as FirebaseAuthRepository;
        return RecipeParserService(
          getCurrentUserId: () => authRepo.currentUser?.uid ?? 'anonymous',
          siteConfigRepository: app<SiteConfigRepository>(),
          llmService: container<LlmService>(),
          ingredientStrategy: app<IngredientParsingStrategy>(),
          neuralLineClassifier: app<NeuralLineClassifier>(),
        );
      },
      dispose: (s) => s.close(),
    );
  }

  @override
  Future<void> configure(GetIt container) async {
    try {
      // Recipe repository - depends on Auth from Core Module
      container.registerLazySingleton<RecipeRepository>(
        () => FirebaseRecipeRepository(
            authRepository: container<auth.AuthRepository>()),
      );

      // BUT-838: per-user cook-event log. Needs the concrete recipe
      // repository so the event doc and the recipe's cookCount bump can
      // commit in one atomic WriteBatch (batch-additive increment helper).
      container.registerLazySingleton<CookEventRepository>(
        () => FirebaseCookEventRepository(
          authRepository: container<auth.AuthRepository>(),
          recipeRepository:
              container<RecipeRepository>() as FirebaseRecipeRepository,
        ),
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

      // UnifiedRecipeService, ImportManager, UnifiedMenuService, OfflineService:
      // registered in configureUserScope

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

      // LlmService, LlmEnhancementService, YouTubeImportStrategy,
      // TikTokPipeline, InstagramPipeline: registered in configureUserScope
      // (depend on ConsentService which is user-scoped)

      // YouTube transcript service for fetching video transcripts
      container.registerLazySingleton<YouTubeTranscriptService>(
        () => YouTubeTranscriptService(
          client: container<http.Client>(),
        ),
      );

      // Site config repository for dynamic CSS selectors from Firestore
      container.registerLazySingleton<SiteConfigRepository>(
        () => SiteConfigRepository(),
      );

      // Admin-dashboard read-only repositories (engagement, ops log, recipe
      // stats). Admin-only aggregate reads, gated by isAdmin() in the rules.
      container.registerLazySingleton<EngagementRepository>(
        () => EngagementRepository(),
      );
      container.registerLazySingleton<RecipeStatsRepository>(
        () => RecipeStatsRepository(),
      );
      container.registerLazySingleton<OpsLogRepository>(
        () => OpsLogRepository(),
      );
      container.registerLazySingleton<ParseEventsRepository>(
        () => ParseEventsRepository(),
      );

      // Metric-registry assembler: fetches admin data per category (lazy) and
      // runs the pure resolvers. Fetchers wrap the existing admin repositories.
      container.registerLazySingleton<MetricsAssembler>(
        () => MetricsAssembler([
          RecipeCategoryFetcher(container<RecipeStatsRepository>()),
          ImportCategoryFetcher(container<SiteConfigRepository>()),
          EngagementCategoryFetcher(container<EngagementRepository>()),
        ]),
      );

      // Firebase Storage instance for model loaders
      container.registerLazySingleton<FirebaseStorage>(
        () => FirebaseStorage.instance,
      );

      // Remote CRF weight loader for active learning updates
      container.registerLazySingleton<RemoteWeightLoader>(
        () => RemoteWeightLoader(storage: container<FirebaseStorage>()),
      );

      // On-device BERT NER model manager + inference service
      container.registerLazySingleton<NerModelManager>(
        () => NerModelManager(storage: container<FirebaseStorage>()),
      );
      container.registerLazySingleton<OnnxNerService>(
        () => OnnxNerService(),
        dispose: (s) => s.dispose(),
      );
      container.registerLazySingleton<NeuralIngredientParser>(
        () => NeuralIngredientParser(
          nerService: container<OnnxNerService>(),
          modelManager: container<NerModelManager>(),
        ),
      );

      // On-device neural line classifier (same pattern as NER)
      container.registerLazySingleton<LineClassifierModelManager>(
        () => LineClassifierModelManager(storage: container<FirebaseStorage>()),
      );
      container.registerLazySingleton<OnnxLineClassifierService>(
        () => OnnxLineClassifierService(),
        dispose: (s) => s.dispose(),
      );
      container.registerLazySingleton<NeuralLineClassifier>(
        () => NeuralLineClassifier(
          classifierService: container<OnnxLineClassifierService>(),
          modelManager: container<LineClassifierModelManager>(),
        ),
        dispose: (s) => s.dispose(),
      );

      // Shared ingredient parsing strategy (CRF → BERT NER → regex fallback)
      container.registerLazySingleton<IngredientParsingStrategy>(
        () => IngredientParsingStrategy(
          remoteLoader: container<RemoteWeightLoader>(),
          neuralParser: container<NeuralIngredientParser>(),
        ),
      );

      // RecipeParserService: registered in configureUserScope
      // (depends on LlmService → ConsentService, both user-scoped)

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

      // BUT-595: per-field parse-correction uploader (logParseCorrection
      // callable). Lazy-Functions instance keeps tests Firebase-free.
      container.registerLazySingleton<ParseCorrectionUploader>(
        () => ParseCorrectionUploader(),
      );

      // Menu lexicon: code defaults + Firestore overlay (BUT-370)
      container.registerLazySingleton<FirebaseMenuLexiconRepository>(
        () => FirebaseMenuLexiconRepository(),
      );
      container.registerLazySingleton<LexiconProvider>(
        () => CompositeLexiconProvider(
          code: const CodeLexiconProvider(),
          firestore: FirestoreLexiconProvider(
            repository: container<FirebaseMenuLexiconRepository>(),
          ),
        ),
      );

      // Menu service for meal planning
      container.registerLazySingleton<MenuService>(
        () => MenuService(lexiconProvider: container<LexiconProvider>()),
      );

      container.registerLazySingleton<WeeklyMenuPlanRepository>(
        () => FirebaseWeeklyMenuPlanRepository(
          authRepository: container<auth.AuthRepository>(),
          auditRepository: container<FirebaseAuditRepository>(),
        ),
      );

      // Lazy resolution of UserService: it's registered in SocialModule
      // which loads after ContentModule. Lazy singleton resolves at first
      // get() which happens after all modules are configured.
      container.registerLazySingleton<WeeklyMenuPlanService>(
        () => WeeklyMenuPlanService(
          repository: container<WeeklyMenuPlanRepository>(),
          userService: container<UserService>(),
        ),
      );

      // BUT-956: menu→shopping generation. ServiceLocator-resolves its three
      // collaborators at call time, so registration order is a non-issue.
      container.registerLazySingleton<MenuShoppingListGenerator>(
        () => MenuShoppingListGenerator(),
      );

      // BUT-405: group-scoped weekly menu plans. Coexists with the per-user
      // plan service — 1:1 conversations still use WeeklyMenuPlanService;
      // group conversations route through this one.
      container.registerLazySingleton<GroupWeeklyMenuPlanRepository>(
        () => FirebaseGroupWeeklyMenuPlanRepository(
          authRepository: container<auth.AuthRepository>(),
          auditRepository: container<FirebaseAuditRepository>(),
        ),
      );
      container.registerLazySingleton<GroupWeeklyMenuPlanService>(
        () => GroupWeeklyMenuPlanService(
          repository: container<GroupWeeklyMenuPlanRepository>(),
        ),
      );

      // Live watcher for the group plan doc (content-only, no presence).
      container.registerLazySingleton<RealtimeGroupMenuModule>(
        () => RealtimeGroupMenuModule(
          repository: container<GroupWeeklyMenuPlanRepository>(),
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

      // BUT-409: seasonal hero service — reads bundled JSON, no auth/network.
      container.registerLazySingleton<SeasonalHeroService>(
        () => SeasonalHeroService(),
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

      // User-scoped services — only initialize if user session is active
      if (container.isRegistered<OfflineService>()) {
        // Initialize OfflineService FIRST - other services depend on its database
        final offlineService = container<OfflineService>();
        await offlineService.initialize();

        // Initialize UnifiedRecipeService (depends on OfflineService.database)
        final unifiedRecipeService = container<UnifiedRecipeService>();
        await unifiedRecipeService.initialize();

        // UnifiedMenuService and RecipeParserService are independent after
        // OfflineService + UnifiedRecipeService — initialize in parallel.
        await Future.wait([
          container<UnifiedMenuService>().initialize(),
          if (container.isRegistered<RecipeParserService>())
            container<RecipeParserService>().init(),
        ]);
      }

      // Validate app-scoped services are accessible
      final services = [
        container<MenuService>(),
        container<SearchService>(),
        container<ShareService>(),
        container<StorageService>(),
        container<ImagePickerService>(),
        container<BackupService>(),
      ];

      for (final service in services) {
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

      // App-scoped services (always available)
      final services = <String, dynamic>{
        'RecipeRepository': container<RecipeRepository>(),
        'MenuService': container<MenuService>(),
        'SearchService': container<SearchService>(),
        'ShareService': container<ShareService>(),
        'StorageService': container<StorageService>(),
        'ImagePickerService': container<ImagePickerService>(),
        'CollaborativeRecipeRepository':
            container<CollaborativeRecipeRepository>(),
        'BackupService': container<BackupService>(),
        'SocialMediaExtractor': container<SocialMediaExtractor>(),
        'ExtractionManager': container<ExtractionManager>(),
        'GlobalRecipeCache': container<GlobalRecipeCache>(),
        'ImportRateLimiter': container<ImportRateLimiter>(),
        'SiteConfigRepository': container<SiteConfigRepository>(),
      };

      // User-scoped services (only after login)
      if (container.isRegistered<UnifiedRecipeService>()) {
        services['UnifiedRecipeService'] = container<UnifiedRecipeService>();
        services['ImportManager'] = container<ImportManager>();
        services['OfflineService'] = container<OfflineService>();
        // LLM + parser services depend on ConsentService (user-scoped)
        services['RecipeParserService'] = container<RecipeParserService>();
        services['LlmService'] = container<LlmService>();
        services['LlmEnhancementService'] = container<LlmEnhancementService>();
        services['YouTubeTranscriptService'] =
            container<YouTubeTranscriptService>();
        services['YouTubeImportStrategy'] = container<YouTubeImportStrategy>();
        services['TikTokPipeline'] = container<TikTokPipeline>();
        services['InstagramPipeline'] = container<InstagramPipeline>();
      }

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
