/// BUT-2354: the Art. 15 section for shopping-list templates, which the
/// deletion cascade erases. It must hold the user's own templates, public and
/// private, and drop other people's display names from the copied items.
library;

import 'dart:convert';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/shopping_template_export.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

const _me = 'user-me';
const _other = 'user-other';

/// Throws from the template read, so the failure envelope can be checked.
class _FailingExports extends FirebaseDataExportRepository {
  _FailingExports({required super.authRepository})
    : super(firestore: FakeFirebaseFirestore());

  @override
  Future<List<Map<String, dynamic>>> exportShoppingListTemplates(
    String userId, {
    int maxDocuments = 500,
  }) async => throw StateError('permission-denied for $userId');
}

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeAuthRepository auth;
  late ShoppingTemplateExport export;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = FakeAuthRepository();
    auth.setAuthState(
      user: FakeUser(uid: _me),
      userId: _me,
      isAuthenticated: true,
    );
    export = ShoppingTemplateExport(
      FirebaseDataExportRepository(firestore: firestore, authRepository: auth),
    );
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  Future<void> seed(String id, Map<String, dynamic> data) => firestore
      .collection(FirestoreCollections.shoppingListTemplates)
      .doc(id)
      .set(data);

  List<Map<String, dynamic>> rowsOf(Map<String, dynamic> section) =>
      (section['shopping_list_templates'] as List).cast<Map<String, dynamic>>();

  test('exports the user\'s public and private templates only', () async {
    await seed('t-public', {
      'ownerId': _me,
      'name': 'Veckohandling',
      'isPublic': true,
    });
    await seed('t-private', {
      'ownerId': _me,
      'name': 'Fest',
      'isPublic': false,
    });
    await seed('t-other', {
      'ownerId': _other,
      'name': 'Deras mall',
      'isPublic': true,
    });

    final section = await export.export(_me);

    expect(section.containsKey('error'), isFalse);
    expect(section['total_count'], 2);
    expect(rowsOf(section).map((r) => r['template_id']).toSet(), {
      't-public',
      't-private',
    });
  });

  test(
    'drops other people\'s names on items and keeps the user\'s own',
    () async {
      await seed('t1', {
        'ownerId': _me,
        'ownerDisplayName': 'Jag',
        'name': 'Från delad lista',
        'isPublic': true,
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(1760000000000),
        'items': [
          {
            'id': 'i1',
            'name': 'Mjölk',
            'addedByUserId': _other,
            'addedByDisplayName': 'Olle',
            'purchasedByUserId': _me,
            'purchasedByDisplayName': 'Jag',
            'addedAt': Timestamp.fromMillisecondsSinceEpoch(1760000000000),
          },
        ],
      });

      final section = await export.export(_me);
      final data = (rowsOf(section).single['data'] as Map)
          .cast<String, dynamic>();
      final item = ((data['items'] as List).single as Map)
          .cast<String, dynamic>();

      expect(data['ownerDisplayName'], 'Jag');
      expect(item.containsKey('addedByDisplayName'), isFalse);
      expect(item['addedByUserId'], _other);
      expect(item['purchasedByDisplayName'], 'Jag');
      expect(jsonEncode(section), isNot(contains('Olle')));
      expect(section['data_minimisation'], contains('display names'));
      // Templates always carry `createdAt`; a raw Timestamp would abort the
      // whole bundle at jsonEncode.
      expect(() => jsonEncode(section), returnsNormally);
    },
  );

  test('an items field that is not a list is left out', () async {
    await seed('t-odd', {
      'ownerId': _me,
      'name': 'Udda',
      'isPublic': false,
      'items': {'addedByUserId': _other, 'addedByDisplayName': 'Olle'},
    });

    final section = await export.export(_me);
    final data = (rowsOf(section).single['data'] as Map)
        .cast<String, dynamic>();

    expect(data.containsKey('items'), isFalse);
    expect(data['name'], 'Udda');
  });

  test(
    'a failed read returns a stable error code, not the exception',
    () async {
      final failing = ShoppingTemplateExport(
        _FailingExports(authRepository: auth),
      );

      final section = await failing.export(_me);

      expect(section['error_code'], 'shopping-list-templates-export-failed');
      expect(jsonEncode(section), isNot(contains(_me)));
    },
  );
}
