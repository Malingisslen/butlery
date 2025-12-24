// lib/core/rate_limiting/rate_limiter.dart

import 'dart:async';
import 'package:butlery/core/utils/logger.dart';

/// Operation types for rate limiting
enum RateLimitOperation {
  // Authentication operations
  login,
  register,
  passwordReset,

  // Recipe CRUD operations
  createRecipe,
  updateRecipe,
  deleteRecipe,
  fetchRecipes,

  // Social operations
  addFriend,
  removeFriend,
  sendMessage,
  postComment,
  addReaction,
  shareContent,

  // Shopping operations
  createShoppingList,
  updateShoppingList,
  deleteShoppingList,

  // Menu operations
  createMenu,
  updateMenu,
  deleteMenu,

  // Import operations
  importRecipe,
  ocrExtraction,
  webScraping,
}

/// Rate limit configuration for an operation
class RateLimitConfig {
  final int maxTokens; // Maximum tokens in bucket
  final int refillRate; // Tokens added per refill interval
  final Duration refillInterval; // How often to refill

  const RateLimitConfig({
    required this.maxTokens,
    required this.refillRate,
    required this.refillInterval,
  });

  /// Tokens per second for this configuration
  double get tokensPerSecond => refillRate / refillInterval.inSeconds;
}

/// Token bucket for tracking rate limits
class TokenBucket {
  final RateLimitConfig config;
  double _tokens;
  DateTime _lastRefill;

  TokenBucket(this.config)
      : _tokens = config.maxTokens.toDouble(),
        _lastRefill = DateTime.now();

  /// Try to consume tokens, returns true if successful
  bool tryConsume(int tokens) {
    _refill();

    if (_tokens >= tokens) {
      _tokens -= tokens;
      return true;
    }

    return false;
  }

  /// Get current token count
  double get currentTokens {
    _refill();
    return _tokens;
  }

  /// Get time until next token is available
  Duration? get timeUntilNextToken {
    if (_tokens >= 1) return null;

    final tokensNeeded = 1 - _tokens;
    final secondsNeeded = tokensNeeded / config.tokensPerSecond;
    return Duration(milliseconds: (secondsNeeded * 1000).ceil());
  }

  /// Refill tokens based on elapsed time
  void _refill() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRefill);

    if (elapsed >= config.refillInterval) {
      final refills =
          elapsed.inMilliseconds / config.refillInterval.inMilliseconds;
      final tokensToAdd = refills * config.refillRate;

      _tokens = (_tokens + tokensToAdd).clamp(0.0, config.maxTokens.toDouble());
      _lastRefill = now;
    }
  }

  /// Reset bucket to full capacity (for testing)
  void reset() {
    _tokens = config.maxTokens.toDouble();
    _lastRefill = DateTime.now();
  }
}

/// Result of a rate limit check
class RateLimitResult {
  final bool allowed;
  final String? reason;
  final Duration? retryAfter;
  final int? remainingTokens;

  const RateLimitResult({
    required this.allowed,
    this.reason,
    this.retryAfter,
    this.remainingTokens,
  });

  factory RateLimitResult.allowed(int remainingTokens) {
    return RateLimitResult(
      allowed: true,
      remainingTokens: remainingTokens,
    );
  }

  factory RateLimitResult.denied({
    required String reason,
    Duration? retryAfter,
  }) {
    return RateLimitResult(
      allowed: false,
      reason: reason,
      retryAfter: retryAfter,
    );
  }
}

/// Client-side rate limiter using token bucket algorithm
class RateLimiter {
  static final RateLimiter _instance = RateLimiter._internal();
  factory RateLimiter() => _instance;
  RateLimiter._internal();

  final Map<RateLimitOperation, TokenBucket> _buckets = {};
  final Map<RateLimitOperation, int> _violationCounts = {};

