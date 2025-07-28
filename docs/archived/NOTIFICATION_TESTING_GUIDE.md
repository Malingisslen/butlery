# Butlery Notification System - Testing Guide

## 🧪 Comprehensive Testing Strategy

This guide provides detailed instructions for testing the Butlery notification system during development and validating its readiness for production deployment.

## 📋 Test Categories Overview

| Category | Tests | Purpose | Priority |
|----------|-------|---------|----------|
| **Functional** | 1-10 | Core notification delivery logic | 🔴 Critical |
| **Edge Cases** | 11-16 | Error handling & boundary conditions | 🟡 High |
| **Performance** | 17-20 | Load testing & memory usage | 🟢 Medium |
| **User Experience** | 21-25 | A/B testing & feedback collection | 🔵 Low |

## 🔴 Critical Functional Tests

### Test 1: Friend Request Notification Flow
```dart
// Setup
final testUser = await createTestUser('anna_test');
final targetUser = await createTestUser('bob_test');

// Execute
await friendsOps.sendFriendRequest(targetUser.uid);

// Verify
expect(notificationLogs).to.contain([
  'FCM notification ready for: ${targetUser.uid}',
  'Title: Ny vänskapsförfrågan',
  'Body: Anna vill bli vän med dig'
]);

// Cleanup
await deleteTestUsers([testUser, targetUser]);
```

**Expected Result:**
```
🔔 [DEV] FCM notification ready for: bob_test_123
📋 [DEV] Title: Ny vänskapsförfrågan
📋 [DEV] Body: Anna vill bli vän med dig
📋 [DEV] Data keys: senderUserId, requestId, message
```

### Test 2: Recipe Sharing with Multiple Recipients
```dart
// Setup
final recipe = await createTestRecipe('Test Lasagna');
final recipients = await createTestUsers(['user1', 'user2', 'user3']);

// Execute
await recipeOps.shareRecipe(
  recipe.id,
  recipients.map((u) => u.uid).toList(),
  {'user1': 'User One', 'user2': 'User Two', 'user3': 'User Three'}
);

// Verify
expect(notificationLogs.length).to.equal(3);
for (final recipient in recipients) {
  expect(notificationLogs).to.contain('FCM notification ready for: ${recipient.uid}');
}
```

### Test 3: Comment Batching System
```dart
// Setup
final recipe = await createTestRecipe('Popular Recipe');
final commenter = await createTestUser('frequent_commenter');

// Execute - Send 5 comments rapidly
final comments = [];
for (int i = 0; i < 5; i++) {
  final comment = await recipeOps.addComment(recipe.id, 'Comment number $i');
  comments.add(comment);
}

// Verify - Should trigger batching
await Future.delayed(Duration(minutes: 6)); // Wait for batch window
expect(batchedNotifications).to.contain.key('recipeComment_${recipe.id}');
```

## 🟡 High Priority Edge Cases

### Test 11: Null Safety and Data Validation
```dart
// Test null sender name
await expectException(() async {
  await _sendFriendRequestNotification(
    FriendRequest(id: 'test', fromUserId: 'user1', toUserId: 'user2'),
    null, // null sender name
    'Valid Recipient'
  );
});

// Should gracefully handle with fallback
expect(notificationLogs).to.contain('senderName: Unknown User');
```

### Test 12: Network Disconnection Handling
```dart
// Simulate network failure
await NetworkSimulator.disconnectNetwork();

// Attempt to send notification
final result = await friendsOps.sendFriendRequest('user123');

// Verify offline queuing
expect(result).to.be.false;
expect(offlineNotificationQueue.length).to.equal(1);

// Restore network and verify retry
await NetworkSimulator.connectNetwork();
await processOfflineQueue();
expect(notificationLogs).to.contain('Queued notification processed');
```

### Test 13: Concurrent Notification Prevention
```dart
// Attempt to send duplicate notifications simultaneously
final futures = List.generate(5, (i) => 
  friendsOps.sendFriendRequest('same_user_123')
);

final results = await Future.wait(futures);

// Only first should succeed
expect(results.where((r) => r == true).length).to.equal(1);
expect(duplicatePreventionLogs.length).to.equal(4);
```

## 🟢 Performance Testing

