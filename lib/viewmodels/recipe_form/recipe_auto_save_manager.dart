// lib/viewmodels/recipe_form/recipe_auto_save_manager.dart

import 'package:clock/clock.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Draft metadata for managing saved drafts
class DraftMetadata {
  final String draftId;
  final DateTime createdAt;
  final DateTime lastModifiedAt;
  final String title;
  final int fieldCount; // Number of filled fields for content assessment

  const DraftMetadata({
    required this.draftId,
    required this.createdAt,
    required this.lastModifiedAt,
    required this.title,
    required this.fieldCount,
  });

  Map<String, dynamic> toJson() => {
        'draftId': draftId,
        'createdAt': createdAt.toIso8601String(),
        'lastModifiedAt': lastModifiedAt.toIso8601String(),
        'title': title,
        'fieldCount': fieldCount,
      };

  factory DraftMetadata.fromJson(Map<String, dynamic> json) => DraftMetadata(
        draftId: (json['draftId'] as String?).orEmpty(),
        createdAt: SerializationUtils.safeRequiredDateTime(json, 'createdAt'),
        lastModifiedAt:
            SerializationUtils.safeRequiredDateTime(json, 'lastModifiedAt'),
        title: (json['title'] as String?).orEmpty(),
        fieldCount: (json['fieldCount'] as int?).orZero(),
      );

  /// Check if draft is recent (within last 24 hours)
  bool get isRecent => clock.now().difference(lastModifiedAt).inHours < 24;

  /// Get human-readable time since last modification
  String get timeAgo => ContextualTimeFormatter.compact(lastModifiedAt);
}

/// Intelligent auto-save manager for recipe forms with draft persistence and recovery
class RecipeFormAutoSaveManager extends ChangeNotifier {
  static const String _draftsKey = 'recipe_drafts_metadata';
  static const String _draftPrefix = 'recipe_draft_';
  static const Duration _autoSaveDelay = Duration(seconds: 3);
  static const Duration _quickAutoSaveDelay = Duration(seconds: 1);
  static const int _minFieldsForAutoSave =
      2; // Minimum fields to consider worth saving
  static const int _maxDrafts = 5; // Maximum number of drafts to keep

  Timer? _autoSaveTimer;
  Timer? _feedbackTimer;
  String? _currentDraftId;
  bool _isAutoSaving = false;
  bool _isDisposed = false;
  bool _hasShownAutoSaveNotice = false;
  DateTime? _lastAutoSaveTime;
  bool _isTemplate = false; // Track if this is a template-based form
  Completer<void>? _metadataWriteLock;

  // Auto-save state for UI feedback
  bool get isAutoSaving => _isAutoSaving;
  bool get hasRecentAutoSave =>
      _lastAutoSaveTime != null &&
      clock.now().difference(_lastAutoSaveTime!).inSeconds < 10;
  String? get currentDraftId => _currentDraftId;

  /// Initialize auto-save manager and check for existing drafts
  /// [isTemplate] - If true, disables auto-save for template-based forms until first significant edit
  Future<void> initialize({bool isTemplate = false}) async {
    _isTemplate = isTemplate;
    await _cleanupOldDrafts();

    if (isTemplate) {
      AppLogger.info(
          '🔄 AUTO_SAVE: Manager initialized for TEMPLATE (auto-save disabled until edit)');
    } else {
      AppLogger.info('🔄 AUTO_SAVE: Manager initialized for regular form');
    }
  }

  /// Schedule debounced auto-save with intelligent timing
  /// [skipIfBusy] - Skip scheduling if other operations are in progress
  void scheduleAutoSave(Map<String, dynamic> formData,
      {bool isQuickSave = false, bool skipIfBusy = false}) {
    _autoSaveTimer?.cancel();

    // RACE CONDITION GUARD: Skip if already auto-saving to prevent conflicts
    if (_isAutoSaving && skipIfBusy) {
      AppLogger.debug(
          '🔄 AUTO_SAVE: Skipping schedule - auto-save already in progress');
      return;
    }

    // Use quick save for critical changes (title, description)
    final delay = isQuickSave ? _quickAutoSaveDelay : _autoSaveDelay;

    _autoSaveTimer = Timer(delay, () => _performAutoSave(formData));

    AppLogger.debug(
        '🔄 AUTO_SAVE: Scheduled auto-save in ${delay.inSeconds}s (quick: $isQuickSave)');
  }

