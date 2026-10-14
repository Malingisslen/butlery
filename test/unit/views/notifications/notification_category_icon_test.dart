// Megagenomgång B (09): the icon was keyed on 'recipe' and 'menu', which the
// notification categories never store, so most rows got the bell.
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/views/notifications/notifications_view.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

void main() {
  test('every stored category except none gets its own icon, not the bell', () {
    for (final category in NotificationCategory.values) {
      expect(
        notificationCategoryIcon(category.name),
        isNot(ButleryIcons.bell),
        reason: category.name,
      );
    }
  });

  test('an unknown category falls back to the bell', () {
    expect(notificationCategoryIcon('okand'), ButleryIcons.bell);
  });
}
