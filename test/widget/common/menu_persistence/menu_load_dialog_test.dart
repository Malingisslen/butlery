/// Widget tests for LoadMenuBottomSheet (menu_load_dialog.dart).
///
/// Covers the four observable behaviours:
///   1. Initial render shows the localized header + close button.
///   2. While `refreshSavedMenus` is in flight, a spinner is shown.
///   3. Empty result list renders the StateWidget.empty branch with the
///      localized "Inga sparade menyer" copy.
///   4. Populated result list renders one ListTile per saved menu and the
///      onTap callback invokes `viewModel.loadSavedMenu(menu.key)`.
///
/// The viewmodel is faked via mocktail; we don't drive the SnackBar /
/// Navigator side effects since those traverse Scaffold descendants — they
/// are exercised by integration tests. See SKIP comments below.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/viewmodels/menu/menu_state_manager.dart';
import 'package:butlery/widgets/common/menu_persistence/menu_load_dialog.dart';
import 'package:butlery/widgets/common/state_widget.dart';

class _FakeMenuViewModel extends Mock implements MenuViewModel {}

/// Wraps the sheet in a MaterialApp with Swedish l10n so `context.l10n.*` works.
/// Scaffold is included because `_loadMenu` calls `ScaffoldMessenger.of`.
Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

SavedMenuInfo _menu({
  String key = 'k1',
  String name = 'Veckomeny',
  int recipeCount = 5,
  String comment = '',
}) => SavedMenuInfo(
  key: key,
  name: name,
  savedDate: DateTime(2026, 5, 23),
  recipeCount: recipeCount,
  comment: comment,
);

void main() {
  group('LoadMenuBottomSheet', () {
    testWidgets('renders header with title and close button after load', (
      tester,
    ) async {
      final vm = _FakeMenuViewModel();
      when(() => vm.refreshSavedMenus()).thenAnswer((_) async {});
      when(() => vm.savedMenus).thenReturn(<SavedMenuInfo>[]);

      await tester.pumpWidget(_wrap(LoadMenuBottomSheet(viewModel: vm)));
      await tester.pumpAndSettle();

      // Swedish locale: "Sparade menyer" + "Stäng"
      expect(find.text('Sparade menyer'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Stäng'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
    });

    testWidgets(
      'shows CircularProgressIndicator while refreshSavedMenus is in flight',
      (tester) async {
        final vm = _FakeMenuViewModel();
        final completer = Completer<void>();
        when(() => vm.refreshSavedMenus()).thenAnswer((_) => completer.future);
        when(() => vm.savedMenus).thenReturn(<SavedMenuInfo>[]);

        await tester.pumpWidget(_wrap(LoadMenuBottomSheet(viewModel: vm)));
        // One frame for initState's setState(_isLoading = true) to land.
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Unblock so pumpAndSettle in subsequent assertions doesn't hang.
        completer.complete();
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets('empty saved-menus list renders the StateWidget.empty branch', (
      tester,
    ) async {
      final vm = _FakeMenuViewModel();
      when(() => vm.refreshSavedMenus()).thenAnswer((_) async {});
      when(() => vm.savedMenus).thenReturn(<SavedMenuInfo>[]);

      await tester.pumpWidget(_wrap(LoadMenuBottomSheet(viewModel: vm)));
      await tester.pumpAndSettle();

      // "Inga sparade menyer" comes from menuNoSavedMenus, "Stäng" from
      // commonClose (used by both header AND empty-state action button → 2x).
      expect(find.text('Inga sparade menyer'), findsOneWidget);
      expect(find.byType(StateWidget), findsOneWidget);
      // Header close + StateWidget close action = 2 occurrences.
      expect(find.text('Stäng'), findsNWidgets(2));
    });

    testWidgets('populated list renders one Card+ListTile per saved menu', (
      tester,
    ) async {
      final vm = _FakeMenuViewModel();
      when(() => vm.refreshSavedMenus()).thenAnswer((_) async {});
      when(() => vm.savedMenus).thenReturn([
        _menu(key: 'a', name: 'Veckomeny v.45'),
        _menu(key: 'b', name: 'Helgmiddag'),
      ]);

      await tester.pumpWidget(_wrap(LoadMenuBottomSheet(viewModel: vm)));
      await tester.pumpAndSettle();

      expect(find.text('Veckomeny v.45'), findsOneWidget);
      expect(find.text('Helgmiddag'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(2));
      // Subtitle uses menuSavedEarlier = "Sparad tidigare", one per tile.
      expect(find.text('Sparad tidigare'), findsNWidgets(2));
    });

    // SKIP: SavedMenuInfo.name is a non-nullable String, but the production
    // widget defensively coalesces `menu.name ?? l10n.menuUnnamed` because the
    // parameter type is `dynamic`. Exercising the null branch requires either
    // a List<dynamic> typed contrary to the savedMenus getter, or modifying
    // production. Branch is dead-code-ish; not worth the scaffolding.
    testWidgets(
      'null menu.name fallback to "Namnlös meny" (SKIP — dead branch)',
      skip: true,
      (tester) async {},
    );

    testWidgets(
      'tapping a list item invokes viewModel.loadSavedMenu with the menu key',
      (tester) async {
        final vm = _FakeMenuViewModel();
        when(() => vm.refreshSavedMenus()).thenAnswer((_) async {});
        when(
          () => vm.savedMenus,
        ).thenReturn([_menu(key: 'menu-42', name: 'Måndag')]);
        // success branch resolves; Navigator.pop is invoked too — Scaffold +
        // dialog route absent so the pop is a no-op route-pop on root.
        when(() => vm.loadSavedMenu('menu-42')).thenAnswer((_) async => true);
        when(() => vm.error).thenReturn(null);

        await tester.pumpWidget(_wrap(LoadMenuBottomSheet(viewModel: vm)));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Måndag'));
        await tester.pump(); // allow async gap
        await tester.pump();

        verify(() => vm.loadSavedMenu('menu-42')).called(1);
      },
    );

    testWidgets(
      'PopupMenuButton "Ladda" option also delegates to loadSavedMenu',
      (tester) async {
        final vm = _FakeMenuViewModel();
        when(() => vm.refreshSavedMenus()).thenAnswer((_) async {});
        when(() => vm.savedMenus).thenReturn([_menu(key: 'k1', name: 'M1')]);
        when(() => vm.loadSavedMenu('k1')).thenAnswer((_) async => true);
        when(() => vm.error).thenReturn(null);

        await tester.pumpWidget(_wrap(LoadMenuBottomSheet(viewModel: vm)));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();

        // Popup label "Ladda meny" comes from menuLoad
        expect(find.text('Ladda meny'), findsOneWidget);
        await tester.tap(find.text('Ladda meny'));
        await tester.pump();
        await tester.pump();

        verify(() => vm.loadSavedMenu('k1')).called(1);
      },
    );

    // SKIP: deletion confirmation dialog navigates through showDialog<bool>
    // which composes a second route. Testing the end-to-end delete branch
    // requires driving the AlertDialog inside the bottom sheet AND mocking
    // the SnackBar; the value-vs-noise tradeoff is poor for a pure widget
    // test. The flow is exercised by integration tests.
    testWidgets(
      'delete branch end-to-end (SKIP — dialog-on-dialog flow)',
      skip: true,
      (tester) async {},
    );
  });
}
