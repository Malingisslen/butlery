// lib/widgets/common/list/butlery_list_sheet.dart
//
// Choices open in a bottom sheet (Mer, omtänkt, 2026-10-10: "val i ett ark
// nerifrån"): a title and rows, the same rows as on the page below it.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// Opens a sheet titled [title] over [rows]. The rows get the sheet's own
/// context, so a row closes the sheet with `Navigator.pop(sheetContext)`.
Future<T?> showButleryListSheet<T>(
  BuildContext context, {
  required String title,
  required List<Widget> Function(BuildContext sheetContext) rows,
}) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: cs.surface,
    builder: (sheetContext) => SingleChildScrollView(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppDimensions.layoutMarginOf(sheetContext),
        0,
        AppDimensions.layoutMarginOf(sheetContext),
        AppDimensions.layoutMargin,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: AppTextStyles.subpageTitle),
          ),
          ButleryListSection(rows: rows(sheetContext)),
        ],
      ),
    ),
  );
}

/// Opens a sheet where one of [options] is picked; the current one carries
/// a check. Returns the picked value, or null when the sheet is dismissed.
Future<T?> showButleryChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  required T selected,
}) {
  return showButleryListSheet<T>(
    context,
    title: title,
    rows: (sheetContext) => [
      for (final (value, label) in options)
        _ChoiceRow(
          label: label,
          selected: value == selected,
          onTap: () => Navigator.of(sheetContext).pop(value),
        ),
    ],
  );
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppDimensions.minTouchTarget,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style:
                        (selected
                                ? AppTextStyles.labelLarge
                                : AppTextStyles.bodyMedium)
                            .copyWith(color: cs.onSurface),
                  ),
                ),
                if (selected)
                  ExcludeSemantics(
                    child: ButleryIcon(ButleryIcons.check, color: cs.tertiary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
