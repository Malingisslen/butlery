// The web build compiles OfflineService against offline_user_storage_stub.dart
// (a conditional import), so a public method added to the native class and not
// to the stub breaks the web build while analyze and every unit test stay
// green (BUT-2294 PR 7).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Set<String> _publicMembers(String path) {
  final member = RegExp(r'^  (?!static )[A-Za-z][\w<>?, \[\]]*? (\w+)\(');
  final getter = RegExp(r'^  [A-Za-z][\w<>?, \[\]]*? get (\w+)\b');
  final names = <String>{};
  for (final line in File(path).readAsLinesSync()) {
    final name =
        getter.firstMatch(line)?.group(1) ?? member.firstMatch(line)?.group(1);
    if (name != null && name != 'Function' && !name.startsWith('_')) {
      names.add(name);
    }
  }
  return names;
}

void main() {
  test('the web stub of OfflineUserStorage has every public method of the '
      'native class', () {
    final native = _publicMembers(
      'lib/services/offline/offline_user_storage.dart',
    );
    final stub = _publicMembers(
      'lib/services/offline/offline_user_storage_stub.dart',
    );

    expect(native, containsAll(['hasQueuedGroup', 'queueImageGroupForUser']));
    expect(native.difference(stub), isEmpty);
  });
}
