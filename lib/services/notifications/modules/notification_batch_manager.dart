// lib/services/notifications/modules/notification_batch_manager.dart

import 'dart:async';
import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/repositories/interfaces/notification_batch_repository.dart';
import 'package:butlery/models/notification_batch.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

/// Notification batching and spam prevention with intelligent grouping, rate limiting, and spam detection.
/// Follows SRP - handles only batching/spam (not FCM tokens, content, preferences, or analytics).
/// ```dart
/// await manager.addToBatch(targetUserIds: [id], strategy: strategy, variables: vars);
/// await manager.processAllPendingBatches();
/// ```
class NotificationBatchManager {
  final String _userId;
  final NotificationBatchRepository _repository;
  final Clock _clock;

  // Batch timers for different notification types
  final Map<String, Timer> _batchTimers = {};

  // Rate limiting tracking
  final Map<String, List<DateTime>> _rateLimitingTracker = {};

  // Batch processing state
  bool _isBatchProcessing = false;

  // Optional callback for when batches are ready to send
  Future<void> Function(NotificationBatch)? _sendBatchCallback;

  NotificationBatchManager({
    required String userId,
    required NotificationBatchRepository repository,
    Future<void> Function(NotificationBatch)? sendBatchCallback,
    Clock? clock,
  }) : _userId = userId,
       _repository = repository,
       _sendBatchCallback = sendBatchCallback,
       _clock = clock ?? const Clock();

  /// Add notification to appropriate batch queue
  /// This is the main entry point for batchable notifications
  Future<bool> addToBatch({
    required List<String> targetUserIds,
    required NotificationStrategy strategy,
    required Map<String, String> variables,
    Map<String, dynamic>? additionalData,
    String? imageUrl,
    List<NotificationAction>? actions,
  }) async {
    try {
      AppLogger.debug(
        '🔔 Adding notification to batch for ${targetUserIds.length} users',
      );

      // Check if notification should be batched at all
      if (strategy.type != NotificationType.batchable) {
        AppLogger.debug(
          '📋 Strategy is not batchable, skipping batch processing',
        );
        return false;
      }

      bool anyBatched = false;

      for (final targetUserId in targetUserIds) {
        // Check rate limiting first
        if (_isRateLimited(targetUserId, strategy.category)) {
          AppLogger.warning(
            '⚠️ Rate limit exceeded for user $targetUserId in ${strategy.category.name}',
          );
          continue;
        }

        // Generate batch key for this user/category/time window
        final batchKey = _generateBatchKey(targetUserId, strategy);

        // Create notification template
        final template = NotificationTemplate.fromStrategy(
          strategy,
          variables,
          additionalData: additionalData,
          imageUrl: imageUrl,
          actions: actions,
        );

        // Add to batch in repository
        await _repository.addToBatch(
          batchKey: batchKey,
          notification: template,
          batchWindow: strategy.batchWindow ?? const Duration(minutes: 5),
        );

        // Set up batch timer if not already running
        _scheduleBatchProcessing(batchKey, strategy);

        // Track for rate limiting
        _trackNotificationForRateLimit(targetUserId, strategy.category);

        anyBatched = true;
        AppLogger.debug('✅ Added notification to batch: $batchKey');
      }

      if (anyBatched) {
        AppLogger.success(
          '✅ Successfully batched notification for ${targetUserIds.length} users',
        );
      }

      return anyBatched;
    } catch (e) {
      AppLogger.error('❌ Failed to add notification to batch', e);
      return false;
    }
  }

  /// Force process a specific batch (for testing or manual trigger)
  Future<void> forceBatchProcessing(String batchKey) async {
    AppLogger.info('🔄 Manually forcing batch processing for: $batchKey');
    await _processBatch(batchKey);
  }

