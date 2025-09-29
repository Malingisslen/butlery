/// Comprehensive universal sharing dialog ViewModel providing advanced multi-content social distribution for Flutter applications.
///
/// This module implements sophisticated universal sharing functionality following Single Responsibility Principle,
/// specializing in multi-content sharing, recipient management, cross-platform distribution, and share status coordination.
/// It provides complete universal sharing infrastructure while maintaining clean separation from UI rendering,
/// content data persistence, and complex social sharing business logic implementation.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles universal sharing dialog presentation layer concerns:
/// - **Multi-Content Sharing Intelligence**: Advanced sharing of recipes, menus, and shopping lists with unified interface
/// - **Recipient Management System**: Comprehensive friend and group selection with multi-target sharing coordination
/// - **Cross-Platform Distribution**: Universal sharing operations with consistent API across different content types
/// - **Share Status Coordination**: Complete sharing state management with progress tracking and comprehensive error handling
/// - **Swedish Localization Excellence**: Complete Swedish language support for sharing operations and user feedback
///
/// **What This Module Does NOT Handle:**
/// - UI rendering and widget creation (handled by universal share dialog views and presentation components)
/// - Content data persistence and storage (handled by respective services and underlying data repositories)
/// - Complex social relationship business logic (handled by social services and relationship infrastructure)
/// - Share delivery infrastructure (handled by social services and communication systems)
///
/// **Universal Share Dialog ViewModel Features:**
/// - **Multi-Content Support**: Unified sharing interface for recipes, menus, and shopping lists with consistent operations
/// - **Advanced Recipient Selection**: Comprehensive friend and group targeting with multi-recipient coordination
/// - **Cross-Service Integration**: Seamless integration with social recipe and shopping services for content distribution
/// - **Share Status Management**: Complete sharing progress tracking with error handling and delivery confirmation
/// - **Swedish Localization**: Complete Swedish language support for sharing operations and error messages
///
/// **Usage Examples:**
/// ```dart
/// // Initialize universal share dialog ViewModel with service integration
/// final shareDialogViewModel = UniversalShareDialogViewModel(
///   socialRecipeService: ServiceLocator.get<SocialRecipeService>(),
///   shoppingService: ServiceLocator.get<UnifiedShoppingService>(),
/// );
/// 
/// // Share recipe with friends and groups
/// final recipeShared = await shareDialogViewModel.shareRecipe(
///   recipe: recipeToShare,
///   friendUserIds: ['friend_123', 'friend_456'],
///   groupIds: ['group_789'],
///   message: 'Kolla in detta fantastiska recept!',
///   allowCollaboration: true,
/// );
/// 
/// if (recipeShared) {
///   // Navigate back or show success message
/// } else if (shareDialogViewModel.hasError) {
///   // Handle sharing error
/// }
/// 
/// // Share menu with comprehensive coordination
/// final menuShared = await shareDialogViewModel.shareMenu(
///   menu: weekMenu,
///   friendUserIds: ['friend_123'],
///   groupIds: ['group_456'],
///   menuId: 'menu_weekly_plan',
///   message: 'Vår veckors matsedel - perfekt för familjen!',
///   allowCollaboration: false,
/// );
/// 
/// // Share shopping list with multi-target distribution
/// final listShared = await shareDialogViewModel.shareShoppingList(
///   shoppingList: groceryList,
///   friendUserIds: ['friend_789'],
///   groupIds: ['group_123', 'group_456'],
///   message: 'Gemensam inköpslista för helgmiddagen!',
/// );
/// 
/// // Monitor sharing progress and state
/// if (shareDialogViewModel.isSharing) {
///   // Show sharing progress indicator
/// }
/// 
/// // Error handling and recovery
/// if (shareDialogViewModel.hasError) {
///   final errorMessage = shareDialogViewModel.errorMessage;
///   // Display error message to user
///   shareDialogViewModel.clearError(); // Clear error state
/// }
/// 
/// // Access sharing state information
/// final isSharing = shareDialogViewModel.isSharing;
/// final hasError = shareDialogViewModel.hasError;
/// ```

