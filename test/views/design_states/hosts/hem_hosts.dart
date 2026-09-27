/// P8-U01 hosts: Hem (four rows), re-anchored to lib/views/hem/* (AGARE_NU).
///
/// Mina recept (lib/views/mina_recept_view.dart:420-460) stacks the offline
/// banner, then Hem's section over the library in HemLibraryScroll. That
/// view needs six view models and no test in the repo pumps it, so the
/// harness stacks the same three parts the same way: the real banner
/// (LayoutComponents.offlineIndicator), the real HemSection with a real
/// HemViewModel over fake reads, and HemLibraryScroll. The library body is
/// the empty state where the library is empty (mina_recept_view.dart:693)
/// and an empty list otherwise: the library's rows are not part of Hem's
/// state.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/viewmodels/hem/hem_viewmodel.dart';
import 'package:butlery/views/hem/hem_empty_state.dart';
import 'package:butlery/views/hem/hem_library_scroll.dart';
import 'package:butlery/views/hem/hem_section.dart';
import 'package:butlery/widgets/common/layout_components.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../state_host.dart';

/// Thursday 9 July 2026, 18:00: "God kväll".
final hemNow = DateTime(2026, 7, 9, 18);

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

WeeklyMenuPlan _plan() =>
    WeeklyMenuPlan.empty(userId: 'u1', date: hemNow).copyWith(
      entries: [
        WeeklyMenuPlanEntry.create(
          day: DayOfWeek.thu,
          slot: MealSlot.middag,
          recipeId: 'r1',
          recipeTitle: 'Krämig svamppasta med timjan',
        ),
      ],
    );

Future<HemViewModel> _vm(
  HostContext ctx, {
  required bool online,
  bool loading = false,
}) async {
  final pending = Completer<WeeklyMenuPlanRead>();
  final vm = HemViewModel(
    readWeek: (_) async => loading
        ? pending.future
        : WeeklyMenuPlanRead(plan: _plan(), readFailed: false),
    recipeById: (id) => id == 'r1' ? _recipe() : null,
    pantryIngredientIds: () async => {'svamp', 'pasta', 'salt'},
    isOnline: () => online,
  );
  if (!loading) await withClock(Clock.fixed(hemNow), vm.load);
  ctx.disposers.add(vm.dispose);
  return vm;
}

Widget _hemScreen(
  HemViewModel vm, {
  required bool online,
  required bool libraryEmpty,
}) => Scaffold(
  body: SafeArea(
    bottom: false,
    child: Column(
      children: [
        LayoutComponents.offlineIndicator(),
        Expanded(
          child: HemLibraryScroll(
            header: HemSection(
              viewModel: vm,
              now: hemNow,
              firstName: 'Malin',
              libraryEmpty: libraryEmpty,
              isOnline: online,
              onStartCooking: (_) {},
              onOpenMenu: () {},
            ),
            body: libraryEmpty
                ? const HemEmptyState()
                : ListView(primary: true, children: const []),
          ),
        ),
      ],
    ),
  ),
);

final hemHosts = <String, StateHost>{
  'hem::DEFAULT': StateHost(
    build: (ctx) async => _hemScreen(
      await _vm(ctx, online: true),
      online: true,
      libraryEmpty: false,
    ),
  ),
  'hem::EMPTY': StateHost(
    build: (ctx) async => _hemScreen(
      await _vm(ctx, online: true),
      online: true,
      libraryEmpty: true,
    ),
  ),
  'hem::LOADING': StateHost(
    build: (ctx) async => _hemScreen(
      await _vm(ctx, online: true, loading: true),
      online: true,
      libraryEmpty: false,
    ),
    reach: (tester, ctx) async {
      // The first read is pending: HemViewModel starts in loading.
    },
  ),
  'hem::OFFLINE': StateHost(
    online: false,
    build: (ctx) async => _hemScreen(
      await _vm(ctx, online: false),
      online: false,
      libraryEmpty: false,
    ),
  ),
};
