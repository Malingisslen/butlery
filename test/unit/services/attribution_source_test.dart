/// AttributionSource: who a document other people read says its writer is
/// (BUT-2009).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/utils/stored_display_name.dart';
import 'package:butlery/services/attribution_source.dart';
import 'package:butlery/services/user_service.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  test('a rename between construction and read is reflected', () {
    final userService = MockUserService();
    when(() => userService.attributionDisplayName).thenReturn('Anna');
    when(() => userService.profileAvatarUrl).thenReturn('https://x/a.jpg');
    final source = AttributionSource(userService: () => userService);

    expect(source.displayName, 'Anna');
    expect(source.avatarUrl, 'https://x/a.jpg');

    when(() => userService.attributionDisplayName).thenReturn('Anna B');
    when(() => userService.profileAvatarUrl).thenReturn(null);

    expect(source.displayName, 'Anna B');
    expect(source.avatarUrl, isNull);
  });

  test(
    'the service is resolved at call time, not captured at construction',
    () {
      UserService? current;
      final source = AttributionSource(userService: () => current);
      expect(source.displayName, isEmpty);

      final arrived = MockUserService();
      when(() => arrived.attributionDisplayName).thenReturn('Kommer senare');
      current = arrived;

      expect(source.displayName, 'Kommer senare');
    },
  );

  test(
    'with no service the name is empty and the avatar null',
    () {
      final source = AttributionSource(userService: () => null);

      expect(source.displayName, isEmpty);
      expect(knownStoredName(source.displayName), isNull);
      expect(source.avatarUrl, isNull);
    },
  );
}
