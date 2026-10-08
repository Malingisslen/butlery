// lib/viewmodels/recipe_form/recipe_auto_save_manager.dart

import 'package:clock/clock.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Draft metadata for managing saved drafts
class DraftMetadata {
  final String draftId;
  final DateTime createdAt;
  final DateTime lastModifiedAt;
  final String title;
  final int fieldCount; // Number of filled fields for content assessment

  /// The account that wrote the draft, or null for a draft written before
  /// drafts carried an owner. Drafts live on the device, not on the account
  /// (produktregler.md:169), and an automatic sign-out keeps them (PQ-12 = A),
  /// so a draft is only offered to the account that wrote it.
  final String? ownerId;

  const DraftMetadata({
    required this.draftId,
    required this.createdAt,
    required this.lastModifiedAt,
    required this.title,
    required this.fieldCount,
    this.ownerId,
  });

  Map<String, dynamic> toJson() => {
    'draftId': draftId,
    'createdAt': createdAt.toIso8601String(),
    'lastModifiedAt': lastModifiedAt.toIso8601String(),
    'title': title,
    'fieldCount': fieldCount,
    'ownerId': ?ownerId,
  };

  factory DraftMetadata.fromJson(Map<String, dynamic> json) => DraftMetadata(
    draftId: (json['draftId'] as String?).orEmpty(),
    createdAt: SerializationUtils.safeRequiredDateTime(json, 'createdAt'),
    lastModifiedAt: SerializationUtils.safeRequiredDateTime(
      json,
      'lastModifiedAt',
    ),
    title: (json['title'] as String?).orEmpty(),
    fieldCount: (json['fieldCount'] as int?).orZero(),
    ownerId: json['ownerId'] as String?,
  );

  /// When the draft stops being resumable: 30 days after the last change
  /// (ux-beslut.json D-01; produktregler.md:170).
  DateTime get expiresAt =>
      lastModifiedAt.add(RecipeFormAutoSaveManager.draftLifetime);

  /// How long the draft is still kept. The list says this rather than when
  /// the draft was written (Skarmar v12 etapp 4 #editorutkastval).
  Duration get timeLeft {
    final left = expiresAt.difference(clock.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Whether the draft is still within its lifetime.
  bool get isRecent =>
      clock.now().difference(lastModifiedAt) <
      RecipeFormAutoSaveManager.draftLifetime;

  /// Get human-readable time since last modification
  String get timeAgo => ContextualTimeFormatter.compact(lastModifiedAt);
}

/// Intelligent auto-save manager for recipe forms with draft persistence and recovery
class RecipeFormAutoSaveManager extends ChangeNotifier {
  /// [ownerIdProvider] names the signed-in account; it defaults to
  /// [AuthService.currentUserId].
  RecipeFormAutoSaveManager({String? Function()? ownerIdProvider})
    : _ownerIdProvider = ownerIdProvider ?? _signedInUserId;

  static const String _draftsKey = 'recipe_drafts_metadata';
  static const String _draftPrefix = 'recipe_draft_';

  /// Later saves are debounced; the FIRST one is not (see [scheduleAutoSave]).
  static const Duration _autoSaveDelay = Duration(seconds: 3);
  static const Duration _quickAutoSaveDelay = Duration(seconds: 1);

  /// One filled field is enough: "Utkastet persisteras från det första
  /// tecken användaren skriver. Ingen tidsgräns och inget krav på ifyllda
  /// fält får fördröja den första persisteringen" (ux-beslut.json D-02).
  static const int _minFieldsForAutoSave = 1;

  /// Five slots per account (produktregler.md:790; D-01 changed only the
  /// lifetime).
  static const int maxDrafts = 5;

  /// "Ett påbörjat recept är återupptagbart i 30 dagar sedan senaste
  /// ändring" (ux-beslut.json D-01, superseding the 24 h of
  /// produktregler.md:790).
  static const Duration draftLifetime = Duration(days: 30);

  final String? Function() _ownerIdProvider;

  static String? _signedInUserId() {
    try {
      if (!ServiceLocator.isRegistered<AuthService>()) return null;
      return ServiceLocator.get<AuthService>().currentUserId;
    } catch (_) {
      return null;
    }
  }

  /// Deletes the recipe drafts of the account that signs out, and the
  /// ownerless drafts written before drafts carried an owner (those were
  /// offered to that account, see [getAvailableDrafts]). Another account's
  /// drafts on the same device stay: it may have kept them through its own
  /// automatic sign-out (PQ-12 = A).
  ///
  /// Called on an explicit sign-out only (produktregler.md:171; PQ-12 = A in
  /// produktbeslut-2026-09-23.json: an automatic sign-out keeps drafts).
  /// Best-effort: logs and never throws, so a sign-out cannot fail on it.
  static Future<void> clearDraftsFor(String? ownerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftsKey);
      final all = raw == null
          ? const <DraftMetadata>[]
          : (jsonDecode(raw) as List)
                .map(
                  (json) =>
                      DraftMetadata.fromJson(json as Map<String, dynamic>),
                )
                .toList();
      final kept = all
          .where((m) => m.ownerId != null && m.ownerId != ownerId)
          .toList();
      final keptKeys = {for (final m in kept) '$_draftPrefix${m.draftId}'};
      // A draft body without an index entry is offered to nobody and has
      // no known owner; it goes like an ownerless draft.
      final gone = prefs
          .getKeys()
          .where((k) => k.startsWith(_draftPrefix) && !keptKeys.contains(k))
          .toList();
      for (final key in gone) {
        await prefs.remove(key);
      }
      if (kept.isEmpty) {
        await prefs.remove(_draftsKey);
      } else {
        await prefs.setString(
          _draftsKey,
          jsonEncode(kept.map((m) => m.toJson()).toList()),
        );
      }
      AppLogger.info('AUTO_SAVE: ${gone.length} drafts deleted at sign-out');
    } catch (e) {
      AppLogger.warning('AUTO_SAVE: could not delete drafts: $e');
    }
  }

