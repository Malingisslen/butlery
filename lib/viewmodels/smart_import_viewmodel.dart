/// ViewModel for the unified SmartImport view.
///
/// Handles:
/// - Input detection (URL vs text, platform identification)
/// - Import orchestration via ImportManager
/// - State machine for import phases
/// - Result handling for all ImportResultV2 types
library;

import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/input_detector.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/viewmodels/import_progress_tracker.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Import phases for the state machine.
enum ImportPhase {
  /// Waiting for user input
  idle,

  /// Fetching content from URL
  fetching,

  /// Analyzing/parsing recipe content
  analyzing,

  /// Creating recipe in database
  creating,

  /// Import completed successfully
  complete,

  /// Needs user assistance (AssistedImportDialog)
  needsHelp,

  /// Error occurred
  error,
}

/// Result of import attempt for UI handling.
sealed class SmartImportResult {
  const SmartImportResult();
}

/// Import succeeded - navigate to recipe editor.
class ImportSucceeded extends SmartImportResult {
  final Recipe recipe;
  const ImportSucceeded(this.recipe);
}

/// Import needs user assistance - show AssistedImportDialog.
class ImportNeedsUserHelp extends SmartImportResult {
  final String extractedText;
  final String? suggestedTitle;
  final String? thumbnailUrl;
  final String? sourceUrl;
  final List<int> likelyIngredientLines;

  const ImportNeedsUserHelp({
    required this.extractedText,
    this.suggestedTitle,
    this.thumbnailUrl,
    this.sourceUrl,
    this.likelyIngredientLines = const [],
  });
}

/// Import hit rate limit - show RateLimitDialog.
class ImportRateLimited extends SmartImportResult {
  final RateLimitDenied rateLimitResult;
  const ImportRateLimited(this.rateLimitResult);
}

/// Import failed with error.
class ImportFailed extends SmartImportResult {
  final String message;
  const ImportFailed(this.message);
}

/// ViewModel for SmartImportView.
class SmartImportViewModel extends BaseViewModel with AsyncOperationMixin {
  final ImportManager _importManager;
  final InputDetector _inputDetector;

  /// Current input text (URL or pasted text).
  String _input = '';

  /// Current import phase.
  ImportPhase _phase = ImportPhase.idle;

  /// Detection result for current input.
  InputDetectionResult? _detection;

  /// Last import result for UI handling.
  SmartImportResult? _lastResult;

  /// Successfully imported recipe.
  Recipe? _importedRecipe;

  String? _clipboardUrl;
  String? _lastPromptedUrl;

  bool _hasPendingImport = false;
  ConnectivityMonitoringService? _connectivity;

  late final ImportProgressTracker _progressTracker;

  static const String _pendingImportKey = 'butlery_pending_import_url';

  SmartImportViewModel({
    required ImportManager importManager,
    InputDetector? inputDetector,
  })  : _importManager = importManager,
        _inputDetector = inputDetector ?? InputDetector() {
    _progressTracker = ImportProgressTracker(
      notifyListeners: notifyListeners,
      setPhase: _setPhase,
      isDisposed: () => isDisposed,
    );
    _setupConnectivityListener();
    _loadPendingImport();
  }

  // Getters

  String get input => _input;
  ImportPhase get phase => _phase;
  InputDetectionResult? get detection => _detection;
  SmartImportResult? get lastResult => _lastResult;
  Recipe? get importedRecipe => _importedRecipe;
  String? get clipboardUrl => _clipboardUrl;
  bool get hasPendingImport => _hasPendingImport;

  bool get isOnline => _connectivity?.isConnectedToInternet ?? true;

  /// Elapsed time since import started. Duration.zero when idle.
  Duration get elapsed => _progressTracker.elapsed;

  /// Whether input is valid for import.
  bool get canImport => _input.trim().isNotEmpty;

  /// Whether an import is in progress.
  bool get isImporting =>
      _phase == ImportPhase.fetching ||
      _phase == ImportPhase.analyzing ||
      _phase == ImportPhase.creating;