  /// Perform intelligent auto-save with content validation
  Future<void> _performAutoSave(Map<String, dynamic> formData) async {
    if (_isAutoSaving) {
      AppLogger.debug(
          '🔄 AUTO_SAVE: Already saving, skipping duplicate request');
      return;
    }

    if (!_shouldAutoSave(formData)) {
      AppLogger.debug(
          '🔄 AUTO_SAVE: Content not significant enough for auto-save');
      return;
    }

    _isAutoSaving = true;
    if (!_isDisposed) notifyListeners();

    try {
      final now = clock.now();
      final draftId = _currentDraftId ?? 'draft_${now.millisecondsSinceEpoch}';
      _currentDraftId = draftId;

      // Create draft metadata
      final metadata = DraftMetadata(
        draftId: draftId,
        createdAt: _currentDraftId == draftId
            ? now
            : await _getExistingDraftCreationTime(draftId) ?? now,
        lastModifiedAt: now,
        title: _extractTitle(formData),
        fieldCount: _countFilledFields(formData),
      );

      // Save draft data and metadata
      await _saveDraftData(draftId, formData);
      await _saveDraftMetadata(metadata);

      _lastAutoSaveTime = now;

      // Show subtle user feedback (once per session)
      if (!_hasShownAutoSaveNotice) {
        _showAutoSaveNotice();
        _hasShownAutoSaveNotice = true;
      }

      AppLogger.info(
          '🔄 AUTO_SAVE: Draft saved successfully - ID: $draftId, fields: ${metadata.fieldCount}');
    } catch (e) {
      AppLogger.error('🔄 AUTO_SAVE: Failed to save draft: $e');
      // Don't show error to user for auto-save failures - it's background operation
    } finally {
      _isAutoSaving = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Check if content is significant enough for auto-save
  bool _shouldAutoSave(Map<String, dynamic> formData) {
    final filledFields = _countFilledFields(formData);

    // For templates, only auto-save after significant editing
    if (_isTemplate) {
      // Promote template to regular form after substantial changes
      if (_hasSignificantTemplateChanges(formData)) {
        _isTemplate = false; // Convert template to regular form
        AppLogger.info(
            '🔄 AUTO_SAVE: Template promoted to regular form after significant changes');
      } else {
        AppLogger.debug(
            '🔄 AUTO_SAVE: Skipping auto-save for template (insufficient changes)');
        return false; // Don't auto-save templates until they're significantly modified
      }
    }

    return filledFields >= _minFieldsForAutoSave;
  }

  /// Check if template has been significantly modified to warrant auto-save
  bool _hasSignificantTemplateChanges(Map<String, dynamic> formData) {
    int changeScore = 0;

    // Major edits that indicate user is actively customizing the template
    final title = (formData['title'] as String?).orEmpty();
    final description = (formData['description'] as String?).orEmpty();
    final ingredients = (formData['ingredients'] as List<String>?).orEmpty();
    final instructions = (formData['instructions'] as List<String>?).orEmpty();

    // Title or description editing (indicates intentional customization)
    if (title.trim().isNotEmpty) changeScore += 2;
    if (description.trim().isNotEmpty) changeScore += 2;

    // Adding new ingredients/instructions (beyond template)
    changeScore += ingredients.where((i) => i.trim().isNotEmpty).length;
    changeScore += instructions.where((i) => i.trim().isNotEmpty).length;

    // Images indicate serious editing intent
    final imageUrls = (formData['imageUrls'] as List<String>?).orEmpty();
    changeScore += imageUrls.length * 3;

    // Portion/time changes indicate recipe customization
    if (formData['portions'] != null && formData['portions'] > 0) {
      changeScore += 1;
    }
    if (formData['timeMinutes'] != null && formData['timeMinutes'] > 0) {
      changeScore += 1;
    }

    // Need at least 5 points of changes to convert template to auto-saveable form
    const int significantChangeThreshold = 5;
    return changeScore >= significantChangeThreshold;
  }

  /// Count non-empty form fields to assess content significance
  int _countFilledFields(Map<String, dynamic> formData) {
    int count = 0;

    // Core fields
    if (_isNotEmpty(formData['title'])) count++;
    if (_isNotEmpty(formData['description'])) count++;
    if (formData['portions'] != null && formData['portions'] > 0) count++;
    if (formData['timeMinutes'] != null && formData['timeMinutes'] > 0) count++;
    if (_isNotEmpty(formData['sourceUrl'])) count++;

    // Dynamic lists
    final ingredients = (formData['ingredients'] as List<String>?).orEmpty();
    count += ingredients.where((i) => i.trim().isNotEmpty).length;

    final instructions = (formData['instructions'] as List<String>?).orEmpty();
    count += instructions.where((i) => i.trim().isNotEmpty).length;

    final tags = (formData['tags'] as List<String>?).orEmpty();
    count += tags.where((t) => t.trim().isNotEmpty).length;

    // Images
    final imageUrls = (formData['imageUrls'] as List<String>?).orEmpty();
    count += imageUrls.length;

    return count;
  }

  /// Extract meaningful title for draft identification
  String _extractTitle(Map<String, dynamic> formData) {
    final title = (formData['title'] as String?).orEmpty();
    if (title.trim().isNotEmpty) return title.trim();

    // Fallback to first ingredient if no title
    final ingredients = (formData['ingredients'] as List<String>?).orEmpty();
    final firstIngredient =
        ingredients.firstWhere((i) => i.trim().isNotEmpty, orElse: () => '');

    if (firstIngredient.isNotEmpty) {
      return AppLocale.current.recipeAutoTitleWithIngredient(firstIngredient);
    }

    return AppLocale.current.recipeAutoTitleUntitled;
  }

  /// Save draft data to local storage
  Future<void> _saveDraftData(
      String draftId, Map<String, dynamic> formData) async {
    final prefs = await SharedPreferences.getInstance();
    final draftKey = '$_draftPrefix$draftId';
    final jsonData = jsonEncode(formData);
    await prefs.setString(draftKey, jsonData);
  }

  /// Save draft metadata for management.
  /// Uses a Completer lock to serialize concurrent writes and prevent
  /// a second read-modify-write from overwriting the first.
  Future<void> _saveDraftMetadata(DraftMetadata metadata) async {
    // Chain on previous write to serialize concurrent access
    final previous = _metadataWriteLock?.future ?? Future.value();
    final thisLock = Completer<void>();
    _metadataWriteLock = thisLock;
    await previous;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingMetadata = await _loadAllDraftMetadata();

      existingMetadata.removeWhere((m) => m.draftId == metadata.draftId);
      existingMetadata.add(metadata);

      existingMetadata
          .sort((a, b) => b.lastModifiedAt.compareTo(a.lastModifiedAt));
      if (existingMetadata.length > _maxDrafts) {
        final draftsToRemove = existingMetadata.sublist(_maxDrafts);
        for (final draft in draftsToRemove) {
          await _deleteDraft(draft.draftId);
        }
        existingMetadata.removeRange(_maxDrafts, existingMetadata.length);
      }

      final metadataJson =
          jsonEncode(existingMetadata.map((m) => m.toJson()).toList());
      await prefs.setString(_draftsKey, metadataJson);
    } finally {
      thisLock.complete();
    }
  }

  /// Load all draft metadata
  Future<List<DraftMetadata>> _loadAllDraftMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadataJson = prefs.getString(_draftsKey);
      if (metadataJson == null) return [];

      final metadataList = jsonDecode(metadataJson) as List;
      return metadataList.map((json) => DraftMetadata.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('🔄 AUTO_SAVE: Failed to load draft metadata: $e');
      return [];
    }
  }

