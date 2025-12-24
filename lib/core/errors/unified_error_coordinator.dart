/// Unified error state management coordinator providing centralized error handling across recipe form components.
/// This coordinator manages error states across RecipeFormViewModel, RecipeImageManager, FormFieldsManager,
/// and other recipe form components, providing consistent error presentation, recovery mechanisms, and user feedback.
/// **Architecture Integration:**
/// - Coordinates errors from multiple form components
/// - Provides prioritized error display logic
/// - Manages error recovery workflows
/// - Enables comprehensive error analytics and logging
/// - Maintains error state consistency across component boundaries

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/utils/logger.dart';

/// Error severity levels for prioritized error handling
enum ErrorSeverity {
  low, // Info/warnings that don't block functionality
  medium, // Issues that may impact user experience
  high, // Errors that block primary functionality
  critical // System-level errors requiring immediate attention
}

/// Error source identification for targeted error handling
enum ErrorSource {
  formValidation, // Form field validation errors
  imageUpload, // Image upload and processing errors
  recipeService, // Recipe service operation errors
  permissions, // Permission and authorization errors
  network, // Network connectivity errors
  storage, // Local storage and caching errors
  collaboration, // Real-time collaboration errors
  autoSave, // Auto-save functionality errors
  system, // System-level errors
}

/// Error recovery action types
enum ErrorRecoveryAction {
  retry, // Retry the failed operation
  refresh, // Refresh/reload data
  navigate, // Navigate to different screen
  ignore, // Dismiss and continue
  escalate, // Show system-level error handling
}

/// Comprehensive error information for unified handling
class UnifiedErrorInfo {
  final String id;
  final ErrorSource source;
  final ErrorSeverity severity;
  final String message;
  final String? technicalDetails;
  final DateTime occurredAt;
  final List<ErrorRecoveryAction> availableActions;
  final Map<String, dynamic> context;
  final String? componentId; // Identifies which component reported the error

  const UnifiedErrorInfo({
    required this.id,
    required this.source,
    required this.severity,
    required this.message,
    this.technicalDetails,
    required this.occurredAt,
    this.availableActions = const [ErrorRecoveryAction.ignore],
    this.context = const {},
    this.componentId,
  });

  /// Create error from form validation
  factory UnifiedErrorInfo.fromFormValidation({
    required String message,
    String? fieldName,
    String? componentId,
  }) {
    return UnifiedErrorInfo(
      id: 'form_validation_${DateTime.now().millisecondsSinceEpoch}',
      source: ErrorSource.formValidation,
      severity: ErrorSeverity.medium,
      message: message,
      occurredAt: DateTime.now(),
      availableActions: [ErrorRecoveryAction.ignore],
      context: {'fieldName': fieldName},
      componentId: componentId,
    );
  }

  /// Create error from image upload
  factory UnifiedErrorInfo.fromImageUpload({
    required String message,
    String? technicalDetails,
    String? imagePath,
    String? componentId,
  }) {
    return UnifiedErrorInfo(
      id: 'image_upload_${DateTime.now().millisecondsSinceEpoch}',
      source: ErrorSource.imageUpload,
      severity: ErrorSeverity.high,
      message: message,
      technicalDetails: technicalDetails,
      occurredAt: DateTime.now(),
      availableActions: [ErrorRecoveryAction.retry, ErrorRecoveryAction.ignore],
      context: {'imagePath': imagePath},
      componentId: componentId,
    );
  }

  /// Create error from service operations
  factory UnifiedErrorInfo.fromServiceOperation({
    required String message,
    String? technicalDetails,
    String? operation,
    String? componentId,
  }) {
    return UnifiedErrorInfo(
      id: 'service_${DateTime.now().millisecondsSinceEpoch}',
      source: ErrorSource.recipeService,
      severity: ErrorSeverity.high,
      message: message,
      technicalDetails: technicalDetails,
      occurredAt: DateTime.now(),
      availableActions: [
        ErrorRecoveryAction.retry,
        ErrorRecoveryAction.refresh,
        ErrorRecoveryAction.ignore
      ],
      context: {'operation': operation},
      componentId: componentId,
    );
  }

  /// Check if error should be displayed to user
  bool get shouldDisplayToUser => severity != ErrorSeverity.low;

  /// Get user-friendly error message
  String get userMessage {
    // Customize message based on source and severity
    switch (source) {
      case ErrorSource.formValidation:
        return message;
      case ErrorSource.imageUpload:
        return 'Bilduppladdning misslyckades: $message';
      case ErrorSource.recipeService:
        return 'Recepthantering misslyckades: $message';
      case ErrorSource.permissions:
        return 'Behörighetsfel: $message';
      case ErrorSource.network:
        return 'Nätverksfel: $message';
      case ErrorSource.storage:
        return 'Lagringsfel: $message';
      case ErrorSource.collaboration:
        return 'Samarbetsfel: $message';
      case ErrorSource.autoSave:
        return 'Autosparning misslyckades: $message';
      case ErrorSource.system:
        return 'Systemfel: $message';
    }
  }

