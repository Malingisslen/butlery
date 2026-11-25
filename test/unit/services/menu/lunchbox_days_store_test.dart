// The weekdays a person wants lunchboxes on are kept per account on this
// device only.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/services/menu/lunchbox_days_store.dart';

void main() {
  const store = LunchboxDaysStore();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'what was written for an account reads back, whatever the order',
    () async {
      await store.write('u-1', {DayOfWeek.fri, DayOfWeek.mon, DayOfWeek.wed});

      expect(await store.read('u-1'), {
        DayOfWeek.mon,
        DayOfWeek.wed,
        DayOfWeek.fri,
      });
    },
  );

  test('another account on the same phone reads nothing', () async {
    await store.write('u-1', {DayOfWeek.mon});

    expect(await store.read('u-2'), isEmpty);
    expect(await store.read('u-1'), {DayOfWeek.mon});
  });

  test('writing an empty choice replaces an earlier one', () async {
    await store.write('u-1', {DayOfWeek.mon});
    await store.write('u-1', {});

    expect(await store.read('u-1'), isEmpty);
  });

  test(
    'an unknown day name in storage is ignored, the known ones kept',
    () async {
      SharedPreferences.setMockInitialValues({
        '${LunchboxDaysStore.keyPrefix}u-1': ['tue', 'someday'],
      });

      expect(await store.read('u-1'), {DayOfWeek.tue});
    },
  );

  test('clearAll removes every account but leaves other keys alone', () async {
    await store.write('u-1', {DayOfWeek.mon});
    await store.write('u-2', {DayOfWeek.tue});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('unrelated', 'kept');

    await LunchboxDaysStore.clearAll();

    expect(await store.read('u-1'), isEmpty);
    expect(await store.read('u-2'), isEmpty);
    expect(prefs.getString('unrelated'), 'kept');
  });
}
