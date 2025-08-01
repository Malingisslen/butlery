/// Comprehensive unified recipe ViewModel providing advanced recipe management and operations for Flutter applications.
///
/// This module implements sophisticated unified recipe coordination following Single Responsibility Principle,
/// serving as a comprehensive facade that delegates to specialized focused ViewModels while maintaining backward compatibility
/// with existing application interfaces. It provides complete recipe management infrastructure including personal recipes,
/// collaborative features, real-time editing, and advanced querying capabilities through clean architectural separation.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles unified recipe coordination and facade responsibilities:
/// - **Unified Recipe Operations**: Comprehensive recipe management through focused ViewModel delegation and service coordination
/// - **Architectural Facade**: Clean facade pattern providing unified API while delegating to specialized ViewModels for maintainability
/// - **Backward Compatibility**: Complete interface compatibility with existing application code and legacy operation support
/// - **Cross-Cutting Coordination**: Unified state management, error handling, and notification coordination across all recipe operations
/// - **Performance Optimization**: Intelligent caching, reactive updates, and resource management through focused ViewModel architecture
///
/// **What This Module Does NOT Handle:**
/// - Direct recipe data persistence (handled by UnifiedRecipeService and specialized data repositories)
/// - Complex business logic implementation (handled by focused ViewModels: Personal, Social, Realtime, Query)
/// - UI rendering and widget creation (handled by recipe views and presentation components)
/// - Service-layer implementation details (handled by UnifiedRecipeService and underlying service infrastructure)
///
/// **Unified Recipe ViewModel Architecture:**
/// - **PersonalRecipeViewModel**: Personal recipe operations, creation, editing, and private recipe management
/// - **SocialRecipeViewModel**: Collaborative recipes, sharing, member management, and social interaction features
/// - **RealtimeRecipeViewModel**: Real-time collaborative editing, live synchronization, and concurrent editing coordination
/// - **RecipeQueryViewModel**: Advanced querying, filtering, analytics, and recipe discovery capabilities
/// - **Clean Facade Pattern**: Unified API maintaining backward compatibility while leveraging focused architecture
///
/// **Usage Examples:**
/// ```dart
/// // Initialize unified recipe ViewModel with service dependencies
/// final unifiedRecipeViewModel = UnifiedRecipeViewModel();
/// await unifiedRecipeViewModel.initialize();
/// 
/// // Personal recipe operations
/// final personalCreated = await unifiedRecipeViewModel.createPersonalRecipe(
///   name: 'Vegetarisk Pasta Carbonara',
///   description: 'Krämig pasta med vegetariska alternativ',
///   ingredients: ['200g pasta', '100ml grädde', 'Vegetarisk bacon'],
///   instructions: ['Koka pastan', 'Stek baconen', 'Blanda med grädde'],
///   mealType: 'Middag',
///   portions: 4,
///   timeMinutes: 25,
/// );
/// 
/// // Collaborative recipe creation with member management
/// final collaborativeCreated = await unifiedRecipeViewModel.createCollaborativeRecipe(
///   name: 'Familjerrecept: Köttbullar',
///   memberIds: ['user1', 'user2', 'user3'],
///   memberDisplayNames: {'user1': 'Anna', 'user2': 'Erik', 'user3': 'Lisa'},
///   description: 'Traditionella svenska köttbullar',
///   allowGuestViewing: true,
///   allowMemberInvites: true,
/// );
/// 
/// // Recipe sharing and social operations
/// final sharedRecipeId = await unifiedRecipeViewModel.shareRecipe(
///   recipeId: 'recipe_123',
///   memberIds: ['friend1', 'friend2'],
///   memberDisplayNames: {'friend1': 'Sara', 'friend2': 'Johan'},
///   collaborativeDescription: 'Delat för familjemiddag',
/// );
/// 
/// // Advanced querying and filtering
/// final dinnerRecipes = unifiedRecipeViewModel.getRecipesByMealType('Middag');
/// final searchResults = unifiedRecipeViewModel.searchRecipes('vegetarisk pasta');
/// final recentlyCooked = unifiedRecipeViewModel.getRecentlyCookedRecipes();
/// 
/// // Real-time collaborative editing
/// await unifiedRecipeViewModel.startRealtimeEditing('recipe_456');
/// final editSuccess = await unifiedRecipeViewModel.makeRealtimeEdit(
///   recipeId: 'recipe_456',
///   changes: {'ingredients': updatedIngredients},
///   editDescription: 'Lade till mer kryddor',
/// );
/// 
/// // Recipe content management
/// final updated = await unifiedRecipeViewModel.updateRecipeContent(
///   recipeId: 'recipe_789',
///   name: 'Uppdaterat Receptnamn',
///   description: 'Ny beskrivning med förbättringar',
///   portions: 6,
///   timeMinutes: 30,
/// );
/// 
/// // State monitoring and reactive updates
/// final allRecipes = unifiedRecipeViewModel.allRecipes;
/// final personalRecipes = unifiedRecipeViewModel.personalRecipes;
/// final collaborativeRecipes = unifiedRecipeViewModel.collaborativeRecipes;
/// 
/// if (unifiedRecipeViewModel.isLoading) {
///   // Show loading indicator
/// } else if (unifiedRecipeViewModel.hasError) {
///   // Handle error state: unifiedRecipeViewModel.error
/// }
/// ```

