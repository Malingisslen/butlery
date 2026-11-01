library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe_unified.dart';

RecipeCore _core({bool? show, DateTime? changedAt}) => RecipeCore(
  id: 'r1',
  title: 'Pannkakor',
  description: 'Goda',
  ingredients: const ['mjölk'],
  instructions: const ['stek'],
  mealType: 'Frukost',
  showOnProfile: show ?? false,
  showOnProfileChangedAt: changedAt,
);

void main() {
  final changedAt = DateTime.utc(2026, 10, 20, 12);

  group('showOnProfile', () {
    test('defaults to false with no changed-at', () {
      final core = _core();

      expect(core.showOnProfile, isFalse);
      expect(core.showOnProfileChangedAt, isNull);
      expect(
        Recipe(core: core, type: RecipeType.personal).showOnProfile,
        isFalse,
      );
    });

    test('RecipeCore.copyWith keeps and sets it', () {
      final shown = _core(show: true, changedAt: changedAt);

      final kept = shown.copyWith(title: 'Annan');
      expect(kept.showOnProfile, isTrue);
      expect(kept.showOnProfileChangedAt, changedAt);

      final off = shown.copyWith(showOnProfile: false);
      expect(off.showOnProfile, isFalse);
      expect(off.showOnProfileChangedAt, changedAt);

      final cleared = shown.copyWith(showOnProfileChangedAt: null);
      expect(cleared.showOnProfileChangedAt, isNull);

      expect(_core().copyWith(showOnProfile: true).showOnProfile, isTrue);
    });

    test('Recipe.copyWith keeps and sets it', () {
      final recipe = Recipe(
        core: _core(show: true, changedAt: changedAt),
        type: RecipeType.personal,
      );

      final kept = recipe.copyWith(title: 'Annan');
      expect(kept.showOnProfile, isTrue);
      expect(kept.core.showOnProfileChangedAt, changedAt);

      final off = recipe.copyWith(showOnProfile: false);
      expect(off.showOnProfile, isFalse);

      final stamped = Recipe(
        core: _core(),
        type: RecipeType.personal,
      ).copyWith(showOnProfile: true, showOnProfileChangedAt: changedAt);
      expect(stamped.showOnProfile, isTrue);
      expect(stamped.core.showOnProfileChangedAt, changedAt);
    });

    test('toFirestore always writes the flag, true and false', () {
      expect(_core(show: true).toFirestore()['showOnProfile'], isTrue);
      expect(_core(show: false).toFirestore()['showOnProfile'], isFalse);
    });

    test('toFirestore writes changed-at as a Timestamp only when set', () {
      final without = _core(show: true).toFirestore();
      expect(without.containsKey('showOnProfileChangedAt'), isFalse);

      final withIt = _core(show: true, changedAt: changedAt).toFirestore();
      expect(withIt['showOnProfileChangedAt'], isA<Timestamp>());
      expect(
        (withIt['showOnProfileChangedAt'] as Timestamp).toDate().toUtc(),
        changedAt,
      );
    });

    test('fromMap reads the flag and changed-at', () {
      final data = _core(show: true, changedAt: changedAt).toFirestore();

      final core = RecipeCore.fromMap('r1', data);

      expect(core.showOnProfile, isTrue);
      expect(core.showOnProfileChangedAt?.toUtc(), changedAt);
    });

    test('fromMap reads absent as false and null', () {
      final data = _core().toFirestore()
        ..remove('showOnProfile')
        ..remove('showOnProfileChangedAt');

      final core = RecipeCore.fromMap('r1', data);

      expect(core.showOnProfile, isFalse);
      expect(core.showOnProfileChangedAt, isNull);
      expect(Recipe.fromMap('r1', data).showOnProfile, isFalse);
    });

    test('toJson and fromJson round-trip it', () {
      final json = _core(show: true, changedAt: changedAt).toJson();
      expect(json['showOnProfile'], isTrue);

      final back = RecipeCore.fromJson(json);
      expect(back.showOnProfile, isTrue);
      expect(back.showOnProfileChangedAt?.toUtc(), changedAt);
    });

    test('toJson omits changed-at when unset; fromJson absent is false', () {
      final json = _core().toJson();
      expect(json.containsKey('showOnProfileChangedAt'), isFalse);

      json.remove('showOnProfile');
      final back = RecipeCore.fromJson(json);
      expect(back.showOnProfile, isFalse);
      expect(back.showOnProfileChangedAt, isNull);
    });
  });
}
