// PQ-17 and P4-U19: the shell's routes. The old ones keep working (a deep
// link to /laggTill, /veckomeny, /inkopslista or /shopping still lands), Mer
// and "Väntar på synk" get their own, and all of them are behind sign-in.
//
// AppRouter.generateRoute needs Firebase for its auth check on these routes,
// so the router's cases are pinned by reading its source, as
// root_bar_title_room_test.dart does.

import 'dart:io';

import 'package:butlery/core/constants/routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('route constants', () {
    test('Mer and the queue view are routes behind sign-in', () {
      expect(Routes.more, '/mer');
      expect(Routes.syncQueue, '/vantar-pa-synk');
      for (final route in [Routes.more, Routes.syncQueue]) {
        expect(Routes.isValidRoute(route), isTrue, reason: route);
        expect(Routes.requiresAuth(route), isTrue, reason: route);
      }
    });

    test('Mer is a tab (fade), the queue view a subpage (from the right)', () {
      expect(Routes.getAnimationType(Routes.more), RouteAnimationType.fade);
      expect(
        Routes.getAnimationType(Routes.syncQueue),
        RouteAnimationType.slideFromRight,
      );
    });

    test('the existing routes and aliases still resolve', () {
      for (final route in [
        Routes.home,
        Routes.addRecipe,
        Routes.weeklyMenu,
        Routes.shoppingList,
      ]) {
        expect(Routes.isValidRoute(route), isTrue, reason: route);
      }
      expect(Routes.resolveRoute('/shopping'), Routes.shoppingList);
      expect(Routes.resolveRoute('/home'), Routes.home);
    });
  });

  group('router cases', () {
    final code = File('lib/core/router/app_router.dart').readAsStringSync();

    String caseBody(String name) {
      final start = code.indexOf('case Routes.$name:');
      expect(start, isNonNegative, reason: 'no case for Routes.$name');
      final end = code.indexOf('case Routes.', start + 1);
      return code.substring(start, end < 0 ? code.length : end);
    }

    test('each tab route opens the shell on its own tab', () {
      expect(caseBody('home'), contains('LayoutScaffolds.homeTab'));
      expect(caseBody('weeklyMenu'), contains('LayoutScaffolds.menuTab'));
      expect(caseBody('shoppingList'), contains('LayoutScaffolds.shoppingTab'));
      expect(caseBody('more'), contains('LayoutScaffolds.moreTab'));
    });

    test('the queue view has its own case', () {
      expect(caseBody('syncQueue'), contains('SyncQueueView('));
    });

    test('/laggTill still opens the add view for old links', () {
      expect(caseBody('addRecipe'), contains('LaggTillReceptView()'));
    });
  });
}
