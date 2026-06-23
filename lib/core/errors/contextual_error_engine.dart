// lib/core/errors/contextual_error_engine.dart

import 'package:clock/clock.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/connectivity_check.dart';

/// User action contexts for intelligent error message generation
enum UserActionContext {
  // Recipe contexts
  recipeSaving,
  recipeUploading,
  recipeLoading,
  recipeDeleting,
  recipeValidation,
  recipeCollaborativeSync,
  recipeDraftRestore,

  // Image contexts
  recipeImageUpload,
  recipeImageProcessing,
  recipeImageDelete,

  // Shopping contexts
  shoppingListCreate,
  shoppingItemAdd,
  shoppingListSync,
  shoppingListShare,
  shoppingListDelete,

  // Social contexts
  friendInvite,
  groupCreate,
  messagesSend,
  socialSync,
  userProfileUpdate,
  permissionRequest,

  // System contexts
  appStartup,
  dataSync,
  backgroundUpload,
  offline
  ;

  /// Localized description of the action
  String get localizedDescription {
    final l = AppLocale.current;
    switch (this) {
      case recipeSaving:
        return l.actionRecipeSaving;
      case recipeUploading:
        return l.actionRecipeUploading;
      case recipeLoading:
        return l.actionRecipeLoading;
      case recipeDeleting:
        return l.actionRecipeDeleting;
      case recipeValidation:
        return l.actionRecipeValidation;
      case recipeCollaborativeSync:
        return l.actionRecipeCollaborativeSync;
      case recipeDraftRestore:
        return l.actionRecipeDraftRestore;
      case recipeImageUpload:
        return l.actionRecipeImageUpload;
      case recipeImageProcessing:
        return l.actionRecipeImageProcessing;
      case recipeImageDelete:
        return l.actionRecipeImageDelete;
      case shoppingListCreate:
        return l.actionShoppingListCreate;
      case shoppingItemAdd:
        return l.actionShoppingItemAdd;
      case shoppingListSync:
        return l.actionShoppingListSync;
      case shoppingListShare:
        return l.actionShoppingListShare;
      case shoppingListDelete:
        return l.actionShoppingListDelete;
      case friendInvite:
        return l.actionFriendInvite;
      case groupCreate:
        return l.actionGroupCreate;
      case messagesSend:
        return l.actionMessagesSend;
      case socialSync:
        return l.actionSocialSync;
      case userProfileUpdate:
        return l.actionUserProfileUpdate;
      case permissionRequest:
        return l.actionPermissionRequest;
      case appStartup:
        return l.actionAppStartup;
      case dataSync:
        return l.actionDataSync;
      case backgroundUpload:
        return l.actionBackgroundUpload;
      case offline:
        return l.actionOffline;
    }
  }
}

/// Error severity levels for progressive disclosure
enum ErrorSeverity {
  minimal('minimal'), // Just show icon/indicator
  standard('standard'), // Show standard message
  detailed('detailed'), // Show detailed message with context
  diagnostic('diagnostic')
  ; // Show full diagnostic information

  const ErrorSeverity(this.level);
  final String level;
}

/// Enhanced error details for contextual messaging
class ErrorContext {
  final ErrorType errorType;
  final UserActionContext actionContext;
  final ConnectivityResult connectivity;
  final ErrorSeverity severity;
  final String? technicalDetails;
  final List<String>? recoveryActions;
  final Map<String, dynamic>? additionalData;
  final DateTime timestamp;

  const ErrorContext({
    required this.errorType,
    required this.actionContext,
    required this.connectivity,
    this.severity = ErrorSeverity.standard,
    this.technicalDetails,
    this.recoveryActions,
    this.additionalData,
    required this.timestamp,
  });

  /// Create error context from current system state
  factory ErrorContext.fromCurrentState({
    required ErrorType errorType,
    required UserActionContext actionContext,
    ConnectivityResult connectivity = ConnectivityResult.full,
    ErrorSeverity severity = ErrorSeverity.standard,
    String? technicalDetails,
    List<String>? recoveryActions,
    Map<String, dynamic>? additionalData,
  }) {
    return ErrorContext(
      errorType: errorType,
      actionContext: actionContext,
      connectivity: connectivity,
      severity: severity,
      technicalDetails: technicalDetails,
      recoveryActions: recoveryActions,
      additionalData: additionalData,
      timestamp: clock.now(),
    );
  }
}

/// Intelligent contextual error message engine for Swedish cooking application
class ContextualErrorEngine {
  ContextualErrorEngine._();

