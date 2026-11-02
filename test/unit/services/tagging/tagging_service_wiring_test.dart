/// BUT-1508: the tagging service hands its feature flags and its live tag
/// config to the generator it builds. Dropping either hand-off would leave the
/// remote thresholds and the late-loaded allergen config silently unused.
library;

import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/tagging/firebase_tag_config.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/tagging/tag_config_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/builders/user_builder.dart';
import '../../../infrastructure/helpers/tagging_test_helper.dart';
import '../../../infrastructure/mocks/production_mocks.dart'
    show FakePermissionService;

class _MockLookup extends Mock implements IngredientLookupService {}

class _MockFlags extends Mock implements FeatureFlagService {}

class _LateConfig extends TagConfigService {
  FirebaseTagConfig? _late;

  _LateConfig() : super(firestore: FakeFirebaseFirestore());

  @override
  FirebaseTagConfig? get configOrNull => _late;

  void arrive(FirebaseTagConfig config) => _late = config;
}

FirebaseTagConfig _configWithMarkerCuisine() {
  Map<String, dynamic> load(String name) =>
      jsonDecode(
            File('scripts/output/tagConfigs/$name.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  return FirebaseTagConfig.fromDocuments(
    allergensData: load('allergens'),
    dietaryData: load('dietary'),
    cuisinesData: {
      'schemaVersion': 1,
      'version': 999,
      'updatedAt': '2026-01-01T00:00:00.000Z',
      'updatedBy': 'but-1508-test',
      'displayOrder': ['marker_cuisine'],
      'entries': [
        {
          'key': 'marker_cuisine',
          'tags': {'sv': 'testkök'},
          'titleKeywords': ['zzcuisine'],
          'ingredientKeywords': <String>[],
          'ingredientGroups': <String>[],
          'minIngredientMatches': 1,
          'matchMode': 'title_only',
          'enabled': true,
          'priority': 0,
        },
      ],
    },
    propertiesData: load('properties'),
    displayData: load('display'),
  );
}

void main() {
  late _MockLookup lookupService;
  late FakePermissionService permissionService;

  setUp(() {
    lookupService = _MockLookup();
    when(() => lookupService.initialize()).thenAnswer((_) async {});
    when(() => lookupService.dispose()).thenAnswer((_) async {});
    final lookup = TaggingTestHelper.createLookup([
      TaggingTestHelper.ingredient('lettuce', 'vegetable', {}),
      TaggingTestHelper.ingredient('tomato', 'vegetable', {}),
      TaggingTestHelper.ingredient('cucumber', 'vegetable', {}),
    ]);
    when(
      () => lookupService.lookupFromRaw(any(), userId: any(named: 'userId')),
    ).thenAnswer((_) async => lookup);
    permissionService = FakePermissionService()
      ..setPermissionState(
        currentUser: UserBuilder().withId('wiring-uid').build(),
      );
  });

  Future<Set<String>> tagsOf(TaggingService service, String title) async {
    final recipe = RecipeBuilder()
        .withTitle(title)
        .withTimeMinutes(10)
        .withIngredients(['lettuce', 'tomato', 'cucumber'])
        .build();
    final result = await service.generateTags(recipe);
    expect(result, isNotNull);
    return result!.tags;
  }

  test(
    'without flags the default thresholds tag a quick salad as easy',
    () async {
      final service = TaggingService(
        lookupService: lookupService,
        permissionService: permissionService,
      );

      expect(await tagsOf(service, 'Simple Salad'), contains('enkel'));
    },
  );

  test('the injected feature flags set the generator thresholds', () async {
    final flags = _MockFlags();
    when(() => flags.getInt(any())).thenReturn(5);
    final service = TaggingService(
      lookupService: lookupService,
      permissionService: permissionService,
      featureFlags: flags,
    );

    expect(await tagsOf(service, 'Simple Salad'), isNot(contains('enkel')));
  });

  test('a tag config that loads after boot reaches the generator', () async {
    final config = _LateConfig();
    final service = TaggingService(
      lookupService: lookupService,
      permissionService: permissionService,
      tagConfigService: config,
    );
    expect(
      await tagsOf(service, 'Zzcuisine Testrätt'),
      isNot(contains('testkök')),
    );

    config.arrive(_configWithMarkerCuisine());

    expect(await tagsOf(service, 'Zzcuisine Testrätt'), contains('testkök'));
  });
}
