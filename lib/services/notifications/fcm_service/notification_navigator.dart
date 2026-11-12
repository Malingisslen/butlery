import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/stored_display_name.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/widgets/common/feedback_fab.dart' show appNavigatorKey;

/// Opens the screen a tapped push notification points at.
class NotificationNavigator {
  NotificationNavigator({
    required RecipeRepository Function() getRecipeRepository,
    required FirebaseSharedMenuRepository Function() getSharedMenuRepository,
    required UnifiedRecipeService Function() getRecipeService,
    required PermissionService Function() getPermissionService,
  }) : _getRecipeRepository = getRecipeRepository,
       _getSharedMenuRepository = getSharedMenuRepository,
       _getRecipeService = getRecipeService,
       _getPermissionService = getPermissionService;

  final RecipeRepository Function() _getRecipeRepository;
  final FirebaseSharedMenuRepository Function() _getSharedMenuRepository;
  final UnifiedRecipeService Function() _getRecipeService;
  final PermissionService Function() _getPermissionService;

  /// Uses [appNavigatorKey] to avoid stale BuildContext crashes.
  Future<void> handle(RemoteMessage message) async {
    try {
      final data = message.data;
      final notificationType = data['type'];
      final screen = data['screen'];

      AppLogger.info(
        '🔔 Handling notification navigation: type=$notificationType, screen=$screen',
      );

      final navigator = appNavigatorKey.currentState;
      if (navigator == null) {
        AppLogger.warning('⚠️ Cannot navigate - no navigator available');
        return;
      }

      switch (notificationType) {
        case NotificationPayloadType.friendRequest:
          navigator.pushNamed(Routes.friendRequests);
          break;
        case NotificationPayloadType.recipeShared:
          await _navigateToSharedRecipe(navigator, data);
          break;
        case NotificationPayloadType.collaborationInvite:
          await _navigateToCollaboration(navigator, data);
          break;
        case NotificationPayloadType.recipeComment:
          await _navigateToSharedRecipe(
            navigator,
            data,
            scrollToComments: true,
          );
          break;
        case NotificationPayloadType.recipeShareRequest:
          await _navigateToOwnRecipeForShareRequest(navigator, data);
          break;
        default:
          AppLogger.warning(
            '⚠️ Unknown notification type for navigation: $notificationType',
          );
      }
    } catch (e) {
      AppLogger.error('❌ Failed to handle notification navigation', e);
    }
  }

  /// BUT-1744: the sender stores no placeholder, so the fallback is resolved
  /// here, in the recipient's own language.
  static String shareRequestSenderName(Map<String, dynamic> data) {
    return storedNameOr(
      data['fromUserName'] as String?,
      AppLocale.current.displayUnknownUser,
    );
  }

  Future<void> _navigateToSharedRecipe(
    NavigatorState navigator,
    Map<String, dynamic> data, {
    bool scrollToComments = false,
  }) async {
    final recipeId = data['recipeId'] as String?;
    if (recipeId == null) return;

    final recipeRepo = _getRecipeRepository();
    final recipe = await recipeRepo.read(recipeId);
    if (recipe != null) {
      final arguments = scrollToComments
          ? <String, dynamic>{'recipe': recipe, 'scrollToComments': true}
          : recipe;
      navigator.pushNamed(Routes.recipeDetail, arguments: arguments);
    }
  }

  /// Opens the owner's own recipe with a one-tap share-back banner.
  /// Tapped when the owner receives a "X wants your recipe" push notification.
  Future<void> _navigateToOwnRecipeForShareRequest(
    NavigatorState navigator,
    Map<String, dynamic> data,
  ) async {
    final recipeId = data['recipeId'] as String?;
    final requestId = data['requestId'] as String?;
    if (recipeId == null || requestId == null) return;

    final fromUserId = data['fromUserId'] as String?;
    if (fromUserId == null || fromUserId.isEmpty) return;
    final fromUserName = shareRequestSenderName(data);

    final recipe = _getRecipeService().getRecipeById(
      recipeId,
    );
    if (recipe == null) return;

    final currentUserId = _getPermissionService().currentUserId;

    final request = SocialRequest(
      id: requestId,
      type: SocialRequestType.recipeShareRequest,
      fromUserId: fromUserId.orEmpty(),
      toUserId: currentUserId.orEmpty(),
      recipeId: recipeId,
      fromUserName: fromUserName,
    );

    navigator.pushNamed(
      Routes.recipeDetail,
      arguments: <String, dynamic>{'recipe': recipe, 'shareRequest': request},
    );
  }

  Future<void> _navigateToCollaboration(
    NavigatorState navigator,
    Map<String, dynamic> data,
  ) async {
    final resourceId = data['resourceId'] as String?;
    final resourceType = data['resourceType'] as String?;

    if (resourceId == null || resourceType == null) return;

    switch (resourceType) {
      case 'recipe':
        final recipeRepo = _getRecipeRepository();
        final recipe = await recipeRepo.read(resourceId);
        if (recipe != null) {
          navigator.pushNamed(Routes.recipeDetail, arguments: recipe);
        }
        break;
      case 'menu':
        final menuRepo = _getSharedMenuRepository();
        final menu = await menuRepo.getSharedMenu(resourceId);
        if (menu != null) {
          navigator.pushNamed(Routes.menuPreview, arguments: menu);
        }
        break;
      case 'shopping_list':
        navigator.pushNamed(
          Routes.collaborativeShopping,
          arguments: resourceId,
        );
        break;
      default:
        AppLogger.warning(
          '⚠️ Unknown collaboration resource type: $resourceType',
        );
    }
  }
}
