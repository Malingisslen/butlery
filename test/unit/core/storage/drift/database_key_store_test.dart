// The database key is read, retried and reported, and never silently replaced
// by one the existing file cannot be opened with.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:butlery/core/storage/drift/database_key_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStore implements SecretStore {
  String? value;
  int readFailures = 0;
  bool failWrites = false;
  int reads = 0;
  int writes = 0;

  @override
  Future<String?> read(String name) async {
    reads++;
    if (readFailures > 0) {
      readFailures--;
      throw StateError('keystore busy: secret-from-platform');
    }
    return value;
  }

  @override
  Future<void> write(String name, String value) async {
    writes++;
    if (failWrites) throw StateError('keystore full');
    this.value = value;
  }
}

void main() {
  late Directory dir;
  late File file;
  late _FakeStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('db_key_store_test');
    file = File('${dir.path}/butlery_drift_encrypted.sqlite');
    store = _FakeStore();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  DatabaseKeyStore keys() => DatabaseKeyStore(
    store: store,
    retryDelay: Duration.zero,
    random: Random(1),
  );

  test('first start with no file makes and stores a key', () async {
    final key = await keys().keyFor(file);

    expect(base64Url.decode(key), hasLength(32));
    expect(store.value, key);
    expect(store.writes, 1);
  });

  test('an existing key is returned and nothing is written', () async {
    store.value = 'existing-key';
    file.writeAsBytesSync([1, 2, 3]);

    expect(await keys().keyFor(file), 'existing-key');
    expect(store.writes, 0);
  });

  test(
    'a read that fails once is retried and the same key comes back',
    () async {
      store.value = 'existing-key';
      store.readFailures = 2;
      file.writeAsBytesSync([1, 2, 3]);

      expect(await keys().keyFor(file), 'existing-key');
      expect(store.reads, 3);
      expect(store.writes, 0);
    },
  );

  test('a read that keeps failing is reported, not replaced', () async {
    store.value = 'existing-key';
    store.readFailures = 99;
    file.writeAsBytesSync([1, 2, 3]);

    await expectLater(
      keys().keyFor(file),
      throwsA(isA<DatabaseKeyUnavailable>()),
    );
    expect(store.writes, 0);
    expect(store.value, 'existing-key');
    expect(file.existsSync(), isTrue);
  });

  test('a missing key next to an existing file is reported as lost, and '
      'nothing is overwritten', () async {
    file.writeAsBytesSync([1, 2, 3]);

    await expectLater(keys().keyFor(file), throwsA(isA<DatabaseKeyLost>()));
    expect(store.writes, 0);
    expect(file.existsSync(), isTrue);
  });

  test('an empty leftover file does not count as data', () async {
    file.writeAsBytesSync([]);

    expect(await keys().keyFor(file), isNotEmpty);
  });

  test('a first start that cannot store its key opens no database', () async {
    store.failWrites = true;

    await expectLater(
      keys().keyFor(file),
      throwsA(isA<DatabaseKeyUnavailable>()),
    );
  });
}
