// lib/core/errors/contextual_error_engine.dart

import 'package:butlery/core/mixins/error_handling_mixin.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/connectivity_check.dart';

/// User action contexts for intelligent error message generation
enum UserActionContext {
  // Recipe contexts
  recipeSaving('sparar recept'),
  recipeUploading('laddar upp recept'),
  recipeLoading('laddar recept'),
  recipeDeleting('tar bort recept'),
  recipeValidation('validerar recept'),
  recipeCollaborativeSync('synkroniserar delat recept'),
  recipeDraftRestore('återställer utkast'),

  // Image contexts
  recipeImageUpload('laddar upp bilder'),
  recipeImageProcessing('bearbetar bilder'),
  recipeImageDelete('tar bort bild'),

  // Shopping contexts
  shoppingListCreate('skapar inköpslista'),
  shoppingItemAdd('lägger till vara'),
  shoppingListSync('synkroniserar inköpslista'),
  shoppingListShare('delar inköpslista'),
  shoppingListDelete('tar bort inköpslista'),

  // Social contexts
  friendInvite('skickar väninvitation'),
  groupCreate('skapar grupp'),
  messagesSend('skickar meddelande'),
  socialSync('synkroniserar socialt innehåll'),
  userProfileUpdate('uppdaterar profil'),
  permissionRequest('begär behörighet'),

  // System contexts
  appStartup('startar app'),
  dataSync('synkroniserar data'),
  backgroundUpload('bakgrundsuppladdning'),
  offline('offline-operation');

  const UserActionContext(this.swedishDescription);

  /// Human-readable Swedish description of the action
  final String swedishDescription;
}

