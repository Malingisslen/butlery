// A transaction whose handler throws an error that a caller acts on goes
// through `runTransactionKeepingHandlerError` (or `runTransactionWithNativeErrors`
// for the platform's own budget): on the web the Firestore plugin replaces the
// handler's error with a plain one, so the caller's typed catch never matches.
// Every other direct `runTransaction` in `lib/` is listed here with the reason
// its handler needs none, and a new one without an entry fails this test.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _boundary =
    'lib/repositories/firebase/modules/firestore_transaction_boundary.dart';

/// file -> (direct calls, why the handler's own errors are not acted on)
const _direct = <String, (int, String)>{
  'lib/core/mixins/firebase_service_mixin.dart': (
    1,
    'executeTransaction has no caller; it takes its handler from the caller',
  ),
  'lib/repositories/firebase/base_shared_content_repository.dart': (
    1,
    'decrementUnreadCounter: the handler throws nothing and the catch logs',
  ),
  'lib/repositories/firebase/friends/friend_relationship_repository.dart': (
    2,
    'the handlers throw nothing and addMutualFriends has no production '
        'caller',
  ),
  'lib/repositories/firebase/modules/message_poll_mutation_module.dart': (
    2,
    'vote and close handlers throw nothing; callers log and rethrow',
  ),
  'lib/services/family/family_rating_service.dart': (
    1,
    'the catch logs',
  ),
  'lib/services/import/import_rate_limiter.dart': (
    1,
    'the handler throws nothing',
  ),
  'lib/services/moderation/report_takedowns.dart': (
    1,
    'the handler answers with a bool and throws nothing',
  ),
  'lib/services/unified/operations/modules/comment_reactions_system.dart': (
    1,
    'the handler returns early and throws nothing; the catch answers false',
  ),
};

String _code(String source) => source
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'(?<!:)//[^\n]*'), '');

final _call = RegExp(r'\brunTransaction\s*[(<]');

int _countIn(String source) => _call.allMatches(_code(source)).length;

Map<String, int> _counts() {
  final counts = <String, int>{};
  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    final path = file.path.replaceAll(r'\', '/');
    if (path == _boundary) continue;
    final n = _countIn(file.readAsStringSync());
    if (n > 0) counts[path] = n;
  }
  return counts;
}

void main() {
  test('no unlisted code calls runTransaction directly', () {
    expect(_counts(), {for (final e in _direct.entries) e.key: e.value.$1});
  });

  test('the pattern finds the spellings the code uses', () {
    expect(_countIn('await firestore.runTransaction((tx) async {})'), 1);
    expect(_countIn('firestore.runTransaction<bool>((tx) async {})'), 1);
    expect(_countIn('_repo.firestore.runTransaction(\n(t) async {})'), 1);
    expect(
      _countIn('a.runTransaction((t) async {}); b.runTransaction<int>((t) {})'),
      2,
    );
  });

  test('the pattern leaves the helpers and comments alone', () {
    expect(_countIn('runTransactionKeepingHandlerError<int>(run, h)'), 0);
    expect(_countIn('runTransactionWithNativeErrors<int>(fs, h)'), 0);
    expect(_countIn('// firestore.runTransaction(h)'), 0);
    expect(_countIn('/* firestore.runTransaction(h) */'), 0);
  });

  test('every listed exception gives a reason', () {
    for (final e in _direct.entries) {
      expect(e.value.$2.trim(), isNotEmpty, reason: e.key);
    }
  });
}
