/// Biometric authentication service for Face ID, Touch ID, and fingerprint authentication.
/// Provides secure local authentication on iOS and Android.

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/core/utils/logger.dart';

/// Service for biometric authentication (Face ID, Touch ID, Fingerprint).
class BiometricService {
  static const String _biometricEnabledKey = 'biometric_auth_enabled';

  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isInitialized = false;
  bool _isAvailable = false;
  bool _isEnabled = false;
  List<BiometricType> _availableBiometrics = [];

  /// Whether the service has been initialized.
  bool get isInitialized => _isInitialized;

  /// Whether biometric authentication is available on this device.
  bool get isAvailable => _isAvailable;

  /// Whether biometric authentication is enabled by the user.
  bool get isEnabled => _isEnabled;

  /// List of available biometric types on this device.
  List<BiometricType> get availableBiometrics => _availableBiometrics;

  /// Whether Face ID is available.
  bool get hasFaceId => _availableBiometrics.contains(BiometricType.face);

  /// Whether Touch ID / Fingerprint is available.
  bool get hasFingerprint =>
      _availableBiometrics.contains(BiometricType.fingerprint) ||
      _availableBiometrics.contains(BiometricType.strong) ||
      _availableBiometrics.contains(BiometricType.weak);

  /// Initialize the biometric service.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if biometrics are available
      _isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      _isAvailable = _isAvailable && isDeviceSupported;

      if (_isAvailable) {
        // Get available biometric types
        _availableBiometrics = await _localAuth.getAvailableBiometrics();
        AppLogger.info(
          'BiometricService: Available biometrics: $_availableBiometrics',
        );
      }

      // Load user preference
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_biometricEnabledKey) ?? false;

      _isInitialized = true;
      AppLogger.info(
        'BiometricService: Initialized - available: $_isAvailable, enabled: $_isEnabled',
      );
    } catch (e) {
      AppLogger.warning('BiometricService: Failed to initialize: $e');
      _isAvailable = false;
      _isInitialized = true;
    }
  }

  /// Enable or disable biometric authentication.
  Future<void> setEnabled(bool enabled) async {
    if (!_isAvailable && enabled) {
      AppLogger.warning(
        'BiometricService: Cannot enable - biometrics not available',
      );
      return;
    }

    // If enabling, verify the user can authenticate first
    if (enabled) {
      final authenticated = await authenticate(
        reason:
            'Verifiera din identitet för att aktivera biometrisk inloggning',
      );
      if (!authenticated) {
        AppLogger.info('BiometricService: User failed verification');
        return;
      }
    }

    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
    AppLogger.info('BiometricService: Enabled set to: $enabled');
  }

  /// Authenticate using biometrics.
  /// Returns true if authentication was successful.
  Future<bool> authenticate({
    required String reason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    if (!_isAvailable) {
      AppLogger.warning(
        'BiometricService: Authentication failed - not available',
      );
      return false;
    }

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: true,
        ),
      );

      AppLogger.info(
        'BiometricService: Authentication ${authenticated ? 'successful' : 'failed'}',
      );
      return authenticated;
    } on PlatformException catch (e) {
      AppLogger.warning('BiometricService: Authentication error: ${e.message}');
      return false;
    }
  }

  /// Get a human-readable name for the available biometric type.
  String get biometricTypeName {
    if (hasFaceId) return 'Face ID';
    if (hasFingerprint) return 'Fingeravtryck';
    return 'Biometrisk autentisering';
  }

  /// Stop any ongoing authentication.
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      // Ignore errors when stopping
    }
  }
}
