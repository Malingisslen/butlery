/// BUT-2144: bulk share says so when the friend list cannot be read, instead
/// of opening a sheet that claims there is nobody to share with; and each
/// recipe card is identified by its recipe, not its place in the list.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/views/mina_recept/recipe_card_widget.dart';
import 'package:butlery/views/mina_recept/selection_app_bar.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

class _MockRecipeListViewModel extends Mock implements RecipeListViewModel {}

class _MockFriendsService extends Mock implements UnifiedFriendsService {}

class _MockShareViewModel extends Mock
    implements UniversalShareDialogViewModel {}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  locale: const Locale('sv'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  late _MockRecipeListViewModel viewModel;

  Recipe recipe(String id) =>
      (RecipeBuilder()
            ..id = id
            ..title = 'Pannbiffar med lök'
            ..imageUrls = [])
          .build();

  setUp(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    viewModel = _MockRecipeListViewModel();
    when(() => viewModel.selectedIds).thenReturn(const {'r1'});
    when(() => viewModel.selectedCount).thenReturn(1);
    when(() => viewModel.isSelectionMode).thenReturn(true);
    when(() => viewModel.isGridView).thenReturn(false);
    when(() => viewModel.pantryOnly).thenReturn(false);
    when(() => viewModel.pantryMatches).thenReturn(const {});
    when(() => viewModel.pooledStats).thenReturn(const {});
    when(() => viewModel.allSelected).thenReturn(false);
    when(() => viewModel.recipes).thenReturn([recipe('r1'), recipe('r2')]);
    when(() => viewModel.selectedRecipes).thenReturn([recipe('r1')]);
  });

  tearDown(() async => TestServiceLocator.reset());

  testWidgets('a friend list that cannot be read is reported, not shown '
      'as nobody to share with', (tester) async {
    final friends = _MockFriendsService();
    when(() => friends.isInitialized).thenReturn(false);
    when(() => friends.initialize()).thenThrow(Exception('offline'));
    TestServiceLocator.registerMock<UnifiedFriendsService>(friends);
    TestServiceLocator.registerMock<UniversalShareDialogViewModel>(
      _MockShareViewModel(),
    );

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            appBar: buildMinaReceptSelectionAppBar(context, viewModel),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mina-recept-bulk-share')));
    await tester.pumpAndSettle();

    expect(
      find.text('Kunde inte läsa dina vänner. Recepten är fortfarande valda.'),
      findsOneWidget,
    );
    expect(find.byType(UniversalShareDialog), findsNothing);
  });

  testWidgets('a recipe card is identified by its recipe id', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: MinaReceptRecipeCard(
            viewModel: viewModel,
            recipe: recipe('r2'),
            allergenPrefs: const UserAllergenPreferences(
              trackedAllergens: {},
              trackedDietary: {},
            ),
            onDelete: (_) {},
            index: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final identifiers = find.semantics
        .byPredicate((node) => node.identifier.startsWith('recipe-card-'))
        .evaluate()
        .map((node) => node.identifier)
        .toList();
    expect(identifiers, ['recipe-card-r2']);
    handle.dispose();
  });
}
