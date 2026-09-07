// test/widget/common/indicators/batch_activity_bar_test.dart
//
// `BatchActivityBar` exists so that work outliving the control that started it
// still has a voice on screen (BUT-2041). Its behaviour is exercised through
// the friend-requests screen, but only in the two states that screen can reach
// — so the label override, which no caller passes yet, is pinned here, and the
// widget keeps a pin of its own the day a second screen mounts it.

library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/indicators/batch_activity_bar.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  /// The RegExp form is the portable one: a host that merges its descendants'
  /// labels answers 0 to an exact match.
  Finder labelled(String label) =>
      find.bySemanticsLabel(RegExp(RegExp.escape(label)));

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(BatchActivityBar)));

  testWidgets('an inactive bar draws no indicator and announces nothing', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(child: const BatchActivityBar(active: false)),
    );

    final l10n = l10nOf(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(labelled(l10n.a11yLoading), findsNothing);
    handle.dispose();
  });

  testWidgets('an active bar draws an indicator and announces the default '
      'loading label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(child: const BatchActivityBar(active: true)),
    );
    // Single pump, not pumpAndSettle: the indicator is indeterminate and
    // animates forever, so settling never returns.
    await tester.pump();

    final l10n = l10nOf(tester);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(labelled(l10n.a11yLoading), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a caller label REPLACES the default rather than joining it', (
    tester,
  ) async {
    const override = 'Bjuder in vännerna';

    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const BatchActivityBar(active: true, semanticLabel: override),
      ),
    );
    await tester.pump();

    final l10n = l10nOf(tester);
    expect(labelled(override), findsOneWidget);
    // The `??` is a replacement, not a fallback that also speaks: leaving the
    // default in place would make a screen reader say both.
    expect(labelled(l10n.a11yLoading), findsNothing);
    handle.dispose();
  });

  testWidgets('the announcement is a live region, so a reader speaks it '
      'unasked', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(child: const BatchActivityBar(active: true)),
    );
    await tester.pump();

    // Read off the built semantics node, not the widget property: the label
    // and the liveRegion flag land on different nodes, and only the rendered
    // tree says whether they ended up on the same one.
    expect(
      tester.getSemantics(labelled(l10nOf(tester).a11yLoading)),
      containsSemantics(isLiveRegion: true),
    );
    handle.dispose();
  });
}
