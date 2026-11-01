import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/tagging/firebase_tag_config.dart';
import 'package:butlery/services/tagging/tag_config_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// Read-only view of the allergen and diet rules the tagger runs on.
class TagRulesViewModel extends BaseViewModel {
  final TagConfigService _service;

  TagRulesViewModel({TagConfigService? tagConfigService})
    : _service = tagConfigService ?? ServiceLocator.get<TagConfigService>();

  FirebaseTagConfig? get config => _service.configOrNull;

  /// Null when the config is not loaded; the view shows an error then, never
  /// an empty list.
  List<FirebaseAllergenEntry>? get allergens =>
      config?.allergens.enabledEntries;

  List<FirebaseDietaryEntry>? get diets => config?.dietary.enabledEntries;

  void refresh() => notifyListeners();
}
