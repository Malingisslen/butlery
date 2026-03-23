import 'dart:async';
import 'dart:js_interop';
import 'dart:convert';
import 'package:web/web.dart' as web;

/// Triggers a browser download of a JSON file.
Future<String?> downloadJsonFile(String content, String fileName) async {
  final jsArray = utf8.encode(content).toJS;
  final blob =
      web.Blob([jsArray].toJS, web.BlobPropertyBag(type: 'application/json'));
  final url = web.URL.createObjectURL(blob);

  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  // Defer revoke to let browser schedule the download first
  unawaited(Future.delayed(Duration.zero, () => web.URL.revokeObjectURL(url)));
  return fileName;
}

/// Web has no native share sheet — triggers download as fallback.
Future<void> shareJsonFile(String content, String fileName,
    {String? subject, String? text}) async {
  await downloadJsonFile(content, fileName);
}

bool get canShareFiles => false;
