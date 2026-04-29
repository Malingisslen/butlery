// tools/audit_unwrapped_tap_targets.dart
// BUT-697: surfaces InkWell/GestureDetector tap targets that aren't wrapped
// in Semantics(label:) within the immediately preceding 10 lines. Heuristic
// — not a strict CI gate. Run before shipping a sprint that adds tappable
// widgets to confirm a11y coverage.
//
// Usage: dart run tools/audit_unwrapped_tap_targets.dart
//
// Exit code: 0 always (audit, not gate). Use --strict to exit 1 on findings.

// ignore_for_file: avoid_print

import 'dart:io';

const _scanRoots = ['lib/views', 'lib/widgets'];
const _proximityWindow = 10;

/// Anchors that count as "this tap target is a11y-handled":
/// - Direct Semantics(label:) parent within proximity window
/// - Wrapped in a self-labeling Material/Cupertino primitive (the regex
///   walks back up to 4 lines to find the enclosing widget call)
const _wrapperAnchors = {
  'Semantics(',
  'IconButton(',
  'TextButton(',
  'OutlinedButton(',
  'ElevatedButton(',
  'FilledButton(',
  'FloatingActionButton(',
  'CupertinoButton(',
  'Switch(',
  'Checkbox(',
  'Radio(',
  'ListTile(', // ListTile gets a11y from title:/onTap: pair
  'CheckboxListTile(',
  'SwitchListTile(',
  'RadioListTile(',
};

/// Tap-target widgets we want to audit.
final _tapTargetPattern = RegExp(r'\b(InkWell|GestureDetector)\(');

/// Files / dirs to skip — generated, test-only, or known-decorative.
const _skipPatterns = [
  '.dart_tool/',
  'generated_plugin_registrant',
  '/test/',
];

class _Finding {
  final String file;
  final int line;
  final String widgetName;
  final String snippet;
  _Finding(this.file, this.line, this.widgetName, this.snippet);
}

void main(List<String> args) async {
  final strict = args.contains('--strict');
  final findings = <_Finding>[];

  for (final root in _scanRoots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (_skipPatterns.any(entity.path.contains)) continue;
      _auditFile(entity, findings);
    }
  }

  if (findings.isEmpty) {
    print('OK — no unwrapped InkWell/GestureDetector found '
        'in lib/views/ + lib/widgets/.');
    return;
  }

  print('Found ${findings.length} unwrapped tap target(s) — '
      'review each manually:');
  print('');
  for (final f in findings) {
    print('${f.file}:${f.line}  ${f.widgetName}');
    print('    ${f.snippet.trim()}');
    print('');
  }
  print('Note: heuristic. False positives expected for tap targets where the '
      'parent widget already provides Semantics (custom button widgets, '
      'list-row decorations).');

  if (strict) exit(1);
}

void _auditFile(File file, List<_Finding> findings) {
  final lines = file.readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final match = _tapTargetPattern.firstMatch(lines[i]);
    if (match == null) continue;

    final start = (i - _proximityWindow).clamp(0, lines.length);
    final priorChunk = lines.sublist(start, i + 1).join('\n');
    final hasAnchor = _wrapperAnchors.any(priorChunk.contains);
    if (hasAnchor) continue;

    findings.add(_Finding(
      file.path.replaceAll('\\', '/'),
      i + 1,
      match.group(1)!,
      lines[i],
    ));
  }
}