  /// Default rate limit configurations
  static final Map<RateLimitOperation, RateLimitConfig> _defaultConfigs = {
    // Auth operations - very restrictive (DoS prevention)
    RateLimitOperation.login: const RateLimitConfig(
      maxTokens: 5,
      refillRate: 1,
      refillInterval: Duration(minutes: 1),
    ),
    RateLimitOperation.register: const RateLimitConfig(
      maxTokens: 3,
      refillRate: 1,
      refillInterval: Duration(hours: 1),
    ),
    RateLimitOperation.passwordReset: const RateLimitConfig(
      maxTokens: 3,
      refillRate: 1,
      refillInterval: Duration(hours: 1),
    ),

    // Recipe CRUD - moderate limits
    RateLimitOperation.createRecipe: const RateLimitConfig(
      maxTokens: 10,
      refillRate: 5,
      refillInterval: Duration(minutes: 1),
    ),
    RateLimitOperation.updateRecipe: const RateLimitConfig(
      maxTokens: 30,
      refillRate: 10,
      refillInterval: Duration(minutes: 1),
    ),
    RateLimitOperation.deleteRecipe: const RateLimitConfig(
      maxTokens: 10,
      refillRate: 5,
      refillInterval: Duration(minutes: 1),
    ),
    RateLimitOperation.fetchRecipes: const RateLimitConfig(
      maxTokens: 50,
      refillRate: 20,
      refillInterval: Duration(minutes: 1),
    ),

    // Social operations - higher limits for engagement
    RateLimitOperation.addFriend: const RateLimitConfig(
      maxTokens: 20,
      refillRate: 10,
      refillInterval: Duration(minutes: 1),
    ),
    RateLimitOperation.removeFriend: const RateLimitConfig(
      maxTokens: 10,
      refillRate: 5,
      refillInterval: Duration(minutes: 1),
    ),
    RateLimitOperation.sendMessage: const RateLimitConfig(
      maxTokens: 60,
      refillRate: 30,
      refillInterval: Duration(minutes: 1),
    ),
    RateLimitOperation.postComment: const RateLimitConfig(
      maxTokens: 30,
      refillRate: 15,
      refillInterval: Duration(minutes: 1),
    ),
    RateLimitOperation.addReaction: const RateLimitConfig(
      maxTokens: 100,
      refillRate: 50,
      refillInterval: Duration(minutes: 1),
    ),
    RateLimitOperation.shareContent: const RateLimitConfig(
      maxTokens: 20,
      refillRate: 10,
      refillInterval: Duration(minutes: 1),
    ),

    // Shopping operations
    RateLimitOperation.createShoppingList: const RateLimitConfig(
      maxTokens: 10,
      refillRate: 5,
      refillInterval: Duration(minutes: 1),
    ),
    RateLimitOperation.updateShoppingList: const RateLimitConfig(
      maxTokens: 50,
      refillRate: 20,
      refillInterval: Duration(minutes: 1),
    ),
    RateLimitOperation.deleteShoppingList: const RateLimitConfig(
      maxTokens: 10,
      refillRate: 5,
      refillInterval: Duration(minutes: 1),
    ),

    // Menu operations
    RateLimitOperation.createMenu: const RateLimitConfig(
      maxTokens: 10,
      refillRate: 5,
      refillInterval: Duration(minutes: 1),
    ),
    RateLimitOperation.updateMenu: const RateLimitConfig(
      maxTokens: 30,
      refillRate: 15,
      refillInterval: Duration(minutes: 1),
    ),
    RateLimitOperation.deleteMenu: const RateLimitConfig(
      maxTokens: 10,
      refillRate: 5,
      refillInterval: Duration(minutes: 1),
    ),

    // Import operations - expensive, restrictive limits
    RateLimitOperation.importRecipe: const RateLimitConfig(
      maxTokens: 10,
      refillRate: 3,
      refillInterval: Duration(minutes: 1),
    ),
    RateLimitOperation.ocrExtraction: const RateLimitConfig(
      maxTokens: 5,
      refillRate: 2,
      refillInterval: Duration(minutes: 1),
    ),
    RateLimitOperation.webScraping: const RateLimitConfig(
      maxTokens: 10,
      refillRate: 3,
      refillInterval: Duration(minutes: 1),
    ),
  };

