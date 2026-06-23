import 'dart:async';
import 'dart:js_interop';
import 'dart:convert';
import 'package:web/web.dart' as web;

/// Triggers a browser download of a JSON file.
///
/// Creates a temporary Blob URL, triggers download via anchor click,
/// then revokes the URL after a delay so the browser can complete the stream.
Future<String?> downloadJsonFile(String content, String fileName) async {
  try {
    final jsArray = utf8.encode(content).toJS;
    final blob = web.Blob(
      [jsArray].toJS,
      web.BlobPropertyBag(type: 'application/json'),
    );
    final url = web.URL.createObjectURL(blob);

    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;
    web.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    // Defer revoke to let browser complete the download stream
    unawaited(
      Future.delayed(
        const Duration(seconds: 10),
        () => web.URL.revokeObjectURL(url),
      ),
    );
    return fileName;
  } catch (e) {
    throw Exception('Failed to create download: $e');
  }
}

/// Triggers a browser download of a CSV file (UTF-8, text/csv).
Future<String?> downloadCsvFile(String content, String fileName) async {
  try {
    final jsArray = utf8.encode(content).toJS;
    final blob = web.Blob(
      [jsArray].toJS,
      web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;
    web.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    unawaited(
      Future.delayed(
        const Duration(seconds: 10),
        () => web.URL.revokeObjectURL(url),
      ),
    );
    return fileName;
  } catch (e) {
    throw Exception('Failed to create CSV download: $e');
  }
}

/// Web has no native share sheet — triggers download as fallback.
Future<void> shareJsonFile(
  String content,
  String fileName, {
  String? subject,
  String? text,
}) async {
  await downloadJsonFile(content, fileName);
}

bool get canShareFiles => false;
