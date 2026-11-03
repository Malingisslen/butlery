// Literals stay non-const so each test can derive from the sample freely.
// ignore_for_file: prefer_const_literals_to_create_immutables

import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/repositories/interfaces/ingredient_change_request_repository.dart';
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
  Future<IngredientData?> getByIdFromServer(String id) async {
    if (error != null) throw error!;
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
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

class FakeChangeRequestRepository implements IngredientChangeRequestRepository {
  FakeChangeRequestRepository({this.failWrites = false});

  final bool failWrites;
  final List<IngredientChangeRequest> created = [];
  final List<List<IngredientChangeRequest>> batches = [];
  final List<String> withdrawn = [];
  final StreamController<List<IngredientChangeRequest>> pending =
      StreamController<List<IngredientChangeRequest>>.broadcast();
  final StreamController<List<IngredientChangeRequest>> decided =
      StreamController<List<IngredientChangeRequest>>.broadcast();

  @override
  Future<IngredientChangeRequest> create(IngredientChangeRequest entity) async {
    if (failWrites) throw StateError('write failed');
    created.add(entity);
    return entity;
  }

  @override
  Future<void> createBatch(List<IngredientChangeRequest> entities) async {
    if (failWrites) throw StateError('write failed');
    batches.add(entities);
  }

  int watchCalls = 0;

  @override
  Stream<List<IngredientChangeRequest>> watchOpen() {
    watchCalls++;
    return pending.stream;
  }

  @override
  Stream<List<IngredientChangeRequest>> watchApplied() => decided.stream.map(
    (l) => [
      for (final p in l)
        if (p.status == IngredientChangeStatus.applied) p,
    ],
  );

  @override
  Stream<List<IngredientChangeRequest>> watchRejected() => decided.stream.map(
    (l) => [
      for (final p in l)
        if (p.status == IngredientChangeStatus.rejected) p,
    ],
  );

  @override
  Future<void> withdraw(String id) async {
    if (failWrites) throw StateError('write failed');
    withdrawn.add(id);
  }
}
