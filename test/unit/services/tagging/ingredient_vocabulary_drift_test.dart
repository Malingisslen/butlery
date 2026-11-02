/// The proposal vocabulary is a hand-kept copy of the sync's: this fails when
/// the TypeScript source and the Dart lists part.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/ingredient_allergen_impact.dart';
import 'package:butlery/services/tagging/ingredient_change_validator.dart';

Set<String> _quoted(String block) =>
    RegExp(r'"([^"]+)"').allMatches(block).map((m) => m.group(1)!).toSet();

void main() {
  final core = File(
    'functions/src/admin/sync-ingredients-core.ts',
  ).readAsStringSync();

  test('group prefixes equal VALID_GROUP_PREFIXES', () {
    final block = RegExp(
      r'VALID_GROUP_PREFIXES = \[(.*?)\]',
      dotAll: true,
    ).firstMatch(core)!.group(1)!;
    expect(kProposableGroupPrefixes.toSet(), _quoted(block));
    expect(kProposableGroupPrefixes.length, _quoted(block).length);
  });

  test('properties equal VALID_PROPERTIES', () {
    final setBlock = RegExp(
      r'const VALID_PROPERTIES = new Set(?:<string>)?\(\[(.*?)\]\)',
      dotAll: true,
    ).firstMatch(core)!.group(1)!;
    final allergenBlock = RegExp(
      r'const ALLERGEN_BLOCK_PROPERTIES = \[(.*?)\]',
      dotAll: true,
    ).firstMatch(core)!.group(1)!;
    expect(kProposableProperties, _quoted('$setBlock $allergenBlock'));
  });

  test('allergen-relevant set equals ALLERGEN_RELEVANT_PROPERTIES', () {
    final src = File(
      'functions/src/shared/allergen-properties.ts',
    ).readAsStringSync();
    final block = RegExp(
      r'ALLERGEN_RELEVANT_PROPERTIES: ReadonlySet<string> = new Set\(\[(.*?)\]\)',
      dotAll: true,
    ).firstMatch(src)!.group(1)!;
    expect(kAllergenRelevantProperties, _quoted(block));
  });
}
