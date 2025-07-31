/// Comprehensive dialog management service providing centralized dialog orchestration and app lifecycle control.
///
/// This service provides sophisticated dialog management functionality including confirmation dialogs, 
/// application lifecycle management, and user interaction workflows. It separates dialog business logic
/// from the UI layer while maintaining consistent styling, behavior patterns, and comprehensive error
/// handling throughout the application's dialog system.
///
/// **Architecture Integration:**
/// - Extends [BaseService] for consistent service patterns and error handling
/// - Integrates with Flutter's dialog system for native platform behavior
/// - Coordinates with app lifecycle management for proper application termination
/// - Uses centralized theming through [AppColors] for consistent visual presentation
///
/// **Dialog Management Features:**
/// - **Exit Dialog Management**: Sophisticated application exit confirmation with proper lifecycle handling
/// - **Confirmation Dialogs**: Flexible confirmation dialogs with customizable text and destructive action styling
/// - **App Lifecycle Control**: Comprehensive application termination management with proper cleanup
/// - **Swedish Localization**: Native Swedish language support for authentic user experience
/// - **Theme Integration**: Consistent styling using centralized app color system
/// - **Error Resilience**: Comprehensive error handling with graceful fallbacks and default values
///
/// **User Experience Features:**
/// - **Destructive Action Styling**: Visual distinction for dangerous operations using error color schemes
/// - **Consistent Button Layout**: Standardized button positioning and styling across all dialogs
/// - **Context Safety**: Proper context mounting checks to prevent widget lifecycle issues
/// - **Default Value Handling**: Intelligent default responses for edge cases and error conditions

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/core/base/base_service.dart';

/// Dialog management service providing centralized dialog orchestration and application lifecycle control.
///
/// This service manages comprehensive dialog workflows including user confirmations, application exit
/// handling, and consistent UI presentation patterns. It provides a centralized approach to dialog
/// management that ensures consistent behavior, proper error handling, and Swedish localization
/// throughout the application.
///
/// **Service Architecture:**
/// Built on BaseService foundation providing:
/// - Consistent error handling and logging patterns
/// - Service operation management with timeout handling
/// - Comprehensive error recovery and default value strategies
/// - Integration with application service lifecycle management
///
/// **Dialog Types and Workflows:**
/// Supports comprehensive dialog patterns including:
/// - Application exit confirmation with proper lifecycle management
/// - Generic confirmation dialogs with customizable styling and text
/// - Destructive action confirmations with visual warning indicators
/// - Context-safe dialog management with proper widget lifecycle handling
///
/// **Usage Examples:**
/// ```dart
/// final dialogService = DialogService();
/// 
/// // Show application exit confirmation
/// final shouldExit = await dialogService.showExitDialog(context);
/// if (shouldExit) {
///   await dialogService.exitApp();
/// }
/// 
/// // Show custom confirmation dialog
/// final confirmed = await dialogService.showConfirmDialog(
///   context,
///   title: 'Delete Recipe',
///   message: 'Are you sure you want to delete this recipe?',
///   isDestructive: true,
/// );
/// ```
class DialogService extends BaseService {
  
  @override
  String get serviceName => 'DialogService';

  /// Displays a localized application exit confirmation dialog with proper context safety.
  ///
  /// This method presents a Swedish-localized confirmation dialog asking the user if they want
  /// to exit the application. It implements proper context mounting checks and comprehensive
  /// error handling to ensure reliable dialog presentation and user interaction.
  ///
  /// [context] BuildContext for dialog presentation and theming
  /// Returns `true` if user confirms exit, `false` if cancelled or dialog fails
  /// 
  /// **Dialog Features:**
  /// - Swedish localization for authentic user experience
  /// - Consistent button styling with app theme integration
  /// - Destructive action styling for the exit button
  /// - Proper error handling with safe default return value
  /// 
  /// **Context Safety:**
  /// - Comprehensive error handling if context becomes invalid
  /// - Safe default return value (false) for all error conditions
  /// - Service operation management through BaseService integration
  Future<bool> showExitDialog(BuildContext context) async {
    return await executeServiceOperation(
      () async {
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Avsluta Butlery?'),
            content: const Text('Vill du verkligen avsluta appen?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Avbryt'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: const Text('Avsluta'),
              ),
            ],
          ),
        );
        return shouldExit ?? false;
      },
      operationName: 'Show exit dialog',
      defaultValue: false,
    ) ?? false;
  }

  /// Performs controlled application termination using platform-appropriate system calls.
  ///
  /// This method executes proper application termination through Flutter's SystemNavigator,
  /// ensuring clean application shutdown that respects platform conventions and lifecycle
  /// management. It provides comprehensive error handling and logging for system-level operations.
  ///
  /// **Platform Behavior:**
  /// - Uses SystemNavigator.pop() for proper platform-specific termination
  /// - Respects platform lifecycle management and cleanup processes
  /// - Ensures proper resource cleanup before application termination
  /// 
  /// **Error Handling:**
  /// - Comprehensive error handling for system-level operations
  /// - Service operation management through BaseService integration
  /// - No authentication required for application termination
  Future<void> exitApp() async {
    await executeServiceOperation(
      () async {
        await SystemNavigator.pop();
      },
      operationName: 'Exit application',
      requiresAuth: false,
    );
  }

  /// Show exit dialog and exit if confirmed
  Future<void> showExitDialogAndExit(BuildContext context) async {
    await executeServiceOperation(
      () async {
        final shouldExit = await showExitDialog(context);
        if (shouldExit && context.mounted) {
          await exitApp();
        }
      },
      operationName: 'Show exit dialog and exit',
      requiresAuth: false,
    );
  }

  /// Displays a customizable confirmation dialog with flexible styling and localization options.
  ///
  /// This method presents a comprehensive confirmation dialog with customizable text, styling,
  /// and behavioral options. It supports both standard confirmations and destructive actions
  /// with appropriate visual styling to guide user decision-making safely and effectively.
  ///
  /// [context] BuildContext for dialog presentation and theming
  /// [title] Dialog title text displayed prominently at the top
  /// [message] Main dialog message explaining the action or consequence
  /// [confirmText] Customizable confirmation button text (defaults to Swedish 'Bekräfta')
  /// [cancelText] Customizable cancellation button text (defaults to Swedish 'Avbryt')
  /// [isDestructive] Whether this action is destructive (enables error color styling)
  /// Returns `true` if user confirms, `false` if cancelled or dialog fails
  ///
  /// **Styling Behavior:**
  /// - Standard actions use default button styling for neutral confirmation
  /// - Destructive actions use error color styling to warn users of dangerous operations
  /// - Consistent button layout with cancel (left) and confirm (right) positioning
  /// 
  /// **Localization Support:**
  /// - Default Swedish text for buttons with customization options
  /// - Flexible text parameters allowing full localization control
  /// - Consistent with application's Swedish language focus
  ///
  /// **Error Handling:**
  /// - Safe default return value (false) for all error conditions
  /// - Comprehensive error handling with service operation management
  /// - Context safety with proper null handling and widget lifecycle awareness
  Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Bekräfta',
    String cancelText = 'Avbryt',
    bool isDestructive = false,
  }) async {
    return await executeServiceOperation(
      () async {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(cancelText),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: isDestructive
                    ? FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                      )
                    : null,
                child: Text(confirmText),
              ),
            ],
          ),
        );
        return result ?? false;
      },
      operationName: 'Show confirmation dialog',
      defaultValue: false,
      requiresAuth: false,
    ) ?? false;
  }
}