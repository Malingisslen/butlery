// The merge sheet's parts: the summary, the figures, the details toggle,
// the switch rows and the pantry notice (P6-U02, #inkopmerge).
part of 'shopping_merge_sheet.dart';

/// "5 rätter ger 24 rader. Efter sammanslagning blir det **18 varor**."
/// The line reads in text.secondary; the item count is bold in text.primary
/// (Skarmar v12 del 2 #inkopmerge, lines 267 and 70).
class _Summary extends StatelessWidget {
  const _Summary({required this.merge});

  final MenuShoppingMergePreview merge;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final items = l.shoppingMergeItemCount(merge.itemCount);
    final text = l.shoppingMergeSummary(
      merge.recipeCount,
      merge.rawRowCount,
      items,
    );
    // 13/400 as drawn in --r04slot-702: #627061 light, #93a48d dark, which is
    // text.secondary (tokens.json) = onSurfaceVariant in both modes.
    final style = AppTextStyles.bodySmall.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w400,
    );
    final at = text.indexOf(items);
    return Text.rich(
      key: ShoppingMergeSheet.summaryKey,
      at < 0
          ? TextSpan(text: text)
          : TextSpan(
              children: [
                TextSpan(text: text.substring(0, at)),
                TextSpan(
                  text: items,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: text.substring(at + items.length)),
              ],
            ),
      style: style,
    );
  }
}

/// The three figures: "6 slås samman · 3 konverteras · 6 finns hemma", in
/// cells of the sheet's own paper divided by border.subtle hairlines, 12 px
/// corners (#inkopmerge: cells --r04slot-648 = sheet --r04slot-619).
class _Figures extends StatelessWidget {
  const _Figures({required this.merge});

  final MenuShoppingMergePreview merge;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    Widget cell(String id, int value, String label) => Expanded(
      child: ColoredBox(
        // The sheet's paper (BottomSheetThemeData.backgroundColor = surface),
        // so only the hairlines set the cells apart, as drawn.
        color: cs.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.spacingL,
            horizontal: AppDimensions.spacingSm,
          ),
          child: MergeSemantics(
            key: ShoppingMergeSheet.statKey(id),
            child: Column(
              children: [
                Text(
                  '$value',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: cs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingXxs),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  // text.secondary (--r04slot-702), as the summary line.
                  style: AppTextStyles.labelMedium.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: DecoratedBox(
        // border.subtle shows through the 1 px gaps and around the cells.
        decoration: BoxDecoration(
          color: cs.outlineVariant,
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 1,
            children: [
              cell('merged', merge.mergedCount, l.shoppingMergeStatMerged),
              cell(
                'converted',
                merge.convertedCount,
                l.shoppingMergeStatConverted,
              ),
              cell('atHome', merge.atHomeCount, l.shoppingMergeStatAtHome),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Visa detaljer" / "Dölj detaljer": a 48 dp row between hairlines, the
/// label 13/600 and the chevron in text.link (#inkopmerge draws the old
/// #A15A0A, which text.link replaced, as app_colors.dart records). Open,
/// the lower hairline is text.primary (#inkopmergeoppen).
class _DetailsToggle extends StatelessWidget {
  const _DetailsToggle({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    // text.link: #8A5212 light, #DCA968 dark.
    final link = context.butleryColors.info;
    return Semantics(
      button: true,
      expanded: open,
      label: open
          ? l.shoppingMergeHideDetailsA11y
          : l.shoppingMergeShowDetailsA11y,
      excludeSemantics: true,
      child: InkWell(
        key: ShoppingMergeSheet.detailsToggleKey,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: cs.outlineVariant),
              bottom: BorderSide(
                color: open ? cs.onSurface : cs.outlineVariant,
              ),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppDimensions.spacingXxl,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    open
                        ? l.shoppingMergeHideDetails
                        : l.shoppingMergeShowDetails,
                    style: AppTextStyles.bodySmall.copyWith(color: link),
                  ),
                ),
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  size: AppDimensions.iconSizeM,
                  color: link,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One switch as drawn: a 24 px checkbox, the title 13/700 in text.primary
/// and the description 12/400 in text.secondary, at least 48 dp tall.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.which,
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
    required this.divider,
    this.extra,
  });

  final ShoppingMergeSwitch which;
  final String title;
  final String body;
  final bool value;

  /// Null switches the row off; its body then says why.
  final ValueChanged<bool>? onChanged;
  final bool divider;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: InkWell(
        key: ShoppingMergeSheet.switchKey(which),
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: divider
                ? Border(bottom: BorderSide(color: cs.outlineVariant))
                : null,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppDimensions.spacingXxl,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.spacingSm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: value,
                    onChanged: onChanged == null
                        ? null
                        : (v) => onChanged!(v ?? false),
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: AppDimensions.spacingL,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingXxs),
                          Text(
                            body,
                            style: AppTextStyles.captionBase.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          if (extra != null) ...[
                            const SizedBox(height: AppDimensions.spacingXs),
                            extra!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// produktregler.md:697: when the pantry cannot be read the list is made
/// without deduction, the sheet says so, and there is a way to try again.
/// The notice says what happened and what it means, and offers Försök igen
/// (content-style-guide.md:87-97).
class _PantryUnavailable extends StatelessWidget {
  const _PantryUnavailable({required this.retrying, required this.onRetry});

  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: ShoppingMergeSheet.pantryUnavailableKey,
      // The partial-outcome form (produktregler.md:905-909): surface.raised
      // with a rust edge, #E6EAD9 / #2F4437 and cs.secondary in both modes.
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(left: BorderSide(color: cs.secondary, width: 3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.spacingL,
          AppDimensions.spacingSm,
          AppDimensions.spacingSm,
          AppDimensions.spacingSm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l.shoppingMergePantryUnavailable,
                  style: AppTextStyles.captionBase.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),
            TextButton(
              key: ShoppingMergeSheet.pantryRetryKey,
              onPressed: retrying ? null : onRetry,
              child: Text(l.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
