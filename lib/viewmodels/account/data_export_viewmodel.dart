import 'dart:async';
import 'dart:io' show SocketException;

import 'package:clock/clock.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:butlery/services/account/data_export_service.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Why an export failed. "Tre felorsaker, tre besked: utgången inloggning
/// leder till inloggningen, nekad behörighet är vårt fel och ber inte om ett
/// nytt försök, nätavbrott får försök igen" (produktregler.md:735), plus the
/// general case, the only one that may ask for a retry without explaining
/// (Skarmar v12 etapp 6 #dataexportfel).
enum ExportFailure {
  /// The sign-in has expired or is gone: the way on is signing in.
  signedOut,

  /// The server refused. Our fault; no retry is offered.
  permissionDenied,

  /// The connection dropped mid-export: retry.
  network,

  /// Anything else: retry.
  other,
}

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
  ExportFailure? _failure;

  // Getters
  bool get isExporting => isLoading; // Compatibility alias for UI
  String? get exportedData => _exportedData;
  String? get errorMessage =>
      error; // Compatibility alias for UI - StateNotifierMixin provides 'error'
  DateTime? get exportTimestamp => _exportTimestamp;

  /// Why the last export failed, or null.
  ExportFailure? get failure => _failure;
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
    final now = clock.now();
    final difference = now.difference(_exportTimestamp!);

    final l = AppLocale.current;
    if (difference.inMinutes < 1) {
      return l.commonJustNow;
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} h';
    } else {
      return '${difference.inDays} d';
    }
  }

  /// Export all user data
  /// Returns true on success, false on failure.
  /// Loading state, error handling, and duplicate prevention managed by AsyncOperationMixin.
  Future<bool> exportData() async {
    _failure = null;
    try {
      return await executeNamedOperation(
        'export', // Prevents duplicate concurrent exports
        () async {
          app_logger.AppLogger.info('[$_logTag] Starting data export');

          final jsonData = await _exportService.exportUserData();

          _exportedData = jsonData;
          _exportTimestamp = clock.now();

          app_logger.AppLogger.success(
            '[$_logTag] Data export completed successfully ($exportSizeText)',
          );

          return true;
        },
      );
    } catch (e) {
      // executeNamedOperation already set loading=false and hasError=true
      // Update error message to user-friendly format. No partial file is
      // ever kept: the bundle is only assigned on success
      // (produktregler.md:734).
      _failure = classifyExportError(e);
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
    _failure = null;
    clearError(); // AsyncOperationMixin provides clearError()
    notifyListeners();
    app_logger.AppLogger.info('[$_logTag] Exported data cleared');
  }

  /// Clear current export and start fresh
  void reset() {
    _exportedData = null;
    _exportTimestamp = null;
    _failure = null;
    clearError(); // AsyncOperationMixin provides clearError()
    // isLoading automatically managed by AsyncOperationMixin
    notifyListeners();
    app_logger.AppLogger.info('[$_logTag] Export state reset');
  }

  /// Sorts an export error into its cause. Typed errors first; the string
  /// checks keep the old behaviour for errors that arrive as plain
  /// exceptions ("No authenticated user found", data_export_service.dart).
  @visibleForTesting
  static ExportFailure classifyExportError(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return ExportFailure.permissionDenied;
        case 'unauthenticated':
        case 'user-token-expired':
        case 'invalid-user-token':
        case 'user-not-found':
        case 'requires-recent-login':
          return ExportFailure.signedOut;
        case 'unavailable':
        case 'deadline-exceeded':
        case 'network-request-failed':
          return ExportFailure.network;
      }
      return ExportFailure.other;
    }
    if (error is SocketException || error is TimeoutException) {
      return ExportFailure.network;
    }
    final text = error.toString();
    if (text.contains('No authenticated user')) return ExportFailure.signedOut;
    if (text.contains('permission')) return ExportFailure.permissionDenied;
    if (text.contains('network') || text.contains('connection')) {
      return ExportFailure.network;
    }
    return ExportFailure.other;
  }

  // Private helper methods

  String _formatErrorMessage(Object error) {
    final errorStr = error.toString();
    final l = AppLocale.current;

    if (errorStr.contains('No authenticated user')) {
      return l.errorMustBeLoggedInToExport;
    } else if (errorStr.contains('network') ||
        errorStr.contains('connection')) {
      return l.errorNoInternetCheckConnection;
    } else if (errorStr.contains('permission')) {
      return l.errorPermissionDeniedRetry;
    } else {
      return l.errorExportFailed;
    }
  }

  @override
  void dispose() {
    // Clear sensitive data from memory on dispose: the file lives only in
    // memory and is cleared when the view is left, which the view says
    // (produktregler.md:733).
    _exportedData = null;
    _exportTimestamp = null;
    app_logger.AppLogger.debug('[$_logTag] ViewModel disposed');
    super.dispose();
  }
}