// lib/viewmodels/unified_recipe_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/permission_service.dart' as perm;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/utils/logging_utils.dart';
import 'package:butlery/services/unified/types/recipe_types.dart' show RecipeOperationResult;
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';

// Import focused ViewModels
import 'package:butlery/viewmodels/recipe/personal_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/recipe/realtime_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/recipe/recipe_query_viewmodel.dart';
/// Comprehensive unified recipe ViewModel providing advanced recipe management and operations through focused architecture.
///
/// Serves as the main facade coordinating specialized ViewModels for recipe operations, providing unified API
/// for personal recipes, collaborative features, real-time editing, and advanced querying while maintaining
/// clean MVVM architecture separation and backward compatibility with existing application interfaces.
class UnifiedRecipeViewModel extends ChangeNotifier {
  final UnifiedRecipeService _recipeService = ServiceLocator.get<UnifiedRecipeService>();

  // ===== FOCUSED VIEWMODEL ARCHITECTURE =====
  
  /// Personal recipe operations ViewModel for private recipe management and individual user functionality.
  late final PersonalRecipeViewModel _personalViewModel;
  
  /// Social recipe operations ViewModel for collaborative features, sharing, and member management.
  late final SocialRecipeViewModel _socialViewModel;
  
  /// Real-time editing ViewModel for live collaborative editing and synchronization coordination.
  late final RealtimeRecipeViewModel _realtimeViewModel;
  
  /// Recipe querying and analytics ViewModel for advanced filtering, search, and insights functionality.
  late final RecipeQueryViewModel _queryViewModel;

  /// Initializes unified recipe ViewModel with comprehensive focused architecture and reactive coordination.
  /// 
  /// Establishes specialized ViewModels for different recipe operation categories, sets up reactive
  /// state coordination between all ViewModels and services, and prepares unified API facade
  /// for complete recipe management functionality with clean architectural separation.
  /// 
  /// **Initialization Process:**
  /// - Focused ViewModel instantiation for specialized responsibilities
  /// - Reactive listener setup for cross-ViewModel state synchronization
  /// - Service integration with unified state management
  /// - Facade pattern establishment for backward compatibility
  UnifiedRecipeViewModel() {
    // Initialize focused ViewModels with specialized responsibilities
    _personalViewModel = PersonalRecipeViewModel();
    _socialViewModel = SocialRecipeViewModel(friendsService: ServiceLocator.get());
    _realtimeViewModel = RealtimeRecipeViewModel();
    _queryViewModel = RecipeQueryViewModel();

    // Set up unified service state synchronization
    _recipeService.addListener(_onServiceUpdate);
    
    // Establish cross-ViewModel reactive coordination for unified state management
    _personalViewModel.addListener(_onServiceUpdate);
    _socialViewModel.addListener(_onServiceUpdate);
    _realtimeViewModel.addListener(_onServiceUpdate);
    _queryViewModel.addListener(_onServiceUpdate);
  }