  Timer? _autoSaveTimer;
  Timer? _feedbackTimer;
  String? _currentDraftId;
  bool _isAutoSaving = false;
  bool _isDisposed = false;
  bool _hasShownAutoSaveNotice = false;
  DateTime? _lastAutoSaveTime;
  bool _isTemplate = false; // Track if this is a template-based form
  Completer<void>? _metadataWriteLock;
  bool _hasSaveFailed = false;
  int _failurePeriod = 0;

  // Auto-save state for UI feedback
  bool get isAutoSaving => _isAutoSaving;
  bool get hasRecentAutoSave =>
      _lastAutoSaveTime != null &&
      clock.now().difference(_lastAutoSaveTime!).inSeconds < 10;
  String? get currentDraftId => _currentDraftId;

  /// Whether the latest draft write failed. The editor shows a warning
  /// triangle instead of the cloud while this holds (BUT-2224 = A).
  bool get hasAutoSaveFailed => _hasSaveFailed;

  /// Counts failure periods: it grows when a period starts, not on every
  /// failed write, so the editor can show its failure snackbar once per
  /// period (BUT-2224 = A).
  int get autoSaveFailurePeriod => _failurePeriod;

  /// BUT-1136 test seam: lets tests assert that a pending debounce timer
  /// survives a `scheduleAutoSave(..., skipIfBusy: true)` call while a
  /// prior save is in flight (instead of being silently cancelled).
  @visibleForTesting
  bool get hasPendingAutoSaveTimer => _autoSaveTimer?.isActive ?? false;

  /// BUT-1136 test seam: lets tests flip `_isAutoSaving` to simulate a
  /// save in flight without relying on the fragile `saveNow()` mid-await
  /// state (which would also cancel the pending timer via its own
  /// `_autoSaveTimer?.cancel()` prelude).
  @visibleForTesting
  // ignore: avoid_setters_without_getters
  set debugIsAutoSaving(bool value) => _isAutoSaving = value;

  /// Initialize auto-save manager and check for existing drafts
  /// [isTemplate] - If true, disables auto-save for template-based forms until first significant edit
  Future<void> initialize({bool isTemplate = false}) async {
    _isTemplate = isTemplate;
    await _cleanupOldDrafts();

    if (isTemplate) {
      AppLogger.info(
        '🔄 AUTO_SAVE: Manager initialized for TEMPLATE (auto-save disabled until edit)',
      );
    } else {
      AppLogger.info('🔄 AUTO_SAVE: Manager initialized for regular form');
    }
  }

  /// Schedule debounced auto-save with intelligent timing
  /// [skipIfBusy] - Skip scheduling if other operations are in progress
  void scheduleAutoSave(
    Map<String, dynamic> formData, {
    bool isQuickSave = false,
    bool skipIfBusy = false,
  }) {
    // BUT-1136: guard BEFORE cancel — when skipIfBusy returns early, the
    // existing debounce timer survives so the queued edit eventually fires
    // when the in-flight save completes. The pre-fix order silently dropped
    // the queued timer.
    if (_isAutoSaving && skipIfBusy) {
      AppLogger.debug(
        '🔄 AUTO_SAVE: Skipping schedule - auto-save already in progress (existing timer preserved)',
      );
      return;
    }

    _autoSaveTimer?.cancel();

    // D-02: the first persistence is never delayed. Until a draft exists the
    // edit is written at once; after that, saves are debounced as before.
    if (_currentDraftId == null && !_isAutoSaving) {
      unawaited(_performAutoSave(formData));
      return;
    }

    // Use quick save for critical changes (title, description)
    final delay = isQuickSave ? _quickAutoSaveDelay : _autoSaveDelay;

    _autoSaveTimer = Timer(delay, () => _performAutoSave(formData));

    AppLogger.debug(
      '🔄 AUTO_SAVE: Scheduled auto-save in ${delay.inSeconds}s (quick: $isQuickSave)',
    );
  }

