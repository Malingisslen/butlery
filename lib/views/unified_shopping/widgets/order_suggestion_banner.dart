import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';

/// "Du tar oftast Kött & fisk före Mejeri i ICA Maxi. Flytta?" with Nej and
/// Ja, under the store chip. The habit is counted on the phone only.
class OrderSuggestionBanner extends StatelessWidget {
  const OrderSuggestionBanner({super.key, required this.viewModel});

  final UnifiedShoppingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final suggestion = viewModel.orderSuggestion;
    final store = viewModel.activeStore;
    if (suggestion == null || store == null) return const SizedBox.shrink();
    final body = AppModeColors.textBody(Theme.of(context).brightness);
    final l = context.l10n;
    return Semantics(
      key: const ValueKey('unifiedShopping.orderSuggestion'),
      container: true,
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space4,
        ),
        decoration: BoxDecoration(
          color: context.modeColors.surfaceTintSuccess,
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space12,
                  vertical: AppDimensions.space8,
                ),
                child: Text(
                  l.shoppingOrderSuggestionText(
                    ShoppingCategory.displayName(suggestion.first),
                    ShoppingCategory.displayName(suggestion.second),
                    store.name,
                  ),
                  style: AppTextStyles.captionBase.copyWith(color: body),
                ),
              ),
            ),
            ButleryTextButton(
              key: const ValueKey('unifiedShopping.orderSuggestion.no'),
              label: l.shoppingOrderSuggestionNo,
              onPressed: viewModel.dismissOrderSuggestion,
              dense: true,
            ),
            ButleryTextButton(
              key: const ValueKey('unifiedShopping.orderSuggestion.yes'),
              label: l.shoppingOrderSuggestionYes,
              onPressed: viewModel.acceptOrderSuggestion,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}
