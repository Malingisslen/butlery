import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:butlery/core/utils/logger.dart';

/// Where the database key is kept. [FlutterSecureStorage] in the app.
abstract class SecretStore {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
}

class _KeychainSecretStore implements SecretStore {
  const _KeychainSecretStore();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  Future<String?> read(String name) => _storage.read(key: name);

  @override
  Future<void> write(String name, String value) =>
      _storage.write(key: name, value: value);
}

/// The key cannot be read from, or written to, secure storage right now.
/// Nothing on disk was touched, so a later start can still open the database.
class DatabaseKeyUnavailable implements Exception {
  const DatabaseKeyUnavailable();

  @override
  String toString() => 'DatabaseKeyUnavailable';
}

/// The encrypted file exists but its key is gone (a restore onto a new phone
/// without the keychain, or a wiped keystore). Its contents cannot be read by
/// anyone, and only an explicit decision may replace the file.
class DatabaseKeyLost implements Exception {
  const DatabaseKeyLost();

  @override
  String toString() => 'DatabaseKeyLost';
}

/// Hands out the key for the encrypted database file, and never a different
/// one than the file was made with: a key that fails to read is retried and
/// then reported, not replaced, because a replacement locks the file for good
/// and makes the app look like it simply has no offline data.
///
/// Exception text is never logged: a platform error can carry the key name or
/// value.
class DatabaseKeyStore {
  DatabaseKeyStore({
    SecretStore? store,
    this.attempts = 3,
    this.retryDelay = const Duration(milliseconds: 250),
    Random? random,
  }) : _store = store ?? const _KeychainSecretStore(),
       _random = random ?? Random.secure();

  static const keyName = 'drift_db_encryption_key';

  final SecretStore _store;
  final int attempts;
  final Duration retryDelay;
  final Random _random;

  Future<String> keyFor(File databaseFile) async {
    final existing = await _readWithRetry();
    if (existing != null) return existing;

    if (databaseFile.existsSync() && databaseFile.lengthSync() > 0) {
      AppLogger.error('Database file exists but its key is gone');
      throw const DatabaseKeyLost();
    }

    final key = _generate();
    try {
      await _store.write(keyName, key);
    } catch (_) {
      AppLogger.error('Could not store a new database key');
      throw const DatabaseKeyUnavailable();
    }
    AppLogger.info('Generated new database encryption key');
    return key;
  }

  Future<String?> _readWithRetry() async {
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        return await _store.read(keyName);
      } catch (_) {
        if (attempt < attempts) await Future<void>.delayed(retryDelay);
      }
    }
    AppLogger.error('Could not read the database key from secure storage');
    throw const DatabaseKeyUnavailable();
  }

  String _generate() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }
}
