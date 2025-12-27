import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:butlery/core/utils/logger.dart';

/// Service for detecting compromised devices (rooted Android / jailbroken iOS).
///
/// Provides device integrity checks to warn users about security risks
/// when running on modified devices. Uses a non-blocking approach that
/// warns users but allows continued app usage.
class DeviceIntegrityService {
  bool? _isCompromised;
  bool? _isDeveloperMode;
  bool _isInitialized = false;

  /// Whether the service has completed initialization.
  bool get isInitialized => _isInitialized;

  /// Initialize the service and perform initial checks.
  Future<void> initialize() async {
    if (_isInitialized) return;

    await isDeviceCompromised();
    await isDeveloperModeEnabled();
    _isInitialized = true;
  }

  /// Check if device is rooted (Android) or jailbroken (iOS).
  ///
  /// Returns cached result if already checked.
  /// Returns false on error to avoid blocking legitimate users.
  Future<bool> isDeviceCompromised() async {
    if (_isCompromised != null) return _isCompromised!;

    try {
      _isCompromised = await FlutterJailbreakDetection.jailbroken;
      AppLogger.info(
        'Device integrity check: compromised=${_isCompromised! ? "YES" : "no"}',
      );
      return _isCompromised!;
    } catch (e) {
      AppLogger.warning('Failed to check device integrity: $e');
      _isCompromised = false;
      return false;
    }
  }

  /// Check if developer mode is enabled on the device.
  ///
  /// Developer mode can indicate additional security risks.
  Future<bool> isDeveloperModeEnabled() async {
    if (_isDeveloperMode != null) return _isDeveloperMode!;

    try {
      _isDeveloperMode = await FlutterJailbreakDetection.developerMode;
      if (_isDeveloperMode!) {
        AppLogger.info('Device has developer mode enabled');
      }
      return _isDeveloperMode!;
    } catch (e) {
      AppLogger.debug('Failed to check developer mode: $e');
      _isDeveloperMode = false;
      return false;
    }
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
    _isCompromised = null;
    _isDeveloperMode = null;
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
