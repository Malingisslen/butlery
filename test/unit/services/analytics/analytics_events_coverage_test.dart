/// BUT-436: structural lint asserting every constant declared in
/// `AnalyticsEvents` and `AnalyticsUserProperties` has at least one caller
/// in `lib/`. Catches the "facade lies about coverage" regression where
/// someone declares a new event-name constant but forgets to wire the
/// emitter — Firebase Analytics dashboards would then silently report zero
/// for that event, looking broken.
///
/// Detection strategy: walk every `.dart` file under `lib/`, grep for
/// `AnalyticsEvents.<name>` / `AnalyticsUserProperties.<name>`, and assert
/// each declared constant appears at least once OUTSIDE its own declaration
/// file. Raw-string usage of the event name (e.g. `name: 'screen_viewed'`)
/// is NOT counted as a caller — the registry's whole point is that all
/// emit sites route through the constants for typo-safety.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every AnalyticsEvents constant has a caller in lib/', () {
    final declared = _collectDeclaredConstants(
      'lib/services/analytics/analytics_events.dart',
      className: 'AnalyticsEvents',
    );
    expect(declared, isNotEmpty,
        reason: 'sanity check — should find dozens of constants');

    final used = _collectQualifiedReferences('AnalyticsEvents');
    final dead = declared.difference(used);

    expect(
      dead,
      isEmpty,
      reason: 'AnalyticsEvents constants with zero `AnalyticsEvents.<name>` '
          'call sites in lib/. Either wire the emitter at the right call '
          'site or remove the constant. Dead constants make the analytics '
          'dashboard show zero for an event that was never actually emitted, '
          'masking either missing instrumentation or a name typo.\n'
          'Dead: $dead',
    );
  });

  test('every AnalyticsUserProperties constant has a caller in lib/', () {
    final declared = _collectDeclaredConstants(
      'lib/services/analytics/analytics_events.dart',
      className: 'AnalyticsUserProperties',
    );
    expect(declared, isNotEmpty);

    final used = _collectQualifiedReferences('AnalyticsUserProperties');
    final dead = declared.difference(used);

    expect(
      dead,
      isEmpty,
      reason: 'AnalyticsUserProperties constants with zero '
          '`AnalyticsUserProperties.<name>` call sites in lib/. Same '
          'dashboard-lies-about-coverage failure mode as the events case '
          'above.\nDead: $dead',
    );
  });

  test(
      'every `logEvent(name: "...")` raw-string is also declared in AnalyticsEvents',
      () {
    // Caught the reverse direction the per-constant-test misses: someone
    // calls `logEvent(name: 'app_opened', ...)` with a literal string but
    // never adds the matching `AnalyticsEvents.appOpened` constant. The
    // event ships, the funnel works — but the registry's typo-safety net
    // is bypassed and a one-character typo silently kills the dashboard.
    final declaredValues = _collectDeclaredEventValues(
      'lib/services/analytics/analytics_events.dart',
    );
    final usedValues = _collectLogEventNameStrings();
    final undeclared = usedValues.difference(declaredValues);

    expect(
      undeclared,
      isEmpty,
      reason: 'logEvent name strings in lib/ that have no matching constant '
          'in AnalyticsEvents. Add the constant to the registry and reference '
          'it via `AnalyticsEvents.<name>` at the call site so a typo can\'t '
          'silently kill the funnel.\nUndeclared: $undeclared',
    );
  });
}

/// Parse the registry file for `static const <name> = ...` lines inside
/// the named class block. Pure regex — no Dart analyzer dependency to
/// keep the lint cheap and runnable from a regular `flutter test`.
Set<String> _collectDeclaredConstants(String path,
    {required String className}) {
  final source = File(path).readAsStringSync();
  // Locate the class body — `abstract final class <name> { ... }`.
  final classStart = source.indexOf('class $className');
  expect(classStart, isNot(-1), reason: 'class $className not found in $path');
  final braceStart = source.indexOf('{', classStart);
  // Match braces to find the class end (single-level — there are no nested
  // class declarations in this file, so a depth counter is enough).
  var depth = 0;
  var classEnd = -1;
  for (var i = braceStart; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) {
        classEnd = i;
        break;
      }
    }
  }
  expect(classEnd, isNot(-1), reason: 'unbalanced braces in $className');
  final body = source.substring(braceStart, classEnd);

  final declRe = RegExp(r'static\s+const\s+(\w+)\s*=', multiLine: true);
  return declRe.allMatches(body).map((m) => m.group(1)!).toSet();
}

/// Parse the registry for the *string values* of `AnalyticsEvents`
/// constants — `static const xxx = 'xxx_value';` → collect `xxx_value`.
/// Used by the reverse-direction lint that compares raw-string `name:`
/// arguments against the declared registry.
Set<String> _collectDeclaredEventValues(String path) {
  final source = File(path).readAsStringSync();
  final classStart = source.indexOf('class AnalyticsEvents');
  final braceStart = source.indexOf('{', classStart);
  var depth = 0;
  var classEnd = -1;
  for (var i = braceStart; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) {
        classEnd = i;
        break;
      }
    }
  }
  final body = source.substring(braceStart, classEnd);
  final valueRe =
      RegExp(r"static\s+const\s+\w+\s*=\s*'([^']+)'", multiLine: true);
  return valueRe.allMatches(body).map((m) => m.group(1)!).toSet();
}

/// Walk lib/ and collect every literal string passed as the `name:`
/// argument to a `logEvent` call (`logEvent(name: 'foo'...)` or
/// `logEvent(\n  name: 'foo',`). Used by the reverse-direction lint.
/// Multi-line tolerant; ignores commented-out call sites by skipping
/// lines inside `///` doc comments — pragmatic, not exhaustive.
Set<String> _collectLogEventNameStrings() {
  final names = <String>{};
  // Match `logEvent(...name: 'xxx'...)` across whitespace/newlines.
  final logEventRe = RegExp(
    r"\.logEvent\s*\(\s*[\s\S]*?name:\s*'([a-z][a-z0-9_]*)'",
    multiLine: true,
  );
  final libDir = Directory('lib');
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final source = entity.readAsStringSync();
    for (final m in logEventRe.allMatches(source)) {
      names.add(m.group(1)!);
    }
  }
  return names;
}

/// Walk lib/ and collect every `<className>.<member>` reference. Skips
/// the registry file itself so the declaration line doesn't count as a
/// reference to itself.
Set<String> _collectQualifiedReferences(String className) {
  final references = <String>{};
  final refRe = RegExp(RegExp.escape(className) + r'\.(\w+)');
  final libDir = Directory('lib');
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('analytics_events.dart')) continue;
    final source = entity.readAsStringSync();
    for (final m in refRe.allMatches(source)) {
      references.add(m.group(1)!);
    }
  }
  return references;
}
