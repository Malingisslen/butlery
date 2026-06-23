/// Stub — never called directly. Conditional import resolves to web or native.
Future<String?> downloadJsonFile(String content, String fileName) async =>
    throw UnsupportedError('Platform not supported');

Future<String?> downloadCsvFile(String content, String fileName) async =>
    throw UnsupportedError('Platform not supported');

Future<void> shareJsonFile(
  String content,
  String fileName, {
  String? subject,
  String? text,
}) async => throw UnsupportedError('Platform not supported');

bool get canShareFiles => false;
