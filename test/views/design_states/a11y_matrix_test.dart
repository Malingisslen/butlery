/// P8-U02: the accessibility matrix over the U01 states.
///
/// The 18 DEFAULT rows, in light and dark, at 320, 360 and 412 dp and at
/// text scale 1.0, 1.5 and 2.0 (Butlery tillganglighetshandoff.dc.html:85: 412/360/320
/// and 200 % text; testmatris.md:60-63; syntes.json PAKET 8 "vid 1,5× och
/// 2,0× textskala"). Each case must hold:
/// - no overflow, and no horizontal scroll of the page itself
///   (testmatris.md:60 "inget horisontellt scroll");
/// - no button label cut to an ellipsis (testmatris.md:63 "radbrytning i
///   stället för ellips", "inga trunkerade primärhandlingar");
/// - every tap target 48 dp (androidTapTargetGuideline; tokens.json
///   touchTarget.min 48) and labelled (labeledTapTargetGuideline).
/// Text contrast as rendered (textContrastGuideline) is read once per row
/// and mode, at 360 dp and 1.0, since it renders the screen to an image.
///
/// The LOADING, EMPTY and OFFLINE rows are checked for targets and labels at
/// 360 dp and 1.0 in both modes.
///
/// Today's failures are listed in known_a11y_findings.dart with their
/// tickets; an unlisted failure is red, and so is a listed one that passes.
/// A few text contrast findings depend on the host's glyph rasteriser and are
/// listed per host there (Linux, Windows).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/views/unified_shopping/widgets/shopping_item_tiles.dart';

import 'known_a11y_findings.dart';
import 'state_harness.dart';
import 'state_hosts.dart';
import 'state_rules.dart';
import 'state_runner.dart';

const _modes = [Brightness.light, Brightness.dark];
const _widths = [320.0, 360.0, 412.0];
const _scales = [1.0, 1.5, 2.0];

String _modeName(Brightness b) => b == Brightness.dark ? 'dark' : 'light';

String _scaleName(double s) => s.toStringAsFixed(1);

/// A page-level horizontal scroll: a horizontal scrollable as wide as the
/// screen and at least half as tall. A chip or tab row scrolls sideways by
/// design (testmatris.md:63) and is shorter than that.
bool _pageScrollsSideways(WidgetTester tester) {
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (final e in onstageElements()) {
    final w = e.widget;
    if (w is! Scrollable ||
        axisDirectionToAxis(w.axisDirection) != Axis.horizontal) {
      continue;
    }
    // A TabBarView or PageView pages sideways by design; that is not the
    // page's content scrolling.
    var paged = false;
    e.visitAncestorElements((a) {
      paged = a.widget is PageView || a.widget is TabBarView;
      return !paged;
    });
    if (paged) continue;
    final r = e.renderObject;
    if (r is RenderBox &&
        r.hasSize &&
        r.size.width >= screen.width * 0.9 &&
        r.size.height >= screen.height * 0.5) {
      final position = (e as StatefulElement).state as ScrollableState;
      if (position.position.maxScrollExtent > 0) return true;
    }
  }
  return false;
}

/// Labels cut to an ellipsis: a truncated paragraph inside a button or an
/// InkWell. BUT-2193 (Malin, 2026-10-03): a shopping item row and the list
/// name in the list picker may cut a long name at the normal text size, never
/// at a larger one.
List<String> _ellipsisedButtons(double scale) {
  final out = <String>[];
  for (final e in onstageElements()) {
    final r = e is RenderObjectElement ? e.renderObject : null;
    if (r is! RenderParagraph || r.overflow != TextOverflow.ellipsis) continue;
    if (!r.hasSize || !r.didExceedMaxLines) continue;
    var inButton = false;
    var inListRow = false;
    e.visitAncestorElements((a) {
      if (a.widget is ShoppingItemTile || a.widget is DropdownMenuItem) {
        inListRow = true;
      }
      if (a.widget is ButtonStyleButton || a.widget is InkWell) {
        inButton = true;
      }
      return true;
    });
    if (inListRow && scale <= 1) continue;
    if (inButton) out.add(textSample(r.text.toPlainText()));
  }
  return out;
}

Future<List<Violation>> _guidelines(
  WidgetTester tester, {
  required bool contrast,
}) async {
  final out = <Violation>[];
  final targets = await androidTapTargetGuideline.evaluate(tester);
  if (!targets.passed) {
    out.add(Violation('TAP_TARGET', targets.reason!.split('\n').first));
  }
  final labels = await labeledTapTargetGuideline.evaluate(tester);
  if (!labels.passed) {
    out.add(Violation('TAP_LABEL', labels.reason!.split('\n').first));
  }
  if (contrast) {
    final text = await textContrastGuideline.evaluate(tester);
    if (!text.passed) {
      out.add(Violation('TEXT_CONTRAST', text.reason!.split('\n').first));
    }
  }
  return out;
}

