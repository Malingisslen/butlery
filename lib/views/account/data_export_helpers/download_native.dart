import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Saves a JSON file to the documents directory, returns the full path.
Future<String?> downloadJsonFile(String content, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final filePath = '${directory.path}/$fileName';
  final file = File(filePath);
  await file.writeAsString(content);
  return filePath;
}

/// Shares a JSON file via the native share sheet, cleans up temp file after.
Future<void> shareJsonFile(String content, String fileName,
    {String? subject, String? text}) async {
  final directory = await getTemporaryDirectory();
  final filePath = '${directory.path}/$fileName';
  final file = File(filePath);
  await file.writeAsString(content);

  try {
    await SharePlus.instance.share(ShareParams(
      files: [XFile(filePath)],
      subject: subject,
      text: text,
    ));
  } finally {
    if (await file.exists()) await file.delete();
  }
}

bool get canShareFiles => true;
