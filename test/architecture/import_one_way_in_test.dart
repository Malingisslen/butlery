// BUT-2240: channels do not parse. A view or viewmodel naming one of
// these types is building a second pipeline beside it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _bypass = RegExp(
  r'\b(WebScraper|SocialMediaExtractor|RecipeParserService|FileImportStrategy|UrlImportStrategy|TextImportStrategy|getTextImportStrategy)\b',
);

/// Code without comments, so history in a comment is not a use.
String _code(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'(?<!:)//.*'), '');

List<String> _uiFiles() => [
  for (final dir in ['lib/views', 'lib/viewmodels'])
    for (final e in Directory(dir).listSync(recursive: true))
      if (e is File && e.path.endsWith('.dart')) e.path.replaceAll(r'\', '/'),
];

List<String> _hits(String source) => [
  for (final m in _bypass.allMatches(_code(source))) m.group(1)!,
];

void main() {
  test('no view or viewmodel names a parser type', () {
    final files = _uiFiles();
    expect(files, isNotEmpty, reason: 'run from the repository root');
    final offenders = <String>[
      for (final path in files)
        for (final hit in _hits(File(path).readAsStringSync())) '$path: $hit',
    ];
    expect(
      offenders,
      isEmpty,
      reason: 'Call ImportManager instead; it owns the quota and the event.',
    );
  });

  group('the matcher', () {
    test('catches a direct use', () {
      expect(_hits('final s = WebScraper();'), ['WebScraper']);
      expect(_hits('FileImportStrategy().pickFile()'), ['FileImportStrategy']);
      expect(_hits('importManager.getTextImportStrategy().import(t)'), [
        'getTextImportStrategy',
      ]);
      expect(_hits('ServiceLocator.get<RecipeParserService>()'), [
        'RecipeParserService',
      ]);
      expect(_hits('UrlImportStrategy().import(url)'), ['UrlImportStrategy']);
      expect(_hits('TextImportStrategy().import(text)'), [
        'TextImportStrategy',
      ]);
    });

    test('ignores comments and longer names', () {
      expect(_hits('// was WebScraper before BUT-2240'), isEmpty);
      expect(_hits('final x = MockWebScraperFactory();'), isEmpty);
    });
  });
}
