/// The app and `sendNotification` must agree on every push the app sends
/// (BUT-2400): the server refuses a payload whose `route` is missing or not in
/// its allowlist, which once silently dropped every app-sent push.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/notifications/recipe_activity_strategies.dart';

/// `NOTIFICATION_ROUTES` as the server declares it, read from its source.
Set<String> _serverRoutes() {
  final source = File(
    'functions/src/shared/notification-payload.ts',
  ).readAsStringSync();
  final block = RegExp(
    r'export const NOTIFICATION_ROUTES = \[(.*?)\] as const;',
    dotAll: true,
  ).firstMatch(source);
  expect(block, isNotNull, reason: 'NOTIFICATION_ROUTES not found');
  final body = block!
      .group(1)!
      .split('\n')
      .map((line) => line.replaceFirst(RegExp(r'//.*'), ''))
      .join('\n');
  return RegExp(r'"([^"]+)"').allMatches(body).map((m) => m.group(1)!).toSet();
}

final _strategies = <NotificationStrategy>[
  ...NotificationStrategy.all,
  ...RecipeActivityStrategies.all,
];

void main() {
  late Set<String> serverRoutes;

  setUpAll(() => serverRoutes = _serverRoutes());

  test('the app and the server list the same routes', () {
    expect(serverRoutes, isNotEmpty);
    expect(NotificationRoutes.all, serverRoutes);
  });

  test('every strategy names a route the server accepts and a type', () {
    for (final strategy in _strategies) {
      final data = strategy.deepLinkData(const {});
      expect(
        serverRoutes,
        contains(data['route']),
        reason: '${strategy.notificationType} route',
      );
      expect(data['notificationType'], isNotEmpty);
      expect(data['targetId'], isA<String>());
    }
  });

  test('a strategy reads its destination id from its own key', () {
    for (final strategy in _strategies) {
      final key = strategy.destination.targetIdKey;
      if (key == null) continue;
      expect(
        strategy.deepLinkData({key: 'id-1'})['targetId'],
        'id-1',
        reason: strategy.notificationType,
      );
    }
  });

  test('a built template carries the schema fields, and they win', () {
    for (final strategy in _strategies) {
      final template = NotificationTemplate.fromStrategy(
        strategy,
        const {},
        additionalData: const {
          'route': '/not-a-route',
          'notificationType': '',
        },
      );
      expect(template.data['route'], strategy.destination.route);
      expect(template.data['notificationType'], strategy.notificationType);
    }
  });
}
