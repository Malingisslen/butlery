import 'package:package_info_plus/package_info_plus.dart';

/// Static utility for accessing app version metadata.
///
/// Call [initialize] during bootstrap (platform stage) before accessing
/// any properties. Falls back to 'unknown' if platform call fails.
class VersionInfo {
  static String _appVersion = 'unknown';
  static String _buildNumber = 'unknown';

  VersionInfo._();

  static String get appVersion => _appVersion;
  static String get buildNumber => _buildNumber;
  static String get fullVersion => '$_appVersion+$_buildNumber';

  static Future<void> initialize() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
      _buildNumber = info.buildNumber;
    } catch (_) {
      // Platform call can fail on web/test — keep 'unknown' defaults
    }
  }
}
