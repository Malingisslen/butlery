import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

String guardSource(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is gone; update the guard');
  return file
      .readAsStringSync()
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//[^\n]*'), '');
}

Map<String, dynamic> guardJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<String> guardLibPaths() => [
  for (final e in Directory('lib').listSync(recursive: true))
    if (e is File &&
        e.path.endsWith('.dart') &&
        !e.path.replaceAll(r'\', '/').startsWith('lib/l10n/'))
      e.path.replaceAll(r'\', '/'),
]..sort();

List<String> guardLibFilesMatching(Pattern pattern) => [
  for (final path in guardLibPaths())
    if (guardSource(path).contains(pattern)) path,
];

double _channel(int v) {
  final s = v / 255;
  return s <= 0.03928
      ? s / 12.92
      : math.pow((s + 0.055) / 1.055, 2.4) as double;
}

double _luminance(String hex) {
  final v = int.parse(hex.replaceFirst('#', ''), radix: 16);
  return 0.2126 * _channel((v >> 16) & 0xFF) +
      0.7152 * _channel((v >> 8) & 0xFF) +
      0.0722 * _channel(v & 0xFF);
}

double guardContrast(String a, String b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
