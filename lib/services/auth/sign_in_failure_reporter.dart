import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/services/auth/provider_sign_in_platform.dart';

/// Sends a failed Google/Apple sign-in to the `logSignInFailure` callable
/// (BUT-2502).
///
/// No consent check: Malin chose legitimate interest (2026-11-04), which holds
/// because nothing personal is sent: the provider, the step, the platform and
/// the error code, each from a closed list or a code pattern the server checks
/// again.
class SignInFailureReporter {
  SignInFailureReporter({
    required Future<void> Function(Map<String, String> payload) send,
    String? platform,
  }) : _send = send,
       _platform = platform ?? _currentPlatform();

  /// The real sender: the `logSignInFailure` callable.
  factory SignInFailureReporter.viaFunctions(FirebaseFunctions functions) =>
      SignInFailureReporter(
        send: (payload) =>
            functions.httpsCallable('logSignInFailure').call<void>(payload),
      );

  final Future<void> Function(Map<String, String> payload) _send;
  final String? _platform;

  static const String stageSignIn = 'signIn';
  static const String stageRecovered = 'signInRecovered';

  /// Fire and forget: a report never delays or fails the sign-in.
  void report(SignInProvider provider, Object error, {bool recovered = false}) {
    final platform = _platform;
    if (platform == null) return;
    final payload = {
      'provider': provider.analyticsMethod,
      'stage': recovered ? stageRecovered : stageSignIn,
      'platform': platform,
      'code': codeFor(error),
    };
    unawaited(
      _send(payload).timeout(const Duration(seconds: 10)).catchError((
        Object e,
      ) {
        AppLogger.warning('Sign-in failure report not sent: ${e.runtimeType}');
      }),
    );
  }

  /// The code the server accepts: Firebase's own, or the app's kind of error
  /// with a prefix. Never the error's message, which can repeat an address.
  static String codeFor(Object error) {
    final raw = switch (error) {
      FirebaseAuthException(:final code) => code,
      ProviderSheetException(:final reason) => 'sheet:$reason',
      _ => 'dart:${error.runtimeType}',
    };
    final cleaned = raw
        .replaceAll(RegExp(r'[^A-Za-z0-9:_.-]+'), '.')
        .replaceAll(RegExp(r'^[^A-Za-z0-9]+'), '');
    if (cleaned.isEmpty) return 'unknown';
    return cleaned.length > 64 ? cleaned.substring(0, 64) : cleaned;
  }

  static String? _currentPlatform() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
  }
}
