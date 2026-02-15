// lib/widgets/common/permissions/permission_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// PermissionWidgets - Permission-based action buttons
/// Provides action buttons that adapt based on user permissions.
class PermissionWidgets {
  /// Action buttons baserat på användares permissions för kollaborativ redigering
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
    final effectiveSaveLabel = saveLabel ?? _getSaveLabel(context, editMode);
    final effectiveForkLabel = forkLabel ?? _getForkLabel(context, editMode);

    switch (editMode) {
      case EditMode.owner:
      case EditMode.edit:
        return ActionButtons.primaryButton(
          context,
          label: effectiveSaveLabel,
          onPressed: isSaving ? null : onSave,
          icon: Icons.save,
          isLoading: isSaving,
          loadingText: context.l10n.permissionSaving,
          isExpanded: isExpanded,
        );

      case EditMode.collaborative:
        return Column(
          children: [
            ActionButtons.primaryButton(
              context,
              label: effectiveSaveLabel,
              onPressed: isSaving ? null : onSave,
              icon: Icons.save,
              isLoading: isSaving,
              loadingText: context.l10n.permissionSaving,
              isExpanded: isExpanded,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            ActionButtons.outlinedButton(
              context,
              label: effectiveForkLabel,
              onPressed: isForking ? null : onFork,
              icon: Icons.content_copy,
              isLoading: isForking,
              loadingText: context.l10n.permissionCreatingCopy,
              isExpanded: isExpanded,
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
          loadingText: context.l10n.permissionCreatingCopy,
          isExpanded: isExpanded,
        );

      case EditMode.noAccess:
        final cs = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.all(AppDimensions.spacingL),
          decoration: BoxDecoration(
            color: cs.error.withValues(alpha: AppDimensions.opacityVeryLight),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            border: Border.all(color: cs.error),
          ),
          child: Row(
            children: [
              Icon(Icons.block, color: cs.error),
              const SizedBox(width: AppDimensions.spacingM),
              Text(context.l10n.permissionNoAccess,
                  style: AppTextStyles.bodyMediumError),
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
    final effectiveSaveLabel = saveLabel ?? _getSaveLabel(context, editMode);
    final effectiveForkLabel = forkLabel ?? _getForkLabel(context, editMode);

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
                label: context.l10n.permissionCopy,
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
        return const SizedBox.shrink(); // Ingen knapp för ingen åtkomst
    }
  }

  static String _getSaveLabel(BuildContext context, EditMode editMode) {
    switch (editMode) {
      case EditMode.owner:
      case EditMode.edit:
        return context.l10n.permissionSaveChanges;
      case EditMode.collaborative:
        return context.l10n.permissionSaveChanges;
      case EditMode.readOnlyWithFork:
      case EditMode.view:
        return context.l10n.permissionSaveMyCopy;
      case EditMode.noAccess:
        return context.l10n.permissionNoAccess;
    }
  }

  static String _getForkLabel(BuildContext context, EditMode editMode) {
    switch (editMode) {
      case EditMode.owner:
      case EditMode.edit:
        return context.l10n.permissionSaveAsNew;
      case EditMode.collaborative:
        return context.l10n.permissionSaveMyCopy;
      case EditMode.readOnlyWithFork:
      case EditMode.view:
        return context.l10n.permissionSaveMyCopy;
      case EditMode.noAccess:
        return context.l10n.permissionNoAccess;
    }
  }
}
