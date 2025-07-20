// lib/widgets/common/permissions/permission_widgets.dart

import 'package:flutter/material.dart';
import '../../../models/permissions/edit_mode.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_styles.dart';
import '../buttons/action_buttons.dart';

/// PermissionWidgets - Permission-based action buttons
///
/// Provides action buttons that adapt based on user permissions.
class PermissionWidgets {
  /// Action buttons baserat på användares permissions för kollaborativ redigering
  ///
  /// Visar olika knappar beroende på användarens rättigheter:
  /// - Ägare: "Spara ändringar" (standard save)
  /// - Collaborator: "Spara ändringar" + "Spara min kopia" (både save och fork)
  /// - Viewer: "Spara min kopia" (endast fork)
  static Widget permissionsActionButtons({
    required BuildContext context,
    required EditMode editMode,
    VoidCallback? onSave,
    VoidCallback? onFork,
    bool isSaving = false,
    bool isForking = false,
    String? saveLabel,
    String? forkLabel,
    bool isExpanded = true,
  }) {
    // Dynamiska labels baserat på edit mode
    final effectiveSaveLabel = saveLabel ?? _getSaveLabel(editMode);
    final effectiveForkLabel = forkLabel ?? _getForkLabel(editMode);

    switch (editMode) {
      case EditMode.owner:
      case EditMode.edit:
        // Ägare: Endast "Spara ändringar"
        return ActionButtons.primaryButton(
          context,
          label: effectiveSaveLabel,
          onPressed: isSaving ? null : onSave,
          icon: Icons.save,
          isLoading: isSaving,
          loadingText: 'Sparar...',
          isExpanded: isExpanded,
        );

      case EditMode.collaborative:
        // Collaborator: Både "Spara ändringar" och "Spara min kopia"
        return Column(
          children: [
            ActionButtons.primaryButton(
              context,
              label: effectiveSaveLabel,
              onPressed: isSaving ? null : onSave,
              icon: Icons.save,
              isLoading: isSaving,
              loadingText: 'Sparar...',
              isExpanded: isExpanded,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            ActionButtons.outlinedButton(
              context,
              label: effectiveForkLabel,
              onPressed: isForking ? null : onFork,
              icon: Icons.content_copy,
              isLoading: isForking,
              loadingText: 'Skapar kopia...',
              isExpanded: isExpanded,
            ),
          ],
        );

      case EditMode.readOnlyWithFork:
      case EditMode.view:
        // Viewer: Endast "Spara min kopia"
        return ActionButtons.primaryButton(
          context,
          label: effectiveForkLabel,
          onPressed: isForking ? null : onFork,
          icon: Icons.content_copy,
          isLoading: isForking,
          loadingText: 'Skapar kopia...',
          isExpanded: isExpanded,
        );

      case EditMode.noAccess:
        // Ingen åtkomst: Ingen knapp
        return Container(
          padding: EdgeInsets.all(AppDimensions.spacingL),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            border: Border.all(color: AppColors.error),
          ),
          child: Row(
            children: [
              Icon(Icons.block, color: AppColors.error),
              const SizedBox(width: AppDimensions.spacingM),
              Text('Ingen åtkomst', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
            ],
          ),
        );
    }
  }

  /// Horizontal layout för permissions buttons (för mindre skärmar)
  static Widget permissionsActionButtonsHorizontal({
    required BuildContext context,
    required EditMode editMode,
    VoidCallback? onSave,
    VoidCallback? onFork,
    bool isSaving = false,
    bool isForking = false,
    String? saveLabel,
    String? forkLabel,
  }) {
    final effectiveSaveLabel = saveLabel ?? _getSaveLabel(editMode);
    final effectiveForkLabel = forkLabel ?? _getForkLabel(editMode);

    switch (editMode) {
      case EditMode.owner:
      case EditMode.edit:
        return ActionButtons.primaryButton(
          context,
          label: effectiveSaveLabel,
          onPressed: isSaving ? null : onSave,
          icon: Icons.save,
          isLoading: isSaving,
          isExpanded: true,
        );

      case EditMode.collaborative:
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: ActionButtons.primaryButton(
                context,
                label: effectiveSaveLabel,
                onPressed: isSaving ? null : onSave,
                icon: Icons.save,
                isLoading: isSaving,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: ActionButtons.outlinedButton(
                context,
                label: 'Kopia',
                onPressed: isForking ? null : onFork,
                icon: Icons.content_copy,
                isLoading: isForking,
              ),
            ),
          ],
        );

      case EditMode.readOnlyWithFork:
      case EditMode.view:
        return ActionButtons.primaryButton(
          context,
          label: effectiveForkLabel,
          onPressed: isForking ? null : onFork,
          icon: Icons.content_copy,
          isLoading: isForking,
          isExpanded: true,
        );

      case EditMode.noAccess:
        return SizedBox.shrink(); // Ingen knapp för ingen åtkomst
    }
  }

  /// Helper för att få rätt save label baserat på edit mode
  static String _getSaveLabel(EditMode editMode) {
    switch (editMode) {
      case EditMode.owner:
      case EditMode.edit:
        return 'Spara ändringar';
      case EditMode.collaborative:
        return 'Spara ändringar';
      case EditMode.readOnlyWithFork:
      case EditMode.view:
        return 'Spara min kopia'; // ReadOnly kan bara fork:a
      case EditMode.noAccess:
        return 'Ingen åtkomst'; // Används aldrig
    }
  }

  /// Helper för att få rätt fork label baserat på edit mode
  static String _getForkLabel(EditMode editMode) {
    switch (editMode) {
      case EditMode.owner:
      case EditMode.edit:
        return 'Spara som ny'; // Används sällan
      case EditMode.collaborative:
        return 'Spara min kopia';
      case EditMode.readOnlyWithFork:
      case EditMode.view:
        return 'Spara min kopia';
      case EditMode.noAccess:
        return 'Ingen åtkomst'; // Används aldrig
    }
  }
}