/// Error severity levels for progressive disclosure
enum ErrorSeverity {
  minimal('minimal'), // Just show icon/indicator
  standard('standard'), // Show standard message
  detailed('detailed'), // Show detailed message with context
  diagnostic('diagnostic'); // Show full diagnostic information

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
      timestamp: DateTime.now(),
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
          '🚨 ERROR_ENGINE: Generating contextual message for ${context.actionContext.name} - ${context.errorType.name}');

      final baseMessage = _generateBaseMessage(context);
      final recoveryGuidance = _generateRecoveryGuidance(context);
      final fullMessage = recoveryGuidance.isNotEmpty
          ? '$baseMessage\n\n$recoveryGuidance'
          : baseMessage;

      AppLogger.info(
          '🚨 ERROR_ENGINE: Generated message: ${fullMessage.length > 100 ? '${fullMessage.substring(0, 100)}...' : fullMessage}');
      return fullMessage;
    } catch (e) {
      AppLogger.error(
          '🚨 ERROR_ENGINE: Failed to generate contextual message: $e');
      return _getFallbackMessage(context.actionContext);
    }
  }

  /// Generate the main error message with context and connectivity awareness
  static String _generateBaseMessage(ErrorContext context) {
    final action = context.actionContext.swedishDescription;

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
      String action, ConnectivityResult connectivity) {
    switch (connectivity) {
      case ConnectivityResult.none:
        return 'Ingen internetanslutning medan $action. Ändringar sparas lokalt och synkroniseras automatiskt när du är online igen.';

      case ConnectivityResult.limited:
        return 'Begränsad internetanslutning medan $action. Vissa funktioner kan vara otillgängliga.';

      case ConnectivityResult.degraded:
        return 'Anslutningsproblem medan $action. DNS-problem upptäckta, kontrollerar anslutningen automatiskt.';

      case ConnectivityResult.full:
        return 'Tillfälligt nätverksfel medan $action. Kontrollerar anslutningen och försöker igen automatiskt.';

      case ConnectivityResult.unknown:
        return 'Okänd anslutningsstatus medan $action. Kontrollera internetanslutningen och försök igen.';
    }
  }

  /// Generate authentication error messages with context
  static String _getAuthenticationErrorMessage(
      String action, ErrorContext context) {
    final baseMessage = 'Du saknar behörighet för $action';

    // Check for specific permission context from additional data
    final permissionLevel =
        context.additionalData?['permissionLevel'] as String?;
    final resourceOwner = context.additionalData?['resourceOwner'] as String?;
    final isAuthenticated =
        context.additionalData?['isAuthenticated'] as bool? ?? true;

    if (!isAuthenticated) {
      return '$baseMessage eftersom du inte är inloggad.';
    }

    if (permissionLevel != null) {
      switch (permissionLevel) {
        case 'viewer':
          return '$baseMessage. Du har endast läsrättigheter för detta innehåll.';
        case 'editor':
          return '$baseMessage. Redigeringsrättigheter krävs för denna åtgärd.';
        case 'none':
          return '$baseMessage. Du har inte delats detta innehåll.';
      }
    }

    if (resourceOwner != null) {
      return '$baseMessage. Endast ägaren ($resourceOwner) kan utföra denna åtgärd.';
    }

    return '$baseMessage. Kontakta innehållsägaren för utökade rättigheter.';
  }

  /// Generate not found error messages
  static String _getNotFoundErrorMessage(String action, ErrorContext context) {
    if (action.contains('recept')) {
      return 'Receptet kunde inte hittas medan $action. Det kan ha blivit raderat eller flyttat av ägaren.';
    } else if (action.contains('inköpslista')) {
      return 'Inköpslistan kunde inte hittas medan $action. Den kan ha blivit raderad eller du har inte längre åtkomst.';
    } else if (action.contains('bild')) {
      return 'Bilden kunde inte hittas medan $action. Den kan ha blivit raderad eller flyttad.';
    }

    return 'Det begärda innehållet kunde inte hittas medan $action. Det kan ha blivit raderat eller du har inte längre åtkomst.';
  }

  /// Generate service unavailable error messages
  static String _getServiceUnavailableMessage(
      String action, ErrorContext context) {
    final isMaintenanceTime = _isMaintenanceTime();

    if (isMaintenanceTime) {
      return 'Tjänsten är temporärt otillgänglig för underhåll medan $action. Försök igen om några minuter.';
    }

    if (action.contains('synkroniserar') || action.contains('delar')) {
      return 'Synkroniseringstjänsten är temporärt otillgänglig medan $action. Ändringar sparas lokalt och synkroniseras automatiskt senare.';
    }

    return 'Tjänsten är temporärt otillgänglig medan $action. Försök igen om ett par minuter.';
  }

  /// Generate DNS resolution error messages
  static String _getDnsErrorMessage(String action, ErrorContext context) {
    return 'Kunde inte ansluta till servern medan $action. Kontrollera internetanslutningen eller försök igen senare.';
  }

  /// Generate unknown error messages with context
  static String _getUnknownErrorMessage(String action, ErrorContext context) {
    final technicalInfo = context.technicalDetails != null &&
            context.severity != ErrorSeverity.minimal
        ? ' (Teknisk information: ${context.technicalDetails})'
        : '';

    return 'Ett oväntat fel uppstod medan $action. Försök igen eller kontakta support om problemet kvarstår.$technicalInfo';
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

    final actionText = recoveryActions.length == 1
        ? 'Förslag: ${recoveryActions.first}'
        : 'Förslag:\n${recoveryActions.map((action) => '• $action').join('\n')}';

    return actionText;
  }

  /// Get context-specific recovery actions
  static List<String> _getContextSpecificActions(ErrorContext context) {
    final actions = <String>[];

    switch (context.actionContext) {
      case UserActionContext.recipeSaving:
        if (context.errorType == ErrorType.networkConnectivity) {
          actions.add('Receptet sparas lokalt och synkroniseras automatiskt');
        } else if (context.errorType == ErrorType.authentication) {
          actions.add('Kontrollera att du är inloggad');
          actions.add('Be om redigeringsrättigheter från receptägaren');
        }
        break;

      case UserActionContext.recipeImageUpload:
        if (context.errorType == ErrorType.networkConnectivity) {
          actions
              .add('Bilderna sparas lokalt och laddas upp automatiskt senare');
        } else {
          actions.add('Kontrollera att bilderna är mindre än 10MB');
          actions.add('Använd JPG, PNG eller HEIC format');
        }
        break;

      case UserActionContext.recipeDraftRestore:
        actions.add('Välj ett annat utkast från listan');
        actions.add('Börja skapa ett nytt recept istället');
        break;

      case UserActionContext.friendInvite:
      case UserActionContext.socialSync:
        if (context.errorType == ErrorType.authentication) {
          actions.add('Kontrollera att du är inloggad');
          actions.add('Uppdatera dina kontoinställningar');
        }
        break;

      default:
        // Generic recovery actions based on error type
        switch (context.errorType) {
          case ErrorType.networkConnectivity:
            actions.add('Kontrollera internetanslutningen');
            actions.add('Försök igen när anslutningen är stabil');
            break;
          case ErrorType.authentication:
            actions.add('Logga in på nytt');
            break;
          case ErrorType.serviceUnavailable:
            actions.add('Försök igen om några minuter');
            break;
          default:
            actions.add('Försök igen eller kontakta support');
        }
    }

    return actions;
  }

  /// Get fallback message when error generation fails
  static String _getFallbackMessage(UserActionContext context) {
    return 'Ett fel uppstod medan ${context.swedishDescription}. Försök igen.';
  }

  /// Check if current time is during maintenance window (simple heuristic)
  static bool _isMaintenanceTime() {
    final now = DateTime.now();
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
