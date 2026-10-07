/// Base ViewModel for all import operations.

// lib/viewmodels/import_base_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';

abstract class ImportBaseViewModel extends BaseViewModel
    with AsyncOperationMixin {
  final ImportManager _importManager;
  final ConnectivityMonitoringService? _connectivity;

  Recipe? _parsedRecipe;
  String? _sourceUrl;

  ImportBaseViewModel({
    required ImportManager importManager,
    ConnectivityMonitoringService? connectivity,
  }) : _importManager = importManager,
       // BUT-1360 (mirrors BUT-610): default-resolve from ServiceLocator so
       // existing subclass `super(importManager: ...)` calls need no change;
       // tests inject an offline double. tryGet (not get) keeps the VM usable
       // when connectivity DI is absent — that case is treated as online.
       _connectivity =
           connectivity ??
           ServiceLocator.tryGet<ConnectivityMonitoringService>();

  /// BUT-1360 offline pre-check: unknown/missing connectivity defaults to online.
  bool get isOnline => _connectivity?.isConnectedToInternet ?? true;

  Recipe? get parsedRecipe => _parsedRecipe;
  bool get hasParsedRecipe => _parsedRecipe != null;
  String? get sourceUrl => _sourceUrl;
  bool get canImport => true;
  bool get isParsing => isLoading;
  bool get canParse => true;

  @protected
  ImportManager get importManager => _importManager;

  @protected
  void setParsedRecipe(Recipe? recipe) {
    if (isDisposed) return;
    _parsedRecipe = recipe;
    notifyListeners();
  }

  void setSourceUrl(String? url) {
    if (isDisposed) return;
    _sourceUrl = url;
    notifyListeners();
  }

  @protected
  void clearImportData() {
    if (isDisposed) return;
    _parsedRecipe = null;
    _sourceUrl = null;
    clearState();
  }

  String get importType;

  @protected
  void updateParsedRecipe({
    String? title,
    String? description,
    List<String>? ingredients,
    List<String>? instructions,
    String? mealType,
    int? portions,
    int? timeMinutes,
    List<String>? tags,
    List<String>? imageUrls,
  }) {
    if (_parsedRecipe == null || isDisposed) return;

    final updatedRecipe = _parsedRecipe!.copyWith(
      title: title,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      personalTagIds: tags,
      imageUrls: imageUrls,
    );

    setParsedRecipe(updatedRecipe);
  }

  void clearAll() {
    if (isDisposed) return;

    _parsedRecipe = null;
    _sourceUrl = null;
    clearError();
    notifyListeners();
  }

  @override
  Map<String, dynamic> get debugState => {
    ...super.debugState,
    'hasParsedRecipe': hasParsedRecipe,
    'sourceUrl': _sourceUrl,
    'canImport': canImport,
    'importType': importType,
  };

  @override
  void dispose() {
    clearImportData();
    super.dispose();
  }
}

mixin TextImportMixin on ImportBaseViewModel {
  String _inputText = '';

  String get inputText => _inputText;
  bool get hasValidInput => _inputText.trim().isNotEmpty;

  @override
  bool get canImport => hasValidInput;

  void updateInputText(String text) {
    if (isDisposed) return;

    _inputText = text;
    clearError();

    // Clear previous results if text changed significantly
    if (text.trim().isEmpty) {
      clearImportData();
    }

    notifyListeners();
  }

  void clearInput() {
    if (isDisposed) return;

    _inputText = '';
    clearImportData();
  }

  @override
  String get importType => 'text';

  @override
  Map<String, dynamic> get debugState => {
    ...super.debugState,
    'inputText': _inputText.length > 50
        ? '${_inputText.substring(0, 50)}...'
        : _inputText,
    'hasValidInput': hasValidInput,
  };
}
