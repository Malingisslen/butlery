/// Unit tests for the permission-exception family.
///
/// Pins the `toString()` output for each type. The real consumer is the
/// crash-report path: `recordError` sends `exception.toString()`, and on web
/// the error reporter reads it directly — so this format is what leaves the
/// device. (An earlier header named the audit-log writer; it takes structured
/// fields and never stringifies these.)
/// Each exception's optional context fields drop out of toString() when
/// absent and join cleanly when present.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';

/// One copy, file-level. Both masking groups used to declare it separately, and
/// a shortened copy would drop below the 20-character window and pass for the
/// wrong reason.
const _uid = 'AbCdEfGhIjKlMnOpQrStUvWx1234';
const _otherUid = 'ZyXwVuTsRqPoNmLkJiHgFeDc9876';

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

  // BUT-1897. `toString()` is the string that leaves the device: `AppLogger`
  // hands the exception OBJECT to `recordError` unchanged, an uncaught
  // exception reaches `recordError` from `main.dart` without passing any
  // logger, and on web Crashlytics is skipped so the web reporter reads
  // `error.toString()` directly. Masking here reaches every throw site of these
  // classes at once, and reaches those three paths as well.
  group('uid-shaped identifiers are masked in toString', () {
    test('a uid in the userId field is truncated', () {
      final e = PermissionDeniedException('denied', userId: _uid);

      expect(e.toString(), isNot(contains(_uid)));
      expect(e.toString(), contains('AbCd***'));
    });

    test('a uid inside the MESSAGE is truncated too', () {
      // A route the named-field rule cannot see: sites in
      // `base_firebase_repository` interpolate the uid into the message rather
      // than passing it as `userId:`, and a field rule misses every one of them.
      // The counts live nowhere now — see the doc on
      // `PermissionDeniedException.toString`, which explains why.
      final e = PermissionDeniedException(
        'User $_uid may not read Recipe r1',
      );

      expect(e.toString(), isNot(contains(_uid)));
    });

    test('a uid inside a resource PATH is truncated', () {
      // `resource: 'storage/$path'` where path is `users/<_uid>/...` — the id is
      // not the thing interpolated, so a field-name rule cannot see it.
      final e = PermissionDeniedException(
        'denied',
        resource: 'storage/users/$_uid/avatar.jpg',
      );

      expect(e.toString(), isNot(contains(_uid)));
    });

    test('a DM conversation id is hashed, not printed', () {
      // `direct_<uidA>_<uidB>` is a social-graph edge: it asserts that these two
      // accounts have a private conversation. Hashed rather than blanked so one
      // conversation still reads the same across a crash report and a Cloud
      // Functions log.
      final e = ResourceNotFoundException(
        'not found',
        resourceType: 'conversation',
        resourceId: 'direct_${_uid}_$_otherUid',
      );

      expect(e.toString(), isNot(contains(_uid)));
      expect(e.toString(), isNot(contains(_otherUid)));
      expect(e.toString(), contains('direct_#'));
    });

    test('the subclass masks in its own right', () {
      // `StaleAccessControlBaseException` OVERRIDES `toString()`, so it does not
      // inherit the parent's masking along with the parent's reasoning.
      final e = StaleAccessControlBaseException('stale', userId: _uid);

      expect(e.toString(), isNot(contains(_uid)));
      expect(e.toString(), startsWith('StaleAccessControlBaseException: '));
    });

    test('the exception TYPE survives the mask', () {
      // Not cosmetic: `PermissionDeniedException` is 25 alphanumeric characters,
      // inside the masker's 20-28 window (a uid is 28 — it is the WINDOW they
      // share, not the length). Masking the label with the body turned every
      // one of these into `Perm***`, and the label's position outside the mask
      // is what keeps Crashlytics grouping by type: `recordError` sends
      // `exception.toString()`, so the object's `runtimeType` never crosses.
      expect(
        PermissionDeniedException('denied').toString(),
        startsWith('PermissionDeniedException: '),
      );
      expect(
        ResourceNotFoundException('gone').toString(),
        startsWith('ResourceNotFoundException: '),
      );
    });

    test('a uid inside a COMPOSITE document id is truncated', () {
      // The case a word-boundary rule misses, and it is not exotic: a weekly
      // menu plan's id is `${userId}_${weekKey}` and a retention row's is
      // `{_uid}_{date}`. `\b` counts `_` as a word character, so the whole
      // composite passed through untouched inside a message
      // `base_firebase_repository` really throws.
      final e = PermissionDeniedException(
        'User $_uid may not read WeeklyMenuPlan ${_uid}_2026-W34',
      );

      expect(e.toString(), isNot(contains(_uid)));
    });

    test('SecurityViolationException masks its details', () {
      // Left out of the first pass, and `details:` is exactly where callers put
      // the id.
      final e = SecurityViolationException(
        'not allowed',
        details: 'household=$_uid',
      );

      expect(e.toString(), isNot(contains(_uid)));
      expect(e.toString(), startsWith('SecurityViolationException: '));
    });

    test('AuthenticationException masks its details', () {
      final e = AuthenticationException(
        'not signed in',
        details: 'uid=$_uid',
      );

      expect(e.toString(), isNot(contains(_uid)));
      expect(e.toString(), startsWith('AuthenticationException: '));
    });

    test('the raw values stay on the fields', () {
      final e = PermissionDeniedException('denied', userId: _uid);

      expect(
        e.userId,
        _uid,
        reason:
            'masking is a property of the STRING that leaves the device, not '
            'of the exception — a local handler still gets the real id',
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

    // BUT-1897: the rejected value is DESCRIBED, never quoted. It is whatever
    // the user typed — a comment body, a recipe title, an email into a form —
    // and `toString()` is what reaches Crashlytics.
    test('toString names the type of the value, not the value', () {
      expect(
        ValidationException('bad', value: 42).toString(),
        'ValidationException: bad, Value: <int>',
      );
    });

    test('toString omits value when null but describes it when 0', () {
      // `if (value != null)` — 0 is not null and must still be reported. Both
      // halves are asserted because the name claims both; asserting only the
      // zero half is the defect this sprint fixed one file over.
      expect(
        ValidationException('bad').toString(),
        isNot(contains('Value:')),
      );
      expect(
        ValidationException('bad', value: 0).toString(),
        'ValidationException: bad, Value: <int>',
      );
    });

    test('an identifier in the MESSAGE is masked here too', () {
      // The mask call on this class was deletable-green until this case
      // existed: every other assertion was an exact literal over short tokens,
      // and the free-text case below is satisfied by the type-description
      // branch alone, without the mask ever running.
      final e = ValidationException(
        'Ogiltig mottagare $_uid',
        field: 'recipient',
      );

      expect(e.toString(), isNot(contains(_uid)));
    });

    test('a free-text value never reaches the string', () {
      // A synthetic address, not a real one — this is the file about not
      // leaking personal data.
      const address = 'someone@example.com';
      final e = ValidationException(
        'ogiltig e-post',
        field: 'email',
        value: address,
      );

      expect(e.toString(), isNot(contains('@')));
      expect(e.toString(), contains('Field: email'));
      expect(
        e.value,
        address,
        reason:
            'the FIELD keeps the raw value — a local handler and a debugger '
            'are unaffected; only the string that leaves the device is masked',
      );
    });

    test('value field exposes the raw object', () {
      final value = {'k': 'v'};
      final e = ValidationException('bad', value: value);
      expect(e.value, same(value));
    });
  });
}