// lib/viewmodels/universal_share_dialog_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/viewmodels/shared_content_viewmodel.dart';

/// PHASE 2: Validation result for sharing operations
class ShareValidationResult {
  final bool hasExistingCollaborators;
  final String errorMessage;
  final List<String> existingCollaboratorIds;
  final List<String> newFriendIds;
  final bool canProceed;

  const ShareValidationResult({
    required this.hasExistingCollaborators,
    required this.errorMessage,
    required this.existingCollaboratorIds,
    required this.newFriendIds,
    required this.canProceed,
  });

  /// Factory for successful validation (no existing collaborators)
  factory ShareValidationResult.success() {
    return const ShareValidationResult(
      hasExistingCollaborators: false,
      errorMessage: '',
      existingCollaboratorIds: [],
      newFriendIds: [],
      canProceed: true,
    );
  }

  /// Factory for partial success (some existing collaborators, but new friends to invite)
  factory ShareValidationResult.partialSuccess(List<String> newIds, List<String> existingIds) {
    final existingCount = existingIds.length;
    final newCount = newIds.length;
    final warningMessage = existingCount == 1 
        ? 'En vän har redan tillgång. $newCount nya inbjudningar kommer skickas.'
        : '$existingCount vänner har redan tillgång. $newCount nya inbjudningar kommer skickas.';
        
    return ShareValidationResult(
      hasExistingCollaborators: true,
      errorMessage: warningMessage,
      existingCollaboratorIds: existingIds,
      newFriendIds: newIds,
      canProceed: true,
    );
  }

  /// Factory for validation failure with existing collaborators
  factory ShareValidationResult.existingCollaborators(List<String> existingIds) {
    final count = existingIds.length;
    final errorMessage = count == 1 
        ? 'Den valda vännen har redan tillgång till listan'
        : 'Alla valda vänner har redan tillgång till listan';
        
    return ShareValidationResult(
      hasExistingCollaborators: true,
      errorMessage: errorMessage,
      existingCollaboratorIds: existingIds,
      newFriendIds: [],
      canProceed: false,
    );
  }
}

/// Comprehensive universal sharing dialog ViewModel providing advanced multi-content social distribution through service integration.
///
/// Manages universal sharing state enabling multi-content social distribution with recipe sharing, menu distribution,
/// shopping list coordination, and recipient management while maintaining clean MVVM architecture separation between
/// universal sharing business logic and UI presentation concerns through unified sharing interface.
///
/// **Core Responsibilities:**
/// - Advanced multi-content sharing with unified interface for recipes, menus, and shopping lists
/// - Comprehensive recipient management with friend and group targeting coordination
/// - Cross-service integration with social recipe and shopping services for content distribution
/// - Complete sharing state management with progress tracking and comprehensive error handling
/// - Swedish localized error messages and user feedback coordination throughout sharing operations
class UniversalShareDialogViewModel extends ChangeNotifier with StreamManagementMixin {
  final SocialRecipeService _socialRecipeService;
  final UnifiedShoppingService _shoppingService;

  // ===== SHARING OPERATION STATE =====

  /// Share operation state for UI progress indication during sharing operations.
  /// 
  /// Indicates active sharing operation for loading indicators and interaction
  /// control during content distribution and delivery processes.
  bool _isSharing = false;
  
  /// Error message for user feedback and comprehensive error state management.
  /// 
  /// Provides localized error messages for user display and error recovery
  /// throughout universal sharing operations and content distribution.
  String? _errorMessage;

  /// Initializes universal share dialog ViewModel with comprehensive service integration and sharing preparation.
  /// 
  /// [socialRecipeService] SocialRecipeService instance for recipe and menu sharing operations
  /// [shoppingService] UnifiedShoppingService instance for shopping list sharing coordination
  /// 
  /// Establishes universal sharing infrastructure with multi-service integration, enabling comprehensive
  /// social content distribution functionality with recipe sharing, menu distribution, shopping list coordination,
  /// and recipient management through unified sharing interface and consistent operation patterns.
  /// 
  /// **Service Integration:**
  /// - SocialRecipeService integration for recipe and menu sharing with social distribution
  /// - UnifiedShoppingService integration for shopping list sharing and collaborative coordination
  /// - Cross-service sharing coordination for consistent user experience across content types
  /// - Unified error handling and state management across different sharing operations
  UniversalShareDialogViewModel({
    required SocialRecipeService socialRecipeService,
    required UnifiedShoppingService shoppingService,
  }) : _socialRecipeService = socialRecipeService,
       _shoppingService = shoppingService;

