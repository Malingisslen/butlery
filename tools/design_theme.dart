// BUT-2202: the one way the generated theme files reach lib/theme/.
//
// The colour and type generators live in design/tools/ and write their raw
// output to design/lib/theme/, where the Block 289 freeze hashes it byte for
// byte. The app compiles the dart-formatted text of those same files. This
// tool runs the generators and writes the formatted result into lib/theme/;
// with --check it writes nothing and exits 1 when either side has drifted,
// which is what CI runs.
//
// Run from the app repo root (needs node and dart on PATH):
//
//   dart run tools/design_theme.dart          regenerate after editing
//                                             design/tokens.json
//   dart run tools/design_theme.dart --check  CI: red on a hand edit

// ignore_for_file: avoid_print

import 'dart:io';

const _designRoot = 'design';

const _generators = [
  'tools/gen-app-theme.mjs',
  'tools/gen-app-theme-dark.mjs',
];

const _files = [
  'app_colors.dart',
  'app_colors_dark.dart',
  'app_text_styles.dart',
];

Future<void> main(List<String> args) async {
  final check = args.contains('--check');
  var failed = false;

  for (final generator in _generators) {
    final run = await Process.run(
      'node',
      [generator, if (check) '--check'],
      workingDirectory: _designRoot,
    );
    stdout.write(run.stdout);
    stderr.write(run.stderr);
    if (run.exitCode != 0) failed = true;
  }
  if (failed && !check) {
    stderr.writeln('a generator failed; lib/theme/ left as it was');
    exit(1);
  }

  final tmp = Directory.systemTemp.createTempSync('design_theme');
  try {
    for (final name in _files) {
      File('$_designRoot/lib/theme/$name').copySync('${tmp.path}/$name');
    }
    final format = await Process.run('dart', ['format', tmp.path]);
    if (format.exitCode != 0) {
      stderr.write(format.stderr);
      exit(1);
    }
    for (final name in _files) {
      final want = File('${tmp.path}/$name').readAsStringSync();
      final target = File('lib/theme/$name');
      if (!check) {
        target.writeAsStringSync(want);
        print('wrote ${target.path}');
        continue;
      }
      final got = target.existsSync() ? target.readAsStringSync() : null;
      if (got == want) {
        print('THEME-CHECK ok ${target.path}');
      } else {
        stderr.writeln(
          'THEME-CHECK drift ${target.path}: not the formatted output of '
          '$_designRoot/lib/theme/$name. Edit design/tokens.json and run '
          'dart run tools/design_theme.dart, never the file itself.',
        );
        failed = true;
      }
    }
  } finally {
    tmp.deleteSync(recursive: true);
  }
  if (failed) exit(1);
}
