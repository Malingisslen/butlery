import 'dart:typed_data';

/// BUT-910: web has no filesystem to stage draft image bytes on, so the
/// photo-import draft degrades to text-only there — the OCR text (the
/// expensive artefact) still round-trips through SharedPreferences; the image
/// preview does not survive navigation.
Future<String?> stageDraftImage(Uint8List bytes) async => null;

Future<Uint8List?> readDraftImage(String? path) async => null;

Future<void> deleteDraftImage(String? path) async {}