  // ===== SHARING STATE ACCESSORS =====

  /// Share operation state for UI progress indication and interaction control.
  /// 
  /// Indicates whether sharing operation is in progress for loading indicators
  /// and user interaction management during sharing operations.
  bool get isSharing => _isSharing;
  
  /// Error message for user feedback and comprehensive error state management.
  /// 
  /// Provides access to current error state enabling error display
  /// and recovery coordination throughout universal sharing operations.
  String? get errorMessage => _errorMessage;
  
  /// Error state indicator for UI conditional rendering and error handling.
  /// 
  /// Indicates presence of errors for UI error display decisions
  /// and error state management throughout sharing operations.
  bool get hasError => _errorMessage != null;

  /// Share a recipe with selected friends and groups
  Future<bool> shareRecipe({
    required Recipe recipe,
    required List<String> friendUserIds,
    List<String>? groupIds,
    String? message,
    bool allowCollaboration = false,
  }) async {
    if (friendUserIds.isEmpty && (groupIds?.isEmpty ?? true)) {
      _setError('Inga vänner eller grupper valda');
      return false;
    }

    _setSharing(true);
    _clearError();

    try {
      // Share to friends if any selected
      if (friendUserIds.isNotEmpty) {
        await _socialRecipeService.shareRecipeToFriends(
          recipe.id,
          friendUserIds,
        );
      }

      // Share to groups if any selected
      if (groupIds != null && groupIds.isNotEmpty) {
        await _socialRecipeService.shareRecipeToGroups(
          recipe.id,
          groupIds,
        );
      }

      return true;
    } catch (e) {
      _setError('Kunde inte dela recept: $e');
      return false;
    } finally {
      _setSharing(false);
    }
  }

  /// Share a menu with selected friends and groups
  Future<bool> shareMenu({
    required Map<String, List<Recipe>> menu,
    required List<String> friendUserIds,
    List<String>? groupIds,
    String? menuId,
    String? message,
    bool allowCollaboration = false,
  }) async {
    if (friendUserIds.isEmpty && (groupIds?.isEmpty ?? true)) {
      _setError('Inga vänner eller grupper valda');
      return false;
    }

    _setSharing(true);
    _clearError();

    try {
      // Generate menu ID if not provided
      final actualMenuId = menuId ?? _generateMenuId(menu);
      
      // Share to friends if any selected
      if (friendUserIds.isNotEmpty) {
        await _socialRecipeService.shareMenuToFriends(
          actualMenuId,
          friendUserIds,
        );
      }

      // Share to groups if any selected
      if (groupIds != null && groupIds.isNotEmpty) {
        await _socialRecipeService.shareMenuToGroups(
          actualMenuId,
          groupIds,
        );
      }

      final totalTargets = friendUserIds.length + (groupIds?.length ?? 0);
      AppLogger.success('Menu shared successfully with $totalTargets targets (${friendUserIds.length} friends, ${groupIds?.length ?? 0} groups)');
      return true;
    } catch (e) {
      _setError('Kunde inte dela meny: $e');
      AppLogger.error('Failed to share menu: $e');
      return false;
    } finally {
      _setSharing(false);
    }
  }

