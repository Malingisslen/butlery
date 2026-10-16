// lib/widgets/common/menus/butlery_menu.dart
//
// The ⋯ menu on a card or a header, and the dropdown in a form. A view hands
// over the choices; the glyph, the touch target, the focus ring, the arrow
// colours and the row layout are drawn here.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/input/field_error_line.dart';
import 'package:butlery/widgets/common/input/labeled_field.dart';
import 'package:butlery/widgets/common/input/styled_input_borders.dart';

/// One choice in a [ButleryMenu].
class ButleryMenuChoice<T> {
  const ButleryMenuChoice({
    required this.value,
    required this.label,
    this.icon,
    this.danger = false,
    this.enabled = true,
    this.dividerBefore = false,
    this.tabularFigures = false,
    this.itemKey,
    this.selected = false,
    this.trailingIcon,
    this.iconColor,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// Drawn in text.danger: the choice removes something.
  final bool danger;
  final bool enabled;

  /// A hairline above the choice, to set a destructive one apart.
  final bool dividerBefore;

  /// The label in tabular figures, for a choice that carries a count such as
  /// "Markera alla 24".
  final bool tabularFigures;

  /// Lets a test find the row.
  final Key? itemKey;

  /// The choice now in force: its glyph is drawn in the text colour.
  final bool selected;

  /// A glyph after the label, as the arrow that gives a sort direction.
  final IconData? trailingIcon;

  /// The glyph in this colour, when only it should stand out, as the flag of
  /// a report choice; [danger] colours the words too.
  final Color? iconColor;
}

/// A button that opens a menu of [choices] and reports the one picked.
class ButleryMenu<T> extends StatelessWidget {
  const ButleryMenu({
    required this.choices,
    required this.onSelected,
    required this.semanticLabel,
    this.icon = ButleryIcons.moreVertical,
    this.iconColor,
    this.child,
    this.iconWidget,
    this.padding,
    this.style,
    super.key,
  });

  final List<ButleryMenuChoice<T>> choices;
  final ValueChanged<T> onSelected;

  /// What the button opens, from l10n: "Fler val för receptet".
  final String semanticLabel;

  final IconData icon;
  final Color? iconColor;

  /// Draws the button as this widget instead of the ⋯ glyph, such as a
  /// "Sortera" pill, or the paper ring on a photo. The menu rows are the same.
  final Widget? child;

  /// Draws the button as this widget in the icon slot, which keeps the icon
  /// button's name and tap target, as the ring on a photo does.
  final Widget? iconWidget;
  final EdgeInsetsGeometry? padding;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PressFill(
      surface: PressSurface.base,
      child: PopupMenuButton<T>(
        tooltip: semanticLabel,
        padding: padding ?? const EdgeInsets.all(8),
        style: style,
        icon:
            iconWidget ??
            (child == null ? ButleryIcon(icon, color: iconColor) : null),
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final c in choices) ...[
            if (c.dividerBefore) const PopupMenuDivider(),
            ButleryMenuItem<T>(
              key: c.itemKey,
              value: c.value,
              enabled: c.enabled,
              child: Row(
                children: [
                  if (c.icon != null) ...[
                    ButleryIcon(
                      c.icon!,
                      color: c.danger
                          ? cs.error
                          : c.iconColor ?? (c.selected ? cs.onSurface : null),
                    ),
                    const SizedBox(width: AppDimensions.space8),
                  ],
                  Flexible(
                    child: Text(
                      c.label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: !c.enabled
                            ? AppModeColors.textDisabled(cs.brightness)
                            : c.danger
                            ? cs.error
                            : null,
                        fontFeatures: c.tabularFigures
                            ? const [FontFeature.tabularFigures()]
                            : null,
                      ),
                    ),
                  ),
                  if (c.trailingIcon != null) ...[
                    const SizedBox(width: AppDimensions.space8),
                    ButleryIcon(
                      c.trailingIcon!,
                      size: AppDimensions.iconSizeM,
                      color: cs.onSurface,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
        child: child,
      ),
    );
  }
}

/// One option in a [ButleryDropdown].
class ButleryDropdownOption<T> {
  const ButleryDropdownOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.header = false,
    this.error = false,
    this.indented = false,
    this.subtitleSuffix,
    this.subtitleSuffixColor,
  });

  final T value;
  final String label;

  /// A heading over the options below it: drawn bold and not pickable.
  final bool header;

  /// The label in the error colour, for a stored value that no longer exists.
  final bool error;

  /// Set in under a [header].
  final bool indented;

  /// A second line under the label, as the item count under a list's name.
  final String? subtitle;

  /// Words after the second line, in their own colour, as the permission
  /// after a list's item count.
  final String? subtitleSuffix;
  final Color? subtitleSuffixColor;

  /// A glyph before the label, as the eye, pencil or crown of a permission.
  final IconData? icon;
  final Color? iconColor;
}

/// A form field that picks one of [options]. The stored value and the options
/// must come from one read: the framework re-checks that they match on every
/// build.
class ButleryDropdown<T> extends StatelessWidget {
  const ButleryDropdown({
    required this.options,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.hint,
    this.label,
    this.validator,
    this.autovalidateMode,
    this.errorText,
    this.dense = false,
    this.square = false,
    this.closedShowsSubtitle = false,
    super.key,
  });

  final List<ButleryDropdownOption<T>> options;
  final T? value;

  /// Null disables the field.
  final ValueChanged<T>? onChanged;
  final String? hint;

  /// The visible label above the box, drawn as a text field's is.
  final String? label;

  /// Runs inside a Form, as a text field's validator does.
  final String? Function(T?)? validator;
  final AutovalidateMode? autovalidateMode;

  /// An error set from outside the Form, in the error line under the box.
  final String? errorText;

  /// A tighter box, for a field inside a card or a rule row.
  final bool dense;

  /// Square corners and a hairline edge, as the onboarding screens draw it.
  final bool square;

  /// The closed field shows the second line too, for a choice that is
  /// recognised by it, such as a list by its item count.
  final bool closedShowsSubtitle;

  /// Names the field for a screen reader, since the chosen value alone does
  /// not.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borders = square
        ? styledInputBorders(context, square: true, showWarning: false)
        : null;
    final field = PressFill(
      surface: PressSurface.base,
      child: DropdownButtonFormField<T>(
        // initialValue is read once; a new value rebuilds the field.
        key: ValueKey<T?>(value),
        initialValue: value,
        isExpanded: true,
        // A closed field with a second line needs more than the dense
        // button height.
        isDense:
            !(closedShowsSubtitle && options.any((o) => o.subtitle != null)),
        // Null lets an option with a second line take the height it needs.
        itemHeight: options.any((o) => o.subtitle != null)
            ? null
            : kMinInteractiveDimension,
        icon: const ButleryIcon(ButleryIcons.chevronDown),
        iconEnabledColor: cs.onSurfaceVariant,
        iconDisabledColor: AppModeColors.textDisabled(cs.brightness),
        hint: hint == null ? null : Text(hint!),
        style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurface),
        validator: validator,
        autovalidateMode: autovalidateMode,
        errorBuilder: FieldErrorLine.builder,
        decoration: InputDecoration(
          isDense: dense,
          border: borders?.base,
          enabledBorder: borders?.resting,
          focusedBorder: borders?.resting,
          errorBorder: borders?.error,
          focusedErrorBorder: borders?.error,
          disabledBorder: borders?.disabled,
          error: errorText == null || validator != null
              ? null
              : FieldErrorLine(errorText!),
        ),
        // The closed field shows one line; the second line is for the menu.
        selectedItemBuilder: (context) => [
          for (final o in options)
            _OptionRow(option: o, compact: !closedShowsSubtitle),
        ],
        items: [
          for (final o in options)
            DropdownMenuItem<T>(
              value: o.value,
              enabled: !o.header,
              child: _OptionRow(option: o),
            ),
        ],
        onChanged: onChanged == null
            ? null
            : (v) {
                if (v != null) onChanged!(v);
              },
      ),
    );
    return Semantics(
      label: semanticLabel,
      child: label == null ? field : LabeledField(label: label, child: field),
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({required this.option, this.compact = false});

  final ButleryDropdownOption<T> option;

  /// Label and glyph only: the closed field is one line high.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final second = compact ? null : option.subtitle;
    // Cut to one line at the normal text size; the name wraps when the user
    // has asked for larger text.
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1;
    if (option.icon == null && second == null) {
      final text = Text(
        option.label,
        overflow: TextOverflow.ellipsis,
        style: option.header
            ? AppTextStyles.labelMediumBold
            : option.error
            ? AppTextStyles.formOption.copyWith(color: cs.error)
            : null,
      );
      return option.indented
          ? Padding(padding: AppDimensions.paddingOnlyStart8, child: text)
          : text;
    }
    return Row(
      children: [
        if (option.icon != null) ...[
          ButleryIcon(option.icon!, color: option.iconColor),
          const SizedBox(width: AppDimensions.space8),
        ],
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option.label,
                maxLines: largeText ? null : 1,
                overflow: largeText ? null : TextOverflow.ellipsis,
              ),
              if (second != null)
                Text.rich(
                  TextSpan(
                    text: second,
                    children: [
                      if (option.subtitleSuffix != null)
                        TextSpan(
                          text: ' • ${option.subtitleSuffix}',
                          style: TextStyle(
                            color:
                                option.subtitleSuffixColor ??
                                cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  style: AppTextStyles.captionBase.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
