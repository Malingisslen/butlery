// lib/widgets/admin/admin_table.dart
//
// The admin table of the drawn admin panel (Skarmar v12 etapp 5-7 #9): a
// tinted header row in capitals, hairline rows, and every column given room,
// so nothing is clipped or broken mid-word.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';
import 'package:butlery/widgets/common/press_fill.dart';

class AdminTableColumn {
  const AdminTableColumn({
    required this.label,
    this.flex = 1,
    this.alignEnd = false,
  });

  final String label;
  final int flex;
  final bool alignEnd;
}

class AdminTableRow {
  const AdminTableRow({required this.cells, this.onTap, this.cellColors});

  /// One text per column.
  final List<String> cells;
  final VoidCallback? onTap;

  /// Optional text colour per column; null keeps the default.
  final List<Color?>? cellColors;
}

class AdminTable extends StatelessWidget {
  const AdminTable({
    required this.columns,
    required this.rows,
    this.footer,
    super.key,
  });

  final List<AdminTableColumn> columns;
  final List<AdminTableRow> rows;

  /// A tinted note closing the table, as "Glest med flit" in the driftlogg.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: cs.outlineVariant,
          width: AppDimensions.borderWidthStandard,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (columns.any((c) => c.label.isNotEmpty))
            Container(
              color: cs.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space12,
                vertical: AppDimensions.space8,
              ),
              child: _line(
                [
                  for (final c in columns)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: c.alignEnd
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: Text(
                        c.label.toUpperCase(),
                        style: AppTextStyles.overline.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                      ),
                    ),
                ],
              ),
            ),
          for (final row in rows) _row(context, row),
          ?footer,
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AdminTableRow row) {
    final cs = Theme.of(context).colorScheme;
    final content = Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant,
            width: AppDimensions.borderWidthStandard,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space12,
      ),
      child: _line([
        for (var i = 0; i < columns.length; i++)
          WholeWordText(
            i < row.cells.length ? row.cells[i] : '',
            style: AppTextStyles.bodyMedium.copyWith(
              color: row.cellColors?[i] ?? cs.onSurface,
            ),
            textAlign: columns[i].alignEnd ? TextAlign.end : TextAlign.start,
          ),
      ]),
    );
    if (row.onTap == null) return content;
    return PressFill(
      surface: PressSurface.base,
      child: InkWell(onTap: row.onTap, child: content),
    );
  }

  // The gap keeps one column's capitals from running into the next one's.
  Widget _line(List<Widget> cells) => Row(
    spacing: AppDimensions.space8,
    children: [
      for (var i = 0; i < cells.length; i++)
        Expanded(flex: columns[i].flex, child: cells[i]),
    ],
  );
}
