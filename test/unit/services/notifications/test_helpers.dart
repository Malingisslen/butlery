/// Test helpers for notification module testing
///
/// Provides common test utilities, factories, and mock data
/// for notification module tests to ensure consistency and reduce duplication.
library;

import 'package:butlery/services/notifications/notification_types.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mocktail/mocktail.dart';

/// Helper class providing common test utilities for notification modules
class NotificationTestHelpers {
  /// Create a test notification with default values
  static PendingNotification createTestNotification({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    NotificationPriority? priority,
    NotificationCategory? category,
    Map<String, dynamic>? data,
    DateTime? scheduledAt,
    int? retryCount,
  }) {
    return PendingNotification(
      id: id ?? 'test-notification-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId ?? 'test-user-123',
      title: title ?? 'Test Notification',
      body: body ?? 'This is a test notification',
      type: type ?? NotificationType.immediate,
      priority: priority ?? NotificationPriority.medium,
      category: category ?? NotificationCategory.system,
      data: data ?? {},
      scheduledAt: scheduledAt,
      retryCount: retryCount ?? 0,
    );
  }

  /// Create default notification preferences for testing
  static NotificationPreferences createDefaultPreferences({
    String? userId,
    bool? enableAll,
    bool? enableFriends,
    bool? enableRecipes,
    bool? enableShopping,
    bool? enableCollaboration,
    bool? enableMessaging,
    bool? enableDigest,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    String? digestFrequency,
    Map<String, bool>? categorySettings,
  }) {
    return NotificationPreferences(
      userId: userId ?? 'test-user-123',
      enableAll: enableAll ?? true,
      enableFriends: enableFriends ?? true,
      enableRecipes: enableRecipes ?? true,
      enableShopping: enableShopping ?? true,
      enableCollaboration: enableCollaboration ?? true,
      enableMessaging: enableMessaging ?? true,
      enableDigest: enableDigest ?? false,
      quietHoursEnabled: quietHoursEnabled ?? false,
      quietHoursStart: quietHoursStart ?? '22:00',
      quietHoursEnd: quietHoursEnd ?? '08:00',
      digestFrequency: digestFrequency ?? 'daily',
      categorySettings: categorySettings ?? {},
      updatedAt: DateTime.now(),
    );
  }

  /// Create a test FCM token
  static FCMToken createTestToken({
    String? token,
    String? userId,
    String? deviceId,
    String? platform,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return FCMToken(
      token: token ?? 'test-fcm-token-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId ?? 'test-user-123',
      deviceId: deviceId ?? 'test-device-001',
      platform: platform ?? 'android',
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      isActive: isActive ?? true,
    );
  }

  /// Create a batch of test notifications
  static List<PendingNotification> createNotificationBatch({
    int count = 5,
    String? userId,
    NotificationType? type,
    NotificationCategory? category,
  }) {
    return List.generate(
      count,
      (index) => createTestNotification(
        id: 'batch-notification-$index',
        userId: userId,
        title: 'Batch Notification $index',
        body: 'Batch notification body $index',
        type: type ?? NotificationType.batchable,
        category: category ?? NotificationCategory.social,
      ),
    );
  }

  /// Create notification history entry
  static NotificationHistoryEntry createHistoryEntry({
    String? notificationId,
    String? userId,
    String? title,
    DateTime? sentAt,
    bool? wasDelivered,
    bool? wasOpened,
    String? errorMessage,
  }) {
    return NotificationHistoryEntry(
      notificationId:
          notificationId ??
          'history-notification-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId ?? 'test-user-123',
      title: title ?? 'Historical Notification',
      sentAt: sentAt ?? DateTime.now(),
      wasDelivered: wasDelivered ?? true,
      wasOpened: wasOpened ?? false,
      errorMessage: errorMessage,
    );
  }

  /// Create analytics event
  static NotificationAnalyticsEvent createAnalyticsEvent({
    String? eventType,
    String? notificationId,
    String? userId,
    DateTime? timestamp,
    Map<String, dynamic>? properties,
  }) {
    return NotificationAnalyticsEvent(
      eventType: eventType ?? 'notification_sent',
      notificationId: notificationId ?? 'analytics-notification-001',
      userId: userId ?? 'test-user-123',
      timestamp: timestamp ?? DateTime.now(),
      properties: properties ?? {},
    );
  }

  /// Create test RemoteMessage for FCM testing
  static RemoteMessage createTestRemoteMessage({
    String? messageId,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    String? from,
    String? collapseKey,
    DateTime? sentTime,
  }) {
    return RemoteMessage(
      messageId:
          messageId ?? 'test-message-${DateTime.now().millisecondsSinceEpoch}',
      data: data ?? {'type': 'test', 'action': 'none'},
      from: from ?? 'test-sender',
      collapseKey: collapseKey,
      sentTime: sentTime ?? DateTime.now(),
      notification: RemoteNotification(
        title: title ?? 'Test FCM Notification',
        body: body ?? 'Test FCM notification body',
      ),
    );
  }

  /// Check if current time is within quiet hours
  static bool isWithinQuietHours(
    DateTime time,
    String quietHoursStart,
    String quietHoursEnd,
  ) {
    final startParts = quietHoursStart.split(':');
    final endParts = quietHoursEnd.split(':');

    final startHour = int.parse(startParts[0]);
    final startMinute = int.parse(startParts[1]);
    final endHour = int.parse(endParts[0]);
    final endMinute = int.parse(endParts[1]);

    final currentMinutes = time.hour * 60 + time.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    // Handle overnight quiet hours (e.g., 22:00 to 08:00)
    if (startMinutes > endMinutes) {
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    } else {
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    }
  }

  /// Generate Swedish test content
  static Map<String, String> getSwedishTestContent() {
    return {
      'title': 'Ny receptdelning',
      'body': 'Anna har delat sitt recept för Köttbullar med dig',
      'action': 'Visa recept',
      'decline': 'Avböj',
    };
  }

  /// Generate test topics for FCM subscriptions
  static List<String> getTestTopics({
    String? userId,
    bool includeCategories = true,
    bool includeDigest = false,
  }) {
    final topics = <String>[];

    // User-specific topic
    if (userId != null) {
      topics.add('user_$userId');
    }

    // Category topics
    if (includeCategories) {
      topics.addAll([
        'recipes_new',
        'friends_updates',
        'shopping_shared',
        'collaboration_invites',
      ]);
    }

    // Digest topic
    if (includeDigest) {
      topics.add('digest_daily');
    }

    // Global topics
    topics.add('app_updates');

    return topics;
  }

  /// Create a test batch queue
  static NotificationBatchQueue createTestBatchQueue({
    String? queueId,
    List<PendingNotification>? notifications,
    DateTime? windowStart,
    Duration? batchWindow,
    int? maxSize,
  }) {
    return NotificationBatchQueue(
      queueId: queueId ?? 'test-queue-001',
      notifications: notifications ?? [],
      windowStart: windowStart ?? DateTime.now(),
      batchWindow: batchWindow ?? const Duration(minutes: 5),
      maxSize: maxSize ?? 10,
    );
  }
}

// ============= DATA MODELS =============
// These are simplified test models that match the expected structure

/// Pending notification model for testing
class PendingNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final NotificationPriority priority;
  final NotificationCategory category;
  final Map<String, dynamic> data;
  final DateTime? scheduledAt;
  final int retryCount;

  PendingNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.priority,
    required this.category,
    required this.data,
    this.scheduledAt,
    required this.retryCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.toString(),
      'priority': priority.toString(),
      'category': category.toString(),
      'data': data,
      'scheduledAt': scheduledAt?.toIso8601String(),
      'retryCount': retryCount,
    };
  }
}

/// Notification preferences model for testing
class NotificationPreferences {
  final String userId;
  final bool enableAll;
  final bool enableFriends;
  final bool enableRecipes;
  final bool enableShopping;
  final bool enableCollaboration;
  final bool enableMessaging;
  final bool enableDigest;
  final bool quietHoursEnabled;
  final String quietHoursStart;
  final String quietHoursEnd;
  final String digestFrequency;
  final Map<String, bool> categorySettings;
  final DateTime updatedAt;

  NotificationPreferences({
    required this.userId,
    required this.enableAll,
    required this.enableFriends,
    required this.enableRecipes,
    required this.enableShopping,
    required this.enableCollaboration,
    required this.enableMessaging,
    required this.enableDigest,
    required this.quietHoursEnabled,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    required this.digestFrequency,
    required this.categorySettings,
    required this.updatedAt,
  });

  factory NotificationPreferences.defaults() {
    return NotificationPreferences(
      userId: '',
      enableAll: true,
      enableFriends: true,
      enableRecipes: true,
      enableShopping: true,
      enableCollaboration: true,
      enableMessaging: true,
      enableDigest: false,
      quietHoursEnabled: false,
      quietHoursStart: '22:00',
      quietHoursEnd: '08:00',
      digestFrequency: 'daily',
      categorySettings: {},
      updatedAt: DateTime.now(),
    );
  }