  /// Handles unified state updates from focused ViewModels and services with comprehensive coordination.
  /// 
  /// Provides centralized state synchronization for all recipe operations ensuring
  /// UI components receive immediate updates when any focused ViewModel or service
  /// changes state, maintaining reactive consistency across the entire recipe management system.
  void _onServiceUpdate() {
    notifyListeners();
  }

  // ===== UNIFIED RECIPE STATE ACCESSORS =====

  /// Complete recipe collection for comprehensive access and UI display coordination.
  /// 
  /// Provides access to all recipes across personal and collaborative categories
  /// for unified recipe management and complete application functionality.
  List<Recipe> get allRecipes => _recipeService.recipes;

  /// All recipes collection for backward compatibility and unified access.
  /// 
  /// Delegates to UnifiedRecipeService for complete recipe collection enabling
  /// comprehensive recipe management and UI display functionality.
  List<Recipe> get recipes => _recipeService.recipes;
  
  /// Personal recipes collection for individual user recipe management.
  /// 
  /// Provides access to user-owned recipes for personal recipe operations
  /// and individual meal planning functionality.
  List<Recipe> get personalRecipes => _recipeService.personalRecipes;
  
  /// Collaborative recipes collection for social recipe management and sharing.
  /// 
  /// Provides access to shared and collaborative recipes for social features
  /// and team-based meal planning functionality.
  List<Recipe> get collaborativeRecipes => _recipeService.collaborativeRecipes;

  // ===== LOADING AND SYNCHRONIZATION STATE =====

  /// Loading operation state for UI progress indication and interaction control.
  /// 
  /// Indicates active loading operations for UI loading indicators and user interaction
  /// management during recipe data retrieval and synchronization processes.
  bool get isLoading => _recipeService.isLoading;
  
  /// Synchronization state for data consistency indication and offline coordination.
  /// 
  /// Indicates active synchronization between local and remote data sources
  /// for data consistency management and offline functionality coordination.
  bool get isSyncing => _recipeService.isSyncing;
  
  /// Initialization state for application readiness and feature availability.
  /// 
  /// Indicates whether recipe service is fully initialized and ready for operations,
  /// enabling UI feature activation and functionality availability management.
  bool get isInitialized => _recipeService.isInitialized;

  // ===== ERROR HANDLING AND CONNECTIVITY =====

  /// Current error message for user feedback and error state management.
  /// 
  /// Delegates to UnifiedRecipeService for centralized error handling with localized
  /// error messages for comprehensive user feedback and error recovery.
  String? get error => _recipeService.error;
  
  /// Error state indicator for UI conditional rendering and error handling.
  /// 
  /// Provides boolean error state check for UI error display decisions
  /// and error state management throughout recipe operations.
  bool get hasError => _recipeService.hasError;

  /// Online connectivity status for feature availability and user guidance.
  /// 
  /// Combines initialization and error states to indicate application connectivity
  /// and feature availability for user interface adaptation and functionality guidance.
  bool get isOnline => !hasError && isInitialized;

  // ===== RECIPE AVAILABILITY AND STATISTICS =====

  /// Recipe availability indicator for UI conditional display and feature enabling.
  /// 
  /// Indicates whether any recipes are available for display and operations,
  /// enabling UI conditional rendering and recipe-dependent feature activation.
  bool get hasRecipes => _recipeService.hasRecipes;
  
  /// Personal recipe availability for individual feature enabling and UI coordination.
  /// 
  /// Indicates whether user has personal recipes for individual recipe feature
  /// activation and personal meal planning functionality.
  bool get hasPersonalRecipes => personalRecipes.isNotEmpty;
  
  /// Collaborative recipe availability for social feature enabling and UI coordination.
  /// 
  /// Indicates whether user has collaborative recipes for social feature activation
  /// and collaborative meal planning functionality.
  bool get hasCollaborativeRecipes => collaborativeRecipes.isNotEmpty;

  // ===== USER CONTEXT AND IDENTIFICATION =====

  /// Current user identifier for permission management and operation coordination.
  /// 
  /// Provides current user ID for permission validation, operation attribution,
  /// and user-specific functionality throughout recipe management operations.
  String? get currentUserId => _recipeService.currentUserId;
  
