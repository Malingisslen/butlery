import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/models/tagging/ingredient_column.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/ingredient_change_request_repository.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/tagging/ingredient_change_validator.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// Form state behind "Föreslå ändring" for one ingredient. The old value is
/// read from the server when the form opens, so the proposal records what is
/// true then rather than what the hour-old cache held.
class IngredientProposalFormViewModel extends BaseViewModel {
  IngredientProposalFormViewModel({
    required this.ingredientId,
    IngredientRepository? ingredientRepository,
    IngredientChangeRequestRepository? repository,
  }) : _ingredients =
           ingredientRepository ?? ServiceLocator.get<IngredientRepository>(),
       _repository =
           repository ??
           ServiceLocator.get<IngredientChangeRequestRepository>();

  static const int maxNoteLength = 500;

  final String ingredientId;
  final IngredientRepository _ingredients;
  final IngredientChangeRequestRepository _repository;

  IngredientData? _current;
  final Map<IngredientColumn, Object?> _edits = {};

  IngredientData? get current => _current;

  Future<void> load() async {
    await executeAsyncVoid(() async {
      final fresh = await _ingredients.getByIdFromServer(ingredientId);
      if (fresh == null) throw StateError('Ingredient $ingredientId not found');
      _current = fresh;
      _edits.clear();
    }, errorPrefix: AppLocale.current.adminProposalFormLoadFailed);
  }

  Object? valueOf(IngredientColumn column) => _edits.containsKey(column)
      ? _edits[column]
      : column.oldValueOf(_current!);

  void setValue(IngredientColumn column, Object? value) {
    if (_current == null) return;
    // An edit that equals the old value is no edit.
    if (column.valuesEqual(value, column.oldValueOf(_current!))) {
      _edits.remove(column);
    } else {
      _edits[column] = value;
    }
    notifyListeners();
  }

  bool isChanged(IngredientColumn column) => _edits.containsKey(column);

  List<IngredientColumn> get changedColumns => [
    for (final c in IngredientColumn.values)
      if (_edits.containsKey(c)) c,
  ];

  bool get hasChanges => _edits.isNotEmpty;

  IngredientChangeValidation get validation => validateIngredientChanges(
    _current!,
    Map.unmodifiable(_edits),
  );

  bool noteIsValid(String note) => note.trim().length <= maxNoteLength;

  /// The caller must have asked for confirmation first when this is true.
  bool get needsAllergenConfirmation =>
      _current != null && hasChanges && validation.affectsAllergens;

  /// Returns false, without writing, when nothing changed or anything is
  /// invalid; the view shows [validation] for the reason.
  Future<bool> save(String note) async {
    final current = _current;
    if (current == null || !hasChanges) return false;
    if (!validation.isValid || !noteIsValid(note)) return false;
    return executeAsyncVoid(() async {
      await _repository.create(
        IngredientChangeRequest(
          ingredientId: current.id,
          ingredientUpdatedAt: current.updatedAt,
          note: note.trim(),
          changes: [
            for (final c in changedColumns)
              IngredientFieldChange.from(current, c, _normalized(c)),
          ],
        ),
      );
    }, errorPrefix: AppLocale.current.adminProposalSaveFailed);
  }

  Object? _normalized(IngredientColumn column) {
    final v = _edits[column];
    return switch (column.kind) {
      IngredientColumnKind.text => (v as String?).orEmpty().trim(),
      IngredientColumnKind.list => [
        for (final e in v as Iterable) e.toString().trim(),
      ],
      IngredientColumnKind.number => v,
    };
  }
}
