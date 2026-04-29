/// Safe SharedPreferences accessor used by milestone/dedupe services.
///
/// Returns null on platform-channel failure (e.g. SharedPreferences plugin
/// not yet initialized in a test, or storage IO error) so callers can choose
/// to skip rather than crash.
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/core/utils/logger.dart';

/// Tries to acquire SharedPreferences. Returns null on failure and logs a
/// warning tagged with [logTag] so the call site is identifiable.
Future<SharedPreferences?> tryGetSharedPreferences({
  required String logTag,
}) async {
  try {
    return await SharedPreferences.getInstance();
  } catch (e) {
    AppLogger.warning(
      '$logTag: SharedPreferences unavailable ($e); skipping',
    );
    return null;
  }
}