  /// Swedish progress message for current phase.
  String get progressMessage {
    switch (_phase) {
      case ImportPhase.idle:
        return '';
      case ImportPhase.fetching:
        return AppLocale.current.importPhaseFetching;
      case ImportPhase.analyzing:
        return AppLocale.current.importPhaseAnalyzing;
      case ImportPhase.creating:
        return AppLocale.current.importPhaseCreating;
      case ImportPhase.complete:
        return AppLocale.current.importPhaseComplete;
      case ImportPhase.needsHelp:
        return AppLocale.current.importPhaseNeedsHelp;
      case ImportPhase.error:
        return error ?? AppLocale.current.importPhaseError;
    }
  }

  /// Current step number (1-3) for progress indicator.
  int get currentStep {
    switch (_phase) {
      case ImportPhase.idle:
        return 0;
      case ImportPhase.fetching:
        return 1;
      case ImportPhase.analyzing:
        return 2;
      case ImportPhase.creating:
      case ImportPhase.complete:
        return 3;
      case ImportPhase.needsHelp:
      case ImportPhase.error:
        return _lastStepBeforeError;
    }
  }

  int _lastStepBeforeError = 0;

  // Clipboard

  /// Check clipboard for a recipe URL. Called once when the import view opens.
  Future<void> checkClipboardForUrl() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (isDisposed) return;
      final text = clipboardData?.text?.trim();
      if (text == null || text.isEmpty) return;

      final detection = _inputDetector.detect(text);
      if (!detection.isUrl) return;

      if (text == _lastPromptedUrl) return;

