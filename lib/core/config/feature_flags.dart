// lib/core/config/feature_flags.dart

/// Feature flags configuration for controlling app features and experiments
class FeatureFlags {
  // Prevent instantiation
  FeatureFlags._();

  // ===== SOCIAL FEATURES =====
  
  /// Enable social recipe sharing and comments
  static const bool enableSocialFeatures = true;
  
  /// Enable recipe commenting system
  static const bool enableRecipeComments = true;
  
  /// Enable friend invitations and social groups
  static const bool enableFriendInvitations = true;
  
  /// Enable collaborative shopping lists
  static const bool enableCollaborativeShoppingLists = true;

  // ===== RECIPE FEATURES =====
  
  /// Enable AI-powered recipe suggestions
  static const bool enableAiRecipeSuggestions = false;
  
  /// Enable recipe import from URLs
  static const bool enableRecipeImport = true;
  
  /// Enable recipe sharing to external apps
  static const bool enableRecipeExport = true;
  
  /// Enable recipe rating and reviews
  static const bool enableRecipeRatings = true;

  // ===== SHOPPING FEATURES =====
  
  /// Enable smart shopping list generation from recipes
  static const bool enableSmartShoppingLists = true;
  
  /// Enable shopping list sharing
  static const bool enableShoppingListSharing = true;
  
  /// Enable barcode scanning for shopping items
  static const bool enableBarcodeScanning = false;

  // ===== PERFORMANCE FEATURES =====
  
  /// Enable analytics and performance monitoring
  static const bool enableAnalytics = true;
  
  /// Enable crash reporting
  static const bool enableCrashReporting = true;
  
  /// Enable debug logging in production
  static const bool enableDebugLogging = false;

  // ===== EXPERIMENTAL FEATURES =====
  
  /// Enable experimental UI components
  static const bool enableExperimentalUI = false;
  
  /// Enable beta features for testing
  static const bool enableBetaFeatures = false;
  
  /// Enable A/B testing framework
  static const bool enableAbTesting = false;

  // ===== INFRASTRUCTURE FEATURES =====
  
  /// Enable modular dependency injection
  static const bool useModularDI = true;
  
  /// Enable health monitoring and diagnostics
  static const bool enableHealthMonitoring = true;
  
  /// Enable legacy fallback mechanisms for compatibility
  static const bool enableLegacyFallback = false;

  // ===== HELPER METHODS =====
  
  /// Check if a feature is enabled
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
  
  /// Get all enabled features
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
  
  /// Validate the current feature flag configuration
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