### Test 17: High Volume Notification Processing
```dart
class NotificationLoadTest {
  static Future<LoadTestResult> runBulkNotificationTest({
    required int notificationCount,
    required Duration maxAllowedTime,
  }) async {
    final stopwatch = Stopwatch()..start();
    final users = await createTestUsers(notificationCount);
    
    // Generate notifications
    for (final user in users) {
      await recipeOps.shareRecipe('viral_recipe', [user.uid]);
    }
    
    stopwatch.stop();
    
    return LoadTestResult(
      totalNotifications: notificationCount,
      processingTime: stopwatch.elapsed,
      averageTimePerNotification: stopwatch.elapsed ~/ notificationCount,
      memoryUsage: await getCurrentMemoryUsage(),
      passedPerformanceTest: stopwatch.elapsed < maxAllowedTime,
    );
  }
}

// Run test
final result = await NotificationLoadTest.runBulkNotificationTest(
  notificationCount: 1000,
  maxAllowedTime: Duration(seconds: 30),
);

assert(result.passedPerformanceTest, 'Performance test failed: ${result.processingTime}');
```

### Test 18: Memory Leak Detection
```dart
class MemoryLeakTest {
  static Future<void> detectMemoryLeaks() async {
    final initialMemory = await getCurrentMemoryUsage();
    
    // Create and destroy notification services repeatedly
    for (int i = 0; i < 100; i++) {
      final service = NotificationService(
        firestore: FirebaseFirestore.instance,
        userId: 'test_user_$i',
      );
      
      await service.initialize();
      await service.sendImmediateNotification(/* ... */);
      await service.dispose();
    }
    
    // Force garbage collection
    await forceGarbageCollection();
    final finalMemory = await getCurrentMemoryUsage();
    
    final memoryIncrease = finalMemory - initialMemory;
    assert(memoryIncrease < 50 * 1024 * 1024, 'Memory leak detected: ${memoryIncrease}MB');
  }
}
```

## 🔵 User Experience Testing

### Test 21: A/B Testing Framework
```dart
class NotificationABTesting {
  static Future<void> runContentVariationTest() async {
    final testUsers = await createTestUsers(1000);
    final results = <String, ABTestMetrics>{};
    
    for (final user in testUsers) {
      // Randomly assign test variant
      final variant = _getRandomVariant(['formal', 'casual', 'emoji']);
      
      await sendNotificationWithVariant(
        userId: user.uid,
        variant: variant,
        notificationType: 'friend_request',
      );
      
      // Track user engagement
      final engagement = await trackUserEngagement(user.uid, Duration(hours: 24));
      results[variant] ??= ABTestMetrics();
      results[variant]!.addEngagement(engagement);
    }
    
    // Analyze results
    final winner = _determineWinningVariant(results);
    await _saveABTestResults('friend_request_content', winner, results);
  }
}
```

### Test 22: User Feedback Collection
```dart
class FeedbackCollectionTest {
  static Future<void> testFeedbackFlow() async {
    // Send notification
    await friendsOps.sendFriendRequest('feedback_tester');
    
    // Simulate user interaction
    await simulateNotificationOpen('notification_123');
    
    // Show feedback dialog after delay
    await Future.delayed(Duration(seconds: 30));
    await showNotificationFeedbackDialog();
    
    // Simulate user rating
    await submitFeedbackRating(4, 'Good timing but could be more personalized');
    
    // Verify feedback storage
    final feedback = await getFeedbackForNotification('notification_123');
    expect(feedback.rating).to.equal(4);
    expect(feedback.comment).to.contain('personalized');
  }
}
```

## 🔧 Test Environment Setup

### Development Test Configuration
```dart
// test/test_config.dart
class NotificationTestConfig {
  static const bool enableTestMode = true;
  static const bool captureNotificationLogs = true;
  static const bool simulateNetworkDelay = false;
  static const Duration mockFCMDelay = Duration(milliseconds: 100);
  
  static Future<void> setupTestEnvironment() async {
    // Initialize test Firebase instance
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: 'test-app-id',
        messagingSenderId: 'test-sender-id',
        projectId: 'butlery-test',
      ),
    );
    
    // Setup notification interceptor
    NotificationService.setTestMode(true);
    NotificationService.setLogInterceptor(_captureNotificationLog);
  }
}
```

### Mock Services for Testing
```dart
// test/mocks/mock_notification_service.dart
class MockNotificationService extends NotificationService {
  final List<NotificationLog> sentNotifications = [];
  
  @override
  Future<void> sendImmediateNotification({
    required List<String> targetUserIds,
    required NotificationStrategy strategy,
    required Map<String, String> variables,
  }) async {
    // Capture instead of sending
    sentNotifications.add(NotificationLog(
      targetUserIds: targetUserIds,
      strategy: strategy,
      variables: variables,
      timestamp: DateTime.now(),
    ));
    
    // Simulate processing delay
    await Future.delayed(Duration(milliseconds: 50));
  }
}
```

