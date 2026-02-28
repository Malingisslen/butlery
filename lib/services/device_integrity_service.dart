import 'package:freerasp/freerasp.dart';
import 'package:butlery/core/utils/logger.dart';

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

    try {
      final config = TalsecConfig(
        androidConfig: AndroidConfig(
          packageName: 'com.butlery.app',
          signingCertHashes: ['AKoRuyLMM91E7lX/Zqp3u4jMmd0A7hH/Iqo/IWQHKIE='],
        ),
        iosConfig: IOSConfig(
          bundleIds: ['com.butlery.app'],
          teamId: 'BUTLERY_TEAM',
        ),
        watcherMail: 'security@butlery.app',
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
