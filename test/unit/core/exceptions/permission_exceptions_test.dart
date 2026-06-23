/// Unit tests for the permission-exception family.
///
/// Pins the `toString()` output for each type — the format is used by
/// log scrapers and the audit-log writer, so we treat it as a contract.
/// Each exception's optional context fields drop out of toString() when
/// absent and join cleanly when present.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';

void main() {
  group('PermissionDeniedException', () {
    test('toString includes only message when no context provided', () {
      final e = PermissionDeniedException('denied');
      expect(e.toString(), 'PermissionDeniedException: denied');
    });

    test('toString joins all context fields in fixed order', () {
      final e = PermissionDeniedException(
        'denied',
        resource: 'recipe',
        operation: 'delete',
        userId: 'alice',
      );
      expect(
        e.toString(),
        'PermissionDeniedException: denied, Operation: delete, Resource: recipe, User: alice',
      );
    });

    test('omits absent fields individually', () {
      final e = PermissionDeniedException('denied', userId: 'alice');
      expect(e.toString(), 'PermissionDeniedException: denied, User: alice');
    });

    test('is an Exception', () {
      expect(PermissionDeniedException('x'), isA<Exception>());
    });
  });

  group('ResourceNotFoundException', () {
    test('toString includes only message when no context', () {
      final e = ResourceNotFoundException('not found');
      expect(e.toString(), 'ResourceNotFoundException: not found');
    });

    test('toString includes type and id when present', () {
      final e = ResourceNotFoundException(
        'not found',
        resourceType: 'recipe',
        resourceId: 'r1',
      );
      expect(
        e.toString(),
        'ResourceNotFoundException: not found, Type: recipe, ID: r1',
      );
    });

    test('omits absent fields', () {
      final e = ResourceNotFoundException('not found', resourceType: 'x');
      expect(e.toString(), 'ResourceNotFoundException: not found, Type: x');
    });
  });

  group('SecurityViolationException', () {
    test('toString without details is bare', () {
      final e = SecurityViolationException('blocked');
      expect(e.toString(), 'SecurityViolationException: blocked');
    });

    test('toString appends details with " - " separator', () {
      final e = SecurityViolationException('blocked', details: 'too many');
      expect(e.toString(), 'SecurityViolationException: blocked - too many');
    });
  });

  group('AuthenticationException', () {
    test('toString without details is bare', () {
      final e = AuthenticationException('must sign in');
      expect(e.toString(), 'AuthenticationException: must sign in');
    });

    test('toString appends details with " - " separator', () {
      final e = AuthenticationException(
        'must sign in',
        details: 'session expired',
      );
      expect(
        e.toString(),
        'AuthenticationException: must sign in - session expired',
      );
    });
  });

  group('ValidationException', () {
    test('toString without field/value is bare', () {
      expect(ValidationException('bad').toString(), 'ValidationException: bad');
    });

    test('toString includes field when set', () {
      expect(
        ValidationException('bad', field: 'title').toString(),
        'ValidationException: bad, Field: title',
      );
    });

    test('toString includes value when set', () {
      expect(
        ValidationException('bad', value: 42).toString(),
        'ValidationException: bad, Value: 42',
      );
    });

    test('toString omits value when null but includes when 0', () {
      // `if (value != null)` — 0 is not null and must appear.
      expect(
        ValidationException('bad', value: 0).toString(),
        'ValidationException: bad, Value: 0',
      );
    });

    test('value field exposes the raw object', () {
      final value = {'k': 'v'};
      final e = ValidationException('bad', value: value);
      expect(e.value, same(value));
    });
  });
}
