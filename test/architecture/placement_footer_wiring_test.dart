/// BUT-2126/BUT-2124/BUT-2129: source lints keeping the placement footer's
/// silently-deletable wirings connected.
///
/// These seams share a shape: an optional argument whose absence still compiles,
/// still builds, and leaves every suite green while the user-visible behaviour
/// is gone.
///
/// `MenuPlacementChoiceFooter.isPlacing` defaults to `false`, so dropping the
/// `isPlacing:` argument in `veckomeny_view.dart` ships the app with the
/// second-tap guard the viewmodel keeps but the button no longer shows
/// (BUT-1987). `applyGeneratedMenu`'s `onPublished` is nullable, so dropping
/// a half of its wiring silently takes back what the publish-time announcement
/// bought.
///
/// The parts either side of each seam are pinned elsewhere: the viewmodel suite
/// covers `isPlacingGeneratedMenu` and the publish-time callback, and
/// `test/widget/menu/menu_placement_footer_test.dart` proves a tap is refused
/// when `isPlacing` is true. None of them can see the arguments that connect
/// the two layers, because no test mounts `VeckomenyView`: it reaches a dozen
/// services through `ServiceLocator` and `context.read`. So the connections are
/// asserted against the source instead.
///
/// The source is read as text, but never matched with a distance window or an
/// argument order (BUT-2133): [callArguments] finds a call by name and cuts out
/// its balanced argument list, and [namedArgument] looks an argument up by
/// name, so reordering named arguments or growing the code between two of them
/// cannot redden a lint against correct code.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _stripComments(String source) =>
    source.replaceAll(RegExp(r'(?<!:)//[^\n]*'), '');

String _normalize(String source) =>
    _stripComments(source).replaceAll(RegExp(r'\s+'), ' ');

/// The argument list of every call of [name] in [source], without the outer
/// parentheses. Declarations (`Future<int?> name({`) are skipped: their
/// parameter list is not a call.
List<String> callArguments(String source, String name) {
  final found = <String>[];
  for (final m in RegExp('(?<!\\w)$name\\(').allMatches(source)) {
    final before = source.substring(0, m.start).trimRight();
    if (before.endsWith('>') || before.endsWith('void')) continue;
    var depth = 1;
    var i = m.end;
    while (i < source.length && depth > 0) {
      final c = source[i];
      if (c == '(') depth++;
      if (c == ')') depth--;
      i++;
    }
    if (depth == 0) found.add(source.substring(m.end, i - 1));
  }
  return found;
}

/// Splits [args] at commas outside any bracket pair.
List<String> topLevelArguments(String args) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < args.length; i++) {
    final c = args[i];
    if ('([{'.contains(c)) depth++;
    if (')]}'.contains(c)) depth--;
    if (c == ',' && depth == 0) {
      parts.add(args.substring(start, i).trim());
      start = i + 1;
    }
  }
  final last = args.substring(start).trim();
  if (last.isNotEmpty) parts.add(last);
  return parts;
}

/// The value of the named argument [name] in a call's [args], or null.
String? namedArgument(String args, String name) {
  for (final part in topLevelArguments(args)) {
    final m = RegExp('^$name:\\s*(.*)\$').firstMatch(part);
    if (m != null) return m.group(1)!.trim();
  }
  return null;
}

String _squash(String value) => value.replaceAll(RegExp(r'\s+'), '');

