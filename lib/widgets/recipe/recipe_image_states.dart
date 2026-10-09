import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

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
                const SizedBox(height: AppDimensions.spacingSm),
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

/// "Lägg till foto" in the chip row of a recipe page without a photo
/// (Skarmar v12 del 1 'Receptdetalj'): a pill with a hairline edge, 48 dp
/// tall.
class RecipeAddPhotoChip extends StatelessWidget {
  const RecipeAddPhotoChip({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = context.l10n.recipeAddPhoto;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            onTap: onPressed,
            customBorder: const StadiumBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDimensions.minTouchTarget,
              ),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: StadiumBorder(
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingL,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ButleryIcon(
                        ButleryIcons.camera,
                        size: AppDimensions.iconSizeS,
                        color: cs.onSurface,
                      ),
                      const SizedBox(width: AppDimensions.spacingXs),
                      Text(
                        label,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
