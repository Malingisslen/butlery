/// P6-U01: flow 01 on the week menu (flows-roles-budget.md:24-38).
///
/// Each group is named after its transition in
/// fas2/block288-uxfrysning.json:
/// - TR::FLOW::01::genererar::0-recept-placerade: nothing matched is its own
///   state, "Inga recept matchar" (Skarmar v12 del 1 #veckoingamatch), never
///   "Ett fel uppstod".
/// - TR::FLOW::01::genererar::offline: Generera is switched off with the
///   reason in text; nothing starts, so nothing is saved
///   (produktregler.md:1131).
///
/// The 6 s subtitle (TR::FLOW::01::genererar::6-10-s) is pinned in
/// test/widget/widgets/menu/veckomeny_generating_overlay_test.dart, the
/// partial result and the conflict snackbar in
/// test/widget/views/veckomeny_partial_and_conflict_test.dart.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/views/veckomeny_view.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';

/// Connectivity the test can flip.
class _FakeOffline extends ChangeNotifier implements OfflineService {
  _FakeOffline({required this.online});

  bool online;

  @override
  bool get isOnline => online;

  void set(bool value) {
    online = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.lightTheme,
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: child),
);

void main() {
  group('TR::FLOW::01::genererar::0-recept-placerade', () {
    testWidgets('says what stopped it and offers two ways on', (tester) async {
      var edits = 0;
      var plans = 0;
      await tester.pumpWidget(
        _app(
          VeckomenyNoMatch(
            outcome: const MenuNoMatchOutcome(
              poolSize: 84,
              constraints: ['Under 30 min', 'Vegetariskt'],
            ),
            onEditPrompt: () => edits++,
            onPlanYourself: () => plans++,
          ),
        ),
      );

      expect(find.text('Inga recept matchar'), findsOneWidget);
      expect(
        find.text(
          'Beskrivningen ger noll träffar bland dina 84 recept. Ändra eller '
          'släpp ett krav så hittar vi förslag.',
        ),
        findsOneWidget,
      );
      expect(find.text('Kraven: Under 30 min, Vegetariskt'), findsOneWidget);
      expect(find.textContaining('Ett fel uppstod'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      // The view's one saffron action stays Generera.
      expect(find.byType(HeroButton), findsNothing);

      await tester.tap(find.byKey(VeckomenyNoMatch.editPromptKey));
      await tester.tap(find.byKey(VeckomenyNoMatch.planYourselfKey));
      expect(edits, 1);
      expect(plans, 1);
    });

    testWidgets('without read requirements the line is left out', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          VeckomenyNoMatch(
            outcome: const MenuNoMatchOutcome(poolSize: 1, constraints: []),
            onEditPrompt: () {},
            onPlanYourself: () {},
          ),
        ),
      );

      expect(find.textContaining('Kraven'), findsNothing);
      expect(
        find.textContaining('ingen träff på ditt enda recept'),
        findsOneWidget,
      );
    });
  });

  group('TR::FLOW::01::genererar::offline', () {
    late _FakeOffline offline;

    setUp(() async {
      await GetIt.instance.reset();
      offline = _FakeOffline(online: false);
      GetIt.instance.registerSingleton<OfflineService>(offline);
      prod.ServiceLocator.initialize(DIContainer());
    });

    tearDown(() async {
      prod.ServiceLocator.reset();
      await GetIt.instance.reset();
    });

    Widget button(VoidCallback onGenerate, {ThemeData? theme}) => _app(
      VeckomenyGenerateButton(
        label: 'Generera',
        busy: false,
        busyLabel: 'Planerar veckan …',
        onGenerate: onGenerate,
      ),
      theme: theme,
    );

    for (final (mode, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('offline, Generera is off and says why; a tap starts '
          'nothing ($mode)', (tester) async {
        var generated = 0;
        await tester.pumpWidget(button(() => generated++, theme: theme));

        final hero = tester.widget<HeroButton>(find.byType(HeroButton));
        expect(hero.onPressed, isNull);
        final reason = tester.widget<Text>(
          find.byKey(VeckomenyGenerateButton.offlineReasonKey),
        );
        expect(
          reason.data,
          'Ingen anslutning, så veckan kan inte planeras nu. Kalendern går att '
          'ändra som vanligt.',
        );
        // text.secondary in both modes.
        expect(reason.style!.color, theme.colorScheme.onSurfaceVariant);

        await tester.tap(find.byType(HeroButton), warnIfMissed: false);
        await tester.pump();
        expect(generated, 0, reason: 'no generation, so no save');
      });
    }

    testWidgets('back online, Generera comes back and the reason goes', (
      tester,
    ) async {
      var generated = 0;
      await tester.pumpWidget(button(() => generated++));
      expect(VeckomenyConnectivity.isOnlineNow(), isFalse);

      offline.set(true);
      await tester.pump();

      expect(
        find.byKey(VeckomenyGenerateButton.offlineReasonKey),
        findsNothing,
      );
      await tester.tap(find.byType(HeroButton));
      await tester.pump();
      expect(generated, 1);
    });
  });
}