  /// Get current batch statistics
  Map<String, dynamic> getBatchStatistics() {
    return {
      'active_batch_timers': _batchTimers.length,
      'batch_keys': _batchTimers.keys.toList(),
      'is_processing': _isBatchProcessing,
      'rate_limit_tracking': _rateLimitingTracker.map(
        (key, value) => MapEntry(key, value.length),
      ),
    };
  }

  /// Check if user has exceeded rate limit for category
  bool _isRateLimited(String userId, NotificationCategory category) {
    final key = '${userId}_${category.name}';
    final now = _clock.now();
    const window = Duration(minutes: 15); // 15-minute window

    // Get recent notifications for this user/category
    final recentNotifications = _rateLimitingTracker[key] ?? [];

    // Remove old entries outside the window
    recentNotifications.removeWhere(
      (timestamp) => now.difference(timestamp) > window,
    );

    // Check limits based on category
    int maxNotifications;
    switch (category) {
      case NotificationCategory.friends:
        maxNotifications = 10; // Friend activities can be frequent
        break;
      case NotificationCategory.recipes:
        maxNotifications = 8; // Recipe comments/likes
        break;
      case NotificationCategory.collaboration:
        maxNotifications = 15; // Real-time collaboration
        break;
      case NotificationCategory.shopping:
        maxNotifications = 5; // Shopping updates
        break;
      case NotificationCategory.messaging:
        maxNotifications = 20; // Messages should have higher limit
        break;
      case NotificationCategory.social:
        maxNotifications = 6; // General social activity
        break;
      case NotificationCategory.system:
        maxNotifications = 3; // System notifications are rare
        break;
    }

    final isLimited = recentNotifications.length >= maxNotifications;

    if (isLimited) {
      AppLogger.warning(
        '⚠️ Rate limit exceeded: ${recentNotifications.length}/$maxNotifications for $key',
      );
    }

    return isLimited;
  }

  /// Track notification for rate limiting
  void _trackNotificationForRateLimit(
    String userId,
    NotificationCategory category,
  ) {
    final key = '${userId}_${category.name}';
    final now = _clock.now();

    _rateLimitingTracker.putIfAbsent(key, () => []).add(now);

    // Keep only recent entries to prevent memory bloat
    const window = Duration(minutes: 15);
    _rateLimitingTracker[key]!.removeWhere(
      (timestamp) => now.difference(timestamp) > window,
    );
  }

  /// Detect potential spam patterns
  bool _isSpamPattern(List<NotificationTemplate> notifications) {
    if (notifications.length < 3) return false;

    // Check for identical content (potential spam)
    final uniqueTitles = notifications.map((n) => n.title).toSet();
    if (uniqueTitles.length == 1 && notifications.length > 5) {
      AppLogger.warning('⚠️ Detected potential spam pattern: identical titles');
      return true;
    }

    // Check for rapid succession (all within 1 minute)
    final timestamps =
        notifications
            .map(
              (n) =>
                  DateTime.tryParse((n.data['timestamp'] as String?).orEmpty()),
            )
            .whereType<DateTime>()
            .toList()
          ..sort();

    if (timestamps.isNotEmpty) {
      final timeSpan = timestamps.last.difference(timestamps.first);
      if (timeSpan.inMinutes < 1 && notifications.length > 8) {
        AppLogger.warning(
          '⚠️ Detected potential spam pattern: rapid succession',
        );
        return true;
      }
    }

    return false;
  }

  /// Process all pending batches that are ready
  Future<void> processAllPendingBatches() async {
    if (_isBatchProcessing) {
      AppLogger.debug('📋 Batch processing already in progress');
      return;
    }

    _isBatchProcessing = true;

    try {
      AppLogger.info('🔔 Processing all pending notification batches');

      final batches = await _repository.getPendingBatches();
      int processedCount = 0;
      int errorCount = 0;

      for (final batch in batches) {
        try {
          await _processBatch(batch.batchKey);
          processedCount++;
        } catch (e) {
          AppLogger.error('❌ Failed to process batch ${batch.batchKey}', e);
          errorCount++;
        }
      }

      AppLogger.success(
        '✅ Processed $processedCount batches, $errorCount errors',
      );
    } catch (e) {
      AppLogger.error('❌ Failed to process pending batches', e);
    } finally {
      _isBatchProcessing = false;
    }
  }

