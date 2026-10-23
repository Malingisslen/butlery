import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/butlery_tap_target.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// A photo that exists but failed to load. Unlike a recipe with no photo,
/// which collapses its media area, this keeps the area so the layout does not
/// jump when the network wavers, and says why it is empty (Komponentark v1
/// "Bild saknas, bild misslyckas", case 4).
class RecipeImageFailedPlate extends StatelessWidget {
  const RecipeImageFailedPlate({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = context.l10n.imageCouldNotBeShown;
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(
        child: ColoredBox(
          color: cs.surfaceContainerHighest,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ButleryIcon(
                  ButleryIcons.image,
                  size: AppDimensions.iconSizeHero,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(height: AppDimensions.space8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The camera as a round outlined button beside a wider button; the drawn
/// circle is smaller than its touch target.
class RecipeAddPhotoIconButton extends StatelessWidget {
  const RecipeAddPhotoIconButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ButleryTapTarget(
      semanticLabel: context.l10n.recipeAddPhoto,
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppDimensions.minTouchTarget / 2),
      child: SizedBox.square(
        dimension: AppDimensions.minTouchTarget,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: CircleBorder(side: BorderSide(color: cs.outlineVariant)),
          ),
          child: Center(
            child: ButleryIcon(
              ButleryIcons.camera,
              size: AppDimensions.iconSizeM,
              color: cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
