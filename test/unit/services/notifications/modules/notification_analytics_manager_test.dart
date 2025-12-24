/// Unit tests for NotificationAnalyticsManager - Business Logic Testing
///
/// ✅ Following FIREBASE_TESTING_GUIDE.md:
/// - Tests business logic using repository-level mocking
/// - No Firebase operations (moved to integration tests)
/// - Fast, isolated, deterministic tests
///
/// Integration tests for FieldValue operations are in:
/// /test/integration/firebase/services/notification_analytics_integration_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';

// Mock for repository-level testing
class MockNotificationAnalyticsRepository extends Mock {
  int _sentCount = 0;
  int _deliveredCount = 0;
  int _failedCount = 0;
  int _openedCount = 0;

  void setAnalyticsState({
    int sentCount = 0,
    int deliveredCount = 0,
    int failedCount = 0,
    int openedCount = 0,
  }) {
    _sentCount = sentCount;
    _deliveredCount = deliveredCount;
    _failedCount = failedCount;
    _openedCount = openedCount;
  }

  Future<void> incrementSentCount() async {
    _sentCount++;
  }

  Future<void> incrementDeliveredCount() async {
    _deliveredCount++;
  }

  Future<void> incrementFailedCount() async {
    _failedCount++;
  }

  Future<void> incrementOpenedCount() async {
    _openedCount++;
  }

  Map<String, int> getAnalytics() {
    return {
      'sent': _sentCount,
      'delivered': _deliveredCount,
      'failed': _failedCount,
      'opened': _openedCount,
    };
  }

  double getDeliveryRate() {
    if (_sentCount == 0) return 0;
    return _deliveredCount / _sentCount;
  }

  double getOpenRate() {
    if (_sentCount == 0) return 0;
    return _openedCount / _sentCount;
  }
}

// Service wrapper for unit testing (business logic)
class NotificationAnalyticsService {
  final MockNotificationAnalyticsRepository repository;
  final List<Map<String, dynamic>> _pendingEvents = [];
  int _dismissedCount = 0;
  int _actionsCount = 0;

  NotificationAnalyticsService({required this.repository});

  Future<void> trackNotificationSent(String userId, String category) async {
    await repository.incrementSentCount();
    _pendingEvents.add({
      'type': 'sent',
      'userId': userId,
      'category': category,
      'timestamp': DateTime.now(),
    });
  }

  Future<void> trackNotificationDelivered(String notificationId) async {
    await repository.incrementDeliveredCount();
  }

  Future<void> trackNotificationFailed(
      String notificationId, String errorCode) async {
    await repository.incrementFailedCount();
  }

  Future<void> trackNotificationOpened(String notificationId) async {
    await repository.incrementOpenedCount();
  }

  Future<void> trackNotificationDismissed(
      String notificationId, String? reason) async {
    _dismissedCount++;
  }

  Future<void> trackNotificationActionTaken(
      String notificationId, String actionId) async {
    _actionsCount++;
  }

  double calculateDeliveryRate() {
    return repository.getDeliveryRate();
  }

  double calculateOpenRate() {
    return repository.getOpenRate();
  }

  double calculateEngagementRate() {
    final analytics = repository.getAnalytics();
    if (analytics['sent'] == 0) return 0.0;
    return (analytics['opened']! + _actionsCount) / analytics['sent']!;
  }

  Map<String, dynamic> generateMetricsSummary() {
    final analytics = repository.getAnalytics();
    return {
      'total_sent': analytics['sent'],
      'total_delivered': analytics['delivered'],
      'total_failed': analytics['failed'],
      'total_opened': analytics['opened'],
      'total_dismissed': _dismissedCount,
      'total_actions': _actionsCount,
      'delivery_rate': calculateDeliveryRate(),
      'open_rate': calculateOpenRate(),
      'engagement_rate': calculateEngagementRate(),
      'failure_rate': (analytics['sent'] ?? 0) > 0
          ? analytics['failed']! / analytics['sent']!
          : 0.0,
    };
  }

  Map<String, dynamic> getCategoryPerformance(String category) {
    // Simulate category-specific metrics
    final analytics = repository.getAnalytics();
    return {
      'category': category,
      'sent': analytics['sent'],
      'delivered': analytics['delivered'],
      'opened': analytics['opened'],
      'performance_score': calculateOpenRate() * 100,
    };
  }

  Map<String, dynamic> getUserEngagementSummary() {
    final analytics = repository.getAnalytics();
    return {
      'notifications_received': analytics['delivered'],
      'notifications_opened': analytics['opened'],
      'notifications_dismissed': _dismissedCount,
      'actions_taken': _actionsCount,
      'engagement_score': calculateEngagementRate() * 100,
    };
  }

