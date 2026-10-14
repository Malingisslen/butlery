import 'package:flutter/services.dart';

/// Loads a bundled legal document in the app's language, not the phone's.
/// Falls back to Swedish, the source language, when no translation ships.
Future<String> loadLegalAsset(
  String baseName,
  String languageCode, {
  AssetBundle? bundle,
}) async {
  final source = bundle ?? rootBundle;
  try {
    return await source.loadString('assets/legal/${baseName}_$languageCode.md');
  } catch (_) {
    return source.loadString('assets/legal/${baseName}_sv.md');
  }
}
