/// Unit tests for CorrelationId — request correlation tracking.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../test_support/base_unit_test.dart';
import 'package:butlery/core/utils/correlation_id.dart';

void main() {
  group('CorrelationId', () {
    setUp(() async => await BaseUnitTest.setupUnit());
    tearDown(() {
      CorrelationId.clear();
      BaseUnitTest.resetMocks();
    });

    test('current is null initially', () {
      expect(CorrelationId.current, isNull);
    });

    test('generate sets current and returns formatted id', () {
      final id = CorrelationId.generate();
      expect(id, matches(RegExp(r'^\d+-\d{4}$')));
      expect(CorrelationId.current, id);
    });

    test('set assigns a custom value', () {
      CorrelationId.set('custom-id-123');
      expect(CorrelationId.current, 'custom-id-123');
    });

    test('clear resets current to null', () {
      CorrelationId.generate();
      expect(CorrelationId.current, isNotNull);
      CorrelationId.clear();
      expect(CorrelationId.current, isNull);
    });

    test('scope generates, runs action, and clears', () async {
      String? idDuringScope;
      await CorrelationId.scope(() async {
        idDuringScope = CorrelationId.current;
      });
      expect(idDuringScope, isNotNull);
      expect(idDuringScope, matches(RegExp(r'^\d+-\d{4}$')));
      expect(CorrelationId.current, isNull);
    });

    test('scopeSync generates, runs action, and clears', () {
      String? idDuringScope;
      CorrelationId.scopeSync(() {
        idDuringScope = CorrelationId.current;
        return 42;
      });
      expect(idDuringScope, isNotNull);
      expect(CorrelationId.current, isNull);
    });

    test('scopeSync clears even if action throws', () {
      try {
        CorrelationId.scopeSync<void>(() {
          throw Exception('test error');
        });
      } catch (_) {}
      expect(CorrelationId.current, isNull);
    });
  });
}
