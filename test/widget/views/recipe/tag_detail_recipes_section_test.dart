// The recipes under a tag's rules on the tag page: which ones are listed, where
// a tap leads, and that the list follows the tag's total.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/widgets/common/list/recipe_thumb_row.dart';
import 'package:butlery/widgets/tagging/tag_detail_recipes_section.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockRecipeRepository extends Mock implements RecipeRepository {}

void main() {
  final sv = AppLocalizationsSv();
  late _MockRecipeRepository repo;

  setUp(() async {
    await GetIt.instance.reset();
    repo = _MockRecipeRepository();
    GetIt.instance.registerSingleton<RecipeRepository>(repo);
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Widget section(int count) => createLocalizedTestApp(
    onGenerateRoute: (settings) {
      if (settings.name == Routes.recipeDetail) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('RECEPT-SIDAN')),
        );
      }
      return null;
    },
    child: SingleChildScrollView(
      child: TagDetailRecipesSection(tagId: 'tag-1', recipeCount: count),
    ),
  );

  testWidgets('lists the tag\'s recipes under the count heading and a tap '
      'opens that recipe', (tester) async {
    final pannkakor = RecipeFactory.build(id: 'r1', title: 'Pannkakor');
    final soppa = RecipeFactory.build(id: 'r2', title: 'Tomatsoppa');
    when(
      () => repo.fetchRecipesByTagId('tag-1'),
    ).thenAnswer((_) async => [pannkakor, soppa]);

    late RouteSettings pushed;
    await tester.pumpWidget(
      createLocalizedTestApp(
        onGenerateRoute: (settings) {
          if (settings.name == Routes.recipeDetail) {
            pushed = settings;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('RECEPT-SIDAN')),
            );
          }
          return null;
        },
        child: const SingleChildScrollView(
          child: TagDetailRecipesSection(tagId: 'tag-1', recipeCount: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(sv.tagDetailRecipesHeading(2)), findsOneWidget);
    expect(find.text('Pannkakor'), findsOneWidget);
    expect(find.text('Tomatsoppa'), findsOneWidget);

    await tester.tap(find.text('Tomatsoppa'));
    await tester.pumpAndSettle();

    expect(pushed.name, Routes.recipeDetail);
    final args = pushed.arguments! as Map<String, dynamic>;
    expect((args['recipe'] as Recipe).id, 'r2');
    expect(find.text('RECEPT-SIDAN'), findsOneWidget);
  });

  testWidgets('a changed total reloads the list', (tester) async {
    when(
      () => repo.fetchRecipesByTagId('tag-1'),
    ).thenAnswer((_) async => [RecipeFactory.build(id: 'r1', title: 'Gröt')]);

    await tester.pumpWidget(section(1));
    await tester.pumpAndSettle();

    await tester.pumpWidget(section(2));
    await tester.pumpAndSettle();

    verify(() => repo.fetchRecipesByTagId('tag-1')).called(2);
    expect(find.text(sv.tagDetailRecipesHeading(2)), findsOneWidget);
  });

  testWidgets('an unchanged total does not refetch on rebuild', (tester) async {
    when(
      () => repo.fetchRecipesByTagId('tag-1'),
    ).thenAnswer((_) async => const <Recipe>[]);

    await tester.pumpWidget(section(3));
    await tester.pumpAndSettle();
    await tester.pumpWidget(section(3));
    await tester.pumpAndSettle();

    verify(() => repo.fetchRecipesByTagId('tag-1')).called(1);
  });

  testWidgets('a failed load keeps the heading, says so and retries on '
      'Försök igen', (tester) async {
    when(
      () => repo.fetchRecipesByTagId('tag-1'),
    ).thenThrow(Exception('offline'));

    await tester.pumpWidget(section(4));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(sv.tagDetailRecipesHeading(4)), findsOneWidget);
    expect(find.text(sv.tagDetailRecipesLoadFailed), findsOneWidget);
    expect(find.byType(RecipeThumbRow), findsNothing);

    final pannkakor = RecipeFactory.build(id: 'r1', title: 'Pannkakor');
    when(
      () => repo.fetchRecipesByTagId('tag-1'),
    ).thenAnswer((_) async => [pannkakor]);
    await tester.tap(find.byKey(InlineError.actionKey));
    await tester.pumpAndSettle();

    expect(find.text(sv.tagDetailRecipesLoadFailed), findsNothing);
    expect(find.text('Pannkakor'), findsOneWidget);
  });
}
