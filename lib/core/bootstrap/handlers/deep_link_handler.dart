/// Deep link handling for the application.
/// This handler manages all deep link processing including friend invitations,
/// recipe sharing, menu sharing, and shopping list sharing. Extracted from
/// the main.dart to provide clean separation of concerns.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_intent/receive_intent.dart' as receive_intent;
import 'package:butlery/core/constants/routes.dart';

/// Deep link handler for processing incoming shared content.
/// Handles various types of deep links including:
/// - Friend invitations (/invite)
/// - Recipe sharing (/recipe)
/// - Menu sharing (/menu)
/// - Shopping list sharing (/shopping)
/// Provides both initialization-time handling and runtime processing.
class DeepLinkHandler {
  static final DeepLinkHandler _instance = DeepLinkHandler._internal();
  factory DeepLinkHandler() => _instance;
  DeepLinkHandler._internal();

  bool _isInitialized = false;
  String? _pendingDeepLink;

  /// Whether the deep link handler has been initialized.
  bool get isInitialized => _isInitialized;

  /// Initialize deep link handling.
  /// This should be called during app startup to set up deep link processing.
  /// It will handle any deep links that were received during app launch.
  Future<void> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) {
        debugPrint('⚠️ DeepLinkHandler already initialized');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('🔗 Initializing deep link handler...');
    }

    try {
      // Check if platform supports deep links via receive_intent
      // Web platform doesn't support this plugin
      if (kIsWeb) {
        if (kDebugMode) {
          debugPrint('🌐 Web platform detected - deep links via receive_intent not supported');
          debugPrint('💡 Web deep links should be handled via URL parameters in the browser');
        }
        _isInitialized = true;
        return;
      }

      // Only attempt to use receive_intent on mobile platforms
      // We can't check Platform.isAndroid/iOS on web, so we rely on kIsWeb check above
      // and assume non-web means mobile for now (desktop support can be added later)
      if (!kIsWeb) {
        // Get initial deep link from app launch
        final receivedIntent = await receive_intent.ReceiveIntent.getInitialIntent();
        
        if (receivedIntent != null && receivedIntent.data != null) {
          if (kDebugMode) {
            debugPrint('🔗 Initial deep link received: ${receivedIntent.data}');
          }
          
          // Store the deep link for processing when context is available
          _pendingDeepLink = receivedIntent.data;
        }
        
        // Note: receive_intent package doesn't support streaming
        // Deep links while app is running would typically be handled by
        // the operating system's intent system automatically
        
        if (kDebugMode) {
          debugPrint('📱 Mobile platform - deep link handling enabled');
        }
      }
      
      _isInitialized = true;
      
      if (kDebugMode) {
        debugPrint('✅ Deep link handler initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Deep link initialization failed: $e');
      }
      // Don't rethrow - app should continue even if deep links fail
      _isInitialized = true;
    }
  }

  /// Process any pending deep link with the provided context.
  /// This should be called once the app is fully initialized and has
  /// a valid navigation context available.
  Future<void> processPendingDeepLink(BuildContext context) async {
    if (_pendingDeepLink != null) {
      if (kDebugMode) {
        debugPrint('🔗 Processing pending deep link: $_pendingDeepLink');
      }
      
      await processDeepLink(_pendingDeepLink!, context);
      _pendingDeepLink = null;
    }
  }

  /// Process a deep link URL and navigate to the appropriate view.
  /// Parses the incoming URL to extract the path and query parameters,
  /// then routes to the correct handler based on the content type.
  /// [deepLinkUrl] The complete deep link URL to process
  /// [context] The BuildContext for navigation
  /// Supports the following URL patterns:
  /// - `/invite?id=xxx&from=yyy&type=friend` - Friend invitations
  /// - `/recipe?id=xxx&from=yyy` - Shared recipes
  /// - `/menu?id=xxx&from=yyy` - Shared menus
  /// - `/shopping?id=xxx&from=yyy` - Shared shopping lists
  Future<void> processDeepLink(String deepLinkUrl, BuildContext context) async {
    try {
      final uri = Uri.parse(deepLinkUrl);
      if (kDebugMode) {
        debugPrint('🔗 Processing deep link: ${uri.path}');
      }

      // Extract path and parameters
      final path = uri.path;
      final params = uri.queryParameters;

      // Ensure context is still valid
      if (!context.mounted) {
        if (kDebugMode) {
          debugPrint('⚠️ Context not mounted, cannot process deep link');
        }
        return;
      }

      // Route based on deep link type
      if (path.startsWith('/invite')) {
        await _handleInvitationLink(params, context);
      } else if (path.startsWith('/recipe')) {
        await _handleRecipeLink(params, context);
      } else if (path.startsWith('/menu')) {
        await _handleMenuLink(params, context);
      } else if (path.startsWith('/shopping')) {
        await _handleShoppingLink(params, context);
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ Unknown deep link path: $path');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Error processing deep link: $e');
      }
    }
  }

  /// Handle friend invitation deep links.
  Future<void> _handleInvitationLink(
    Map<String, String> params,
    BuildContext context,
  ) async {
    final invitationId = params['id'];
    final fromUserId = params['from'];
    final type = params['type'];

    if (invitationId != null && fromUserId != null) {
      if (kDebugMode) {
        debugPrint('🔗 Handling invitation: $type from $fromUserId');
      }
      
      // Navigate to appropriate view based on invitation type
      if (context.mounted) {
        if (type == 'friend') {
          // Navigate to friend requests view
          GoRouter.of(context).push(Routes.friendRequests);
        } else {
          // Default to friends list for unknown invitation types
          GoRouter.of(context).push(Routes.friends);
        }
      }
    }
  }

  /// Handle recipe sharing deep links.
  Future<void> _handleRecipeLink(
    Map<String, String> params,
    BuildContext context,
  ) async {
    final recipeId = params['id'];
    final fromUserId = params['from'];

    if (recipeId != null) {
      if (kDebugMode) {
        debugPrint('🔗 Handling recipe link: $recipeId from $fromUserId');
      }
      
      if (context.mounted) {
        // Navigate to recipe detail view with recipe ID as query parameter
        GoRouter.of(context).push('${Routes.receptDetalj}?recipeId=$recipeId');
      }
    }
  }

  /// Handle menu sharing deep links.
  Future<void> _handleMenuLink(
    Map<String, String> params,
    BuildContext context,
  ) async {
    final menuId = params['id'];
    final fromUserId = params['from'];

    if (menuId != null) {
      if (kDebugMode) {
        debugPrint('🔗 Handling menu link: $menuId from $fromUserId');
      }
      
      if (context.mounted) {
        // Navigate to shared with me view to see the menu
        GoRouter.of(context).push(Routes.shared);
      }
    }
  }

  /// Handle shopping list sharing deep links.
  Future<void> _handleShoppingLink(
    Map<String, String> params,
    BuildContext context,
  ) async {
    final listId = params['id'];
    final fromUserId = params['from'];

    if (listId != null) {
      if (kDebugMode) {
        debugPrint('🔗 Handling shopping list link: $listId from $fromUserId');
      }
      
      if (context.mounted) {
        // Navigate to collaborative shopping view
        GoRouter.of(context).push(Routes.collaborativeShopping);
      }
    }
  }

  /// Reset the handler state (for testing).
  void reset() {
    _isInitialized = false;
    _pendingDeepLink = null;
    
    if (kDebugMode) {
      debugPrint('🔄 DeepLinkHandler reset');
    }
  }

  /// Get debug information about the handler state.
  Map<String, dynamic> get debugInfo => {
        'initialized': _isInitialized,
        'has_pending_link': _pendingDeepLink != null,
        'pending_link': _pendingDeepLink,
      };
}