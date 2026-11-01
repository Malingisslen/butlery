import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/repositories/interfaces/notification_analytics_repository.dart';
import 'package:butlery/services/notifications/modules/notification_analytics_manager.dart';

class _MockAnalyticsRepo extends Mock
    implements NotificationAnalyticsRepository {}

void main() {
  test(
    'delivery updates go to the repository passed to the constructor',
    () async {
      final repo = _MockAnalyticsRepo();
      when(() => repo.updateDelivery(any(), any())).thenAnswer((_) async {});
      final manager = NotificationAnalyticsManager(
        userId: 'u1',
        repository: repo,
      );

      await manager.recordNotificationFailed(
        notificationId: 'n1',
        errorCode: 'unregistered',
      );

      final written =
          verify(() => repo.updateDelivery('n1', captureAny())).captured.single
              as Map<String, dynamic>;
      expect(written['status'], 'failed');
      expect(written['errorCode'], 'unregistered');
    },
  );
}
