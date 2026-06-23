import 'package:cloud_functions/cloud_functions.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/notifications/notification_service.dart'
    as notif;
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/repositories/interfaces/search_repository.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// BUT-788: client wrapper for the server-side account-deletion callable.
///
/// The cascade itself lives in `functions/src/account/request-account-
/// deletion.ts`. This class is now a thin orchestrator:
///
///   1. Pre-CF: clean third-party indexes the CF can't reach (Algolia /
///      MeiliSearch search index, local offline cache).
///   2. Invoke the `requestAccountDeletion` callable. The CF runs the
///      Firestore cascade + Storage cleanup as Admin SDK, then calls
///      `admin.auth().deleteUser(uid)` LAST.
///   3. Post-CF: reset local notification state and sign the user out.
///
/// **No client-side `user.delete()` call** — that was the source of the
/// auth-context race the rewrite eliminated.
///
/// **Re-auth requirement**: the CF rejects requests when the ID token's
/// `auth_time` claim is older than 5 minutes. The error surfaces here as
/// `result['requiresReauth'] = true`; callers prompt for re-authentication
/// and retry.
class AccountDeletionService extends BaseService {
  @override
  String get serviceName => 'AccountDeletionService';

  final AuthService _authService;
  final FirebaseFunctions _functions;
  final SearchRepository? _searchRepository;
  final OfflineService? _offlineService;
  static const String _logTag = 'AccountDeletionService';
  static const String _callableName = 'requestAccountDeletion';

  AccountDeletionService({
    required AuthService authService,
    required FirebaseFunctions functions,
    SearchRepository? searchRepository,
    OfflineService? offlineService,
  }) : _authService = authService,
       _functions = functions,
       _searchRepository = searchRepository,
       _offlineService = offlineService;

  /// Delete this user's account.
  ///
  /// Result map shape preserved for backwards compatibility with
  /// `ProfileViewModel`:
  ///   - `success` (bool) — overall outcome.
  ///   - `deletedCollections` (`List<String>`) — collections the CF deleted.
  ///   - `failedCollections` (`List<String>`) — collections that failed.
  ///   - `errors` (`List<String>`) — error messages.
  ///   - `auditLogId` (String?) — id of the deletion-audit row.
  ///   - `requiresReauth` (bool) — set when the CF rejects on stale
  ///     `auth_time`; caller must trigger re-authentication and retry.
  Future<Map<String, dynamic>> deleteUserAccount({
    required String reason,
    bool createAuditLog = true,
  }) async {
    final result = <String, dynamic>{
      'success': false,
      'deletedCollections': <String>[],
      'failedCollections': <String>[],
      'errors': <String>[],
      'auditLogId': null,
    };

    final uid = _authService.currentUserId;
    if (uid == null) {
      result['errors'] = ['No authenticated user'];
      return result;
    }

    app_logger.AppLogger.info('[$_logTag] Starting account deletion');

    // Pre-CF: search-index cleanup. Once `auth.deleteUser` runs server-side,
    // the client's search-SDK credentials are tied to a now-gone user, so
    // any Algolia/Meili call would fail. Run this BEFORE the CF call.
    if (_searchRepository != null) {
      await _cleanupSearchIndex(uid, result);
    }

    // Pre-CF: clear local offline cache. Client-only — no CF equivalent.
    if (_offlineService != null) {
      try {
        await _offlineService.clearUserData(uid);
      } catch (e) {
        app_logger.AppLogger.warning(
          '[$_logTag] Offline cache cleanup failed: $e',
        );
        // Non-fatal — proceeds to CF call.
      }
    }

    // Server-side cascade + admin.auth().deleteUser(uid).
    try {
      final callable = _functions.httpsCallable(
        _callableName,
        options: HttpsCallableOptions(
          timeout: const Duration(minutes: 9),
        ),
      );
      final response = await callable.call<Map<dynamic, dynamic>>({
        'reason': reason,
      });
      _mergeCfResult(response.data, result);
    } on FirebaseFunctionsException catch (e) {
      _handleCfException(e, result);
      return result;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] CF call failed', e);
      result['errors'] = [...(result['errors'] as List<String>), 'cf_call: $e'];
      return result;
    }

    // Post-CF: reset local notification state, then sign out.
    try {
      await ServiceLocator.get<notif.NotificationService>().resetForLogout();
    } catch (e) {
      app_logger.AppLogger.warning(
        '[$_logTag] Failed to reset notification service: $e',
      );
    }
    try {
      await _authService.signOut();
    } catch (e) {
      app_logger.AppLogger.warning(
        '[$_logTag] Sign-out after deletion failed: $e',
      );
    }

    app_logger.AppLogger.info(
      '[$_logTag] Account deletion completed: success=${result['success']}',
    );
    return result;
  }

  Future<void> _cleanupSearchIndex(
    String userId,
    Map<String, dynamic> result,
  ) async {
    try {
      await _searchRepository!.removeUser(userId);
      (result['deletedCollections'] as List).add('search_index_user');
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] search index user removal failed',
        e,
      );
      (result['failedCollections'] as List).add('search_index_user');
    }
  }

  /// Translate a `FirebaseFunctionsException` into the result-map shape.
  /// `failed-precondition` with `code: requires-recent-login` becomes
  /// `requiresReauth: true` so the caller can prompt the user.
  void _handleCfException(
    FirebaseFunctionsException e,
    Map<String, dynamic> result,
  ) {
    app_logger.AppLogger.error(
      '[$_logTag] CF rejected request: ${e.code} — ${e.message}',
      e,
    );
    final details = e.details;
    final code = details is Map ? details['code'] : null;
    if (e.code == 'failed-precondition' && code == 'requires-recent-login') {
      result['requiresReauth'] = true;
    } else if (e.code == 'unauthenticated') {
      result['requiresReauth'] = true;
    }
    (result['errors'] as List).add('cf_${e.code}: ${e.message.orEmpty()}');
  }

  void _mergeCfResult(
    Map<dynamic, dynamic>? data,
    Map<String, dynamic> result,
  ) {
    if (data == null) return;
    if (data['success'] is bool) {
      result['success'] = data['success'];
    }
    // whereType<String>() returns Iterable<String> directly. The earlier
    // `.cast<String>()` approach produced a lazy CastList<dynamic, String>
    // whose runtime type didn't match the `List<String>` addAll target — the
    // iterable check fired at addAll time, swallowing the CF response.
    if (data['deletedCollections'] is List) {
      (result['deletedCollections'] as List<String>).addAll(
        (data['deletedCollections'] as List).whereType<String>(),
      );
    }
    if (data['failedCollections'] is List) {
      (result['failedCollections'] as List<String>).addAll(
        (data['failedCollections'] as List).whereType<String>(),
      );
    }
    if (data['errors'] is List) {
      (result['errors'] as List<String>).addAll(
        (data['errors'] as List).map<String>((e) => e.toString()),
      );
    }
    if (data['auditLogId'] is String) {
      result['auditLogId'] = data['auditLogId'];
    }
  }
}
