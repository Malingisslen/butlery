/// Unit tests for [ErasureResidueExportManager] (BUT-2414).
///
/// The section is the client half of the `exportErasureResidue` callable. Its
/// contract: a success carries the callable's named sections and known gaps;
/// ANY failure becomes a section `error` + `error_code` and is never thrown,
/// so the rest of the Art. 15 bundle still ships.
library;

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/account/export/erasure_residue_export_manager.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock
    implements HttpsCallableResult<Map<dynamic, dynamic>> {}

void main() {
  late _MockFunctions functions;
  late _MockCallable callable;
  late ErasureResidueExportManager manager;

  setUpAll(() {
    registerFallbackValue(HttpsCallableOptions());
  });

  setUp(() {
    functions = _MockFunctions();
    callable = _MockCallable();
    when(
      () => functions.httpsCallable(any(), options: any(named: 'options')),
    ).thenReturn(callable);
    manager = ErasureResidueExportManager(functions: functions);
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
    'sections': <dynamic, dynamic>{
      'tag_overrides_log': {
        'rows': [
          {'id': 't1', 'tag': 'gluten', 'direction': 'remove'},
        ],
      },
      'messages_in_left_conversations': {
        'error_code': 'erasure-residue-too-large',
      },
    },
    'known_gaps': ['a-gap'],
    'gdprArticle': 'Article 15 - Right of Access',
  };

  test('a success carries every named section, a failed one included, and '
      'the known gaps', () async {
    respond(response());

    final section = await manager.exportErasureResidue();

    expect(section.keys.toSet(), {'sections', 'known_gaps', 'error_code'});
    // A failed named section marks the whole one partial, without `error`.
    expect(section['error_code'], ErasureResidueExportManager.partialErrorCode);
    final sections = section['sections'] as Map;
    final row =
        ((sections['tag_overrides_log'] as Map)['rows'] as List).single as Map;
    expect(row['tag'], 'gluten');
    expect(
      (sections['messages_in_left_conversations'] as Map)['error_code'],
      'erasure-residue-too-large',
    );
    expect(section['known_gaps'], ['a-gap']);

    verify(
      () => functions.httpsCallable(
        'exportErasureResidue',
        options: any(named: 'options'),
      ),
    ).called(1);
    // The callable reads the uid from request.auth; a payload is never sent.
    verify(() => callable.call<Map<dynamic, dynamic>>(null)).called(1);
  });

  test(
    'a success with every named section intact carries no error_code',
    () async {
      respond({
        ...response(),
        'sections': {
          'guest_quota': {'rows': <dynamic>[]},
        },
      });

      final section = await manager.exportErasureResidue();

      expect(section.keys.toSet(), {'sections', 'known_gaps'});
    },
  );

  test('a success is JSON-encodable even if a value is a Timestamp', () async {
    respond({
      ...response(),
      'sections': {
        'guest_quota': {
          'rows': [
            {'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10))},
          ],
        },
      },
    });

    final section = await manager.exportErasureResidue();

    expect(() => jsonEncode(section), returnsNormally);
  });

  test('a response missing a key fails the section rather than reading as '
      'empty', () async {
    respond({...response()}..remove('sections'));

    final section = await manager.exportErasureResidue();

    expect(section['error_code'], 'erasure-residue-export-failed');
    expect(section.containsKey('sections'), isFalse);
  });

  final cases = <String, (Object, String)>{
    'unavailable': (
      FirebaseFunctionsException(code: 'unavailable', message: 'down'),
      'erasure-residue-unavailable',
    ),
    'a client-side timeout': (
      TimeoutException('callable'),
      'erasure-residue-timeout',
    ),
    'anything else': (StateError('boom'), 'erasure-residue-export-failed'),
    'a code outside the lower-case token shape': (
      FirebaseFunctionsException(code: 'Bad code: users/x', message: 'x'),
      'erasure-residue-unknown',
    ),
  };

  for (final MapEntry(key: name, value: (error, code)) in cases.entries) {
    test('$name becomes section error_code $code, never a throw', () async {
      fail(error);

      final section = await manager.exportErasureResidue();

      expect(section['error_code'], code);
      expect(section['error'], isA<String>());
      expect(section.containsKey('sections'), isFalse);
    });
  }

  test('the exception text never reaches the section', () async {
    const foreignUid = 'uid-of-another-person-9f2e45';
    fail(
      FirebaseFunctionsException(
        code: 'internal',
        message: 'failed reading users/$foreignUid',
      ),
    );

    final section = await manager.exportErasureResidue();

    expect(jsonEncode(section).contains(foreignUid), isFalse);
  });
}
