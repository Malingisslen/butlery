// lib/widgets/common/share_dialog/share_sheet.dart
library;

import 'package:flutter/material.dart';

import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';

/// Opens the universal share surface as a sheet from the bottom with a
/// handle, as frame #delaark draws it (R8-8). On a wide screen the sheet
/// keeps one column; the width comes from the sheet theme.
///
/// [builder] returns the share widget, with any provider it needs wrapped
/// around it by the caller.
Future<void> showUniversalShareSheet(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showButlerySheet<void>(context: context, builder: builder);
}