void main() {
  final rows = StateFixture.load().rows;
  final results = <Map<String, Object?>>[];
  final knownOnThisHost = knownA11yFindingsOnThisHost();

  setUpAll(() async {
    registerHostFallbacks();
    await loadButlerySans();
  });

  tearDownAll(() {
    final out = File('test_results/design-states-a11y.json');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({'cases': results}),
    );
  });

  Future<void> check(
    WidgetTester tester,
    StateRow row,
    Brightness mode,
    double width,
    double scale, {
    required bool layout,
    required bool contrast,
  }) async {
    final semantics = tester.ensureSemantics();
    final run = await pumpState(
      tester,
      row,
      mode,
      size: Size(width, stateSurface.height),
      textScale: scale,
    );
    // Entrance animations (a floating action button scales in) finish
    // before targets are measured.
    await tester.pump(const Duration(milliseconds: 1000));
    final violations = <Violation>[
      ...run.violations.where((v) => v.code == 'NO_HOST'),
    ];
    if (layout) {
      if (run.capture.overflows.isNotEmpty) {
        violations.add(
          Violation('OVERFLOW', run.capture.overflows.toSet().join(' | ')),
        );
      }
      if (_pageScrollsSideways(tester)) {
        violations.add(
          const Violation('H_SCROLL', 'the page scrolls sideways'),
        );
      }
      final cut = _ellipsisedButtons(scale);
      if (cut.isNotEmpty) {
        violations.add(Violation('ELLIPSIS', cut.join(', ')));
      }
    }
    // A host whose layout failed (its EXCEPTION finding below) cannot be
    // measured by the guidelines: they read a semantics tree that was
    // never laid out.
    if (run.capture.exceptions.isEmpty) {
      violations.addAll(await _guidelines(tester, contrast: contrast));
    }
    await finishState(tester, run);
    if (run.capture.exceptions.isNotEmpty) {
      violations.add(
        Violation('EXCEPTION', run.capture.exceptions.first),
      );
    }
    semantics.dispose();

    final key =
        '${row.id}::${_modeName(mode)}::${width.toInt()}::${_scaleName(scale)}';
    final found = violations.map((v) => v.code).toSet();
    final known = knownOnThisHost.keys
        .where((k) => k.startsWith('$key::'))
        .map((k) => k.substring(key.length + 2))
        .toSet();
    results.add({
      'case': key,
      'violations': [for (final v in violations) v.toString()],
    });
    final unlisted = found.difference(known);
    expect(
      unlisted,
      isEmpty,
      reason:
          '$key: ${violations.where((v) => unlisted.contains(v.code)).join('\n')}',
    );
    expect(
      known.difference(found),
      isEmpty,
      reason: '$key passes now: remove it from known_a11y_findings.dart',
    );
  }

  test('the known findings stay under the ceiling and carry tickets', () {
    final hostBound = {
      ...knownA11yFindingsLinuxOnly,
      ...knownA11yFindingsWindowsOnly,
    };
    expect(
      knownA11yFindings.length +
          knownA11yFindingsLinuxOnly.length +
          knownA11yFindingsWindowsOnly.length,
      lessThanOrEqualTo(knownA11yFindingsCeiling),
    );
    // A host-bound finding is in one list only, and only a pixel check
    // (TEXT_CONTRAST) may depend on the host.
    expect(
      hostBound.length,
      knownA11yFindingsLinuxOnly.length + knownA11yFindingsWindowsOnly.length,
    );
    for (final key in hostBound.keys) {
      expect(knownA11yFindings.containsKey(key), isFalse, reason: key);
      expect(key, endsWith('::TEXT_CONTRAST'));
    }
    for (final entry in {...knownA11yFindings, ...hostBound}.entries) {
      expect(
        RegExp(r'^BUT-\d+$').hasMatch(entry.value),
        isTrue,
        reason: '${entry.key} needs a registered BUT ticket',
      );
    }
    expect(stateHosts, isNotEmpty);
  });

  group('DEFAULT rows over widths and text scales', () {
    for (final row in rows.where((r) => r.state == 'DEFAULT')) {
      for (final mode in _modes) {
        for (final width in _widths) {
          for (final scale in _scales) {
            testWidgets(
              '${row.id} ${_modeName(mode)} ${width.toInt()} dp '
              '×${_scaleName(scale)}',
              (tester) => atFixedClock(
                tester,
                () => check(
                  tester,
                  row,
                  mode,
                  width,
                  scale,
                  layout: true,
                  contrast: width == 360 && scale == 1.0,
                ),
              ),
            );
          }
        }
      }
    }
  });

  group('LOADING, EMPTY and OFFLINE rows: targets and labels', () {
    for (final row in rows.where(
      (r) => {'LOADING', 'EMPTY', 'OFFLINE'}.contains(r.state),
    )) {
      for (final mode in _modes) {
        testWidgets(
          '${row.id} ${_modeName(mode)} 360 dp ×1.0',
          (tester) => atFixedClock(
            tester,
            () => check(
              tester,
              row,
              mode,
              360,
              1.0,
              layout: false,
              contrast: false,
            ),
          ),
        );
      }
    }
  });
}
