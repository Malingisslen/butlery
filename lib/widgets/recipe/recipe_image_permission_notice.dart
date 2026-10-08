import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/os_permission_helper.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/widgets/common/permissions/media_permission_notice_card.dart';
import 'package:butlery/widgets/recipe/recipe_image_picker.dart';

/// The recipe editor's word on a camera or photo-library answer, under the
/// image strip (flow 07, BUT-2160). A refused camera leads to the library
/// (flows-roles-budget.md:105). A refused library has no fallback here:
/// writing the recipe yourself is offered in photo import (Malin, decision
/// A, 2026-10-07).
class RecipeImagePermissionNotice extends StatelessWidget {
  const RecipeImagePermissionNotice({super.key, required this.viewModel});

  final RecipeFormViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel.imageManager,
      builder: (context, _) {
        final notice = viewModel.imageManager.permissionNotice;
        if (notice == null) return const SizedBox.shrink();
        final l10n = context.l10n;
        final camera = notice.source == ImageSource.camera;
        return Padding(
          padding: const EdgeInsets.only(top: AppDimensions.spacingM),
          child: MediaPermissionNoticeCard(
            source: notice.source,
            outcome: notice.outcome,
            deniedMessage: camera
                ? l10n.permCameraDeniedImage
                : l10n.permPhotosDeniedImage,
            onAskAgain: () => RecipeImagePicker.pick(
              context,
              viewModel,
              notice.source,
              askAgain: true,
            ),
            onOpenSettings: OsPermissionHelper.openSettings,
            fallbackLabel: camera ? l10n.permFallbackGallery : null,
            onFallback: camera
                ? () => RecipeImagePicker.pick(
                    context,
                    viewModel,
                    ImageSource.gallery,
                  )
                : null,
            fallbackKey: const ValueKey('permission-fallback-gallery'),
          ),
        );
      },
    );
  }
}