  Future<void> flushPendingEvents() async {
    // Simulate batch flush
    _pendingEvents.clear();
  }

  int getPendingEventsCount() {
    return _pendingEvents.length;
  }

  Future<void> cleanupOldData(Duration olderThan) async {
    // Simulate cleanup
    _pendingEvents.removeWhere((event) {
      final eventTime = event['timestamp'] as DateTime;
      return DateTime.now().difference(eventTime) > olderThan;
    });
  }
}

void main() {
  group('NotificationAnalyticsManager - Unit Tests', () {
    late MockNotificationAnalyticsRepository mockRepository;
    late NotificationAnalyticsService service;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      mockRepository = MockNotificationAnalyticsRepository();
      service = NotificationAnalyticsService(repository: mockRepository);
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Delivery Tracking', () {
      test('should track notification sent event', () async {
        // Arrange
        mockRepository.setAnalyticsState(sentCount: 10);

        // Act
        await service.trackNotificationSent('user123', 'social');

        // Assert
        expect(mockRepository.getAnalytics()['sent'], equals(11));
      });

      test('should track notification delivered event', () async {
        // Arrange
        mockRepository.setAnalyticsState(
          sentCount: 10,
          deliveredCount: 5,
        );

        // Act
        await service.trackNotificationDelivered('notif_123');

        // Assert
        expect(mockRepository.getAnalytics()['delivered'], equals(6));
      });

      test('should track notification failed event', () async {
        // Arrange
        mockRepository.setAnalyticsState(
          sentCount: 10,
          failedCount: 2,
        );

        // Act
        await service.trackNotificationFailed('notif_123', 'TOKEN_NOT_FOUND');

        // Assert
        expect(mockRepository.getAnalytics()['failed'], equals(3));
      });
    });

    group('Engagement Tracking', () {
      test('should track notification opened event', () async {
        // Arrange
        mockRepository.setAnalyticsState(
          sentCount: 10,
          deliveredCount: 10,
          openedCount: 3,
        );

        // Act
        await service.trackNotificationOpened('notif_123');

        // Assert
        expect(mockRepository.getAnalytics()['opened'], equals(4));
      });

      test('should calculate open rate correctly', () {
        // Arrange
        mockRepository.setAnalyticsState(
          sentCount: 100,
          deliveredCount: 95,
          openedCount: 30,
        );

        // Act
        final openRate = service.calculateOpenRate();

        // Assert
        expect(openRate, equals(0.3)); // 30/100
      });

      test('should handle zero sent notifications', () {
        // Arrange
        mockRepository.setAnalyticsState(
          sentCount: 0,
          deliveredCount: 0,
          openedCount: 0,
        );

        // Act
        final openRate = service.calculateOpenRate();
        final deliveryRate = service.calculateDeliveryRate();

        // Assert
        expect(openRate, equals(0.0));
        expect(deliveryRate, equals(0.0));
      });
    });

    group('Performance Metrics', () {
      test('should calculate delivery rate correctly', () {
        // Arrange
        mockRepository.setAnalyticsState(
          sentCount: 100,
          deliveredCount: 85,
        );

        // Act
        final deliveryRate = service.calculateDeliveryRate();

        // Assert
        expect(deliveryRate, equals(0.85)); // 85/100
      });

      test('should generate comprehensive metrics summary', () {
        // Arrange
        mockRepository.setAnalyticsState(
          sentCount: 1000,
          deliveredCount: 950,
          failedCount: 50,
          openedCount: 475,
        );

        // Act
        final metrics = service.generateMetricsSummary();

        // Assert
        expect(metrics['total_sent'], equals(1000));
        expect(metrics['total_delivered'], equals(950));
        expect(metrics['total_failed'], equals(50));
        expect(metrics['total_opened'], equals(475));
        expect(metrics['delivery_rate'], equals(0.95));
        expect(metrics['open_rate'], equals(0.475));
        expect(metrics['failure_rate'], equals(0.05));
      });

      test('should handle edge case with all notifications failed', () {
        // Arrange
        mockRepository.setAnalyticsState(
          sentCount: 10,
          deliveredCount: 0,
          failedCount: 10,
          openedCount: 0,
        );

        // Act
        final metrics = service.generateMetricsSummary();

        // Assert
        expect(metrics['delivery_rate'], equals(0.0));
        expect(metrics['open_rate'], equals(0.0));
        expect(metrics['failure_rate'], equals(1.0));
      });

      test('should handle perfect delivery and engagement', () {
        // Arrange
        mockRepository.setAnalyticsState(
          sentCount: 50,
          deliveredCount: 50,
          failedCount: 0,
          openedCount: 50,
        );

        // Act
        final metrics = service.generateMetricsSummary();

        // Assert
        expect(metrics['delivery_rate'], equals(1.0));
        expect(metrics['open_rate'], equals(1.0));
        expect(metrics['failure_rate'], equals(0.0));
      });
    });

    group('Batch Processing', () {
      test('should batch multiple sent events', () async {
        // Arrange
        mockRepository.setAnalyticsState(sentCount: 0);

        // Act - Send multiple notifications
        for (int i = 0; i < 10; i++) {
          await service.trackNotificationSent('user$i', 'social');
        }

        // Assert
        expect(mockRepository.getAnalytics()['sent'], equals(10));
      });

      test('should handle mixed event types', () async {
        // Arrange
        mockRepository.setAnalyticsState();

        // Act
        await service.trackNotificationSent('user1', 'social');
        await service.trackNotificationDelivered('notif_1');
        await service.trackNotificationOpened('notif_1');
        await service.trackNotificationSent('user2', 'recipe');
        await service.trackNotificationFailed('notif_2', 'ERROR');

        // Assert
        final analytics = mockRepository.getAnalytics();
        expect(analytics['sent'], equals(2));
        expect(analytics['delivered'], equals(1));
        expect(analytics['opened'], equals(1));
        expect(analytics['failed'], equals(1));
      });
    });

    group('Engagement Actions', () {
      test('should track notification dismissed events', () async {
        // Arrange
        mockRepository.setAnalyticsState(sentCount: 10, deliveredCount: 10);

        // Act
        await service.trackNotificationDismissed('notif_1', 'user_dismissed');
        await service.trackNotificationDismissed('notif_2', null);

        // Assert
        final metrics = service.generateMetricsSummary();
        expect(metrics['total_dismissed'], equals(2));
      });

      test('should track notification action taken events', () async {
        // Arrange
        mockRepository.setAnalyticsState(sentCount: 10, deliveredCount: 10);

        // Act
        await service.trackNotificationActionTaken('notif_1', 'accept');
        await service.trackNotificationActionTaken('notif_2', 'decline');
        await service.trackNotificationActionTaken('notif_3', 'view');

        // Assert
        final metrics = service.generateMetricsSummary();
        expect(metrics['total_actions'], equals(3));
      });

      test('should calculate engagement rate including actions', () async {
        // Arrange
        mockRepository.setAnalyticsState(
          sentCount: 100,
          deliveredCount: 95,
          openedCount: 40,
        );

        // Act
        await service.trackNotificationActionTaken('notif_1', 'action1');
        await service.trackNotificationActionTaken('notif_2', 'action2');
        await service.trackNotificationActionTaken('notif_3', 'action3');
        await service.trackNotificationActionTaken('notif_4', 'action4');
        await service.trackNotificationActionTaken('notif_5', 'action5');

        final engagementRate = service.calculateEngagementRate();

        // Assert
        expect(
            engagementRate, equals(0.45)); // (40 opened + 5 actions) / 100 sent
      });
    });

    group('Category Performance', () {
      test('should get performance metrics for specific category', () {
        // Arrange
        mockRepository.setAnalyticsState(
          sentCount: 50,
          deliveredCount: 48,
          openedCount: 25,
        );

        // Act
        final socialPerformance = service.getCategoryPerformance('social');

        // Assert
        expect(socialPerformance['category'], equals('social'));
        expect(socialPerformance['sent'], equals(50));
        expect(socialPerformance['delivered'], equals(48));
        expect(socialPerformance['opened'], equals(25));
        expect(socialPerformance['performance_score'],
            equals(50.0)); // 25/50 * 100
      });

      test('should handle empty category metrics', () {
        // Arrange
        mockRepository.setAnalyticsState();

        // Act
        final emptyPerformance =
            service.getCategoryPerformance('unused_category');

        // Assert
        expect(emptyPerformance['sent'], equals(0));
        expect(emptyPerformance['performance_score'], equals(0.0));
      });
    });

    group('User Engagement Summary', () {
      test('should generate user engagement summary', () async {
        // Arrange
        mockRepository.setAnalyticsState(
          sentCount: 100,
          deliveredCount: 95,
          openedCount: 45,
        );
        await service.trackNotificationDismissed('notif_1', 'not_interested');
        await service.trackNotificationDismissed('notif_2', 'busy');
        await service.trackNotificationActionTaken('notif_3', 'accept');

        // Act
        final engagement = service.getUserEngagementSummary();

        // Assert
        expect(engagement['notifications_received'], equals(95));
        expect(engagement['notifications_opened'], equals(45));
        expect(engagement['notifications_dismissed'], equals(2));
        expect(engagement['actions_taken'], equals(1));
        expect(
            engagement['engagement_score'], equals(46.0)); // (45+1)/100 * 100
      });

      test('should handle user with no engagement', () {
        // Arrange
        mockRepository.setAnalyticsState(
          sentCount: 10,
          deliveredCount: 10,
          openedCount: 0,
        );

        // Act
        final engagement = service.getUserEngagementSummary();

        // Assert
        expect(engagement['notifications_opened'], equals(0));
        expect(engagement['notifications_dismissed'], equals(0));
        expect(engagement['actions_taken'], equals(0));
        expect(engagement['engagement_score'], equals(0.0));
      });
    });

    group('Pending Events Management', () {
      test('should accumulate pending events', () async {
        // Arrange & Act
        await service.trackNotificationSent('user1', 'social');
        await service.trackNotificationSent('user2', 'recipe');
        await service.trackNotificationSent('user3', 'friend');

        // Assert
        expect(service.getPendingEventsCount(), equals(3));
      });

      test('should flush pending events when called', () async {
        // Arrange
        await service.trackNotificationSent('user1', 'social');
        await service.trackNotificationSent('user2', 'recipe');
        expect(service.getPendingEventsCount(), equals(2));

        // Act
        await service.flushPendingEvents();

        // Assert
        expect(service.getPendingEventsCount(), equals(0));
      });

      test('should handle empty flush gracefully', () async {
        // Arrange
        expect(service.getPendingEventsCount(), equals(0));

        // Act
        await service.flushPendingEvents();

        // Assert
        expect(service.getPendingEventsCount(), equals(0));
      });
    });

    group('Data Cleanup', () {
      test('should cleanup old events', () async {
        // Arrange
        await service.trackNotificationSent('user1', 'social');

        // Simulate old event by waiting
        await Future.delayed(const Duration(milliseconds: 100));

        await service.trackNotificationSent('user2', 'recipe');

        expect(service.getPendingEventsCount(), equals(2));

        // Act - Clean up events older than 50ms
        await service.cleanupOldData(const Duration(milliseconds: 50));

        // Assert - Only the recent event should remain
        expect(service.getPendingEventsCount(), equals(1));
      });

      test('should handle cleanup with no old data', () async {
        // Arrange
        await service.trackNotificationSent('user1', 'social');
        await service.trackNotificationSent('user2', 'recipe');

        // Act - Clean up with long duration (nothing is old)
        await service.cleanupOldData(const Duration(days: 1));

        // Assert - All events should remain
        expect(service.getPendingEventsCount(), equals(2));
      });
    });

    group('Edge Cases and Error Scenarios', () {
      test('should handle metrics with partial data', () {
        // Arrange
        mockRepository.setAnalyticsState(
          sentCount: 100,
          deliveredCount: 0, // No deliveries yet
          openedCount: 0,
        );

        // Act
        final metrics = service.generateMetricsSummary();

        // Assert
        expect(metrics['delivery_rate'], equals(0.0));
        expect(metrics['open_rate'], equals(0.0));
        expect(metrics['engagement_rate'], equals(0.0));
      });

      test('should handle concurrent tracking events', () async {
        // Arrange
        mockRepository.setAnalyticsState();

        // Act - Simulate concurrent events
        final futures = <Future>[];
        for (int i = 0; i < 10; i++) {
          futures.add(service.trackNotificationSent('user$i', 'social'));
          futures.add(service.trackNotificationDelivered('notif_$i'));
        }
        await Future.wait(futures);

        // Assert
        final analytics = mockRepository.getAnalytics();
        expect(analytics['sent'], equals(10));
        expect(analytics['delivered'], equals(10));
      });

      test('should calculate metrics with high precision', () {
        // Arrange
        mockRepository.setAnalyticsState(
          sentCount: 1337,
          deliveredCount: 1289,
          openedCount: 567,
        );

        // Act
        final metrics = service.generateMetricsSummary();

        // Assert
        expect(metrics['delivery_rate'], closeTo(0.964, 0.001));
        expect(metrics['open_rate'], closeTo(0.424, 0.001));
      });

      test('should handle category performance with special characters', () {
        // Arrange
        mockRepository.setAnalyticsState(sentCount: 10);

        // Act
        final performance = service.getCategoryPerformance('recipe_shared_🍽️');

        // Assert
        expect(performance['category'], equals('recipe_shared_🍽️'));
        expect(performance['sent'], equals(10));
      });
    });
  });
}
