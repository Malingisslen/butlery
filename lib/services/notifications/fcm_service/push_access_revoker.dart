import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/user_service.dart';

/// Consent-revoke cleanup of the FCM token in the SDK and on the profile.
class PushAccessRevoker {
  PushAccessRevoker._();

  /// Delete FCM token from SDK + Firestore + memory after consent revoke
  /// (BUT-573). Best-effort: each cleanup is independent so partial success
  /// beats total failure. SDK + Firestore deletes run in parallel — they
  /// don't depend on each other.
  ///
  /// Companion: NotificationService.`_handleConsentChange` →
  /// FCMTokenManager.`clearLocalToken()` covers the per-user SecureStorage
  /// cache (BUT-754). The split is intentional: FCMService is app-singleton
  /// (SDK + Firestore + memory); FCMTokenManager is per-user (SecureStorage +
  /// instance memory). Each half owns its own lifecycle scope.
  static Future<void> revoke({
    required FirebaseMessaging messaging,
    required UserService? Function() getUserService,
  }) async {
    final userService = getUserService();
    final hasUserService = userService != null;

    await Future.wait<void>([
      // ignore: deprecated_member_use
      messaging.deleteToken().catchError((e) {
        AppLogger.warning('⚠️ FCM: Failed to delete SDK token: $e');
      }),
      if (hasUserService)
        userService.clearFCMToken().catchError((e) {
          AppLogger.warning('⚠️ FCM: Failed to clear profile token: $e');
        }),
    ]);

    if (!hasUserService) {
      AppLogger.info(
        '🔔 FCM: UserService not registered — skipping profile-token clear',
      );
    }
  }
}
