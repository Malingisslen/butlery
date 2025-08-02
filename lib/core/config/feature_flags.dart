/// Feature flag configuration system for centralized feature toggle management.
/// Central feature flag management with compile-time constants for optimal performance.
class FeatureFlags {
  /// Private constructor
  FeatureFlags._();

  /// Master toggle for all social functionality
  static const bool enableSocialFeatures = true;
  
  /// Enables recipe commenting and rating system
  static const bool enableRecipeComments = true;
  
  /// Enables friend invitation and social group management
  static const bool enableFriendInvitations = true;
  
  /// Enables collaborative shopping lists with real-time sync
  static const bool enableCollaborativeShoppingLists = true;

  /// Enables AI-powered recipe suggestions (experimental)
  static const bool enableAiRecipeSuggestions = false;
  
  /// Enables recipe import from external URLs
  static const bool enableRecipeImport = true;
  
  /// Enables recipe export and sharing to external platforms
  static const bool enableRecipeExport = true;
  
  /// Enables recipe rating and review system
  static const bool enableRecipeRatings = true;

  /// Enables intelligent shopping list generation from recipes
  static const bool enableSmartShoppingLists = true;
  
  /// Enables shopping list sharing with collaborative editing
  static const bool enableShoppingListSharing = true;
  
  /// Enables barcode scanning for product identification (experimental)
  static const bool enableBarcodeScanning = false;

  /// Enables analytics and performance monitoring
  static const bool enableAnalytics = true;
  
  /// Enables automatic crash reporting and error tracking
  static const bool enableCrashReporting = true;
  
  /// Enables debug logging in production (security sensitive)
  static const bool enableDebugLogging = false;

  /// Enables experimental UI components (disabled in production)
  static const bool enableExperimentalUI = false;
  
  /// Enables beta features for testing (disabled in production)
  static const bool enableBetaFeatures = false;
  
  /// Enables A/B testing framework (experimental)
  static const bool enableAbTesting = false;

  /// Enables modular dependency injection system
  static const bool useModularDI = true;
  
  /// Enables comprehensive health monitoring and diagnostics
  static const bool enableHealthMonitoring = true;
  
  /// Enables legacy fallback mechanisms (conflicts with modern DI)
  static const bool enableLegacyFallback = false;

  /// Checks if a feature is enabled by string name
  static bool isFeatureEnabled(String featureName) {
    switch (featureName) {
      case 'socialFeatures':
        return enableSocialFeatures;
      case 'recipeComments':
        return enableRecipeComments;
      case 'friendInvitations':
        return enableFriendInvitations;
      case 'collaborativeShoppingLists':
        return enableCollaborativeShoppingLists;
      case 'aiRecipeSuggestions':
        return enableAiRecipeSuggestions;
      case 'recipeImport':
        return enableRecipeImport;
      case 'recipeExport':
        return enableRecipeExport;
      case 'recipeRatings':
        return enableRecipeRatings;
      case 'smartShoppingLists':
        return enableSmartShoppingLists;
      case 'shoppingListSharing':
        return enableShoppingListSharing;
      case 'barcodeScanning':
        return enableBarcodeScanning;
      case 'analytics':
        return enableAnalytics;
      case 'crashReporting':
        return enableCrashReporting;
      case 'debugLogging':
        return enableDebugLogging;
      case 'experimentalUI':
        return enableExperimentalUI;
      case 'betaFeatures':
        return enableBetaFeatures;
      case 'abTesting':
        return enableAbTesting;
      case 'useModularDI':
        return useModularDI;
      case 'enableHealthMonitoring':
        return enableHealthMonitoring;
      case 'enableLegacyFallback':
        return enableLegacyFallback;
      default:
        return false;
    }
  }
  
  /// Returns list of all currently enabled features
  static List<String> getEnabledFeatures() {
    final enabledFeatures = <String>[];
    
    if (enableSocialFeatures) enabledFeatures.add('socialFeatures');
    if (enableRecipeComments) enabledFeatures.add('recipeComments');
    if (enableFriendInvitations) enabledFeatures.add('friendInvitations');
    if (enableCollaborativeShoppingLists) enabledFeatures.add('collaborativeShoppingLists');
    if (enableAiRecipeSuggestions) enabledFeatures.add('aiRecipeSuggestions');
    if (enableRecipeImport) enabledFeatures.add('recipeImport');
    if (enableRecipeExport) enabledFeatures.add('recipeExport');
    if (enableRecipeRatings) enabledFeatures.add('recipeRatings');
    if (enableSmartShoppingLists) enabledFeatures.add('smartShoppingLists');
    if (enableShoppingListSharing) enabledFeatures.add('shoppingListSharing');
    if (enableBarcodeScanning) enabledFeatures.add('barcodeScanning');
    if (enableAnalytics) enabledFeatures.add('analytics');
    if (enableCrashReporting) enabledFeatures.add('crashReporting');
    if (enableDebugLogging) enabledFeatures.add('debugLogging');
    if (enableExperimentalUI) enabledFeatures.add('experimentalUI');
    if (enableBetaFeatures) enabledFeatures.add('betaFeatures');
    if (enableAbTesting) enabledFeatures.add('abTesting');
    if (useModularDI) enabledFeatures.add('useModularDI');
    if (enableHealthMonitoring) enabledFeatures.add('enableHealthMonitoring');
    if (enableLegacyFallback) enabledFeatures.add('enableLegacyFallback');
    
    return enabledFeatures;
  }
  
  /// Validates feature flag configuration for conflicts and dependencies
  static bool validateConfiguration() {
    // Check for conflicting features
    if (enableLegacyFallback && useModularDI) {
      return false; // Legacy fallback conflicts with modular DI
    }
    
    // Check for required dependencies
    if (enableHealthMonitoring && !enableAnalytics) {
      return false; // Health monitoring requires analytics
    }
    
    // Check for experimental features in production
    if (enableBetaFeatures && !enableDebugLogging) {
      return false; // Beta features require debug logging
    }
    
    return true;
  }
}