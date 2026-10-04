/// P6-U02: the merge sheet, the only way from the week menu to a list.
///
/// Skarmar v12 del 2 #inkopmerge and #inkopmergeoppen;
/// flows-roles-budget.md:44-51 (flow 02); fas2/block288-uxfrysning.json
/// TR::FLOW::02::veckomeny::till-inköpslistan, ::merge-ark::lägg-till-n-varor
/// and ::merge-ark::ersätt-listan-på, all REQUIRED.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

part 'shopping_merge_sheet_parts.dart';

/// Opens the merge sheet and returns the merge the user confirmed, or null
/// when it was cancelled. Nothing is written here.
Future<MenuShoppingMergePreview?> showShoppingMergeSheet(
  BuildContext context, {
  required MenuShoppingSource source,
  required MenuShoppingPantry pantry,
  required Future<MenuShoppingPantry> Function() retryPantry,
  bool canReplace = true,
}) {
  return showModalBottomSheet<MenuShoppingMergePreview>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ShoppingMergeSheet(
      source: source,
      pantry: pantry,
      retryPantry: retryPantry,
      canReplace: canReplace,
    ),
  );
}

/// The switches the sheet can show, as stable ids for keys and tests.
enum ShoppingMergeSwitch { duplicates, convert, pantry, replace }

/// "Sammanfattning först." (#inkopmerge): the summary line and three figures
/// carry the outcome, and the rules sit one tap away behind "Visa detaljer".
/// Opened (#inkopmergeoppen), all four switches show, so no setting hides.
/// "Ersätt listan" is always off by default and is shown in both states.
class ShoppingMergeSheet extends StatefulWidget {
  const ShoppingMergeSheet({
    super.key,
    required this.source,
    required this.pantry,
    required this.retryPantry,
    this.canReplace = true,
  });

  final MenuShoppingSource source;
  final MenuShoppingPantry pantry;
  final Future<MenuShoppingPantry> Function() retryPantry;

  /// False when the week's list was written before the app knew which rows
  /// came from recipes: "Ersätt listan" is then off, with the reason
  /// (MenuShoppingListGenerator.canReplaceWeekList).
  final bool canReplace;

  static const Key detailsToggleKey = ValueKey<String>(
    'shopping-merge-details',
  );
  static const Key confirmKey = ValueKey<String>('shopping-merge-confirm');
  static const Key cancelKey = ValueKey<String>('shopping-merge-cancel');
  static const Key summaryKey = ValueKey<String>('shopping-merge-summary');
  static const Key pantryUnavailableKey = ValueKey<String>(
    'shopping-merge-pantry-unavailable',
  );
  static const Key pantryRetryKey = ValueKey<String>(
    'shopping-merge-pantry-retry',
  );
  static const Key coveredKey = ValueKey<String>('shopping-merge-covered');

  /// The row of one switch.
  static Key switchKey(ShoppingMergeSwitch which) =>
      ValueKey<String>('shopping-merge-switch-${which.name}');

  /// One of the three summary figures: merged, converted, atHome.
  static Key statKey(String which) =>
      ValueKey<String>('shopping-merge-stat-$which');

  @override
  State<ShoppingMergeSheet> createState() => _ShoppingMergeSheetState();
}

class _ShoppingMergeSheetState extends State<ShoppingMergeSheet> {
  var _options = const MenuShoppingMergeOptions();
  late MenuShoppingPantry _pantry = widget.pantry;
  var _detailsOpen = false;
  var _retrying = false;

