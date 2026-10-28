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
    final style = AppTextStyles.bodyMedium.copyWith(color: cs.onSurfaceVariant);
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
                  style: AppTextStyles.bodyBold.copyWith(color: cs.onSurface),
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
        // The sheet's own paper, so only the hairlines set the cells apart,
        // as drawn.
        color: Theme.of(context).bottomSheetTheme.backgroundColor ?? cs.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.space12,
            horizontal: AppDimensions.space8,
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
                const SizedBox(height: AppDimensions.space4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  // text.secondary (--r04slot-702), as the summary line.
                  style: AppTextStyles.captionBase.copyWith(
                    color: cs.onSurfaceVariant,
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
      child: ButleryOutlinedBox(
        paintOnly: true,
        // border.subtle shows through the 1 px gaps and around the cells.
        color: cs.outlineVariant,
        borderColor: cs.outlineVariant,
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
/// label 14/600 and the chevron in text.link (#inkopmerge draws the old
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
    final link = context.modeColors.textLink;
    return Semantics(
      button: true,
      expanded: open,
      label: open
          ? l.shoppingMergeHideDetailsA11y
          : l.shoppingMergeShowDetailsA11y,
      excludeSemantics: true,
      child: PressFill(
        surface: PressSurface.base,
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
                      style: AppTextStyles.labelLarge.copyWith(color: link),
                    ),
                  ),
                  ButleryIcon(
                    open ? ButleryIcons.chevronUp : ButleryIcons.chevronDown,
                    size: AppDimensions.iconSizeM,
                    color: link,
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

/// One switch as drawn: a checkbox, the title 14/700 in text.primary
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
      child: PressFill(
        surface: PressSurface.base,
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
                  vertical: AppDimensions.space8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ButleryCheckbox(value: value, onChanged: onChanged),
                    const SizedBox(width: AppDimensions.space8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: AppDimensions.space12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTextStyles.bodyBold.copyWith(
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.space4),
                            Text(
                              body,
                              style: AppTextStyles.captionBase.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            if (extra != null) ...[
                              const SizedBox(height: AppDimensions.space4),
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
      // The partial-outcome form: surface.raised
      // with a rust edge, #E6EAD9 / #2F4437 and cs.secondary in both modes.
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(left: BorderSide(color: cs.secondary, width: 3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.space12,
          AppDimensions.space8,
          AppDimensions.space8,
          AppDimensions.space8,
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
            ButleryTextButton(
              key: ShoppingMergeSheet.pantryRetryKey,
              label: l.commonRetry,
              onPressed: retrying ? null : onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
