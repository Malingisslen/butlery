// lib/views/family/family_form_parts.dart
//
// The pieces of the family member form as the sketch draws it (Skärmar v12
// #familjemedlem): sections told apart by a hairline with a bold title and
// an outlined badge, tabs for the age band, rounded colour swatches, checkbox
// rows and pill choices.
library;

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/choice_option.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/badges/unified_badge.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';

/// The small capitals above a field: "NAMN", "FÄRG".
class FormFieldLabel extends StatelessWidget {
  const FormFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space8),
      child: SectionHeading(text),
    );
  }
}

/// A section of the form: a hairline, a bold title with its badge ("KRÄVS",
/// "VALFRITT") and the content under it.
class FormSection extends StatelessWidget {
  const FormSection({
    required this.title,
    required this.badge,
    required this.children,
    super.key,
  });

  final String title;
  final String badge;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ButleryDivider(),
        const SizedBox(height: AppDimensions.space16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: WholeWordText(
                  title,
                  style: AppTextStyles.bodyBold.copyWith(color: cs.onSurface),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.space8),
            UnifiedBadge.status(label: badge),
          ],
        ),
        const SizedBox(height: AppDimensions.space8),
        ...children,
        const SizedBox(height: AppDimensions.space24),
      ],
    );
  }
}

/// A checkbox with its sentence, the whole row ticking it.
class FormCheckRow extends StatelessWidget {
  const FormCheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.dividerBelow = false,
    this.bodyStyle = false,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// A hairline under the row, for the allergen grid.
  final bool dividerBelow;

  /// The running-text size, for a consent sentence rather than a short name.
  final bool bodyStyle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      checked: value,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: dividerBelow
                  ? Border(bottom: BorderSide(color: cs.outlineVariant))
                  : null,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDimensions.minTouchTarget,
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: ButleryCheckbox(value: value, onChanged: onChanged),
                  ),
                  const SizedBox(width: AppDimensions.space4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.space8,
                      ),
                      child: Text(
                        label,
                        style:
                            (bodyStyle
                                    ? AppTextStyles.bodySmall
                                    : AppTextStyles.bodyMedium)
                                .copyWith(color: cs.onSurface),
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

/// Two columns of [FormCheckRow]s: the allergens, as the sketch lists them.
class FormCheckGrid extends StatelessWidget {
  const FormCheckGrid({required this.items, super.key});

  final List<({String label, bool value, ValueChanged<bool> onChanged})> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppDimensions.space16;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: FormCheckRow(
                  label: item.label,
                  value: item.value,
                  onChanged: item.onChanged,
                  dividerBelow: true,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A pill the user may pick any number of: the disliked ingredients.
class FormChoice extends StatelessWidget {
  const FormChoice({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return PressFill(
      surface: selected ? PressSurface.ink : PressSurface.base,
      child: ChoiceOption(
        label: label,
        selected: selected,
        onSelected: () => onSelected(!selected),
      ),
    );
  }
}

/// The age band as tabs: the picked one in bold over an ink underline.
class FormTabs<T> extends StatelessWidget {
  const FormTabs({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    super.key,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          for (final value in values)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == selected,
                label: labelOf(value),
                excludeSemantics: true,
                child: PressFill(
                  surface: PressSurface.base,
                  child: InkWell(
                    onTap: () => onSelected(value),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppDimensions.minTouchTarget,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: value == selected
                                  ? cs.primary
                                  : Colors.transparent,
                              width: AppDimensions.borderWidthThick,
                            ),
                          ),
                        ),
                        child: Center(
                          child: WholeWordText(
                            labelOf(value),
                            textAlign: TextAlign.center,
                            style:
                                (value == selected
                                        ? AppTextStyles.bodyBold
                                        : AppTextStyles.bodyMedium)
                                    .copyWith(
                                      color: value == selected
                                          ? cs.onSurface
                                          : cs.onSurfaceVariant,
                                    ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
