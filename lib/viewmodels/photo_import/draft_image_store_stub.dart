import 'dart:typed_data';

/// Stub — never called directly. Conditional import resolves to io or web.
Future<String?> stageDraftImage(Uint8List bytes) async =>
    throw UnsupportedError('Platform not supported');

Future<Uint8List?> readDraftImage(String? path) async =>
    throw UnsupportedError('Platform not supported');

Future<void> deleteDraftImage(String? path) async =>
    throw UnsupportedError('Platform not supported');
