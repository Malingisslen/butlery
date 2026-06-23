// test/widget/a11y/announce_channel_harness_test.dart
//
// BUT-1210: smoke tests for the announce-channel harness itself. If these go
// red, every per-site announce test built on the harness is suspect — so prove
// the interceptor actually captures a raw `SemanticsService.announce` and that
// the live-l10n resolution pattern the per-site tests rely on works.

library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

import '../../infrastructure/helpers/announce_channel.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('AnnounceChannel harness', () {
    testWidgets(
      'captures a raw SemanticsService.sendAnnouncement payload (real channel, not a stub)',
      (tester) async {
        // Proves: the harness intercepts the actual flutter/accessibility channel
        // that production SemanticsService.sendAnnouncement writes to.
        final announces = AnnounceChannel.arm(tester);
        await tester.pumpWidget(
          createLocalizedTestApp(child: const SizedBox()),
        );

        SemanticsService.sendAnnouncement(
          tester.view,
          'hej',
          TextDirection.ltr,
        );
        await tester.pump();

        expect(announces.messages, ['hej']);
        expect(announces.last, 'hej');
        expect(announces.count, 1);
      },
    );

    testWidgets('resolves the expected value from the live AppLocalizations', (
      tester,
    ) async {
      // Proves: the per-site tests can assert against the live l10n value
      // (survives ARB copy edits) rather than a hardcoded literal.
      final announces = AnnounceChannel.arm(tester);
      late AppLocalizations l10n;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox();
            },
          ),
        ),
      );

      SemanticsService.sendAnnouncement(
        tester.view,
        l10n.a11yOcrComplete,
        TextDirection.ltr,
      );
      await tester.pump();

      expect(announces.messages, [l10n.a11yOcrComplete]);
      // Swedish locale is pinned by createLocalizedTestApp — sanity-check it.
      expect(l10n.a11yOcrComplete, 'Textavläsning klar');
    });

    testWidgets('reset() forgets captured messages but keeps intercepting', (
      tester,
    ) async {
      // Proves: the "assert no FURTHER announce" idiom the announce-once guard
      // test relies on works — reset clears history without tearing down.
      final announces = AnnounceChannel.arm(tester);
      await tester.pumpWidget(createLocalizedTestApp(child: const SizedBox()));

      SemanticsService.sendAnnouncement(tester.view, 'one', TextDirection.ltr);
      await tester.pump();
      announces.reset();
      expect(announces.messages, isEmpty);

      SemanticsService.sendAnnouncement(tester.view, 'two', TextDirection.ltr);
      await tester.pump();
      expect(announces.messages, ['two']);
    });

    testWidgets('dispose() stops capturing further announcements', (
      tester,
    ) async {
      // Proves: teardown actually removes the handler (no leak across tests).
      final announces = AnnounceChannel.arm(tester);
      await tester.pumpWidget(createLocalizedTestApp(child: const SizedBox()));

      announces.dispose();
      SemanticsService.sendAnnouncement(
        tester.view,
        'after-dispose',
        TextDirection.ltr,
      );
      await tester.pump();

      expect(announces.messages, isEmpty);
    });
  });
}
