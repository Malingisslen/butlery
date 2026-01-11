// lib/widgets/social/collaborative/components/collaborative_permissions_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/widgets/permissions/edit_mode_ui_helper.dart';

/// Permission-related widgets for collaborative content
class CollaborativePermissionsWidgets {
  /// Permissions banner for collaborative editing
  static Widget permissionsBanner({
    required BuildContext context,
    required EditMode editMode,
    VoidCallback? onTap,
  }) {
    final color = EditModeUIHelper.getColor(editMode, context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      margin: const EdgeInsets.all(AppDimensions.spacingS),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
        border: Border.all(
          color: color.withValues(alpha: AppDimensions.opacityMediumLight),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
        child: Row(
          children: [
            Icon(
              EditModeUIHelper.getIcon(editMode),
              color: color,
              size: AppDimensions.iconSizeAction,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Expanded(
              child: Text(
                editMode.description,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
