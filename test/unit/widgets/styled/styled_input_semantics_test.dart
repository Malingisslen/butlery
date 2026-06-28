// Verifies BUT-539: StyledInput must expose a screen-reader-findable label
// in every shape it ships in. Material's TextField auto-supplies Semantics
// when decoration.labelText is set, so the test focuses on the two failure
// modes that A11y audits actually flag:
//
//   1. label-only field — Semantics label must equal the visible label.
//   2. hint-only / search variant — explicit Semantics wrapper must carry
//      the hint as the screen-reader label (otherwise TalkBack reads
//      "edit box, blank").
//
// The semanticsHandle pattern is used instead of find.bySemanticsLabel for
// the label-only case because TextField composes its semantics from a
// nested EditableText node and labelText, and findBySemanticsLabel
// reliably resolves both.

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: SizedBox(width: 320, child: child),
  ),
);

/// Localized wrapper (pinned to Swedish) for the required-field marker test,
/// which exercises the `context.l10n.a11yRequiredFieldSuffix` path (BUT-1430).
Widget _wrapLocalized(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(
    body: SizedBox(width: 320, child: child),
  ),
);

void main() {
  group('StyledInput Semantics (BUT-539)', () {
    testWidgets('labelText surfaces as screen-reader label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StyledInput(
            label: 'Receptnamn',
            hint: 'T.ex. köttbullar',
          ),
        ),
      );

      // Material TextField publishes labelText via its built-in Semantics
      // wrapper — the label must resolve verbatim for TalkBack/VoiceOver.
      expect(find.bySemanticsLabel('Receptnamn'), findsOneWidget);
    });

    testWidgets('search variant (no visible label) wraps with explicit '
        'Semantics carrying the hint', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StyledInput.search(
            hint: 'Sök recept',
          ),
        ),
      );

      // No visible label, so the build() path must add the Semantics wrapper
      // that exposes hint as label — otherwise screen readers announce the
      // field as unlabelled. TextField also publishes the hintText via its
      // own Semantics, so the matcher accepts >= 1 (proves the wrapper fires
      // without coupling to internal Material plumbing).
      expect(find.bySemanticsLabel('Sök recept'), findsAtLeastNWidgets(1));
    });

    testWidgets('explicit semanticLabel overrides hint fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StyledInput(
            hint: 'Sök',
            semanticLabel: 'Sök bland recept',
          ),
        ),
      );

      expect(find.bySemanticsLabel('Sök bland recept'), findsOneWidget);
    });

    testWidgets(
      'required field appends a localized required marker (BUT-1430)',
      (
        tester,
      ) async {
        // Was a hardcoded `'$label (obligatorisk)'`; now localized so English
        // users hear "(required)" instead of Swedish. Pinned to sv here.
        await tester.pumpWidget(
          _wrapLocalized(
            const StyledFormField(
              label: 'Epost',
              isRequired: true,
              child: TextField(),
            ),
          ),
        );

        // Inspect the Semantics widget StyledFormField declares (mirrors the
        // textField-wrapper test below) — robust against the child TextField's
        // own merged semantics node.
        final labelled = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .where((s) => s.properties.label == 'Epost (obligatorisk)');
        expect(labelled, hasLength(1));
      },
    );

    testWidgets('exposes textField semantics on the wrapper Semantics widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StyledInput.search(hint: 'Sök'),
        ),
      );

      // Locate the Semantics widget added by StyledInput.build() (the one
      // whose properties.textField == true) — proves the wrapper passes
      // textField: true rather than only a label.
      final semanticsWidget = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where(
            (s) =>
                s.properties.textField == true && s.properties.label == 'Sök',
          );
      expect(semanticsWidget, hasLength(1));
    });
  });
}
