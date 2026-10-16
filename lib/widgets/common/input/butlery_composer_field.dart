// lib/widgets/common/input/butlery_composer_field.dart

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/field_text_style.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';

/// The field people write chat messages and comments in.
///
/// The same paper, edge and focus ring as every other field, but with round
/// ends, so writing to someone reads apart from filling in a form. It grows
/// with the text to [maxLines] and then scrolls inside (mockup "Butlerys
/// inmatningsfält", del 4, chosen as direction A on 2026-10-10).
///
/// The send button and the other actions stay with the caller, because the
/// chat and the comments carry different ones.
class ButleryComposerField extends StatelessWidget {
  const ButleryComposerField({
    required this.hintText,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.enabled = true,
    this.autofocus = false,
    super.key,
  });

  /// The lines the field grows to before it scrolls.
  static const int maxLines = 4;

  /// Half the one-line height, so a one-line field has fully round ends and
  /// a taller one keeps the same corners.
  static const double radius = AppDimensions.minTouchTarget / 2;

  final String hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final corners = BorderRadius.circular(radius);
    // The edge keeps its colour and width at focus; the ring outside shows
    // focus. Every slot is set, because the theme's own slots would
    // otherwise replace a lone `border`.
    OutlineInputBorder edge(Color color, double width) => OutlineInputBorder(
      borderRadius: corners,
      borderSide: BorderSide(color: color, width: width),
    );
    final resting = edge(cs.outline, AppDimensions.borderWidthStandard);
    final error = edge(cs.error, AppDimensions.borderWidthOutlinedEdge);
    return ButleryFocusRing(
      borderRadius: corners,
      bounds: FocusRingBounds.textFieldBox,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        autofocus: autofocus,
        onChanged: onChanged,
        minLines: 1,
        maxLines: maxLines,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        textCapitalization: TextCapitalization.sentences,
        style: fieldTextStyle(
          context,
          enabled: enabled,
          base: AppTextStyles.bodyMedium.copyWith(color: cs.onSurface),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          border: resting,
          enabledBorder: resting,
          focusedBorder: resting,
          errorBorder: error,
          focusedErrorBorder: error,
          disabledBorder: edge(
            AppModeColors.surfaceDisabled(cs.brightness),
            AppDimensions.borderWidthStandard,
          ),
          constraints: const BoxConstraints(
            minHeight: AppDimensions.minTouchTarget,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space16,
            vertical: AppDimensions.space12,
          ),
        ),
      ),
    );
  }
}
