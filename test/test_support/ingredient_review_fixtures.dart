// Literals stay non-const so each test can derive from the sample freely.
// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/tagging/tag_config_service.dart';
import 'package:butlery/models/tagging/firebase_tag_config.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';

/// Gluten (simple), nuts (combined) and one diet that excludes meat.
FirebaseTagConfig ingredientReviewConfig() {
  return FirebaseTagConfig.fromDocuments(
    allergensData: {
      'schemaVersion': 1,
      'version': 1,
      'updatedBy': 'test',
      'displayOrder': ['gluten', 'nötter'],
      'entries': [
        {
          'key': 'gluten',
          'triggerProperties': ['contains-gluten'],
          'enabled': true,
          'isEuAllergen': true,
        },
        {
          'key': 'nötter',
          'triggerProperties': ['tree-nut', 'peanut'],
          'enabled': true,
        },
      ],
    },
    dietaryData: {
      'schemaVersion': 1,
      'version': 1,
      'updatedBy': 'test',
      'displayOrder': ['vegetarian'],
      'entries': [
        {
          'key': 'vegetarian',
          'tags': {'sv': 'vegetarisk'},
          'excludedProperties': ['meat', 'seafood'],
          'enabled': true,
        },
      ],
    },
    cuisinesData: const {},
    propertiesData: const {},
    displayData: const {},
  );
}

List<IngredientData> ingredientReviewSample() => [
  IngredientData(
    id: 'wheat-flour',
    swedish: 'vetemjöl',
    english: 'wheat flour',
    group: 'pantry/flour',
    properties: {'contains-gluten'},
    aliasesSv: ['mjöl'],
    status: 'verified',
    priceCategory: 'low',
    updatedAt: DateTime.utc(2026, 10, 1),
  ),
  IngredientData(
    id: 'chicken-breast',
    swedish: 'kycklingbröst',
    english: 'chicken breast',
    group: 'protein/meat',
    properties: {'meat'},
    status: 'draft',
    updatedAt: DateTime.utc(2026, 10, 20),
  ),
  IngredientData(
    id: 'almond',
    swedish: 'mandel',
    english: 'almond',
    group: 'pantry/nuts',
    properties: {'tree-nut'},
    status: 'needs-review',
    avgPriceSek: 80,
  ),
  IngredientData(
    id: 'water',
    swedish: 'vatten',
    english: 'water',
    group: 'liquid/water',
    properties: <String>{},
    status: 'deleted',
    aliasesEn: ['tap water'],
  ),
  IngredientData(
    id: 'salt',
    swedish: 'salt',
    english: 'salt',
    group: 'pantry/spice',
    properties: <String>{},
    status: 'validated',
    priceCategory: 'low',
  ),
];

class FakeIngredientRepository implements IngredientRepository {
  FakeIngredientRepository(this.items, {this.error});

  final List<IngredientData> items;
  final Object? error;

  @override
  Future<List<IngredientData>> getAll() async {
    if (error != null) throw error!;
    return items;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTagConfigService extends TagConfigService {
  FakeTagConfigService(this._config)
    : super(firestore: FakeFirebaseFirestore());

  final FirebaseTagConfig? _config;

  @override
  FirebaseTagConfig? get configOrNull => _config;
}
