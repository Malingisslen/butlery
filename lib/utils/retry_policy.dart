/// Generic exponential-backoff retry helper for user-initiated network calls.
///
/// Use this for **idempotent** operations on the user-initiated path
/// (image upload, recipe save retry, share-extract). Do NOT wrap blanket — a
/// non-idempotent network call (e.g. one that creates a new resource without
/// a client-side dedup key) should not be retried, or must be made idempotent
/// first (typically by passing a stable client-generated UUID).
///
/// Default policy:
/// * 3 attempts
/// * Base delays: 1s, 2s, 4s with ±25% random jitter
/// * Retries on: network errors (`SocketException`, timeouts), HTTP 5xx,
///   FirebaseException codes `unavailable` / `deadline-exceeded` / `internal`.
/// * Does NOT retry on: `permission-denied`, `not-found`, validation errors,
///   cancellations, or any FirebaseException code that maps to a "user broke
///   the rules" failure mode.
///
/// Designed to compose under the existing upload-layer retry/circuit-breaker
/// in `UploadRetryManager` — that manager owns the upload-specific state
/// machine (queue, circuit breaker, progress); this helper is for the
/// remaining user-initiated call sites that don't have their own machinery.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

/// Test-injectable random source for jitter — allows deterministic tests.
typedef RetryRandom = double Function();

/// Test-injectable sleep — allows tests to advance virtual time without waiting.
typedef RetrySleeper = Future<void> Function(Duration);

/// Default retryability predicate.
///
/// Returns `true` for transient errors that are reasonable to retry, and
/// `false` for errors that indicate the caller (or input) is wrong and a
/// retry would just waste work and the user's quota.
bool defaultIsRetryable(Object error) {
  // Network-layer transients
  if (error is SocketException) return true;
  if (error is TimeoutException) return true;
  if (error is HttpException) return true;
  if (error is http.ClientException) return true;

  // Firebase: only the truly transient codes
  if (error is FirebaseException) {
    const retryable = {'unavailable', 'deadline-exceeded', 'internal'};
    return retryable.contains(error.code);
  }

  // Heuristic last-resort: explicit 5xx in stringified error
  final s = error.toString().toLowerCase();
  if (s.contains('http 5') || s.contains('status: 5')) return true;

  return false;
}

/// Run [op] with exponential-backoff retries.
///
/// Throws the original exception from the final attempt if all retries fail.
///
/// Parameters:
/// * [maxAttempts] — total tries including the first. Min 1. Default 3.
/// * [initialDelay] — base delay before the first retry. Default 1s.
/// * [isRetryable] — predicate; defaults to [defaultIsRetryable].
/// * [maxDelay] — caps the per-retry sleep. Default 30s.
/// * [jitterFraction] — ±fraction applied to each delay. Default 0.25 (±25%).
/// * [random] / [sleeper] — test injection points; leave null in production.
Future<T> withRetry<T>(
  Future<T> Function() op, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(seconds: 1),
  bool Function(Object e)? isRetryable,
  Duration maxDelay = const Duration(seconds: 30),
  double jitterFraction = 0.25,
  RetryRandom? random,
  RetrySleeper? sleeper,
}) async {
  assert(maxAttempts >= 1, 'maxAttempts must be at least 1');
  assert(jitterFraction >= 0 && jitterFraction < 1,
      'jitterFraction must be in [0, 1)');

  final predicate = isRetryable ?? defaultIsRetryable;
  final rng = random ?? _defaultRng;
  final sleep = sleeper ?? Future.delayed;

  var attempt = 0;
  while (true) {
    attempt += 1;
    try {
      return await op();
    } catch (e) {
      final hasMoreAttempts = attempt < maxAttempts;
      if (!hasMoreAttempts || !predicate(e)) {
        rethrow;
      }
      final delay = _computeDelay(
        attempt: attempt,
        initialDelay: initialDelay,
        maxDelay: maxDelay,
        jitterFraction: jitterFraction,
        rng: rng,
      );
      await sleep(delay);
    }
  }
}

/// Compute the backoff for [attempt] (1-indexed: 1 means "after the 1st failure").
///
/// Exposed for unit tests so we can assert jitter bounds directly.
Duration _computeDelay({
  required int attempt,
  required Duration initialDelay,
  required Duration maxDelay,
  required double jitterFraction,
  required RetryRandom rng,
}) {
  // Exponential: initialDelay * 2^(attempt-1)
  // attempt=1 → initialDelay * 1 (=1s default)
  // attempt=2 → initialDelay * 2 (=2s)
  // attempt=3 → initialDelay * 4 (=4s)
  final exponent = math.min(attempt - 1, 16); // Guard against absurd values
  final baseMicros =
      (initialDelay.inMicroseconds * math.pow(2, exponent)).round();
  final cappedMicros = math.min(baseMicros, maxDelay.inMicroseconds);

  // Symmetric jitter: ±jitterFraction × delay
  final jitterRange = (cappedMicros * jitterFraction).round();
  final jitterOffset =
      jitterRange == 0 ? 0 : ((rng() * 2 - 1) * jitterRange).round();
  final finalMicros = math.max(0, cappedMicros + jitterOffset);

  return Duration(microseconds: finalMicros);
}

final _rng = math.Random();
double _defaultRng() => _rng.nextDouble();

/// Test hook: compute the delay schedule for a given configuration.
///
/// Returns the list of delays that would be used if every attempt failed.
/// Useful for asserting jitter bounds in unit tests.
@visibleForTesting
List<Duration> debugComputeSchedule({
  int maxAttempts = 3,
  Duration initialDelay = const Duration(seconds: 1),
  Duration maxDelay = const Duration(seconds: 30),
  double jitterFraction = 0.25,
  RetryRandom? random,
}) {
  final rng = random ?? _defaultRng;
  return [
    for (var attempt = 1; attempt < maxAttempts; attempt++)
      _computeDelay(
        attempt: attempt,
        initialDelay: initialDelay,
        maxDelay: maxDelay,
        jitterFraction: jitterFraction,
        rng: rng,
      ),
  ];
}
