// lib/widgets/common/input/butlery_row_field.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/field_text_style.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';

/// One row of an editable list: ingredients, steps, imported lines.
///
/// No box around each row, only a dividing line under it and the focus
/// ring on the field being written in (mockup "Butlerys inmatningsfält",
/// del 4 "Radfält i listor", chosen as direction A on 2026-10-10). The row is
/// at least the 48 dp touch target tall.
class ButleryFieldRow extends StatelessWidget {
  const ButleryFieldRow({
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    super.key,
  });

  /// The row's content, typically a drag handle, a [ButleryRowField] in an
  /// [Expanded] and the row's actions.
  final List<Widget> children;

  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant,
            width: AppDimensions.borderWidthStandard,
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppDimensions.minTouchTarget,
        ),
        child: Row(
          crossAxisAlignment: crossAxisAlignment,
          children: children,
        ),
      ),
    );
  }
}

/// The number in front of a numbered row, such as a recipe step. It stands
/// on the first line of the row's text, so a long step keeps its number at
/// the top; give that row [CrossAxisAlignment.start].
class ButleryRowNumber extends StatelessWidget {
  const ButleryRowNumber(this.number, {super.key});

  final int number;

  /// The least width of the number column, so rows line up.
  static const double width = 28;

  @override
  Widget build(BuildContext context) {
    // Read as part of the row's hint or text, so the number is not said
    // twice.
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: width),
        child: Padding(
          padding: const EdgeInsets.only(top: AppDimensions.space12),
          child: Text('$number.', style: AppTextStyles.contentLabel),
        ),
      ),
    );
  }
}

/// The text field inside a [ButleryFieldRow]: no fill and no edge, and the
/// focus ring when focused.
///
/// A [maxLength] limits the text without showing a counter, as the rows
/// have no room for one.
class ButleryRowField extends StatelessWidget {
  const ButleryRowField({
    this.controller,
    this.initialValue,
    this.focusNode,
    this.hintText,
    this.style,
    this.maxLength,
    this.maxLines,
    this.keyboardType = TextInputType.multiline,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onFieldSubmitted,
    this.suffixIcon,
    this.enabled = true,
    super.key,
  }) : assert(
         controller == null || initialValue == null,
         'Pass a controller or an initial value, not both.',
       );

  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final String? hintText;

  /// The typed text's style; body medium in onSurface when null.
  final TextStyle? style;

  final int? maxLength;

  /// Null lets the row grow with its text.
  final int? maxLines;

  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  /// An action inside the field's end, such as a remove or add button.
  final Widget? suffixIcon;

  final bool enabled;

  static Widget? _noCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final corners = BorderRadius.circular(AppDimensions.radiusControl);
    return ButleryFocusRing(
      borderRadius: corners,
      bounds: FocusRingBounds.textFieldBox,
      child: TextFormField(
        controller: controller,
        initialValue: initialValue,
        focusNode: focusNode,
        enabled: enabled,
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,
        maxLength: maxLength,
        maxLengthEnforcement: maxLength == null
            ? null
            : MaxLengthEnforcement.enforced,
        buildCounter: _noCounter,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        style: fieldTextStyle(
          context,
          enabled: enabled,
          base: style ?? AppTextStyles.bodyMedium.copyWith(color: cs.onSurface),
        ),
        // Every edge slot is set to none, because the theme's own slots
        // would otherwise draw a box around the row.
        decoration: InputDecoration(
          hintText: hintText,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          suffixIcon: suffixIcon,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space8,
            vertical: AppDimensions.space12,
          ),
        ),
      ),
    );
  }
}
