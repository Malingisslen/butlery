import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// The note a cookbook keeps for a recipe, shown at the top of the recipe
/// when it was opened from that book (BUT-1325). The recipe itself does not
/// carry it.
class CookbookNoteBanner extends StatelessWidget {
  const CookbookNoteBanner({
    required this.cookbookName,
    required this.note,
    super.key,
  });

  final String cookbookName;
  final String note;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: AppDimensions.responsiveContentPadding(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border(left: BorderSide(color: cs.primary, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.cookbookNoteFrom(cookbookName),
                style: AppTextStyles.sectionLabel.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(note, style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
