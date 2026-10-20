import 'dart:io';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('db_encryption_test');
    path = '${dir.path}/enc.sqlite';
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Database open(String key) {
    final db = sqlite3.open(path);
    configureDatabaseEncryption(db, key);
    return db;
  }

  test('the cipher library is the one loaded', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    expect(db.select('PRAGMA cipher'), isNotEmpty);
  });

  test('the file on disk is not plain SQLite', () {
    final db = open('key-one');
    db.execute('CREATE TABLE t (v TEXT)');
    db.execute("INSERT INTO t VALUES ('secret-recipe')");
    db.close();

    final bytes = File(path).readAsBytesSync();
    expect(String.fromCharCodes(bytes.take(15)), isNot('SQLite format 3'));
    expect(String.fromCharCodes(bytes), isNot(contains('secret-recipe')));
  });

  test('the right key reads the data back', () {
    open('key-one')
      ..execute('CREATE TABLE t (v TEXT)')
      ..execute("INSERT INTO t VALUES ('a')")
      ..close();

    final db = open('key-one');
    addTearDown(db.close);
    expect(db.select('SELECT v FROM t').single['v'], 'a');
  });

  test('a wrong key is refused', () {
    open('key-one')
      ..execute('CREATE TABLE t (v TEXT)')
      ..close();

    final db = open('key-two');
    addTearDown(db.close);
    expect(() => db.select('SELECT * FROM t'), throwsA(isA<SqliteException>()));
  });

  // Written by SQLCipher 4.12 with the key below (python sqlcipher3); this is
  // the file format devices that ran the old build already hold.
  test('a database file written by real SQLCipher 4 still opens', () {
    File('test/fixtures/db/sqlcipher4_fixture.sqlite').copySync(path);

    final db = open('fixture-key');
    addTearDown(db.close);
    expect(db.select('SELECT v FROM t').single['v'], 'from-sqlcipher-4');
  });
}
