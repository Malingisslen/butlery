// lib/widgets/common/list/recipe_thumb_row.dart
//
// A recipe as one row of a plain list: a small photo, the title in bold and a
// hairline under it, as the drawn cookbook and tag pages set their recipes
library;

import 'package:flutter/material.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/image/recipe_image_widget.dart';

class RecipeThumbRow extends StatelessWidget {
  const RecipeThumbRow({
    required this.recipe,
    this.note,
    this.onTap,
    this.onLongPress,
    this.trailing,
    super.key,
  });

  final Recipe recipe;

  /// A line of the user's own words under the title.
  final String? note;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  static const double _thumb = AppDimensions.minTouchTarget;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final note = this.note;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: onTap != null,
              child: PressFill(
                surface: PressSurface.base,
                child: InkWell(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.space8,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: _thumb,
                          height: _thumb,
                          child: ExcludeSemantics(
                            child: RecipeImageWidget.card(
                              imageUrls: recipe.imageUrls,
                              size: ImageSize.thumbnail,
                              showMultipleIndicator: false,
                              customWidth: _thumb,
                              customHeight: _thumb,
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusControl,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.space16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recipe.title,
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: cs.onSurface,
                                ),
                              ),
                              if (note != null) ...[
                                const SizedBox(height: AppDimensions.space4),
                                Text(
                                  note,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
