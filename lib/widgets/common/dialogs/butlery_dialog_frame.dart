// lib/widgets/common/dialogs/butlery_dialog_frame.dart
//
// The frame of a dialog that lays out its own body, such as a form with a
// header and a footer. Background and edge come from the dialog theme; the
// frame sets the width and height ceiling from the dialog tokens, so no dialog
// picks its own number. A dialog that only asks or tells uses ButleryDialog.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';

class ButleryDialogFrame extends StatelessWidget {
  const ButleryDialogFrame({
    required this.child,
    this.maxWidth = AppDimensions.dialogMaxWidthMedium,
    this.maxHeight,
    this.padding,
    super.key,
  });

  final Widget child;

  /// A dialog token, or a screen-based value clamped between two of them.
  final double maxWidth;
  final double? maxHeight;

  /// Space around [child]; null when the body pads itself.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final body = padding == null
        ? child
        : Padding(padding: padding!, child: child);
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight ?? double.infinity,
        ),
        child: body,
      ),
    );
  }
}
