import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/tagging/firebase_tag_config.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/tagging/ingredient_tag_preview.dart';
import 'package:butlery/services/tagging/tag_config_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// Status buckets shown as counters. Anything that is not one of the four
/// working statuses (deleted, user-defined, unknown) lands in [other] so it is
/// counted rather than silently dropped.
abstract final class IngredientStatusBucket {
  static const draft = 'draft';
  static const validated = 'validated';
  static const verified = 'verified';
  static const needsReview = 'needs-review';
  static const other = 'other';

  static const all = [draft, validated, verified, needsReview, other];

  static String of(String status) =>
      const {draft, validated, verified, needsReview}.contains(status)
      ? status
      : other;
}

/// Read-only ViewModel behind the admin "Ingredienser" tab.
class IngredientReviewViewModel extends BaseViewModel {
  /// Allergen filter value meaning "the tagger gives no allergen".
  static const noAllergenFilter = '__none__';

  final IngredientRepository _repository;
  final TagConfigService _tagConfigService;

  List<IngredientData> _all = const [];
  Map<String, IngredientTagPreview> _previews = const {};
  FirebaseTagConfig? _config;
  List<IngredientData> _filtered = const [];
  Map<String, int> _counts = const {};
  List<String> _groups = const [];
  DateTime? _lastSynced;

  String _query = '';
  String? _statusFilter;
  String? _groupFilter;
  String? _allergenFilter;
  bool _missingPriceOnly = false;

  IngredientReviewViewModel({
    IngredientRepository? repository,
    TagConfigService? tagConfigService,
  }) : _repository = repository ?? ServiceLocator.get<IngredientRepository>(),
       _tagConfigService =
           tagConfigService ?? ServiceLocator.get<TagConfigService>();

  List<IngredientData> get ingredients => _filtered;
  int get totalCount => _all.length;
  Map<String, int> get statusCounts => _counts;
  List<String> get groups => _groups;
  DateTime? get lastSynced => _lastSynced;

  /// False means allergen and diet answers are unavailable, not "none".
  bool get hasTagConfig => _config != null;

  List<String> get allergenKeys => [
    for (final e in _config?.allergens.enabledEntries ?? const []) e.key,
  ];

  String get query => _query;
  String? get statusFilter => _statusFilter;
  String? get groupFilter => _groupFilter;
  String? get allergenFilter => _allergenFilter;
  bool get missingPriceOnly => _missingPriceOnly;

  bool get hasActiveFilters =>
      _query.isNotEmpty ||
      _statusFilter != null ||
      _groupFilter != null ||
      _allergenFilter != null ||
      _missingPriceOnly;

  IngredientTagPreview? previewOf(IngredientData ingredient) =>
      _previews[ingredient.id];

  String dietLabel(String key) =>
      _config?.dietary.getByKey(key)?.getTag('sv') ?? key;

  Future<void> load() async {
    final ok = await executeAsyncVoid(() async {
      final loaded = await _repository.getAll();
      // The repository degrades to an empty list when a cold load fails, so
      // empty must read as a failure instead of "0 ingredienser".
      if (loaded.isEmpty) throw StateError('Ingredient list is empty');
      _config = _tagConfigService.configOrNull;
      _all = loaded;
      _previews = _config == null
          ? const {}
          : {
              for (final i in loaded)
                i.id: previewIngredientTags(i.properties, _config!),
            };
      _recomputeStatic();
      _applyFilters();
    }, errorPrefix: AppLocale.current.adminIngredientsLoadFailed);
    if (!ok) {
      _all = const [];
      _filtered = const [];
      notifyListeners();
    }
  }

  void setQuery(String value) {
    _query = value.trim();
    _applyFilters();
    notifyListeners();
  }

  void setStatusFilter(String? bucket) {
    _statusFilter = bucket;
    _applyFilters();
    notifyListeners();
  }

  void setGroupFilter(String? group) {
    _groupFilter = group;
    _applyFilters();
    notifyListeners();
  }

  void setAllergenFilter(String? allergen) {
    _allergenFilter = allergen;
    _applyFilters();
    notifyListeners();
  }

  void setMissingPriceOnly(bool value) {
    _missingPriceOnly = value;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _query = '';
    _statusFilter = null;
    _groupFilter = null;
    _allergenFilter = null;
    _missingPriceOnly = false;
    _applyFilters();
    notifyListeners();
  }

  void _recomputeStatic() {
    final counts = {for (final b in IngredientStatusBucket.all) b: 0};
    final groups = <String>{};
    DateTime? newest;
    for (final i in _all) {
      final bucket = IngredientStatusBucket.of(i.status);
      counts[bucket] = counts[bucket]! + 1;
      if (i.group.isNotEmpty) groups.add(i.topLevelGroup);
      final updated = i.updatedAt;
      if (updated != null && (newest == null || updated.isAfter(newest))) {
        newest = updated;
      }
    }
    _counts = counts;
    _groups = groups.toList()..sort();
    _lastSynced = newest;
  }

  void _applyFilters() {
    final q = _query.toLowerCase();
    final result = <IngredientData>[
      for (final i in _all)
        if (_matches(i, q)) i,
    ];
    result.sort(
      (a, b) => a.swedish.toLowerCase().compareTo(b.swedish.toLowerCase()),
    );
    _filtered = result;
  }

  bool _matches(IngredientData i, String q) {
    if (_statusFilter != null &&
        IngredientStatusBucket.of(i.status) != _statusFilter) {
      return false;
    }
    if (_groupFilter != null && i.topLevelGroup != _groupFilter) return false;
    if (_missingPriceOnly && !_lacksPrice(i)) return false;
    final allergen = _allergenFilter;
    if (allergen != null) {
      final keys = _previews[i.id]?.allergenKeys;
      if (keys == null) return false;
      if (allergen == noAllergenFilter) {
        if (keys.isNotEmpty) return false;
      } else if (!keys.contains(allergen)) {
        return false;
      }
    }
    if (q.isEmpty) return true;
    return i.id.toLowerCase().contains(q) ||
        i.swedish.toLowerCase().contains(q) ||
        i.english.toLowerCase().contains(q) ||
        i.aliasesSv.any((a) => a.toLowerCase().contains(q)) ||
        i.aliasesEn.any((a) => a.toLowerCase().contains(q));
  }

  static bool _lacksPrice(IngredientData i) =>
      (i.priceCategory == null || i.priceCategory!.trim().isEmpty) &&
      i.avgPriceSek == null;

  /// Deterministic text for pasting into a Claude session — no LLM involved.
  String claudeTextFor(IngredientData i) {
    final preview = previewOf(i);
    final allergens = preview == null
        ? 'okänt (taggkonfiguration saknas)'
        : _listOrNone(preview.allergenKeys);
    final diets = preview == null
        ? 'okänt (taggkonfiguration saknas)'
        : _listOrNone(preview.brokenDietKeys.map(dietLabel));
    return 'Ingrediens i Butlery:\n'
        'Id: ${i.id}\n'
        'Svenskt namn: ${i.swedish}\n'
        'Grupp: ${i.group}\n'
        'Status: ${i.status}\n'
        'Egenskaper: ${_listOrNone(i.properties.toList()..sort())}\n'
        'Ger allergener: $allergens\n'
        'Bryter koster: $diets\n\n'
        'Stämmer något här inte? Berätta vad som ska ändras, så rättar vi '
        'ingrediensen i docs/tagging/data/Butlery_Ingredients_INGREDIENTS.csv.';
  }

  static String _listOrNone(Iterable<String> items) =>
      items.isEmpty ? 'inga' : items.join(', ');
}
