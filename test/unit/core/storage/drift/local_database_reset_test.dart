/// "Börja om med tom lokal data" deletes the encrypted database and SQLite's
/// side files, and nothing else in the documents directory.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:butlery/core/storage/drift/local_database_reset.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('local_db_reset_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => dir.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File at(String name) => File(p.join(dir.path, name));

  test('the file name is the one the database opens', () {
    expect(encryptedDatabaseFileName, 'butlery_drift_encrypted.sqlite');
  });

  test('deletes the database and its side files, and leaves others', () async {
    final targets = [
      for (final suffix in const ['', '-wal', '-shm', '-journal'])
        at('$encryptedDatabaseFileName$suffix'),
    ];
    final bystanders = [at('butlery_drift.sqlite'), at('notes.txt')];
    for (final f in [...targets, ...bystanders]) {
      f.writeAsStringSync('x');
    }

    await resetLocalDatabase();

    for (final f in targets) {
      expect(f.existsSync(), isFalse, reason: f.path);
    }
    for (final f in bystanders) {
      expect(f.existsSync(), isTrue, reason: f.path);
    }
  });

  test('with nothing to delete it completes', () async {
    await resetLocalDatabase();
    await resetLocalDatabase();
    expect(dir.listSync(), isEmpty);
  });
}
