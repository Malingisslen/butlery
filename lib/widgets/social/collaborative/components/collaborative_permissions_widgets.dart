// lib/widgets/social/collaborative/components/collaborative_permissions_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/permissions/edit_mode_ui_helper.dart';

/// Permission-related widgets for collaborative content
class CollaborativePermissionsWidgets {
  /// Permissions banner for collaborative editing
  static Widget permissionsBanner({
    required BuildContext context,
    required EditMode editMode,
    VoidCallback? onTap,
  }) {
    final (fill, color) = _noticeColors(context, editMode);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      margin: const EdgeInsets.all(AppDimensions.space4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Semantics(
        label: context.l10n.a11yPermissionsBanner,
        button: onTap != null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          child: Row(
            children: [
              ButleryIcon(
                EditModeUIHelper.getIcon(editMode),
                color: color,
                size: AppDimensions.iconSizeAction,
              ),
              const SizedBox(width: AppDimensions.space4),
              Expanded(
                child: Text(
                  editMode.description,
                  style: AppTextStyles.contentTitle.copyWith(
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // The notice box is the mode's surface tint with no border (B83-2); owner
  // and edit carry no status, so they stand on the raised surface.
  static (Color fill, Color foreground) _noticeColors(
    BuildContext context,
    EditMode editMode,
  ) {
    final cs = Theme.of(context).colorScheme;
    final modeColors = context.modeColors;
    switch (editMode) {
      case EditMode.owner:
      case EditMode.edit:
        return (cs.surfaceContainerHighest, cs.onSurface);
      case EditMode.collaborative:
        return (modeColors.surfaceTintSuccess, modeColors.onSuccessContainer);
      case EditMode.readOnlyWithFork:
      case EditMode.view:
        return (
          modeColors.surfaceTintWarning,
          AppModeColors.textWarning(Theme.of(context).brightness),
        );
      case EditMode.noAccess:
        return (modeColors.surfaceTintDanger, cs.onErrorContainer);
    }
  }

  /// Smart permissions banner with ViewModel integration
  static Widget smartPermissionsBanner({
    required BuildContext context,
    required RecipeFormViewModel viewModel,
  }) {
    if (viewModel.editMode == null) return const SizedBox.shrink();

    return permissionsBanner(
      context: context,
      editMode: viewModel.editModeEnum ?? EditMode.noAccess,
    );
  }
}
