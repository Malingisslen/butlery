// lib/widgets/recipe/recipe_draft_recovery_handler.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/constants/app_strings.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/dialogs/draft_recovery_dialog.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/logger.dart';

/// Handles draft recovery logic for recipe forms.
/// Provides methods to check, display, and restore drafts.
class RecipeDraftRecoveryHandler {
  static const String _logTag = 'DRAFT_RECOVERY';

  /// Check for available drafts and show recovery dialog if needed.
  /// Should be called after widget build via addPostFrameCallback.
  static Future<void> checkAndShowDraftRecovery(BuildContext context) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeFormViewModel>();

    // Only check for drafts when creating new recipes (not editing existing ones)
    if (viewModel.isEditMode) {
      AppLogger.debug('[$_logTag] Skipping draft check - editing existing recipe');
      return;
    }

    try {
      final availableDrafts = await viewModel.getAvailableDrafts();

      if (availableDrafts.isEmpty) {
        AppLogger.debug('[$_logTag] No drafts available');
        return;
      }

      AppLogger.info('[$_logTag] Found ${availableDrafts.length} available drafts');

      if (context.mounted) {
        final selectedDraftId = await context.showDraftRecovery(availableDrafts);

        if (selectedDraftId != null && context.mounted) {
          await restoreDraft(context, selectedDraftId);
        } else {
          AppLogger.info('[$_logTag] User chose to start fresh');
        }
      }
    } catch (e) {
      AppLogger.error('[$_logTag] Error checking for drafts: $e');
      // Don't show error to user - draft recovery is optional functionality
    }
  }

  /// Restore draft with user feedback.
  static Future<void> restoreDraft(BuildContext context, String draftId) async {
    if (!context.mounted) return;

    try {
      // Show loading state
      SnackBarUtils.showLoading(context, AppStrings.restoringDraft);

      final viewModel = context.read<RecipeFormViewModel>();
      final success = await viewModel.loadFromDraft(draftId);

      if (context.mounted) {
        if (success) {
          // Show success feedback with field count
          final formData = viewModel.serializeCurrentFormData();
          final fieldCount = countRestoredFields(formData);

          UtilityComponents.showSuccessSnackbar(
            context,
            AppStrings.draftRestoredWithCount(fieldCount),
          );

          AppLogger.info('[$_logTag] Draft restored successfully - $fieldCount fields loaded');
        } else {
          UtilityComponents.showErrorSnackbar(
            context,
            AppStrings.couldNotRestoreDraft,
          );

          AppLogger.error('[$_logTag] Failed to restore draft: $draftId');
        }
      }
    } catch (e) {
      AppLogger.error('[$_logTag] Error restoring draft: $e');

      if (context.mounted) {
        UtilityComponents.showErrorSnackbar(
          context,
          AppStrings.couldNotRestoreDraft,
        );
      }
    }
  }

  /// Count non-empty fields in restored form data for user feedback.
  static int countRestoredFields(Map<String, dynamic> formData) {
    int count = 0;

    // Core fields
    if (_isNotEmpty(formData['title'])) count++;
    if (_isNotEmpty(formData['description'])) count++;
    if (formData['portions'] != null && formData['portions'] > 0) count++;
    if (formData['timeMinutes'] != null && formData['timeMinutes'] > 0) count++;
    if (_isNotEmpty(formData['sourceUrl'])) count++;

    // Dynamic lists
    final ingredients = formData['ingredients'] as List<String>? ?? [];
    count += ingredients.where((i) => i.trim().isNotEmpty).length;

    final instructions = formData['instructions'] as List<String>? ?? [];
    count += instructions.where((i) => i.trim().isNotEmpty).length;

    final tags = formData['tags'] as List<String>? ?? [];
    count += tags.where((t) => t.trim().isNotEmpty).length;

    // Images
    final imageUrls = formData['imageUrls'] as List<String>? ?? [];
    count += imageUrls.length;

    return count;
  }

  /// Helper method for checking non-empty values.
  static bool _isNotEmpty(dynamic value) {
    return value != null && value.toString().trim().isNotEmpty;
  }
}
