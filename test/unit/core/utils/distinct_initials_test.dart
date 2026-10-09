import 'package:butlery/core/utils/distinct_initials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'same first name and surname initial differ on the distinguishing char',
    () {
      expect(distinctInitials(['Test 16', 'Test 17']), ['T6', 'T7']);
    },
  );

  test('different first names get two letters of the first name', () {
    expect(distinctInitials(['Maria A', 'Mikael A']), ['Ma', 'Mi']);
  });

  test('no collision leaves initials unchanged', () {
    expect(distinctInitials(['Anna Berg', 'Karl Dahl']), ['AB', 'KD']);
  });

  test('only the colliding group changes', () {
    expect(
      distinctInitials(['Maria A', 'Anna Berg', 'Mikael A']),
      ['Ma', 'AB', 'Mi'],
    );
  });

  test('empty name gives question mark', () {
    expect(initialsFor('   '), '?');
    expect(distinctInitials(['']), ['?']);
  });

  test('emoji first name is not split mid-grapheme', () {
    expect(initialsFor('😀 Test'), '😀T');
    expect(distinctInitials(['😀😀 A', '😀🙂 A']), ['😀😀', '😀🙂']);
  });

  test('identical names keep identical initials', () {
    expect(distinctInitials(['Test 16', 'Test 16']), ['T1', 'T1']);
    expect(
      distinctInitials(['Test 16', 'Test 17', 'Test 16']),
      ['T6', 'T7', 'T6'],
    );
  });

  test('a subgroup still sharing that character is split again', () {
    expect(
      distinctInitials(['Anna Berg', 'Anna Björk', 'Anna Bergström']),
      ['A', 'AJ', 'AS'],
    );
  });

  test('one-letter first name falls back to the differing character', () {
    expect(distinctInitials(['M 11', 'M 12']), ['M1', 'M2']);
  });

  test('a space where the names differ is skipped for the next letter', () {
    expect(distinctInitials(['Ann Bab', 'Ann B b']), ['AA', 'AB']);
  });

  test('names differing only in case are one person', () {
    expect(distinctInitials(['anna berg', 'Anna Berg']), ['AB', 'AB']);
  });

  test('order is preserved', () {
    expect(
      distinctInitials(['Mikael A', 'Anna Berg', 'Maria A']),
      ['Mi', 'AB', 'Ma'],
    );
  });
}