  /// Schedule batch processing with timer
  void _scheduleBatchProcessing(
    String batchKey,
    NotificationStrategy strategy,
  ) {
    // Don't create duplicate timers
    if (_batchTimers.containsKey(batchKey)) {
      AppLogger.debug('📋 Batch timer already exists for: $batchKey');
      return;
    }

    final batchWindow = strategy.batchWindow ?? const Duration(minutes: 5);

    _batchTimers[batchKey] = Timer(batchWindow, () {
      AppLogger.info('⏰ Batch timer expired, processing: $batchKey');
      _processBatch(batchKey);
    });

    AppLogger.debug(
      '⏰ Scheduled batch processing for $batchKey in ${batchWindow.inMinutes} minutes',
    );
  }

  /// Process a specific batch of notifications
  Future<void> _processBatch(String batchKey) async {
    try {
      AppLogger.info('🔔 Processing notification batch: $batchKey');

      // Get the specific batch directly (avoids fetching all batches)
      final batch = await _repository.getBatchByKey(batchKey);

      if (batch == null) {
        AppLogger.warning('⚠️ Batch not found: $batchKey');
        _cleanupBatchTimer(batchKey);
        return;
      }

      // Check for spam patterns
      if (_isSpamPattern(batch.notifications)) {
        AppLogger.warning('⚠️ Discarding batch due to spam pattern: $batchKey');
        await _repository.removeBatch(batchKey);
        _cleanupBatchTimer(batchKey);
        return;
      }

      // Build combined notification from batch
      final combinedNotification = _buildBatchedNotification(
        batch.notifications,
      );

      // Create updated batch with combined notification
      final processedBatch = NotificationBatch(
        batchKey: batch.batchKey,
        userId: batch.userId,
        notifications: [combinedNotification],
        createdAt: batch.createdAt,
        scheduledFor: batch.scheduledFor,
      );

      // Use callback if provided
      if (_sendBatchCallback != null) {
        await _sendBatchCallback!(processedBatch);
      } else {
        AppLogger.info(
          '📋 [DEV] Would send batched notification to ${batch.userId}: ${combinedNotification.title}',
        );
      }

      // Remove the processed batch
      await _repository.removeBatch(batchKey);
      _cleanupBatchTimer(batchKey);

      AppLogger.success(
        '✅ Processed batch with ${batch.notifications.length} notifications',
      );
    } catch (e) {
      AppLogger.error('❌ Failed to process batch: $batchKey', e);
      _cleanupBatchTimer(batchKey);
      rethrow;
    }
  }