      _clipboardUrl = text;
      _lastPromptedUrl = text;
      notifyListeners();
    } catch (e) {
      AppLogger.debug('Clipboard check failed: $e');
    }
  }

  void clearClipboardSuggestion() {
    if (isDisposed) return;
    _clipboardUrl = null;
    notifyListeners();
  }

  // Input Handling

  /// Update input text and detect platform.
  void updateInput(String text) {
    if (isDisposed) return;

    _input = text;
    _detection = _inputDetector.detect(text);

    // Reset state when input changes
    if (_phase != ImportPhase.idle) {
      _phase = ImportPhase.idle;
      _lastResult = null;
      clearError();
    }

    notifyListeners();
  }

  /// Clear all input and state.
  void clearInput() {
    if (isDisposed) return;

    _input = '';
    _detection = null;
    _phase = ImportPhase.idle;
    _lastResult = null;
    _importedRecipe = null;
    clearError();
    notifyListeners();
  }

  // Import Operations

  /// Start the import process.
  Future<SmartImportResult> startImport() async {
    if (!canImport || isImporting) {
      return ImportFailed(AppLocale.current.errorImportConditionsNotMet);
    }

    clearError();
    _lastResult = null;
    _importedRecipe = null;

    // Pre-check connectivity before starting network-dependent import
    if (!isOnline && _detection?.isUrl == true) {
      await _savePendingImportUrl(_input.trim());
      _setPhase(ImportPhase.error);
      setError(AppLocale.current.importSavedForLater);
      final failResult = ImportFailed(AppLocale.current.importErrorNoInternet);
      _lastResult = failResult;
      return failResult;
    }

    _progressTracker.start();
    try {
      // Initial phase — real transitions driven by ImportManager onProgress
      _setPhase(ImportPhase.fetching);
      _lastStepBeforeError = 1;

      // Execute import via ImportManager with real phase callbacks
      final result = await _importManager.autoImport(
        _input.trim(),
        onProgress: _progressTracker.onProgress,
      );

      await _clearPendingImportUrl();
      return await _handleImportResult(result);
    } catch (e) {
      if (_isNetworkError('$e')) {
        await _savePendingImportUrl(_input.trim());
      }
      _setPhase(ImportPhase.error);
      setError(AppLocale.current.errorImportFailed);
      final failResult = ImportFailed('$e');
      _lastResult = failResult;
      return failResult;
    } finally {
      _progressTracker.stop();
    }
  }

  /// Handle import result from ImportManager.
  Future<SmartImportResult> _handleImportResult(
      ImportManagerResult result) async {
    // Check if user assistance is needed
    if (result.needsAssistance) {
      _setPhase(ImportPhase.needsHelp);
      final helpResult = ImportNeedsUserHelp(
        extractedText: result.extractedText ?? '',
        suggestedTitle: result.suggestedTitle,
        thumbnailUrl: result.thumbnailUrl,
        sourceUrl: result.sourceUrl,
        likelyIngredientLines: result.likelyIngredientLines ?? [],
      );
      _lastResult = helpResult;
      return helpResult;
    }

    // Check for rate limit errors
    if (!result.isSuccess && result.errorMessage != null) {
      final errorLower = result.errorMessage!.toLowerCase();
      if (errorLower.contains('rate limit') ||
          errorLower.contains('kvot') ||
          errorLower.contains('gräns')) {
        _setPhase(ImportPhase.error);
        // For now, create a basic rate limit result
        // In production, this would come from the actual rate limiter
        final rateLimitResult = RateLimitDenied(
          limitType: LimitType.perDay,
          message:
              result.errorMessage ?? AppLocale.current.errorDailyQuotaReached,
          retryAfter: const Duration(hours: 1),
          suggestedAction: FallbackAction.useUserAssisted,
        );
        final limitedResult = ImportRateLimited(rateLimitResult);
        _lastResult = limitedResult;
        return limitedResult;
      }
    }

    // Check for other errors
    if (!result.isSuccess) {
      _setPhase(ImportPhase.error);
      final localizedError = _localizeImportError(result.errorMessage);
      setError(localizedError);
      final failResult = ImportFailed(localizedError);
      _lastResult = failResult;
      return failResult;
    }

    // Success!
    _setPhase(ImportPhase.creating);
    _lastStepBeforeError = 3;

    // Recipe is NOT saved yet - user will review and save in editor
    _importedRecipe = result.recipe;

    _setPhase(ImportPhase.complete);
    final successResult = ImportSucceeded(result.recipe!);
    _lastResult = successResult;
    return successResult;
  }

  /// Handle recipe from AssistedImportDialog.
  Future<SmartImportResult> handleAssistedRecipe(Recipe recipe) async {
    try {
      _setPhase(ImportPhase.creating);

      // Save the recipe
      final saveResult = await _importManager.saveImportedRecipe(recipe);

      if (!saveResult.isSuccess) {
        _setPhase(ImportPhase.error);
        setError(saveResult.errorMessage ??
            AppLocale.current.errorCouldNotSaveRecipe);
        final failResult = ImportFailed(saveResult.errorMessage ??
            AppLocale.current.errorCouldNotSaveRecipe);
        _lastResult = failResult;
        return failResult;
      }

      _importedRecipe = saveResult.recipe ?? recipe;
      _setPhase(ImportPhase.complete);
      final successResult = ImportSucceeded(_importedRecipe!);
      _lastResult = successResult;
      return successResult;
    } catch (e) {
      _setPhase(ImportPhase.error);
      setError(AppLocale.current.errorCouldNotSaveRecipe);
      final failResult = ImportFailed('$e');
      _lastResult = failResult;
      return failResult;
    }
  }

  /// Retry import without LLM (for rate limit fallback).
  Future<SmartImportResult> retryWithoutLlm() async {
    if (!canImport) {
      return ImportFailed(AppLocale.current.errorImportConditionsNotMet);
    }

    clearError();
    _lastResult = null;

    _progressTracker.start();
    try {
      _setPhase(ImportPhase.fetching);
      _lastStepBeforeError = 1;

      // Execute import with skipLlm option and real phase callbacks
      final result = await _importManager.autoImport(
        _input.trim(),
        options: {'skipLlm': true},
        onProgress: _progressTracker.onProgress,
      );

      return await _handleImportResult(result);
    } catch (e) {
      _setPhase(ImportPhase.error);
      setError(AppLocale.current.errorImportFailed);
      final failResult = ImportFailed('$e');
      _lastResult = failResult;
      return failResult;
    } finally {
      _progressTracker.stop();
    }
  }

  /// Trigger manual import (show AssistedImportDialog).
  void triggerManualImport() {
    if (!canImport) return;

    _setPhase(ImportPhase.needsHelp);
    final helpResult = ImportNeedsUserHelp(
      extractedText: _input.trim(),
      sourceUrl: _detection?.isUrl == true ? _input.trim() : null,
    );
    _lastResult = helpResult;
    notifyListeners();
  }

  // Private Helpers

  /// Maps English error messages from ImportManager to localized strings.
  String _localizeImportError(String? errorMessage) {
    if (errorMessage == null) return AppLocale.current.errorUnknown;

    final lower = errorMessage.toLowerCase();
    final l10n = AppLocale.current;

    if (lower.contains('no import strategy') ||
        lower.contains('could not parse')) {
      return l10n.importErrorCouldNotParseRecipe;
    }
    if (lower.contains('no recipe found')) {
      return l10n.importErrorNoRecipeFound;
    }
    if (_isNetworkError(lower)) {
      return l10n.importErrorCouldNotReachPage;
    }
    if (lower.contains('invalid url')) {
      return l10n.importErrorInvalidUrl;
    }
    if (lower.contains('login required') || lower.contains('authentication')) {
      return l10n.importErrorLoginRequired;
    }
    if (lower.contains('could not read') || lower.contains('ocr')) {
      return l10n.importErrorCouldNotReadImage;
    }
    if (lower.contains('could not save')) {
      return l10n.importErrorCouldNotSaveRecipe;
    }
    if (lower.contains('cancelled') || lower.contains('canceled')) {
      return l10n.importErrorCancelled;
    }
    if (lower.contains('no internet')) {
      return l10n.importErrorNoInternet;
    }

    return l10n.importErrorUnexpected;
  }

  void _setPhase(ImportPhase phase) {
    if (isDisposed) return;
    _phase = phase;
    // Keep _lastStepBeforeError in sync with phase transitions from onProgress
    if (phase == ImportPhase.fetching) _lastStepBeforeError = 1;
    if (phase == ImportPhase.analyzing) _lastStepBeforeError = 2;
    if (phase == ImportPhase.creating) _lastStepBeforeError = 3;
    notifyListeners();
  }

  static bool _isNetworkError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('network') ||
        lower.contains('timeout') ||
        lower.contains('no internet') ||
        lower.contains('could not reach');
  }

  void _setupConnectivityListener() {
    _connectivity = ServiceLocator.tryGet<ConnectivityMonitoringService>();
    _connectivity?.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    if (isDisposed) return;
    if ((_connectivity?.isConnectedToInternet ?? false) && _hasPendingImport) {
      notifyListeners();
    }
  }

  Future<void> _loadPendingImport() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isDisposed) return;
      final url = prefs.getString(_pendingImportKey);
      if (url != null && url.isNotEmpty) {
        _hasPendingImport = true;
        if (_input.isEmpty) {
          _input = url;
          _detection = _inputDetector.detect(url);
        }
        notifyListeners();
      }
    } catch (e) {
      AppLogger.warning('Failed to load pending import: $e');
    }
  }

  Future<void> _savePendingImportUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isDisposed) return;
      await prefs.setString(_pendingImportKey, url);
      _hasPendingImport = true;
    } catch (e) {
      AppLogger.warning('Failed to save pending import URL: $e');
    }
  }

  Future<void> _clearPendingImportUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isDisposed) return;
      await prefs.remove(_pendingImportKey);
      _hasPendingImport = false;
    } catch (e) {
      AppLogger.warning('Failed to clear pending import URL: $e');
    }
  }

  Future<void> retryPendingImport() async {
    if (!_hasPendingImport || !isOnline) return;
    // Read persisted URL directly — _input may have been changed by the user
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isDisposed) return;
      final url = prefs.getString(_pendingImportKey);
      if (url != null && url.isNotEmpty) {
        _input = url;
        _detection = _inputDetector.detect(url);
        notifyListeners();
      }
    } catch (e) {
      AppLogger.warning('Failed to read pending import URL: $e');
    }
    await startImport();
  }

  Future<void> dismissPendingImport() async {
    await _clearPendingImportUrl();
    notifyListeners();
  }

  @override
  Map<String, dynamic> get debugState => {
        ...super.debugState,
        'input': _input.length > 50 ? '${_input.substring(0, 50)}...' : _input,
        'phase': _phase.name,
        'detection': _detection?.platform.name,
        'canImport': canImport,
        'isImporting': isImporting,
        'hasPendingImport': _hasPendingImport,
        'isOnline': isOnline,
      };

  @override
  void dispose() {
    _progressTracker.dispose();
    _connectivity?.removeListener(_onConnectivityChanged);
    _input = '';
    _detection = null;
    _lastResult = null;
    _importedRecipe = null;
    _clipboardUrl = null;
    _lastPromptedUrl = null;
    super.dispose();
  }
}