  /// Get action button text for recovery
  String getActionText(ErrorRecoveryAction action) {
    switch (action) {
      case ErrorRecoveryAction.retry:
        return 'Försök igen';
      case ErrorRecoveryAction.refresh:
        return 'Uppdatera';
      case ErrorRecoveryAction.navigate:
        return 'Gå tillbaka';
      case ErrorRecoveryAction.ignore:
        return 'OK';
      case ErrorRecoveryAction.escalate:
        return 'Rapportera';
    }
  }
}

/// CRITICAL FIX: Unified error state management coordinator for consistent error handling
class UnifiedErrorCoordinator extends ChangeNotifier {
  // Current error state
  UnifiedErrorInfo? _currentError;
  final List<UnifiedErrorInfo> _errorHistory = [];
  final Map<String, UnifiedErrorInfo> _componentErrors = {};

  // Error display coordination
  bool _isShowingError = false;
  Timer? _errorDisplayTimer;
  Timer? _errorClearTimer;

  // Error analytics
  final Map<ErrorSource, int> _errorCounts = {};
  final Map<ErrorSeverity, int> _severityCounts = {};

  // Disposal tracking
  bool _disposed = false;

  // Getters
  UnifiedErrorInfo? get currentError => _currentError;
  bool get hasError => _currentError != null;
  bool get isShowingError => _isShowingError;
  List<UnifiedErrorInfo> get errorHistory => List.unmodifiable(_errorHistory);
  Map<ErrorSource, int> get errorStatistics => Map.unmodifiable(_errorCounts);

  /// Report error from any component
  void reportError(UnifiedErrorInfo error) {
    if (_disposed) return;

    AppLogger.error(
        '🚨 ERROR_COORDINATOR: ${error.source.name} error from ${error.componentId}: ${error.message}');

    // Add to history
    _errorHistory.add(error);

    // Update analytics
    _errorCounts[error.source] = (_errorCounts[error.source] ?? 0) + 1;
    _severityCounts[error.severity] =
        (_severityCounts[error.severity] ?? 0) + 1;

    // Track component-specific errors
    if (error.componentId != null) {
      _componentErrors[error.componentId!] = error;
    }

    // Set as current error if it should be displayed and is higher priority
    if (error.shouldDisplayToUser && _shouldReplaceCurrentError(error)) {
      _setCurrentError(error);
    }
  }

  /// Check if new error should replace current error based on priority
  bool _shouldReplaceCurrentError(UnifiedErrorInfo newError) {
    if (_currentError == null) return true;

    // Higher severity always takes precedence
    if (newError.severity.index > _currentError!.severity.index) {
      return true;
    }

    // Same severity - newer error takes precedence
    if (newError.severity == _currentError!.severity) {
      return newError.occurredAt.isAfter(_currentError!.occurredAt);
    }

    return false;
  }

  /// Set current error with display coordination
  void _setCurrentError(UnifiedErrorInfo error) {
    _currentError = error;
    _isShowingError = true;

    // Cancel existing timers
    _errorDisplayTimer?.cancel();
    _errorClearTimer?.cancel();

    // Auto-clear low priority errors after a delay
    if (error.severity == ErrorSeverity.low ||
        error.severity == ErrorSeverity.medium) {
      _errorClearTimer = Timer(const Duration(seconds: 8), () {
        if (!_disposed && _currentError?.id == error.id) {
          clearCurrentError();
        }
      });
    }

    notifyListeners();

    AppLogger.info(
        '📱 ERROR_DISPLAY: Showing ${error.severity.name} error: ${error.message}');
  }

  /// Clear current error
  void clearCurrentError() {
    if (_disposed || _currentError == null) return;

    AppLogger.info(
        '✅ ERROR_COORDINATOR: Clearing current error: ${_currentError!.id}');

    _currentError = null;
    _isShowingError = false;

    _errorDisplayTimer?.cancel();
    _errorClearTimer?.cancel();

    notifyListeners();
  }

  /// Clear errors from specific component
  void clearComponentErrors(String componentId) {
    if (_disposed) return;

    _componentErrors.remove(componentId);

    // Clear current error if it's from this component
    if (_currentError?.componentId == componentId) {
      clearCurrentError();
    }

    AppLogger.debug(
        '🧹 ERROR_COORDINATOR: Cleared errors for component: $componentId');
  }

