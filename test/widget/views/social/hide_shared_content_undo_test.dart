/// P3-U10 (PQ-07 = A, produktbeslut 2026-09-23): "Dölj delat innehåll" keeps
/// its confirmation question and its Ångra, but Ångra goes through the undo
/// primitive and leaves after the 7 s window like every other undo
/// (produktregler.md:131-132; SnackBarUtils.showUndo / UndoSnackBar).
///
/// Pinned on both call sites: the shared-with-me actions (the snackbar stays
/// on the same view) and the shared menu preview (the view pops right after,
/// so the snackbar must be shown on the view below).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/undo_window.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_menu_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_recipe_viewmodel.dart';
import 'package:butlery/views/social/menu_preview_view.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_actions.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockCoordinator extends Mock
    implements SharedContentCoordinatorViewModel {}

class _MockRecipeViewModel extends Mock implements SharedRecipeViewModel {}

class _MockMenuViewModel extends Mock implements SharedMenuViewModel {}

class _MockRealtimeSyncService extends Mock implements RealtimeSyncService {}

class _FakeSharedRecipe extends Fake implements SharedRecipe {}

class _FakeSharedMenu extends Fake implements SharedMenu {}

void main() {
  late _MockCoordinator coordinator;
  late _MockRecipeViewModel recipes;
  late _MockMenuViewModel menus;

  final recipe = SharedRecipe(
    id: 'share-1',
    sharedByUserId: 'u-anna',
    sharedByDisplayName: 'Anna',
    originalRecipeId: 'r-1',
    recipeTitle: 'Citronrisotto',
  );

  final menu = SharedMenu(
    id: 'menu-1',
    sharedByUserId: 'u-anna',
    sharedByDisplayName: 'Anna',
    menuTitle: 'Snabb vardag',
    menuSnapshot: const {},
  );

  setUpAll(() {
    registerFallbackValue(_FakeSharedRecipe());
    registerFallbackValue(_FakeSharedMenu());
  });

  setUp(() async {
    await GetIt.instance.reset();
    // MenuPreviewView mounts the ConflictBanner, which reads the realtime
    // service through the production locator.
    final realtime = _MockRealtimeSyncService();
    when(
      () => realtime.conflictStream,
    ).thenAnswer((_) => const Stream.empty());
    GetIt.instance.registerSingleton<RealtimeSyncService>(realtime);
    prod.ServiceLocator.initialize(DIContainer());

    recipes = _MockRecipeViewModel();
    when(
      () => recipes.dismissSharedRecipe(any()),
    ).thenAnswer((_) async => true);
    when(
      () => recipes.undismissSharedRecipe(any()),
    ).thenAnswer((_) async => true);
    when(() => recipes.hasError).thenReturn(false);

    menus = _MockMenuViewModel();
    when(() => menus.dismissSharedMenu(any())).thenAnswer((_) async => true);
    when(() => menus.undismissSharedMenu(any())).thenAnswer((_) async => true);
    when(() => menus.hasError).thenReturn(false);
    when(() => menus.isMenuImported(any())).thenReturn(false);
    when(() => menus.isItemOperating(any())).thenReturn(false);

    coordinator = _MockCoordinator();
    when(() => coordinator.recipeViewModel).thenReturn(recipes);
    when(() => coordinator.menuViewModel).thenReturn(menus);
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<void> confirmHide(WidgetTester tester) async {
    // The confirmation question stays (PQ-07 = A): "Dölj" confirms.
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Dölj'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hiding a shared recipe offers Ångra through the primitive, '
      'and Ångra restores it', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => SharedContentActions.dismissRecipe(
              context,
              coordinator,
              recipe,
            ),
            child: const Text('hide'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('hide'));
    await tester.pumpAndSettle();
    await confirmHide(tester);

    expect(find.byType(InkSnackBar), findsOneWidget);
    expect(find.text('Ångra'), findsOneWidget);

    await tester.tap(find.text('Ångra'));
    await tester.pumpAndSettle();

    verify(() => recipes.undismissSharedRecipe(recipe)).called(1);
    expect(find.text('Ångra'), findsNothing);
  });

  testWidgets('the hide Ångra leaves after the 7 s window without undoing', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => SharedContentActions.dismissRecipe(
              context,
              coordinator,
              recipe,
            ),
            child: const Text('hide'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('hide'));
    await tester.pumpAndSettle();
    await confirmHide(tester);
    expect(find.text('Ångra'), findsOneWidget);

    // Still there just inside the window.
    await tester.pump(kUndoWindow - const Duration(milliseconds: 500));
    expect(find.text('Ångra'), findsOneWidget);

    // Gone once the window has run out (it used to stay until tapped).
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Ångra'), findsNothing);
    verifyNever(() => recipes.undismissSharedRecipe(any()));
  });

  testWidgets('hiding from the menu preview shows Ångra on the view below '
      'after the pop, for 7 s', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: ChangeNotifierProvider<SharedContentCoordinatorViewModel>.value(
          value: coordinator,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ChangeNotifierProvider<
                        SharedContentCoordinatorViewModel
                      >.value(
                        value: coordinator,
                        child: MenuPreviewView(sharedMenu: menu),
                      ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuPreviewView), findsOneWidget);

    await tester.ensureVisible(find.byIcon(Icons.visibility_off));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pumpAndSettle();
    await confirmHide(tester);

    // The preview is gone and the snackbar stands on the view below.
    expect(find.byType(MenuPreviewView), findsNothing);
    expect(find.text('Ångra'), findsOneWidget);

    await tester.pump(kUndoWindow + const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Ångra'), findsNothing);
    verifyNever(() => menus.undismissSharedMenu(any()));
  });
}
