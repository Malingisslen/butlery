// Kärnflöde steg 9C: the sheet that follows "lagat": which pantry rows to
// take what the recipe used from.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/swedish_decimal_input.dart';
import 'package:butlery/services/pantry/cooked_pantry_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';
import 'package:butlery/widgets/common/input/styled_input.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet_header.dart';

/// Resolves to the takes the user kept, each with its final amount (never
/// zero), or null when the sheet was skipped or dismissed.
Future<List<CookedPantryTake>?> showCookedPantrySheet(
  BuildContext context, {
  required List<CookedPantryTake> takes,
  required int portions,
}) {
  return showButlerySheet<List<CookedPantryTake>>(
    context: context,
    maxHeightFraction: 0.9,
    builder: (_) => CookedPantrySheet(takes: takes, portions: portions),
  );
}

class CookedPantrySheet extends StatefulWidget {
  const CookedPantrySheet({
    required this.takes,
    required this.portions,
    super.key,
  });

  final List<CookedPantryTake> takes;
  final int portions;

  @override
  State<CookedPantrySheet> createState() => _CookedPantrySheetState();
}

class _CookedPantrySheetState extends State<CookedPantrySheet> {
  // An amount of zero is an unticked row; the planned amount is kept in
  // widget.takes so ticking the row again brings it back.
  late final List<double> _amounts = [
    for (final take in widget.takes) take.amount,
  ];

  int get _count => _amounts.where((a) => a > 0).length;

  CookedPantryTake _take(int i) => widget.takes[i].withAmount(_amounts[i]);

  void _toggle(int i) => setState(
    () => _amounts[i] = _amounts[i] > 0 ? 0 : widget.takes[i].amount,
  );

  Future<void> _edit(int i) async {
    final next = await showButleryDialog<double>(
      context: context,
      builder: (_) => _AmountDialog(take: _take(i)),
    );
    if (next == null) return;
    final max = widget.takes[i].item.quantity ?? 0;
    setState(() => _amounts[i] = next.clamp(0, max).toDouble());
  }

  void _confirm() => Navigator.pop(context, [
    for (var i = 0; i < _amounts.length; i++)
      if (_amounts[i] > 0) _take(i),
  ]);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.space24,
          AppDimensions.space12,
          AppDimensions.space24,
          AppDimensions.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ButlerySheetHeader(
              title: l10n.cookedPantryTitle,
              subtitle: l10n.cookedPantrySubtitle(widget.portions),
            ),
            const SizedBox(height: AppDimensions.space12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                // The floating feedback button sits over this edge (BUT-2261).
                padding: const EdgeInsetsDirectional.only(
                  end: AppDimensions.minTouchTarget + AppDimensions.space8,
                ),
                itemCount: widget.takes.length,
                separatorBuilder: (_, _) => const ButleryDivider(spacing: 1),
                itemBuilder: (_, i) => _CookedPantryRow(
                  key: ValueKey(widget.takes[i].item.id),
                  take: _take(i),
                  onToggle: () => _toggle(i),
                  onEdit: () => _edit(i),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ActionButtons.outlinedButton(
                    context,
                    onPressed: () => Navigator.pop(context),
                    label: l10n.cookedPantrySkip,
                    isExpanded: true,
                  ),
                ),
                const SizedBox(width: AppDimensions.space8),
                Expanded(
                  flex: 3,
                  child: FormButton(
                    label: l10n.cookedPantryConfirm(_count),
                    expand: true,
                    onPressed: _count > 0 ? _confirm : null,
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

String _amountText(double amount, String unit) {
  final rounded = (amount * 100).round() / 100;
  // Non-breaking space: an amount never wraps from its unit.
  return '${formatSwedishDecimal(rounded)}\u00A0$unit'.trim();
}

class _CookedPantryRow extends StatelessWidget {
  const _CookedPantryRow({
    required this.take,
    required this.onToggle,
    required this.onEdit,
    super.key,
  });

  final CookedPantryTake take;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final item = take.item;
    final selected = take.amount > 0;
    final have = _amountText(item.quantity ?? 0, item.unit);
    final detail = take.emptiesRow
        ? l10n.cookedPantryHasRemoved(have)
        : l10n.cookedPantryHasLeft(have, _amountText(take.left, item.unit));
    final amount = _amountText(take.amount, item.unit);

    return Row(
      children: [
        Expanded(
          child: Semantics(
            checked: selected,
            label: l10n.cookedPantryRowSemantics(item.ingredientName, amount),
            onTap: onToggle,
            excludeSemantics: true,
            child: Material(
              type: MaterialType.transparency,
              child: PressFill(
                surface: PressSurface.base,
                child: InkWell(
                  onTap: onToggle,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Row(
                      children: [
                        IgnorePointer(
                          child: ButleryCheckbox(
                            value: selected,
                            onChanged: (_) {},
                          ),
                        ),
                        const SizedBox(width: AppDimensions.space8),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.ingredientName,
                                style: AppTextStyles.labelLargeBold.copyWith(
                                  color: cs.onSurface,
                                ),
                              ),
                              Text(
                                detail,
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
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
        ),
        const SizedBox(width: AppDimensions.space8),
        Semantics(
          button: true,
          label: l10n.cookedPantryAmountSemantics(item.ingredientName, amount),
          excludeSemantics: true,
          onTap: onEdit,
          child: Material(
            type: MaterialType.transparency,
            child: PressFill(
              surface: PressSurface.base,
              child: InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(
                  AppDimensions.radiusControl,
                ),
                child: ButleryOutlinedBox(
                  borderColor: cs.outline,
                  radius: AppDimensions.radiusControl,
                  alignment: Alignment.center,
                  constraints: const BoxConstraints(
                    minWidth: AppDimensions.minTouchTarget,
                    minHeight: AppDimensions.minTouchTarget,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space12,
                  ),
                  child: Text(
                    amount,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelLargeBold.copyWith(
                      color: selected ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.take});

  final CookedPantryTake take;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: formatSwedishDecimal((widget.take.amount * 100).round() / 100),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // An empty or unreadable field is zero: the row is left out.
  void _save() =>
      Navigator.pop(context, parseSwedishDecimal(_controller.text) ?? 0);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = widget.take.item;
    return ButleryDialog.confirm(
      title: l10n.cookedPantryEditTitle(item.ingredientName),
      primaryLabel: l10n.commonSave,
      onPrimary: _save,
      content: StyledInput(
        label: item.unit.isEmpty
            ? l10n.pantryQuantityLabel
            : '${l10n.pantryQuantityLabel} (${item.unit})',
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: const <TextInputFormatter>[
          SwedishDecimalInputFormatter(),
        ],
        onSubmitted: (_) => _save(),
      ),
    );
  }
}
