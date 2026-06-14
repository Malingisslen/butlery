/// Behaviour test for the BUT-1258-extracted [VeckomenyGeneratingOverlay].
///
/// The overlay is a thin wrapper whose ONLY job is to wire the two
/// generation-status strings into a [PeaLoadingOverlay]: the message
/// (`menuGeneratingOverlay`) and the subtitle (`menuGeneratingSubtitle`).
///
/// Intent: prove that while a menu is generating the user actually sees the
/// generating message and its subtitle. If a future edit swapped in the wrong
/// l10n key (or dropped the subtitle), this fails. Strings are resolved through
/// the live `context.l10n` rather than hardcoded, so a copy tweak to the Swedish
/// text won't break it — only a wrong-key regression will.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/indicators/pea_loading_animation.dart';
import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets(
      'surfaces the generating message and subtitle through PeaLoadingOverlay',
      (tester) async {
    String? expectedMessage;
    String? expectedSubtitle;

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(builder: (context) {
          // Capture the exact strings the app's localization resolves, so the
          // assertions track the ARB without hardcoding Swedish copy.
          expectedMessage = context.l10n.menuGeneratingOverlay;
          expectedSubtitle = context.l10n.menuGeneratingSubtitle;
          return const VeckomenyGeneratingOverlay();
        }),
      ),
    );
    await tester.pump();

    // The wrapper must delegate to PeaLoadingOverlay (the branded loader);
    // anything else means a user mid-generation sees the wrong chrome.
    expect(find.byType(PeaLoadingOverlay), findsOneWidget);

    // Both status lines must be visible to the user during generation.
    expect(find.text(expectedMessage!), findsOneWidget,
        reason: 'the generating message must be shown');
    expect(find.text(expectedSubtitle!), findsOneWidget,
        reason: 'the generating subtitle must be shown');
  });
}