## 📊 Test Metrics and Reporting

### Automated Test Report Generation
```dart
class NotificationTestReporter {
  static Future<void> generateTestReport() async {
    final report = TestReport(
      testSuite: 'Notification System',
      executionTime: DateTime.now(),
      results: await _collectAllTestResults(),
    );
    
    // Generate detailed report
    final markdownReport = _generateMarkdownReport(report);
    await File('test_reports/notification_tests_${DateTime.now().toIso8601String()}.md')
        .writeAsString(markdownReport);
    
    // Generate metrics dashboard
    final metricsJson = _generateMetricsJson(report);
    await File('test_reports/metrics.json').writeAsString(metricsJson);
    
    // Send to analytics if configured
    if (TestConfig.enableAnalytics) {
      await _sendTestMetricsToAnalytics(report);
    }
  }
}
```

### Key Performance Indicators (KPIs)
```dart
class NotificationKPIs {
  // Performance KPIs
  static const Duration maxNotificationProcessingTime = Duration(seconds: 5);
  static const int maxMemoryUsageIncrease = 10; // MB
  static const double minSuccessRate = 0.99; // 99%
  
  // User Experience KPIs  
  static const double minUserSatisfactionRating = 4.0; // out of 5
  static const double maxOptOutRate = 0.05; // 5%
  static const Duration maxTimeToAction = Duration(minutes: 30);
  
  // System Health KPIs
  static const double maxErrorRate = 0.01; // 1%
  static const int maxQueueBacklog = 100;
  static const double minDeliveryRate = 0.95; // 95%
}
```

## 🚀 Continuous Integration Testing

### GitHub Actions Configuration
```yaml
# .github/workflows/notification_tests.yml
name: Notification System Tests

on: [push, pull_request]

jobs:
  notification-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Run notification unit tests
        run: flutter test test/notification_service_test.dart
        
      - name: Run notification integration tests
        run: flutter test integration_test/notification_flow_test.dart
        
      - name: Run performance tests
        run: flutter test test/notification_performance_test.dart
        
      - name: Generate test report
        run: dart run test/generate_test_report.dart
        
      - name: Upload test artifacts
        uses: actions/upload-artifact@v2
        with:
          name: test-reports
          path: test_reports/
```

## 📈 Production Readiness Checklist

### Pre-Production Validation
- [ ] All 20 core tests passing
- [ ] Performance tests meet KPI thresholds
- [ ] Memory leak tests show no leaks
- [ ] A/B testing framework validated
- [ ] User feedback collection working
- [ ] Error handling covers all edge cases
- [ ] Localization tested for Swedish/English
- [ ] Rate limiting prevents spam
- [ ] Offline queuing functional
- [ ] Analytics integration working

### Production Deployment Tests
- [ ] Cloud Functions deployed successfully
- [ ] End-to-end notification delivery working
- [ ] FCM token management operational
- [ ] User preferences respected
- [ ] Quiet hours functionality working
- [ ] Notification analytics collecting data
- [ ] Dashboard showing real-time metrics
- [ ] Error alerts configured
- [ ] Rollback procedure tested
- [ ] Load testing in production environment

## 🔍 Debugging and Troubleshooting

### Common Test Failures and Solutions

**Test Failure: "Notification not logged"**
```dart
// Problem: Notification service not initialized
// Solution: Ensure proper test setup
await NotificationTestConfig.setupTestEnvironment();
await notificationService.initialize();
```

**Test Failure: "Batch window not triggered"**
```dart
// Problem: Timer not advanced in test
// Solution: Use fake timers
fakeAsync((async) {
  await addComments(); 
  async.elapse(Duration(minutes: 6)); // Advance timer
  expect(batchTriggered).to.be.true;
});
```

**Test Failure: "Memory usage exceeded threshold"**
```dart
// Problem: Services not properly disposed
// Solution: Ensure cleanup in test tearDown
tearDown(() async {
  await notificationService.dispose();
  await clearTestData();
});
```

This comprehensive testing guide ensures the Butlery notification system is thoroughly validated before production deployment and provides ongoing quality assurance throughout its lifecycle.