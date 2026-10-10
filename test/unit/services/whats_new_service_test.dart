import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/whats_new/whats_new_catalog.dart';
import 'package:butlery/services/whats_new/whats_new_service.dart';

WhatsNewItem _item(String name) =>
    WhatsNewItem(title: (_) => name, body: (_) => name);

WhatsNewRelease _release(String version, int count) => WhatsNewRelease(
  version: version,
  items: [for (var i = 0; i < count; i++) _item('$version-$i')],
);

Future<WhatsNewService> _service({
  required String current,
  String? stored,
  List<WhatsNewRelease> catalog = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    WhatsNewService.lastSeenKey: ?stored,
  });
  return WhatsNewService(
    prefs: await SharedPreferences.getInstance(),
    currentVersion: current,
    catalog: catalog,
  );
}

Future<String?> _storedVersion() async =>
    (await SharedPreferences.getInstance()).getString(
      WhatsNewService.lastSeenKey,
    );

void main() {
  test('first install shows nothing and records the current version', () async {
    final service = await _service(
      current: '1.4.0',
      catalog: [_release('1.4.0', 2)],
    );

    expect(await service.releasesToShow(), isEmpty);
    expect(await _storedVersion(), '1.4.0');
  });

  test('an update shows the new release and records the version', () async {
    final service = await _service(
      current: '1.4.0',
      stored: '1.3.0',
      catalog: [_release('1.3.0', 1), _release('1.4.0', 2)],
    );

    final result = await service.releasesToShow();

    expect(result.map((r) => r.version), ['1.4.0']);
    expect(result.single.items, hasLength(2));
    expect(await _storedVersion(), '1.4.0');
  });

  test(
    'skipped versions come newest first and are capped at 5 items',
    () async {
      final service = await _service(
        current: '1.4.0',
        stored: '1.0.0',
        catalog: [
          _release('1.2.0', 2),
          _release('1.4.0', 4),
          _release('1.3.0', 3),
        ],
      );

      final result = await service.releasesToShow();

      expect(result.map((r) => r.version), ['1.4.0', '1.3.0']);
      expect(result.expand((r) => r.items), hasLength(5));
      expect(result.last.items, hasLength(1));
    },
  );

  test('releases newer than the running version are not shown', () async {
    final service = await _service(
      current: '1.3.0',
      stored: '1.0.0',
      catalog: [_release('1.3.0', 1), _release('1.4.0', 1)],
    );

    expect((await service.releasesToShow()).map((r) => r.version), ['1.3.0']);
  });

  test('the same version shows nothing', () async {
    final service = await _service(
      current: '1.4.0',
      stored: '1.4.0',
      catalog: [_release('1.4.0', 2)],
    );

    expect(await service.releasesToShow(), isEmpty);
  });

  test('a downgrade shows nothing and records the lower version', () async {
    final service = await _service(
      current: '1.3.0',
      stored: '1.4.0',
      catalog: [_release('1.3.0', 2), _release('1.4.0', 2)],
    );

    expect(await service.releasesToShow(), isEmpty);
    expect(await _storedVersion(), '1.3.0');
  });

  test('an unknown version shows nothing and stores nothing', () async {
    final service = await _service(
      current: 'unknown',
      stored: '1.0.0',
      catalog: [_release('1.4.0', 2)],
    );

    expect(await service.releasesToShow(), isEmpty);
    expect(await _storedVersion(), '1.0.0');
  });

  test('versions compare numerically and ignore the build suffix', () async {
    final service = await _service(
      current: '1.10.0+7',
      stored: '1.9.0',
      catalog: [_release('1.10.0', 1)],
    );

    expect((await service.releasesToShow()).map((r) => r.version), ['1.10.0']);
  });

  test('latestReleaseUpTo picks the newest release not above the version', () {
    final catalog = [
      _release('1.2.0', 1),
      _release('1.4.0', 1),
      _release('1.3.0', 1),
    ];

    expect(
      WhatsNewService.latestReleaseUpTo(catalog, '1.3.5')?.version,
      '1.3.0',
    );
    expect(WhatsNewService.latestReleaseUpTo(catalog, '1.1.0'), isNull);
    expect(WhatsNewService.latestReleaseUpTo(catalog, 'unknown'), isNull);
  });
}