  /// Get existing draft creation time
  Future<DateTime?> _getExistingDraftCreationTime(String draftId) async {
    final metadata = await _loadAllDraftMetadata();
    final existing = metadata.where((m) => m.draftId == draftId).firstOrNull;
    return existing?.createdAt;
  }

  /// Load specific draft data
  Future<Map<String, dynamic>?> loadDraftData(String draftId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftKey = '$_draftPrefix$draftId';
      final jsonData = prefs.getString(draftKey);
      if (jsonData == null) return null;

      return jsonDecode(jsonData) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.error(
          '🔄 AUTO_SAVE: Failed to load draft data for $draftId: $e');
      return null;
    }
  }

  /// Get available drafts for recovery
  Future<List<DraftMetadata>> getAvailableDrafts() async {
    final metadata = await _loadAllDraftMetadata();
    // Return recent drafts sorted by modification time
    return metadata.where((m) => m.isRecent).toList()
      ..sort((a, b) => b.lastModifiedAt.compareTo(a.lastModifiedAt));
  }

  /// Delete specific draft
  Future<void> deleteDraft(String draftId) async {
    await _deleteDraft(draftId);

    // Update metadata
    final metadata = await _loadAllDraftMetadata();
    metadata.removeWhere((m) => m.draftId == draftId);

    final prefs = await SharedPreferences.getInstance();
    final metadataJson = jsonEncode(metadata.map((m) => m.toJson()).toList());
    await prefs.setString(_draftsKey, metadataJson);

    AppLogger.info('🔄 AUTO_SAVE: Draft deleted: $draftId');
  }

  /// Internal draft deletion
  Future<void> _deleteDraft(String draftId) async {
    final prefs = await SharedPreferences.getInstance();
    final draftKey = '$_draftPrefix$draftId';
    await prefs.remove(draftKey);
  }

  /// Clear current draft after successful save
  void clearCurrentDraft() {
    if (_currentDraftId != null) {
      deleteDraft(_currentDraftId!);
      _currentDraftId = null;
    }
  }

  /// Cleanup old drafts beyond retention period
  Future<void> _cleanupOldDrafts() async {
    final metadata = await _loadAllDraftMetadata();
    final oldDrafts = metadata.where((m) => !m.isRecent).toList();

    for (final draft in oldDrafts) {
      await _deleteDraft(draft.draftId);
    }

    if (oldDrafts.isNotEmpty) {
      // Update metadata to remove old drafts
      final remainingMetadata = metadata.where((m) => m.isRecent).toList();
      final prefs = await SharedPreferences.getInstance();
      final metadataJson =
          jsonEncode(remainingMetadata.map((m) => m.toJson()).toList());
      await prefs.setString(_draftsKey, metadataJson);

      AppLogger.info('🔄 AUTO_SAVE: Cleaned up ${oldDrafts.length} old drafts');
    }
  }

  /// Immediately flush any pending auto-save (cancels debounce timer).
  /// Used when the app is backgrounded or about to be killed.
  Future<void> saveNow(Map<String, dynamic> formData) async {
    _autoSaveTimer?.cancel();
    await _performAutoSave(formData);
  }

  /// Show subtle auto-save notice to user (once per session)
  void _showAutoSaveNotice() {
    // Delayed subtle notification
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 1500), () {
      // This would be called in context where BuildContext is available
      AppLogger.info(
          '🔄 AUTO_SAVE: Auto-save enabled - drafts saved automatically');
    });
  }

  /// Show user feedback about auto-save status (to be called from UI)
  static void showAutoSaveNotice(BuildContext context) {
    UtilityComponents.showSuccessSnackbar(
      context,
      AppLocale.current.autoSaveEnabled,
    );
  }

  /// Utility helper
  bool _isNotEmpty(dynamic value) {
    return value != null && value.toString().trim().isNotEmpty;
  }

  /// Dispose resources
  @override
  void dispose() {
    _isDisposed = true;
    _autoSaveTimer?.cancel();
    _feedbackTimer?.cancel();
    // Unblock any waiter before tearing down
    if (_metadataWriteLock != null && !_metadataWriteLock!.isCompleted) {
      _metadataWriteLock!.complete();
    }
    super.dispose();
  }
}
