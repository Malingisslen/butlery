// lib/widgets/common/input/butlery_code_field.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// The field for a one-time code: one logical text field shown as six boxes
/// (mockup "Butlerys inmatningsfält", del 4 "Kodfält", chosen as direction A
/// on 2026-10-10), six equal boxes with no divider (Skarmar v12 etapp 3
/// #authmfa).
///
/// The boxes draw the digits. A transparent text field lies over them and
/// takes the touches, the keyboard, paste and autofill, so a
/// whole code lands at once and a digit can be corrected without stepping
/// between six focus stops. A screen reader meets one
/// field named [label].
class ButleryCodeField extends StatefulWidget {
  const ButleryCodeField({
    required this.controller,
    required this.label,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.hasError = false,
    this.autofocus = false,
    super.key,
  });

  /// The digits in a code.
  static const int length = 6;

  /// The height of a box.
  static const double boxHeight = 56;

  final TextEditingController controller;

  /// Shown above the boxes and read as the field's name.
  final String label;

  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Draws the boxes with the error edge. The caller shows the error text.
  final bool hasError;

  final bool autofocus;

  @override
  State<ButleryCodeField> createState() => _ButleryCodeFieldState();
}

class _ButleryCodeFieldState extends State<ButleryCodeField> {
  FocusNode? _ownFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
    _focusNode.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(ButleryCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_rebuild);
      _focusNode.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focusNode.removeListener(_rebuild);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final digits = widget.controller.text;
    // The box the next digit goes into, or the last box once the code is
    // whole, carries the ring while the field has focus: it stands in for
    // the caret the hidden field does not show.
    final current = digits.length < ButleryCodeField.length
        ? digits.length
        : ButleryCodeField.length - 1;
    final focused = _focusNode.hasFocus;

    Widget box(int i) => Expanded(
      child: _CodeBox(
        digit: i < digits.length ? digits[i] : '',
        current: focused && i == current,
        hasError: widget.hasError,
      ),
    );

    final boxes = ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < ButleryCodeField.length; i++) ...[
            if (i > 0) const SizedBox(width: AppDimensions.space8),
            box(i),
          ],
        ],
      ),
    );

    final hiddenField = TextSelectionTheme(
      data: const TextSelectionThemeData(selectionColor: Colors.transparent),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: ButleryCodeField.length,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        buildCounter: _noCounter,
        showCursor: false,
        autocorrect: false,
        enableSuggestions: false,
        expands: true,
        maxLines: null,
        style: const TextStyle(color: Colors.transparent),
        // Every slot is set, because the theme's own slots would otherwise
        // draw a box over the six.
        decoration: const InputDecoration(
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isCollapsed: true,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Read as the field's name below, so it is not said twice.
        ExcludeSemantics(
          child: Text(
            widget.label,
            style: AppTextStyles.bodySmall.copyWith(color: cs.onSurface),
          ),
        ),
        const SizedBox(height: AppDimensions.space8),
        SizedBox(
          height: ButleryCodeField.boxHeight,
          child: Stack(
            children: [
              Positioned.fill(child: boxes),
              Positioned.fill(
                child: Semantics(label: widget.label, child: hiddenField),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget? _noCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => null;
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.digit,
    required this.current,
    required this.hasError,
  });

  final String digit;
  final bool current;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final corners = BorderRadius.circular(AppDimensions.radiusControl);
    final edge = hasError
        ? BorderSide(
            color: cs.error,
            width: AppDimensions.borderWidthOutlinedEdge,
          )
        : BorderSide(
            // A box with a digit in it is drawn darker than an empty one.
            color: digit.isEmpty ? cs.outline : cs.onSurfaceVariant,
            width: AppDimensions.borderWidthStandard,
          );
    final face = ButleryOutlinedBox(
      paintOnly: true,
      color: cs.surface,
      borderRadius: corners,
      border: Border.fromBorderSide(edge),
      child: Center(
        child: Text(
          digit,
          style: AppTextStyles.headlineSmall.copyWith(
            color: cs.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
    if (!current) return face;
    // The ring: 2 px, 3 px outside the box edge.
    const gap = AppDimensions.focusRingOffset;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: face),
        Positioned(
          left: -gap,
          top: -gap,
          right: -gap,
          bottom: -gap,
          child: IgnorePointer(
            child: ButleryOutlinedBox(
              paintOnly: true,
              radius: AppDimensions.radiusControl + gap,
              border: Border.all(
                color: AppModeColors.focusRing(cs.brightness),
                width: AppDimensions.focusRingWidth,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