  /// Build combined notification from multiple templates
  NotificationTemplate _buildBatchedNotification(
    List<NotificationTemplate> notifications,
  ) {
    if (notifications.isEmpty) {
      throw ArgumentError('Cannot batch empty notification list');
    }

    if (notifications.length == 1) {
      return notifications.first;
    }

    // Combine multiple notifications into a summary
    final firstNotification = notifications.first;
    final categoryString = firstNotification.data['category'] as String;
    // Extract enum name from either 'recipes' or legacy 'NotificationCategory.recipes' format
    final categoryName = categoryString.contains('.')
        ? categoryString.split('.').last
        : categoryString;
    final category = NotificationCategory.values.firstWhereOrNull(
      (c) => c.name == categoryName,
    );

    String title;
    String body;

    // Build localized batched content based on category
    switch (category) {
      case NotificationCategory.recipes:
        title = 'Ny receptaktivitet';
        body = '${notifications.length} nya händelser på dina recept';
      case NotificationCategory.friends:
        title = 'Vänaktivitet';
        body = '${notifications.length} nya aktiviteter från dina vänner';
      case NotificationCategory.collaboration:
        title = 'Samarbetsaktivitet';
        body = '${notifications.length} nya samarbetshändelser';
      case NotificationCategory.shopping:
        title = 'Inköpslistor';
        body = '${notifications.length} uppdateringar av inköpslistor';
      case NotificationCategory.messaging:
        title = 'Meddelanden';
        body = '${notifications.length} nya meddelanden';
      case NotificationCategory.social:
        title = 'Social aktivitet';
        body = '${notifications.length} nya sociala händelser';
      case NotificationCategory.system:
        title = 'Systemmeddelanden';
        body = '${notifications.length} nya systemhändelser';
      case null:
        title = 'Ny aktivitet';
        body = '${notifications.length} nya händelser i Butlery';
    }

    // Extract unique data from all notifications
    final combinedData = <String, dynamic>{
      ...firstNotification.data,
      'batched': true,
      'count': notifications.length,
      'batch_categories': notifications
          .map((n) => n.data['category'])
          .toSet()
          .toList(),
      'batch_types': notifications.map((n) => n.data['type']).toSet().toList(),
    };

    return NotificationTemplate(
      title: title,
      body: body,
      data: combinedData,
      imageUrl: firstNotification.imageUrl, // Use first image if any
      actions: firstNotification.actions, // Use first actions if any
    );
  }

  /// Generate batch key for grouping notifications
  String _generateBatchKey(String targetUserId, NotificationStrategy strategy) {
    final now = _clock.now();
    final batchWindow = strategy.batchWindow ?? const Duration(minutes: 5);

    // Create time-based grouping (e.g., 5-minute windows)
    final windowStart = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      (now.minute ~/ batchWindow.inMinutes) * batchWindow.inMinutes,
    );

    final windowKey = '${windowStart.millisecondsSinceEpoch ~/ 1000}';
    return '${strategy.category.name}_${strategy.type.name}_${targetUserId}_$windowKey';
  }

  /// Clean up batch timer
  void _cleanupBatchTimer(String batchKey) {
    final timer = _batchTimers.remove(batchKey);
    timer?.cancel();
    AppLogger.debug('🧹 Cleaned up batch timer: $batchKey');
  }

  /// Set callback for when batches are ready to send
  void setSendBatchCallback(Future<void> Function(NotificationBatch) callback) {
    _sendBatchCallback = callback;
  }

  /// Clean up old rate limiting data
  void cleanupRateLimitData([Duration? cleanupWindow]) {
    try {
      final now = _clock.now();
      final window = cleanupWindow ?? const Duration(minutes: 15);
      int removedEntries = 0;

      _rateLimitingTracker.forEach((key, timestamps) {
        final initialSize = timestamps.length;
        timestamps.removeWhere(
          (timestamp) => now.difference(timestamp) > window,
        );
        removedEntries += initialSize - timestamps.length;
      });

      // Remove empty entries
      _rateLimitingTracker.removeWhere((key, timestamps) => timestamps.isEmpty);

      if (removedEntries > 0) {
        AppLogger.debug('🧹 Cleaned up $removedEntries old rate limit entries');
      }
    } catch (e) {
      AppLogger.error('❌ Failed to cleanup rate limit data', e);
    }
  }

  /// Dispose resources and cleanup
  void dispose() {
    AppLogger.info(
      '🔔 Disposing NotificationBatchManager for user ${_userId.maskedUserId}',
    );

    // Cancel all batch timers
    for (final timer in _batchTimers.values) {
      timer.cancel();
    }
    _batchTimers.clear();

    // Clear rate limiting data
    _rateLimitingTracker.clear();

    // Clear callback
    _sendBatchCallback = null;

    AppLogger.debug('✅ NotificationBatchManager disposed');
  }
}
