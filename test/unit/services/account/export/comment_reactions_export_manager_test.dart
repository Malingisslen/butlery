/// Unit tests for [CommentReactionsExportManager] (BUT-2318, BUT-2398).
///
/// The comment and message sections are the client half of the
/// `exportCommentReactions` callable. Their contract: a success lists the id
/// and reaction only; ANY failure becomes a section `error` + `error_code` and
/// is never thrown, so the rest of the Art. 15 bundle still ships.
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/account/export/comment_reactions_export_manager.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock
    implements HttpsCallableResult<Map<dynamic, dynamic>> {}

void main() {
  late _MockFunctions functions;
  late _MockCallable callable;
  late CommentReactionsExportManager manager;

  setUpAll(() {
    registerFallbackValue(HttpsCallableOptions());
  });

  setUp(() {
    functions = _MockFunctions();
    callable = _MockCallable();
    when(
      () => functions.httpsCallable(any(), options: any(named: 'options')),
    ).thenReturn(callable);
    manager = CommentReactionsExportManager(functions: functions);
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
    respond({'reactions': const <dynamic>[]});

    final section = (await manager.exportReactions()).comments;

    expect(section['reactions'], isEmpty);
    expect(section['total'], 0);
    expect(section.containsKey('error'), isFalse);

    verify(
      () => functions.httpsCallable(
        'exportCommentReactions',
        options: any(named: 'options'),
      ),
    ).called(1);
    verify(() => callable.call<Map<dynamic, dynamic>>()).called(1);
  });

  test('lists comment id and reaction for each row', () async {
    respond({
      'reactions': [
        {'commentId': 'c1', 'key': 'heart'},
        {'commentId': 'c2', 'key': 'yum'},
      ],
      'gdprArticle': 'Article 15 - Right of Access',
    });

    final section = (await manager.exportReactions()).comments;

    expect(section['reactions'], [
      {'comment_id': 'c1', 'reaction': 'heart'},
      {'comment_id': 'c2', 'reaction': 'yum'},
    ]);
    expect(section['total'], 2);
    expect(section['note'], CommentReactionsExportManager.note);
    expect(section.containsKey('error'), isFalse);
  });

  test('a response without reactions fails the section, never reads as '
      'none', () async {
    respond({'gdprArticle': 'Article 15 - Right of Access'});

    final section = (await manager.exportReactions()).comments;

    expect(section.containsKey('reactions'), isFalse);
    expect(section['error_code'], 'comment-reactions-export-failed');
  });

  final failures = <String, (Object, String)>{
    'the decline': (
      FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'too many',
        details: const {'error_code': 'comment-reactions-too-large'},
      ),
      'comment-reactions-too-large',
    ),
    'a callable not deployed yet': (
      FirebaseFunctionsException(code: 'not-found', message: 'x'),
      'comment-reactions-not-found',
    ),
    'a rate-limit refusal': (
      FirebaseFunctionsException(code: 'resource-exhausted', message: 'x'),
      'comment-reactions-resource-exhausted',
    ),
    'an unrecognised code': (
      FirebaseFunctionsException(code: 'Weird Code', message: 'x'),
      'comment-reactions-unknown',
    ),
    'a timeout': (TimeoutException('slow'), 'comment-reactions-timeout'),
    'anything else': (StateError('boom'), 'comment-reactions-export-failed'),
  };

  for (final MapEntry(key: name, value: (error, code)) in failures.entries) {
    test('$name becomes error_code $code and the message is not '
        'forwarded', () async {
      fail(error);

      final section = (await manager.exportReactions()).comments;

      expect(section['error_code'], code);
      expect(section['error'], 'This section could not be exported.');
      expect(section.containsKey('reactions'), isFalse);
    });
  }

  group('BUT-2398: message reactions', () {
    test('lists message id and reaction for each row from the same '
        'call', () async {
      respond({
        'reactions': [
          {'commentId': 'c1', 'key': 'heart'},
        ],
        'messageReactions': [
          {'messageId': 'm1', 'key': 'fire'},
          {'messageId': 'm2', 'key': 'yum'},
        ],
        'gdprArticle': 'Article 15 - Right of Access',
      });

      final sections = await manager.exportReactions();

      expect(sections.messages['reactions'], [
        {'message_id': 'm1', 'reaction': 'fire'},
        {'message_id': 'm2', 'reaction': 'yum'},
      ]);
      expect(sections.messages['total'], 2);
      expect(
        sections.messages['note'],
        CommentReactionsExportManager.messageNote,
      );
      expect(sections.messages.containsKey('error'), isFalse);
      expect(sections.comments['reactions'], [
        {'comment_id': 'c1', 'reaction': 'heart'},
      ]);
      verify(() => callable.call<Map<dynamic, dynamic>>()).called(1);
    });

    test('a response without messageReactions fails only the message '
        'section, never reads as none', () async {
      respond({
        'reactions': [
          {'commentId': 'c1', 'key': 'heart'},
        ],
      });

      final sections = await manager.exportReactions();

      expect(sections.messages.containsKey('reactions'), isFalse);
      expect(
        sections.messages['error_code'],
        'message-reactions-export-failed',
      );
      expect(sections.comments['total'], 1);
      expect(sections.comments.containsKey('error'), isFalse);
    });

    test('a malformed message row fails only the message section', () async {
      respond({
        'reactions': const <dynamic>[],
        'messageReactions': [
          {'messageId': 7, 'key': 'fire'},
        ],
      });

      final sections = await manager.exportReactions();

      expect(
        sections.messages['error_code'],
        'message-reactions-export-failed',
      );
      expect(sections.comments.containsKey('error'), isFalse);
    });

    final messageFailures = <String, (Object, String)>{
      'the message decline': (
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'too many',
          details: const {'error_code': 'message-reactions-too-large'},
        ),
        'message-reactions-too-large',
      ),
      'the comment decline': (
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'too many',
          details: const {'error_code': 'comment-reactions-too-large'},
        ),
        'comment-reactions-too-large',
      ),
      'a rate-limit refusal': (
        FirebaseFunctionsException(code: 'resource-exhausted', message: 'x'),
        'message-reactions-resource-exhausted',
      ),
      'a timeout': (TimeoutException('slow'), 'message-reactions-timeout'),
      'anything else': (StateError('boom'), 'message-reactions-export-failed'),
    };

    for (final MapEntry(key: name, value: (error, code))
        in messageFailures.entries) {
      test('$name gives the message section error_code $code', () async {
        fail(error);

        final section = (await manager.exportReactions()).messages;

        expect(section['error_code'], code);
        expect(section['error'], 'This section could not be exported.');
        expect(section.containsKey('reactions'), isFalse);
      });
    }

    test('the message decline token passes through to the comment section '
        'too, since one call carries both', () async {
      fail(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'too many',
          details: const {'error_code': 'message-reactions-too-large'},
        ),
      );

      final sections = await manager.exportReactions();

      expect(sections.comments['error_code'], 'message-reactions-too-large');
    });
  });
}
