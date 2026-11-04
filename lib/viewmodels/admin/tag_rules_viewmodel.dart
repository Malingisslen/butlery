import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/models/tagging/firebase_tag_config.dart';
import 'package:butlery/repositories/interfaces/ingredient_change_request_repository.dart';
import 'package:butlery/services/tagging/config/occasion_lists.dart';
import 'package:butlery/services/tagging/tag_config_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// The allergen and diet rules the tagger runs on, and the entry point for
/// proposing a change to one of its word lists.
class TagRulesViewModel extends BaseViewModel {
  final TagConfigService _service;
  final IngredientChangeRequestRepository? _repositoryOverride;

  /// Longest note the proposal rules accept.
  static const int maxNoteLength = 500;

  TagRulesViewModel({
    TagConfigService? tagConfigService,
    IngredientChangeRequestRepository? repository,
  }) : _service = tagConfigService ?? ServiceLocator.get<TagConfigService>(),
       _repositoryOverride = repository;

  // Resolved on first use so the read-only tables need no repository.
  IngredientChangeRequestRepository get _repository =>
      _repositoryOverride ??
      ServiceLocator.get<IngredientChangeRequestRepository>();

  FirebaseTagConfig? get config => _service.configOrNull;

  /// Null when the config is not loaded; the view shows an error then, never
  /// an empty list.
  List<FirebaseAllergenEntry>? get allergens =>
      config?.allergens.enabledEntries;

  List<FirebaseDietaryEntry>? get diets => config?.dietary.enabledEntries;

  void refresh() => notifyListeners();

  bool noteIsValid(String note) => note.trim().length <= maxNoteLength;

  /// Returns false, without writing, when the words are invalid or equal to
  /// the compiled-in list; true once the proposal is saved. On a failed write
  /// [error] holds the message.
  Future<bool> proposeWordList(
    OccasionList list,
    List<String> newWords, {
    String note = '',
  }) async {
    if (validateOccasionWords(newWords) != null || !noteIsValid(note)) {
      return false;
    }
    if (sameWords(list.words, newWords)) return false;
    return executeAsyncVoid(
      () async {
        await _repository.create(
          IngredientChangeRequest.wordList(
            listKey: list.key,
            oldWords: list.words,
            newWords: newWords,
            note: note.trim(),
          ),
        );
      },
      errorPrefix: AppLocale.current.adminProposalSaveFailed,
    );
  }

  /// Same words in the same order.
  static bool sameWords(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