  /// Handle error recovery action
  Future<bool> handleRecoveryAction(
      ErrorRecoveryAction action, UnifiedErrorInfo error) async {
    if (_disposed) return false;

    AppLogger.info(
        '🔧 ERROR_RECOVERY: Handling ${action.name} for ${error.source.name} error');

    try {
      switch (action) {
        case ErrorRecoveryAction.retry:
          return await _handleRetryAction(error);
        case ErrorRecoveryAction.refresh:
          return await _handleRefreshAction(error);
        case ErrorRecoveryAction.navigate:
          return await _handleNavigateAction(error);
        case ErrorRecoveryAction.ignore:
          clearCurrentError();
          return true;
        case ErrorRecoveryAction.escalate:
          return await _handleEscalateAction(error);
      }
    } catch (e) {
      AppLogger.error('❌ ERROR_RECOVERY: Recovery action failed: $e');
      return false;
    }
  }

  /// Handle retry recovery action
  Future<bool> _handleRetryAction(UnifiedErrorInfo error) async {
    // Retry logic would depend on the error source and context
    // For now, clear the error and return success
    clearCurrentError();

    // Could implement specific retry logic based on error.source
    switch (error.source) {
      case ErrorSource.imageUpload:
        // Could trigger image re-upload
        break;
      case ErrorSource.recipeService:
        // Could trigger service operation retry
        break;
      default:
        break;
    }

    return true;
  }

  /// Handle refresh recovery action
  Future<bool> _handleRefreshAction(UnifiedErrorInfo error) async {
    clearCurrentError();
    // Refresh logic would depend on context
    return true;
  }

  /// Handle navigate recovery action
  Future<bool> _handleNavigateAction(UnifiedErrorInfo error) async {
    clearCurrentError();
    // Navigation logic would depend on context
    return true;
  }

  /// Handle escalate recovery action
  Future<bool> _handleEscalateAction(UnifiedErrorInfo error) async {
    // Log detailed error information for analysis
    AppLogger.error(
        '🆘 ERROR_ESCALATION: Critical error escalated: ${error.technicalDetails}');

    clearCurrentError();
    return true;
  }

  /// Get error summary for debugging
  Map<String, dynamic> getErrorSummary() {
    return {
      'currentError': _currentError?.message,
      'totalErrors': _errorHistory.length,
      'errorsBySource': _errorCounts,
      'errorsBySeverity': _severityCounts,
      'componentErrorCount': _componentErrors.length,
      'isShowingError': _isShowingError,
    };
  }

  /// Clear all error history (for testing or reset)
  void clearAllErrors() {
    if (_disposed) return;

    _currentError = null;
    _isShowingError = false;
    _errorHistory.clear();
    _componentErrors.clear();
    _errorCounts.clear();
    _severityCounts.clear();

    _errorDisplayTimer?.cancel();
    _errorClearTimer?.cancel();

    notifyListeners();

    AppLogger.info('🧹 ERROR_COORDINATOR: All errors cleared');
  }

  @override
  void dispose() {
    _disposed = true;

    _errorDisplayTimer?.cancel();
    _errorClearTimer?.cancel();

    AppLogger.info('🔄 ERROR_COORDINATOR: Disposed');
    super.dispose();
  }
}

/// Mixin for components to easily integrate with error coordinator
mixin ErrorCoordinatorMixin {
  UnifiedErrorCoordinator? _errorCoordinator;
  String? _componentId;

  /// Initialize error coordinator integration
  void initializeErrorCoordinator(
      UnifiedErrorCoordinator coordinator, String componentId) {
    _errorCoordinator = coordinator;
    _componentId = componentId;
  }

  /// Report error to coordinator
  void reportError({
    required ErrorSource source,
    required String message,
    ErrorSeverity severity = ErrorSeverity.medium,
    String? technicalDetails,
    Map<String, dynamic> context = const {},
    List<ErrorRecoveryAction> actions = const [ErrorRecoveryAction.ignore],
  }) {
    if (_errorCoordinator != null && _componentId != null) {
      final error = UnifiedErrorInfo(
        id: '${_componentId}_${DateTime.now().millisecondsSinceEpoch}',
        source: source,
        severity: severity,
        message: message,
        technicalDetails: technicalDetails,
        occurredAt: DateTime.now(),
        availableActions: actions,
        context: context,
        componentId: _componentId,
      );

      _errorCoordinator!.reportError(error);
    }
  }

  /// Clear errors for this component
  void clearComponentErrors() {
    if (_errorCoordinator != null && _componentId != null) {
      _errorCoordinator!.clearComponentErrors(_componentId!);
    }
  }
}
