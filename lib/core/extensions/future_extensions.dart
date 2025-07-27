// lib/core/extensions/future_extensions.dart

import 'dart:async';
import 'package:butlery/core/error/failures.dart';

extension FutureTimeout<T> on Future<T> {
  /// Lägger till timeout med custom error handling
  Future<T> withTimeout({
    Duration duration = const Duration(seconds: 30),
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
      duration: const Duration(seconds: 5),
      timeoutMessage:
          'Operationen tog för lång tid. Kontrollera din internetanslutning.',
    );
  }

  /// Lång timeout för uppladdningar eller nedladdningar
  Future<T> withLongTimeout() {
    return withTimeout(
      duration: const Duration(minutes: 2),
      timeoutMessage:
          'Operationen avbröts efter 2 minuter. Försök igen med en mindre fil.',
    );
  }
}
