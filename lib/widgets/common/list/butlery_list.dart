// lib/widgets/common/list/butlery_list.dart
//
// The one row and the one section every page under Mer draws (Mer, omtänkt,
// 2026-10-10: "rader, inte kort, för inställningar och navigering" and "en
// sorts avsnittsrubrik: den gröna överraden"). Grown out of MoreView's own
// section and row so the hub and the pages under it cannot drift apart.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/input/butlery_switch.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/sync/sync_queue_indicator.dart';
import 'package:butlery/widgets/common/section_heading.dart';

/// A section: an optional overline and its rows, a divider between rows but
/// not after the last.
class ButleryListSection extends StatelessWidget {
  const ButleryListSection({
    this.title,
    required this.rows,
    this.count,
    super.key,
  }) : _plainTitle = false;

  /// A section named in bold ink with its size at the end of the line, as
  /// Mitt hushåll draws "Hushållets konton · 2 konton".
  const ButleryListSection.counted({
    required String this.title,
    required String this.count,
    required this.rows,
    super.key,
  }) : _plainTitle = true;

  /// Written at the end of a [ButleryListSection.counted] heading.
  final String? count;

  final bool _plainTitle;

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
            top: AppDimensions.space16,
            bottom: heading == null ? 0 : AppDimensions.space4,
          ),
          child: heading == null
              ? null
              : _plainTitle
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          heading,
                          style: AppTextStyles.bodyBold.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                    if (count != null)
                      Text(
                        count!,
                        style: AppTextStyles.captionBase.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                )
              : SectionHeading(heading, tone: SectionHeadingTone.emphasis),
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
    this.selected,
    this.emphasis = false,
    this.identifier,
    super.key,
  }) : _muted = false,
       leadingColor = null,
       _kind = _RowKind.nav,
       centered = false,
       enabled = true,
       strongValue = false,
       checked = false,
       onChanged = null;

  /// A switch that saves when it is flipped; the whole row flips it.
  const ButleryListRow.toggle({
    required this.label,
    required this.checked,
    required ValueChanged<bool> this.onChanged,
    this.subtitle,
    this.enabled = true,
    this.emphasis = false,
    this.identifier,
    super.key,
  }) : _muted = false,
       leadingColor = null,
       _kind = _RowKind.toggle,
       centered = false,
       strongValue = false,
       selected = null,
       onTap = null,
       value = null,
       count = 0,
       countLabel = null,
       leading = null,
       trailing = null;

  /// The destructive row, in text.danger, last on its page. What it does is
  /// confirmed by the dialog it opens, not by the row.
  ///
  /// [centered] draws it as the sketch's last line of a profile page: the
  /// words centred under the rows, no chevron.
  const ButleryListRow.danger({
    required this.label,
    required VoidCallback this.onTap,
    this.subtitle,
    this.centered = false,
    this.identifier,
    super.key,
  }) : _muted = false,
       leadingColor = null,
       _kind = _RowKind.danger,
       selected = null,
       enabled = true,
       emphasis = false,
       strongValue = false,
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
    this.strongValue = false,
    this.identifier,
    super.key,
  }) : _muted = false,
       leadingColor = null,
       _kind = _RowKind.info,
       centered = false,
       selected = null,
       enabled = true,
       emphasis = false,
       onTap = null,
       subtitle = null,
       count = 0,
       countLabel = null,
       leading = null,
       trailing = null,
       checked = false,
       onChanged = null;

  /// A line that tells something and leads nowhere, with an optional glyph:
  /// the check and cross rows of Hämta ut dina uppgifter. [muted] sets the
  /// text in secondary ink, for what does not apply.
  const ButleryListRow.note({
    required this.label,
    this.leading,
    this.leadingColor,
    this.subtitle,
    bool muted = false,
    this.emphasis = false,
    this.identifier,
    super.key,
  }) : _muted = muted,
       _kind = _RowKind.info,
       centered = false,
       selected = null,
       enabled = true,
       strongValue = false,
       onTap = null,
       value = null,
       count = 0,
       countLabel = null,
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

  /// Set on a row that picks among several, so its state is read out; the
  /// glyph that shows it is excluded from semantics. A selected row also takes
  /// the selected surface behind its full width.
  final bool? selected;

  /// A danger row drawn as centred words with no chevron.
  final bool centered;

  final String? identifier;
  final VoidCallback? onTap;
  final bool checked;
  final ValueChanged<bool>? onChanged;

  /// Only for a toggle that cannot be flipped now because something above it
  /// is off; drawn in text.disabled, never faded.
  final bool enabled;

  /// The master switch that rules the rows under it, set in bold.
  final bool emphasis;

  /// An information row's figure set in bold ink, as the sketch's counts.
  final bool strongValue;

  /// The colour of [leading]; secondary ink when null.
  final Color? leadingColor;

  bool get muted => _muted;
  final bool _muted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final danger = _kind == _RowKind.danger;
    final toggle = _kind == _RowKind.toggle;
    final info = _kind == _RowKind.info;
    final mutedText = cs.onSurfaceVariant;
    final labelColor = !enabled
        ? AppModeColors.textDisabled(cs.brightness)
        : danger
        ? cs.error
        : muted
        ? cs.onSurfaceVariant
        : cs.onSurface;

    if (centered) {
      return Semantics(
        container: true,
        button: true,
        identifier: identifier,
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDimensions.minTouchTarget,
              ),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyBold.copyWith(color: labelColor),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final valueStyle = strongValue
        ? AppTextStyles.bodyBold.copyWith(
            color: cs.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          )
        : AppTextStyles.captionBase.copyWith(
            color: mutedText,
            fontFeatures: const [FontFeature.tabularFigures()],
          );
    final labelStyle = emphasis
        ? AppTextStyles.bodyBold
        : AppTextStyles.bodyMedium;
    // Under large text a value that does not fit beside the label's widest
    // word goes under the label.
    bool stacks(double rowWidth) {
      if (value == null || !isLargeText(context)) return false;
      final valueWidth = singleLineWidth(context, value!, valueStyle);
      final chrome =
          AppDimensions.space12 * 2 +
          AppDimensions.minTouchTarget +
          (leading != null ? AppDimensions.minTouchTarget : 0) +
          (trailing != null ? AppDimensions.minTouchTarget : 0) +
          (count > 0 ? AppDimensions.minTouchTarget : 0);
      return valueWidth > rowWidth * 0.45 ||
          widestWord(context, [label], labelStyle) + valueWidth + chrome >
              rowWidth;
    }

    Widget valueText(bool stackValue) => stackValue
        ? WholeWordText(value!, style: valueStyle)
        : Text(
            value!,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: valueStyle,
          );

    Widget rowContent(double rowWidth) {
      final stackValue = stacks(rowWidth);
      return ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppDimensions.minTouchTarget,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.space8,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                ExcludeSemantics(
                  child: ButleryIcon(
                    leading!,
                    color: leadingColor ?? mutedText,
                  ),
                ),
                const SizedBox(width: AppDimensions.space12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WholeWordText(
                      label,
                      style: labelStyle.copyWith(color: labelColor),
                    ),
                    if (subtitle != null)
                      WholeWordText(
                        subtitle!,
                        style: AppTextStyles.captionBase.copyWith(
                          color: mutedText,
                        ),
                      ),
                    if (value != null && stackValue) valueText(true),
                  ],
                ),
              ),
              if (value != null && !stackValue) ...[
                const SizedBox(width: AppDimensions.space12),
                // At most 45 % of the row, so the label keeps its room and
                // every chevron stays at the end.
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: rowWidth * 0.45),
                  child: valueText(false),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: AppDimensions.space8),
                ExcludeSemantics(child: trailing!),
              ],
              if (count > 0) ...[
                const SizedBox(width: AppDimensions.space8),
                ExcludeSemantics(child: SaffronCount(count: count)),
              ],
              if (toggle) ...[
                const SizedBox(width: AppDimensions.space12),
                // The row carries the switch's meaning; the switch is drawn.
                ExcludeSemantics(
                  child: ButlerySwitch(
                    value: checked,
                    onChanged: enabled ? onChanged : null,
                  ),
                ),
              ] else if (!info) ...[
                const SizedBox(width: AppDimensions.space8),
                const ButleryChevron(),
              ],
            ],
          ),
        ),
      );
    }

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
      selected: selected,
      enabled: enabled,
      identifier: identifier,
      value: count > 0 ? countLabel : null,
      // surface.selected behind the whole row; transparent otherwise so the
      // page's own surface shows.
      child: Material(
        color: selected == true
            ? cs.surfaceContainerHighest
            : Colors.transparent,
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            onTap: !enabled
                ? null
                : toggle
                ? () => onChanged!(!checked)
                : onTap,
            child: content,
          ),
        ),
      ),
    );
  }
}

/// The chevron at the end of a row that leads somewhere: 12 px in
/// text.secondary. Drawn, not
/// read: the row it sits in is the control and carries the meaning.
class ButleryChevron extends StatelessWidget {
  const ButleryChevron({this.color, super.key});

  /// Secondary ink when null; a row on a coloured surface names its own.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ButleryIcon(
        ButleryIcons.chevronRight,
        size: AppDimensions.iconSizeXs,
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