  NotificationPreferences copyWith({
    bool? enableAll,
    bool? enableFriends,
    bool? enableRecipes,
    bool? enableShopping,
    bool? enableCollaboration,
    bool? enableMessaging,
    bool? enableDigest,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    String? digestFrequency,
    Map<String, bool>? categorySettings,
  }) {
    return NotificationPreferences(
      userId: userId,
      enableAll: enableAll ?? this.enableAll,
      enableFriends: enableFriends ?? this.enableFriends,
      enableRecipes: enableRecipes ?? this.enableRecipes,
      enableShopping: enableShopping ?? this.enableShopping,
      enableCollaboration: enableCollaboration ?? this.enableCollaboration,
      enableMessaging: enableMessaging ?? this.enableMessaging,
      enableDigest: enableDigest ?? this.enableDigest,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      digestFrequency: digestFrequency ?? this.digestFrequency,
      categorySettings: categorySettings ?? this.categorySettings,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'enableAll': enableAll,
      'enableFriends': enableFriends,
      'enableRecipes': enableRecipes,
      'enableShopping': enableShopping,
      'enableCollaboration': enableCollaboration,
      'enableMessaging': enableMessaging,
      'enableDigest': enableDigest,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'digestFrequency': digestFrequency,
      'categorySettings': categorySettings,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory NotificationPreferences.fromMap(
    String userId,
    Map<String, dynamic> map,
  ) {
    return NotificationPreferences(
      userId: userId,
      enableAll: map['enableAll'] ?? true,
      enableFriends: map['enableFriends'] ?? true,
      enableRecipes: map['enableRecipes'] ?? true,
      enableShopping: map['enableShopping'] ?? true,
      enableCollaboration: map['enableCollaboration'] ?? true,
      enableMessaging: map['enableMessaging'] ?? true,
      enableDigest: map['enableDigest'] ?? false,
      quietHoursEnabled: map['quietHoursEnabled'] ?? false,
      quietHoursStart: map['quietHoursStart'] ?? '22:00',
      quietHoursEnd: map['quietHoursEnd'] ?? '08:00',
      digestFrequency: map['digestFrequency'] ?? 'daily',
      categorySettings: Map<String, bool>.from(map['categorySettings'] ?? {}),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }
}

/// FCM token model for testing
class FCMToken {
  final String token;
  final String userId;
  final String deviceId;
  final String platform;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  FCMToken({
    required this.token,
    required this.userId,
    required this.deviceId,
    required this.platform,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'token': token,
      'userId': userId,
      'deviceId': deviceId,
      'platform': platform,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
    };
  }
}

/// Notification history entry for testing
class NotificationHistoryEntry {
  final String notificationId;
  final String userId;
  final String title;
  final DateTime sentAt;
  final bool wasDelivered;
  final bool wasOpened;
  final String? errorMessage;

  NotificationHistoryEntry({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.sentAt,
    required this.wasDelivered,
    required this.wasOpened,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'userId': userId,
      'title': title,
      'sentAt': sentAt.toIso8601String(),
      'wasDelivered': wasDelivered,
      'wasOpened': wasOpened,
      'errorMessage': errorMessage,
    };
  }
}

/// Analytics event for testing
class NotificationAnalyticsEvent {
  final String eventType;
  final String notificationId;
  final String userId;
  final DateTime timestamp;
  final Map<String, dynamic> properties;

  NotificationAnalyticsEvent({
    required this.eventType,
    required this.notificationId,
    required this.userId,
    required this.timestamp,
    required this.properties,
  });

  Map<String, dynamic> toMap() {
    return {
      'eventType': eventType,
      'notificationId': notificationId,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'properties': properties,
    };
  }
}

/// Notification batch queue for testing
class NotificationBatchQueue {
  final String queueId;
  final List<PendingNotification> notifications;
  final DateTime windowStart;
  final Duration batchWindow;
  final int maxSize;

  NotificationBatchQueue({
    required this.queueId,
    required this.notifications,
    required this.windowStart,
    required this.batchWindow,
    required this.maxSize,
  });

  bool get isFull => notifications.length >= maxSize;

  bool get isWindowExpired {
    final windowEnd = windowStart.add(batchWindow);
    return DateTime.now().isAfter(windowEnd);
  }

  void addNotification(PendingNotification notification) {
    if (!isFull) {
      notifications.add(notification);
    }
  }

  void clear() {
    notifications.clear();
  }
}

/// Fake RemoteNotification for testing
class FakeRemoteNotification extends Fake implements RemoteNotification {
  @override
  final String? title;
  @override
  final String? body;

  FakeRemoteNotification({this.title, this.body});
}

/// Mock NotificationRepository for testing modules
class MockNotificationRepository extends Mock {
  // Configuration state
  NotificationPreferences _preferences = NotificationPreferences.defaults();
  final List<NotificationHistoryEntry> _history = [];
  final List<PendingNotification> _queue = [];
  final Map<String, FCMToken> _tokens = {};

  void setNotificationState({
    NotificationPreferences? preferences,
    List<NotificationHistoryEntry>? history,
    List<PendingNotification>? queue,
    Map<String, FCMToken>? tokens,
  }) {
    if (preferences != null) _preferences = preferences;
    if (history != null) {
      _history.clear();
      _history.addAll(history);
    }
    if (queue != null) {
      _queue.clear();
      _queue.addAll(queue);
    }
    if (tokens != null) {
      _tokens.clear();
      _tokens.addAll(tokens);
    }
  }

  // Mock methods for testing
  Future<NotificationPreferences> getPreferences() async => _preferences;

  Future<void> updatePreferences(NotificationPreferences preferences) async {
    _preferences = preferences;
  }

  Future<void> addToHistory(NotificationHistoryEntry entry) async {
    _history.add(entry);
  }

  Future<List<NotificationHistoryEntry>> getHistory() async => _history;

  Future<void> queueNotification(PendingNotification notification) async {
    _queue.add(notification);
  }

  Future<List<PendingNotification>> getQueuedNotifications() async => _queue;

  Future<void> saveToken(FCMToken token) async {
    _tokens[token.token] = token;
  }

  Future<FCMToken?> getToken(String token) async => _tokens[token];
}