  Future<void> _retryPantry() async {
    setState(() => _retrying = true);
    final pantry = await widget.retryPantry();
    if (!mounted) return;
    setState(() {
      _pantry = pantry;
      _retrying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final merge = MenuShoppingListGenerator.preview(
      widget.source,
      _pantry,
      _options,
    );
    final canConfirm = merge.itemCount > 0 || _options.replaceList;
    final confirmLabel = _options.replaceList
        ? l.shoppingMergeReplaceAction(merge.itemCount)
        : l.shoppingMergeAdd(merge.itemCount);

    return DecoratedBox(
      // The sheet's top edge: 1 px #7d897c in the drawing, border.strong
      // (outline in both schemes).
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.spacingLg,
          AppDimensions.spacingL,
          AppDimensions.spacingLg,
          AppDimensions.spacingLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The drawn grab handle, 34 x 4 in border.subtle.
            Center(
              child: SizedBox(
                width: 34,
                height: AppDimensions.spacingXs,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusKnob,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Semantics(
              header: true,
              child: Text(
                l.shoppingMergeTitle,
                style: AppTextStyles.headlineSmall.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space4),
            _Summary(merge: merge),
            if (widget.source.scaledMeals > 0) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                l.menuShoppingScaledToPresence,
                style: AppTextStyles.captionBase.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            if (merge.pantryUnavailable) ...[
              const SizedBox(height: AppDimensions.spacingL),
              _PantryUnavailable(
                retrying: _retrying,
                onRetry: () => unawaited(_retryPantry()),
              ),
            ],
            if (!_detailsOpen) ...[
              const SizedBox(height: AppDimensions.space12),
              _Figures(merge: merge),
            ],
            const SizedBox(height: AppDimensions.spacingL),
            _DetailsToggle(
              open: _detailsOpen,
              onTap: () => setState(() => _detailsOpen = !_detailsOpen),
            ),
            if (_detailsOpen) ...[
              _SwitchRow(
                which: ShoppingMergeSwitch.duplicates,
                title: l.shoppingMergeDuplicatesTitle,
                body: l.shoppingMergeDuplicatesBody,
                value: _options.mergeDuplicates,
                divider: true,
                onChanged: (v) => setState(
                  () => _options = _options.copyWith(mergeDuplicates: v),
                ),
              ),
              _SwitchRow(
                which: ShoppingMergeSwitch.convert,
                title: l.shoppingMergeConvertTitle,
                body: l.shoppingMergeConvertBody,
                value: _options.convertUnits,
                divider: true,
                onChanged: (v) => setState(
                  () => _options = _options.copyWith(convertUnits: v),
                ),
              ),
              _SwitchRow(
                which: ShoppingMergeSwitch.pantry,
                title: l.shoppingMergePantryTitle,
                body: l.shoppingMergePantryBody(merge.atHomeCount),
                extra: merge.coveredAtHome.isEmpty
                    ? null
                    : Text(
                        l.shoppingMergePantryCovered(
                          merge.coveredAtHome.join(', '),
                        ),
                        key: ShoppingMergeSheet.coveredKey,
                        style: AppTextStyles.captionBase.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                value: _options.subtractPantry,
                divider: true,
                onChanged: (v) => setState(
                  () => _options = _options.copyWith(subtractPantry: v),
                ),
              ),
            ] else
              const SizedBox(height: AppDimensions.spacingL),
            _SwitchRow(
              which: ShoppingMergeSwitch.replace,
              title: l.shoppingMergeReplaceTitle,
              body: widget.canReplace
                  ? l.shoppingMergeReplaceBody
                  : l.shoppingMergeReplaceUnavailable,
              value: _options.replaceList,
              divider: false,
              onChanged: widget.canReplace
                  ? (v) => setState(
                      () => _options = _options.copyWith(replaceList: v),
                    )
                  : null,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    key: ShoppingMergeSheet.cancelKey,
                    onPressed: () => Navigator.of(context).pop(),
                    // A button never cuts its own name (BUT-2193, BUT-2219):
                    // the label wraps, as HeroButton's does.
                    child: Text(l.commonCancel, textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  flex: 3,
                  child: HeroButton(
                    key: ShoppingMergeSheet.confirmKey,
                    label: confirmLabel,
                    expand: true,
                    onPressed: canConfirm
                        ? () => Navigator.of(context).pop(merge)
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
