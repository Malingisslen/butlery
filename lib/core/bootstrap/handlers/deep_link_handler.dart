/// Deep link handling for the application.
/// This handler manages all deep link processing including friend invitations,
/// recipe sharing, menu sharing, and shopping list sharing. Extracted from
/// the main.dart to provide clean separation of concerns.
library;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/router/deferred_module_loader.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';
import 'package:butlery/repositories/interfaces/acquisition_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/services/analytics/acquisition_milestone.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';

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
      return;
    }

    try {
      // Web takes a different path: read deep-link parameters from the
      // browser URL (web share target writes them as query params).
      if (kIsWeb) {
        // On web, read the browser URL for deep link parameters
        final uri = Uri.base;
        // Handle web share target: shared content arrives as query params
        final sharedUrl = uri.queryParameters['url'];
        final sharedText = uri.queryParameters['text'];
        if (sharedUrl != null && sharedUrl.isNotEmpty) {
          _pendingDeepLink =
              'butlery://import?url=${Uri.encodeComponent(sharedUrl)}';
        } else if (sharedText != null && sharedText.isNotEmpty) {
          // Text might contain a URL
          final urlMatch = RegExp(
            r'https?://[^\s<>"{}|\\^`\[\]]+',
          ).firstMatch(sharedText);
          if (urlMatch != null) {
            _pendingDeepLink =
                'butlery://import?url=${Uri.encodeComponent(urlMatch.group(0)!)}';
          }
        } else if (uri.path.length > 1 || uri.queryParameters.isNotEmpty) {
          _pendingDeepLink = uri.toString();
        }
        _isInitialized = true;
        return;
      }

      // `getInitialLinkString` (not `getInitialLink`) avoids Uri.parse
      // normalization and preserves the prior `receivedIntent.data` String
      // contract verbatim.
      if (!kIsWeb) {
        _pendingDeepLink = await AppLinks().getInitialLinkString();
      }

      _isInitialized = true;
    } catch (e) {
      // Don't rethrow - app should continue even if deep links fail
      _isInitialized = true;
    }
  }

  /// Process any pending deep link with the provided context.
  /// This should be called once the app is fully initialized and has
  /// a valid navigation context available.
  Future<void> processPendingDeepLink(BuildContext context) async {
    if (_pendingDeepLink != null) {
      await processDeepLink(_pendingDeepLink!, context);
      _pendingDeepLink = null;
    }
  }

  /// Process a deep link URL and navigate to the appropriate view.
  Future<void> processDeepLink(String deepLinkUrl, BuildContext context) async {
    try {
      // Auth gate: require authentication before processing deep links
      final authRepo = ServiceLocator.get<AuthRepository>();
      if (authRepo.currentUser == null) {
        _pendingDeepLink = deepLinkUrl;
        return;
      }

      final uri = Uri.parse(deepLinkUrl);

      // Host validation for custom scheme
      if (uri.scheme == 'butlery' &&
          uri.host.isNotEmpty &&
          uri.host != 'butlery.app') {
        return;
      }

      final path = uri.path;
      final params = uri.queryParameters;

      // P8-21: Campaign attribution from UTM parameters
      _trackCampaignAttribution(params);

      if (!context.mounted) {
        return;
      }

      if (path.startsWith('/invite')) {
        await _handleInvitationLink(params, context);
      } else if (path.startsWith('/recipe')) {
        await _handleRecipeLink(params, context);
      } else if (path.startsWith('/menu')) {
        await _handleMenuLink(params, context);
      } else if (path.startsWith('/shopping')) {
        await _handleShoppingLink(params, context);
      } else if (path.startsWith('/profile')) {
        _handleProfileLink(params, context);
      } else if (path.startsWith('/import') ||
          (uri.scheme == 'butlery' && uri.host == 'import')) {
        _handleImportLink(params, context);
      }
    } catch (e) {
      // Silently handle deep link processing errors
    }
  }

  /// P8-21: Track UTM campaign attribution from deep links.
  ///
  /// BUT-612: also persists first-arrival UTM as Firebase user properties
  /// AND mirrors to Firestore (users/{uid}/acquisition/current) so retention
  /// can be sliced by acquisition channel. First-write-wins — later UTM
  /// clicks log the `campaign_click` event but do not overwrite attribution.
  void _trackCampaignAttribution(Map<String, String> params) {
    final utmSource = params['utm_source'];
    if (utmSource == null || utmSource.isEmpty) return;

    final utmMedium = params['utm_medium'].orEmpty();
    final utmCampaign = params['utm_campaign'].orEmpty();

    try {
      final analytics = ServiceLocator.tryGet<AnalyticsService>();
      analytics?.logEvent(
        name: AnalyticsEvents.campaignClick,
        parameters: {
          'utm_source': utmSource,
          'utm_medium': utmMedium,
          'utm_campaign': utmCampaign,
        },
      );

      // BUT-612: persist as user properties + Firestore subdoc for cohorting.
      // Fire-and-forget — never block deep-link routing on attribution work.
      final repo = ServiceLocator.tryGet<AcquisitionRepository>();
      final authRepo = ServiceLocator.tryGet<AuthRepository>();
      AcquisitionMilestone.recordIfFirst(
        analytics: analytics,
        repository: repo,
        userId: authRepo?.currentUserId,
        utmSource: utmSource,
        utmMedium: utmMedium,
        utmCampaign: utmCampaign,
      );
    } catch (e) {
      // Campaign tracking not critical
    }
  }

  /// Validate that an ID looks like a valid Firestore document ID.
  static bool _isValidFirestoreId(String id) {
    if (id.length < 20 || id.length > 28) return false;
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(id);
  }

  /// Handle friend invitation deep links.
  Future<void> _handleInvitationLink(
    Map<String, String> params,
    BuildContext context,
  ) async {
    final invitationId = params['id'];
    final fromUserId = params['from'];
    final type = params['type'];

    if (invitationId != null &&
        fromUserId != null &&
        _isValidFirestoreId(invitationId) &&
        _isValidFirestoreId(fromUserId)) {
      // Pre-load social module before navigation
      await _ensureSocialModuleLoaded();

      // Navigate to appropriate view based on invitation type
      if (context.mounted) {
        if (type == 'friend') {
          // Navigate to friend requests view
          Navigator.of(context).pushNamed(Routes.friendRequests);
        } else {
          // Default to friends list for unknown invitation types
          Navigator.of(context).pushNamed(Routes.friends);
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

    if (recipeId != null && _isValidFirestoreId(recipeId)) {
      // Fetch full Recipe object — router expects Recipe, not String ID
      final recipeRepo = ServiceLocator.get<RecipeRepository>();
      final recipe = await recipeRepo.read(recipeId);
      if (recipe != null && context.mounted) {
        Navigator.of(context).pushNamed(
          Routes.recipeDetail,
          arguments: recipe,
        );
      }
    }
  }

  /// Handle menu sharing deep links.
  Future<void> _handleMenuLink(
    Map<String, String> params,
    BuildContext context,
  ) async {
    final menuId = params['id'];

    if (menuId != null && _isValidFirestoreId(menuId)) {
      await _ensureSocialModuleLoaded();

      // Fetch full SharedMenu object — router expects SharedMenu, not String ID
      final menuRepo = ServiceLocator.get<FirebaseSharedMenuRepository>();
      final menu = await menuRepo.getSharedMenu(menuId);
      if (menu != null && context.mounted) {
        Navigator.of(context).pushNamed(Routes.menuPreview, arguments: menu);
      }
    }
  }

  /// Handle shopping list sharing deep links.
  Future<void> _handleShoppingLink(
    Map<String, String> params,
    BuildContext context,
  ) async {
    final listId = params['id'];

    if (listId != null && _isValidFirestoreId(listId)) {
      // Pre-load social module before navigation
      await _ensureSocialModuleLoaded();

      if (context.mounted) {
        // Navigate to collaborative shopping view
        Navigator.of(
          context,
        ).pushNamed(Routes.collaborativeShopping, arguments: listId);
      }
    }
  }

  /// Pre-load social module for deep link navigation
  Future<void> _ensureSocialModuleLoaded() async {
    if (DeferredModuleLoader.isRegistered('social') &&
        !DeferredModuleLoader.isLoaded('social')) {
      try {
        await DeferredModuleLoader.ensureLoaded('social');
      } catch (e) {
        AppLogger.warning('Failed to pre-load social module for deep link: $e');
      }
    }
  }

  /// Handle public profile deep link — navigate to public profile view.
  void _handleProfileLink(
    Map<String, String> params,
    BuildContext context,
  ) {
    final userId = params['id'];
    if (userId != null && _isValidFirestoreId(userId)) {
      if (context.mounted) {
        Navigator.of(
          context,
        ).pushNamed(Routes.publicProfile, arguments: userId);
      }
    }
  }

  /// Handle import link from web share target — navigate to add recipe with URL pre-filled.
  void _handleImportLink(
    Map<String, String> params,
    BuildContext context,
  ) {
    final url = params['url'];
    if (url != null && url.isNotEmpty) {
      // Land a shared URL on Smart Import (which prefills it), not the generic
      // add-recipe hub that ignored the argument.
      Navigator.of(context).pushNamed(Routes.smartImport, arguments: url);
    }
  }

  /// Reset the handler state (for testing).
  void reset() {
    _isInitialized = false;
    _pendingDeepLink = null;
  }

  /// Get debug information about the handler state.
  Map<String, dynamic> get debugInfo => kDebugMode
      ? {
          'initialized': _isInitialized,
          'has_pending_link': _pendingDeepLink != null,
          'pending_link': _pendingDeepLink,
        }
      : {};
}
