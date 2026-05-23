/// Unit tests for CorrelationId.
///
/// Static-state singleton. Each test resets via clear() in tearDown so
/// they don't bleed into each other.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/correlation_id.dart';

void main() {
  tearDown(CorrelationId.clear);

  test('generate produces a timestamp-random format and sets current', () {
    final id = CorrelationId.generate();
    expect(id, matches(RegExp(r'^\d+-\d{4}$')));
    expect(CorrelationId.current, id);
  });

  test('generate produces distinct IDs across rapid calls', () {
    final ids = List.generate(50, (_) => CorrelationId.generate()).toSet();
    // Even if timestamps collide, the random suffix gives variety.
    // We tolerate occasional collisions but assert most are unique.
    expect(ids.length, greaterThan(40));
  });

  test('current is null when no ID has been generated', () {
    expect(CorrelationId.current, isNull);
  });

  test('set overrides current with the provided value', () {
    CorrelationId.set('external-corr-123');
    expect(CorrelationId.current, 'external-corr-123');
  });

  test('clear resets current to null', () {
    CorrelationId.generate();
    expect(CorrelationId.current, isNotNull);
    CorrelationId.clear();
    expect(CorrelationId.current, isNull);
  });

  group('scope (async)', () {
    test('generates before action, clears after — even on success', () async {
      String? observed;
      final result = await CorrelationId.scope(() async {
        observed = CorrelationId.current;
        return 42;
      });
      expect(result, 42);
      expect(observed, isNotNull);
      expect(CorrelationId.current, isNull);
    });

    test('clears even when action throws', () async {
      String? observed;
      await expectLater(
        () => CorrelationId.scope(() async {
          observed = CorrelationId.current;
          throw StateError('boom');
        }),
        throwsA(isA<StateError>()),
      );
      expect(observed, isNotNull);
      expect(CorrelationId.current, isNull);
    });
  });

  group('scopeSync', () {
    test('generates before, clears after on success', () {
      String? observed;
      final result = CorrelationId.scopeSync(() {
        observed = CorrelationId.current;
        return 'ok';
      });
      expect(result, 'ok');
      expect(observed, isNotNull);
      expect(CorrelationId.current, isNull);
    });

    test('clears even when sync action throws', () {
      expect(
        () => CorrelationId.scopeSync(() => throw ArgumentError('x')),
        throwsArgumentError,
      );
      expect(CorrelationId.current, isNull);
    });
  });
}
