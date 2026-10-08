/// The import gate's site pages, shared by the gate and the nightly AI
/// corpus so both read the same bytes (BUT-2239).
library;

import 'dart:io';

import '../fixtures/swedish_sites/arla_test_data.dart';
import '../fixtures/swedish_sites/ica_test_data.dart';
import '../fixtures/swedish_sites/koket_test_data.dart';
import '../fixtures/swedish_sites/recept_test_data.dart';

const siteGoldPath = 'test/import_gate/sites/gold.json';

/// Site pages that already live as Dart constants; the gate's own pages are
/// HTML files beside `sites/gold.json`.
const _dartFixtures = <String, String>{
  'ArlaTestFixtures.chokladbollarComplete':
      ArlaTestFixtures.chokladbollarComplete,
  'ArlaTestFixtures.realStructureKassler':
      ArlaTestFixtures.realStructureKassler,
  'ArlaTestFixtures.recipeWithoutJsonLd': ArlaTestFixtures.recipeWithoutJsonLd,
  'IcaTestFixtures.kottbullarComplete': IcaTestFixtures.kottbullarComplete,
  'IcaTestFixtures.realStructureBananomelett':
      IcaTestFixtures.realStructureBananomelett,
  'IcaTestFixtures.recipeWithoutJsonLd': IcaTestFixtures.recipeWithoutJsonLd,
  'KoketTestFixtures.kottbullarProfessional':
      KoketTestFixtures.kottbullarProfessional,
  'KoketTestFixtures.recipeWithoutJsonLd':
      KoketTestFixtures.recipeWithoutJsonLd,
  'ReceptTestFixtures.kanelbullarComplete':
      ReceptTestFixtures.kanelbullarComplete,
  'ReceptTestFixtures.recipeWithoutJsonLd':
      ReceptTestFixtures.recipeWithoutJsonLd,
};

/// The page a `gold.json` entry's `source` names: a file beside `gold.json`
/// (`file:<name>`) or one of the Dart constants above.
String sitePageHtml(String source) => source.startsWith('file:')
    ? File('test/import_gate/sites/${source.substring(5)}').readAsStringSync()
    : _dartFixtures[source] ?? (throw StateError('okänd fixtur: $source'));
