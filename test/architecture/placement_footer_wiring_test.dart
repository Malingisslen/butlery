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
/// Residual, named rather than left to be found: these patterns run over the
/// file's text, so they are coupled to what `dart format` currently emits
/// beyond the joints made optional below.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUp(() {
    source = File(
      'lib/views/veckomeny_view.dart',
    ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
  });

  test('the placement footer reads isPlacing from the calendar viewmodel', () {
    expect(
      source,
      contains('MenuPlacementChoiceFooter('),
      reason: 'the footer moved; this lint has to move with it',
    );
    expect(
      source,
      matches(
        RegExp(
          // The gap absorbs the comment that sits between the constructor
          // and its first argument; it stays bounded so the match cannot
          // wander into a different widget further down the tree.
          r'MenuPlacementChoiceFooter\(.{0,300}?isPlacing: context ?'
          r'\.watch<WeeklyMenuPlanViewModel>\(\) ?\.isPlacingGeneratedMenu',
        ),
      ),
      reason:
          'without this argument the button never shows a placement in '
          'flight, and every existing test stays green',
    );
  });

  test('the publish-time callback is threaded to applyGeneratedMenu', () {
    expect(
      source,
      matches(RegExp(r'applyGeneratedMenu\(.{0,300}?onPublished: onPublished')),
      reason:
          'the viewmodel would fire a callback nobody passed, and offline the '
          'calendar would wait for an ack that never comes',
    );
  });

  test('the generate handler announces from inside the callback', () {
    expect(
      source,
      matches(
        RegExp(
          r'_applyGeneratedToCalendar\( ?skipConfirm: true, ?onPublished: '
          r'\(placed\) \{.{0,400}?_showAutoPlacedToast\(placed\)',
        ),
      ),
      reason:
          'reading the return value here is what left the kalender path silent '
          'offline',
    );
  });

  test('the auto-place handler acts from inside the callback', () {
    expect(
      source,
      matches(
        RegExp(
          r'_applyGeneratedToCalendar\( ?onPublished: \(placed\) \{.{0,800}?'
          r'_setViewMode\(VeckomenyViewMode\.kalender\)',
        ),
      ),
      reason:
          'switching the view after the await is what made the button look '
          'dead offline',
    );
    expect(
      source,
      matches(
        RegExp(
          r'_applyGeneratedToCalendar\( ?onPublished: \(placed\) \{.{0,800}?'
          r'_showAutoPlacedToast\(placed\)',
        ),
      ),
      reason: 'the toast has to describe the week the user can already see',
    );
  });
}
