// lib/services/social/modules/recipe_share_request_module.dart

import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/repositories/firebase/firebase_social_request_repository.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/error_sanitizer.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Module handling the recipe-share *request* flow: a user asking a friend
/// (the owner) to share a recipe, and the owner accepting that request.
///
/// Extracted from [SocialRecipeService] to keep that service under the
/// 500-line limit. Logic is unchanged — same idempotency, same l10n keys,
/// same notification payload.
class RecipeShareRequestModule {
  final FirebaseSocialRequestRepository socialRequestRepository;
  final PermissionService permissionService;
  final UserService userService;

  RecipeShareRequestModule({
    required this.socialRequestRepository,
    required this.permissionService,
    required this.userService,
  });

  /// Last sanitized error for the most recent operation, mirroring the
  /// service's `_error` semantics so callers can surface a banner.
  String? _error;

  String? get error => _error;

  /// Ask [ownerId] to share [recipeId] (titled [recipeTitle]) with the current
  /// user. Idempotent: if a pending recipe-share request already exists for the
  /// (requester, owner, recipe) triple, this is a no-op that still returns true
  /// — so a double-tap can't write a duplicate request or fire a duplicate
  /// notification. Returns false only when there is no authenticated user.
  Future<bool> requestRecipeShare({
    required String ownerId,
    required String recipeId,
    required String recipeTitle,
  }) async {
    _error = null;
    final me = permissionService.currentUserId;
    if (me == null) return false;

    try {
      final alreadyRequested = await socialRequestRepository
          .recipeShareRequestExists(me, ownerId, recipeId);
      if (alreadyRequested) return true;

      final fromUserName =
          userService.currentDisplayName ??
          AppLocale.current.displayUnknownUser;

      final request = SocialRequest.recipeShareRequest(
        fromUserId: me,
        toUserId: ownerId,
        recipeId: recipeId,
        recipeTitle: recipeTitle,
        fromUserName: fromUserName,
      );
      await socialRequestRepository.createRequest(request);

      try {
        await _sendRecipeShareRequestNotification(
          ownerId: ownerId,
          fromUserName: fromUserName,
          recipeId: recipeId,
          recipeTitle: recipeTitle,
          requestId: request.id,
          fromUserId: me,
        );
      } catch (e) {
        AppLogger.warning(
          'Recipe share request notification failed (non-fatal): $e',
        );
      }
      return true;
    } catch (e) {
      _captureAndLog('Failed to request recipe share', e);
      return false;
    }
  }

  /// Owner-side accept: share [request]'s recipe with the requester and mark the
  /// request accepted. Returns false if the request carries no recipeId or if
  /// the share itself fails (in which case the status is NOT flipped — we never
  /// claim accepted on a failed share).
  Future<bool> acceptRecipeShareRequest(SocialRequest request) async {
    _error = null;
    final recipeId = request.recipeId;
    if (recipeId == null) return false;

    final me = permissionService.currentUserId;
    if (me == null || me != request.toUserId) return false;

    try {
      // Share in place: add the requester to the ORIGINAL recipe's
      // memberPermissions. The read path (fetchFriendRecipe) and the firestore
      // rule both key off the original doc, so a new collaborative copy would
      // leave the requester unable to open the recipe.
      final shareResult = await ServiceLocator.get<SocialRecipeCoordinator>()
          .shareRecipeWithUsers(recipeId, [
            request.fromUserId,
          ], ResourcePermission.viewer);
      // BUT-1503: accept once access was actually granted (the primary
      // memberPermissions write succeeded — the requester can open the recipe).
      // A failed secondary discovery-doc write (accessGranted but not
      // fullyShared) must NOT leave the request stuck pending forever, since
      // the requester already has access; the discovery doc self-heals.
      if (!shareResult.accessGranted) return false;

      await socialRequestRepository.updateRequestStatus(
        request.id,
        {'status': SocialRequestStatus.accepted.name},
      );
      return true;
    } catch (e) {
      _captureAndLog('Failed to accept recipe share request', e);
      return false;
    }
  }

  /// Deterministic (no-LLM) notification for a recipe-share request. Text is
  /// sourced from l10n keys at call time, mirroring the friend-request
  /// notification's category/priority so it surfaces immediately.
  Future<void> _sendRecipeShareRequestNotification({
    required String ownerId,
    required String fromUserName,
    required String recipeId,
    required String recipeTitle,
    required String requestId,
    required String fromUserId,
  }) async {
    final notificationService = ServiceLocator.tryGet<NotificationService>();
    if (notificationService == null) return;

    final strategy = NotificationStrategy(
      type: NotificationType.immediate,
      priority: NotificationPriority.critical,
      category: NotificationCategory.friends,
      localization: {
        'title_sv': AppLocale.current.recipeShareRequestNotifTitle,
        'title_en': AppLocale.current.recipeShareRequestNotifTitle,
        'body_sv': AppLocale.current.recipeShareRequestNotifBody(
          fromUserName,
          recipeTitle,
        ),
        'body_en': AppLocale.current.recipeShareRequestNotifBody(
          fromUserName,
          recipeTitle,
        ),
      },
    );

    await notificationService.sendImmediateNotification(
      targetUserIds: [ownerId],
      strategy: strategy,
      variables: const {},
      additionalData: {
        'type': NotificationPayloadType.recipeShareRequest,
        'requestId': requestId,
        'recipeId': recipeId,
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
      },
    );
  }

  void _captureAndLog(String message, Object e) {
    AppLogger.error(message, e);
    _error = sanitizeErrorForUser(e);
  }
}
