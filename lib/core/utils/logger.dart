// lib/core/utils/logger.dart

import 'dart:developer' as developer;

/// 📝 LOGGER UTILITY - PROFESSIONELL LOGGNING
///
/// Ersätter print() med developer.log() för bättre debugging
/// och production-säker logging
class AppLogger {
  /// 🟢 SUCCESS - För framgångsrika operationer
  static void success(String message, [String? name]) {
    developer.log(
      '✅ $message',
      name: name ?? 'Butlery',
      level: 800, // Info level
    );
  }

  /// 🔵 INFO - För allmän information
  static void info(String message, [String? name]) {
    developer.log(
      '💡 $message',
      name: name ?? 'Butlery',
      level: 800, // Info level
    );
  }

  /// 🟡 WARNING - För varningar som inte stoppar appen
  static void warning(String message, [String? name]) {
    developer.log(
      '⚠️ $message',
      name: name ?? 'Butlery',
      level: 900, // Warning level
    );
  }

  /// 🔴 ERROR - För fel som påverkar funktionalitet
  static void error(String message, [Object? error, String? name]) {
    developer.log(
      '❌ $message',
      name: name ?? 'Butlery',
      level: 1000, // Error level
      error: error,
    );
  }

  /// 🐛 DEBUG - För utvecklingsinformation (visas bara i debug mode)
  static void debug(String message, [String? name]) {
    // Bara i debug mode
    assert(() {
      developer.log(
        '🐛 $message',
        name: name ?? 'Butlery-Debug',
        level: 700, // Debug level
      );
      return true;
    }());
  }

  /// 💾 PERSISTENCE - Specifik för datalagring
  static void persistence(String message) {
    info(message, 'Persistence');
  }

  /// 🎯 SERVICE - Specifik för service-operationer
  static void service(String message) {
    info(message, 'Service');
  }

  /// 🧠 VIEWMODEL - Specifik för ViewModel-operationer
  static void viewModel(String message) {
    info(message, 'ViewModel');
  }
}
