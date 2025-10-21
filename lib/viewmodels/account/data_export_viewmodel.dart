import 'package:flutter/foundation.dart';
import 'package:butlery/services/account/data_export_service.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// ViewModel for managing user data export UI state and operations
///
/// Handles the GDPR data portability feature, allowing users to export
/// all their personal data in JSON format.
///
/// **State Management:**
/// - Export progress tracking
/// - Loading states
/// - Success/error handling
/// - Export result storage
///
/// **User Flow:**
/// 1. User requests data export
/// 2. ViewModel triggers export via DataExportService
/// 3. Shows loading state during export
/// 4. On success: Stores JSON data for download/share
/// 5. On error: Shows error message with retry option
class DataExportViewModel extends ChangeNotifier {
  final DataExportService _exportService;
  static const String _logTag = 'DataExportViewModel';

  DataExportViewModel({
    required DataExportService exportService,
  }) : _exportService = exportService;

  // State
  bool _isExporting = false;
  String? _exportedData;
  String? _errorMessage;
  DateTime? _exportTimestamp;

  // Getters
  bool get isExporting => _isExporting;
  String? get exportedData => _exportedData;
  String? get errorMessage => _errorMessage;
  DateTime? get exportTimestamp => _exportTimestamp;
  bool get hasExportedData => _exportedData != null;
  bool get hasError => _errorMessage != null;

  /// Estimated export size in KB (rough estimate)
  int get estimatedSizeKB {
    if (_exportedData == null) return 0;
    return (_exportedData!.length / 1024).ceil();
  }

  /// User-friendly export size string
  String get exportSizeText {
    final sizeKB = estimatedSizeKB;
    if (sizeKB < 1024) {
      return '$sizeKB KB';
    } else {
      final sizeMB = (sizeKB / 1024).toStringAsFixed(1);
      return '$sizeMB MB';
    }
  }

  /// User-friendly export timestamp
  String get exportTimestampText {
    if (_exportTimestamp == null) return '';
    final now = DateTime.now();
    final difference = now.difference(_exportTimestamp!);

    if (difference.inMinutes < 1) {
      return 'Just nu';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minuter sedan';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} timmar sedan';
    } else {
      return '${difference.inDays} dagar sedan';
    }
  }

  /// Export all user data
  ///
  /// Returns true on success, false on failure.
  /// Updates state to show loading, then success/error.
  Future<bool> exportData() async {
    if (_isExporting) {
      app_logger.AppLogger.warning('[$_logTag] Export already in progress');
      return false;
    }

    try {
      _setExporting(true);
      _clearError();

      app_logger.AppLogger.info('[$_logTag] Starting data export');

      final jsonData = await _exportService.exportUserData();

      _exportedData = jsonData;
      _exportTimestamp = DateTime.now();
      _setExporting(false);

      app_logger.AppLogger.success(
        '[$_logTag] Data export completed successfully ($exportSizeText)',
      );

      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Data export failed', e);
      _setError(_formatErrorMessage(e));
      _setExporting(false);
      return false;
    }
  }

  /// Retry export after error
  Future<bool> retryExport() async {
    _clearError();
    return await exportData();
  }

  /// Clear exported data (e.g., after user downloads/shares)
  void clearExportedData() {
    _exportedData = null;
    _exportTimestamp = null;
    _clearError();
    notifyListeners();
    app_logger.AppLogger.info('[$_logTag] Exported data cleared');
  }

  /// Clear current export and start fresh
  void reset() {
    _exportedData = null;
    _exportTimestamp = null;
    _errorMessage = null;
    _isExporting = false;
    notifyListeners();
    app_logger.AppLogger.info('[$_logTag] Export state reset');
  }

  // Private helper methods

  void _setExporting(bool value) {
    _isExporting = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _formatErrorMessage(Object error) {
    final errorStr = error.toString();

    // User-friendly Swedish error messages
    if (errorStr.contains('No authenticated user')) {
      return 'Du måste vara inloggad för att exportera data';
    } else if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'Ingen internetanslutning. Kontrollera din anslutning och försök igen.';
    } else if (errorStr.contains('permission')) {
      return 'Behörighet nekad. Försök logga in igen.';
    } else {
      return 'Ett fel uppstod vid export av data. Försök igen.';
    }
  }

  @override
  void dispose() {
    // Clear sensitive data from memory on dispose
    _exportedData = null;
    app_logger.AppLogger.debug('[$_logTag] ViewModel disposed');
    super.dispose();
  }
}