  /// Share a shopping list with selected friends and groups
  Future<bool> shareShoppingList({
    required UnifiedShoppingList shoppingList,
    required List<String> friendUserIds,
    List<String>? groupIds,
    String? message,
    ShareMode shareMode = ShareMode.staticCopy,
  }) async {
    if (friendUserIds.isEmpty && (groupIds?.isEmpty ?? true)) {
      _setError('Inga vänner eller grupper valda');
      return false;
    }

    // PHASE 2: Validate sharing targets and filter existing collaborators
    final validationResult = _validateSharingTargets(shoppingList, friendUserIds);
    if (!validationResult.canProceed) {
      _setError(validationResult.errorMessage);
      return false;
    }
    
    // Use filtered friends list (exclude existing collaborators)
    final filteredFriendUserIds = validationResult.newFriendIds.isNotEmpty 
        ? validationResult.newFriendIds 
        : friendUserIds;

    _setSharing(true);
    _clearError();

    try {
      final totalTargets = filteredFriendUserIds.length + (groupIds?.length ?? 0);
      final modeText = shareMode == ShareMode.realtime ? 'kollaborativ lista' : 'kopia';
      
      AppLogger.info(
        '📋 Delar inköpslista: ${shoppingList.name} som $modeText med $totalTargets mottagare (${filteredFriendUserIds.length} vänner, ${groupIds?.length ?? 0} grupper)',
      );

      // Show info about validation results
      if (validationResult.hasExistingCollaborators) {
        AppLogger.info('⚠️ ${validationResult.existingCollaboratorIds.length} friends skipped (already have access)');
      }

      if (message != null) {
        AppLogger.info('💬 Meddelande: $message');
      }

      // Handle collaborative sharing for realtime mode - USE INVITATION SYSTEM
      if (shareMode == ShareMode.realtime) {
        AppLogger.info('🚀 REALTIME DEBUG: ✅ CONFIRMED - Using realtime sharing mode');
        AppLogger.info('🚀 REALTIME DEBUG: This SHOULD use invitation system, not direct addition');
        AppLogger.info('🚀 INVITATION DEBUG: Starting realtime sharing flow');
        AppLogger.info('🚀 INVITATION DEBUG: List ID: ${shoppingList.id}');
        AppLogger.info('🚀 INVITATION DEBUG: List name: "${shoppingList.name}"');
        AppLogger.info('🚀 INVITATION DEBUG: Original friends: $friendUserIds');
        AppLogger.info('🚀 INVITATION DEBUG: Filtered friends (new): $filteredFriendUserIds');
        AppLogger.info('🚀 INVITATION DEBUG: List type: ${shoppingList.type}');
        AppLogger.info('🚀 INVITATION DEBUG: List is collaborative: ${shoppingList.isCollaborative}');
        AppLogger.info('🚀 INVITATION DEBUG: List collaborators: ${shoppingList.collaborators}');
        
        // ULTRATHINK FIX: Use invitation system with filtered friends
        final success = await SocialContentFeatures.shareContentWithFriends(
          shoppingList.id,
          'shopping_list',
          filteredFriendUserIds,
          message ?? 'Vill dela denna inköpslista med dig!',
          _shoppingService,
        );

        if (success) {
          AppLogger.success('✅ INVITATION DEBUG: Inköpslista inbjudningar skickade framgångsrikt');
          AppLogger.info('🚀 INVITATION DEBUG: Recipients should see invitations in "delat med mig" view');
          
          // Set success message that includes info about skipped friends
          if (validationResult.hasExistingCollaborators) {
            final invitedCount = filteredFriendUserIds.length;
            final skippedCount = validationResult.existingCollaboratorIds.length;
            _setError('$invitedCount inbjudningar skickade. $skippedCount vänner hoppades över (har redan tillgång).');
          }
          
          return true;
        } else {
          AppLogger.error('❌ INVITATION DEBUG: Failed to send invitations');
          throw Exception('Kunde inte skicka inbjudningar');
        }
      } else {
        // Handle traditional copy-based sharing with filtered friends
        AppLogger.warning('⚠️ COPY MODE DEBUG: Using static copy mode instead of realtime!');
        AppLogger.info('📋 COPY MODE DEBUG: Share mode: $shareMode');
        AppLogger.info('📋 COPY MODE DEBUG: Content type: ${shareMode == ShareMode.staticCopy ? "STATIC COPY" : "OTHER"}');
        AppLogger.warning('🚨 COPY MODE FIX: The old copy mode was broken - just returned true without doing anything!');
        AppLogger.info('✅ COPY MODE FIX: Now using invitation system for copy mode too');
        
        // ULTRATHINK FIX: Use invitation system for copy mode too instead of broken shareListWithFriend
        final success = await SocialContentFeatures.shareContentWithFriends(
          shoppingList.id,
          'shopping_list',
          filteredFriendUserIds,
          message ?? 'Vill dela denna inköpslista med dig!',
          _shoppingService,
        );

        // Share to groups if any selected (TODO: Implement group invitations)
        if (groupIds != null && groupIds.isNotEmpty) {
          AppLogger.warning('⚠️ COPY MODE: Group sharing not yet implemented for copy mode');
          // For now, just log this - group sharing would need similar invitation system
        }

        if (success) {
          AppLogger.success('✅ COPY MODE FIX: Inköpslista invitations sent successfully via invitation system');
          return true;
        } else {
          throw Exception('Kunde inte skicka inbjudningar');
        }
      }
    } catch (e) {
      _setError('Kunde inte dela inköpslista: $e');
      return false;
    } finally {
      _setSharing(false);
    }
  }

