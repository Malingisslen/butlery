import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/shopping/shopping_dietary_hints.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/utils/allergen_label.dart';
import 'package:butlery/widgets/common/buttons/app_icon_button.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/shopping/shopping_row.dart';

/// The reminder under a shopping row (BUT-2494): the kit's band with a warning
/// glyph, the text, and a tick that says "Inte aktuellt".
///
/// The text names a choice "i hushållet", never a person or where the choice
/// came from, and never claims anything about rows without a box.
class ShoppingDietaryHintBox extends StatelessWidget {
  const ShoppingDietaryHintBox({
    required this.hint,
    required this.onDismiss,
    super.key,
  });

  final ShoppingDietaryHint hint;
  final VoidCallback onDismiss;

  /// The sentence a hint reads as.
  static String textFor(AppLocalizations l10n, ShoppingDietaryHint hint) =>
      switch (hint.kind) {
        ShoppingDietaryHintKind.chooseFreeVariant => switch (hint.choiceKey) {
          'gluten' => l10n.shoppingHintChooseGlutenFree,
          _ => l10n.shoppingHintChooseLactoseFree,
        },
        ShoppingDietaryHintKind.checkContents => l10n.shoppingHintCheckContents(
          allergenLabel(l10n, hint.choiceKey).toLowerCase(),
        ),
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Padding(
      // Under the name, past the tick box, as the mockup sets it.
      padding: const EdgeInsetsDirectional.only(
        start: ShoppingRow.textInset,
        bottom: AppDimensions.space8,
      ),
      child: Container(
        constraints: const BoxConstraints(
          minHeight: AppDimensions.minTouchTarget,
        ),
        padding: const EdgeInsetsDirectional.only(
          start: AppDimensions.space12,
          end: AppDimensions.space4,
          top: AppDimensions.space4,
          bottom: AppDimensions.space4,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        ),
        child: Row(
          children: [
            ButleryIcon(
              ButleryIcons.triangleAlert,
              size: AppDimensions.iconSizeM,
              color: AppModeColors.actionPrimary(cs.brightness),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Text(
                textFor(l10n, hint),
                // The kit's band text (13/600), as the mockup draws it.
                style: AppTextStyles.bodySmall.copyWith(color: cs.onSurface),
              ),
            ),
            AppIconButton(
              icon: ButleryIcons.check,
              iconSize: AppDimensions.iconSizeM,
              semanticLabel: l10n.shoppingHintDismiss,
              color: cs.onSurface,
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
