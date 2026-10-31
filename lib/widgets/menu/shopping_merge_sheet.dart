/// P6-U02: the merge sheet, the only way from the week menu to a list.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';

part 'shopping_merge_sheet_parts.dart';

/// Opens the merge sheet and returns the merge the user confirmed, or null
/// when it was cancelled. Nothing is written here.
Future<MenuShoppingMergePreview?> showShoppingMergeSheet(
  BuildContext context, {
  required MenuShoppingSource source,
  required MenuShoppingPantry pantry,
  required Future<MenuShoppingPantry> Function() retryPantry,
  bool updatesList = false,
}) {
  return showButlerySheet<MenuShoppingMergePreview>(
    context: context,
    builder: (_) => ShoppingMergeSheet(
      source: source,
      pantry: pantry,
      retryPantry: retryPantry,
      updatesList: updatesList,
    ),
  );
}

/// The switches the sheet can show, as stable ids for keys and tests.
enum ShoppingMergeSwitch { duplicates, convert, pantry }

/// "Sammanfattning först." (#inkopmerge): the summary line and three figures
/// carry the outcome, and the rules sit one tap away behind "Visa detaljer".
/// Opened (#inkopmergeoppen), all three switches show, so no setting hides.
/// Kärnflöde 8B: there is no "Ersätt listan" any more. Every confirm is one
/// sync, so the button says "Uppdatera listan" once the list holds rows from
/// this source.
class ShoppingMergeSheet extends StatefulWidget {
  const ShoppingMergeSheet({
    super.key,
    required this.source,
    required this.pantry,
    required this.retryPantry,
    this.updatesList = false,
  });

  final MenuShoppingSource source;
  final MenuShoppingPantry pantry;
  final Future<MenuShoppingPantry> Function() retryPantry;

  /// The week's list already holds rows from this source
  /// (MenuShoppingListGenerator.weekListHasRowsFrom), so confirming updates
  /// them.
  final bool updatesList;

  static const Key detailsToggleKey = ValueKey<String>(
    'shopping-merge-details',
  );
  static const Key confirmKey = ValueKey<String>('shopping-merge-confirm');
  static const Key cancelKey = ValueKey<String>('shopping-merge-cancel');
  static const Key summaryKey = ValueKey<String>('shopping-merge-summary');
  static const Key pantryUnavailableKey = ValueKey<String>(
    'shopping-merge-pantry-unavailable',
  );
  static const Key unresolvedRecipesKey = ValueKey<String>(
    'shopping-merge-unresolved-recipes',
  );
  static const Key pantryRetryKey = ValueKey<String>(
    'shopping-merge-pantry-retry',
  );
  static const Key coveredKey = ValueKey<String>('shopping-merge-covered');
  static const Key updatesListKey = ValueKey<String>(
    'shopping-merge-updates-list',
  );

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
    // An update with nothing left to buy still takes the rows off.
    final canConfirm = merge.itemCount > 0 || widget.updatesList;
    final confirmLabel = widget.updatesList
        ? l.shoppingMergeUpdate
        : l.shoppingMergeAdd(merge.itemCount);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.space24,
        AppDimensions.space12,
        AppDimensions.space24,
        AppDimensions.space24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            const SizedBox(height: AppDimensions.space8),
            Text(
              l.menuShoppingScaledToPresence,
              style: AppTextStyles.captionBase.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          if (merge.unresolvedRecipes > 0) ...[
            const SizedBox(height: AppDimensions.space12),
            _UnresolvedRecipes(count: merge.unresolvedRecipes),
          ],
          if (merge.pantryUnavailable) ...[
            const SizedBox(height: AppDimensions.space12),
            _PantryUnavailable(
              retrying: _retrying,
              onRetry: () => unawaited(_retryPantry()),
            ),
          ],
          if (!_detailsOpen) ...[
            const SizedBox(height: AppDimensions.space12),
            _Figures(merge: merge),
          ],
          const SizedBox(height: AppDimensions.space12),
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
              divider: false,
              onChanged: (v) => setState(
                () => _options = _options.copyWith(subtractPantry: v),
              ),
            ),
          ],
          if (widget.updatesList) ...[
            const SizedBox(height: AppDimensions.space12),
            Text(
              l.shoppingMergeUpdateBody,
              key: ShoppingMergeSheet.updatesListKey,
              style: AppTextStyles.captionBase.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.space16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ActionButtons.outlinedButton(
                  context,
                  key: ShoppingMergeSheet.cancelKey,
                  label: l.commonCancel,
                  isExpanded: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: AppDimensions.space8),
              Expanded(
                flex: 3,
                child: FormButton(
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
    );
  }
}
