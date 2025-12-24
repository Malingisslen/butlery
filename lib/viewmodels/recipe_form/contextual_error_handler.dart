// lib/viewmodels/recipe_form/contextual_error_handler.dart

import 'package:butlery/core/errors/contextual_error_engine.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/constants/app_strings.dart';
import 'package:butlery/core/utils/connectivity_check.dart';
import 'package:butlery/core/utils/logger.dart';

/// Handles contextual error generation for recipe forms.
/// Provides intelligent error messages based on context, connectivity, and user actions.
class ContextualErrorHandler {
  /// Generate contextual error message with intelligent message generation.
  static Future<String> generateContextualError({
    required ErrorType errorType,
    required UserActionContext actionContext,
    String? technicalDetails,
    List<String>? recoveryActions,
    ErrorSeverity severity = ErrorSeverity.standard,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Get current connectivity state for context-aware messaging
      final connectivity = await _getCurrentConnectivity();

      final context = ErrorContext.fromCurrentState(
        errorType: errorType,
        actionContext: actionContext,
        connectivity: connectivity,
        severity: severity,
        technicalDetails: technicalDetails,
        recoveryActions: recoveryActions,
        additionalData: additionalData,
      );

      final contextualMessage = ContextualErrorEngine.generateMessage(context);
      AppLogger.debug(
          'CONTEXTUAL_ERROR: Generated error for ${actionContext.name}: $errorType');
      return contextualMessage;
    } catch (e) {
      // Fallback to basic error if contextual generation fails
      AppLogger.error('Failed to generate contextual error: $e');
      return AppStrings.actionSpecificError(actionContext.swedishDescription,
          technicalDetails ?? 'Ett fel uppstod');
    }
  }

  /// Generate network-aware error message with connectivity context.
  static Future<String> generateNetworkAwareError({
    required String operation,
    String? technicalDetails,
    bool includeRecoveryAction = true,
  }) async {
    try {
      final connectivity = await _getCurrentConnectivity();
      final connectivityType = _getConnectivityTypeName(connectivity);

      final message = AppStrings.networkAwareError(
        baseOperation: operation,
        connectivityType: connectivityType,
        includeRecoveryAction: includeRecoveryAction,
      );

      AppLogger.info(
          'NETWORK_ERROR: Generated network-aware error for $operation with $connectivityType connectivity');
      return message;
    } catch (e) {
      AppLogger.error('Failed to generate network-aware error: $e');
      return AppStrings.actionSpecificError(
          operation, technicalDetails ?? 'Natverksfel');
    }
  }

  /// Generate permission-aware error message with access context.
  static String generatePermissionError({
    required String resource,
    required String action,
    String? reason,
    String? suggestedAction,
  }) {
    final message = AppStrings.permissionContextualError(
      resource: resource,
      action: action,
      reason: reason,
      suggestedAction: suggestedAction,
    );

    AppLogger.info(
        'PERMISSION_ERROR: Generated permission error for $action on $resource');
    return message;
  }

  /// Generate error message with recovery suggestions.
  static String generateErrorWithRecovery({
    required String action,
    required String issue,
    String? recoveryAction,
  }) {
    return recoveryAction != null
        ? AppStrings.actionWithRecovery(action, issue, recoveryAction)
        : AppStrings.actionSpecificError(action, issue);
  }

  /// Generate informational message for offline operations.
  static String generateOfflineInfo(String operation) {
    final message = AppStrings.networkAwareError(
      baseOperation: operation,
      connectivityType: 'none',
      includeRecoveryAction: true,
    );

    AppLogger.info('OFFLINE_INFO: Generated offline info for $operation');
    return message;
  }

  /// Get current connectivity state using ConnectivityCheck utility.
  static Future<ConnectivityResult> _getCurrentConnectivity() async {
    try {
      return await ConnectivityCheck.checkConnectivity();
    } catch (e) {
      AppLogger.error('Failed to check connectivity: $e');
      return ConnectivityResult.limited; // Fallback assumption
    }
  }

  /// Convert connectivity result to readable type name.
  static String _getConnectivityTypeName(
      ConnectivityResult connectivityResult) {
    switch (connectivityResult) {
      case ConnectivityResult.none:
        return 'none';
      case ConnectivityResult.limited:
        return 'limited';
      case ConnectivityResult.degraded:
        return 'degraded';
      case ConnectivityResult.full:
        return 'full';
      case ConnectivityResult.unknown:
        return 'unknown';
    }
  }
}
