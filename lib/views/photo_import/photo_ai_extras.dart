// lib/views/photo_import/photo_ai_extras.dart

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';

/// What sits under the recipe the photo gave: the notice for recipes the AI
/// could not read, and the way to ask AI for more. Ends with the gap to what
/// follows.
class PhotoAiExtrasSection extends StatelessWidget {
  const PhotoAiExtrasSection({super.key, required this.viewModel});

  final PhotoImportViewModel viewModel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (viewModel.droppedRecipeCount > 0) ...[
        const SizedBox(height: AppDimensions.space8),
        PhotoDroppedRecipesNotice(count: viewModel.droppedRecipeCount),
      ],
      if (viewModel.canAskAiToRead)
        PhotoAiAskLink(onPressed: viewModel.askAiToRead),
      const SizedBox(height: AppDimensions.space16),
    ],
  );
}

/// The way to let AI read a photo the phone already read, for the recipe the
/// phone missed. A quiet text button, not an action the screen asks for.
class PhotoAiAskLink extends StatelessWidget {
  const PhotoAiAskLink({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: ButleryTextButton(
      label: context.l10n.photoAiAskToRead,
      tone: ButleryTextButtonTone.muted,
      onPressed: onPressed,
    ),
  );
}

/// Says how many recipes the AI reading saw but could not read, so a missing
/// recipe is never silent.
class PhotoDroppedRecipesNotice extends StatelessWidget {
  const PhotoDroppedRecipesNotice({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    container: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space12),
      decoration: BoxDecoration(
        color: context.modeColors.surfaceTintWarning,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Text(
        context.l10n.photoAiDroppedRecipes(count),
        style: AppTextStyles.titleSmall.copyWith(
          color: context.modeColors.onWarningContainer,
        ),
      ),
    ),
  );
}
