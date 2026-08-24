/// Unit tests for RecipeGdprExportOperations.
///
/// The module exposes ONE BUT-501 GDPR Article 20 export path: the per-user
/// subcollection `users/{userId}/recipes`. It validates ownership before
/// reading and honours the `maxDocuments` cap; both are driven end-to-end here
/// against `FakeFirebaseFirestore`.
///
/// A second method used to read a top-level `recipes` collection as a "legacy
/// shape", and the five tests for it passed happily because `FakeFirebaseFirestore`
/// evaluates no rules — while in production that collection has no `match` block,
/// so the real query was denied and took the whole recipes section of the export
/// down with it (BUT-1801). A fake-backed test is evidence about the query, never
/// about the permission.
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
}
