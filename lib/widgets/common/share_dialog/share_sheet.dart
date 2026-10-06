// lib/widgets/common/share_dialog/share_sheet.dart
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';

/// Opens the universal share surface as a sheet from the bottom with a
/// handle, as frame #delaark draws it (R8-8). On a wide screen the sheet
/// keeps one column of at most [AppDimensions.dialogMaxWidthLarge].
///
/// [builder] returns the share widget, with any provider it needs wrapped
/// around it by the caller.
Future<void> showUniversalShareSheet(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: cs.surface,
    constraints: const BoxConstraints(
      maxWidth: AppDimensions.dialogMaxWidthLarge,
    ),
    builder: builder,
  );
}
