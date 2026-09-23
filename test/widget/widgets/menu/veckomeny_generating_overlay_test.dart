/// The week while it is planned (P4-U09).
///
/// ux-beslut.json D-03 and B-18 (beslutslogg.md:25): the plate line with
/// text replaces the animated pea pod, and there is no "Fortsätt i
/// bakgrunden". Skarmar v12 del 1 #veckogenererarpanel draws a bordered
/// panel with the step, the indeterminate line and a line on what is done.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/indicators/pea_loading_animation.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('shows the plate line with text, never the pea pod', (
    tester,
  ) async {
    late String title;
    late String subtitle;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            title = context.l10n.weekMenuPlanningTitle;
            subtitle = context.l10n.menuGeneratingSubtitle;
            return const VeckomenyGeneratingOverlay();
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(PeaLoadingOverlay), findsNothing);
    expect(find.byType(PeaLoadingAnimation), findsNothing);
    expect(find.byType(PlateLine), findsOneWidget);
    expect(
      tester.widget<PlateLine>(find.byType(PlateLine)).value,
      isNull,
      reason: 'generation is not measured, so the line is indeterminate',
    );
    expect(find.text(title), findsOneWidget);
    expect(find.text(subtitle), findsOneWidget);
    expect(title, 'Planerar veckan …');
    // D-03: no long-wait state and no background choice.
    expect(find.textContaining('bakgrund'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('the status is read once, as the line label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(child: const VeckomenyGeneratingOverlay()),
    );
    await tester.pump();

    expect(
      find.bySemanticsLabel('Planerar veckan …'),
      findsOneWidget,
      reason: 'the title is excluded so the line carries it once',
    );
    handle.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets('the border is text.primary (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('sv'),
          home: const Scaffold(body: VeckomenyGeneratingOverlay()),
        ),
      );
      await tester.pump();
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(VeckomenyGeneratingOverlay),
              matching: find.byType(Container),
            )
            .first,
      );
      final border = (box.decoration! as BoxDecoration).border! as Border;
      expect(border.top.color, theme.colorScheme.onSurface);
    });
  }
}
