/// Unit tests for [ModerationAppealsExportManager] (BUT-2353).
///
/// The section is the client half of the `exportModerationAppeals` callable.
/// Its contract: a success lists role, text, dates and status only; ANY failure
/// becomes a section `error` + `error_code` and is never thrown, so the rest of
/// the Art. 15 bundle still ships.
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/account/export/moderation_appeals_export_manager.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock
    implements HttpsCallableResult<Map<dynamic, dynamic>> {}

void main() {
  late _MockFunctions functions;
  late _MockCallable callable;
  late ModerationAppealsExportManager manager;

  setUpAll(() {
    registerFallbackValue(HttpsCallableOptions());
  });

  setUp(() {
    functions = _MockFunctions();
    callable = _MockCallable();
    when(
      () => functions.httpsCallable(any(), options: any(named: 'options')),
    ).thenReturn(callable);
    manager = ModerationAppealsExportManager(functions: functions);
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

  test('calls the callable by name and sends no payload', () async {
    respond({'appeals': const <dynamic>[]});

    final section = await manager.exportModerationAppeals();

    expect(section['appeals'], isEmpty);
    expect(section['total'], 0);
    expect(section.containsKey('error'), isFalse);

    verify(
      () => functions.httpsCallable(
        'exportModerationAppeals',
        options: any(named: 'options'),
      ),
    ).called(1);
    verify(() => callable.call<Map<dynamic, dynamic>>()).called(1);
  });

  test('lists role, text, dates and status for each row', () async {
    respond({
      'appeals': [
        {
          'role': 'owner',
          'text': 'Receptet är mitt eget',
          'createdAt': '2026-10-11T08:00:00.000Z',
          'status': 'upheld',
          'answeredAt': '2026-10-12T08:00:00.000Z',
        },
        {
          'role': 'reporter',
          'text': 'Det bryter mot reglerna',
          'createdAt': null,
          'status': null,
          'answeredAt': null,
        },
      ],
      'gdprArticle': 'Article 15 - Right of Access',
    });

    final section = await manager.exportModerationAppeals();

    expect(section['appeals'], [
      {
        'role': 'owner',
        'text': 'Receptet är mitt eget',
        'created_at': '2026-10-11T08:00:00.000Z',
        'status': 'upheld',
        'answered_at': '2026-10-12T08:00:00.000Z',
      },
      {
        'role': 'reporter',
        'text': 'Det bryter mot reglerna',
        'created_at': null,
        'status': null,
        'answered_at': null,
      },
    ]);
    expect(section['total'], 2);
    expect(section['note'], ModerationAppealsExportManager.note);
    expect(section.containsKey('error'), isFalse);
  });

  test('a response without appeals fails the section, never reads as '
      'none', () async {
    respond({'gdprArticle': 'Article 15 - Right of Access'});

    final section = await manager.exportModerationAppeals();

    expect(section.containsKey('appeals'), isFalse);
    expect(section['error_code'], 'moderation-appeals-export-failed');
  });

  final failures = <String, (Object, String)>{
    'the decline': (
      FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'too many',
        details: const {'error_code': 'moderation-appeals-too-large'},
      ),
      'moderation-appeals-too-large',
    ),
    'a callable not deployed yet': (
      FirebaseFunctionsException(code: 'not-found', message: 'x'),
      'moderation-appeals-not-found',
    ),
    'a rate-limit refusal': (
      FirebaseFunctionsException(code: 'resource-exhausted', message: 'x'),
      'moderation-appeals-resource-exhausted',
    ),
    'an unrecognised code': (
      FirebaseFunctionsException(code: 'Weird Code', message: 'x'),
      'moderation-appeals-unknown',
    ),
    'a timeout': (TimeoutException('slow'), 'moderation-appeals-timeout'),
    'anything else': (StateError('boom'), 'moderation-appeals-export-failed'),
  };

  for (final MapEntry(key: name, value: (error, code)) in failures.entries) {
    test('$name becomes error_code $code and the message is not '
        'forwarded', () async {
      fail(error);

      final section = await manager.exportModerationAppeals();

      expect(section['error_code'], code);
      expect(section['error'], 'This section could not be exported.');
      expect(section.containsKey('appeals'), isFalse);
    });
  }
}
