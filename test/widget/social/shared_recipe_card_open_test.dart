/// What tapping a shared recipe does (BUT-2156): a recipe that is not saved
/// yet opens the receive sheet, a saved one opens the recipe directly, and
/// the sheet's two choices import or open.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_recipe_viewmodel.dart';
import 'package:butlery/views/social/shared_with_me/shared_recipe_card.dart';
import 'package:butlery/widgets/social/shared_receive_sheet.dart';

class _FakePermissionService extends Fake implements PermissionService {
  @override
  String? get currentUserId => 'me';
}

class _FakeSocialRecipeCoordinator extends Fake
    implements SocialRecipeCoordinator {}

class _RecordingRecipeViewModel extends SharedRecipeViewModel {
  _RecordingRecipeViewModel({required this.saved})
    : super(
        socialRecipeCoordinator: _FakeSocialRecipeCoordinator(),
        permissionService: _FakePermissionService(),
      );

  final bool saved;
  int imports = 0;
  int opens = 0;
  int markedViewed = 0;

  @override
  bool isRecipeViewed(SharedRecipe recipe) => false;

  @override
  bool isRecipeImported(SharedRecipe recipe) => saved;

  @override
  Future<bool> markAsViewed(SharedRecipe sharedRecipe) async {
    markedViewed++;
    return true;
  }

  @override
  Future<String?> importSharedRecipe(
    SharedRecipe sharedRecipe, {
    String? newTitle,
  }) async {
    imports++;
    return 'new-id';
  }

  @override
  Future<Recipe> loadFullRecipe(SharedRecipe sharedRecipe) async {
    opens++;
    return sharedRecipe.contentSnapshot;
  }
}

class _FakeCoordinator extends Fake
    implements SharedContentCoordinatorViewModel {
  _FakeCoordinator(this._recipes);

  final _RecordingRecipeViewModel _recipes;

  @override
  SharedRecipeViewModel get recipeViewModel => _recipes;
}

SharedRecipe _shared({bool allowCollaboration = false}) => SharedRecipe(
  id: 's1',
  sharedByUserId: 'friend-1',
  sharedByDisplayName: 'Anna',
  originalRecipeId: 'orig-1',
  recipeTitle: 'Köttbullar',
  recipePortions: 4,
  recipeTimeMinutes: 30,
  allowCollaboration: allowCollaboration,
);

Future<_RecordingRecipeViewModel> _pump(
  WidgetTester tester, {
  required bool saved,
  bool allowCollaboration = false,
}) async {
  final recipes = _RecordingRecipeViewModel(saved: saved);
  final coordinator = _FakeCoordinator(recipes);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      onGenerateRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => const Text('recipe page')),
      home: Scaffold(
        body: Builder(
          builder: (context) => SharedRecipeCard.build(
            context,
            coordinator,
            _shared(allowCollaboration: allowCollaboration),
          ),
        ),
      ),
    ),
  );
  return recipes;
}

void main() {
  testWidgets('an unsaved recipe opens the sheet and marks the share read', (
    tester,
  ) async {
    final recipes = await _pump(tester, saved: false);
    await tester.tap(find.textContaining('Köttbullar'));
    await tester.pumpAndSettle();
    expect(find.byType(SharedReceiveSheet), findsOneWidget);
    expect(find.text('KAN LÄSA'), findsOneWidget);
    expect(recipes.markedViewed, 1);
    expect(recipes.opens, 0);
  });

  testWidgets('a shared recipe that may be edited says so', (tester) async {
    await _pump(tester, saved: false, allowCollaboration: true);
    await tester.tap(find.textContaining('Köttbullar'));
    await tester.pumpAndSettle();
    expect(find.text('KAN REDIGERA'), findsOneWidget);
  });

  testWidgets('Acceptera imports and does not open the recipe', (tester) async {
    final recipes = await _pump(tester, saved: false);
    await tester.tap(find.textContaining('Köttbullar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SharedReceiveSheet.acceptKey));
    await tester.pumpAndSettle();
    expect(recipes.imports, 1);
    expect(recipes.opens, 0);
    expect(find.text('recipe page'), findsNothing);
  });

  testWidgets('Visa receptet opens the recipe and does not import', (
    tester,
  ) async {
    final recipes = await _pump(tester, saved: false);
    await tester.tap(find.textContaining('Köttbullar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SharedReceiveSheet.viewKey));
    await tester.pumpAndSettle();
    expect(recipes.opens, 1);
    expect(recipes.imports, 0);
    expect(find.text('recipe page'), findsOneWidget);
  });

  testWidgets('a saved recipe opens directly without the sheet', (
    tester,
  ) async {
    final recipes = await _pump(tester, saved: true);
    await tester.tap(find.textContaining('Köttbullar'));
    await tester.pumpAndSettle();
    expect(find.byType(SharedReceiveSheet), findsNothing);
    expect(recipes.opens, 1);
    expect(find.text('recipe page'), findsOneWidget);
  });
}
