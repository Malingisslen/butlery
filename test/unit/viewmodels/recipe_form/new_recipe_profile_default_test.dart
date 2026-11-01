library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe/source_artefact.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/viewmodels/recipe_form/new_recipe_profile_default.dart';

import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';

void main() {
  UserProfile profile({bool on = true, bool minor = false}) =>
      MockFactory.createUserProfile(
        userId: 'u1',
      ).copyWith(newRecipesShowOnProfile: on, isMinor: minor);

  Recipe recipe({
    RecipeType type = RecipeType.personal,
    String? sourceUrl,
    SourceArtefact? artefact,
  }) {
    final base = RecipeFactory.build(type: type, sourceUrl: sourceUrl);
    return artefact == null ? base : base.copyWith(sourceArtefact: artefact);
  }

  bool shows({
    UserProfile? p,
    Recipe? r,
    bool fromTemplate = false,
    bool noProfile = false,
  }) => showsNewRecipeOnProfile(
    profile: noProfile ? null : (p ?? profile()),
    recipe: r ?? recipe(),
    fromTemplate: fromTemplate,
  );

  test('true: setting on, adult, hand-written personal recipe', () {
    expect(shows(), isTrue);
  });

  test('true when sourceUrl is only whitespace', () {
    expect(shows(r: recipe(sourceUrl: '   ')), isTrue);
  });

  test('false: setting off', () {
    expect(shows(p: profile(on: false)), isFalse);
  });

  test('false: minor', () {
    expect(shows(p: profile(minor: true)), isFalse);
  });

  test('false: started from a template', () {
    expect(shows(fromTemplate: true), isFalse);
  });

  test('false: not a personal recipe', () {
    for (final t in [
      RecipeType.collaborative,
      RecipeType.shared,
      RecipeType.realtime,
    ]) {
      expect(
        shows(r: recipe(type: t)),
        isFalse,
        reason: t.name,
      );
    }
  });

  test('false: has a source artefact', () {
    final artefact = SourceArtefact(
      type: SourceArtefactType.url,
      payload: 'https://example.se',
      fetchedAt: DateTime.utc(2026, 10, 1),
    );
    expect(shows(r: recipe(artefact: artefact)), isFalse);
  });

  test('false: has a source url', () {
    expect(shows(r: recipe(sourceUrl: 'https://example.se/r')), isFalse);
  });

  test('false: no profile', () {
    expect(shows(noProfile: true), isFalse);
  });
}
