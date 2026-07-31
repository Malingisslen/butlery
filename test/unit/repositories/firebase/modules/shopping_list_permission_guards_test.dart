/// BUT-1755 — `requireNoPrivilegeEscalation` on a list with no stored
/// `createdAt`.
///
/// The guard compares `proposed.createdAt` against `stored.createdAt` for exact
/// equality. `proposed` and `stored` are two SEPARATE parses of the same
/// Firestore document, so that comparison is only meaningful if the parse seam
/// is deterministic. While `UnifiedShoppingList.fromMap` fell back to
/// `clock.now()`, a legacy or imported list produced a different value on every
/// read and this guard refused EVERY non-owner edit of it — a permanent denial
/// whose own remedy ("reload the list") could never clear it.
///
/// These tests drive the guard through `fromMap` on purpose. Building the two
/// lists with an explicit `createdAt` would pass no matter what the seam does,
/// which is exactly the vacuous-fixture trap the repo's lessons warn about.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/modules/shopping_list_permission_guards.dart';

void main() {
  group('ShoppingListPermissionGuards.requireNoPrivilegeEscalation', () {
    const ownerId = 'owner_1';
    const memberId = 'member_2';

    late List<Map<String, Object?>> auditRows;
    late ShoppingListPermissionGuards guards;

    setUp(() {
      auditRows = [];
      guards = ShoppingListPermissionGuards(
        logPermissionCheck:
            ({
              required String userId,
              required String resource,
              required String operation,
              required bool granted,
              String? details,
            }) async {
              auditRows.add({
                'userId': userId,
                'granted': granted,
                'details': details,
              });
            },
        validateUpdatePermission: (_, _, _) async => true,
        validateRequiredFields:
            ({
              required Map<String, dynamic> data,
              required List<String> requiredFields,
              required String resourceType,
            }) {},
      );
    });

    /// A stored document that never got a `createdAt` — the legacy/import shape
    /// the guard used to deadlock on.
    Map<String, dynamic> legacyDoc() => {
      'name': 'Gemensam lista',
      'ownerId': ownerId,
      'ownerDisplayName': 'Ägaren',
      'items': <dynamic>[],
      'memberPermissions': {ownerId: 'admin', memberId: 'edit'},
    };

    /// Runs [body] under a clock that ADVANCES a minute per reading.
    ///
    /// Without it the two parses below would race: the pre-fix `clock.now()`
    /// fallback can hand back the identical microsecond for two back-to-back
    /// reads, so the test would pass on the broken code roughly as often as it
    /// caught it. In production the two reads are minutes apart — a view holds
    /// its copy while the repository re-reads — so the advancing clock is the
    /// faithful staging, not a convenience.
    T underAdvancingClock<T>(T Function() body) {
      var tick = 0;
      return withClock(
        Clock(() => DateTime.utc(2026, 7, 30).add(Duration(minutes: tick++))),
        body,
      );
    }

    test('a non-owner content edit on a list with no stored createdAt is '
        'allowed', () async {
      // The caller's copy is an independent parse of the same document —
      // exactly what the view holds — with only the name changed.
      final (stored, proposed) = underAdvancingClock(() {
        final s = UnifiedShoppingList.fromMap('list_1', legacyDoc());
        final p = UnifiedShoppingList.fromMap(
          'list_1',
          legacyDoc(),
        ).copyWith(name: 'Nytt namn');
        return (s, p);
      });

      await expectLater(
        guards.requireNoPrivilegeEscalation(memberId, proposed, stored),
        completes,
      );
      expect(auditRows, isEmpty, reason: 'no refusal should be audited');
    });

    test('the two parses agree on createdAt, so the guard has something to '
        'compare', () {
      final (a, b) = underAdvancingClock(
        () => (
          UnifiedShoppingList.fromMap('list_1', legacyDoc()),
          UnifiedShoppingList.fromMap('list_1', legacyDoc()),
        ),
      );

      expect(a.createdAt, equals(b.createdAt));
      expect(a.createdAt, equals(UnifiedShoppingList.unknownCreatedAt));
    });

    test(
      'a non-owner that really does move createdAt is still refused',
      () async {
        final stored = UnifiedShoppingList.fromMap('list_1', legacyDoc());
        final proposed = UnifiedShoppingList(
          id: 'list_1',
          name: stored.name,
          ownerId: stored.ownerId,
          ownerDisplayName: stored.ownerDisplayName,
          memberPermissions: stored.memberPermissions,
          createdAt: DateTime.utc(2026, 7, 30),
        );

        await expectLater(
          guards.requireNoPrivilegeEscalation(memberId, proposed, stored),
          throwsA(isA<PermissionDeniedException>()),
        );
        expect(auditRows.single['granted'], isFalse);
        expect(auditRows.single['details'], contains('createdAt'));
      },
    );

    test(
      'a non-owner edit is allowed even after the sentinel round-trips '
      'through a real Firestore Timestamp (UTC in, LOCAL back out)',
      () async {
        // Reproduces the exact reopening this ticket's fix was blind to: the
        // sentinel is `DateTime.utc(1970)`, but `Timestamp.fromDate(...)
        // .toDate()` hands back a LOCAL DateTime for the same instant. A
        // client holding the pre-persist UTC sentinel comparing against a
        // freshly-read post-persist (now local) value must NOT be refused —
        // `!=` alone would flag this as a rewrite because it also compares
        // `isUtc`, not just the instant.
        final roundTripped = Timestamp.fromDate(
          UnifiedShoppingList.unknownCreatedAt,
        ).toDate();
        expect(
          roundTripped.isUtc,
          isFalse,
          reason:
              'Timestamp.toDate() returns local time, not UTC — the '
              'premise this test exists to pin',
        );
        expect(
          roundTripped == UnifiedShoppingList.unknownCreatedAt,
          isFalse,
          reason:
              'same instant, different isUtc — DateTime.== treats these '
              'as unequal, which is exactly the trap',
        );

        final stored = UnifiedShoppingList.fromMap('list_1', {
          ...legacyDoc(),
          'createdAt': Timestamp.fromDate(UnifiedShoppingList.unknownCreatedAt),
        });
        final proposed = UnifiedShoppingList.fromMap(
          'list_1',
          legacyDoc(),
        ).copyWith(name: 'Nytt namn');

        await expectLater(
          guards.requireNoPrivilegeEscalation(memberId, proposed, stored),
          completes,
        );
        expect(auditRows, isEmpty, reason: 'no refusal should be audited');
      },
    );

    test('a non-owner rewriting memberPermissions is still refused', () async {
      final stored = UnifiedShoppingList.fromMap('list_1', legacyDoc());
      final proposed = UnifiedShoppingList.fromMap('list_1', {
        ...legacyDoc(),
        'memberPermissions': {ownerId: 'admin', memberId: 'admin'},
      });

      await expectLater(
        guards.requireNoPrivilegeEscalation(memberId, proposed, stored),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(auditRows.single['details'], contains('memberPermissions'));
    });

    test('the owner is exempt regardless of createdAt', () async {
      final stored = UnifiedShoppingList.fromMap('list_1', legacyDoc());
      final proposed = UnifiedShoppingList.fromMap('list_1', legacyDoc());

      await expectLater(
        guards.requireNoPrivilegeEscalation(ownerId, proposed, stored),
        completes,
      );
      expect(auditRows, isEmpty);
    });
  });
}