  /// Generate contextual error message based on comprehensive error context
  static String generateMessage(ErrorContext context) {
    try {
      AppLogger.debug(
        '🚨 ERROR_ENGINE: Generating contextual message for ${context.actionContext.name} - ${context.errorType.name}',
      );

      final baseMessage = _generateBaseMessage(context);
      final recoveryGuidance = _generateRecoveryGuidance(context);
      final fullMessage = recoveryGuidance.isNotEmpty
          ? '$baseMessage\n\n$recoveryGuidance'
          : baseMessage;

      AppLogger.info(
        '🚨 ERROR_ENGINE: Generated message: ${fullMessage.length > 100 ? '${fullMessage.substring(0, 100)}...' : fullMessage}',
      );
      return fullMessage;
    } catch (e) {
      AppLogger.error(
        '🚨 ERROR_ENGINE: Failed to generate contextual message: $e',
      );
      return _getFallbackMessage(context.actionContext);
    }
  }

  /// Generate the main error message with context and connectivity awareness
  static String _generateBaseMessage(ErrorContext context) {
    final action = context.actionContext.localizedDescription;

    switch (context.errorType) {
      case ErrorType.networkConnectivity:
        return _getNetworkErrorMessage(action, context.connectivity);

      case ErrorType.authentication:
        return _getAuthenticationErrorMessage(action, context);

      case ErrorType.notFound:
        return _getNotFoundErrorMessage(action, context);

      case ErrorType.serviceUnavailable:
        return _getServiceUnavailableMessage(action, context);

      case ErrorType.dnsResolution:
        return _getDnsErrorMessage(action, context);

      case ErrorType.unknown:
        return _getUnknownErrorMessage(action, context);
    }
  }

  /// Generate network-aware error messages
  static String _getNetworkErrorMessage(
    String action,
    ConnectivityResult connectivity,
  ) {
    final l = AppLocale.current;
    switch (connectivity) {
      case ConnectivityResult.none:
        return l.errorNetworkNoConnection(action);
      case ConnectivityResult.limited:
        return l.errorNetworkLimited(action);
      case ConnectivityResult.degraded:
        return l.errorNetworkDegraded(action);
      case ConnectivityResult.full:
        return l.errorNetworkTemporary(action);
      case ConnectivityResult.unknown:
        return l.errorNetworkUnknownStatus(action);
    }
  }

  /// Generate authentication error messages with context
  static String _getAuthenticationErrorMessage(
    String action,
    ErrorContext context,
  ) {
    final l = AppLocale.current;
    final baseMessage = l.errorAuthNoPermissionFor(action);

    final permissionLevel =
        context.additionalData?['permissionLevel'] as String?;
    final resourceOwner = context.additionalData?['resourceOwner'] as String?;
    final isAuthenticated =
        context.additionalData?['isAuthenticated'] as bool? ?? true;

    if (!isAuthenticated) {
      return l.errorAuthNotLoggedInWhile(baseMessage);
    }

    if (permissionLevel != null) {
      switch (permissionLevel) {
        case 'viewer':
          return l.errorAuthViewerOnly(baseMessage);
        case 'editor':
          return l.errorAuthEditorRequired(baseMessage);
        case 'none':
          return l.errorAuthNotShared(baseMessage);
      }
    }

    if (resourceOwner != null) {
      return l.errorAuthOwnerOnly(baseMessage, resourceOwner);
    }

    return l.errorAuthContactOwner(baseMessage);
  }

  /// Generate not found error messages
  static String _getNotFoundErrorMessage(String action, ErrorContext context) {
    final l = AppLocale.current;
    // Match on action context enum rather than string content
    switch (context.actionContext) {
      case UserActionContext.recipeSaving:
      case UserActionContext.recipeLoading:
      case UserActionContext.recipeDeleting:
      case UserActionContext.recipeUploading:
      case UserActionContext.recipeValidation:
      case UserActionContext.recipeCollaborativeSync:
      case UserActionContext.recipeDraftRestore:
        return l.errorNotFoundRecipe(action);
      case UserActionContext.shoppingListCreate:
      case UserActionContext.shoppingItemAdd:
      case UserActionContext.shoppingListSync:
      case UserActionContext.shoppingListShare:
      case UserActionContext.shoppingListDelete:
        return l.errorNotFoundShoppingList(action);
      case UserActionContext.recipeImageUpload:
      case UserActionContext.recipeImageProcessing:
      case UserActionContext.recipeImageDelete:
        return l.errorNotFoundImage(action);
      default:
        return l.errorNotFoundGeneric(action);
    }
  }

