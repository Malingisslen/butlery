// lib/core/error/error_handler.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'failures.dart';
import '../../theme/app_theme.dart';

class ErrorHandler {
  /// Konverterar olika typer av exceptions till Failure objekt
  static Failure handleError(dynamic error) {
    debugPrint('ErrorHandler: ${error.runtimeType} - $error');

    if (error is Failure) {
      return error;
    }

    if (error is FirebaseException) {
      return _handleFirebaseError(error);
    }

    if (error is TimeoutException) {
      return TimeoutFailure(
        message: 'Operationen tog för lång tid. Försök igen.',
        originalError: error,
      );
    }

    if (error is SocketException) {
      return NetworkFailure(
        message:
            'Ingen internetanslutning. Kontrollera din anslutning och försök igen.',
        code: 'no_internet',
        originalError: error,
      );
    }

    if (error is FormatException) {
      return ValidationFailure(
        message: 'Ogiltigt dataformat: ${error.message}',
        code: 'format_error',
      );
    }

    return UnknownFailure(
      message: 'Ett oväntat fel uppstod: ${error.toString()}',
      originalError: error,
    );
  }

  /// Hanterar Firebase-specifika fel
  static Failure _handleFirebaseError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return NetworkFailure(
          message: 'Du har inte behörighet att utföra denna åtgärd.',
          code: error.code,
          originalError: error,
        );

      case 'unavailable':
        return NetworkFailure(
          message: 'Tjänsten är tillfälligt otillgänglig. Försök igen senare.',
          code: error.code,
          originalError: error,
        );

      case 'deadline-exceeded':
        return TimeoutFailure(
          message: 'Förfrågan tog för lång tid. Försök igen.',
        );

      case 'not-found':
        return NetworkFailure(
          message: 'Det efterfrågade innehållet hittades inte.',
          code: error.code,
          originalError: error,
        );

      default:
        return NetworkFailure(
          message: error.message ?? 'Ett Firebase-fel uppstod.',
          code: error.code,
          originalError: error,
        );
    }
  }

  /// Visar fel som Snackbar
  static void showErrorSnackbar(
    BuildContext context,
    Failure failure, {
    VoidCallback? onRetry,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.neutralLight),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                failure.message,
                style: const TextStyle(color: AppTheme.neutralLight),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: AppTheme.snackbarDuration,
        action:
            onRetry != null
                ? SnackBarAction(
                  label: 'Försök igen',
                  textColor: AppTheme.neutralLight,
                  onPressed: onRetry,
                )
                : null,
      ),
    );
  }

  /// Logger för utveckling
  static void logError(dynamic error, StackTrace? stackTrace) {
    debugPrint('=== ERROR LOG ===');
    debugPrint('Error: $error');
    if (stackTrace != null) {
      debugPrint('StackTrace: $stackTrace');
    }
    debugPrint('=================');
  }
}
