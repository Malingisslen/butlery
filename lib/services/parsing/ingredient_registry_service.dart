import 'dart:async';

import 'package:butlery/constants/known_ingredients.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';

/// Enriches the static KnownIngredients registry with Firestore data.
///
/// Falls back to [KnownIngredients.all] when Firestore is unavailable
/// or has not been loaded yet (offline-first).
class IngredientRegistryService extends BaseService {
  final IngredientRepository _ingredientRepository;

  /// Combined ingredient set: static + Firestore-enriched.
  Set<String>? _enrichedIngredients;

  /// Whether Firestore ingredients have been loaded.
  bool _isEnriched = false;

  /// Guard against concurrent enrichment calls.
  Completer<void>? _enrichCompleter;

  /// Compound names from Firestore (ingredients with isCompoundName=true).
  Set<String>? _compoundNames;

  IngredientRegistryService({
    required IngredientRepository ingredientRepository,
  }) : _ingredientRepository = ingredientRepository;

  @override
  String get serviceName => 'IngredientRegistryService';

  /// All known ingredient names (static + Firestore if loaded).
  Set<String> get allIngredients =>
      _enrichedIngredients ?? KnownIngredients.all;

  /// All compound names (static + Firestore if loaded).
  Set<String> get allCompoundNames =>
      _compoundNames ?? KnownIngredients.compoundNames;

  /// Whether an ingredient name is known.
  bool isKnown(String ingredient) {
    return allIngredients.contains(ingredient.toLowerCase());
  }

  /// Load Firestore ingredients to enrich the static registry.
  /// Safe to call multiple times — only loads once.
  Future<void> enrichFromFirestore() async {
    if (_isEnriched) return;
    if (_enrichCompleter != null) return _enrichCompleter!.future;

    _enrichCompleter = Completer<void>();

    try {
      final combined = Set<String>.from(KnownIngredients.all);
      final compoundNameSet = Set<String>.from(KnownIngredients.compoundNames);

      final groups = [
        'protein',
        'vegetable',
        'fruit',
        'grain',
        'dairy',
        'spice',
        'condiment',
        'sweetener',
        'oil',
        'beverage',
      ];

      // Load all groups in parallel
      final results = await Future.wait(
        groups.map((group) async {
          try {
            return await _ingredientRepository.getByGroup(group);
          } catch (_) {
            return <dynamic>[]; // Skip individual group failures
          }
        }),
      );

      for (final ingredients in results) {
        for (final item in ingredients) {
          combined.add(item.swedish.toLowerCase().trim());
          for (final alias in item.aliasesSv) {
            combined.add(alias.toLowerCase().trim());
          }
          if (item.isCompoundName) {
            compoundNameSet.add(item.swedish.toLowerCase().trim());
            for (final alias in item.aliasesSv) {
              compoundNameSet.add(alias.toLowerCase().trim());
            }
          }
        }
      }

      _enrichedIngredients = combined;
      _compoundNames = compoundNameSet;
      _isEnriched = true;

      AppLogger.info(
        'Enriched ingredient registry: ${combined.length} total '
        '(${combined.length - KnownIngredients.all.length} from Firestore)',
        serviceName,
      );
    } catch (e) {
      AppLogger.debug(
        'Could not enrich from Firestore, using static registry: $e',
        serviceName,
      );
    } finally {
      _enrichCompleter!.complete();
      _enrichCompleter = null;
    }
  }
}
