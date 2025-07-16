// lib/core/extensions/future_extensions.dart

import 'dart:async';
import '../error/failures.dart';
import '../../theme/app_theme.dart';

extension FutureTimeout<T> on Future<T> {
  /// Lägger till timeout med custom error handling
  Future<T> withTimeout({
    Duration duration = AppTheme.wait30s,
    String? timeoutMessage,
  }) {
    return timeout(
      duration,
      onTimeout: () {
        throw TimeoutFailure(
          message:
              timeoutMessage ??
              'Operationen tog för lång tid (${duration.inSeconds}s). Försök igen.',
        );
      },
    );
  }

  /// Kort timeout för snabba operationer
  Future<T> withShortTimeout() {
    return withTimeout(
      duration: AppTheme.wait5s,
      timeoutMessage:
          'Operationen tog för lång tid. Kontrollera din internetanslutning.',
    );
  }

  /// Lång timeout för uppladdningar eller nedladdningar
  Future<T> withLongTimeout() {
    return withTimeout(
      duration: AppTheme.wait2m,
      timeoutMessage:
          'Operationen avbröts efter 2 minuter. Försök igen med en mindre fil.',
    );
  }
}
