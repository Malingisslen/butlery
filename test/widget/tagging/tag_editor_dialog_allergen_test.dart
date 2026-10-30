// The tag editor's allergen section: a three-way choice per allergen that ends
// up in the saved TagOverrides.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/services/user_service.dart';
import 'package:butlery/widgets/tagging/tag_editor_dialog.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _MockUserService extends Mock implements UserService {}

TagResult _tags(Map<String, TriState> allergens) => TagResult(
  tags: const {'kyckling'},
  allergenStatus: allergens,
  dietaryStatus: const {},
  coverage: 1.0,
  generatedAt: DateTime(2026),
  generatorVersion: kTagGeneratorVersion,
);

TagResult _partialTags(Map<String, TriState> allergens) => TagResult(
  tags: const {'kyckling'},
  allergenStatus: allergens,
  dietaryStatus: const {},
  coverage: 0.5,
  generatedAt: DateTime(2026),
  generatorVersion: kTagGeneratorVersion,
);

Recipe _recipe({TagResult? tags, TagOverrides? overrides}) => Recipe(
  core: RecipeCore(
    id: 'r1',
    title: 'Pannkakor',
    description: '',
    ingredients: const [],
    instructions: const [],
    mealType: 'Middag',
    createdBy: 'u1',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    tagResult: tags,
    tagOverrides: overrides,
  ),
  type: RecipeType.personal,
);

void main() {
  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<void> open(
    WidgetTester tester,
    Recipe recipe,
    void Function(TagOverrides?) onResult,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                onResult(await TagEditorDialog.show(context, recipe)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Spara'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists a CONTAINS allergen with the app verdict', (tester) async {
    await open(
      tester,
      _recipe(tags: _tags({'gluten': TriState.contains})),
      (_) {},
    );

    expect(find.text('Allergener'), findsOneWidget);
    expect(find.text('gluten'), findsOneWidget);
    expect(find.text('Appen: innehåller'), findsOneWidget);
  });

  testWidgets('picking Innehåller inte saves a FREE override', (tester) async {
    TagOverrides? result;
    await open(
      tester,
      _recipe(tags: _tags({'gluten': TriState.contains})),
      (r) => result = r,
    );

    await tester.tap(find.text('Innehåller inte'));
    await tester.pumpAndSettle();
    await save(tester);

    expect(result!.allergenOverrides, {'gluten': TriState.free});
  });

  testWidgets('Appen avgör removes an existing override', (tester) async {
    TagOverrides? result;
    await open(
      tester,
      _recipe(
        tags: _tags({'gluten': TriState.contains}),
        overrides: const TagOverrides(
          allergenOverrides: {'gluten': TriState.free},
        ),
      ),
      (r) => result = r,
    );

    // The app's own verdict, not the override the user set.
    expect(find.text('Appen: innehåller'), findsOneWidget);

    await tester.tap(find.text('Appen avgör'));
    await tester.pumpAndSettle();
    await save(tester);

    expect(result!.allergenOverrides, isEmpty);
  });

  testWidgets('tag edits still round-trip next to allergen edits', (
    tester,
  ) async {
    TagOverrides? result;
    await open(
      tester,
      _recipe(tags: _tags({'gluten': TriState.contains})),
      (r) => result = r,
    );

    await tester.tap(find.text('Innehåller'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextFormField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'ugnsrätt');
    await tester.tap(find.byTooltip('Lägg till tagg'));
    await tester.pumpAndSettle();
    await save(tester);

    expect(result!.addedTags, {'ugnsrätt'});
    expect(result!.allergenOverrides, {'gluten': TriState.contains});
  });

  testWidgets('the section is absent when nothing qualifies', (tester) async {
    await open(
      tester,
      _recipe(tags: _tags({'gluten': TriState.free})),
      (_) {},
    );

    expect(find.text('Allergener'), findsNothing);
  });

  testWidgets('a tracked allergen is listed with an unchecked verdict', (
    tester,
  ) async {
    final userService = _MockUserService();
    when(() => userService.currentUserProfile).thenReturn(
      UserProfile(
        uid: 'u1',
        displayName: 'Test',
        email: 't@example.com',
        joinedAt: DateTime(2024),
        lastActiveAt: DateTime(2024),
        allergenPreferences: const UserAllergenPreferences(
          trackedAllergens: {'nötter'},
          trackedDietary: {},
        ),
      ),
    );
    await GetIt.instance.reset();
    ServiceLocator.reset();
    final container = DIContainer();
    container.container.registerSingleton<UserService>(userService);
    ServiceLocator.initialize(container);

    TagOverrides? result;
    await open(tester, _recipe(), (r) => result = r);

    expect(find.text('nötter'), findsOneWidget);
    expect(find.text('Appen: ej kontrollerat'), findsOneWidget);

    await tester.tap(find.text('Innehåller'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(result!.allergenOverrides, {'nötter': TriState.contains});
  });
  testWidgets('an override on an allergen the app did not find is listed, '
      'kept on save, and clearable', (tester) async {
    TagOverrides? kept;
    final recipe = _recipe(
      tags: _tags({'mjölk': TriState.free}),
      overrides: const TagOverrides(
        allergenOverrides: {'mjölk': TriState.contains},
      ),
    );
    await open(tester, recipe, (r) => kept = r);

    expect(find.text('mjölk'), findsOneWidget);
    expect(find.text('Appen: innehåller inte'), findsOneWidget);
    await save(tester);
    expect(kept!.allergenOverrides, {'mjölk': TriState.contains});

    TagOverrides? cleared;
    await open(tester, recipe, (r) => cleared = r);
    await tester.tap(find.text('Appen avgör'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(cleared!.allergenOverrides, isEmpty);
  });

  testWidgets('a FREE the app cannot fully back reads as unchecked, not free', (
    tester,
  ) async {
    await open(
      tester,
      _recipe(
        tags: _partialTags({'ägg': TriState.free}),
        overrides: const TagOverrides(
          allergenOverrides: {'ägg': TriState.contains},
        ),
      ),
      (_) {},
    );

    expect(find.text('Appen: ej kontrollerat'), findsOneWidget);
    expect(find.text('Appen: innehåller inte'), findsNothing);
  });
}
