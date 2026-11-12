import 'package:cloud_functions/cloud_functions.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/models/admin/pool_inspection.dart';

/// Why a pool callable was refused, mapped from its error codes.
enum PoolModerationFailure { invalidKey, notAllowed, rateLimited, other }

class PoolModerationException implements Exception {
  const PoolModerationException(this.failure);
  final PoolModerationFailure failure;

  @override
  String toString() => 'PoolModerationException($failure)';
}

/// The admin-only `adminInspectPool` / `adminSetPoolQuarantine` callables.
/// Nothing is cached here: the numbers are read fresh on every call.
/// Manual try/catch instead of `executeServiceOperation`: the caller needs
/// the failure TYPE, not a message (same reason as `password_reset_service.dart`).
class PoolModerationService extends BaseService {
  PoolModerationService({required FirebaseFunctions functions})
    : _functions = functions;

  final FirebaseFunctions _functions;

  @override
  String get serviceName => 'PoolModerationService';

  HttpsCallable _callable(String name) => _functions.httpsCallable(
    name,
    options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
  );

  /// Throws [PoolModerationException] on a refusal.
  Future<PoolInspection> inspect(String poolKey) async {
    try {
      final result = await _callable(
        'adminInspectPool',
      ).call<Map<dynamic, dynamic>>({'poolKey': poolKey});
      final parsed = PoolInspection.fromMap(result.data);
      if (parsed == null) {
        throw const PoolModerationException(PoolModerationFailure.other);
      }
      return parsed;
    } on FirebaseFunctionsException catch (e) {
      throw PoolModerationException(failureFor(e));
    }
  }

  /// [reason] is required when [quarantined] is true. Throws
  /// [PoolModerationException] on a refusal.
  Future<void> setQuarantine({
    required String poolKey,
    required bool quarantined,
    QuarantineReason? reason,
  }) async {
    assert(!quarantined || reason != null);
    try {
      await _callable('adminSetPoolQuarantine').call<Map<dynamic, dynamic>>({
        'poolKey': poolKey,
        'quarantined': quarantined,
        if (quarantined) 'reasonCode': reason!.wireName,
      });
    } on FirebaseFunctionsException catch (e) {
      throw PoolModerationException(failureFor(e));
    }
  }

  static PoolModerationFailure failureFor(FirebaseFunctionsException e) =>
      switch (e.code) {
        'invalid-argument' => PoolModerationFailure.invalidKey,
        'permission-denied' ||
        'unauthenticated' => PoolModerationFailure.notAllowed,
        'resource-exhausted' => PoolModerationFailure.rateLimited,
        _ => PoolModerationFailure.other,
      };
}