void main() {
  late String source;

  setUp(() {
    source = _normalize(
      File('lib/views/veckomeny_view.dart').readAsStringSync(),
    );
  });

  group('the call parser', () {
    test('finds an argument wherever it stands in the call', () {
      const a = 'f(x: 1, onPublished: (p) { g(p); }, skipConfirm: true)';
      const b = 'f(skipConfirm: true, onPublished: (p) { g(p); }, x: 1)';
      for (final call in [a, b]) {
        final args = callArguments(call, 'f').single;
        expect(namedArgument(args, 'skipConfirm'), 'true');
        expect(namedArgument(args, 'onPublished'), contains('g(p)'));
      }
    });

    test('does not depend on how much code sits between two arguments', () {
      final filler = List.filled(5000, 'h();').join(' ');
      final args = callArguments(
        'f(onPublished: (p) { $filler g(p); })',
        'f',
      ).single;
      expect(namedArgument(args, 'onPublished'), contains('g(p)'));
    });

    test('skips a declaration but finds a nested call of the same name', () {
      const text = 'Future<int?> f({int? x}) async {} f(x: f(x: 1))';
      expect(callArguments(text, 'f'), ['x: f(x: 1)', 'x: 1']);
    });
  });

  test('the placement footer reads isPlacing from the calendar viewmodel', () {
    final calls = callArguments(source, 'MenuPlacementChoiceFooter');
    expect(
      calls,
      isNotEmpty,
      reason: 'the footer moved; this lint has to move with it',
    );
    expect(
      _squash(namedArgument(calls.single, 'isPlacing') ?? ''),
      'context.watch<WeeklyMenuPlanViewModel>().isPlacingGeneratedMenu',
      reason:
          'without this argument the button never shows a placement in '
          'flight, and every existing test stays green',
    );
  });

  test('the publish-time callback is threaded to applyGeneratedMenu', () {
    final calls = callArguments(source, 'applyGeneratedMenu');
    expect(calls, isNotEmpty, reason: 'the call moved; move this lint');
    expect(
      namedArgument(calls.single, 'onPublished'),
      'onPublished',
      reason:
          'the viewmodel would fire a callback nobody passed, and offline the '
          'calendar would wait for an ack that never comes',
    );
  });

  /// The calls whose `onPublished` is a closure written at the call site, as
  /// opposed to the pass-through inside [_applyGeneratedToCalendar] itself.
  List<String> inlineCallbackCalls() => [
    for (final args in callArguments(source, '_applyGeneratedToCalendar'))
      if ((namedArgument(args, 'onPublished') ?? '').startsWith('(')) args,
  ];

  test('the generate handler announces from inside the callback', () {
    final skipping = [
      for (final args in inlineCallbackCalls())
        if (namedArgument(args, 'skipConfirm') == 'true') args,
    ];
    expect(skipping, hasLength(1), reason: 'the handler moved; move this lint');
    expect(
      namedArgument(skipping.single, 'onPublished'),
      contains('_showAutoPlacedToast(placed)'),
      reason:
          'reading the return value here is what left the kalender path silent '
          'offline',
    );
  });

  test('the auto-place handler acts from inside the callback', () {
    final auto = [
      for (final args in inlineCallbackCalls())
        if (namedArgument(args, 'skipConfirm') == null) args,
    ];
    expect(auto, hasLength(1), reason: 'the handler moved; move this lint');
    final callback = namedArgument(auto.single, 'onPublished')!;
    expect(
      callback,
      contains('_setViewMode(VeckomenyViewMode.kalender)'),
      reason:
          'switching the view after the await is what made the button look '
          'dead offline',
    );
    expect(
      callback,
      contains('_showAutoPlacedToast(placed)'),
      reason: 'the toast has to describe the week the user can already see',
    );
  });

  // P5-U15 review: a failed placement's Försök igen overwrites the week
  // again. The first confirmation covered the week as it was then; the user
  // may have changed it since (the rollback is skipped when they moved on),
  // or an empty week may have been filled. So the retry goes through the
  // overwrite check and never skips it. No test mounts VeckomenyView, so
  // the retry's arguments are asserted against the source.
  test('a failed placement retries through the overwrite confirmation', () {
    final failures = callArguments(source, 'showWeekPlacementFailure');
    expect(failures, hasLength(1), reason: 'the retry moved; move this lint');
    final retry = namedArgument(failures.single, 'onRetry')!;
    final retried = callArguments(retry, '_applyGeneratedToCalendar');
    expect(retried, hasLength(1), reason: 'the retry moved; move this lint');
    expect(
      namedArgument(retried.single, 'skipConfirm'),
      isNull,
      reason:
          'a retry that skips the confirmation can wipe entries the '
          'user added after the failed placement without asking',
    );
  });
}
