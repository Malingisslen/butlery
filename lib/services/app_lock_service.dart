import 'package:butlery/services/auth/biometric_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for app lock functionality using biometric authentication.
///
/// Tracks when the app is backgrounded and requires biometric authentication
/// when the user returns after a configurable timeout period.
class AppLockService {
  static const String _lockTimeoutKey = 'app_lock_timeout_minutes';
  static const int _defaultTimeoutMinutes = 5;

  final BiometricService _biometricService;

  DateTime? _lastBackgroundTime;
  DateTime? _lastAuthTime;
  int _lockTimeoutMinutes = _defaultTimeoutMinutes;
  bool _isLocked = false;

  /// When the user last successfully authenticated.
  DateTime? get lastAuthTime => _lastAuthTime;

  AppLockService({required BiometricService biometricService})
      : _biometricService = biometricService;

  /// Whether the app is currently locked and requires authentication.
  bool get isLocked => _isLocked;

  /// Whether app lock is available (biometrics available and enabled).
  bool get isAppLockAvailable =>
      _biometricService.isAvailable && _biometricService.isEnabled;

  /// Current lock timeout in minutes.
  int get lockTimeoutMinutes => _lockTimeoutMinutes;

  /// Initialize the service and load user preferences.
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lockTimeoutMinutes =
          prefs.getInt(_lockTimeoutKey) ?? _defaultTimeoutMinutes;
      AppLogger.debug(
        'AppLockService initialized with timeout: $_lockTimeoutMinutes min',
      );
    } catch (e) {
      AppLogger.warning('Failed to load app lock preferences: $e');
    }
  }

  /// Set the lock timeout in minutes.
  Future<void> setLockTimeout(int minutes) async {
    if (minutes < 1 || minutes > 60) {
      AppLogger.warning('Invalid lock timeout: $minutes');
      return;
    }

    _lockTimeoutMinutes = minutes;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lockTimeoutKey, minutes);
    } catch (e) {
      AppLogger.warning('Failed to save lock timeout: $e');
    }
  }

  /// Called when app goes to background.
  void onAppPaused() {
    _lastBackgroundTime = DateTime.now();
    AppLogger.debug('App paused, recording background time');
  }

  /// Called when app returns to foreground.
  /// Returns true if authentication is required.
  Future<bool> onAppResumed() async {
    if (!isAppLockAvailable) {
      _isLocked = false;
      return false;
    }

    if (_lastBackgroundTime == null) {
      _isLocked = false;
      return false;
    }

    final backgroundDuration = DateTime.now().difference(_lastBackgroundTime!);
    final timeoutDuration = Duration(minutes: _lockTimeoutMinutes);

    if (backgroundDuration > timeoutDuration) {
      _isLocked = true;
      AppLogger.info(
        'App was backgrounded for ${backgroundDuration.inMinutes} min, '
        'requiring authentication (timeout: $_lockTimeoutMinutes min)',
      );
      return true;
    }

    _isLocked = false;
    return false;
  }

  /// Attempt to unlock the app using biometric authentication.
  /// Returns true if authentication was successful.
  Future<bool> unlock() async {
    if (!_isLocked) return true;

    final authenticated = await _biometricService.authenticate(
      reason: 'Lås upp Butlery',
      stickyAuth: true,
    );

    if (authenticated) {
      _isLocked = false;
      _lastAuthTime = DateTime.now();
      _lastBackgroundTime = null;
      AppLogger.info('App unlocked via biometric authentication');
    }

    return authenticated;
  }

  /// Force lock the app (for manual lock feature).
  void lock() {
    if (!isAppLockAvailable) return;
    _isLocked = true;
    _lastBackgroundTime = DateTime.now().subtract(
      Duration(minutes: _lockTimeoutMinutes + 1),
    );
    AppLogger.info('App manually locked');
  }

  /// Reset lock state (used after successful login).
  void resetLockState() {
    _isLocked = false;
    _lastBackgroundTime = null;
    _lastAuthTime = DateTime.now();
  }
}
