import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:freerasp/freerasp.dart';
import 'package:butlery/core/utils/logger.dart';

// TODO(BUT-426): replace with the real Apple Developer Team ID once enrolled
// in the Apple Developer Program. The value is a 10-char alphanumeric string
// from developer.apple.com → Membership. Until enrollment, iOS bundle/team
// verification is inactive — that's safe because we don't distribute on
// iOS yet (no TestFlight, no App Store). The runtime warning at line 41
// fires only on iOS where the unset teamId would matter.
const String _kPlaceholderTeamId = 'BUTLERY_TEAM';

// SHA-256 fingerprint of android/app/upload-keystore.jks (alias `upload`),
// base64-encoded. Computed via:
//   keytool -list -v -keystore android/app/upload-keystore.jks -alias upload
// then `xxd -r -p | base64` over the colon-stripped hex. Used by freeRASP
// to verify at runtime that the running APK was signed by this exact key —
// repackaged or sideloaded copies fail the check.
const String _kAndroidUploadCertHash =
    '1V4sCqD8sS+CuMNYsixjbTUz0FE7FOMULGCvw2n4380=';

/// Service for detecting compromised devices using freeRASP.
///
/// Provides comprehensive device integrity checks including root/jailbreak,
/// developer mode, emulator, and reverse engineering detection.
/// Uses a non-blocking approach: warns users but allows continued usage.
class DeviceIntegrityService {
  bool _isCompromised = false;
  bool _isDeveloperMode = false;
  bool _isInitialized = false;

  /// Whether the service has completed initialization.
  bool get isInitialized => _isInitialized;

  /// Initialize the service and start monitoring.
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      AppLogger.info('Device integrity: skipped on web (not supported)');
      _isInitialized = true;
      return;
    }

    if (kReleaseMode && _kPlaceholderTeamId == 'BUTLERY_TEAM') {
      AppLogger.error(
        'SECURITY: freeRASP iOS teamId is a placeholder (BUT-426). iOS team '
        'verification is NOT active until Apple Developer Program enrollment '
        'replaces _kPlaceholderTeamId. Android signing verification is active.',
      );
    }

    try {
      final config = TalsecConfig(
        androidConfig: AndroidConfig(
          packageName: 'com.butlery.app',
          signingCertHashes: [_kAndroidUploadCertHash],
        ),
        iosConfig: IOSConfig(
          bundleIds: ['com.butlery.app'],
          teamId: _kPlaceholderTeamId,
        ),
        watcherMail: 'malin.gisslen1@gmail.com',
      );

      final callback = ThreatCallback(
        onAppIntegrity: () {
          AppLogger.warning('Device integrity: app tampering detected');
          _isCompromised = true;
        },
        onObfuscationIssues: () {
          AppLogger.debug('Device integrity: obfuscation issues');
        },
        onDebug: () {
          AppLogger.debug('Device integrity: debugger attached');
          _isDeveloperMode = true;
        },
        onDeviceBinding: () {
          AppLogger.warning('Device integrity: device binding mismatch');
        },
        onDeviceID: () {
          AppLogger.debug('Device integrity: device ID anomaly');
        },
        onHooks: () {
          AppLogger.warning('Device integrity: hooks detected (Frida/Xposed)');
          _isCompromised = true;
        },
        onPasscode: () {
          AppLogger.debug('Device integrity: no device passcode');
        },
        onPrivilegedAccess: () {
          AppLogger.warning('Device integrity: root/jailbreak detected');
          _isCompromised = true;
        },
        onSecureHardwareNotAvailable: () {
          AppLogger.debug('Device integrity: no secure hardware');
        },
        onSimulator: () {
          AppLogger.info('Device integrity: running on emulator/simulator');
        },
        onUnofficialStore: () {
          AppLogger.warning('Device integrity: unofficial app store');
        },
      );

      Talsec.instance.attachListener(callback);
      await Talsec.instance.start(config);

      _isInitialized = true;
      AppLogger.info('Device integrity service initialized with freeRASP');
    } catch (e) {
      AppLogger.warning('Failed to initialize device integrity: $e');
      _isInitialized = true; // Mark initialized to avoid retries
    }
  }

  /// Check if device is rooted (Android) or jailbroken (iOS).
  Future<bool> isDeviceCompromised() async {
    if (!_isInitialized) await initialize();
    return _isCompromised;
  }

  /// Check if developer mode / debugger is attached.
  Future<bool> isDeveloperModeEnabled() async {
    if (!_isInitialized) await initialize();
    return _isDeveloperMode;
  }

  /// Get comprehensive device integrity status.
  Future<DeviceIntegrityStatus> getStatus() async {
    return DeviceIntegrityStatus(
      isCompromised: await isDeviceCompromised(),
      isDeveloperMode: await isDeveloperModeEnabled(),
    );
  }

  /// Reset cached values (useful for re-checking).
  void resetCache() {
    _isCompromised = false;
    _isDeveloperMode = false;
    _isInitialized = false;
  }
}

/// Represents the device's integrity status.
class DeviceIntegrityStatus {
  /// Whether the device is rooted/jailbroken.
  final bool isCompromised;

  /// Whether developer mode is enabled.
  final bool isDeveloperMode;

  const DeviceIntegrityStatus({
    required this.isCompromised,
    required this.isDeveloperMode,
  });

  /// Whether the device is considered secure.
  bool get isSecure => !isCompromised;

  /// Whether any security concerns were detected.
  bool get hasSecurityConcerns => isCompromised || isDeveloperMode;

  @override
  String toString() =>
      'DeviceIntegrityStatus(compromised: $isCompromised, devMode: $isDeveloperMode)';
}