  /// Current user display name for UI personalization and social interaction.
  /// 
  /// Provides user display name for UI personalization, social features,
  /// and collaborative interaction display throughout the application.
  String? get currentUserDisplayName => _recipeService.currentUserDisplayName;

  // ===== RECIPE STATISTICS AND ANALYTICS =====

  /// Total recipe count for statistics display and application metrics.
  /// 
  /// Provides aggregate recipe count across all categories for statistics display
  /// and application analytics functionality.
  int get totalRecipes => recipes.length;
  
  /// Personal recipe count for individual statistics and feature metrics.
  /// 
  /// Provides personal recipe count for individual user metrics and personal
  /// recipe management statistics display.
  int get personalRecipeCount => personalRecipes.length;
  
  /// Collaborative recipe count for social statistics and engagement metrics.
  /// 
  /// Provides collaborative recipe count for social engagement metrics and
  /// collaborative feature usage statistics display.
  int get collaborativeRecipeCount => collaborativeRecipes.length;

  // ===== COMPREHENSIVE INITIALIZATION =====

  /// Initializes unified recipe system with comprehensive service coordination and state preparation.
  /// 
  /// Performs complete system initialization including service initialization, data loading,
  /// and state preparation for all recipe operations. Includes comprehensive logging
  /// for initialization tracking and debugging support.
  /// 
  /// **Initialization Process:**
  /// - UnifiedRecipeService initialization with data loading
  /// - Focused ViewModel preparation and state coordination
  /// - Service layer integration and connectivity establishment
  /// - Comprehensive logging for initialization tracking
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final viewModel = UnifiedRecipeViewModel();
  /// await viewModel.initialize();
  /// // System ready for all recipe operations
  /// ```
  Future<void> initialize() async {
    await LoggingUtils.loggedOperation(
      'Initialize Unified Recipe ViewModel System',
      () => _recipeService.initialize(),
      level: LogLevel.info,
    );
  }

  // ===== PERSONAL RECIPE OPERATIONS (DELEGATE TO SPECIALIZED VIEWMODEL) =====

