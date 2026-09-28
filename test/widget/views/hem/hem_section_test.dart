// HEM-HERO: Hem as drawn, in its five states.
//
//   default   Skarmar v12 del 1 #hemrecept (:124-150): date, greeting, the
//             ink "Ikväll" band with "Börja laga", "Byt rätt" and the pantry
//             line.
//   empty     del 4 #hemtom (:587-615): "Välkommen", one saffron action,
//             three shortcuts, the allergy link.
//   loading   del 4 #hemladdar (:616-650): plate line and text, a still
//             skeleton only after 300 ms.
//   offline   del 4 #hemoffline (:651-703): the plan with its fetch time.
//   error     del 4 #hemfel (:704-742): what happened, what was kept,
//             Försök igen, Öppna veckomenyn.
//
// Each in light and dark, at 320 dp and at 200 % text.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/hem/hem_viewmodel.dart';
import 'package:butlery/views/hem/hem_empty_state.dart';
import 'package:butlery/views/hem/hem_plan_states.dart';
import 'package:butlery/views/hem/hem_section.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

import '../../../infrastructure/builders/recipe_builder.dart';

// Thursday 9 July 2026 at 18:00: "God kväll".
final _now = DateTime(2026, 7, 9, 18);

const _ink = Color(0xFF24382C);
const _paper = Color(0xFFF5F4ED);
const _saffron = Color(0xFFCE7C1E);

Recipe _recipe() {
  final r =
      (RecipeBuilder()
            ..id = 'r1'
            ..title = 'Krämig svamppasta med timjan'
            ..timeMinutes = 45
            ..portions = 4)
          .build();
  r.core.ingredientsNormalized = ['svamp', 'pasta'];
  return r;
}

WeeklyMenuPlan _plan(List<WeeklyMenuPlanEntry> entries) =>
    WeeklyMenuPlan.empty(userId: 'u1', date: _now).copyWith(entries: entries);

WeeklyMenuPlanEntry _dinner(DayOfWeek day) => WeeklyMenuPlanEntry.create(
  day: day,
  slot: MealSlot.middag,
  recipeId: 'r1',
  recipeTitle: 'Krämig svamppasta med timjan',
);

/// A view model already in [status].
Future<HemViewModel> _vm(
  HemPlanStatus status, {
  DayOfWeek day = DayOfWeek.thu,
  bool online = true,
  Completer<WeeklyMenuPlanRead>? pending,
}) async {
  final vm = HemViewModel(
    readWeek: (_) async {
      if (pending != null) return pending.future;
      return WeeklyMenuPlanRead(
        plan: _plan([_dinner(day)]),
        readFailed: status == HemPlanStatus.failed,
      );
    },
    recipeById: (id) => id == 'r1' ? _recipe() : null,
    pantryIngredientIds: () async => {'svamp', 'pasta', 'salt'},
    isOnline: () => online,
  );
  if (status != HemPlanStatus.loading) {
    await withClock(Clock.fixed(_now), vm.load);
  }
  return vm;
}

class _Calls {
  final List<Recipe> cooked = [];
  int openedMenu = 0;
}

Widget _app(
  Widget child, {
  ThemeData? theme,
  double width = 412,
  double textScale = 1,
}) => MaterialApp(
  theme: theme ?? AppTheme.lightTheme,
  locale: const Locale('sv'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  onGenerateRoute: (settings) => MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => Scaffold(body: Text('route ${settings.name}')),
  ),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  ),
);

/// Hem's top as the view mounts it: the header of a scroll view.
Widget _section(
  HemViewModel vm,
  _Calls calls, {
  bool libraryEmpty = false,
  bool online = true,
}) => Scaffold(
  body: CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: HemSection(
          viewModel: vm,
          now: _now,
          firstName: 'Malin',
          libraryEmpty: libraryEmpty,
          isOnline: online,
          onStartCooking: calls.cooked.add,
          onOpenMenu: () => calls.openedMenu++,
        ),
      ),
    ],
  ),
);

/// Filled buttons whose resting fill is saffron.
int _saffronCount(WidgetTester tester) => tester
    .widgetList<ButtonStyleButton>(
      find.byWidgetPredicate((w) => w is ButtonStyleButton),
    )
    .where(
      (b) =>
          b.style?.backgroundColor?.resolve(const {}) ==
          AppModeColors.actionPrimary(Brightness.light),
    )
    .length;