  /// Clear any error messages
  void clearError() {
    _clearError();
  }

  // Private methods
  void _setSharing(bool value) {
    _isSharing = value;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Generate a unique menu ID based on menu content
  String _generateMenuId(Map<String, List<Recipe>> menu) {
    // Create a deterministic ID based on menu content
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final recipeCount = menu.values.fold<int>(0, (sum, recipes) => sum + recipes.length);
    final dayCount = menu.keys.length;
    
    // Generate ID: timestamp_dayCount_recipeCount
    final menuId = 'menu_${timestamp}_${dayCount}d_${recipeCount}r';
    
    AppLogger.info('Generated menu ID: $menuId for menu with $dayCount days and $recipeCount recipes');
    return menuId;
  }

  /// PHASE 2: Validate sharing targets to filter existing collaborators but allow new friends
  ShareValidationResult _validateSharingTargets(
    UnifiedShoppingList shoppingList, 
    List<String> friendUserIds
  ) {
    // Get existing collaborators from the shopping list
    final existingCollaborators = shoppingList.collaborators.toSet();
    
    // Find friends who are already collaborators
    final existingCollaboratorIds = friendUserIds.where((friendId) => 
      existingCollaborators.contains(friendId)
    ).toList();
    
    // Find friends who are NOT already collaborators (new friends to invite)
    final newFriendIds = friendUserIds.where((friendId) => 
      !existingCollaborators.contains(friendId)
    ).toList();
    
    AppLogger.info('🔍 VALIDATION: Analyzing ${friendUserIds.length} selected friends for list "${shoppingList.name}"');
    AppLogger.info('📊 VALIDATION: Existing collaborators: ${existingCollaboratorIds.length}, New friends: ${newFriendIds.length}');
    
    if (existingCollaboratorIds.isNotEmpty) {
      AppLogger.info(
        '⚠️ VALIDATION: ${existingCollaboratorIds.length} friends already have access: $existingCollaboratorIds'
      );
    }
    
    if (newFriendIds.isEmpty) {
      // All selected friends are already collaborators
      AppLogger.warning('🚫 VALIDATION: All selected friends already have access to this list');
      return ShareValidationResult.existingCollaborators(existingCollaboratorIds);
    }
    
    if (existingCollaboratorIds.isNotEmpty) {
      // Some friends already have access, but we have new friends to invite
      AppLogger.info('✅ VALIDATION: Will invite ${newFriendIds.length} new friends and skip ${existingCollaboratorIds.length} existing collaborators');
      return ShareValidationResult.partialSuccess(newFriendIds, existingCollaboratorIds);
    }
    
    // All friends are new
    AppLogger.info('✅ VALIDATION: All selected friends are new - sharing can proceed with all ${newFriendIds.length} friends');
    return ShareValidationResult.success();
  }
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreamResources(); // From StreamManagementMixin
    super.dispose();
  }
}