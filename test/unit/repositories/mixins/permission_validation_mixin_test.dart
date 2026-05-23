/// Unit tests for PermissionValidationMixin.
///
/// Targets the ~54 unhit lines using a test-only class that includes the
/// mixin. No Firebase needed for most methods.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/repositories/mixins/permission_validation_mixin.dart';

class _TestSubject with PermissionValidationMixin {}

void main() {
  final subject = _TestSubject();

  group('validateOwnership', () {
    test('passes when current user owns resource', () async {
      await subject.validateOwnership(
        currentUserId: 'alice',
        resourceOwnerId: 'alice',
        resourceType: 'recipe',
      );
    });

    test('throws when user is null (unauthenticated)', () async {
      await expectLater(
        () => subject.validateOwnership(
          currentUserId: null,
          resourceOwnerId: 'alice',
          resourceType: 'recipe',
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('throws when user is not owner', () async {
      await expectLater(
        () => subject.validateOwnership(
          currentUserId: 'bob',
          resourceOwnerId: 'alice',
          resourceType: 'recipe',
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('hasReadAccess', () {
    test('false when user is null', () async {
      expect(
          await subject.hasReadAccess(
              currentUserId: null, resourceOwnerId: 'alice'),
          isFalse);
    });

    test('true when user is owner', () async {
      expect(
          await subject.hasReadAccess(
              currentUserId: 'alice', resourceOwnerId: 'alice'),
          isTrue);
    });

    test('true when resource is public', () async {
      expect(
          await subject.hasReadAccess(
              currentUserId: 'bob', resourceOwnerId: 'alice', isPublic: true),
          isTrue);
    });

    test('true when user is in shared list', () async {
      expect(
          await subject.hasReadAccess(
              currentUserId: 'bob',
              resourceOwnerId: 'alice',
              sharedWithUserIds: ['bob']),
          isTrue);
    });

    test('false when not owner, not public, not shared', () async {
      expect(
          await subject.hasReadAccess(
              currentUserId: 'bob', resourceOwnerId: 'alice'),
          isFalse);
    });
  });

  group('validateWritePermission', () {
    test('passes for owner', () async {
      await subject.validateWritePermission(
        currentUserId: 'alice',
        resourceOwnerId: 'alice',
        resourceType: 'recipe',
      );
    });

    test('passes for collaborator', () async {
      await subject.validateWritePermission(
        currentUserId: 'bob',
        resourceOwnerId: 'alice',
        resourceType: 'recipe',
        collaborators: const ['bob'],
      );
    });

    test('throws when user is null', () async {
      await expectLater(
        () => subject.validateWritePermission(
          currentUserId: null,
          resourceOwnerId: 'alice',
          resourceType: 'recipe',
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('throws for non-owner non-collaborator', () async {
      await expectLater(
        () => subject.validateWritePermission(
          currentUserId: 'carol',
          resourceOwnerId: 'alice',
          resourceType: 'recipe',
          collaborators: const ['bob'],
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('validateSelfOperation', () {
    test('passes when current user matches target', () async {
      await subject.validateSelfOperation(
        currentUserId: 'alice',
        targetUserId: 'alice',
        operation: 'update profile',
      );
    });

    test('throws when user is null', () async {
      await expectLater(
        () => subject.validateSelfOperation(
          currentUserId: null,
          targetUserId: 'alice',
          operation: 'update profile',
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('throws when current != target', () async {
      await expectLater(
        () => subject.validateSelfOperation(
          currentUserId: 'bob',
          targetUserId: 'alice',
          operation: 'delete account',
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('validateRequiredFields', () {
    test('passes when all required fields present', () {
      subject.validateRequiredFields(
        data: const {
          'name': 'Pasta',
          'ingredients': ['x']
        },
        requiredFields: const ['name', 'ingredients'],
        resourceType: 'recipe',
      );
    });

    test('throws SecurityViolationException when any missing', () {
      expect(
        () => subject.validateRequiredFields(
          data: const {'name': 'Pasta'},
          requiredFields: const ['name', 'ingredients'],
          resourceType: 'recipe',
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });
  });

  group('validateFieldConstraints', () {
    test('passes when constraints are met', () {
      subject.validateFieldConstraints(
        data: const {
          'title': 'Pasta',
          'tags': ['veg']
        },
        constraints: const {
          'title': FieldConstraint(minLength: 2, maxLength: 100),
          'tags': FieldConstraint(maxItems: 5),
        },
        resourceType: 'recipe',
      );
    });

    test('throws when string exceeds maxLength', () {
      expect(
        () => subject.validateFieldConstraints(
          data: const {'title': 'a very long title'},
          constraints: const {
            'title': FieldConstraint(maxLength: 5),
          },
          resourceType: 'recipe',
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('throws when string below minLength', () {
      expect(
        () => subject.validateFieldConstraints(
          data: const {'title': 'a'},
          constraints: const {
            'title': FieldConstraint(minLength: 3),
          },
          resourceType: 'recipe',
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('throws when list exceeds maxItems', () {
      expect(
        () => subject.validateFieldConstraints(
          data: const {
            'tags': [1, 2, 3, 4, 5, 6]
          },
          constraints: const {
            'tags': FieldConstraint(maxItems: 5),
          },
          resourceType: 'recipe',
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('throws when value not in allowedValues', () {
      expect(
        () => subject.validateFieldConstraints(
          data: const {'status': 'invalid'},
          constraints: const {
            'status': FieldConstraint(allowedValues: ['draft', 'published']),
          },
          resourceType: 'recipe',
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('skips missing keys', () {
      subject.validateFieldConstraints(
        data: const {},
        constraints: const {
          'title': FieldConstraint(maxLength: 5),
        },
        resourceType: 'recipe',
      );
    });
  });

  group('FieldConstraint constructor', () {
    test('stores all fields', () {
      const c = FieldConstraint(
        minLength: 2,
        maxLength: 100,
        maxItems: 10,
        allowedValues: ['a', 'b'],
      );
      expect(c.minLength, 2);
      expect(c.maxLength, 100);
      expect(c.maxItems, 10);
      expect(c.allowedValues, ['a', 'b']);
    });
  });
}
