/// Unit tests for RecipeGdprExportOperations.
///
/// The module exposes the two BUT-501 GDPR Article 20 export paths —
/// per-user subcollection `users/{userId}/recipes` and the legacy
/// top-level `recipes` collection filtered by the `userId` field.
/// Both methods validate ownership before reading, and both honour the
/// `maxDocuments` cap. Tests drive each path end-to-end against
/// `FakeFirebaseFirestore`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/repositories/firebase/modules/recipe_gdpr_export_operations.dart';

const _userId = 'alice';

CollectionReference<Map<String, dynamic>> _userRecipes(
  FakeFirebaseFirestore firestore,
  String userId,
) => firestore.collection('users').doc(userId).collection('recipes');

class _OwnershipCall {
  final String? currentUserId;
  final String resourceOwnerId;
  final String resourceType;
  _OwnershipCall(this.currentUserId, this.resourceOwnerId, this.resourceType);
}

RecipeGdprExportOperations _ops(
  FakeFirebaseFirestore firestore, {
  String? currentUid,
  List<_OwnershipCall>? ownershipCalls,
  bool ownershipThrows = false,
}) {
  return RecipeGdprExportOperations(
    firestore: firestore,
    getCollectionForUser: (uid) => _userRecipes(firestore, uid),
    requireCurrentUserId: () => currentUid ?? _userId,
    validateOwnership:
        ({
          required String? currentUserId,
          required String resourceOwnerId,
          required String resourceType,
          String? resourceId,
        }) async {
          ownershipCalls?.add(
            _OwnershipCall(currentUserId, resourceOwnerId, resourceType),
          );
          if (ownershipThrows) {
            throw PermissionDeniedException('denied');
          }
        },
  );
}

void main() {
  group('exportPersonalRecipesByUser', () {
    test('returns id + data for every doc in user subcollection', () async {
      final firestore = FakeFirebaseFirestore();
      await _userRecipes(firestore, _userId).doc('r1').set({'title': 'Pasta'});
      await _userRecipes(firestore, _userId).doc('r2').set({'title': 'Soup'});

      final export = await _ops(firestore).exportPersonalRecipesByUser(_userId);

      expect(export, hasLength(2));
      final ids = export.map((e) => e['id']).toSet();
      expect(ids, {'r1', 'r2'});
      final titles = export
          .map((e) => (e['data'] as Map<String, dynamic>)['title'])
          .toSet();
      expect(titles, {'Pasta', 'Soup'});
    });

    test('returns empty list when user has no recipes', () async {
      final firestore = FakeFirebaseFirestore();
      expect(
        await _ops(firestore).exportPersonalRecipesByUser(_userId),
        isEmpty,
      );
    });

    test('honours maxDocuments cap', () async {
      final firestore = FakeFirebaseFirestore();
      for (var i = 0; i < 5; i++) {
        await _userRecipes(firestore, _userId).doc('r$i').set({'title': 'r$i'});
      }
      final export = await _ops(
        firestore,
      ).exportPersonalRecipesByUser(_userId, maxDocuments: 3);
      expect(export, hasLength(3));
    });

    test('validates ownership with current user vs target user', () async {
      final firestore = FakeFirebaseFirestore();
      final calls = <_OwnershipCall>[];
      await _ops(
        firestore,
        currentUid: _userId,
        ownershipCalls: calls,
      ).exportPersonalRecipesByUser(_userId);

      final call = calls.single;
      expect(call.currentUserId, _userId);
      expect(call.resourceOwnerId, _userId);
      expect(call.resourceType, 'recipes');
    });

    test('does not read when ownership validation throws', () async {
      final firestore = FakeFirebaseFirestore();
      await _userRecipes(firestore, _userId).doc('r1').set({'leak': true});

      await expectLater(
        () => _ops(
          firestore,
          ownershipThrows: true,
        ).exportPersonalRecipesByUser(_userId),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('exportTopLevelRecipesByOwner', () {
    test('returns only docs whose userId field matches the owner', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('recipes').doc('mine-1').set({
        'userId': _userId,
        'title': 'Pasta',
      });
      await firestore.collection('recipes').doc('mine-2').set({
        'userId': _userId,
        'title': 'Soup',
      });
      // not mine — must be excluded
      await firestore.collection('recipes').doc('theirs').set({
        'userId': 'bob',
        'title': 'Bob recipe',
      });

      final export = await _ops(
        firestore,
      ).exportTopLevelRecipesByOwner(_userId);

      expect(export, hasLength(2));
      expect(export.map((e) => e['id']).toSet(), {'mine-1', 'mine-2'});
    });

    test('returns empty list when no docs match', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('recipes').doc('x').set({'userId': 'bob'});
      expect(
        await _ops(firestore).exportTopLevelRecipesByOwner(_userId),
        isEmpty,
      );
    });

    test('honours maxDocuments cap', () async {
      final firestore = FakeFirebaseFirestore();
      for (var i = 0; i < 5; i++) {
        await firestore.collection('recipes').doc('r$i').set({
          'userId': _userId,
          'title': 'r$i',
        });
      }
      final export = await _ops(
        firestore,
      ).exportTopLevelRecipesByOwner(_userId, maxDocuments: 2);
      expect(export, hasLength(2));
    });

    test('validates ownership before querying', () async {
      final firestore = FakeFirebaseFirestore();
      final calls = <_OwnershipCall>[];
      await _ops(
        firestore,
        ownershipCalls: calls,
      ).exportTopLevelRecipesByOwner(_userId);
      expect(calls.single.resourceOwnerId, _userId);
      expect(calls.single.resourceType, 'recipes');
    });

    test('throws (no data leak) when ownership check rejects', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('recipes').doc('x').set({
        'userId': _userId,
        'leak': true,
      });

      await expectLater(
        () => _ops(
          firestore,
          ownershipThrows: true,
        ).exportTopLevelRecipesByOwner(_userId),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });
}
