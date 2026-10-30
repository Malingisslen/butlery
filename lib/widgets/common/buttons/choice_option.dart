// lib/widgets/common/buttons/choice_option.dart
//
// A pill for picking one value out of a few (
// the meal types). Outlined at rest, ink with paper text when chosen, 48 dp
// high. A group is a [ChoiceOptionWrap], so no view lays pills out itself.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/press_fill.dart';

class ChoiceOption extends StatelessWidget {
  const ChoiceOption({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shape = StadiumBorder(
      side: BorderSide(
        color: selected ? cs.primary : cs.outline,
        width: AppDimensions.borderWidthOutlinedEdge,
      ),
    );
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      onTap: onSelected,
      excludeSemantics: true,
      child: Material(
        color: selected ? cs.primary : Colors.transparent,
        shape: shape,
        child: PressFill(
          surface: selected ? PressSurface.ink : PressSurface.base,
          child: InkWell(
            onTap: onSelected,
            customBorder: shape,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDimensions.minTouchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space16,
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: selected ? cs.onPrimary : cs.onSurface,
                    ),
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

/// The pills of one choice, wrapped onto as many lines as they need.
class ChoiceOptionWrap<T> extends StatelessWidget {
  const ChoiceOptionWrap({
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<T> values;
  final String Function(T value) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.space8,
      runSpacing: AppDimensions.space8,
      children: [
        for (final value in values)
          ChoiceOption(
            label: labelOf(value),
            selected: value == selected,
            onSelected: () => onChanged(value),
          ),
      ],
    );
  }
}