  /// Check if operation is allowed under rate limits
  RateLimitResult checkLimit(
    RateLimitOperation operation, {
    int tokens = 1,
  }) {
    final bucket = _getBucket(operation);

    if (bucket.tryConsume(tokens)) {
      final remaining = bucket.currentTokens.floor();
      AppLogger.debug(
          '✅ Rate limit OK: ${operation.name} ($remaining tokens remaining)');

      return RateLimitResult.allowed(remaining);
    }

    // Rate limit exceeded
    _violationCounts[operation] = (_violationCounts[operation] ?? 0) + 1;
    final retryAfter = bucket.timeUntilNextToken;

    AppLogger.warning(
      '⚠️ Rate limit exceeded: ${operation.name} '
      '(retry after: ${retryAfter?.inSeconds}s, '
      'violations: ${_violationCounts[operation]})',
    );

    return RateLimitResult.denied(
      reason: 'Rate limit exceeded for ${operation.name}',
      retryAfter: retryAfter,
    );
  }

  /// Execute operation with rate limit check
  Future<T> executeWithLimit<T>(
    RateLimitOperation operation,
    Future<T> Function() action, {
    int tokens = 1,
  }) async {
    final result = checkLimit(operation, tokens: tokens);

    if (!result.allowed) {
      throw RateLimitException(
        message: result.reason ?? 'Rate limit exceeded',
        operation: operation,
        retryAfter: result.retryAfter,
      );
    }

    return await action();
  }

  /// Get or create bucket for operation
  TokenBucket _getBucket(RateLimitOperation operation) {
    return _buckets.putIfAbsent(operation, () {
      final config = _defaultConfigs[operation];
      if (config == null) {
        throw ArgumentError('No rate limit config for ${operation.name}');
      }
      return TokenBucket(config);
    });
  }

  /// Get current token count for operation
  double getCurrentTokens(RateLimitOperation operation) {
    final bucket = _buckets[operation];
    return bucket?.currentTokens ??
        _defaultConfigs[operation]!.maxTokens.toDouble();
  }

  /// Get violation count for operation
  int getViolationCount(RateLimitOperation operation) {
    return _violationCounts[operation] ?? 0;
  }

  /// Get statistics for monitoring
  Map<String, dynamic> getStatistics() {
    final stats = <String, dynamic>{};

    for (final operation in RateLimitOperation.values) {
      final bucket = _buckets[operation];
      final config = _defaultConfigs[operation];

      stats[operation.name] = {
        'currentTokens': bucket?.currentTokens ?? config?.maxTokens,
        'maxTokens': config?.maxTokens,
        'tokensPerSecond': config?.tokensPerSecond,
        'violations': _violationCounts[operation] ?? 0,
      };
    }

    return stats;
  }

  /// Reset all rate limits (for testing)
  void reset() {
    _buckets.clear();
    _violationCounts.clear();
    AppLogger.info('🔄 Rate limiter reset');
  }

  /// Reset specific operation (for testing)
  void resetOperation(RateLimitOperation operation) {
    _buckets[operation]?.reset();
    _violationCounts.remove(operation);
    AppLogger.debug('🔄 Rate limiter reset: ${operation.name}');
  }
}

/// Exception thrown when rate limit is exceeded
class RateLimitException implements Exception {
  final String message;
  final RateLimitOperation operation;
  final Duration? retryAfter;

  RateLimitException({
    required this.message,
    required this.operation,
    this.retryAfter,
  });

  @override
  String toString() {
    final retry =
        retryAfter != null ? ' (retry after ${retryAfter!.inSeconds}s)' : '';
    return 'RateLimitException: $message$retry';
  }
}
