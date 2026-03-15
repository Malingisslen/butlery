import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Shared cryptographic utilities.
class CryptoUtils {
  CryptoUtils._();

  /// SHA-256 hash of a string, returned as hex.
  static String sha256Hash(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}
