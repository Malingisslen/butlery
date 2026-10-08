/// Unit tests for [SharedResidueExportManager] (BUT-1747).
///
/// The section is the client half of the `exportSharedResidue` callable. Its
/// contract: a success carries the callable's three keys; ANY failure becomes
/// a section `error` + `error_code` and is never thrown, so the rest of the
/// Art. 15 bundle still ships.
library;

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/account/export/shared_residue_export_manager.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock
    implements HttpsCallableResult<Map<dynamic, dynamic>> {}

void main() {
  late _MockFunctions functions;
  late _MockCallable callable;
  late SharedResidueExportManager manager;

  setUpAll(() {
    registerFallbackValue(HttpsCallableOptions());
  });

  setUp(() {
    functions = _MockFunctions();
    callable = _MockCallable();
    when(
      () => functions.httpsCallable(any(), options: any(named: 'options')),
    ).thenReturn(callable);
    manager = SharedResidueExportManager(functions: functions);
  });

  void respond(Map<dynamic, dynamic> data) {
    final result = _MockResult();
    when(() => result.data).thenReturn(data);
    when(
      () => callable.call<Map<dynamic, dynamic>>(any()),
    ).thenAnswer((_) async => result);
  }

  void fail(Object error) {
    when(
      () => callable.call<Map<dynamic, dynamic>>(any()),
    ).thenThrow(error);
  }

  Map<dynamic, dynamic> response() => <dynamic, dynamic>{
    'shared_lists_left': [
      {
        'id': 'list-1',
        'name': 'Veckohandling',
        'ownerId': 'owner-uid',
        'recorded_as_contributor': true,
        'items': [
          {'id': 'i1', 'name': 'Mjölk', 'addedByUserId': 'me'},
        ],
      },
    ],
    'shared_content_items': [
      {
        'shareId': 'share-1',
        'itemId': 'row-1',
        'item': {'name': 'Bröd', 'addedByUserId': 'me'},
      },
    ],
    'known_gaps': ['left_list_not_on_trail: ...'],
    'gdprArticle': 'Article 15 - Right of Access',
  };

  test('a success carries the three callable keys, the minimisation note and '
      'no error', () async {
    respond(response());

    final section = await manager.exportSharedListsLeft();

    expect(section.keys.toSet(), {
      'shared_lists_left',
      'shared_content_items',
      'known_gaps',
      'data_minimisation',
    });
    expect(
      section['data_minimisation'],
      'From shared lists you have left, only the items that name you are '
      "included, and the list owner's user ID is kept. On every item in this "
      "section, other people's user IDs and display names are removed.",
    );
    final list = (section['shared_lists_left'] as List).single as Map;
    expect(list['id'], 'list-1');
    expect(list['recorded_as_contributor'], isTrue);
    expect(((list['items'] as List).single as Map)['name'], 'Mjölk');
    final row = (section['shared_content_items'] as List).single as Map;
    expect(row['shareId'], 'share-1');
    expect((row['item'] as Map)['name'], 'Bröd');
    expect(section['known_gaps'], ['left_list_not_on_trail: ...']);

    verify(
      () => functions.httpsCallable(
        'exportSharedResidue',
        options: any(named: 'options'),
      ),
    ).called(1);
    // The callable reads the uid from request.auth; a payload is never sent.
    verify(() => callable.call<Map<dynamic, dynamic>>(null)).called(1);
  });

  test('a success is JSON-encodable even if a value is a Timestamp', () async {
    respond({
      ...response(),
      'shared_lists_left': [
        {'id': 'l', 'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10))},
      ],
    });

    final section = await manager.exportSharedListsLeft();

    expect(() => jsonEncode(section), returnsNormally);
    expect(
      ((section['shared_lists_left'] as List).single as Map)['createdAt'],
      startsWith('2026-10-01T00:00:00'),
    );
  });

  test('a response missing a key fails the section rather than reading as '
      'empty', () async {
    respond({...response()}..remove('shared_lists_left'));

    final section = await manager.exportSharedListsLeft();

    expect(section['error_code'], 'shared-lists-left-export-failed');
    expect(section.containsKey('shared_lists_left'), isFalse);
  });

  final cases = <String, (Object, String)>{
    'unavailable (transient)': (
      FirebaseFunctionsException(code: 'unavailable', message: 'down'),
      'shared-lists-left-unavailable',
    ),
    'failed-precondition with the decline token': (
      FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'Shared shopping data is too large to export.',
        details: const {'error_code': 'shared-residue-too-large'},
      ),
      'shared-residue-too-large',
    ),
    'failed-precondition without the decline token': (
      FirebaseFunctionsException(code: 'failed-precondition', message: 'x'),
      'shared-lists-left-failed-precondition',
    ),
    'unauthenticated': (
      FirebaseFunctionsException(code: 'unauthenticated', message: 'x'),
      'shared-lists-left-unauthenticated',
    ),
    'a client-side timeout': (
      TimeoutException('callable'),
      'shared-lists-left-timeout',
    ),
    'anything else': (StateError('boom'), 'shared-lists-left-export-failed'),
    'a code outside the lower-case token shape': (
      FirebaseFunctionsException(code: 'Bad code: users/x', message: 'x'),
      'shared-lists-left-unknown',
    ),
  };

  for (final MapEntry(key: name, value: (error, code)) in cases.entries) {
    test('$name becomes section error_code $code, never a throw', () async {
      fail(error);

      final section = await manager.exportSharedListsLeft();

      expect(section['error_code'], code);
      expect(
        section['error'],
        isA<String>(),
        reason:
            'the whole section failed, so DataExportService must say "could '
            'not be exported" rather than "may be incomplete"',
      );
      expect(section.containsKey('shared_lists_left'), isFalse);
      expect(section.containsKey('data_minimisation'), isFalse);
    });
  }

  test('the exception text never reaches the section', () async {
    const foreignUid = 'uid-of-another-person-9f2e45';
    fail(
      FirebaseFunctionsException(
        code: 'internal',
        message: 'failed reading shared_content/s_$foreignUid/items',
        details: const {'path': 'users/$foreignUid'},
      ),
    );

    final section = await manager.exportSharedListsLeft();

    expect(section['error_code'], 'shared-lists-left-internal');
    expect(jsonEncode(section), isNot(contains(foreignUid)));
  });
}
