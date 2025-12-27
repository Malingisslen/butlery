import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:butlery/core/utils/logger.dart';

/// Service for field-level encryption of sensitive Firestore data.
///
/// Provides AES-256-CBC encryption for protecting user-generated content
/// before it's written to Firestore. This adds an extra layer of protection
/// beyond Firebase's encryption-at-rest.
///
/// Usage:
/// ```dart
/// final service = FieldEncryptionService();
/// final encrypted = await service.encrypt('sensitive data');
/// final decrypted = await service.decrypt(encrypted);
/// ```
class FieldEncryptionService {
  static const _keyStorageKey = 'field_encryption_key_v1';
  static const _encryptionPrefix = 'ENC:';
  static const _keyLength = 32; // 256 bits
  static const _ivLength = 16; // 128 bits

  final FlutterSecureStorage _storage;
  Uint8List? _key;

  FieldEncryptionService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  /// Gets or creates the encryption key.
  Future<Uint8List> _getKey() async {
    if (_key != null) return _key!;

    try {
      var keyString = await _storage.read(key: _keyStorageKey);

      if (keyString == null) {
        // Generate a new 256-bit key using secure random
        _key = _generateSecureRandom(_keyLength);
        keyString = base64Encode(_key!);
        await _storage.write(key: _keyStorageKey, value: keyString);
        AppLogger.info('Generated new field encryption key');
      } else {
        _key = Uint8List.fromList(base64Decode(keyString));
      }

      return _key!;
    } catch (e) {
      AppLogger.error('Failed to initialize encryption: $e');
      rethrow;
    }
  }

  /// Generates cryptographically secure random bytes.
  Uint8List _generateSecureRandom(int length) {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom.nextBytes(length);
  }

  /// Creates an AES-CBC cipher for encryption/decryption.
  PaddedBlockCipher _createCipher(
      bool forEncryption, Uint8List key, Uint8List iv) {
    final params = PaddedBlockCipherParameters(
      ParametersWithIV(KeyParameter(key), iv),
      null,
    );

    return PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    )..init(forEncryption, params);
  }

  /// Encrypts a plaintext string.
  ///
  /// Returns an encrypted string in format: `ENC:<iv>:<ciphertext>`
  /// The IV is randomly generated for each encryption operation.
  ///
  /// Returns the original string if it's null, empty, or already encrypted.
  Future<String> encrypt(String? plaintext) async {
    if (plaintext == null || plaintext.isEmpty) return plaintext ?? '';
    if (isEncrypted(plaintext)) return plaintext;

    try {
      final key = await _getKey();
      final iv = _generateSecureRandom(_ivLength);

      final cipher = _createCipher(true, key, iv);
      final inputBytes = Uint8List.fromList(utf8.encode(plaintext));
      final encrypted = cipher.process(inputBytes);

      return '$_encryptionPrefix${base64Encode(iv)}:${base64Encode(encrypted)}';
    } catch (e) {
      AppLogger.error('Encryption failed: $e');
      // Return original on failure to prevent data loss
      return plaintext;
    }
  }

  /// Decrypts an encrypted string.
  ///
  /// Expects format: `ENC:<iv>:<ciphertext>`
  /// Returns the original string if it's not in encrypted format.
  Future<String> decrypt(String? ciphertext) async {
    if (ciphertext == null || ciphertext.isEmpty) return ciphertext ?? '';
    if (!isEncrypted(ciphertext)) return ciphertext;

    try {
      final key = await _getKey();

      // Remove prefix and split
      final data = ciphertext.substring(_encryptionPrefix.length);
      final parts = data.split(':');

      if (parts.length != 2) {
        AppLogger.warning('Invalid encrypted format');
        return ciphertext;
      }

      final iv = Uint8List.fromList(base64Decode(parts[0]));
      final encrypted = Uint8List.fromList(base64Decode(parts[1]));

      final cipher = _createCipher(false, key, iv);
      final decrypted = cipher.process(encrypted);

      return utf8.decode(decrypted);
    } catch (e) {
      AppLogger.error('Decryption failed: $e');
      // Return original on failure
      return ciphertext;
    }
  }

  /// Checks if a string is in encrypted format.
  bool isEncrypted(String? value) {
    if (value == null || value.isEmpty) return false;
    return value.startsWith(_encryptionPrefix) && value.contains(':');
  }

  /// Encrypts multiple fields in a map.
  ///
  /// Only encrypts fields specified in [fieldsToEncrypt].
  /// Returns a new map with encrypted values.
  Future<Map<String, dynamic>> encryptFields(
    Map<String, dynamic> data,
    List<String> fieldsToEncrypt,
  ) async {
    final result = Map<String, dynamic>.from(data);

    for (final field in fieldsToEncrypt) {
      if (result.containsKey(field) && result[field] is String) {
        result[field] = await encrypt(result[field] as String);
      }
    }

    return result;
  }

  /// Decrypts multiple fields in a map.
  ///
  /// Only decrypts fields specified in [fieldsToDecrypt].
  /// Returns a new map with decrypted values.
  Future<Map<String, dynamic>> decryptFields(
    Map<String, dynamic> data,
    List<String> fieldsToDecrypt,
  ) async {
    final result = Map<String, dynamic>.from(data);

    for (final field in fieldsToDecrypt) {
      if (result.containsKey(field) && result[field] is String) {
        result[field] = await decrypt(result[field] as String);
      }
    }

    return result;
  }

  /// Clears the cached key (useful for testing).
  void clearCache() {
    _key = null;
  }

  /// Rotates the encryption key.
  ///
  /// WARNING: This will make previously encrypted data unreadable.
  /// Only use after migrating all existing encrypted data.
  Future<void> rotateKey() async {
    _key = _generateSecureRandom(_keyLength);
    final keyString = base64Encode(_key!);
    await _storage.write(key: _keyStorageKey, value: keyString);
    AppLogger.warning('Encryption key rotated - previous data may be lost');
  }
}