  /// Creates personal recipe with comprehensive validation and Swedish localization support.
  /// 
  /// [name] Recipe title for identification and display
  /// [description] Detailed recipe description and cooking notes
  /// [ingredients] List of ingredients with quantities and preparation notes
  /// [instructions] Step-by-step cooking instructions for recipe execution
  /// [imageUrls] Recipe images for visual presentation and gallery display
  /// [mealType] Swedish localized meal category (default: 'Lunch')
  /// [portions] Serving size for meal planning and scaling calculations
  /// [timeMinutes] Cooking time for meal planning and filtering
  /// [rating] Recipe quality rating for recommendation and filtering
  /// [tags] Categorization tags for organization and search functionality
  /// [sourceUrl] External source attribution for recipe attribution
  /// 
  /// Returns true if recipe creation succeeds, false if validation fails or creation errors occur.
  /// Delegates to PersonalRecipeViewModel for specialized personal recipe management
  /// with comprehensive validation, data processing, and storage coordination.
  /// 
  /// **Creation Process:**
  /// - Recipe data validation with Swedish localization
  /// - Personal recipe creation through specialized ViewModel
  /// - Storage coordination and data persistence
  /// - State synchronization and UI notification
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final created = await unifiedRecipeViewModel.createPersonalRecipe(
  ///   name: 'Vegetarisk Pasta Carbonara',
  ///   description: 'Krämig pasta med vegetariska alternativ',
  ///   ingredients: ['200g pasta', '100ml grädde', 'Vegetarisk bacon'],
  ///   instructions: ['Koka pastan al dente', 'Stek baconen', 'Blanda med grädde'],
  ///   mealType: 'Middag',
  ///   portions: 4,
  ///   timeMinutes: 25,
  ///   tags: ['vegetarisk', 'pasta', 'snabbt'],
  /// );
  /// ```
  Future<bool> createPersonalRecipe({
    required String name,
    String description = '',
    List<String> ingredients = const [],
    List<String> instructions = const [],
    List<String> imageUrls = const [],
    String mealType = 'Lunch',
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
    String? sourceUrl,
  }) async {
    return await _personalViewModel.createPersonalRecipe(
      name: name,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      imageUrls: imageUrls,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      tags: tags,
      sourceUrl: sourceUrl,
    );
  }

  // ===== SOCIAL RECIPE OPERATIONS (DELEGATE TO SPECIALIZED VIEWMODEL) =====

  /// Creates collaborative recipe with comprehensive member management and permission coordination.
  /// 
  /// [name] Recipe title for identification and collaborative display
  /// [memberIds] List of user IDs for collaborative access and member management
  /// [memberDisplayNames] User ID to display name mapping for collaborative UI
  /// [description] Detailed recipe description and collaborative cooking notes
  /// [ingredients] List of ingredients with collaborative editing capabilities
  /// [instructions] Step-by-step instructions with collaborative refinement
  /// [imageUrls] Recipe images for collaborative visual presentation
  /// [mealType] Swedish localized meal category for collaborative planning
  /// [portions] Serving size for collaborative meal planning
  /// [timeMinutes] Cooking time for collaborative scheduling
  /// [rating] Collaborative recipe quality assessment
  /// [tags] Collaborative categorization tags for organization
  /// [sourceUrl] External source attribution for collaborative reference
  /// [descriptionCollaborative] Collaborative-specific description and context
  /// [allowGuestViewing] Whether non-members can view recipe
  /// [allowMemberInvites] Whether members can invite additional collaborators
  /// [categoryIds] Collaborative category assignments for organization
  /// 
  /// Returns true if collaborative recipe creation succeeds, false if validation or creation fails.
  /// Delegates to SocialRecipeViewModel for specialized collaborative recipe management
  /// with comprehensive member coordination, permission management, and social features.
  /// 
  /// **Collaborative Creation Process:**
  /// - Member validation and permission setup
  /// - Collaborative recipe creation with social coordination
  /// - Permission system initialization for collaborative access
  /// - Social integration and notification coordination
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final collaborativeCreated = await unifiedRecipeViewModel.createCollaborativeRecipe(
  ///   name: 'Familjerecept: Köttbullar',
  ///   memberIds: ['user1', 'user2', 'user3'],
  ///   memberDisplayNames: {'user1': 'Anna', 'user2': 'Erik', 'user3': 'Lisa'},
  ///   description: 'Traditionella svenska köttbullar för familjen',
  ///   mealType: 'Middag',
  ///   allowGuestViewing: true,
  ///   allowMemberInvites: true,
  /// );
  /// ```
  Future<bool> createCollaborativeRecipe({
    required String name,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String description = '',
    List<String> ingredients = const [],
    List<String> instructions = const [],
    List<String> imageUrls = const [],
    String mealType = 'Lunch',
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
    String? sourceUrl,
    String? descriptionCollaborative,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    return await _socialViewModel.createCollaborativeRecipe(
      name: name,
      memberIds: memberIds,
      memberDisplayNames: memberDisplayNames,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      imageUrls: imageUrls,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      tags: tags,
      sourceUrl: sourceUrl,
      descriptionCollaborative: descriptionCollaborative,
      allowGuestViewing: allowGuestViewing,
      allowMemberInvites: allowMemberInvites,
      categoryIds: categoryIds,
    );
  }

  /// Shares existing recipe with comprehensive member coordination and permission management.
  /// 
  /// [recipeId] Recipe identifier for sharing operation
  /// [memberIds] List of user IDs for recipe sharing access
  /// [memberDisplayNames] User ID to display name mapping for sharing UI
  /// [collaborativeDescription] Optional sharing context and collaborative notes
  /// [allowGuestViewing] Whether non-members can view shared recipe
  /// [allowMemberInvites] Whether shared members can invite additional users
  /// [categoryIds] Category assignments for shared recipe organization
  /// 
  /// Returns shared recipe ID if sharing succeeds, null if operation fails.
  /// Delegates to SocialRecipeViewModel for specialized recipe sharing coordination
  /// with comprehensive member management, permission setup, and social integration.
  /// 
  /// **Sharing Process:**
  /// - Recipe validation and sharing permission checks
  /// - Member coordination and permission assignment
  /// - Collaborative recipe creation from personal recipe
  /// - Social notification and integration coordination
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final sharedRecipeId = await unifiedRecipeViewModel.shareRecipe(
  ///   recipeId: 'personal_recipe_123',
  ///   memberIds: ['friend1', 'friend2', 'family1'],
  ///   memberDisplayNames: {
  ///     'friend1': 'Sara Andersson',
  ///     'friend2': 'Johan Eriksson',
  ///     'family1': 'Mamma'
  ///   },
  ///   collaborativeDescription: 'Delat för helgmiddag tillsammans',
  ///   allowGuestViewing: false,
  ///   allowMemberInvites: true,
  /// );
  /// ```
  Future<String?> shareRecipe({
    required String recipeId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String? collaborativeDescription,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    return await _socialViewModel.shareRecipe(
      recipeId: recipeId,
      memberIds: memberIds,
      memberDisplayNames: memberDisplayNames,
      collaborativeDescription: collaborativeDescription,
      allowGuestViewing: allowGuestViewing,
      allowMemberInvites: allowMemberInvites,
      categoryIds: categoryIds,
    );
  }

  /// Converts collaborative recipe to personal recipe with comprehensive data migration.
  /// 
  /// [collaborativeRecipeId] Collaborative recipe identifier for conversion
  /// 
  /// Returns personal recipe ID if conversion succeeds, null if operation fails.
  /// Delegates to SocialRecipeViewModel for specialized recipe conversion coordination
  /// with data migration, permission cleanup, and personal recipe creation.
  /// 
  /// **Conversion Process:**
  /// - Collaborative recipe data extraction and validation
  /// - Personal recipe creation with migrated content
  /// - Collaborative permission cleanup and member notification
  /// - Data consistency validation and state synchronization
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final personalRecipeId = await unifiedRecipeViewModel.makeRecipePersonal(
  ///   'collaborative_recipe_456'
  /// );
  /// if (personalRecipeId != null) {
  ///   // Conversion successful, update UI
  /// }
  /// ```
  Future<String?> makeRecipePersonal(String collaborativeRecipeId) async {
    return await _socialViewModel.makeRecipePersonal(collaborativeRecipeId);
  }

  // ===== UNIFIED RECIPE MANAGEMENT =====

  Future<bool> updateRecipe(Recipe recipe) async {
    if (recipe.isPersonal) {
      return await _personalViewModel.updatePersonalRecipe(recipe);
    } else {
      return await _recipeService.updateRecipe(recipe);
    }
  }

  Future<bool> deleteRecipe(String recipeId) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;
    
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _personalViewModel.deletePersonalRecipe(recipeId);
    } else {
      return await _recipeService.deleteRecipe(recipeId);
    }
  }

  // ===== LEGACY COMPATIBILITY METHODS =====

  Future<RecipeOperationResult> addRecipe(Recipe recipe) async {
    if (recipe.isPersonal) {
      return await _personalViewModel.addLegacyRecipe(recipe);
    } else {
      return RecipeOperationResult.failure('Cannot add non-personal recipe through legacy method');
    }
  }

  Future<RecipeOperationResult> updateLegacyRecipe(Recipe recipe) async {
    if (recipe.isPersonal) {
      return await _personalViewModel.updateLegacyRecipe(recipe);
    } else {
      return RecipeOperationResult.failure('Cannot update non-personal recipe through legacy method');
    }
  }

  Future<RecipeOperationResult> deleteRecipeById(String id) async {
    if (ValidationUtils.isNullOrEmpty(id)) {
      return RecipeOperationResult.failure('Invalid recipe ID');
    }

    try {
      final result = await LoggingUtils.loggedOperation(
        'Delete Recipe by ID',
        () => _recipeService.deleteRecipeById(id),
        metadata: {'recipe_id': id},
      );
      return result;
    } catch (e) {
      return RecipeOperationResult.failure('Failed to delete recipe: $e');
    }
  }

  Future<void> refresh() async {
    await LoggingUtils.loggedOperation(
      'Refresh Recipes',
      () => _recipeService.refresh(),
      level: LogLevel.debug,
    );
  }

  // ===== CONTENT EDITING METHODS =====

  Future<bool> updateRecipeContent({
    required String recipeId,
    String? name,
    String? description,
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? imageUrls,
    String? mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
    String? sourceUrl,
  }) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;

    if (recipe.isPersonal) {
      return await _personalViewModel.updateRecipeContent(
        recipeId: recipeId,
        name: name,
        description: description,
        mealType: mealType,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        tags: tags,
        sourceUrl: sourceUrl,
      );
    } else {
      return await _recipeService.updateRecipeContent(
        recipeId: recipeId,
        title: name,
        description: description,
        ingredients: ingredients,
        instructions: instructions,
        imageUrls: imageUrls,
        mealType: mealType,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        tags: tags,
        sourceUrl: sourceUrl,
      );
    }
  }

  // ===== INGREDIENT MANAGEMENT =====

  Future<bool> addIngredient(String recipeId, String ingredient) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _personalViewModel.addIngredient(recipeId, ingredient);
    } else {
      return await _recipeService.addIngredient(recipeId, ingredient);
    }
  }

  Future<bool> updateIngredient(String recipeId, int index, String newIngredient) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _personalViewModel.updateIngredient(recipeId, index, newIngredient);
    } else {
      return await _recipeService.updateIngredient(recipeId, index, newIngredient);
    }
  }

  Future<bool> removeIngredient(String recipeId, int index) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _personalViewModel.removeIngredient(recipeId, index);
    } else {
      return await _recipeService.removeIngredient(recipeId, index);
    }
  }

  // ===== INSTRUCTION MANAGEMENT =====

  Future<bool> addInstruction(String recipeId, String instruction) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _personalViewModel.addInstruction(recipeId, instruction);
    } else {
      return await _recipeService.addInstruction(recipeId, instruction);
    }
  }

  Future<bool> updateInstruction(String recipeId, int index, String newInstruction) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _personalViewModel.updateInstruction(recipeId, index, newInstruction);
    } else {
      return await _recipeService.updateInstruction(recipeId, index, newInstruction);
    }
  }

  Future<bool> removeInstruction(String recipeId, int index) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _personalViewModel.removeInstruction(recipeId, index);
    } else {
      return await _recipeService.removeInstruction(recipeId, index);
    }
  }

  Future<bool> markRecipeAsCooked(String recipeId) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _personalViewModel.markAsCooked(recipeId);
    } else {
      return await _recipeService.markRecipeAsCooked(recipeId);
    }
  }

  // ===== SOCIAL MEMBER MANAGEMENT (Delegate to SocialRecipeViewModel) =====

  Future<bool> addMemberToRecipe(
      String recipeId, String userId, String userDisplayName, 
      {ResourcePermission? permission}) async {
    permission ??= ResourcePermission.editor; // Default permission
    return await _socialViewModel.addMemberToRecipe(recipeId, userId, userDisplayName, permission: permission);
  }

  Future<bool> removeMemberFromRecipe(String recipeId, String userId) async {
    return await _socialViewModel.removeMemberFromRecipe(recipeId, userId);
  }

  Future<bool> updateMemberPermission(
      String recipeId, String userId, ResourcePermission permission) async {
    return await _socialViewModel.updateMemberPermission(recipeId, userId, permission);
  }

  Map<String, ResourcePermission> getRecipeMembers(String recipeId) {
    return _socialViewModel.getRecipeMembers(recipeId);
  }

  bool canInviteMembers(String recipeId) {
    return _socialViewModel.canInviteMembers(recipeId);
  }

  List<Recipe> getSharedWithMe() {
    return _socialViewModel.getSharedWithMe();
  }

  List<Recipe> getSharedByMe() {
    return _socialViewModel.getSharedByMe();
  }

  // ===== RECIPE QUERIES & FILTERING (Delegate to RecipeQueryViewModel) =====

  Recipe? getRecipeById(String id) {
    return _queryViewModel.getRecipeById(id);
  }

  Recipe? getUnifiedRecipeById(String id) {
    return _queryViewModel.getRecipeById(id);
  }

  List<Recipe> getRecipesByMealType(String mealType) {
    return _queryViewModel.getRecipesByMealType(mealType);
  }

  List<Recipe> getRecipesByTag(String tag) {
    return _queryViewModel.getRecipesByTag(tag);
  }

  List<Recipe> searchRecipes(String query) {
    return _queryViewModel.searchRecipes(query);
  }

  List<Recipe> getEditableRecipes() {
    return _queryViewModel.getEditableRecipes();
  }

  List<Recipe> getRecentlyCookedRecipes() {
    return _queryViewModel.getRecentlyCookedRecipes();
  }

  Map<String, List<Recipe>> get recipesByMealType {
    return _queryViewModel.recipesByMealType;
  }

  List<String> get usedMealTypes {
    return _queryViewModel.usedMealTypes;
  }

  List<String> get usedTags {
    return _queryViewModel.usedTags;
  }

  // ===== COLLABORATIVE FEATURES =====

  bool canManageRecipeMembers(String recipeId) {
    return ServiceLocator.get<perm.PermissionService>().canInviteToRecipe(recipeId);
  }

  List<String> getActiveEditors(String recipeId) {
    return _realtimeViewModel.getActiveEditors(recipeId);
  }

  // ===== REALTIME OPERATIONS (Delegate to RealtimeRecipeViewModel) =====

  Stream<Recipe> watchRecipe(String recipeId) {
    return _realtimeViewModel.watchRecipe(recipeId);
  }

  Stream<List<Recipe>> watchMultipleRecipes(List<String> recipeIds) {
    return _realtimeViewModel.watchMultipleRecipes(recipeIds);
  }

  Future<bool> startRealtimeEditing(String recipeId) async {
    return await _realtimeViewModel.startRealtimeEditing(recipeId);
  }

  Future<bool> stopRealtimeEditing(String recipeId) async {
    return await _realtimeViewModel.stopRealtimeEditing(recipeId);
  }

  Future<bool> makeRealtimeEdit({
    required String recipeId,
    required Map<String, dynamic> changes,
    String? editDescription,
  }) async {
    return await _realtimeViewModel.makeRealtimeEdit(
      recipeId: recipeId,
      changes: changes,
      editDescription: editDescription,
    );
  }

  bool get isRealtimeConnected => _realtimeViewModel.isRealtimeConnected;
  Stream<bool> get realtimeConnectionStream => _realtimeViewModel.realtimeConnectionStream;

  // ===== ERROR HANDLING =====

  void clearError() {
    _recipeService.clearError();
  }

  // ===== ANALYTICS & INSIGHTS =====

  Map<String, dynamic> get recipeInsights {
    return _queryViewModel.recipeInsights;
  }

  List<MapEntry<String, int>> getMostUsedMealTypes() {
    return _queryViewModel.getMostUsedMealTypes();
  }

  List<MapEntry<String, int>> getMostUsedTags() {
    return _queryViewModel.getMostUsedTags();
  }

  // ===== STATE MANAGEMENT =====

  @override
  void dispose() {
    _recipeService.removeListener(_onServiceUpdate);
    _personalViewModel.removeListener(_onServiceUpdate);
    _socialViewModel.removeListener(_onServiceUpdate);
    _realtimeViewModel.removeListener(_onServiceUpdate);
    _queryViewModel.removeListener(_onServiceUpdate);
    
    _personalViewModel.dispose();
    _socialViewModel.dispose();
    _realtimeViewModel.dispose();
    _queryViewModel.dispose();
    
    super.dispose();
  }

  // ===== DEBUGGING & DEVELOPMENT =====

  Map<String, dynamic> get debugInfo {
    return {
      'recipesCount': recipes.length,
      'personalRecipesCount': personalRecipeCount,
      'collaborativeRecipesCount': collaborativeRecipeCount,
      'isInitialized': isInitialized,
      'isLoading': isLoading,
      'hasError': hasError,
      'error': error,
      'currentUserId': currentUserId,
      'serviceState': {
        'isOnline': isOnline,
        'isSyncing': isSyncing,
      },
      'focusedViewModels': {
        'personal': _personalViewModel.serviceName,
        'social': _socialViewModel.serviceName,
        'realtime': _realtimeViewModel.serviceName,
        'query': _queryViewModel.serviceName,
      },
    };
  }

  void printDebugInfo() {
    debugPrint('=== UNIFIED RECIPE DEBUG INFO ===');
    debugInfo.forEach((key, value) {
      debugPrint('$key: $value');
    });
    debugPrint('==================================');
  }
}