  /// Perform intelligent auto-save with content validation
  Future<void> _performAutoSave(Map<String, dynamic> formData) async {
    if (_isAutoSaving) {
      AppLogger.debug(
        '🔄 AUTO_SAVE: Already saving, skipping duplicate request',
      );
      return;
    }

    if (!_shouldAutoSave(formData)) {
      AppLogger.debug(
        '🔄 AUTO_SAVE: Content not significant enough for auto-save',
      );
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
        ownerId: _ownerIdProvider(),
      );

      // Save draft data and metadata
      await _saveDraftData(draftId, formData);
      await _saveDraftMetadata(metadata);

      _lastAutoSaveTime = now;
      _hasSaveFailed = false;

      // Show subtle user feedback (once per session)
      if (!_hasShownAutoSaveNotice) {
        _showAutoSaveNotice();
        _hasShownAutoSaveNotice = true;
      }

      AppLogger.info(
        '🔄 AUTO_SAVE: Draft saved successfully - ID: $draftId, fields: ${metadata.fieldCount}',
      );
    } catch (e) {
      AppLogger.error('🔄 AUTO_SAVE: Failed to save draft: $e');
      if (!_hasSaveFailed) {
        _hasSaveFailed = true;
        _failurePeriod++;
      }
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
          '🔄 AUTO_SAVE: Template promoted to regular form after significant changes',
        );
      } else {
        AppLogger.debug(
          '🔄 AUTO_SAVE: Skipping auto-save for template (insufficient changes)',
        );
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
    final firstIngredient = ingredients.firstWhere(
      (i) => i.trim().isNotEmpty,
      orElse: () => '',
    );

    if (firstIngredient.isNotEmpty) {
      return AppLocale.current.recipeAutoTitleWithIngredient(firstIngredient);
    }

    return AppLocale.current.recipeAutoTitleUntitled;
  }

  /// Save draft data to local storage
  Future<void> _saveDraftData(
    String draftId,
    Map<String, dynamic> formData,
  ) async {
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

      existingMetadata.sort(
        (a, b) => b.lastModifiedAt.compareTo(a.lastModifiedAt),
      );
      // Five slots per account: a new draft pushes out the same account's
      // oldest, never another account's.
      final sameOwner = existingMetadata
          .where((m) => m.ownerId == metadata.ownerId)
          .toList();
      if (sameOwner.length > maxDrafts) {
        final removeIds = sameOwner
            .sublist(maxDrafts)
            .map((m) => m.draftId)
            .toSet();
        for (final id in removeIds) {
          await _deleteDraft(id);
        }
        existingMetadata.removeWhere((m) => removeIds.contains(m.draftId));
      }

      final metadataJson = jsonEncode(
        existingMetadata.map((m) => m.toJson()).toList(),
      );
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
        '🔄 AUTO_SAVE: Failed to load draft data for $draftId: $e',
      );
      return null;
    }
  }

  /// Get available drafts for recovery
  ///
  /// Only the signed-in account's drafts within their lifetime, newest
  /// first. A draft without an owner predates owners and is offered as
  /// before.
  Future<List<DraftMetadata>> getAvailableDrafts() async {
    final metadata = await _loadAllDraftMetadata();
    final owner = _ownerIdProvider();
    return metadata
        .where((m) => m.isRecent)
        .where((m) => m.ownerId == null || m.ownerId == owner)
        .toList()
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
  ///
  /// BUT-1138: Made async + awaits the underlying `deleteDraft` so callers
  /// that chain `clearCurrentDraft(); saveNow(...)` don't race the metadata
  /// delete against the next save's metadata write. Previously the delete
  /// was fire-and-forget and the synchronous null of `_currentDraftId`
  /// allowed `_performAutoSave` to mint a new draft id while the prior
  /// delete was still in flight — and if the delete completed AFTER the
  /// new metadata index write, the fresh entry got clobbered.
  Future<void> clearCurrentDraft() async {
    // The recipe itself is saved, so a failed draft no longer matters, even
    // when the broken storage makes the delete below throw too.
    _hasSaveFailed = false;
    if (_currentDraftId != null) {
      final idToDelete = _currentDraftId!;
      await deleteDraft(idToDelete);
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
      final metadataJson = jsonEncode(
        remainingMetadata.map((m) => m.toJson()).toList(),
      );
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
        '🔄 AUTO_SAVE: Auto-save enabled - drafts saved automatically',
      );
    });
  }

  /// Show user feedback about auto-save status (to be called from UI)
  static void showAutoSaveNotice(BuildContext context) {
    SnackBarUtils.showSuccess(
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
