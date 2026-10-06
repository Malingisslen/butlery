/// Base ViewModel for all import operations.

// lib/viewmodels/import_base_viewmodel.dart

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe/heirloom_metadata.dart';
import 'package:butlery/repositories/interfaces/storage_repository.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/heirloom_bridge.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/image_format_utils.dart';
import 'package:butlery/core/utils/logger.dart';

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

  Future<bool> saveImportedRecipe() async {
    if (_parsedRecipe == null) {
      setError(AppLocale.current.errorNoRecipeToSave);
      return false;
    }

    return await executeAsyncVoid(() async {
      // BUT-953: if PhotoImportView stashed a heirloom draft before
      // navigating here, upload the scan + attach metadata before save.
      // Upload failure blocks the save so the user sees the error instead
      // of a false success toast.
      await _attachHeirloomIfPending();

      final result = await _importManager.saveImportedRecipe(_parsedRecipe!);
      if (!result.isSuccess) {
        throw Exception(result.errorMessage ?? 'Failed to save recipe');
      }
    });
  }

  /// BUT-953: consume any pending heirloom draft, upload the image, attach
  /// the resulting [HeirloomMetadata] to [_parsedRecipe]. Throws on upload
  /// failure so the surrounding `executeAsyncVoid` surfaces the error.
  ///
  /// On any failure (auth, upload), the draft is **restored** to the bridge
  /// so the user's next save attempt can retry without re-filling the form.
  /// `ServiceLocator.get<HeirloomBridge>` (not `tryGet`) so missing DI fails
  /// loud in dev — the bridge is the whole BUT-953 wiring contract.
  Future<void> _attachHeirloomIfPending() async {
    final bridge = ServiceLocator.get<HeirloomBridge>();
    if (!bridge.hasPending) return;
    final draft = bridge.consumeDraft();
    if (draft == null) return;

    try {
      final permission = ServiceLocator.get<PermissionService>();
      // Mirror BUT-1086: re-check auth AND uid together so a sign-out
      // mid-import surfaces the right error instead of a Storage rules deny.
      if (!permission.isAuthenticated || permission.currentUserId == null) {
        throw Exception(AppLocale.current.errorAuthentication);
      }
      final userId = permission.currentUserId!;

      final storage = ServiceLocator.get<StorageRepository>();
      final recipeId = _parsedRecipe!.id;
      final digest = sha256
          .convert(draft.imageBytes)
          .toString()
          .substring(0, 16);
      // BUT-1161: derive the extension from the real image bytes instead of
      // hardcoding .jpg — heirloom scans can be PNG/HEIC/WebP and a mismatched
      // suffix drives the wrong content-type fallback in the storage layer.
      final ext = ImageFormatUtils.extensionFromBytes(draft.imageBytes);
      final path = 'users/$userId/recipes/$recipeId/heirloom/$digest.$ext';

      final url = await storage.uploadImageData(
        imageData: draft.imageBytes,
        userId: userId,
        path: path,
        // Content-addressed → safe to cache for a year.
        cacheControl: 'public, max-age=31536000, immutable',
        metadata: {'purpose': 'heirloom', 'recipeId': recipeId},
      );

      if (url == null) {
        AppLogger.warning('Heirloom upload returned null URL for $recipeId');
        throw Exception(AppLocale.current.errorGeneric);
      }

      final metadata = HeirloomMetadata(
        sourceImageUrl: url,
        writerName: draft.writerName,
        year: draft.year,
        note: draft.note,
        addedAt: clock.now(),
        addedByUserId: userId,
      );

      _parsedRecipe = _parsedRecipe!.copyWith(heirloom: metadata);
      notifyListeners();
    } catch (_) {
      // Restore the draft so the user's next save attempt retries instead
      // of silently saving without the heirloom they entered.
      bridge.setDraft(draft);
      rethrow;
    }
  }

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
