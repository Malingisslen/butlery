import 'package:flutter/foundation.dart';
import 'package:butlery/services/account/data_export_service.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';

/// ViewModel for managing user data export UI state and operations
/// Handles the GDPR data portability feature, allowing users to export
/// all their personal data in JSON format.
/// **State Management:**
/// - Export progress tracking with AsyncOperationMixin
/// - Loading states managed automatically
/// - Success/error handling via AsyncOperationMixin
/// - Export result storage
/// **User Flow:**
/// 1. User requests data export
/// 2. ViewModel triggers export via DataExportService
/// 3. Shows loading state during export (managed by AsyncOperationMixin)
/// 4. On success: Stores JSON data for download/share
/// 5. On error: Shows error message with retry option
class DataExportViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {
  final DataExportService _exportService;
  static const String _logTag = 'DataExportViewModel';

  DataExportViewModel({
    required DataExportService exportService,
  }) : _exportService = exportService;

  // State
  String? _exportedData;
  DateTime? _exportTimestamp;

  // Getters
  bool get isExporting => isLoading; // Compatibility alias for UI
  String? get exportedData => _exportedData;
  String? get errorMessage =>
      error; // Compatibility alias for UI - StateNotifierMixin provides 'error'
  DateTime? get exportTimestamp => _exportTimestamp;
  bool get hasExportedData => _exportedData != null;

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
  /// Returns true on success, false on failure.
  /// Loading state, error handling, and duplicate prevention managed by AsyncOperationMixin.
  Future<bool> exportData() async {
    try {
      return await executeNamedOperation(
        'export', // Prevents duplicate concurrent exports
        () async {
          app_logger.AppLogger.info('[$_logTag] Starting data export');

          final jsonData = await _exportService.exportUserData();

          _exportedData = jsonData;
          _exportTimestamp = DateTime.now();

          app_logger.AppLogger.success(
            '[$_logTag] Data export completed successfully ($exportSizeText)',
          );

          return true;
        },
      );
    } catch (e) {
      // executeNamedOperation already set loading=false and hasError=true
      // Update error message to user-friendly format
      setError(_formatErrorMessage(e));
      return false;
    }
  }

  /// Retry export after error
  Future<bool> retryExport() async {
    clearError(); // AsyncOperationMixin provides clearError()
    return await exportData();
  }

  /// Clear exported data (e.g., after user downloads/shares)
  void clearExportedData() {
    _exportedData = null;
    _exportTimestamp = null;
    clearError(); // AsyncOperationMixin provides clearError()
    notifyListeners();
    app_logger.AppLogger.info('[$_logTag] Exported data cleared');
  }

  /// Clear current export and start fresh
  void reset() {
    _exportedData = null;
    _exportTimestamp = null;
    clearError(); // AsyncOperationMixin provides clearError()
    // isLoading automatically managed by AsyncOperationMixin
    notifyListeners();
    app_logger.AppLogger.info('[$_logTag] Export state reset');
  }

  // Private helper methods

  String _formatErrorMessage(Object error) {
    final errorStr = error.toString();

    // User-friendly Swedish error messages
    if (errorStr.contains('No authenticated user')) {
      return 'Du måste vara inloggad för att exportera data';
    } else if (errorStr.contains('network') ||
        errorStr.contains('connection')) {
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