  /// Generate service unavailable error messages
  static String _getServiceUnavailableMessage(
    String action,
    ErrorContext context,
  ) {
    final l = AppLocale.current;
    final isMaintenanceTime = _isMaintenanceTime();

    if (isMaintenanceTime) {
      return l.errorServiceMaintenance(action);
    }

    // Check sync-related contexts by enum
    switch (context.actionContext) {
      case UserActionContext.shoppingListSync:
      case UserActionContext.socialSync:
      case UserActionContext.dataSync:
      case UserActionContext.shoppingListShare:
      case UserActionContext.recipeCollaborativeSync:
        return l.errorServiceSync(action);
      default:
        return l.errorServiceTemporary(action);
    }
  }

  /// Generate DNS resolution error messages
  static String _getDnsErrorMessage(String action, ErrorContext context) {
    return AppLocale.current.errorDnsConnection(action);
  }

  /// Generate unknown error messages with context
  static String _getUnknownErrorMessage(String action, ErrorContext context) {
    final l = AppLocale.current;
    if (context.technicalDetails != null &&
        context.severity != ErrorSeverity.minimal) {
      return l.errorUnknownWithTechnical(action, context.technicalDetails!);
    }
    return l.errorUnknownWhileAction(action);
  }

  /// Generate recovery guidance based on error context
  static String _generateRecoveryGuidance(ErrorContext context) {
    final recoveryActions = <String>[];

    // Add context-specific recovery actions
    recoveryActions.addAll(_getContextSpecificActions(context));

    // Add user-provided recovery actions
    if (context.recoveryActions != null) {
      recoveryActions.addAll(context.recoveryActions!);
    }

    if (recoveryActions.isEmpty) return '';

    final label = AppLocale.current.suggestionLabel;
    final actionText = recoveryActions.length == 1
        ? '$label ${recoveryActions.first}'
        : '$label\n${recoveryActions.map((action) => '• $action').join('\n')}';

    return actionText;
  }

  /// Get context-specific recovery actions
  static List<String> _getContextSpecificActions(ErrorContext context) {
    final l = AppLocale.current;
    final actions = <String>[];

    switch (context.actionContext) {
      case UserActionContext.recipeSaving:
        if (context.errorType == ErrorType.networkConnectivity) {
          actions.add(l.suggestionSavedLocally);
        } else if (context.errorType == ErrorType.authentication) {
          actions.add(l.suggestionCheckLoggedIn);
          actions.add(l.suggestionRequestPermission);
        }
        break;

      case UserActionContext.recipeImageUpload:
        if (context.errorType == ErrorType.networkConnectivity) {
          actions.add(l.suggestionImageSavedLocally);
        } else {
          actions.add(l.suggestionImageSizeLimit);
          actions.add(l.suggestionImageFormat);
        }
        break;

      case UserActionContext.recipeDraftRestore:
        actions.add(l.suggestionSelectAnotherDraft);
        actions.add(l.suggestionCreateNewRecipe);
        break;

      case UserActionContext.friendInvite:
      case UserActionContext.socialSync:
        if (context.errorType == ErrorType.authentication) {
          actions.add(l.suggestionCheckLoggedIn);
          actions.add(l.suggestionUpdateAccountSettings);
        }
        break;

      default:
        switch (context.errorType) {
          case ErrorType.networkConnectivity:
            actions.add(l.suggestionCheckConnection);
            actions.add(l.suggestionRetryWhenStable);
            break;
          case ErrorType.authentication:
            actions.add(l.suggestionLoginAgain);
            break;
          case ErrorType.serviceUnavailable:
            actions.add(l.suggestionRetryInMinutes);
            break;
          default:
            actions.add(l.suggestionRetryOrContactSupport);
        }
    }

    return actions;
  }

  /// Get fallback message when error generation fails
  static String _getFallbackMessage(UserActionContext context) {
    return AppLocale.current.errorFallbackWhileAction(
      context.localizedDescription,
    );
  }

  /// Check if current time is during maintenance window (simple heuristic)
  static bool _isMaintenanceTime() {
    final now = clock.now();
    // Assume maintenance between 2-4 AM local time
    return now.hour >= 2 && now.hour < 4;
  }

  /// Generate error message with simplified interface
  static String generateSimpleMessage({
    required ErrorType errorType,
    required UserActionContext actionContext,
    ConnectivityResult connectivity = ConnectivityResult.full,
    String? technicalDetails,
    List<String>? recoveryActions,
  }) {
    final context = ErrorContext.fromCurrentState(
      errorType: errorType,
      actionContext: actionContext,
      connectivity: connectivity,
      technicalDetails: technicalDetails,
      recoveryActions: recoveryActions,
    );

    return generateMessage(context);
  }
}
