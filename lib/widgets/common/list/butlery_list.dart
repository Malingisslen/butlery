// lib/widgets/common/list/butlery_list.dart
//
// The one row and the one section every page under Mer draws (Mer, omtänkt,
// 2026-10-10: "rader, inte kort, för inställningar och navigering" and "en
// sorts avsnittsrubrik: den gröna överraden"). Grown out of MoreView's own
// section and row so the hub and the pages under it cannot drift apart.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/sync/sync_queue_indicator.dart';

/// A section: an optional overline and its rows, a divider between rows but
/// not after the last.
class ButleryListSection extends StatelessWidget {
  const ButleryListSection({this.title, required this.rows, super.key});

  /// The overline. Without one the section is a plain group of rows, as
  /// for Logga ut and Radera kontot, which stand apart from what is above.
  final String? title;

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final heading = title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: AppDimensions.spacingMd,
            bottom: heading == null ? 0 : AppDimensions.spacingXs,
          ),
          child: heading == null
              ? null
              : Semantics(
                  // Its own node, so the heading names the section and does
                  // not swallow the rows under it.
                  container: true,
                  header: true,
                  // The overline in text.success (#3F6B4F light, #8FB89A
                  // dark; tokens.json semantic).
                  child: Text(
                    heading.toUpperCase(),
                    style: AppTextStyles.overline.copyWith(color: cs.tertiary),
                  ),
                ),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          // border.subtle between rows (colorScheme.outlineVariant).
          if (i < rows.length - 1)
            Divider(height: 1, thickness: 1, color: cs.outlineVariant),
        ],
      ],
    );
  }
}

enum _RowKind { nav, toggle, danger, info }

/// One row. The whole row is one control named by its text; [value] and
/// [count] sit at the end, before the chevron.
class ButleryListRow extends StatelessWidget {
  /// A row that leads somewhere: a page, a sheet or a dialog.
  const ButleryListRow({
    required this.label,
    required VoidCallback this.onTap,
    this.subtitle,
    this.value,
    this.count = 0,
    this.countLabel,
    this.leading,
    this.trailing,
    this.identifier,
    super.key,
  }) : _kind = _RowKind.nav,
       checked = false,
       onChanged = null;

  /// A switch that saves when it is flipped; the whole row flips it.
  const ButleryListRow.toggle({
    required this.label,
    required this.checked,
    required ValueChanged<bool> this.onChanged,
    this.subtitle,
    this.identifier,
    super.key,
  }) : _kind = _RowKind.toggle,
       onTap = null,
       value = null,
       count = 0,
       countLabel = null,
       leading = null,
       trailing = null;

  /// The destructive row, in text.danger, last on its page. What it does is
  /// confirmed by the dialog it opens, not by the row.
  const ButleryListRow.danger({
    required this.label,
    required VoidCallback this.onTap,
    this.subtitle,
    this.identifier,
    super.key,
  }) : _kind = _RowKind.danger,
       value = null,
       count = 0,
       countLabel = null,
       leading = null,
       trailing = null,
       checked = false,
       onChanged = null;

  /// A row that only tells something, such as the version.
  const ButleryListRow.info({
    required this.label,
    required String this.value,
    this.identifier,
    super.key,
  }) : _kind = _RowKind.info,
       onTap = null,
       subtitle = null,
       count = 0,
       countLabel = null,
       leading = null,
       trailing = null,
       checked = false,
       onChanged = null;

  final _RowKind _kind;
  final String label;
  final String? subtitle;

  /// The current setting, in secondary text at the end of the row.
  final String? value;

  /// A saffron count; drawn only above zero.
  final int count;

  /// What [count] means, read instead of the bare number.
  final String? countLabel;

  /// A glyph before the label, for an action row such as Logga ut.
  final IconData? leading;

  /// Drawn after the value, such as the Admin pill.
  final Widget? trailing;

  final String? identifier;
  final VoidCallback? onTap;
  final bool checked;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final danger = _kind == _RowKind.danger;
    final toggle = _kind == _RowKind.toggle;
    final info = _kind == _RowKind.info;
    final mutedText = cs.onSurfaceVariant;

    Widget rowContent(double rowWidth) => ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppDimensions.minTouchTarget,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.spacingSm + 2,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              ExcludeSemantics(child: ButleryIcon(leading!, color: mutedText)),
              const SizedBox(width: AppDimensions.spacingL),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: danger ? cs.error : cs.onSurface,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTextStyles.captionBase.copyWith(
                        color: mutedText,
                      ),
                    ),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: AppDimensions.spacingL),
              // At most 45 % of the row, so the label keeps its room and
              // every chevron stays at the end.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: rowWidth * 0.45),
                child: Text(
                  value!,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.captionBase.copyWith(
                    color: mutedText,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(width: AppDimensions.spacingSm),
              ExcludeSemantics(child: trailing!),
            ],
            if (count > 0) ...[
              const SizedBox(width: AppDimensions.spacingSm),
              ExcludeSemantics(child: SaffronCount(count: count)),
            ],
            if (toggle) ...[
              const SizedBox(width: AppDimensions.spacingL),
              // The row carries the switch's meaning; the switch is drawn.
              ExcludeSemantics(
                child: Switch(value: checked, onChanged: onChanged),
              ),
            ] else if (!info) ...[
              const SizedBox(width: AppDimensions.spacingSm),
              ExcludeSemantics(
                child: ButleryIcon(ButleryIcons.chevronRight, color: mutedText),
              ),
            ],
          ],
        ),
      ),
    );
    final content = LayoutBuilder(
      builder: (context, constraints) => rowContent(constraints.maxWidth),
    );

    if (info) {
      return Semantics(
        container: true,
        identifier: identifier,
        child: content,
      );
    }

    return Semantics(
      container: true,
      button: !toggle,
      toggled: toggle ? checked : null,
      identifier: identifier,
      value: count > 0 ? countLabel : null,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          onTap: toggle ? () => onChanged!(!checked) : onTap,
          child: content,
        ),
      ),
    );
  }
}
