// test/unit/core/rate_limiting/rate_limiter_test.dart

import 'package:butlery/core/rate_limiting/rate_limiter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RateLimitConfig', () {
    test('calculates tokens per second correctly', () {
      const config = RateLimitConfig(
        maxTokens: 60,
        refillRate: 10,
        refillInterval: Duration(seconds: 1),
      );

      expect(config.tokensPerSecond, 10.0);
    });

    test('handles different refill intervals', () {
      const config = RateLimitConfig(
        maxTokens: 60,
        refillRate: 1,
        refillInterval: Duration(minutes: 1),
      );

      expect(config.tokensPerSecond, 1 / 60);
    });
  });

  group('TokenBucket', () {
    late TokenBucket bucket;

    setUp(() {
      const config = RateLimitConfig(
        maxTokens: 10,
        refillRate: 5,
        refillInterval: Duration(seconds: 1),
      );
      bucket = TokenBucket(config);
    });

    test('starts with max tokens', () {
      expect(bucket.currentTokens, 10.0);
    });

    test('consumes tokens successfully when available', () {
      expect(bucket.tryConsume(5), true);
      expect(bucket.currentTokens, 5.0);
    });

    test('rejects consumption when insufficient tokens', () {
      bucket.tryConsume(8);
      expect(bucket.tryConsume(5), false);
      expect(bucket.currentTokens, 2.0); // 10 - 8 = 2
    });

    test('allows consumption of exact token count', () {
      expect(bucket.tryConsume(10), true);
      expect(bucket.currentTokens, 0.0);
    });

    test('rejects consumption when tokens exhausted', () {
      bucket.tryConsume(10);
      expect(bucket.tryConsume(1), false);
    });

    test('refills tokens over time', () async {
      bucket.tryConsume(10); // Exhaust all tokens
      expect(bucket.currentTokens, 0.0);

      // Wait for refill (refillRate: 5 tokens per second)
      await Future.delayed(const Duration(milliseconds: 1100));

      // Should have refilled approximately 5 tokens
      final tokens = bucket.currentTokens;
      expect(tokens, greaterThan(4.0));
      expect(tokens, lessThanOrEqualTo(10.0));
    });

    test('does not exceed max tokens on refill', () async {
      // Start with full bucket
      expect(bucket.currentTokens, 10.0);

      // Wait for refill interval
      await Future.delayed(const Duration(milliseconds: 1100));

      // Should still be at max
      expect(bucket.currentTokens, 10.0);
    });

    test('calculates time until next token', () {
      bucket.tryConsume(10); // Exhaust all tokens

      final timeUntilNext = bucket.timeUntilNextToken;
      expect(timeUntilNext, isNotNull);
      expect(timeUntilNext!.inMilliseconds, greaterThan(0));
    });

    test('returns null time when tokens available', () {
      expect(bucket.currentTokens, greaterThanOrEqualTo(1));
      expect(bucket.timeUntilNextToken, isNull);
    });

    test('reset restores full capacity', () {
      bucket.tryConsume(8);
      expect(bucket.currentTokens, 2.0);

      bucket.reset();
      expect(bucket.currentTokens, 10.0);
    });
  });

  group('RateLimitResult', () {
    test('creates allowed result with remaining tokens', () {
      final result = RateLimitResult.allowed(5);

      expect(result.allowed, true);
      expect(result.remainingTokens, 5);
      expect(result.reason, isNull);
      expect(result.retryAfter, isNull);
    });

    test('creates denied result with reason and retry time', () {
      final result = RateLimitResult.denied(
        reason: 'Too many requests',
        retryAfter: const Duration(seconds: 30),
      );

      expect(result.allowed, false);
      expect(result.reason, 'Too many requests');
      expect(result.retryAfter, const Duration(seconds: 30));
      expect(result.remainingTokens, isNull);
    });
  });

  group('RateLimiter', () {
    late RateLimiter limiter;

    setUp(() {
      limiter = RateLimiter();
      limiter.reset(); // Clear state from previous tests
    });

    tearDown(() {
      limiter.reset();
    });

    test('singleton pattern works', () {
      final limiter1 = RateLimiter();
      final limiter2 = RateLimiter();

      expect(identical(limiter1, limiter2), true);
    });

    test('allows operation within rate limits', () {
      final result = limiter.checkLimit(RateLimitOperation.createRecipe);

      expect(result.allowed, true);
      expect(result.remainingTokens, greaterThan(0));
    });

    test('denies operation when rate limit exceeded', () {
      const operation = RateLimitOperation.login;

      // Exhaust all tokens (max 5 for login)
      for (int i = 0; i < 5; i++) {
        limiter.checkLimit(operation);
      }

      // Next attempt should be denied
      final result = limiter.checkLimit(operation);
      expect(result.allowed, false);
      expect(result.reason, isNotNull);
      expect(result.retryAfter, isNotNull);
    });

    test('tracks violation counts', () {
      const operation = RateLimitOperation.register;

      // Exhaust tokens (max 3 for register)
      for (int i = 0; i < 3; i++) {
        limiter.checkLimit(operation);
      }

      expect(limiter.getViolationCount(operation), 0);

      // Trigger violations
      limiter.checkLimit(operation);
      expect(limiter.getViolationCount(operation), 1);

      limiter.checkLimit(operation);
      expect(limiter.getViolationCount(operation), 2);
    });

    test('different operations have independent limits', () {
      const op1 = RateLimitOperation.createRecipe;
      const op2 = RateLimitOperation.createMenu;

      // Exhaust op1 tokens (max 10)
      for (int i = 0; i < 10; i++) {
        limiter.checkLimit(op1);
      }

      // op1 should be denied
      expect(limiter.checkLimit(op1).allowed, false);

      // op2 should still be allowed
      expect(limiter.checkLimit(op2).allowed, true);
    });

    test('getCurrentTokens returns correct count', () {
      const operation = RateLimitOperation.addReaction;

      // Get initial tokens (should be max: 100)
      final initial = limiter.getCurrentTokens(operation);
      expect(initial, 100.0);

      // Consume some tokens
      limiter.checkLimit(operation, tokens: 30);
      final after = limiter.getCurrentTokens(operation);
      expect(after, 70.0);
    });

    test('getStatistics returns all operations', () {
      // Perform some operations
      limiter.checkLimit(RateLimitOperation.createRecipe);
      limiter.checkLimit(RateLimitOperation.sendMessage);

      final stats = limiter.getStatistics();

      expect(stats, isNotEmpty);
      expect(stats.containsKey('createRecipe'), true);
      expect(stats.containsKey('sendMessage'), true);

      final recipeStats = stats['createRecipe'] as Map<String, dynamic>;
      expect(recipeStats['maxTokens'], 10);
      expect(recipeStats['currentTokens'], lessThan(10));
    });

    test('executeWithLimit succeeds when allowed', () async {
      const operation = RateLimitOperation.fetchRecipes;

      final result = await limiter.executeWithLimit(
        operation,
        () async => 'success',
      );

      expect(result, 'success');
    });

    test('executeWithLimit throws when rate limited', () async {
      const operation = RateLimitOperation.passwordReset;

      // Exhaust tokens (max 3)
      for (int i = 0; i < 3; i++) {
        limiter.checkLimit(operation);
      }

      expect(
        () => limiter.executeWithLimit(operation, () async => 'success'),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('resetOperation clears specific operation', () {
      const operation = RateLimitOperation.deleteRecipe;

      // Exhaust tokens (max 10)
      for (int i = 0; i < 10; i++) {
        limiter.checkLimit(operation);
      }

      expect(limiter.checkLimit(operation).allowed, false);

      // Reset operation
      limiter.resetOperation(operation);

      // Should be back to max tokens
      expect(limiter.getCurrentTokens(operation), 10.0);

      // Should be allowed again
      expect(limiter.checkLimit(operation).allowed, true);
    });

    test('reset clears all operations', () {
      // Consume tokens from multiple operations
      limiter.checkLimit(RateLimitOperation.createRecipe, tokens: 5);
      limiter.checkLimit(RateLimitOperation.sendMessage, tokens: 30);

      limiter.reset();

      // All should be back to max
      expect(limiter.getCurrentTokens(RateLimitOperation.createRecipe), 10.0);
      expect(limiter.getCurrentTokens(RateLimitOperation.sendMessage), 60.0);
    });

    test('handles multi-token consumption', () {
      const operation = RateLimitOperation.updateRecipe;

      // Consume 15 tokens at once (max 30)
      final result = limiter.checkLimit(operation, tokens: 15);

      expect(result.allowed, true);
      expect(result.remainingTokens, 15);
    });

    test('denies multi-token consumption when insufficient', () {
      const operation = RateLimitOperation.createMenu;

      // Consume 8 tokens (max 10)
      limiter.checkLimit(operation, tokens: 8);

      // Try to consume 5 more (only 2 remaining)
      final result = limiter.checkLimit(operation, tokens: 5);

      expect(result.allowed, false);
    });

    group('Operation-specific limits', () {
      test('auth operations have strict limits', () {
        // Login: 5 max tokens
        expect(limiter.getCurrentTokens(RateLimitOperation.login), 5.0);

        // Register: 3 max tokens
        expect(limiter.getCurrentTokens(RateLimitOperation.register), 3.0);

        // Password reset: 3 max tokens
        expect(limiter.getCurrentTokens(RateLimitOperation.passwordReset), 3.0);
      });

      test('social operations have higher limits', () {
        // Add reaction: 100 max tokens
        expect(limiter.getCurrentTokens(RateLimitOperation.addReaction), 100.0);

        // Send message: 60 max tokens
        expect(limiter.getCurrentTokens(RateLimitOperation.sendMessage), 60.0);

        // Post comment: 30 max tokens
        expect(limiter.getCurrentTokens(RateLimitOperation.postComment), 30.0);
      });

      test('import operations have restrictive limits', () {
        // OCR extraction: 5 max tokens
        expect(limiter.getCurrentTokens(RateLimitOperation.ocrExtraction), 5.0);

        // Import recipe: 10 max tokens
        expect(limiter.getCurrentTokens(RateLimitOperation.importRecipe), 10.0);

        // Web scraping: 10 max tokens
        expect(limiter.getCurrentTokens(RateLimitOperation.webScraping), 10.0);
      });
    });
  });

  group('RateLimitException', () {
    test('formats message without retry time', () {
      final exception = RateLimitException(
        message: 'Rate limit exceeded',
        operation: RateLimitOperation.createRecipe,
      );

      expect(
        exception.toString(),
        'RateLimitException: Rate limit exceeded',
      );
    });

    test('formats message with retry time', () {
      final exception = RateLimitException(
        message: 'Too many requests',
        operation: RateLimitOperation.login,
        retryAfter: const Duration(seconds: 45),
      );

      expect(
        exception.toString(),
        'RateLimitException: Too many requests (retry after 45s)',
      );
    });

    test('includes operation information', () {
      final exception = RateLimitException(
        message: 'Limit exceeded',
        operation: RateLimitOperation.sendMessage,
      );

      expect(exception.operation, RateLimitOperation.sendMessage);
    });
  });

  group('Rate limit scenarios', () {
    late RateLimiter limiter;

    setUp(() {
      limiter = RateLimiter();
      limiter.reset();
    });

    tearDown(() {
      limiter.reset();
    });

    test('DoS attack prevention - rapid login attempts', () {
      const operation = RateLimitOperation.login;
      int successCount = 0;
      int blockedCount = 0;

      // Simulate 20 rapid login attempts
      for (int i = 0; i < 20; i++) {
        final result = limiter.checkLimit(operation);
        if (result.allowed) {
          successCount++;
        } else {
          blockedCount++;
        }
      }

      // Should allow only 5 (max tokens)
      expect(successCount, 5);
      expect(blockedCount, 15);
    });

    test('Normal usage - recipe creation spread over time', () async {
      const operation = RateLimitOperation.createRecipe;

      // Create 5 recipes
      for (int i = 0; i < 5; i++) {
        final result = limiter.checkLimit(operation);
        expect(result.allowed, true);
      }

      // Wait for refill (5 tokens per second)
      await Future.delayed(const Duration(milliseconds: 1100));

      // Should be able to create more recipes
      final result = limiter.checkLimit(operation);
      expect(result.allowed, true);
    });

    test('Mixed operations - realistic user session', () {
      // User logs in
      expect(limiter.checkLimit(RateLimitOperation.login).allowed, true);

      // Fetches recipes multiple times
      for (int i = 0; i < 10; i++) {
        expect(
          limiter.checkLimit(RateLimitOperation.fetchRecipes).allowed,
          true,
        );
      }

      // Creates a recipe
      expect(limiter.checkLimit(RateLimitOperation.createRecipe).allowed, true);

      // Sends messages
      for (int i = 0; i < 20; i++) {
        expect(
          limiter.checkLimit(RateLimitOperation.sendMessage).allowed,
          true,
        );
      }

      // All should succeed - different operation limits
    });

    test('Burst protection - rapid comment posting', () {
      const operation = RateLimitOperation.postComment;

      // Post 30 comments rapidly (max tokens)
      for (int i = 0; i < 30; i++) {
        expect(limiter.checkLimit(operation).allowed, true);
      }

      // Next comment should be blocked
      expect(limiter.checkLimit(operation).allowed, false);

      // Verify violation tracking
      expect(limiter.getViolationCount(operation), 1);
    });
  });
}
