import 'package:flutter/foundation.dart'
    show
        kIsWeb,
        kReleaseMode,
        defaultTargetPlatform,
        TargetPlatform,
        visibleForTesting;
import 'package:freerasp/freerasp.dart';
import 'package:butlery/core/utils/logger.dart';

/// freeRASP credentials.
///
/// **Android cert hash** is committed: a SHA-256 of the current
/// `android/app/upload-keystore.jks` (alias `upload`), base64-encoded.
/// Computed via:
///   keytool -list -v -keystore android/app/upload-keystore.jks -alias upload
/// then `xxd -r -p | base64` over the colon-stripped hex. Used by freeRASP
/// to verify at runtime that the running APK was signed by this exact key —
/// repackaged or sideloaded copies fail the check. Rotate the constant
/// (or override via dart-define) if the upload keystore rotates.
///
/// **iOS teamId** is a placeholder until Apple Developer Program enrollment
/// (free Apple ID gives no Team ID). The `assertReleaseConfig` guard treats
/// this as a hard fail in release builds **only when running on iOS**, so
/// Android-only releases ship today without enrollment. When iOS shipping
/// starts, set `--dart-define=FREE_RASP_TEAM_ID=<real>` in the release
/// pipeline.
///
/// Both values can be overridden at build time via `--dart-define` — see
/// `docs/ops/freerasp-runbook.md`.
const String _kPlaceholderTeamId = 'BUTLERY_TEAM';
const String _kAndroidUploadCertHash =
    '1V4sCqD8sS+CuMNYsixjbTUz0FE7FOMULGCvw2n4380=';

const String _kTalsecTeamId = String.fromEnvironment(
  'FREE_RASP_TEAM_ID',
  defaultValue: _kPlaceholderTeamId,
);
const String _kTalsecAndroidCertHash = String.fromEnvironment(
  'FREE_RASP_ANDROID_CERT_HASH',
  defaultValue: _kAndroidUploadCertHash,
);

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

    if (kReleaseMode && _kTalsecTeamId == _kPlaceholderTeamId) {
      AppLogger.error(
        'SECURITY: freeRASP iOS teamId is a placeholder (BUT-426). iOS team '
        'verification is NOT active until Apple Developer Program enrollment '
        'replaces _kPlaceholderTeamId. Android signing verification is active.',
      );
    }

    assertReleaseConfig(
      isReleaseMode: kReleaseMode,
      runtimePlatform: defaultTargetPlatform,
      teamId: _kTalsecTeamId,
      androidCertHash: _kTalsecAndroidCertHash,
    );

    try {
      final config = TalsecConfig(
        androidConfig: AndroidConfig(
          packageName: 'com.butlery.app',
          signingCertHashes: [_kTalsecAndroidCertHash],
        ),
        iosConfig: IOSConfig(
          bundleIds: ['com.butlery.app'],
          teamId: _kTalsecTeamId,
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

/// Throws `StateError` if a release build is shipping with placeholder
/// freeRASP credentials that matter for the runtime platform.
///
/// - Android: a release build crashes if [androidCertHash] equals the
///   well-known `BUTLERY_ANDROID_PLACEHOLDER_HASH`. The committed default
///   is the real upload-keystore hash, so this only fires if someone
///   intentionally restored the placeholder OR the dart-define forces it.
/// - iOS: a release build crashes if [teamId] equals
///   [_kPlaceholderTeamId] **and** the runtime platform is iOS.
///   Android-only releases ship today without Apple Developer Program
///   enrollment; the iOS guard activates the moment iOS distribution
///   starts (TestFlight, App Store) and forces the dart-define to land.
///
/// Inputs are passed in (rather than read from top-level constants) so
/// the function is testable from a debug-mode unit test.
@visibleForTesting
const String kAndroidPlaceholderCertHash =
    'AKoRuyLMM91E7lX/Zqp3u4jMmd0A7hH/Iqo/IWQHKIE=';

@visibleForTesting
void assertReleaseConfig({
  required bool isReleaseMode,
  required TargetPlatform runtimePlatform,
  required String teamId,
  required String androidCertHash,
}) {
  if (!isReleaseMode) return;
  if (androidCertHash == kAndroidPlaceholderCertHash) {
    throw StateError(
      'BUT-426: FREE_RASP_ANDROID_CERT_HASH is the well-known placeholder. '
      'See docs/ops/freerasp-runbook.md.',
    );
  }
  if (runtimePlatform == TargetPlatform.iOS && teamId == _kPlaceholderTeamId) {
    throw StateError(
      'BUT-426: FREE_RASP_TEAM_ID dart-define missing in iOS release '
      'build. Apple Developer Program enrollment + the dart-define are '
      'required before shipping to TestFlight / App Store. See '
      'docs/ops/freerasp-runbook.md.',
    );
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
