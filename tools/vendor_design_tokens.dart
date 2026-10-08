// P8-U07: vendors the colour part of the design system's tokens.json into
// test/fixtures/design/tokens-semantic.json, for token_parity_test.
//
// The generator that writes lib/theme/app_colors.dart and
// app_colors_dark.dart lives in the design repo (tools/gen-app-theme.mjs),
// so the build cannot re-run it. It checks instead that every generated
// colour equals this vendored copy of the tokens it names. When the design
// tokens change, re-vendor with this tool and regenerate the theme files in
// the design repo; never edit the fixture by hand.
//
// Run from the app repo root, never in CI (CI has no design checkout):
//
//   dart run tools/vendor_design_tokens.dart <path to design-system checkout>
//
// It prints the sha256 of the tokens.json it read.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _fixture = 'test/fixtures/design/tokens-semantic.json';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'usage: dart run tools/vendor_design_tokens.dart <design-system checkout>',
    );
    exit(64);
  }
  final root = args.single;
  final source = File('$root/tokens.json');
  if (!source.existsSync()) {
    stderr.writeln('${source.path} not found');
    exit(66);
  }
  final bytes = source.readAsBytesSync();
  final sha = sha256.convert(bytes).toString();
  final tokens = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

  // The last commit that changed tokens.json, so the label does not move
  // when unrelated design commits land.
  final log = await Process.run('git', [
    '-C',
    root,
    'log',
    '-1',
    '--format=%h',
    '--',
    'tokens.json',
  ]);
  final commit = log.exitCode == 0 ? (log.stdout as String).trim() : '';

  final semantic = <String, Object?>{
    for (final e in (tokens['semantic'] as Map<String, dynamic>).entries)
      e.key: {
        'light': (e.value as Map<String, dynamic>)['light'],
        'dark': (e.value as Map<String, dynamic>)['dark'],
      },
  };
  final ladder = tokens['opacityLadder'] as Map<String, dynamic>;

  final out = <String, Object?>{
    r'$om':
        'P8-U07: the colour tokens of the design system (tokens.json semantic, '
        'palette and opacityLadder, values only). token_parity_test checks '
        'every colour in lib/theme/app_colors.dart and app_colors_dark.dart '
        'against the token its doc line names. Refresh with '
        'tools/vendor_design_tokens.dart, never by hand.',
    'source': {
      'file': 'tokens.json',
      'repo': 'Butlery design system',
      'commit': commit,
      'sha256': sha,
    },
    'version': tokens['version'],
    'date': tokens['date'],
    'opacityLadder': {
      for (final e in ladder.entries)
        if (e.value is List) e.key: e.value,
    },
    'palette': tokens['palette'],
    'semantic': semantic,
  };

  File(
    _fixture,
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(out)}\n');
  stdout.writeln('wrote $_fixture');
  stdout.writeln('tokens.json ${tokens['version']} ($commit) sha256 $sha');
}
