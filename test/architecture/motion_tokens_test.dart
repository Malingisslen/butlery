// Animation times read the motion tokens (produktbeslut R8-9 = A): the retired
// AppDimensions animation names stay gone, and the transitions in the router
// files take AppMotion's time and curve.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_motion.dart';

const _routeFiles = [
  'lib/core/router/app_router.dart',
  'lib/core/router/async_route_builder.dart',
];

String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'(?<!:)//[^\n]*'), '');

/// The old AppDimensions animation names, wherever they appear.
List<String> retiredDurationNames(String path, String code) => [
  for (final m in RegExp(
    r'\banimationDuration(Fast|Medium|Common|Slow|Long|Extended)\b',
  ).allMatches(code))
    '$path ${m.group(0)}',
];

/// A route time or curve that is not an AppMotion member.
List<String> routeMotionOffTokens(String path, String code) => [
  for (final m in RegExp(
    r'(transitionDuration:\s*|return\s+)(const\s+)?Duration\(',
  ).allMatches(code))
    '$path ${m.group(0)}',
  for (final m in RegExp(r'\bCurves\.\w+').allMatches(code))
    '$path ${m.group(0)}',
];

void main() {
  test('no file under lib/ reads a retired animation-duration name', () {
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll('\\', '/');
      found.addAll(retiredDurationNames(path, _code(path)));
    }
    expect(found, isEmpty, reason: 'use AppMotion, or a named wait');
  });

  test('the router files take AppMotion time and curve', () {
    final found = <String>[];
    for (final path in _routeFiles) {
      final code = _code(path);
      expect(code, contains('AppMotion.standard'), reason: path);
      found.addAll(routeMotionOffTokens(path, code));
    }
    expect(found, isEmpty);
  });

  test('the scans see what they are meant to catch', () {
    expect(retiredDurationNames('x', 'AppDimensions.animationDurationLong'), [
      'x animationDurationLong',
    ]);
    expect(
      routeMotionOffTokens(
        'x',
        'transitionDuration: const Duration(milliseconds: 600)',
      ),
      hasLength(1),
    );
    expect(
      routeMotionOffTokens('x', 'return const Duration(milliseconds: 400);'),
      hasLength(1),
    );
    expect(routeMotionOffTokens('x', 'const curve = Curves.elasticOut;'), [
      'x Curves.elasticOut',
    ]);
    expect(
      routeMotionOffTokens('x', 'transitionDuration: AppMotion.standard'),
      isEmpty,
    );
  });

  // One loop of a reverse-repeating pulse is AppMotion.pulse (R7-4, R8-9).
  test('pulseHalf is half of pulse', () {
    expect(AppMotion.pulseHalf * 2, AppMotion.pulse);
  });
}