void main() {
  const modes = [('light', Brightness.light), ('dark', Brightness.dark)];
  ThemeData themeOf(Brightness b) =>
      b == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;

  group('default (#hemrecept)', () {
    for (final (mode, b) in modes) {
      testWidgets('greeting, date and the ink band ($mode)', (tester) async {
        final vm = await _vm(HemPlanStatus.ready);
        final calls = _Calls();
        await tester.pumpWidget(
          _app(_section(vm, calls), theme: themeOf(b)),
        );
        await tester.pumpAndSettle();

        // produktregler.md:278-279.
        expect(find.text('God kväll, Malin'), findsOneWidget);
        expect(find.text('TORSDAG 9 JULI'), findsOneWidget);
        expect(find.bySemanticsLabel('Torsdag 9 juli'), findsOneWidget);

        // The band is ink in both modes; the title paper.
        final card = tester.widget<Container>(
          find.byKey(HemTonightCard.cardKey),
        );
        expect(card.color, _ink);
        final title = tester.widget<Text>(
          find.byKey(const ValueKey('hem-tonight-title')),
        );
        expect(title.data, 'Krämig svamppasta med timjan');
        expect(title.style?.color, _paper);
        final eyebrow = tester.widget<Text>(
          find.text('IKVÄLL · 45 MIN · 4 PORT.'),
        );
        // Skarmar v12 del 1:47 (--r04slot-765): #e09d50 light, #dca968
        // dark, which is text.accent (produktbeslut R6-01 = A, BUT-2197).
        expect(
          eyebrow.style?.color,
          b == Brightness.dark
              ? const Color(0xFFDCA968)
              : const Color(0xFFE09D50),
        );
        expect(eyebrow.style?.color, ModeColors.of(b).accentOnInk);

        // "allt i skafferiet" only because every ingredient is at home.
        final pantry = tester.widget<Text>(
          find.byKey(const ValueKey('hem-all-in-pantry')),
        );
        expect(pantry.data, 'allt i skafferiet');
        expect(pantry.style?.color, AppModeColors.textSecondaryOnInk());

        // One saffron hero (Grafisk manual v6:219), "Börja laga".
        expect(_saffronCount(tester), 1);
        expect(
          find.descendant(
            of: find.byKey(HemTonightCard.startCookingKey),
            matching: find.text('Börja laga'),
          ),
          findsOneWidget,
        );
        final swap = tester.widget<OutlinedButton>(
          find.byKey(HemTonightCard.swapKey),
        );
        expect(swap.style?.foregroundColor?.resolve(const {}), _paper);
        expect(
          swap.style?.side?.resolve(const {})?.color,
          _paper.withValues(alpha: 0.35),
        );
        vm.dispose();
      });
    }

    testWidgets('Börja laga cooks the planned recipe; Byt rätt opens the '
        'menu', (tester) async {
      final vm = await _vm(HemPlanStatus.ready);
      final calls = _Calls();
      await tester.pumpWidget(_app(_section(vm, calls)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(HemTonightCard.startCookingKey));
      expect(calls.cooked.single.id, 'r1');
      await tester.tap(find.byKey(HemTonightCard.swapKey));
      expect(calls.openedMenu, 1);
      vm.dispose();
    });

    testWidgets('a later day is marked with its weekday, never Ikväll', (
      tester,
    ) async {
      final vm = await _vm(HemPlanStatus.ready, day: DayOfWeek.sat);
      await tester.pumpWidget(_app(_section(vm, _Calls())));
      await tester.pumpAndSettle();

      expect(find.text('LÖRDAG · 45 MIN · 4 PORT.'), findsOneWidget);
      expect(find.textContaining('IKVÄLL'), findsNothing);
      vm.dispose();
    });
  });

  group('empty (#hemtom)', () {
    for (final (mode, b) in modes) {
      testWidgets('Välkommen, one saffron action, three shortcuts ($mode)', (
        tester,
      ) async {
        final vm = await _vm(HemPlanStatus.ready);
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: Column(
                children: [
                  HemSection(
                    viewModel: vm,
                    now: _now,
                    firstName: 'Malin',
                    libraryEmpty: true,
                    isOnline: true,
                    onStartCooking: (_) {},
                    onOpenMenu: () {},
                  ),
                  const Expanded(child: HemEmptyState()),
                ],
              ),
            ),
            theme: themeOf(b),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Välkommen, Malin'), findsOneWidget);
        expect(find.byKey(HemTonightCard.cardKey), findsNothing);
        expect(_saffronCount(tester), 1);
        expect(find.byKey(HemEmptyState.addRecipeKey), findsOneWidget);
        for (final route in [
          Routes.smartImport,
          Routes.photoImport,
          Routes.manualEntry,
        ]) {
          expect(find.byKey(ValueKey('hem-shortcut-$route')), findsOneWidget);
        }
        expect(find.text('Ställ in allergener'), findsOneWidget);
        vm.dispose();
      });
    }

    testWidgets('a shortcut opens its own route', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: HemEmptyState())));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('hem-shortcut-${Routes.photoImport}')),
      );
      await tester.pumpAndSettle();
      expect(find.text('route ${Routes.photoImport}'), findsOneWidget);
    });
  });

  group('loading (#hemladdar)', () {
    for (final (mode, b) in modes) {
      testWidgets('plate line with its text; the skeleton only after 300 ms '
          '($mode)', (tester) async {
        final pending = Completer<WeeklyMenuPlanRead>();
        final vm = await _vm(HemPlanStatus.loading, pending: pending);
        await tester.pumpWidget(
          _app(_section(vm, _Calls()), theme: themeOf(b)),
        );

        final line = tester.widget<PlateLine>(find.byType(PlateLine));
        expect(line.semanticLabel, 'Hämtar veckans plan …');
        expect(find.text('Hämtar veckans plan …'), findsOneWidget);
        expect(find.byKey(HemPlanLoading.skeletonKey), findsNothing);

        await tester.pump(const Duration(milliseconds: 299));
        expect(find.byKey(HemPlanLoading.skeletonKey), findsNothing);
        await tester.pump(const Duration(milliseconds: 2));
        expect(find.byKey(HemPlanLoading.skeletonKey), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        vm.dispose();
      });
    }
  });

  group('offline (#hemoffline)', () {
    for (final (mode, b) in modes) {
      testWidgets('the plan carries when it was fetched ($mode)', (
        tester,
      ) async {
        final vm = await _vm(HemPlanStatus.ready);
        await tester.pumpWidget(
          _app(_section(vm, _Calls(), online: false), theme: themeOf(b)),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(HemTonightCard.cardKey), findsOneWidget);
        expect(
          find.text(
            'Planen hämtades 18:00 – kan ha ändrats av någon annan sedan dess.',
          ),
          findsOneWidget,
        );
        vm.dispose();
      });
    }

    testWidgets('online, no fetch line', (tester) async {
      final vm = await _vm(HemPlanStatus.ready);
      await tester.pumpWidget(_app(_section(vm, _Calls())));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('hem-fetched-at')), findsNothing);
      vm.dispose();
    });
  });

  group('error (#hemfel)', () {
    for (final (mode, b) in modes) {
      testWidgets('what happened and what to do, nothing unverified ($mode)', (
        tester,
      ) async {
        final vm = await _vm(HemPlanStatus.failed);
        final calls = _Calls();
        await tester.pumpWidget(
          _app(_section(vm, calls), theme: themeOf(b)),
        );
        await tester.pumpAndSettle();

        final error = tester.widget<InlineError>(find.byType(InlineError));
        expect(error.what, 'Veckans plan kunde inte hämtas.');
        // The read cannot tell whether a plan was saved, so the box never
        // claims it was.
        expect(error.preserved, isNull);
        expect(
          find.descendant(
            of: find.byKey(HemPlanError.retryKey),
            matching: find.text('Försök igen'),
          ),
          findsOneWidget,
        );
        expect(find.byKey(HemTonightCard.cardKey), findsNothing);
        // The greeting stands: an error never empties the view.
        expect(find.text('God kväll, Malin'), findsOneWidget);

        await tester.tap(find.byKey(HemPlanError.showSavedPlanKey));
        expect(calls.openedMenu, 1);

        // Försök igen reads the week again.
        await tester.tap(find.byKey(HemPlanError.retryKey));
        await tester.pumpAndSettle();
        expect(vm.status, HemPlanStatus.failed);
        vm.dispose();
      });
    }
  });

  group('320 dp at 200 % text', () {
    Future<void> pumpNarrow(WidgetTester tester, Widget child, Brightness b) {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(
        _app(child, theme: themeOf(b), width: 320, textScale: 2),
      );
    }

    for (final (mode, b) in modes) {
      for (final status in HemPlanStatus.values) {
        testWidgets('${status.name} fits ($mode)', (tester) async {
          final pending = Completer<WeeklyMenuPlanRead>();
          final vm = await _vm(
            status,
            pending: status == HemPlanStatus.loading ? pending : null,
          );
          await pumpNarrow(tester, _section(vm, _Calls(), online: false), b);
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          vm.dispose();
        });
      }

      testWidgets('the empty state fits ($mode)', (tester) async {
        await pumpNarrow(tester, const Scaffold(body: HemEmptyState()), b);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('the saffron fill is the same in both modes', (tester) async {
    expect(AppModeColors.actionPrimary(Brightness.dark), _saffron);
    expect(AppModeColors.actionPrimary(Brightness.light), _saffron);
  });
}
